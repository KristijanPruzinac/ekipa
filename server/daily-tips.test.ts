import test, { type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Repository } from './repository.ts';
import { classificationReply } from './test-support.ts';
import { WagzService } from './service.ts';
import type { Config } from './config.ts';
import type {
  EventCandidate,
  EventDraft,
  FetchResult,
  SourceDefinition,
  WagzEvent,
} from '../shared/types.ts';

// Actual captured Osijek records. Freeze their capture day, never move editions
// into an invented year. All source/provider calls below are injected or mocked.
const fixture = JSON.parse(
  readFileSync(new URL('../scripts/fixtures/review-events.json', import.meta.url), 'utf8'),
) as {
  sources: SourceDefinition[];
  events: WagzEvent[];
};
const record = fixture.events.find((event) => event.title.includes('DOVIK 2026'))!;
const source = fixture.sources.find((item) => item.id === record.sources[0].sourceId)!;
const draft: EventDraft = {
  title: record.title,
  description: record.description,
  startsAt: record.startsAt,
  endsAt: record.endsAt,
  venue: record.venue,
  address: record.address,
  city: record.city,
  category: record.category,
  price: record.price,
  status: record.status,
  sourceUrl: record.sources[0].url,
};
const candidate: EventCandidate = {
  ...draft,
  sourceId: source.id,
  externalId: record.id,
  sourceUrl: draft.sourceUrl!,
};
const evidence = (event: EventDraft = draft) =>
  JSON.stringify({
    title: event.title,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    venue: event.venue,
    city: event.city,
  });
const aiDraft = (event: EventDraft = draft) => {
  const { sourceUrl: _url, ...fields } = event;
  return { ...fields, dateEvidence: evidence(event) };
};
const config = (enabled = true): Config => ({
  host: '127.0.0.1',
  port: 3000,
  databasePath: ':memory:',
  adminKey: 'local-test-only',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 1440,
  ai: {
    apiKey: enabled ? 'mock-not-a-real-key' : '',
    model: 'google/gemini-2.5-flash-lite',
    monthlyBudgetUsd: 1,
    searchEnabled: true,
  },
});
const empty: FetchResult = { events: [], discovered: 0, skipped: 0, pagesFetched: 0, warnings: [] };
const response = (content: unknown, cost = 0.001) =>
  new Response(
    JSON.stringify({
      choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(content) } }],
      usage: { cost },
    }),
    { status: 200 },
  );
const plausible = (event: EventDraft = draft) => ({
  classification: 'plausible',
  draft: aiDraft(event),
  reason: 'Podaci iz najave.',
});
const freeze = (context: TestContext) => {
  context.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-03T10:00:00Z') });
};

test('daily collection imports sources first and archives an already-listed real event without provider calls', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', [source]);
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async (_request: unknown, init?: RequestInit) => {
    // Only the batched source classification may reach the provider; tip handling must not.
    const categorised = classificationReply(init);
    if (categorised) return categorised;
    calls++;
    throw new Error('Network forbidden');
  });
  const service = new WagzService(repo, config(), async () => ({
    ...empty,
    events: [candidate],
    discovered: 1,
  }));
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026 u Osijeku', url: draft.sourceUrl });
    assert.equal(tip.status, 'inbox');
    await service.collect();
    const prepared = (await repo.tip(tip.id))!;
    assert.equal(prepared.status, 'archived');
    assert.match(prepared.reason, /već objavljen/);
    assert.equal(prepared.matchedEventId, (await repo.events())[0].id);
    assert.equal(calls, 0);
    assert.deepEqual(service.lastTipBatch, {
      queued: 1,
      processed: 1,
      drafted: 0,
      archived: 1,
      deferred: 0,
    });
  } finally {
    await repo.close();
  }
});

test('a valid unpublished source match becomes a linked review draft and stays held', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', [source], false);
  const service = new WagzService(repo, config(false), async () => ({
    ...empty,
    events: [candidate],
  }));
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.collect();
    const prepared = (await repo.tip(tip.id))!;
    assert.equal(prepared.status, 'draft');
    assert.equal(prepared.matchedEventId, (await repo.events())[0].id);
    assert.equal((await repo.publicEvents()).length, 0);
    await service.collect();
    assert.equal((await repo.tip(tip.id))!.revision, prepared.revision);
    assert.equal(service.lastTipBatch?.queued, 0);
  } finally {
    await repo.close();
  }
});

