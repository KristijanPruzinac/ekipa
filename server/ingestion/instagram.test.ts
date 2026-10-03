import test, { type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import { Repository } from '../repository.ts';
import { WagzService } from '../service.ts';
import { classificationReply } from '../test-support.ts';
import type { Config } from '../config.ts';
import type { SourceDefinition } from '../../shared/types.ts';
import { fetchSource, sources } from './index.ts';
import {
  APIFY_ACTOR,
  DEFAULT_MAX_COST_USD,
  fetchInstagramProfile,
  instagramProfiles,
  instagramSources,
  isInstagramSource,
} from './instagram.ts';

const ID = 'instagram-dd';
const HANDLE = 'plesni_klub_dd';
const TOKEN = 'apify_api_test_token_123';
const now = new Date('2026-10-02T06:00:00Z');
const daysAgo = (days: number, from = now) =>
  new Date(from.getTime() - days * 86_400_000).toISOString();

type Call = { url: URL; init: RequestInit };
type Item = Record<string, unknown>;

const post = (shortcode: string, overrides: Item = {}): Item => ({
  url: `https://www.instagram.com/p/${shortcode}/`,
  timestamp: daysAgo(1),
  ownerUsername: HANDLE,
  caption: `Objava ${shortcode}`,
  ...overrides,
});

/** An injected Apify mock; records every call and answers with `reply`. */
function apify(reply: () => Response | Promise<Response>) {
  const calls: Call[] = [];
  const fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: new URL(String(input)), init: init ?? {} });
    return reply();
  }) as typeof globalThis.fetch;
  return { calls, fetch };
}
const items = (rows: unknown) => apify(() => new Response(JSON.stringify(rows), { status: 200 }));

const ENV_KEYS = ['APIFY_TOKEN', 'WAGZ_INSTAGRAM_POSTS', 'WAGZ_APIFY_MAX_COST_USD'] as const;

/**
 * Every test runs with a clean Apify environment and a global fetch that fails loudly, so the
 * suite can never reach the real network or depend on the developer's shell.
 */
let savedEnv: Record<string, string | undefined> = {};
test.beforeEach((context) => {
  savedEnv = Object.fromEntries(ENV_KEYS.map((key) => [key, process.env[key]]));
  for (const key of ENV_KEYS) delete process.env[key];
  (context as TestContext).mock.method(globalThis, 'fetch', async (input: unknown) => {
    throw new Error(`Unexpected real network call: ${String(input)}`);
  });
});
test.afterEach(() => {
  for (const key of ENV_KEYS) {
    if (savedEnv[key] === undefined) delete process.env[key];
    else process.env[key] = savedEnv[key];
  }
});

test('registry: confirmed D&D and Feniks profiles are Instagram sources in the ingestion index', () => {
  assert.ok(isInstagramSource(ID));
  assert.equal(isInstagramSource('kc-osijek'), false);
  assert.equal(isInstagramSource('unknown'), false);
  assert.deepEqual(
    instagramProfiles.map((profile) => profile.handle),
    [HANDLE, 'spufeniksosijek'],
  );
  assert.ok(isInstagramSource('instagram-feniks'));
  const source = sources.find((item) => item.id === ID);
  assert.ok(source);
  assert.equal(source, instagramSources[0]);
  assert.equal(source.url, `https://www.instagram.com/${HANDLE}/`);
  assert.equal(typeof source.enabled, 'boolean');
});

