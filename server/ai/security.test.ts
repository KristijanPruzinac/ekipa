import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { Repository } from '../repository.ts';
import { prepareTip, type AiLedger } from './openrouter.ts';

const input = { note: 'Koncert u Osijeku 5. listopada 2026.', url: null };
const config = { apiKey: 'mock-provider-key', monthlyBudgetUsd: 1, searchEnabled: true };
const envelope = (annotations: unknown = []) =>
  JSON.stringify({
    usage: { cost: 0.001 },
    choices: [{ finish_reason: 'stop', message: { content: 'Lookup finished.', annotations } }],
  });

function accounting() {
  let reservations = 0;
  const settlements: Array<[string, number | null]> = [];
  const ledger: AiLedger = {
    reserve: () => `held-${++reservations}`,
    settle: (id, cost) => {
      settlements.push([id, cost]);
    },
  };
  return { ledger, settlements, reservations: () => reservations };
}

test('a reservation delayed past the deadline never sends a paid request and releases its unused charge', async (context) => {
  context.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-03T10:00:00Z') });
  const deadlineMs = Date.now() + 1000;
  const book = accounting();
  let requests = 0;
  const result = await prepareTip(
    input,
    config,
    {
      ...book.ledger,
      reserve: async (amount) => {
        const id = await book.ledger.reserve(amount);
        context.mock.timers.setTime(deadlineMs + 1);
        return id;
      },
    },
    {
      deadlineMs,
      fetch: async () => {
        requests++;
        return new Response(envelope());
      },
    },
  );
  assert.equal(requests, 0);
  assert.equal(result.attempted, false);
  assert.equal(result.complete, false);
  assert.equal(book.reservations(), 1);
  assert.deepEqual(book.settlements, [['held-1', 0]]);
});

test('excess distinct citation sources, excerpt size or aggregate evidence stop before another reservation or provider call', async () => {
  for (const annotations of [
    Array.from({ length: 4 }, (_, index) => ({
      type: 'url_citation',
      url_citation: { url: `https://organizer.test/${index}`, content: input.note },
    })),
    [
      {
        type: 'url_citation',
        url_citation: { url: 'https://organizer.test/', content: 'x'.repeat(2001) },
      },
    ],
    Array.from({ length: 4 }, (_, index) => ({
      type: 'url_citation',
      url_citation: {
        url: 'https://organizer.test/same-source',
        content: `${index}${'x'.repeat(1500)}`,
      },
    })),
  ]) {
    const book = accounting();
    let requests = 0;
    const result = await prepareTip(input, config, book.ledger, {
      fetch: async () => {
        requests++;
        return new Response(envelope(annotations));
      },
    });
    assert.equal(requests, 1);
    assert.equal(book.reservations(), 1);
    assert.deepEqual(book.settlements, [['held-1', 0.001]]);
    assert.equal(result.complete, false);
    assert.equal(result.draft, null);
    assert.match(result.reason, /ograničenje/);
  }
});

test('repeated citations deduplicate their exact URL and normalized excerpt without exhausting the result limit', async () => {
  const book = accounting();
  let requests = 0;
  const result = await prepareTip(input, config, book.ledger, {
    fetch: async (_request, init) => {
      requests++;
      if (requests === 1)
        return new Response(
          envelope(
            Array.from({ length: 8 }, (_, index) => ({
              type: 'url_citation',
              url_citation: {
                url: 'https://organizer.test/event',
                content:
                  index % 2 ? `  ${input.note.replace('Koncert', '**Koncert**')}  ` : input.note,
                start_index: index * 10,
                end_index: index * 10 + 8,
              },
            })),
          ),
        );
      const data = JSON.parse(JSON.parse(String(init?.body)).messages[1].content);
      assert.deepEqual(data.searchEvidence, {
        urls: ['https://organizer.test/event'],
        excerpts: [input.note],
      });
      return new Response(
        JSON.stringify({
          usage: { cost: 0.001 },
          choices: [
            {
              finish_reason: 'stop',
              message: {
                content: JSON.stringify({
                  classification: 'uncertain',
                  draft: null,
                  reason: 'Potrebna je provjera.',
                }),
              },
            },
          ],
        }),
      );
    },
  });
  assert.equal(requests, 2);
  assert.equal(book.reservations(), 2);
  assert.equal(result.complete, true);
  assert.deepEqual(result.evidenceUrls, ['https://organizer.test/event']);
});

