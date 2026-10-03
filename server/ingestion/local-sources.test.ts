import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { load } from 'cheerio';
import { Repository } from '../repository.ts';
import { WagzService } from '../service.ts';
import type { Config } from '../config.ts';
import { fetchSource, sources } from './index.ts';
import { parseKcListing, parseKcDetail } from './parsers.ts';
import {
  explicitDates,
  parseLocalListing,
  parseAnnouncement,
  parseHnkDetail,
  parseCoreEventDetail,
} from './local-sources.ts';

type FixtureSource = {
  id: string;
  url: string;
  listingHtml: string;
  details: { url: string; html: string }[];
};
const fixture = JSON.parse(
  await readFile(new URL('./fixtures/local-sources.json', import.meta.url), 'utf8'),
) as {
  sources: FixtureSource[];
  overlap: { kcUrl: string; coreUrl: string; kcListing: string; kcHtml: string; coreHtml: string };
};
const source = (id: string) => fixture.sources.find((item) => item.id === id)!;
const now = new Date('2026-10-02T06:00:00Z');

test('GISKO event dates come from announcements, with registration and membership retained', () => {
  const s = source('gisko');
  const listing = parseLocalListing(s.id, s.listingHtml, now);
  assert.equal(listing.entries.length, 9);
  const [literary, family] = s.details.map(
    (page) => parseAnnouncement('gisko', page.html, { url: page.url, title: '' }, now).events[0],
  );
  assert.equal(literary.startsAt, '2026-10-09T18:00:00+02:00');
  assert.equal(literary.venue, 'GISKO — Studijska čitaonica');
  assert.equal(literary.category, 'literature');
  assert.equal(family.startsAt, '2026-10-14T17:30:00+02:00');
  assert.equal(family.endsAt, '2026-10-14T18:30:00+02:00');
  assert.match(family.description, /korisnike Knjižnice starije od tri godine/);
  assert.match(family.description, /prijaviti se/);
  assert.equal(family.price, null);
});

test('HNK discovers every home performance and excludes touring cities; ticket IDs survive time corrections', () => {
  const s = source('hnk-osijek'),
    detail = s.details[0];
  const listing = parseLocalListing(s.id, s.listingHtml, now);
  assert.equal(listing.entries.length, 19);
  assert.ok(listing.entries.every((entry) => !/Krapin|Pula|Bjelovar/i.test(entry.title)));
  const numericListing = parseLocalListing(
    s.id,
    s.listingHtml.replace('03. listopada 2026. 19:00', '03.10.2026. 19:00'),
    now,
  );
  assert.equal(numericListing.entries[0].startsAt, '2026-10-03T19:00:00+02:00');
  const entries = listing.entries.filter((entry) => entry.url === detail.url);
  const parsed = parseHnkDetail(detail.html, entries, now);
  assert.equal(parsed.events.length, 5);
  assert.equal(new Set(parsed.events.map((event) => event.externalId)).size, 5);
  assert.deepEqual(
    parsed.events.map((event) => event.startsAt.slice(0, 10)),
    ['2026-10-09', '2026-10-10', '2026-10-12', '2026-10-13', '2026-10-14'],
  );
  assert.equal(parsed.events[0].category, 'dance');
  assert.match(parsed.events[2].description, /pretplatničkog programa/);
  const changed = parseHnkDetail(
    detail.html,
    [{ ...entries[0], startsAt: entries[0].startsAt!.replace('20:00', '21:00') }],
    now,
  );
  assert.equal(changed.events[0].externalId, parsed.events[0].externalId);
  const ambiguous = parseHnkDetail(
    detail.html,
    [entries[0], { ...entries[0], startsAt: entries[0].startsAt!.replace('20:00', '22:00') }],
    now,
  );
  assert.equal(new Set(ambiguous.events.map((event) => event.externalId)).size, 2);
  assert.equal(ambiguous.reviewExternalIds.length, 2);
});

