import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { COUNTY_URL, parseCountyDetail, parseCountyListing } from './county.ts';
import { fetchSource } from './index.ts';
import type { ListingEntry } from './parsers.ts';

const now = new Date('2026-10-03T10:00:00Z');
const url = 'https://visitslavoniabaranja.com/event/headoneast-festival-osijek/';
const entry: ListingEntry = {
  title: 'HeadOnEast festival, Osijek',
  url,
  startsAt: '2026-10-02',
  endsAt: '2026-10-04',
  dateText: '2026-10-02 – 2026-10-04',
};

// Reduced reproducer of the official Jina HTML inspected on 2026-10-03.
// Capitalized Location and offset-free local timestamps are emitted by this source.
const schema = {
  '@context': 'http://schema.org/',
  '@type': 'Event',
  name: entry.title,
  startDate: '2026-10-02 18:00:00',
  endDate: '2026-10-04 02:00:00',
  eventStatus: 'EventScheduled',
  Location: { '@type': 'Place', name: 'Trg sv. Trojstva', address: 'Trg sv. Trojstva' },
};

function detail(data: Record<string, unknown> = schema, city = 'Osijek') {
  return `<html><body><script type="application/ld+json">${JSON.stringify(data)}</script>
    <div class="c-event__content"><div class="c-event__info"><span class="c-event__info__type">Festival Glazba</span><span class="c-event__info__published">Objavljeno 13/03/2026</span></div><h1>${entry.title}</h1>
    <div><p>Festival u Osijeku.</p></div></div>
    <aside class="c-aside"><div class="c-info-tag"><i class="u-icon--location"></i><span>${city}</span></div><div class="c-info-tag"><i class="u-icon--building"></i><span>Trg sv. Trojstva</span></div></aside>
    <footer>Turistička zajednica, Osijek</footer></body></html>`;
}

function row(
  title = entry.title,
  href = url,
  start = entry.startsAt,
  end = entry.endsAt,
  region = 'osijek_i_podunavlje',
) {
  return `<div data-destination="${region}" data-start="${start}" data-end="${end ?? ''}"><a class="c-btn--card" href="${href}"><p>${title}</p></a></div>`;
}

test('county discovers ongoing multi-day events and hidden cards using full source dates', () => {
  const parsed = parseCountyListing(
    `<div id="event-listing-view">${row()}
    <section hidden>${row('Nested unrelated copy')}</section>
    ${row('Outside Osijek region', '/event/baranja/', '2026-10-03', '2026-10-04', 'baranja')}
    ${row('Past', '/event/past/', '2026-09-01', '2026-09-02')}
    ${row('Invalid', '/event/invalid/', '2026-02-31', '')}
    ${row('Untrusted', 'https://evil.test/event/one/')}
    ${row('Other approved host', 'https://kulturni-centar.hr/event/one/')}
    ${row()}
    <div hidden data-start="2027-01-02" data-end="2027-01-03" data-destination="osijek_i_podunavlje"><a class="c-btn--card" href="/event/new-year/">Next year</a></div>
    </div>`,
    now,
  );
  assert.equal(parsed.discovered, 8);
  assert.equal(parsed.entries.length, 2);
  assert.deepEqual(parsed.entries[0], entry);
  assert.equal(parsed.entries[1].startsAt, '2027-01-02');
  assert.equal(parsed.skipped, 6);
  assert.equal(parsed.warnings.length, 3);
});

test('county HeadOnEast imports official JSON-LD dates and venue instead of publication date', () => {
  const result = parseCountyDetail(detail(), entry, now);
  assert.equal(result.event?.sourceId, 'tz-obz');
  assert.equal(result.event?.sourceUrl, url);
  assert.equal(result.event?.startsAt, '2026-10-02T18:00:00+02:00');
  assert.equal(result.event?.endsAt, '2026-10-04');
  assert.equal(result.event?.venue, 'Trg sv. Trojstva');
  assert.equal(result.event?.city, 'Osijek');
  assert.equal(result.event?.price, null);
  assert.equal(result.event?.discovery?.prominence?.kind, 'festival');
  assert.equal(result.event?.discovery?.free, false);
  assert.match(result.extraction?.text ?? '', /2026-10-02T18:00:00\+02:00/);
  const moved = parseCountyDetail(
    detail({ ...schema, startDate: '2026-10-05', endDate: '2026-10-06' }),
    entry,
    now,
  );
  assert.equal(moved.event?.startsAt, '2026-10-05');
  assert.equal(moved.event?.externalId, result.event?.externalId);
  assert.equal(moved.warnings.length, 1);
});