test('different excerpts from at most three sources preserve up to 6000 characters without truncation', async () => {
  const book = accounting();
  const excerpts = Array.from({ length: 4 }, (_, index) => `${index}${'x'.repeat(1499)}`);
  let requests = 0;
  const result = await prepareTip(input, config, book.ledger, {
    fetch: async (_request, init) => {
      requests++;
      if (requests === 1)
        return new Response(
          envelope(
            excerpts.map((content, index) => ({
              type: 'url_citation',
              url_citation: { url: `https://organizer.test/${index % 3}`, content },
            })),
          ),
        );
      const data = JSON.parse(JSON.parse(String(init?.body)).messages[1].content);
      assert.deepEqual(data.searchEvidence.excerpts, excerpts);
      assert.equal(data.searchEvidence.urls.length, 3);
      assert.equal(data.searchEvidence.excerpts.join('').length, 6000);
      return new Response(
        JSON.stringify({
          usage: { cost: 0.001 },
          choices: [
            {
              finish_reason: 'stop',
              message: {
                content: JSON.stringify({
                  classification: 'uncertain',
                  draft: null,
                  reason: 'Potrebna je provjera.',
                }),
              },
            },
          ],
        }),
      );
    },
  });
  assert.equal(requests, 2);
  assert.equal(result.complete, true);
});

test('oversized provider envelopes cancel the stream and retain the unknown reservation', async () => {
  for (const advertised of [true, false]) {
    const book = accounting();
    let requests = 0,
      cancelled = false;
    const result = await prepareTip(input, config, book.ledger, {
      fetch: async () => {
        requests++;
        const stream = new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new TextEncoder().encode('x'.repeat(256 * 1024 + 1)));
          },
          cancel() {
            cancelled = true;
          },
        });
        return new Response(stream, {
          headers: advertised ? { 'content-length': String(256 * 1024 + 1) } : {},
        });
      },
    });
    assert.equal(requests, 1);
    assert.equal(cancelled, true);
    assert.equal(result.complete, false);
    assert.equal(result.costUsd, null);
    assert.deepEqual(book.settlements, [['held-1', null]]);
  }
});

test('separate repository instances bound concurrent provider calls with durable reservations', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-security-budget-'));
  const repositories = [
    new Repository(join(directory, 'audit.sqlite'), []),
    new Repository(join(directory, 'audit.sqlite'), []),
  ];
  let calls = 0;
  try {
    const results = await Promise.all(
      Array.from({ length: 12 }, (_, index) => {
        const repo = repositories[index % 2];
        return prepareTip(
          input,
          { ...config, searchEnabled: false, monthlyBudgetUsd: 0.06 },
          {
            reserve: (amount) => repo.reserveAi(amount, 0.06),
            settle: (id, cost) => repo.settleAi(id, cost),
          },
          {
            fetch: async () => {
              calls++;
              // Unknown cost must retain both reservations after these mocked failures.
              return new Response('{"error":{"message":"unavailable"}}', { status: 503 });
            },
          },
        );
      }),
    );
    assert.equal(calls, 2);
    assert.equal(results.filter((result) => result.attempted).length, 2);
    assert.equal(await repositories[0].aiSpent(), 0.06);
    assert.equal(await repositories[1].reserveAi(0.03, 0.06), null);
  } finally {
    await Promise.all(repositories.map((repo) => repo.close()));
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-security-budget-'));
    await rm(resolved, { recursive: true, force: true });
  }
});