test('request: POSTs the run-sync dataset endpoint with the token only in the Authorization header', async () => {
  const mock = items([]);
  await fetchInstagramProfile(ID, { fetch: mock.fetch, token: TOKEN, now });
  assert.equal(mock.calls.length, 1);
  const [{ url, init }] = mock.calls;
  assert.equal(url.origin, 'https://api.apify.com');
  assert.equal(url.pathname, `/v2/acts/${APIFY_ACTOR}/run-sync-get-dataset-items`);
  assert.equal(APIFY_ACTOR, 'apify~instagram-scraper');
  assert.equal(init.method, 'POST');
  assert.equal(init.redirect, 'error');
  assert.ok(init.signal instanceof AbortSignal);
  const headers = new Headers(init.headers);
  assert.equal(headers.get('authorization'), `Bearer ${TOKEN}`);
  assert.equal(headers.get('content-type'), 'application/json');
  assert.ok(!url.href.includes(TOKEN), 'the token must never be part of the URL');
  assert.equal(url.searchParams.get('token'), null);
  assert.ok(!String(init.body).includes(TOKEN), 'the token must not be in the body either');
  assert.equal(DEFAULT_MAX_COST_USD, 0.1);
  assert.equal(url.searchParams.get('maxTotalChargeUsd'), '0.1');
  const timeout = Number(url.searchParams.get('timeout'));
  assert.ok(timeout >= 1 && timeout <= 120);
  assert.deepEqual(JSON.parse(String(init.body)), {
    directUrls: [`https://www.instagram.com/${HANDLE}/`],
    resultsType: 'posts',
    resultsLimit: 5,
  });
});

test('request: an explicit cost cap is forwarded verbatim and a near deadline shortens the Apify timeout', async () => {
  const mock = items([]);
  await fetchInstagramProfile(ID, {
    fetch: mock.fetch,
    token: TOKEN,
    now,
    maxCostUsd: 0.25,
    deadlineMs: Date.now() + 30_000,
  });
  assert.equal(mock.calls[0].url.searchParams.get('maxTotalChargeUsd'), '0.25');
  assert.ok(Number(mock.calls[0].url.searchParams.get('timeout')) <= 30);
});

test('request: postsPerProfile is clamped to 1..5 and floored; invalid values fall back to 5', async () => {
  for (const [value, expected] of [
    [0, 1],
    [-3, 1],
    [1, 1],
    [2.9, 2],
    [5, 5],
    [10, 5],
    [Number.NaN, 5],
    [Number.POSITIVE_INFINITY, 5],
    [undefined, 5],
  ] as const) {
    const mock = items([]);
    await fetchInstagramProfile(ID, {
      fetch: mock.fetch,
      token: TOKEN,
      now,
      postsPerProfile: value,
    });
    assert.equal(
      JSON.parse(String(mock.calls[0].init.body)).resultsLimit,
      expected,
      `postsPerProfile ${value}`,
    );
  }
});

test('request: environment fallbacks for token, post count and cost cap are honoured', async () => {
  process.env.APIFY_TOKEN = TOKEN;
  process.env.WAGZ_INSTAGRAM_POSTS = '2';
  process.env.WAGZ_APIFY_MAX_COST_USD = '0.05';
  const mock = items([]);
  await fetchInstagramProfile(ID, { fetch: mock.fetch, now });
  const [{ url, init }] = mock.calls;
  assert.equal(new Headers(init.headers).get('authorization'), `Bearer ${TOKEN}`);
  assert.equal(url.searchParams.get('maxTotalChargeUsd'), '0.05');
  assert.equal(JSON.parse(String(init.body)).resultsLimit, 2);
});

test('preconditions: missing or malformed tokens, unknown ids and invalid cost caps throw before any fetch', async () => {
  const mock = items([]);
  const base = { fetch: mock.fetch, now };
  await assert.rejects(fetchInstagramProfile(ID, base), /Apify token nije postavljen/);
  await assert.rejects(
    fetchInstagramProfile(ID, { ...base, token: '' }),
    /Apify token nije postavljen/,
  );
  for (const token of [' ', '\t', 'abc def', 'abc\n']) {
    await assert.rejects(
      fetchInstagramProfile(ID, { ...base, token }),
      /Apify token nije postavljen/,
      JSON.stringify(token),
    );
  }
  process.env.APIFY_TOKEN = '   ';
  await assert.rejects(fetchInstagramProfile(ID, base), /Apify token nije postavljen/);
  delete process.env.APIFY_TOKEN;
  for (const id of ['instagram-unknown', 'kc-osijek', '']) {
    await assert.rejects(
      fetchInstagramProfile(id, { ...base, token: TOKEN }),
      /Nepoznat Instagram izvor/,
    );
  }
  for (const maxCostUsd of [
    0,
    -0.1,
    1.01,
    5,
    Number.NaN,
    Number.POSITIVE_INFINITY,
    Number.NEGATIVE_INFINITY,
  ]) {
    await assert.rejects(
      fetchInstagramProfile(ID, { ...base, token: TOKEN, maxCostUsd }),
      /ograničenje troška nije valjano/,
      `maxCostUsd ${maxCostUsd}`,
    );
  }
  for (const value of ['0', '-1', '2', 'abc']) {
    process.env.WAGZ_APIFY_MAX_COST_USD = value;
    await assert.rejects(
      fetchInstagramProfile(ID, { ...base, token: TOKEN }),
      /ograničenje troška nije valjano/,
      `WAGZ_APIFY_MAX_COST_USD=${value}`,
    );
  }
  delete process.env.WAGZ_APIFY_MAX_COST_USD;
  await assert.rejects(
    fetchInstagramProfile(ID, { ...base, token: TOKEN, deadlineMs: Date.now() - 1 }),
    /vremensko ograničenje/,
  );
  assert.equal(mock.calls.length, 0, 'no request may be sent when a precondition fails');
  // The upper bound itself is allowed.
  await fetchInstagramProfile(ID, { ...base, token: TOKEN, maxCostUsd: 1 });
  assert.equal(mock.calls.length, 1);
});