test('county rejects invalid dates and requires actual Osijek location evidence', () => {
  assert.throws(
    () => parseCountyDetail(detail({ ...schema, startDate: '2026-02-31' }), entry, now),
    /datum/,
  );
  assert.throws(
    () => parseCountyDetail(detail({ ...schema, endDate: '2026-10-01' }), entry, now),
    /datum/,
  );
  assert.throws(
    () => parseCountyDetail(detail({ ...schema, startDate: undefined }), entry, now),
    /datum/,
  );
  assert.equal(parseCountyDetail(detail(schema, 'Dalj'), entry, now).event, null);
  const unknownCity = parseCountyDetail(detail(schema, ''), entry, now);
  assert.equal(unknownCity.event, null);
  assert.equal(unknownCity.extraction, null);
  assert.equal(unknownCity.warnings.length, 1);
  assert.equal(parseCountyDetail(detail(), entry, new Date('2026-10-05T10:00:00Z')).event, null);
});

test('county decodes source JSON-LD entities and leaves placeholder times unknown', () => {
  const title = 'Tehnicoolum – sajam tehničke kulture u Osijeku';
  const html = detail({
    ...schema,
    name: 'Tehnicoolum &#8211; sajam tehničke kulture u Osijeku',
    startDate: '2026-10-23 10:00:00',
    endDate: '2026-10-24 18:00:00',
  }).replace(`<h1>${entry.title}</h1>`, `<h1>${title}</h1>`);
  assert.equal(parseCountyDetail(html, entry, now).event?.title, title);
  const unknownTime = parseCountyDetail(
    detail({ ...schema, startDate: '2026-11-26 00:00:00', endDate: '2026-11-27 00:00:00' }),
    entry,
    now,
  );
  assert.equal(unknownTime.event?.startsAt, '2026-11-26');
  assert.equal(unknownTime.event?.endsAt, '2026-11-27');
});

test('county structured cancellation and free admission survive graph wrappers', () => {
  const free = {
    ...schema,
    eventStatus: 'https://schema.org/EventCancelled',
    offers: { price: '0' },
  };
  const result = parseCountyDetail(detail({ '@graph': [free] }), entry, now);
  assert.equal(result.event?.status, 'cancelled');
  assert.equal(result.event?.price, 'Besplatno');
  assert.equal(result.event?.discovery?.free, true);
  assert.equal(result.extraction, null);
  const subprogram = detail().replace(
    'Festival u Osijeku.',
    'Festival u Osijeku. Besplatna radionica za studente.',
  );
  assert.equal(parseCountyDetail(subprogram, entry, now).event?.price, null);
});

test('county changed structure fails visibly; an explicit empty list is accepted', () => {
  assert.throws(() => parseCountyListing('<html>maintenance</html>', now), /struktura/);
  assert.throws(() => parseCountyDetail('<html>maintenance</html>', entry, now), /sadržaj/);
  assert.throws(
    () =>
      parseCountyDetail(detail({ '@type': 'WebPage', datePublished: '2026-10-02' }), entry, now),
    /strukturirani/,
  );
  assert.deepEqual(
    parseCountyListing(
      '<div id="event-listing-view"><div class="js-events-empty"></div></div>',
      now,
    ).entries,
    [],
  );
});

test('county source fetches discovered details through Jina and reuses its cache', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-county-test-'));
  const calls: string[] = [];
  const mockFetch = (async (input: string | URL | Request) => {
    const request = String(input);
    calls.push(request);
    if (request === `https://r.jina.ai/${COUNTY_URL}`)
      return new Response(`<html><body><div id="event-listing-view">${row()}</div></body></html>`);
    assert.equal(request, `https://r.jina.ai/${url}`);
    return new Response(detail());
  }) as typeof fetch;
  try {
    const options = { now, cacheDir: directory, fetch: mockFetch };
    const first = await fetchSource('tz-obz', options);
    assert.equal(first.events.length, 1);
    assert.equal(first.events[0].title, entry.title);
    assert.equal(first.pagesFetched, 2);
    const second = await fetchSource('tz-obz', options);
    assert.equal(second.events.length, 1);
    assert.equal(second.pagesFetched, 0);
    assert.equal(calls.length, 2);
  } finally {
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-county-test-'));
    await rm(resolved, { recursive: true, force: true });
  }
});
