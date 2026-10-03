import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { Repository } from './repository.ts';
import { reconcileExtraction, WagzService } from './service.ts';
import type { Config } from './config.ts';
import type { EventCandidate, EventDraft, FetchResult } from '../shared/types.ts';
import { fetchSource, sources } from './ingestion/index.ts';
import { readSourcePage, SourceDeadlineError } from './ingestion/reader.ts';
import { createHash } from 'node:crypto';

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

test('AI enrichment preserves deterministic identity, exact facts and discovery across title formatting', () => {
  const discovery = {
    audiences: ['students'] as const,
    audienceEvidence: [
      {
        audience: 'students' as const,
        reason: 'Izvorni poziv studentima.',
        sourceUrl: candidate.sourceUrl,
      },
    ],
    prominence: null,
    free: false,
  };
  const original: EventCandidate = {
    ...candidate,
    title: 'GRINTALO /predstava/',
    category: 'other',
    description: 'Kratak činjenični opis.',
    discovery: { ...discovery, audiences: [...discovery.audiences] },
  };
  const ai: EventCandidate = {
    ...candidate,
    externalId: 'ai:duplicate',
    title: 'Grintalo',
    startsAt: '2099-10-10',
    venue: 'AI druga dvorana',
    address: 'Ulica 1',
    price: 'Besplatno',
    endsAt: '2099-10-10T22:00:00+02:00',
    category: 'theatre',
    description: 'Ne prepisuj AI opis.',
    status: 'cancelled',
  };
  const result = reconcileExtraction([original], [ai], {
    url: candidate.sourceUrl,
    text: 'Grintalo 2099-10-10 u 20:00. Ulica 1. Besplatan ulaz.',
  });
  assert.equal(result.events.length, 1);
  assert.equal(result.events[0].externalId, original.externalId);
  assert.equal(result.events[0].title, original.title);
  assert.equal(result.events[0].startsAt, original.startsAt);
  assert.equal(result.events[0].venue, original.venue);
  assert.equal(result.events[0].status, original.status);
  assert.equal(result.events[0].description, original.description);
  assert.equal(result.events[0].address, 'Ulica 1');
  assert.equal(result.events[0].price, 'Besplatno');
  assert.equal(result.events[0].category, 'theatre');
  assert.deepEqual(
    result.events[0].discovery?.audienceEvidence,
    original.discovery?.audienceEvidence,
  );
  assert.equal(result.events[0].discovery?.free, true);
  assert.equal(original.price, null, 'the fetch result must remain unchanged');
});

test('same-page date-prefix and expanded source titles merge without upgrading unknown starts', () => {
  for (const [structured, extracted] of [
    [
      '7. i 8.10. DOVIK 2026: DAN OTVORENIH VRATA I DAN KARIJERA',
      'DOVIK 2026: Dan otvorenih vrata i dan karijera',
    ],
    ['23.-25.10. GLAZBENA TRIBINA 2026', 'GLAZBENA TRIBINA HRVATSKOG DRUŠTVA SKLADATELJA'],
    ['HeadOnEast festival, Osijek', 'HeadOnEast'],
    ['Green Matrix Summit, Osijek', 'Green Matrix Summit'],
  ]) {
    const original = { ...candidate, title: structured, startsAt: '2099-10-10' };
    const ai = {
      ...candidate,
      externalId: 'ai:one',
      title: extracted,
      startsAt: '2099-10-10T00:00:00+02:00',
    };
    const result = reconcileExtraction([original], [ai], {
      url: candidate.sourceUrl,
      text: `${structured}. ${extracted}. 2099-10-10.`,
    });
    assert.equal(result.events.length, 1, structured);
    assert.equal(result.events[0].externalId, original.externalId, structured);
    assert.equal(result.events[0].startsAt, '2099-10-10', structured);
  }
});