test('a sourced real event drafts automatically, requires approval and concurrent approvals cannot duplicate it', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return response(plausible());
  });
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    const one = await service.submitTip({ note: 'DOVIK 2026, dan karijera', url: draft.sourceUrl });
    const two = await service.submitTip({
      note: 'DOVIK 2026, otvorena vrata',
      url: draft.sourceUrl,
    });
    assert.equal(calls, 0);
    await service.collect();
    assert.equal(calls, 2);
    assert.equal((await repo.tip(one.id))?.status, 'draft');
    assert.equal((await repo.tip(one.id))?.draft?.startsAt, draft.startsAt);
    assert.equal((await repo.events()).length, 0, 'automatic checking never publishes');
    const approvals = await Promise.all([
      service.updateTip(one.id, 'accept'),
      service.updateTip(two.id, 'accept'),
    ]);
    assert.equal(approvals[0].matchedEventId, approvals[1].matchedEventId);
    assert.equal((await repo.events()).length, 1);
    assert.equal(await repo.aiSpent(), 0.002);
  } finally {
    await repo.close();
  }
});

test('completed spam, no-event, ended, cancelled and incomplete-location outcomes archive recoverably', async (context) => {
  freeze(context);
  const past = {
    ...draft,
    startsAt: '2026-09-12T20:00:00+02:00',
    endsAt: null,
    title: 'Marko Kutlić – Moram dalje tour',
    venue: 'Dvorana Franjo Krežma',
    sourceUrl: 'https://kulturni-centar.hr/dogadjanja/129-marko-kutli-moram-dalje-tour',
  };
  const cases = [
    {
      name: 'spam',
      result: { classification: 'spam', draft: null, reason: 'Oglas bez događaja.' },
      text: evidence(),
      reason: /spam/,
    },
    {
      name: 'uncertain',
      result: {
        classification: 'uncertain',
        draft: null,
        reason: 'Nije pronađena datirana najava.',
      },
      text: evidence(),
      reason: /nije pronađen/,
    },
    { name: 'past', result: plausible(past), text: evidence(past), reason: /već završio/ },
    {
      name: 'cancelled',
      result: plausible({ ...draft, status: 'cancelled' }),
      text: evidence(),
      reason: /otkazan/,
    },
    {
      name: 'venue',
      result: plausible({ ...draft, venue: null }),
      text: evidence({ ...draft, venue: null }),
      reason: /mjesto održavanja/,
    },
  ];
  for (const item of cases) {
    const repo = new Repository(':memory:', []);
    const mocked = context.mock.method(globalThis, 'fetch', async () => response(item.result));
    const service = new WagzService(
      repo,
      config(),
      async () => empty,
      async () => ({ text: item.text }),
    );
    try {
      const tip = await service.submitTip({
        note: `Dojava o događaju: ${item.name}`,
        url: draft.sourceUrl,
      });
      await service.collect();
      const prepared = (await repo.tip(tip.id))!;
      assert.equal(prepared.status, 'archived', item.name);
      assert.match(prepared.reason, item.reason);
      assert.equal(prepared.note, tip.note);
      assert.equal((await repo.events()).length, 0);
      const restored = await service.updateTip(tip.id, 'restore');
      assert.equal(restored.status, 'inbox');
      assert.equal(restored.lastAutomaticAttemptAt, null);
    } finally {
      mocked.mock.restore();
      await repo.close();
    }
  }
});

test('a date quote found only in the submission cannot become an automatic source-backed draft', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  context.mock.method(globalThis, 'fetch', async () => response(plausible()));
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: 'Nedatirani program Kulturnog centra Osijek.' }),
  );
  try {
    const tip = await service.submitTip({ note: evidence(), url: draft.sourceUrl });
    await service.collect();
    assert.equal((await repo.tip(tip.id))?.status, 'archived');
    assert.match((await repo.tip(tip.id))!.reason, /nisu potvrđeni u neovisnom izvoru/);
  } finally {
    await repo.close();
  }
});