test('DKolektiv separates two workshop occurrences and refuses image-only dates, publication dates, deadlines and other towns', () => {
  const s = source('dkolektiv');
  const workshop = s.details[1],
    imageOnly = s.details[2],
    fair = s.details[0];
  const result = parseAnnouncement(
    'dkolektiv',
    workshop.html,
    { url: workshop.url, title: '' },
    now,
  );
  assert.deepEqual(
    result.events.map((event) => [event.startsAt, event.endsAt]),
    [
      ['2026-10-02T17:00:00+02:00', '2026-10-02T18:30:00+02:00'],
      ['2026-10-03T17:00:00+02:00', '2026-10-03T18:30:00+02:00'],
    ],
  );
  assert.equal(new Set(result.events.map((event) => event.externalId)).size, 2);
  assert.equal(result.events[0].venue, 'Franjevačka ulica, Tvrđa');
  const hidden = parseAnnouncement(
    'dkolektiv',
    imageOnly.html,
    { url: imageOnly.url, title: '' },
    now,
  );
  assert.equal(hidden.events.length, 0);
  assert.match(hidden.warnings[0], /slikovni raspored/);
  const historical = parseAnnouncement(
    'dkolektiv',
    fair.html,
    { url: fair.url, title: '' },
    new Date('2026-09-01T10:00:00Z'),
  );
  assert.equal(historical.events[0].startsAt, '2026-09-16T17:00:00+02:00');
  const parse = (body: string) =>
    parseAnnouncement(
      'dkolektiv',
      `<div class="title-page">Plesna radionica</div><div class="single-news"><div class="meta">3. listopada 2026.</div>${body}</div>`,
      { url: workshop.url, title: '' },
      now,
    );
  assert.equal(
    parse('<p>Pozivamo na radionicu. Prijave do 5. listopada 2026.</p><p>📍 Dvorana, Osijek</p>')
      .events.length,
    0,
  );
  assert.equal(
    parse('<p>Pozivamo na radionicu 5. listopada.</p><p>📍 Dvorana, Osijek</p>').events.length,
    0,
  );
  assert.equal(
    parse(
      '<p>Pozivamo na radionicu 5. listopada 2026.</p><p>📍 Dvorana, Podgorač</p><p>Partner: Osijek</p>',
    ).events.length,
    0,
  );
  assert.equal(
    parse(
      '<p>Redovni tjedni sat plesa 5. listopada 2026. Početak u 20h.</p><p>📍 Dvorana, Osijek</p>',
    ).events.length,
    0,
  );
});

test('CoreEvent retains 16+ guardian conditions and splits actual cinema ticket sessions', () => {
  const s = source('coreevent-osijek');
  assert.equal(parseLocalListing(s.id, s.listingHtml, now).entries.length, 9);
  const comedy = parseCoreEventDetail(s.details[0].html, { ...s.details[0], title: '' }, now);
  assert.equal(comedy.events[0].startsAt, '2026-10-25T20:00:00+01:00');
  assert.match(
    comedy.events[0].description,
    /starijoj od 16 godina, mlađi smiju biti u publici uz pratnju staratelja/,
  );
  const movie = parseCoreEventDetail(s.details[2].html, { ...s.details[2], title: '' }, now);
  assert.deepEqual(
    movie.events.map((event) => event.startsAt),
    ['2026-10-03T11:00:00+02:00', '2026-10-04T17:00:00+02:00'],
  );
  assert.ok(movie.events.every((event) => event.endsAt === null && event.category === 'film'));
  assert.equal(new Set(movie.events.map((event) => event.externalId)).size, 2);
  const otherCity = s.details[0].html.replace(
    '"addressLocality": "Osijek"',
    '"addressLocality": "Zagreb"',
  );
  assert.equal(
    parseCoreEventDetail(otherCity, { ...s.details[0], title: '' }, now).events.length,
    0,
  );
});

test('CoreEvent holds DST and conflicting-clock candidates without discarding the real venue or access condition', () => {
  const s = source('coreevent-osijek'),
    page = s.details[1];
  const parsed = parseCoreEventDetail(page.html, { ...page, title: '' }, now);
  assert.equal(parsed.events[0].venue, 'Club Oxygene');
  assert.equal(parsed.events[0].endsAt, '2026-10-25');
  assert.match(parsed.events[0].description, /18 godina/);
  assert.deepEqual(parsed.reviewExternalIds, [parsed.events[0].externalId]);
  const conflict = parseCoreEventDetail(
    s.details[0].html.replace('20:00 sati', '21:00 sati'),
    { ...s.details[0], title: '' },
    now,
  );
  assert.equal(conflict.reviewExternalIds.length, 1);
  assert.match(conflict.warnings[0], /nije usklađena/);
});

test('explicit event years and valid calendar dates are required', () => {
  assert.deepEqual(explicitDates('2. i 3. listopada 2026.'), ['2026-10-02', '2026-10-03']);
  assert.deepEqual(explicitDates('3. listopada'), []);
  assert.deepEqual(explicitDates('31. veljače 2026.'), []);
  for (const title of [
    'Plesno druženje',
    'Plesna radionica',
    'Početni plesni tečaj swinga',
    'Dan otvorenih vrata plesne škole',
  ]) {
    const parsed = parseAnnouncement(
      'dkolektiv',
      `<div class="title-page">${title}</div><div class="single-news"><p>Pozivamo vas 5. listopada 2026. s početkom u 20:00 sati.</p><p>📍 Dvorana, Osijek</p><p>Prijava obavezna.</p></div>`,
      { url: 'https://www.dkolektiv.hr/hr/posts/test-invitation', title },
      now,
    );
    assert.equal(parsed.events.length, 1);
    assert.equal(parsed.events[0].category, 'dance');
    assert.match(parsed.events[0].description, /Prijava obavezna/);
  }
});