test('AI cannot collapse two performances or add a conflicting invented time', () => {
  const later = { ...candidate, externalId: 'later', startsAt: '2099-10-10T22:00:00+02:00' };
  const page = {
    url: candidate.sourceUrl,
    text: 'Koncert na otvorenom 2099-10-10 u 20:00 i 22:00.',
  };
  const vague = reconcileExtraction(
    [candidate, later],
    [{ ...candidate, externalId: 'ai:vague', startsAt: '2099-10-10' }],
    page,
  );
  assert.equal(vague.events.length, 2);
  assert.equal(vague.skipped, 1);
  assert.match(vague.warnings[0], /više izvedbi/);
  const conflicting = reconcileExtraction(
    [candidate],
    [{ ...candidate, externalId: 'ai:conflict', startsAt: '2099-10-10T21:00:00+02:00' }],
    page,
  );
  assert.equal(conflicting.events.length, 1);
  assert.equal(conflicting.skipped, 1);
  assert.equal(conflicting.events[0].startsAt, candidate.startsAt);
  const precise = reconcileExtraction(
    [candidate, later],
    [{ ...later, externalId: 'ai:later', price: '10 EUR' }],
    page,
  );
  assert.equal(precise.events.length, 2);
  assert.equal(precise.events[0].price, null);
  assert.equal(precise.events[1].price, '10 EUR');
});

test('explicit separately dated source occurrences and showtimes remain separate', () => {
  const page = {
    url: candidate.sourceUrl,
    text: 'Koncert na otvorenom 10.10.2099. u 20:00 i 22:00, 7.11.2099. i 5.12.2099.',
  };
  const extras = [
    { ...candidate, externalId: 'ai:later', startsAt: '2099-10-10T22:00:00+02:00' },
    { ...candidate, externalId: 'ai:november', startsAt: '2099-11-07' },
    { ...candidate, externalId: 'ai:december', startsAt: '2099-12-05' },
  ];
  const result = reconcileExtraction([candidate], extras, page);
  assert.equal(result.events.length, 4);
  assert.equal(result.skipped, 0);
  assert.deepEqual(
    result.events.map((event) => event.externalId),
    ['first', 'ai:later', 'ai:november', 'ai:december'],
  );
  const antique = {
    ...candidate,
    title: 'Sajam antikviteta',
    startsAt: '2099-10-10T09:00:00+02:00',
  };
  const november = {
    ...antique,
    externalId: 'ai:november-fair',
    startsAt: '2099-11-07T09:00:00+01:00',
  };
  const repeat = reconcileExtraction([antique], [november], {
    url: candidate.sourceUrl,
    text: 'Sajam antikviteta, od 9 do 14 sati. Sljedeći datumi u 2099. godini: 10.10., 7.11., 5.12.',
  });
  assert.equal(repeat.events.length, 2);
  assert.equal(repeat.skipped, 0);
});

test('conflicting AI alternatives are skipped consistently regardless of order', () => {
  const original = { ...candidate, venue: null };
  const alternatives = [
    { ...candidate, externalId: 'ai:a', venue: 'Dvorana A' },
    { ...candidate, externalId: 'ai:b', venue: 'Dvorana B' },
  ];
  for (const extracted of [alternatives, [...alternatives].reverse()]) {
    const result = reconcileExtraction([original], extracted, {
      url: candidate.sourceUrl,
      text: 'Koncert na otvorenom 2099-10-10. Dvorana A i Dvorana B.',
    });
    assert.equal(result.events.length, 1);
    assert.equal(result.events[0].venue, null);
    assert.equal(result.skipped, 2);
    assert.equal(result.warnings.length, 2);
  }
});

