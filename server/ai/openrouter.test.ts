import assert from 'node:assert/strict';
import test from 'node:test';
import { supportedDays, supportedTime } from './evidence.ts';
import {
  extractEvents,
  prepareTip,
  REQUEST_RESERVATION_USD,
  MAX_EXTRACTION_INPUT_CHARS,
  type AiConfig,
  type AiLedger,
} from './openrouter.ts';

const config: AiConfig = {
  apiKey: 'test-key-never-sent',
  monthlyBudgetUsd: 1,
  searchEnabled: true,
};
const input = {
  note: 'Koncert: 5. listopada 2026., 20:00, Klub Osijek.',
  url: null,
  now: '2026-10-03T10:00:00Z',
};
const page = {
  text: input.note,
  url: 'https://example.test/program',
  sourceId: 'test-source',
  now: input.now,
};
const candidate = {
  title: 'Koncert',
  description: '',
  startsAt: '2026-10-05T20:00:00+02:00',
  endsAt: null,
  venue: 'Klub Osijek',
  address: null,
  city: 'Osijek',
  category: 'music',
  price: null,
  status: 'scheduled',
  dateEvidence: '5. listopada 2026., 20:00',
};
function accounting(available = true) {
  const reservations: number[] = [],
    settlements: Array<[string, number | null]> = [];
  const ledger: AiLedger = {
    reserve: async (amount) => {
      reservations.push(amount);
      return available ? 'reservation-1' : null;
    },
    settle: async (id, amount) => {
      settlements.push([id, amount]);
    },
  };
  return { ledger, reservations, settlements };
}
function response(content: unknown, cost: unknown = 0.002, annotations?: unknown, finish = 'stop') {
  return new Response(
    JSON.stringify({
      choices: [
        {
          finish_reason: finish,
          message: {
            role: 'assistant',
            content: typeof content === 'string' ? content : JSON.stringify(content),
            annotations,
          },
        },
      ],
      usage: { cost },
    }),
    { status: 200 },
  );
}
const mock = (
  run: (request: RequestInfo | URL, init?: RequestInit) => Response | Promise<Response>,
): typeof fetch => run as typeof fetch;
const tip = (draft: unknown = candidate) => ({
  classification: 'plausible',
  draft,
  reason: 'Dojava ima podatke za nacrt.',
});
const extraction = (events: unknown[] = [candidate]) => ({
  events,
  reason: 'Izdvojeni podaci iz izvora.',
});

test('disabled, exhausted and invalid configuration never send requests or settle', async () => {
  for (const disabled of [
    { ...config, apiKey: '' },
    { ...config, monthlyBudgetUsd: 0 },
    { ...config, monthlyBudgetUsd: NaN },
    { ...config, model: 'google/gemini:online' },
  ]) {
    const book = accounting();
    const result = await prepareTip(input, disabled, book.ledger, {
      fetch: mock(() => {
        throw new Error('must not fetch');
      }),
    });
    assert.equal(result.attempted, false);
    assert.equal(result.draft, null);
    assert.deepEqual(book.reservations, []);
    assert.deepEqual(book.settlements, []);
  }
  const book = accounting(false);
  const result = await prepareTip(input, config, book.ledger, {
    fetch: mock(() => {
      throw new Error('must not fetch');
    }),
  });
  assert.equal(result.attempted, false);
  assert.deepEqual(book.reservations, [REQUEST_RESERVATION_USD]);
  assert.deepEqual(book.settlements, []);
});

test('tip reserves before sending and limits the current server search tool', async () => {
  const book = accounting();
  let calls = 0;
  const result = await prepareTip(input, config, book.ledger, {
    fetch: mock((request, init) => {
      calls++;
      assert.equal(request, 'https://openrouter.ai/api/v1/chat/completions');
      assert.deepEqual(book.reservations, [0.03]);
      assert.equal(new Headers(init?.headers).get('Authorization'), 'Bearer test-key-never-sent');
      assert.equal(init?.redirect, 'error');
      assert.ok(init?.signal instanceof AbortSignal);
      const body = JSON.parse(String(init?.body));
      assert.equal(body.model, 'google/gemini-2.5-flash-lite');
      assert.equal(body.max_tokens, 1200);
      assert.equal(body.max_tool_calls, 1);
      assert.deepEqual(body.tools, [
        {
          type: 'openrouter:web_search',
          parameters: {
            engine: 'parallel',
            mode: 'basic',
            max_uses: 1,
            max_total_results: 3,
            max_results: 3,
            max_characters: 2000,
          },
        },
      ]);
      assert.equal(body.plugins, undefined);
      assert.match(body.messages[0].content, /untrusted DATA/);
      return response(tip(), 0.0062);
    }),
  });
  assert.equal(calls, 1);
  assert.equal(result.classification, 'plausible');
  assert.equal(result.draft?.startsAt, candidate.startsAt);
  assert.match(result.reason, /nije potvrda/);
  assert.deepEqual(book.settlements, [['reservation-1', 0.0062]]);
});