test('provider and source failures remain pending, retry at most once per Zagreb day, and recover next day', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return calls === 1 ? response('malformed result') : response(plausible());
  });
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.collect();
    assert.equal((await repo.tip(tip.id))?.status, 'inbox');
    assert.match((await repo.tip(tip.id))!.reason, /ponovni pokušaj/);
    await service.collect(true);
    assert.equal(calls, 1, 'refreshing source collection does not hammer failed tips');
    // Croatia is already on October 4 while UTC is still October 3.
    context.mock.timers.setTime(new Date('2026-10-03T22:01:00Z').getTime());
    await service.collect();
    assert.equal(calls, 2);
    assert.equal((await repo.tip(tip.id))?.status, 'draft');
  } finally {
    await repo.close();
  }

  const failedRepo = new Repository(':memory:', []);
  let reads = 0;
  const failed = new WagzService(
    failedRepo,
    config(),
    async () => empty,
    async () => {
      reads++;
      return { reason: 'Izvor nije dostupan.' };
    },
  );
  try {
    const tip = await failed.submitTip({ note: 'Radionica u Osijeku', url: draft.sourceUrl });
    await failed.collect();
    await failed.collect();
    assert.equal(reads, 1);
    assert.equal((await failedRepo.tip(tip.id))?.status, 'inbox');
    assert.match((await failedRepo.tip(tip.id))!.reason, /Izvor nije dostupan/);
    assert.equal(calls, 2, 'source failure never searches a substitute event');
  } finally {
    await failedRepo.close();
  }
});

test('source extraction and daily tips share the monthly budget; exhaustion does not archive or fetch tips', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', [source]);
  let calls = 0,
    reads = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return response({ events: [], reason: 'Nema događaja.' }, 0.98);
  });
  const service = new WagzService(
    repo,
    config(),
    async () => ({ ...empty, extractionPages: [{ url: source.url, text: 'Službeni program.' }] }),
    async () => {
      reads++;
      return { text: evidence() };
    },
  );
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.collect();
    await service.collect();
    assert.equal(calls, 1);
    assert.equal(reads, 0);
    assert.equal(await repo.aiSpent(), 0.98);
    assert.equal((await repo.tip(tip.id))?.status, 'inbox');
    assert.match((await repo.tip(tip.id))!.reason, /proračun/);
  } finally {
    await repo.close();
  }
});

test('a slow failed source leaves reserved time for a pending tip and all leases release', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', [source]);
  const started = Date.now();
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return response(plausible());
  });
  const service = new WagzService(
    repo,
    config(),
    async (_id, options) => {
      assert.equal(options?.deadlineMs, started + 105_000);
      context.mock.timers.setTime(started + 105_000);
      throw new Error('Source timeout');
    },
    async () => ({ text: evidence() }),
  );
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.collect(false, 240_000);
    assert.equal((await repo.runs())[0].status, 'error');
    assert.equal((await repo.tip(tip.id))?.status, 'draft');
    assert.equal(calls, 1);
    assert.equal(await repo.isLeaseActive('collection'), false);
    assert.equal(await repo.isLeaseActive(`tip:${tip.id}`), false);
  } finally {
    await repo.close();
  }
});

test('a run processes at most twenty tips and a spent deadline preserves unattempted queued work', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  const service = new WagzService(repo, config(false));
  try {
    await repo.upsert(candidate);
    const tips = [];
    for (let i = 0; i < 21; i++)
      tips.push(await service.submitTip({ note: `DOVIK 2026, dojava ${i}`, url: draft.sourceUrl }));
    await service.collect(false, 1000);
    assert.equal((await repo.tips()).filter((tip) => tip.lastAutomaticAttemptAt).length, 0);
    await service.collect();
    assert.equal((await repo.tips()).filter((tip) => tip.status === 'archived').length, 20);
    assert.equal(service.lastTipBatch?.deferred, 1);
    await service.collect();
    assert.equal((await repo.tips()).filter((tip) => tip.status === 'archived').length, 21);
  } finally {
    await repo.close();
  }
});

test('daily processing skips edited drafts and respects archive/restore revisions during AI work', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  let release!: () => void, entered!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const started = new Promise<void>((resolve) => {
    entered = resolve;
  });
  context.mock.method(globalThis, 'fetch', async () => {
    entered();
    await gate;
    return response(plausible());
  });
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    const manual = await service.submitTip({ note: 'Ručni prijedlog' });
    const saved = await service.updateTip(manual.id, 'save', draft);
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    const running = service.collect();
    await started;
    await service.updateTip(tip.id, 'archive');
    const restored = await service.updateTip(tip.id, 'restore');
    release();
    await running;
    assert.deepEqual(await repo.tip(tip.id), restored);
    assert.deepEqual(await repo.tip(manual.id), saved);
    assert.equal(await repo.isLeaseActive(`tip:${tip.id}`), false);
  } finally {
    release();
    await repo.close();
  }
});