test('unrelated page events stay separate while unconfirmed aliases cannot duplicate a known occurrence', () => {
  const other = {
    ...candidate,
    externalId: 'ai:other',
    title: 'Razgovor o filmu',
    startsAt: '2099-10-11',
  };
  const page = {
    url: candidate.sourceUrl,
    text: 'Koncert na otvorenom 2099-10-10 u 20:00. Razgovor o filmu 2099-10-11.',
  };
  assert.equal(reconcileExtraction([candidate], [other], page).events.length, 2);
  const unclear = { ...other, startsAt: candidate.startsAt };
  const result = reconcileExtraction([candidate], [unclear], page);
  assert.equal(result.events.length, 1);
  assert.equal(result.skipped, 1);
  assert.equal(reconcileExtraction([], [other], page).events.length, 1);
  assert.equal(
    reconcileExtraction([candidate], [{ ...candidate, sourceUrl: 'https://wrong.test' }], page)
      .skipped,
    1,
  );
  const umbrella = { ...candidate, title: 'Glazbena tribina' };
  const performance = {
    ...candidate,
    externalId: 'ai:performance',
    title: 'Glazbena tribina: koncert dua Example',
  };
  const subprogram = reconcileExtraction([umbrella], [performance], {
    url: candidate.sourceUrl,
    text: 'Glazbena tribina: koncert dua Example 2099-10-10 u 20:00.',
  });
  assert.equal(subprogram.events.length, 1);
  assert.equal(subprogram.skipped, 1);
});

test('tip matching requires consistent URL/title/date evidence and does not attach vague repeated titles', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings());
  try {
    const first = await repo.upsert(candidate);
    await repo.upsert({
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
      const tip = await service.submitTip({ note });
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
      { note: 'Koncert na otvorenom 2098', url: candidate.sourceUrl },
    ]) {
      const tip = await service.submitTip(input);
      const prepared = await service.prepareTip(tip.id);
      assert.equal(prepared.matchedEventId, null, input.note);
      assert.equal(prepared.verification, 'unverified');
    }
    const repeat = await repo.upsert({
      ...candidate,
      externalId: 'repeat',
      startsAt: '2099-10-11T20:00:00+02:00',
      sourceUrl: 'https://example.test/repeat',
    });
    const repeatedTip = await service.submitTip({ note: 'Koncert na otvorenom 11/10/2099' });
    assert.equal((await service.prepareTip(repeatedTip.id)).matchedEventId, repeat.id);
    await repo.upsert({
      ...candidate,
      externalId: 'same-day',
      startsAt: '2099-10-11T22:00:00+02:00',
      sourceUrl: 'https://example.test/later',
    });
    const uncertainTime = await service.submitTip({
      note: 'Koncert na otvorenom 11. listopada 2099.',
    });
    assert.equal((await service.prepareTip(uncertainTime.id)).matchedEventId, null);
  } finally {
    await repo.close();
  }
});

test('a source link that is no longer supported is cleared instead of surviving an AI preparation', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings());
  try {
    const original = await repo.upsert(candidate);
    const tip = await service.submitTip({ note: 'Koncert na otvorenom 2099-10-10' });
    assert.equal((await service.prepareTip(tip.id)).matchedEventId, original.id);
    await repo.editEvent(original.id, undefined, { title: 'Ispravljen sasvim drugi naslov' });
    const prepared = await service.prepareTip(tip.id);
    assert.equal(prepared.matchedEventId, null);
    assert.equal(prepared.verification, 'unverified');
    assert.equal((await repo.event(original.id))?.title, 'Ispravljen sasvim drugi naslov');
  } finally {
    await repo.close();
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
    assert.equal(await repo.aiSpent(), 0.001);
    assert.equal((await repo.runs()).length, 2);
    for (const run of await repo.runs()) {
      assert.equal(run.status, 'partial');
      assert.equal(run.imported, 0);
      assert.match(run.warnings.join(' '), /Izvor ne navodi potpune datume/);
    }
  } finally {
    await repo.close();
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
    assert.equal((await repo.events()).length, 1);
    for (const run of await repo.runs()) {
      assert.equal(run.status, 'partial');
      assert.match(run.warnings.join(' '), /Odbačeno.*1/);
    }
    assert.ok((await repo.sourceHealth())[0].lastSuccessAt);
  } finally {
    await repo.close();
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
    const tip = await service.submitTip({ note: 'Čuo sam da je uskoro neki koncert.' });
    await service.prepareTip(tip.id);
    await service.prepareTip(tip.id);
    assert.equal(calls, 1);
    config.ai.searchEnabled = true;
    const refreshed = await service.prepareTip(tip.id);
    assert.equal(calls, 3);
    assert.deepEqual(searches, [false, true, false]);
    assert.match(refreshed.reason, /Provjera 3/);
    config.ai.lookupModel = 'google/custom-lookup';
    await service.prepareTip(tip.id);
    assert.equal(calls, 5, 'changing the lookup model invalidates the completed result');
  } finally {
    await repo.close();
  }
});