test('actual KC/CoreEvent overlap merges exact showtime and venue while separate performances stay separate', async () => {
  const { overlap } = fixture;
  const kc = parseKcDetail(overlap.kcHtml, parseKcListing(overlap.kcListing, now).entries[0]).event;
  const core = parseCoreEventDetail(overlap.coreHtml, { url: overlap.coreUrl, title: '' }, now)
    .events[0];
  assert.equal(kc.title, 'USPJEŠNA.HR');
  assert.equal(core.title, kc.title);
  assert.ok(
    overlap.kcHtml.includes(overlap.coreUrl),
    'KC explicitly links the same organizer ticket page.',
  );
  const repo = new Repository(':memory:', sources);
  try {
    await repo.upsert(kc, now);
    await repo.upsert(core, now);
    assert.equal((await repo.events()).length, 1);
    assert.equal((await repo.events())[0].sources.length, 2);
    await repo.upsert(
      {
        ...core,
        externalId: `${core.externalId}-later`,
        startsAt: core.startsAt.replace('20:00', '22:00'),
        endsAt: null,
      },
      now,
    );
    await repo.upsert(
      { ...core, externalId: `${core.externalId}-other-venue`, venue: 'Druga dvorana' },
      now,
    );
    assert.equal((await repo.events()).length, 3);
  } finally {
    await repo.close();
  }
});

function recordedListing(s: FixtureSource): string {
  const $ = load(s.listingHtml),
    paths = new Set(s.details.map((page) => page.url));
  const selector =
    s.id === 'gisko'
      ? '.td-module-title a'
      : s.id === 'dkolektiv'
        ? '.title a'
        : s.id === 'hnk-osijek'
          ? '.slider--schedule__item'
          : 'a.event-card-background';
  $(selector).each((_i, el) => {
    const row = $(el),
      link = s.id === 'hnk-osijek' ? row.parent('a') : row;
    if (!paths.has((link.attr('href') ?? '').trim())) (s.id === 'hnk-osijek' ? link : row).remove();
  });
  $('.pagination').remove();
  return $.html();
}

test('recorded sources pass bounded cached fetch → collection → public feed with no AI and stable repeated runs', async (context) => {
  context.mock.timers.enable({ apis: ['Date'], now });
  const directory = await mkdtemp(join(tmpdir(), 'wagz-local-replay-'));
  const configured = sources.filter((item) => fixture.sources.some((s) => s.id === item.id));
  const repo = new Repository(':memory:', configured);
  const config: Config = {
    host: '127.0.0.1',
    port: 3000,
    databasePath: ':memory:',
    adminKey: 'test',
    autoPublish: true,
    fetchOnStart: false,
    fetchIntervalMinutes: 360,
    ai: { apiKey: '', model: 'unused', monthlyBudgetUsd: 0, searchEnabled: false },
  };
  const offline = async () => {
    throw new Error('Recorded replay must not access the network.');
  };
  try {
    for (const s of fixture.sources)
      for (const page of [{ url: s.url, html: recordedListing(s) }, ...s.details]) {
        await writeFile(
          join(directory, `${createHash('sha256').update(page.url).digest('hex')}.json`),
          JSON.stringify({ ...page, fetchedAt: now.toISOString() }),
        );
      }
    const limited = await fetchSource('gisko', {
      now,
      cacheDir: directory,
      fetch: offline,
      maxDetails: 1,
    });
    assert.equal(limited.events.length, 1);
    assert.ok(limited.warnings.some((warning) => /ograničenje je 1/.test(warning)));
    const service = new WagzService(repo, config, (id) =>
      fetchSource(id, { now, cacheDir: directory, fetch: offline, maxDetails: 10 }),
    );
    assert.equal(await service.collect(), true);
    const events = await repo.events();
    assert.equal(events.length, 13);
    assert.equal((await repo.publicEvents(now)).length, 12);
    const held = events.find((event) => /Slamanje/.test(event.title))!;
    assert.equal(held.publication, 'draft');
    assert.equal(held.venue, 'Club Oxygene');
    assert.ok((await repo.runs()).every((run) => run.pagesFetched === 0));
    assert.equal(await repo.aiSpent(), 0);
    await service.collect();
    assert.equal((await repo.events()).length, 13);
    assert.equal((await repo.publicEvents(now)).length, 12);
  } finally {
    await repo.close();
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-local-replay-'));
    await rm(resolved, { recursive: true, force: true });
  }
});