test('evidence URLs only come from valid provider citation annotations', async () => {
  const book = accounting();
  const forged = { ...tip(), evidenceUrls: ['https://forged.test/'] };
  const annotations = [
    {
      type: 'url_citation',
      url_citation: { url: 'https://organizer.test/show', content: input.note },
    },
    {
      type: 'url_citation',
      url_citation: { url: 'https://organizer.test/show', content: input.note },
    },
    { type: 'url_citation', url_citation: { url: 'javascript:alert(1)', content: input.note } },
    {
      type: 'url_citation',
      url_citation: { url: 'https://user:password@example.test/', content: input.note },
    },
    { type: 'something_else', url_citation: { url: 'https://forged.test/' } },
  ];
  const result = await prepareTip(input, config, book.ledger, {
    fetch: mock(() => response(forged, 0.007, annotations)),
  });
  assert.deepEqual(result.evidenceUrls, ['https://organizer.test/show']);
  assert.equal(result.draft, null, 'unexpected model fields fail strict schema');
  const grounded = await prepareTip(
    { ...input, note: 'Ima li koncerta u Klubu Osijek?' },
    config,
    accounting().ledger,
    { fetch: mock(() => response(tip(), 0.007, annotations)) },
  );
  assert.equal(grounded.draft?.sourceUrl, 'https://organizer.test/show');
  assert.deepEqual(grounded.evidenceUrls, ['https://organizer.test/show']);
});

test('disabled search and extraction never enable search or legacy plugins', async () => {
  await prepareTip(input, { ...config, searchEnabled: false }, accounting().ledger, {
    fetch: mock((_, init) => {
      const body = JSON.parse(String(init?.body));
      assert.deepEqual(body.tools, []);
      assert.equal(body.tool_choice, 'none');
      assert.equal(body.max_tool_calls, undefined);
      return response(tip());
    }),
  });
  const result = await extractEvents(page, config, accounting().ledger, {
    fetch: mock((_, init) => {
      const body = JSON.parse(String(init?.body));
      assert.deepEqual(body.tools, []);
      assert.equal(body.max_tokens, 2500);
      assert.equal(body.plugins, undefined);
      return response(extraction());
    }),
  });
  assert.equal(result.events.length, 1);
  assert.equal(result.events[0].sourceUrl, page.url);
  assert.equal(result.events[0].sourceId, page.sourceId);
});

test('malformed JSON, provider errors and network failure are explicit and never retried', async () => {
  for (const run of [
    () => response('{not json'),
    () => new Response('not json', { status: 200 }),
    () => new Response(JSON.stringify({ error: { message: 'wrong key' } }), { status: 401 }),
    () =>
      new Response(JSON.stringify({ error: { message: 'bad provider' }, usage: { cost: 0.001 } }), {
        status: 200,
      }),
    () => response(tip(), 0.002, undefined, 'length'),
    () => {
      throw new Error('network error with secret test-key-never-sent');
    },
  ]) {
    const book = accounting();
    let calls = 0;
    const result = await prepareTip(input, config, book.ledger, {
      fetch: mock(() => {
        calls++;
        return run();
      }),
    });
    assert.equal(calls, 1);
    assert.equal(result.attempted, true);
    assert.equal(result.draft, null);
    assert.equal(result.classification, 'uncertain');
    assert.ok(result.reason.length > 20);
    assert.doesNotMatch(result.reason, /test-key-never-sent/);
    assert.equal(book.settlements.length, 1);
    assert.equal(book.settlements[0][1], result.costUsd);
  }
});