test('paid preparation failures retry, completed uncertainty caches, and explicit refresh calls the provider again', async (context) => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings(true));
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return calls === 1
      ? completion('malformed JSON payload')
      : completion({ classification: 'uncertain', draft: null, reason: `Provjera ${calls}.` });
  });
  try {
    const tip = await service.submitTip({ note: 'Čuo sam za neki novi koncert.' });
    assert.match((await service.prepareTip(tip.id)).reason, /nije prošao provjeru/);
    assert.match((await service.prepareTip(tip.id)).reason, /Provjera 2/);
    assert.equal(calls, 2);
    assert.match((await service.prepareTip(tip.id)).reason, /Provjera 2/);
    assert.equal(calls, 2);
    assert.match((await service.prepareTip(tip.id, true)).reason, /Provjera 3/);
    assert.equal(calls, 3);
    assert.equal(await repo.aiSpent(), 0.003);
  } finally {
    await repo.close();
  }
});

test('old paid failure cache entries are invalidated and irrelevant tips archive recoverably', async (context) => {
  const repo = new Repository(':memory:', [source]);
  const config = settings(true);
  const service = new WagzService(repo, config);
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return completion({
      classification: 'spam',
      draft: null,
      reason: 'Sadržaj nema vezu s događajem.',
    });
  });
  try {
    const tip = await service.submitTip({ note: 'kinder jajae' });
    const oldKey = createHash('sha256')
      .update(
        JSON.stringify({
          note: tip.note,
          url: tip.url,
          model: config.ai.model,
          searchEnabled: config.ai.searchEnabled,
          day: new Date().toISOString().slice(0, 10),
        }),
      )
      .digest('hex');
    await repo.cache(`tip:${oldKey}`, {
      attempted: true,
      costUsd: 0.001,
      classification: 'uncertain',
      draft: null,
      evidenceUrls: [],
      reason: 'Old broken JSON failure.',
    });
    const prepared = await service.prepareTip(tip.id);
    assert.equal(calls, 1);
    assert.equal(prepared.status, 'archived');
    assert.equal(prepared.note, tip.note);
    assert.equal((await service.updateTip(tip.id, 'restore')).status, 'inbox');
  } finally {
    await repo.close();
  }
});

test('accepting an unchanged source match preserves source facts, discovery and automatic updates', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings());
  try {
    const original = await repo.upsert({
      ...candidate,
      discovery: {
        audiences: ['students'],
        audienceEvidence: [
          { audience: 'students', reason: 'Poziv studentima.', sourceUrl: candidate.sourceUrl },
        ],
        prominence: null,
        free: true,
      },
      price: 'Besplatno',
    });
    const tip = await service.submitTip({ note: 'Koncert na otvorenom 2099-10-10' });
    const prepared = await service.prepareTip(tip.id);
    const accepted = await service.updateTip(tip.id, 'accept', prepared.draft);
    assert.equal(accepted.matchedEventId, original.id);
    assert.deepEqual(await repo.event(original.id), original);
    assert.equal((await repo.events()).length, 1);
    const refreshed = await repo.upsert({ ...candidate, venue: 'Ispravljena dvorana' });
    assert.equal(refreshed.venue, 'Ispravljena dvorana');
    assert.equal(refreshed.manuallyEdited, false);
  } finally {
    await repo.close();
  }
});

