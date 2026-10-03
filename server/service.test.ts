import test from 'node:test';
import assert from 'node:assert/strict';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';
import type { Config } from './config.ts';
import type { EventCandidate, FetchResult } from '../shared/types.ts';

const source = {
  id: 'test',
  name: 'Test source',
  url: 'https://example.test/',
  description: '',
  enabled: true,
};
const candidate: EventCandidate = {
  sourceId: 'test',
  externalId: 'first',
  sourceUrl: 'https://example.test/first',
  title: 'Koncert na otvorenom',
  description: '',
  startsAt: '2099-10-10T20:00:00+02:00',
  endsAt: null,
  venue: 'Dvorana',
  address: null,
  city: 'Osijek',
  category: 'music',
  price: null,
  status: 'scheduled',
};
const settings = (enabled = false): Config => ({
  host: '127.0.0.1',
  port: 3000,
  databasePath: ':memory:',
  adminKey: 'test',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 360,
  ai: {
    apiKey: enabled ? 'mock-key-only' : '',
    model: 'google/gemini-2.5-flash-lite',
    monthlyBudgetUsd: 1,
    searchEnabled: false,
  },
});
const completion = (content: unknown) =>
  new Response(
    JSON.stringify({
      choices: [
        { finish_reason: 'stop', message: { role: 'assistant', content: JSON.stringify(content) } },
      ],
      usage: { cost: 0.001 },
    }),
    { status: 200 },
  );

test('tip matching requires consistent URL/title/date evidence and does not attach vague repeated titles', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings());
  try {
    const first = repo.upsert(candidate);
    repo.upsert({
      ...candidate,
      externalId: 'second',
      sourceUrl: 'https://example.test/second',
      title: 'Velika kazališna predstava',
    });
    for (const note of [
      'Koncert na otvorenom 2099-10-10',
      'Koncert na otvorenom 10. 10. 2099.',
      'Koncert na otvorenom 10. listopada 2099.',
    ]) {
      const tip = service.submitTip({ note });
      const prepared = await service.prepareTip(tip.id);
      assert.equal(prepared.matchedEventId, first.id, note);
      assert.equal(prepared.verification, 'source_match');
    }
    for (const input of [
      { note: 'Velika kazališna predstava 2099-10-10', url: candidate.sourceUrl },
      { note: 'Koncert na otvorenom 2099-11-10', url: candidate.sourceUrl },
      { note: 'Koncert na otvorenom 11. listopada 2099.', url: candidate.sourceUrl },
      { note: 'Koncert na otvorenom 31. veljače 2099.', url: candidate.sourceUrl },
      { note: 'Koncert na otvorenom uskoro' },
      { note: 'Koncert na otvorenom 10. listopada' },
    ]) {
      const tip = service.submitTip(input);
      const prepared = await service.prepareTip(tip.id);
      assert.equal(prepared.matchedEventId, null, input.note);
      assert.equal(prepared.verification, 'unverified');
    }
    const repeat = repo.upsert({
      ...candidate,
      externalId: 'repeat',
      startsAt: '2099-10-11T20:00:00+02:00',
      sourceUrl: 'https://example.test/repeat',
    });
    const repeatedTip = service.submitTip({ note: 'Koncert na otvorenom 11/10/2099' });
    assert.equal((await service.prepareTip(repeatedTip.id)).matchedEventId, repeat.id);
    repo.upsert({
      ...candidate,
      externalId: 'same-day',
      startsAt: '2099-10-11T22:00:00+02:00',
      sourceUrl: 'https://example.test/later',
    });
    const uncertainTime = service.submitTip({ note: 'Koncert na otvorenom 11. listopada 2099.' });
    assert.equal((await service.prepareTip(uncertainTime.id)).matchedEventId, null);
  } finally {
    repo.close();
  }
});

test('a source link that is no longer supported is cleared instead of surviving an AI preparation', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings());
  try {
    const original = repo.upsert(candidate);
    const tip = service.submitTip({ note: 'Koncert na otvorenom 2099-10-10' });
    assert.equal((await service.prepareTip(tip.id)).matchedEventId, original.id);
    repo.editEvent(original.id, undefined, { title: 'Ispravljen sasvim drugi naslov' });
    const prepared = await service.prepareTip(tip.id);
    assert.equal(prepared.matchedEventId, null);
    assert.equal(prepared.verification, 'unverified');
    assert.equal(repo.event(original.id)?.title, 'Ispravljen sasvim drugi naslov');
  } finally {
    repo.close();
  }
});