test('an operator edit before the automatic claim cannot be adopted as a fresh claim', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => {
      throw new Error('Must not read');
    },
  );
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    const original = repo.tip.bind(repo);
    let reads = 0;
    context.mock.method(repo, 'tip', async (id: string) => {
      const read = await original(id);
      if (++reads === 2) {
        await service.updateTip(id, 'archive');
        await service.updateTip(id, 'restore');
      }
      return read;
    });
    await service.collect();
    const result = (await repo.tip(tip.id))!;
    assert.equal(result.status, 'inbox');
    assert.equal(result.lastAutomaticAttemptAt, null);
    assert.equal(result.revision, tip.revision! + 2);
    assert.equal(await repo.aiSpent(), 0);
  } finally {
    await repo.close();
  }
});

test('new source evidence completes an imported missing venue without making a duplicate', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  context.mock.method(globalThis, 'fetch', async () => response(plausible()));
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    const incomplete = await repo.upsert({ ...candidate, venue: null });
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.collect();
    const prepared = (await repo.tip(tip.id))!;
    assert.equal(prepared.status, 'draft');
    assert.equal(prepared.draft?.venue, draft.venue);
    assert.equal(prepared.matchedEventId, incomplete.id);
    await service.updateTip(tip.id, 'accept');
    assert.equal((await repo.events()).length, 1);
    assert.equal((await repo.event(incomplete.id))?.venue, draft.venue);
  } finally {
    await repo.close();
  }
});

test('a date-only possible duplicate stays reviewable and acceptance cannot create a second occurrence', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  context.mock.method(globalThis, 'fetch', async () => response(plausible()));
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    const existing = await repo.upsert({
      ...candidate,
      sourceUrl: source.url,
      startsAt: draft.startsAt.slice(0, 10),
    });
    const tip = await service.submitTip({ note: 'Najava dana karijera', url: draft.sourceUrl });
    await service.collect();
    const prepared = (await repo.tip(tip.id))!;
    assert.equal(prepared.status, 'draft');
    assert.equal(prepared.matchedEventId, null);
    assert.match(prepared.reason, /mogući postojeći/);
    await assert.rejects(service.updateTip(tip.id, 'accept'), /Mogući isti događaj/);
    assert.deepEqual(await repo.events(), [existing]);
  } finally {
    await repo.close();
  }
});

test('an explicitly different showtime never silently archives as the known performance', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  const service = new WagzService(repo, config(false));
  try {
    await repo.upsert(candidate);
    const tip = await service.submitTip({
      note: `${draft.title}, 7.10.2026. u 21:00, druga izvedba.`,
      url: draft.sourceUrl,
    });
    await service.collect();
    const pending = (await repo.tip(tip.id))!;
    assert.equal(pending.status, 'inbox');
    assert.equal(pending.matchedEventId, null);
    assert.equal(pending.draft, null);
  } finally {
    await repo.close();
  }
});

test('a draft approved after a new source import links to that event and preserves the imported facts', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  const service = new WagzService(repo, config(false));
  try {
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.updateTip(tip.id, 'save', draft);
    const imported = await repo.upsert({
      ...candidate,
      price: 'Besplatno',
      description: 'Najnovija potvrđena najava.',
    });
    const accepted = await service.updateTip(tip.id, 'accept');
    assert.equal(accepted.matchedEventId, imported.id);
    assert.deepEqual(await repo.events(), [imported]);
  } finally {
    await repo.close();
  }
});

test('accepting a stale linked draft cannot overwrite an operator correction to its event', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', [], false);
  const service = new WagzService(repo, config(false));
  try {
    const event = await repo.upsert(candidate);
    const tip = await service.submitTip({ note: 'DOVIK 2026', url: draft.sourceUrl });
    await service.collect();
    const prepared = (await repo.tip(tip.id))!;
    const corrected = await repo.editEvent(event.id, 'draft', {
      venue: 'Urednička ispravka lokacije',
    });
    await assert.rejects(
      service.updateTip(tip.id, 'accept', undefined, prepared.revision),
      /Povezani događaj promijenjen/,
    );
    assert.deepEqual(await repo.event(event.id), corrected);
    assert.equal((await repo.tip(tip.id))?.status, 'draft');
  } finally {
    await repo.close();
  }
});