test('unknown, negative and nonnumeric usage costs retain reserve; actual overage is recorded', async () => {
  for (const cost of [undefined, null, -1, '0.001', 0, 0.09]) {
    const book = accounting();
    const result = await prepareTip(input, config, book.ledger, {
      fetch: mock(() => response(tip(), cost === undefined ? NaN : cost)),
    });
    const expected = typeof cost === 'number' && Number.isFinite(cost) && cost >= 0 ? cost : null;
    assert.equal(result.costUsd, expected);
    assert.deepEqual(book.settlements, [['reservation-1', expected]]);
  }
});

test('real dates, explicit years, Zagreb DST offsets and end ordering are enforced', async () => {
  const invalid = [
    { startsAt: '2026-02-30' },
    { startsAt: '2026-13-01' },
    { startsAt: '2026-10-05T24:00:00+02:00' },
    { startsAt: '2026-10-05T20:00:00+01:00' },
    { startsAt: '2026-10-05T20:00:00' },
    { startsAt: '2027-10-05T20:00:00+02:00' },
    { dateEvidence: 'A made-up date in 2026' },
    { endsAt: '2026-10-05T19:00:00+02:00' },
    { startsAt: '2026-03-29T02:30:00+01:00' },
  ];
  for (const fields of invalid) {
    const result = await extractEvents(page, config, accounting().ledger, {
      fetch: mock(() => response(extraction([{ ...candidate, ...fields }]))),
    });
    assert.deepEqual(result.events, [], JSON.stringify(fields));
    assert.match(result.reason, /Odbačeno/);
  }
  const result = await extractEvents(page, config, accounting().ledger, {
    fetch: mock(() =>
      response(extraction([{ ...candidate, startsAt: '2026-10-05', venue: null, address: null }])),
    ),
  });
  assert.equal(result.events[0]?.startsAt, '2026-10-05');
  assert.equal(result.events[0]?.venue, null);
});

test('malformed event fields and absent nullable fields never coerce or acquire defaults', async () => {
  for (const fields of [
    { title: 12 },
    { title: '' },
    { description: null },
    { endsAt: false },
    { venue: false },
    { address: {} },
    { city: null },
    { city: 'Zagreb' },
    { category: 'concert' },
    { price: 0 },
    { status: [] },
    { sourceUrl: 'https://forged.test/' },
    { venue: undefined },
  ]) {
    const result = await extractEvents(page, config, accounting().ledger, {
      fetch: mock(() => response(extraction([{ ...candidate, ...fields }]))),
    });
    assert.equal(result.events.length, 0, JSON.stringify(fields));
  }
});

test('same title at two showtimes has distinct stable occurrence IDs and duplicate rows deduplicate', async () => {
  const shows = [
    candidate,
    {
      ...candidate,
      startsAt: '2026-10-05T22:00:00+02:00',
      dateEvidence: '5. listopada 2026., 22:00',
    },
    candidate,
  ];
  const get = () =>
    extractEvents(
      { ...page, text: `${page.text} Druga izvedba: 5. listopada 2026., 22:00.` },
      config,
      accounting().ledger,
      {
        fetch: mock(() => response(extraction(shows))),
      },
    );
  const first = await get(),
    second = await get();
  assert.equal(first.events.length, 2);
  assert.notEqual(first.events[0].externalId, first.events[1].externalId);
  assert.deepEqual(
    first.events.map((row) => row.externalId),
    second.events.map((row) => row.externalId),
  );
});

test('input limits reject without truncation or charging and empty results explain absence', async () => {
  const book = accounting();
  const options = {
    fetch: mock(() => {
      throw new Error('must not fetch');
    }),
  };
  const longTip = await prepareTip(
    { ...input, note: 'x'.repeat(2001) },
    config,
    book.ledger,
    options,
  );
  assert.equal(longTip.attempted, false);
  const longPage = await extractEvents(
    { ...page, text: 'x'.repeat(MAX_EXTRACTION_INPUT_CHARS + 1) },
    config,
    book.ledger,
    options,
  );
  assert.equal(longPage.attempted, false);
  assert.match(longPage.reason, /podijeliti/);
  assert.deepEqual(book.reservations, []);
  const result = await extractEvents(page, config, accounting().ledger, {
    fetch: mock(() => response(extraction([]))),
  });
  assert.deepEqual(result.events, []);
  assert.match(result.reason, /Nije izdvojen/);
});