test('response: non-200 statuses throw with the HTTP code', async () => {
  for (const status of [400, 401, 402, 404, 408, 429, 500, 502]) {
    const mock = apify(() => new Response('[]', { status }));
    await assert.rejects(
      fetchInstagramProfile(ID, { fetch: mock.fetch, token: TOKEN, now }),
      new RegExp(`HTTP ${status}`),
    );
  }
  // 201 is a successful run-sync answer.
  const created = apify(() => new Response('[]', { status: 201 }));
  const result = await fetchInstagramProfile(ID, { fetch: created.fetch, token: TOKEN, now });
  assert.equal(result.pagesFetched, 1);
});

test('response: oversized bodies throw, by declared content-length and by actual size', async () => {
  const declared = apify(
    () =>
      new Response('[]', {
        status: 200,
        headers: { 'content-length': String(2 * 1024 * 1024 + 1) },
      }),
  );
  await assert.rejects(
    fetchInstagramProfile(ID, { fetch: declared.fetch, token: TOKEN, now }),
    /prevelik/,
  );
  const huge = JSON.stringify([post('ABCDE', { caption: 'x'.repeat(2 * 1024 * 1024) })]);
  const actual = apify(() => new Response(huge, { status: 200 }));
  await assert.rejects(
    fetchInstagramProfile(ID, { fetch: actual.fetch, token: TOKEN, now }),
    /prevelik/,
  );
  // Multi-byte characters count by bytes, not UTF-16 code units.
  const wide = JSON.stringify([post('ABCDE', { caption: 'č'.repeat(1024 * 1024 + 10) })]);
  assert.ok(wide.length < 2 * 1024 * 1024);
  const bytes = apify(() => new Response(wide, { status: 200 }));
  await assert.rejects(
    fetchInstagramProfile(ID, { fetch: bytes.fetch, token: TOKEN, now }),
    /prevelik/,
  );
});

test('response: non-JSON and non-array bodies throw', async () => {
  for (const body of ['<html>blocked</html>', '', '{"items": []}', 'null', '"text"', '42']) {
    const mock = apify(() => new Response(body, { status: 200 }));
    await assert.rejects(
      fetchInstagramProfile(ID, { fetch: mock.fetch, token: TOKEN, now }),
      /neispravan odgovor/,
      JSON.stringify(body),
    );
  }
});

test('result shape: no deterministic events, one page fetched, discovered counts every item', async () => {
  const rows = [post('AAAAA'), post('BBBBB'), null, 'junk', post('CCCCC', { caption: '' })];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.deepEqual(result.events, []);
  assert.equal(result.pagesFetched, 1);
  assert.equal(result.discovered, rows.length);
  assert.equal(result.extractionPages?.length, 2);
  assert.equal(result.skipped, 3);
  const empty = await fetchInstagramProfile(ID, { fetch: items([]).fetch, token: TOKEN, now });
  assert.deepEqual(empty.events, []);
  assert.deepEqual(empty.extractionPages, []);
  assert.equal(empty.discovered, 0);
  assert.equal(empty.skipped, 0);
  assert.deepEqual(empty.warnings, []);
});