test('legacy linked tips without a snapshot may accept unchanged facts but cannot overwrite corrections', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', [], false);
  const service = new WagzService(repo, config(false));
  try {
    const event = await repo.upsert(candidate);
    const unchanged = await service.submitTip({ note: 'Prva stara dojava' });
    await repo.saveTip({
      ...unchanged,
      status: 'draft',
      draft,
      matchedEventId: event.id,
      verification: 'source_match',
    });
    assert.equal((await service.updateTip(unchanged.id, 'accept')).matchedEventId, event.id);
    const stale = await service.submitTip({ note: 'Druga stara dojava' });
    await repo.saveTip({
      ...stale,
      status: 'draft',
      draft,
      matchedEventId: event.id,
      verification: 'source_match',
    });
    const corrected = await repo.editEvent(event.id, 'draft', {
      venue: 'Urednička ispravka lokacije',
    });
    await assert.rejects(
      service.updateTip(stale.id, 'accept'),
      /stariji prijedlog nema spremljenu verziju/,
    );
    assert.deepEqual(await repo.event(event.id), corrected);
  } finally {
    await repo.close();
  }
});

test('cheap abuse and repetitive/promotion spam screening happens before any source read or provider call', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  let providerCalls = 0,
    sourceReads = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    providerCalls++;
    throw new Error('No provider call allowed');
  });
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => {
      sourceReads++;
      return { text: evidence() };
    },
  );
  try {
    const junk = [
      'jebi se',
      'Jebem ti mater!',
      'FUCK YOU!!!',
      'puši kurac',
      'ajde odjebi',
      'asdfasdfasdfasdf',
      'qwerqwerqwerqwer',
      'lol lol lol lol lol lol',
      'aaaaaaaaaaaaaaaaaa',
      '🔥🔥🔥🔥🔥',
      'Buy viagra now https://spam.invalid',
      'Klikni i zaradi 5000 eura, besplatni Bitcoin',
      'FREE SPINS casino bonus!!!',
    ];
    for (const note of junk) {
      const tip = await service.submitTip({ note, url: draft.sourceUrl });
      assert.equal(tip.status, 'archived', note);
      assert.match(tip.reason, /Automatski arhivirano/);
    }
    await service.collect();
    assert.equal(providerCalls, 0);
    assert.equal(sourceReads, 0, 'even a credible submitted URL does not bypass cheap screening');
    assert.equal(await repo.aiSpent(), 0);
    assert.equal(service.lastTipBatch?.queued, 0);
    for (const note of [
      'Predstava Unutarnja kučka, KC Osijek',
      'Koncert benda Pičke vrište, 7.10.2026. u 20 sati u Osijeku.',
      'Stand-up Jebiga, petak u Osijeku.',
      'Let 3 koncert u Osijeku',
      'D&D večer i Feniks salsa radionica',
      'Radionica: kako prepoznati crypto prevare i obećanja garantirane zarade.',
      'Необычный концерт',
    ])
      assert.equal((await service.submitTip({ note })).status, 'inbox', note);
    assert.equal(providerCalls, 0);
  } finally {
    await repo.close();
  }
});

test('case, whitespace and tracking-link variants deduplicate locally before paid work', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  let calls = 0;
  context.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return response(plausible());
  });
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    const original = await service.submitTip({
      note: 'DOVIK 2026 — Dan karijera!',
      url: `${draft.sourceUrl}?utm_source=instagram`,
    });
    const duplicate = await service.submitTip({
      note: '  dovik  2026, dan   karijera. ',
      url: `${draft.sourceUrl}?fbclid=different-tracker`,
    });
    assert.equal(original.id, duplicate.id);
    assert.equal(duplicate.note, original.note, 'original content is retained');
    assert.equal((await repo.tips()).length, 1);
    assert.equal(calls, 0);
    await service.collect();
    assert.equal(calls, 1);
    assert.equal((await repo.tip(original.id))?.status, 'draft');
  } finally {
    await repo.close();
  }
});

test('a completed AI answer cannot silently substitute another explicitly requested showtime', async (context) => {
  freeze(context);
  const repo = new Repository(':memory:', []);
  context.mock.method(globalThis, 'fetch', async () => response(plausible()));
  const service = new WagzService(
    repo,
    config(),
    async () => empty,
    async () => ({ text: evidence() }),
  );
  try {
    await repo.upsert(candidate);
    const tip = await service.submitTip({
      note: `${draft.title}, 7.10.2026. u21.00`,
      url: draft.sourceUrl,
    });
    await service.collect();
    const pending = (await repo.tip(tip.id))!;
    assert.equal(pending.status, 'inbox');
    assert.equal(pending.draft, null);
    assert.match(pending.reason, /satnici u dojavi/);
  } finally {
    await repo.close();
  }
});