test('a historical draft can be saved but cannot be accepted as an upcoming published event', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings());
  try {
    const tip = await service.submitTip({ note: 'Koncert iz prošle godine.' });
    const { sourceId: _sourceId, externalId: _externalId, ...draft } = candidate;
    const historical = { ...draft, startsAt: '2020-10-10T20:00:00+02:00' };
    const saved = await service.updateTip(tip.id, 'save', historical);
    assert.equal(saved.draft?.startsAt, historical.startsAt);
    await assert.rejects(service.updateTip(tip.id, 'accept'), /već završio/);
    assert.equal((await repo.tip(tip.id))?.status, 'draft');
    assert.deepEqual(await repo.events(), []);
  } finally {
    await repo.close();
  }
});

test('known source tip text reaches strict AI preparation, changed content invalidates cache, and refresh bypasses it', async (context) => {
  const repo = new Repository(':memory:', [source]);
  const config = settings(true);
  config.ai.searchEnabled = true;
  let calls = 0,
    text = 'Koncert na otvorenom 2099-10-10, 20:00, Dvorana u Osijeku.';
  const forced: boolean[] = [];
  context.mock.method(globalThis, 'fetch', async (_request: unknown, init: RequestInit) => {
    calls++;
    const payload = JSON.parse(String(init.body));
    assert.deepEqual(payload.tools, []);
    assert.equal(JSON.parse(payload.messages[1].content).sourceText, text);
    const {
      sourceId: _sourceId,
      externalId: _externalId,
      sourceUrl: _sourceUrl,
      ...fields
    } = candidate;
    return completion({
      classification: 'plausible',
      draft: { ...fields, dateEvidence: '2099-10-10, 20:00' },
      reason: 'Nacrt iz izvora.',
    });
  });
  const service = new WagzService(repo, config, undefined, async (_url, options) => {
    forced.push(options?.force ?? false);
    return { text };
  });
  try {
    const tip = await service.submitTip({
      note: 'Koncert na otvorenom',
      url: 'https://kulturni-centar.hr/novi-koncert',
    });
    assert.equal((await service.prepareTip(tip.id)).draft?.startsAt, candidate.startsAt);
    await service.prepareTip(tip.id);
    assert.equal(calls, 1);
    text += ' Dopuna iz izvora.';
    await service.prepareTip(tip.id);
    assert.equal(calls, 2);
    await service.prepareTip(tip.id, true);
    assert.equal(calls, 3);
    assert.deepEqual(forced, [false, false, false, true]);
  } finally {
    await repo.close();
  }
});

test('a failed submitted source read does not search for a replacement event or cache the failed lookup', async (context) => {
  const repo = new Repository(':memory:', [source]);
  const config = settings(true);
  config.ai.searchEnabled = true;
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async (_request: unknown, init: RequestInit) => {
    calls++;
    const payload = JSON.parse(String(init.body));
    assert.deepEqual(payload.tools, []);
    return completion({ classification: 'uncertain', draft: null, reason: 'Nedostaje izvor.' });
  });
  const service = new WagzService(repo, config, undefined, async () => ({
    reason: 'Sadržaj poveznice nije dohvaćen.',
  }));
  try {
    const tip = await service.submitTip({
      note: 'Koncert na otvorenom',
      url: 'https://kulturni-centar.hr/ne-dostupno',
    });
    const prepared = await service.prepareTip(tip.id);
    assert.equal(prepared.draft, null);
    assert.match(prepared.reason, /nije dohvaćen/);
    await service.prepareTip(tip.id);
    assert.equal(calls, 2);
  } finally {
    await repo.close();
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
    await repo.close();
  }
});