test('filtering: invalid or foreign URLs and missing or invalid timestamps are skipped', async () => {
  const rows = [
    post('GOOD1'),
    post('BAD01', { url: 'https://www.instagram.com/stories/plesni_klub_dd/123/' }),
    post('BAD02', { url: 'https://evil.example/p/BAD02/' }),
    post('BAD03', { url: 'http://www.instagram.com/p/BAD03/' }),
    post('BAD04', { url: 'https://instagram.com/p/BAD04/' }),
    post('BAD05', { url: 'https://www.instagram.com/p/BAD05/?utm_source=x' }),
    post('BAD06', { url: 'https://www.instagram.com/p/ab/' }),
    post('BAD07', { url: 'https://www.instagram.com/plesni_klub_dd/' }),
    post('BAD08', { url: 'https://www.instagram.com/p/BAD08/#x' }),
    post('BAD09', { url: 42 }),
    post('BAD10', { url: undefined }),
    post('BAD11', { timestamp: undefined }),
    post('BAD12', { timestamp: 'not a date' }),
    post('BAD13', { timestamp: 1_790_000_000_000 }),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.deepEqual(
    result.extractionPages?.map((page) => page.url),
    ['https://www.instagram.com/p/GOOD1/'],
  );
  assert.equal(result.skipped, rows.length - 1);
  assert.equal(result.discovered, rows.length);
  assert.deepEqual(result.warnings, []);
});

test('filtering: duplicate shortcodes are deduplicated, including across /p/ and /reel/ and a trailing slash', async () => {
  const rows = [
    post('DUPED', { caption: 'Prva verzija', timestamp: daysAgo(1) }),
    post('DUPED', { caption: 'Druga verzija', timestamp: daysAgo(0.5) }),
    post('DUPED', { url: 'https://www.instagram.com/reel/DUPED', caption: 'Reel verzija' }),
    post('OTHER'),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  const pages = result.extractionPages ?? [];
  assert.equal(pages.length, 2);
  assert.equal(pages.filter((page) => page.url.includes('DUPED')).length, 1);
  assert.match(pages.find((page) => page.url.includes('DUPED'))!.text, /Prva verzija/);
  assert.equal(result.skipped, 2);
});

test('filtering: posts owned by another account are skipped with a collaboration warning', async () => {
  const rows = [
    post('MINE1'),
    post('MINE2', { ownerUsername: 'Plesni_Klub_DD' }),
    post('MINE3', { ownerUsername: undefined }),
    post('THEIR', { ownerUsername: 'someone_else' }),
    post('COLAB', { ownerUsername: 'partner_club' }),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.deepEqual(result.extractionPages?.map((page) => page.url.split('/')[4]).sort(), [
    'MINE1',
    'MINE2',
    'MINE3',
  ]);
  assert.equal(result.skipped, 2);
  assert.equal(result.warnings.length, 1);
  assert.match(result.warnings[0], /Plesni klub D&D \(Instagram\): 2 objava pripada drugom računu/);
});

test('filtering: posts older than 60 days are skipped silently', async () => {
  const rows = [
    post('FRESH', { timestamp: daysAgo(59.9) }),
    post('STALE', { timestamp: daysAgo(60.1) }),
    post('OLDER', { timestamp: '2024-01-01T00:00:00Z' }),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.deepEqual(
    result.extractionPages?.map((page) => page.url),
    ['https://www.instagram.com/p/FRESH/'],
  );
  assert.equal(result.skipped, 2);
  assert.deepEqual(result.warnings, []);
});

test('filtering: captionless posts are skipped with the poster-image warning', async () => {
  const rows = [
    post('TEXT1'),
    post('NOCAP', { caption: undefined }),
    post('EMPTY', { caption: '' }),
    post('BLANK', { caption: ' \n\t \u0001\u0007 ' }),
    post('NUMBR', { caption: 42 }),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.equal(result.extractionPages?.length, 1);
  assert.equal(result.skipped, 4);
  assert.equal(result.warnings.length, 1);
  assert.match(result.warnings[0], /4 objava nema tekst/);
  assert.match(result.warnings[0], /samo na slici nije čitljiv/);
});

test('captions: control characters are stripped, newlines and tabs kept, and length capped at 4000', async () => {
  const rows = [
    post('CTRL1', {
      caption: '  Plesna\u0000večer\u0007 \u001b[31mcrveno\u007f\nDrugi red\tkolona\r\nkraj  ',
    }),
    post('LONG1', { caption: `${'a'.repeat(3990)}${'b'.repeat(100)}`, timestamp: daysAgo(2) }),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  const [control, long] = result.extractionPages ?? [];
  const controlCaption = control.text.split('\n\n').slice(1).join('\n\n');
  assert.equal(controlCaption, 'Plesna večer   [31mcrveno \nDrugi red\tkolona\r\nkraj');
  assert.doesNotMatch(control.text, /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/);
  const longCaption = long.text.split('\n\n').slice(1).join('\n\n');
  assert.equal(longCaption.length, 4000);
  assert.equal(longCaption, `${'a'.repeat(3990)}${'b'.repeat(10)}`);
});

test('ordering: pages are newest first and capped at the configured post count', async () => {
  const rows = [
    post('DAY05', { timestamp: daysAgo(5) }),
    post('DAY01', { timestamp: daysAgo(1) }),
    post('DAY30', { timestamp: daysAgo(30) }),
    post('DAY02', { timestamp: daysAgo(2) }),
    post('DAY10', { timestamp: daysAgo(10) }),
    post('DAY03', { timestamp: daysAgo(3) }),
    post('DAY20', { timestamp: daysAgo(20) }),
  ];
  const shortcodes = (urls: string[] | undefined) => urls?.map((url) => url.split('/')[4]);
  const all = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.deepEqual(shortcodes(all.extractionPages?.map((page) => page.url)), [
    'DAY01',
    'DAY02',
    'DAY03',
    'DAY05',
    'DAY10',
  ]);
  assert.equal(all.skipped, 2, 'posts beyond the limit count as skipped');
  assert.equal(all.discovered, 7);
  const two = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
    postsPerProfile: 2,
  });
  assert.deepEqual(shortcodes(two.extractionPages?.map((page) => page.url)), ['DAY01', 'DAY02']);
  assert.equal(two.skipped, 5);
});

test('urls: /reel/ posts keep /reel/ and every page URL is canonical with a trailing slash', async () => {
  const rows = [
    post('REEL1', { url: 'https://www.instagram.com/reel/REEL1/' }),
    post('POST1', { url: 'https://www.instagram.com/p/POST1' }),
    post('Mixed_-Case9', { url: 'https://www.instagram.com/p/Mixed_-Case9/' }),
  ];
  const result = await fetchInstagramProfile(ID, {
    fetch: items(rows).fetch,
    token: TOKEN,
    now,
  });
  assert.deepEqual(result.extractionPages?.map((page) => page.url).sort(), [
    'https://www.instagram.com/p/Mixed_-Case9/',
    'https://www.instagram.com/p/POST1/',
    'https://www.instagram.com/reel/REEL1/',
  ]);
});

test('page text: names the handle and organiser and carries the caption but never the post timestamp', async () => {
  const timestamp = '2026-09-28T17:45:12.000Z';
  const caption = 'Plesna večer 10. listopada 2026. u 20:00, Dvorana Gradski vrt.';
  const result = await fetchInstagramProfile(ID, {
    fetch: items([post('TEXT1', { timestamp, caption })]).fetch,
    token: TOKEN,
    now,
  });
  const [page] = result.extractionPages ?? [];
  assert.equal(page.text, `Instagram objava profila @${HANDLE} (Plesni klub D&D).\n\n${caption}`);
  assert.ok(page.text.includes(`@${HANDLE}`));
  assert.ok(page.text.includes(caption));
  for (const fragment of [timestamp, '2026-09-28', '28.9.', '28. rujna', '17:45', 'rujna'])
    assert.ok(!page.text.includes(fragment), `page text leaks the publication date: ${fragment}`);
});

test('fetchSource routes instagram-dd to the Apify adapter using APIFY_TOKEN and the injected fetch', async () => {
  process.env.APIFY_TOKEN = TOKEN;
  try {
    const mock = items([post('ROUTE', { timestamp: new Date().toISOString() })]);
    const result = await fetchSource(ID, { fetch: mock.fetch });
    assert.equal(mock.calls.length, 1);
    assert.match(mock.calls[0].url.href, /^https:\/\/api\.apify\.com\/v2\/acts\/apify~instagram/);
    assert.equal(new Headers(mock.calls[0].init.headers).get('authorization'), `Bearer ${TOKEN}`);
    assert.deepEqual(result.events, []);
    assert.deepEqual(
      result.extractionPages?.map((page) => page.url),
      ['https://www.instagram.com/p/ROUTE/'],
    );
    // fetchSource forwards its `now` so the 60-day window is evaluated against it.
    const stale = await fetchSource(ID, {
      fetch: items([post('ROUTE', { timestamp: '2026-01-01T00:00:00Z' })]).fetch,
      now,
    });
    assert.deepEqual(stale.extractionPages, []);
    assert.equal(stale.skipped, 1);
    delete process.env.APIFY_TOKEN;
    const unconfigured = items([]);
    await assert.rejects(
      fetchSource(ID, { fetch: unconfigured.fetch }),
      /Apify token nije postavljen/,
    );
    assert.equal(unconfigured.calls.length, 0);
  } finally {
    delete process.env.APIFY_TOKEN;
  }
});

const settings = (): Config => ({
  host: '127.0.0.1',
  port: 3000,
  databasePath: ':memory:',
  adminKey: 'test',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 360,
  ai: {
    apiKey: 'mock-key-only',
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
const caption = 'Plesna večer 10. listopada 2099., 20:00 u Dvorani Gradski vrt, Osijek.';
const extracted = {
  title: 'Plesna večer',
  description: 'Plesna večer kluba D&D.',
  startsAt: '2099-10-10T20:00:00+02:00',
  endsAt: null,
  venue: 'Dvorana Gradski vrt',
  address: null,
  city: 'Osijek',
  category: 'other',
  price: null,
  status: 'scheduled',
  dateEvidence: '10. listopada 2099., 20:00',
};

/** Collect once with the real adapter (mocked Apify) and a mocked AI provider. */
async function collectWithAi(context: TestContext, source: SourceDefinition) {
  assert.ok(caption.includes(extracted.dateEvidence));
  const repo = new Repository(':memory:', [source]);
  const extractionCalls: string[] = [];
  context.mock.method(globalThis, 'fetch', async (input: unknown, init?: RequestInit) => {
    assert.ok(
      String(input).startsWith('https://openrouter.ai/'),
      `unexpected network call ${input}`,
    );
    const categorised = classificationReply(init);
    if (categorised) return categorised;
    const body = JSON.parse(String(init?.body));
    assert.equal(body.response_format?.json_schema?.name, 'page_events');
    extractionCalls.push(String(init?.body));
    return completion({ events: [extracted], reason: 'Izdvojena najava.' });
  });
  const apifyMock = items([post('EVENT', { caption, timestamp: new Date().toISOString() })]);
  // The Instagram adapter is shared by both runs; only the source id differs.
  const service = new WagzService(repo, settings(), (_id, options) =>
    fetchInstagramProfile(ID, { ...options, fetch: apifyMock.fetch, token: TOKEN }),
  );
  try {
    assert.equal(await service.collect(), true);
    return {
      events: await repo.events(),
      runs: await repo.runs(),
      extractionCalls,
      apifyCalls: apifyMock.calls.length,
    };
  } finally {
    await repo.close();
  }
}

test('service: AI-extracted Instagram events are stored as drafts even with autoPublish on', async (context) => {
  const source: SourceDefinition = { ...instagramSources[0], enabled: true };
  assert.equal(source.id, ID);
  const { events, runs, extractionCalls, apifyCalls } = await collectWithAi(context, source);
  assert.equal(apifyCalls, 1);
  assert.equal(extractionCalls.length, 1);
  assert.ok(extractionCalls[0].includes(`@${HANDLE}`), 'the caption page is sent to extraction');
  assert.equal(runs.length, 1);
  assert.equal(runs[0].sourceId, ID);
  assert.equal(runs[0].imported, 1);
  assert.equal(events.length, 1);
  const [event] = events;
  assert.equal(event.title, 'Plesna večer');
  assert.equal(event.startsAt, '2099-10-10T20:00:00+02:00');
  assert.equal(event.venue, 'Dvorana Gradski vrt');
  assert.equal(event.city, 'Osijek');
  assert.equal(event.publication, 'draft');
  assert.equal(event.autoPublishEligible, false);
  assert.equal(event.sources[0].sourceId, ID);
  assert.equal(event.sources[0].url, 'https://www.instagram.com/p/EVENT/');
});

test('service control: the same extraction from a non-Instagram source id is published', async (context) => {
  const source: SourceDefinition = {
    id: 'control',
    name: 'Control',
    url: 'https://example.test/',
    description: '',
    enabled: true,
  };
  const { events } = await collectWithAi(context, source);
  assert.equal(events.length, 1);
  assert.equal(events[0].publication, 'published');
});

test('yearless caption dates gain the next year after publication and pass evidence parsing', async () => {
  const { annotateYears } = await import('./instagram.ts');
  const { supportedDays } = await import('../ai/evidence.ts');
  const cases: Array<[string, string, string[]]> = [
    // Real captions from the 3 October 2026 Feniks pilot.
    ['📅 Početak: srijeda, 7.10. 🕕 Vrijeme: 18:00', '2026-09-23T22:03:36Z', ['2026-10-07']],
    ['Vidimo se u Campusu 24. 7. i 1. 8.!', '2026-07-18T10:05:55Z', ['2026-07-24', '2026-08-01']],
    ['Vidimo se u petak, 7. kolovoza od 20 h', '2026-08-06T14:21:38Z', ['2026-08-07']],
    ['s početkom 12.10. i 14.10.', '2026-09-23T22:11:12Z', ['2026-10-12', '2026-10-14']],
    // Across New Year, and an explicit year that must stay untouched.
    ['Party 3.1. za Novu godinu', '2026-12-20T10:00:00Z', ['2027-01-03']],
    ['📅 Trajanje: 7. - 30.9.2026.', '2026-09-01T00:06:42Z', ['2026-09-07', '2026-09-30']],
  ];
  for (const [caption, published, days] of cases) {
    const { text, changed } = annotateYears(caption, new Date(published));
    assert.deepEqual([...supportedDays(text)].sort(), days, caption);
    assert.equal(changed, !/\d{4}/.test(caption), caption);
  }
  for (const untouched of ['Cijena 10.50 eura', '31.2. nije datum', 'Tel 098 457 557', '18.00 h'])
    assert.equal(annotateYears(untouched, new Date('2026-10-01T00:00:00Z')).text, untouched);
  // A date already weeks past is not pushed ~a year ahead as a new event; it stays yearless and
  // is therefore rejected by the evidence check.
  const stale = annotateYears('Hvala svima na 1.9.!', new Date('2026-09-25T00:00:00Z'));
  assert.equal(stale.text, 'Hvala svima na 1.9.!');
  assert.equal(stale.changed, false);
});

test('annotated pages disclose the automatic year and Feniks is a confirmed profile', async () => {
  const { instagramProfiles } = await import('./instagram.ts');
  assert.ok(instagramProfiles.some((item) => item.handle === 'spufeniksosijek'));
  const calls: unknown[] = [];
  const fetch = (async () => {
    calls.push(1);
    return new Response(
      JSON.stringify([
        {
          url: 'https://www.instagram.com/p/DdpVsZ2uQNP/',
          timestamp: '2026-09-23T22:03:36.000Z',
          ownerUsername: 'spufeniksosijek',
          caption: 'Početni plesni tečaj. 📅 Početak: srijeda, 7.10. 🕕 18:00',
        },
      ]),
      { status: 200 },
    );
  }) as typeof globalThis.fetch;
  const result = await fetchInstagramProfile('instagram-feniks', {
    fetch,
    token: 'test-token',
    now: new Date('2026-10-03T10:00:00Z'),
  });
  assert.equal(calls.length, 1);
  assert.match(result.extractionPages![0].text, /godina .* dodana je automatski/);
  assert.match(result.extractionPages![0].text, /7\.10\.2026\./);
  assert.doesNotMatch(result.extractionPages![0].text, /2026-09-23|22:03/);
});