test('ledger failures fail closed without leaking internal details', async () => {
  const failedReserve: AiLedger = {
    reserve: () => {
      throw new Error('sqlite secret');
    },
    settle: () => {
      throw new Error('must not settle');
    },
  };
  const first = await prepareTip(input, config, failedReserve, {
    fetch: mock(() => {
      throw new Error('must not fetch');
    }),
  });
  assert.equal(first.attempted, false);
  const failedSettle: AiLedger = {
    reserve: () => 'held',
    settle: () => {
      throw new Error('sqlite secret');
    },
  };
  const second = await prepareTip(input, config, failedSettle, {
    fetch: mock(() => response(tip())),
  });
  assert.equal(second.attempted, true);
  assert.equal(second.draft, null);
  assert.match(second.reason, /evidencija/);
  assert.doesNotMatch(second.reason, /sqlite secret/);
});

test('a partial extraction exposes rejected rows and keeps independently valid events', async () => {
  const result = await extractEvents(page, config, accounting().ledger, {
    fetch: mock(() => response(extraction([candidate, { ...candidate, startsAt: '2026-02-30' }]))),
  });
  assert.equal(result.events.length, 1);
  assert.equal(result.complete, false);
  assert.equal(result.rejectedCount, 1);
  assert.match(result.reason, /Odbačeno/);
  const valid = await extractEvents(page, config, accounting().ledger, {
    fetch: mock(() => response(extraction())),
  });
  assert.equal(valid.complete, true);
  assert.equal(valid.rejectedCount, 0);
});

test('one 45-second deadline aborts the request without refunding or retrying', async (context) => {
  context.mock.method(AbortSignal, 'timeout', (milliseconds: number) => {
    assert.equal(milliseconds, 45_000);
    return AbortSignal.abort(new DOMException('Deadline exceeded', 'TimeoutError'));
  });
  const book = accounting();
  let calls = 0;
  const result = await prepareTip(input, config, book.ledger, {
    fetch: mock((_, init) => {
      calls++;
      init?.signal?.throwIfAborted();
      throw new Error('expected timeout');
    }),
  });
  assert.equal(calls, 1);
  assert.equal(result.attempted, true);
  assert.equal(result.draft, null);
  assert.match(result.reason, /45 sekundi/);
  assert.deepEqual(book.settlements, [['reservation-1', null]]);
});

test('single-occurrence identity survives time and venue corrections', async () => {
  const first = await extractEvents(page, config, accounting().ledger, {
    fetch: mock(() => response(extraction())),
  });
  const changed = await extractEvents(
    { ...page, text: page.text.replace('20:00', '21:00') },
    config,
    accounting().ledger,
    {
      fetch: mock(() =>
        response(
          extraction([
            {
              ...candidate,
              startsAt: '2026-10-05T21:00:00+02:00',
              venue: null,
              dateEvidence: '5. listopada 2026., 21:00',
            },
          ]),
        ),
      ),
    },
  );
  assert.equal(first.events[0]?.externalId, changed.events[0]?.externalId);
});

test('a real quote containing only a month and year cannot justify an invented day', async () => {
  for (const quote of ['Advent u Osijeku, prosinac 2026.', 'HeadOnEast — listopad 2026.']) {
    const result = await extractEvents({ ...page, text: quote }, config, accounting().ledger, {
      fetch: mock(() =>
        response(
          extraction([
            { ...candidate, startsAt: '2026-10-01T00:00:00+02:00', dateEvidence: quote },
          ]),
        ),
      ),
    });
    assert.equal(result.events.length, 0);
    assert.equal(result.rejectedCount, 1);
  }
});

test('a supported calendar day with no source time remains date-only', async () => {
  const quote = '26. studenog 2026.';
  const result = await extractEvents({ ...page, text: quote }, config, accounting().ledger, {
    fetch: mock(() =>
      response(
        extraction([{ ...candidate, startsAt: '2026-11-26T00:00:00+01:00', dateEvidence: quote }]),
      ),
    ),
  });
  assert.equal(result.events[0]?.startsAt, '2026-11-26');
});

test('exact ISO timestamp quotes retain their calendar day and clock time', async () => {
  for (const startsAt of ['2026-10-05T20:00:00+02:00', '2026-11-26T09:30:00+01:00']) {
    const quote = `Datum početka iz izvora: ${startsAt}`;
    const result = await extractEvents({ ...page, text: quote }, config, accounting().ledger, {
      fetch: mock(() => response(extraction([{ ...candidate, startsAt, dateEvidence: quote }]))),
    });
    assert.equal(result.events[0]?.startsAt, startsAt, quote);
    assert.equal(result.rejectedCount, 0);
  }
});