test('collection enriches one persistent deterministic event and reuses validated AI cache', async (context) => {
  const repo = new Repository(':memory:', [source]);
  let calls = 0;
  const original: EventCandidate = { ...candidate, title: 'GRINTALO /predstava/', venue: null };
  const {
    sourceId: _sourceId,
    sourceUrl: _sourceUrl,
    externalId: _externalId,
    ...fields
  } = candidate;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return completion({
      events: [
        {
          ...fields,
          title: 'Grintalo',
          startsAt: '2099-10-10',
          price: 'Besplatno',
          dateEvidence: '2099-10-10',
        },
      ],
      reason: 'Izdvojena najava.',
    });
  });
  const service = new WagzService(repo, settings(true), async () => ({
    events: [original],
    discovered: 1,
    skipped: 0,
    pagesFetched: 1,
    warnings: [],
    extractionPages: [
      {
        url: candidate.sourceUrl,
        text: 'GRINTALO /predstava/ 2099-10-10 u 20:00. Dvorana. Ulaz je besplatan.',
      },
    ],
  }));
  try {
    await service.collect();
    const first = (await repo.events())[0];
    assert.equal(first.title, original.title);
    assert.equal(first.venue, 'Dvorana');
    assert.equal(first.price, 'Besplatno');
    assert.equal(first.startsAt, original.startsAt);
    assert.equal(first.publication, 'published');
    await service.collect();
    const events = await repo.events();
    assert.equal(events.length, 1);
    assert.equal(events[0].id, first.id);
    assert.equal(calls, 1);
    assert.ok((await repo.runs()).every((run) => run.imported === 1 && run.skipped === 0));
  } finally {
    await repo.close();
  }
});

test('a database lease prevents two service instances from collecting concurrently and is released', async () => {
  const repo = new Repository(':memory:', [source]);
  let enter!: () => void, finish!: () => void;
  const entered = new Promise<void>((resolve) => {
    enter = resolve;
  });
  const gate = new Promise<void>((resolve) => {
    finish = resolve;
  });
  const first = new WagzService(repo, settings(), async () => {
    enter();
    await gate;
    return { events: [], discovered: 0, skipped: 0, pagesFetched: 0, warnings: [] };
  });
  let secondCalls = 0;
  const second = new WagzService(repo, settings(), async () => {
    secondCalls++;
    return { events: [], discovered: 0, skipped: 0, pagesFetched: 0, warnings: [] };
  });
  const running = first.collect();
  try {
    await entered;
    assert.equal(await second.collect(), false);
    assert.equal(secondCalls, 0);
    assert.equal(second.collecting, false);
    finish();
    assert.equal(await running, true);
    assert.equal(await second.collect(), true);
    assert.equal(secondCalls, 1);
  } finally {
    finish();
    await running;
    await repo.close();
  }
});

test('bounded collection saves gathered events, defers AI and later sources, and releases its lease', async (context) => {
  const laterSource = { ...source, id: 'later' };
  const repo = new Repository(':memory:', [source, laterSource]);
  const started = Date.now();
  let clock = started;
  context.mock.method(Date, 'now', () => clock);
  let aiCalls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    aiCalls++;
    throw new Error('No paid requests may be sent by this test.');
  });
  const fetched: string[] = [];
  const service = new WagzService(repo, settings(true), async (id, options) => {
    fetched.push(id);
    assert.equal(options?.force, true);
    assert.equal(options?.deadlineMs, started + 105_000);
    // Even an overrun from a custom fetcher must not start more work afterwards.
    clock = started + 225_000;
    return {
      events: [candidate],
      discovered: 2,
      skipped: 1,
      pagesFetched: 2,
      warnings: ['Preostala najava čeka sljedeće pokretanje.'],
      extractionPages: [{ url: candidate.sourceUrl, text: 'Koncert 2099-10-10.' }],
    };
  });
  try {
    assert.equal(await service.collect(true, 240_000), true);
    assert.deepEqual(fetched, [source.id]);
    assert.equal(aiCalls, 0);
    assert.equal(await repo.aiSpent(), 0);
    assert.equal((await repo.events()).length, 1);
    const runs = await repo.runs();
    assert.equal(runs.length, 2);
    assert.ok(runs.every((run) => run.status === 'partial' && run.finishedAt));
    assert.equal(runs.find((run) => run.sourceId === source.id)?.imported, 1);
    assert.match(
      runs.find((run) => run.sourceId === source.id)!.warnings.join(' '),
      /AI obrada odgođena/,
    );
    assert.match(
      runs.find((run) => run.sourceId === laterSource.id)!.warnings.join(' '),
      /izvor čeka/,
    );
    assert.equal(await repo.isLeaseActive('collection'), false);
    assert.equal(service.collecting, false);
  } finally {
    await repo.close();
  }
});