test('unchanged successful empty extraction is cached and still reports its missing-data reason', async (context) => {
  const repo = new Repository(':memory:', [source]);
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return completion({ events: [], reason: 'Izvor ne navodi potpune datume događaja.' });
  });
  const fetcher = async (): Promise<FetchResult> => ({
    events: [],
    discovered: 0,
    skipped: 0,
    pagesFetched: 1,
    warnings: [],
    extractionPages: [{ url: source.url, text: 'Najava programa bez pojedinačnih datuma.' }],
  });
  const service = new WagzService(repo, settings(true), fetcher);
  try {
    await service.collect();
    await service.collect();
    assert.equal(calls, 1);
    assert.equal(repo.aiSpent(), 0.001);
    assert.equal(repo.runs().length, 2);
    for (const run of repo.runs()) {
      assert.equal(run.status, 'partial');
      assert.equal(run.imported, 0);
      assert.match(run.warnings.join(' '), /Izvor ne navodi potpune datume/);
    }
  } finally {
    repo.close();
  }
});

test('cached partial extraction retains its rejected-row warning on subsequent runs', async (context) => {
  const repo = new Repository(':memory:', [source]);
  let calls = 0;
  const {
    sourceId: _sourceId,
    sourceUrl: _sourceUrl,
    externalId: _externalId,
    ...fields
  } = candidate;
  const valid = { ...fields, dateEvidence: '2099-10-10' };
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return completion({
      events: [valid, { ...valid, startsAt: '2099-02-30' }],
      reason: 'Djelomično izdvojeni podaci.',
    });
  });
  const service = new WagzService(repo, settings(true), async () => ({
    events: [],
    discovered: 2,
    skipped: 0,
    pagesFetched: 1,
    warnings: [],
    extractionPages: [
      { url: source.url, text: 'Koncert na otvorenom 2099-10-10, Dvorana, 20:00.' },
    ],
  }));
  try {
    await service.collect();
    await service.collect();
    assert.equal(calls, 1);
    assert.equal(repo.events().length, 1);
    for (const run of repo.runs()) {
      assert.equal(run.status, 'partial');
      assert.match(run.warnings.join(' '), /Odbačeno.*1/);
    }
    assert.ok(repo.sourceHealth()[0].lastSuccessAt);
  } finally {
    repo.close();
  }
});

test('tip cache changes when web search is enabled', async (context) => {
  const repo = new Repository(':memory:', [source]);
  const config = settings(true);
  let calls = 0;
  const searches: boolean[] = [];
  context.mock.method(globalThis, 'fetch', async (_request: unknown, init: RequestInit) => {
    calls++;
    const body = JSON.parse(String(init.body));
    searches.push(
      body.tools.some((tool: { type: string }) => tool.type === 'openrouter:web_search'),
    );
    return completion({ classification: 'uncertain', draft: null, reason: `Provjera ${calls}.` });
  });
  const service = new WagzService(repo, config);
  try {
    const tip = service.submitTip({ note: 'Čuo sam da je uskoro neki koncert.' });
    await service.prepareTip(tip.id);
    await service.prepareTip(tip.id);
    assert.equal(calls, 1);
    config.ai.searchEnabled = true;
    const refreshed = await service.prepareTip(tip.id);
    assert.equal(calls, 2);
    assert.deepEqual(searches, [false, true]);
    assert.match(refreshed.reason, /Provjera 2/);
  } finally {
    repo.close();
  }
});

test('scheduled collection uses the reader cache while explicit refresh requests bypass it', async () => {
  const repo = new Repository(':memory:', [source]);
  const seen: boolean[] = [];
  const service = new WagzService(repo, settings(), async (_id, options) => {
    seen.push(options?.force ?? false);
    return { events: [], discovered: 0, skipped: 0, pagesFetched: 1, warnings: [] };
  });
  try {
    await service.collect();
    await service.collect(true);
    assert.deepEqual(seen, [false, true]);
  } finally {
    repo.close();
  }
});