test('Croatian numeric dates followed immediately by slash-delimited times are supported', async () => {
  for (const quote of ['Petak, 9.10.2026./20.00 sati/', '9/10/2026 / 20:00.']) {
    const result = await extractEvents({ ...page, text: quote }, config, accounting().ledger, {
      fetch: mock(() =>
        response(
          extraction([
            {
              ...candidate,
              startsAt: '2026-10-09T20:00:00+02:00',
              dateEvidence: quote,
            },
          ]),
        ),
      ),
    });
    assert.equal(result.events[0]?.startsAt, '2026-10-09T20:00:00+02:00', quote);
  }
});

test('Croatian date ranges substantiate only their valid explicit endpoints', () => {
  for (const [quote, expected] of [
    ['26. i 27. studenog 2026.', ['2026-11-26', '2026-11-27']],
    ['od 2. do 4. listopada 2026.', ['2026-10-02', '2026-10-04']],
    ['7. i 8.10.2026.', ['2026-10-07', '2026-10-08']],
    ['23.–25.10.2026.', ['2026-10-23', '2026-10-25']],
    ['30.9.–2.10.2026.', ['2026-09-30', '2026-10-02']],
    ['30. rujna – 2. listopada 2026.', ['2026-09-30', '2026-10-02']],
    ['5. ožujka 2026.', ['2026-03-05']],
    ['29. veljače 2028.', ['2028-02-29']],
    ['29.–30. veljače 2026.', []],
    ['listopad 2026.', []],
    ['5. listopada; godina nije navedena', []],
  ] as Array<[string, string[]]>) {
    assert.deepEqual([...supportedDays(quote)].sort(), expected, quote);
  }
});

test('range endpoints keep their days and drop invented midnight or end-of-day times', async () => {
  const quote = 'Green Matrix Summit: 26. i 27. studenog 2026.';
  const result = await extractEvents({ ...page, text: quote }, config, accounting().ledger, {
    fetch: mock(() =>
      response(
        extraction([
          {
            ...candidate,
            startsAt: '2026-11-26T00:00:00+01:00',
            endsAt: '2026-11-27T23:59:59+01:00',
            dateEvidence: quote,
          },
        ]),
      ),
    ),
  });
  assert.equal(result.events[0]?.startsAt, '2026-11-26');
  assert.equal(result.events[0]?.endsAt, '2026-11-27');
});

test('calendar components, timestamp seconds and offsets never establish an event time', () => {
  for (const [value, quote] of [
    ['2026-10-05T00:00:00+02:00', '2026-10-05T20:00:00+02:00'],
    ['2026-10-05T02:00:00+02:00', '2026-10-05T20:00:00+02:00'],
    ['2026-10-20T20:10:00+02:00', '20.10.2026.'],
    ['2026-10-20T20:10:00+02:00', '20.10. 2026.'],
  ]) {
    assert.equal(supportedTime(value, quote), value.slice(0, 10), quote);
  }
  assert.equal(
    supportedTime('2026-10-05T09:00:00+02:00', '5.10.2026., od 9 do 14 sati'),
    '2026-10-05T09:00:00+02:00',
  );
  assert.equal(
    supportedTime('2026-10-05T20:10:00+02:00', '5.10.2026./20.10 sati/'),
    '2026-10-05T20:10:00+02:00',
  );
  assert.equal(
    supportedTime('2026-10-05T20:00:00+02:00', '5.10.2026., 18:00-20:00'),
    '2026-10-05T20:00:00+02:00',
  );
  assert.equal(
    supportedTime('2026-10-05T20:00:59+02:00', '5.10.2026., 20:00'),
    '2026-10-05T20:00:00+02:00',
  );
});

test('ISO support still requires an exact source quote and an explicit year', async () => {
  for (const [text, dateEvidence] of [
    ['2026-10-05T20:00:00+02:00', '2026-10-05T21:00:00+02:00'],
    ['5. listopada, 20:00', '5. listopada, 20:00'],
    ['listopad 2026., 20:00', 'listopad 2026., 20:00'],
  ]) {
    const result = await extractEvents({ ...page, text }, config, accounting().ledger, {
      fetch: mock(() => response(extraction([{ ...candidate, dateEvidence }]))),
    });
    assert.equal(result.events.length, 0);
    assert.equal(result.rejectedCount, 1);
  }
});