test('bounded collection gives all seven sources a fair remaining share after a slow source', async (context) => {
  const repo = new Repository(':memory:', sources);
  const started = Date.now();
  let clock = started;
  context.mock.method(Date, 'now', () => clock);
  let aiCalls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    aiCalls++;
    throw new Error('No AI call may take time reserved for later sources.');
  });
  const fetched: Array<{ id: string; deadline: number; started: number }> = [];
  const service = new WagzService(repo, settings(true), async (id, options) => {
    const deadline = options!.deadlineMs!;
    fetched.push({ id, deadline, started: clock });
    // The first calendar is quick; each later source consumes its fetch share.
    clock = id === 'tz-osijek' ? clock + 5000 : deadline;
    return {
      events: [{ ...candidate, sourceId: id, title: `${candidate.title} ${id}` }],
      discovered: 1,
      skipped: 0,
      pagesFetched: 1,
      warnings: [],
      extractionPages:
        id === 'tz-osijek' ? [] : [{ url: candidate.sourceUrl, text: 'Koncert 2099-10-10.' }],
    };
  });
  try {
    assert.equal(await service.collect(false, 240_000), true);
    assert.deepEqual(
      fetched.map((item) => item.id),
      ['tz-osijek', 'kc-osijek', 'tz-obz', 'gisko', 'hnk-osijek', 'coreevent-osijek', 'dkolektiv'],
    );
    for (const [index, item] of fetched.entries()) {
      assert.ok(item.deadline > item.started, `${item.id} retains time to fetch`);
      assert.equal(
        item.deadline,
        item.started + (started + 240_000 - item.started) / (fetched.length - index) - 15_000,
      );
      if (index > 0) assert.ok(item.deadline > fetched[index - 1].deadline);
    }
    assert.equal(fetched.at(-1)!.deadline, started + 225_000);
    assert.equal(aiCalls, 0);
    assert.equal((await repo.events()).length, 7);
    assert.ok((await repo.runs()).every((run) => run.imported === 1 && run.finishedAt));
    assert.equal(await repo.isLeaseActive('collection'), false);
  } finally {
    await repo.close();
  }
});

test('source deadline returns already parsed details without fetching remaining pages', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-deadline-test-'));
  let clock = Date.now() + 60_000;
  const deadlineMs = clock + 60_000;
  context.mock.method(Date, 'now', () => clock);
  const listingUrl = sources.find((item) => item.id === 'kc-osijek')!.url;
  const row = (slug: string) =>
    `<div class="datatable__item"><span class="pattern--date">05/10/99 - 05/10/99 @ 20:00</span><h4><a href="/dogadjanja/${slug}">Koncert ${slug}</a></h4></div>`;
  const calls: string[] = [];
  const mockFetch: typeof fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url === `https://r.jina.ai/${listingUrl}`) {
      clock += 3100;
      return new Response(`<html><body>${row('first')}${row('second')}</body></html>`);
    }
    assert.match(url, /\/dogadjanja\/first$/);
    clock = deadlineMs;
    return new Response(
      '<html><body><h1 class="news-item__title">Koncert first</h1><div class="news-item__content"><span class="pattern--date">05/10/99</span><span class="pattern--time">20:00</span><article class="article"><p>Koncert u Dvorani Franjo Krežma. Ulaz je slobodan.</p></article></div></body></html>',
    );
  };
  try {
    const result = await fetchSource('kc-osijek', {
      force: true,
      now: new Date('2099-10-03T10:00:00Z'),
      cacheDir: directory,
      deadlineMs,
      fetch: mockFetch,
    });
    assert.equal(calls.length, 2);
    assert.equal(result.events.length, 1);
    assert.equal(result.pagesFetched, 2);
    assert.equal(result.discovered, 2);
    assert.equal(result.skipped, 1);
    assert.match(result.warnings.join(' '), /vremensko ograničenje.*1 najava/);
    await assert.rejects(
      readSourcePage(listingUrl, { cacheDir: directory, deadlineMs, fetch: mockFetch }),
      SourceDeadlineError,
    );
    assert.equal(calls.length, 2);
  } finally {
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-deadline-test-'));
    await rm(resolved, { recursive: true, force: true });
  }
});

test('background AI respects operator revisions even with identical timestamps and restored status', async (context) => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, settings(true));
  const stamp = new Date().toISOString();
  context.mock.timers.enable({ apis: ['Date'], now: Date.parse(stamp) });
  const { sourceId: _sourceId, externalId: _externalId, ...draft } = candidate;
  let finish!: () => void;
  try {
    for (const action of ['archive', 'reject', 'save', 'accept', 'archive-restore']) {
      let enter!: () => void;
      const entered = new Promise<void>((resolve) => {
        enter = resolve;
      });
      const gate = new Promise<void>((resolve) => {
        finish = resolve;
      });
      const fetchMock = context.mock.method(globalThis, 'fetch', async () => {
        enter();
        await gate;
        const { sourceUrl: _sourceUrl, ...fields } = draft;
        return completion({
          classification: 'plausible',
          draft: { ...fields, dateEvidence: '2099-10-10' },
          reason: 'AI prepared this draft before the operator intervened.',
        });
      });
      const tip = await service.submitTip({
        note: `Novi koncert ${action} 2099-10-10`,
        url: `${candidate.sourceUrl}/${action}`,
      });
      const preparing = service.prepareTip(tip.id);
      try {
        await entered;
        const manual: EventDraft = { ...draft, sourceUrl: tip.url, title: `Operator ${action}` };
        let edited = await service.updateTip(
          tip.id,
          action === 'archive-restore' ? 'archive' : action,
          manual,
        );
        if (action === 'archive-restore') edited = await service.updateTip(tip.id, 'restore');
        assert.equal(edited.updatedAt, tip.updatedAt);
        assert.ok(edited.revision! > tip.revision!);
        finish();
        const prepared = await preparing;
        assert.deepEqual(prepared, edited, action);
        assert.deepEqual(await repo.tip(tip.id), edited, action);
        assert.equal(await repo.isLeaseActive(`tip:${tip.id}`), false);
      } finally {
        finish();
        await preparing;
        fetchMock.mock.restore();
      }
    }
  } finally {
    finish?.();
    await repo.close();
  }
});

test('tip database lease prevents duplicate AI charges across service instances and permits a cached retry', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-tip-lease-test-'));
  const databasePath = join(directory, 'test.sqlite');
  const repo = new Repository(databasePath, [source]);
  const otherRepo = new Repository(databasePath, [source]);
  const first = new WagzService(repo, settings(true));
  const second = new WagzService(otherRepo, settings(true));
  let enter!: () => void, finish!: () => void;
  const entered = new Promise<void>((resolve) => {
    enter = resolve;
  });
  const gate = new Promise<void>((resolve) => {
    finish = resolve;
  });
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    enter();
    await gate;
    return completion({
      classification: 'uncertain',
      draft: null,
      reason: 'Potrebna je provjera.',
    });
  });
  const tip = await first.submitTip({ note: 'Čuo sam za novi koncert.' });
  const preparing = first.prepareTip(tip.id);
  try {
    await entered;
    assert.equal(await repo.isLeaseActive(`tip:${tip.id}`), true);
    const concurrent = await second.prepareTip(tip.id);
    assert.equal(concurrent.revision, tip.revision);
    assert.equal(calls, 1);
    finish();
    const prepared = await preparing;
    assert.equal(await repo.isLeaseActive(`tip:${tip.id}`), false);
    assert.equal((await second.prepareTip(tip.id)).reason, prepared.reason);
    assert.equal(calls, 1);
    assert.equal(await repo.aiSpent(), 0.001);
  } finally {
    finish();
    await preparing;
    await Promise.all([repo.close(), otherRepo.close()]);
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-tip-lease-test-'));
    await rm(resolved, { recursive: true, force: true });
  }
});
