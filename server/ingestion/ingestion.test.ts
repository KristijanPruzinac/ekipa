import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import {
  parseCalendarDate,
  parseKcDetail,
  parseKcListing,
  parseTourismCalendar,
  zagrebTime,
} from './parsers.ts';
import { readSourcePage, trustedSourceUrl } from './reader.ts';

test('Croatian calendar ranges preserve real dates and reject unknown days', () => {
  assert.deepEqual(parseCalendarDate('23. – 25.10. 2026.'), {
    start: '2026-10-23',
    end: '2026-10-25',
  });
  assert.deepEqual(parseCalendarDate('30.5. – 29.8.2026.'), {
    start: '2026-05-30',
    end: '2026-08-29',
  });
  assert.deepEqual(parseCalendarDate('21.03 – 22.03.2026.'), {
    start: '2026-03-21',
    end: '2026-03-22',
  });
  assert.deepEqual(parseCalendarDate('16. do 20.09.2026.'), {
    start: '2026-09-16',
    end: '2026-09-20',
  });
  assert.deepEqual(parseCalendarDate('3.10.', 2026), { start: '2026-10-03', end: null });
  assert.equal(parseCalendarDate('LISTOPAD 2026.'), null);
  assert.equal(parseCalendarDate('31.02.2026.'), null);
});

test('Zagreb offsets change at DST boundaries; no invented time for ambiguous hours', () => {
  assert.equal(zagrebTime('2026-10-05', '20:00'), '2026-10-05T20:00:00+02:00');
  assert.equal(zagrebTime('2026-10-27', '20:00'), '2026-10-27T20:00:00+01:00');
  assert.equal(zagrebTime('2026-03-29', '02:30'), '2026-03-29');
  assert.equal(zagrebTime('2026-10-25', '02:30'), '2026-10-25');
  assert.equal(zagrebTime('2026-10-05'), '2026-10-05');
});

test('tourism calendar leaves unknown venue/time empty and warns about month-only events', () => {
  const html = `<div class="postcontent text-center">
    <p>LISTOPAD 2026.</p><p>23. – 25.10.2026.<br><strong>Festival</strong><br>#kultura</p>
    <p>listopad 2026.<br><strong>HeadOnEast</strong><br>tzosijek.hr</p>
    <p>3.09.2026.<br><strong>Prošli koncert</strong><br>#glazba</p></div>`;
  const result = parseTourismCalendar(html, new Date('2026-10-03T10:00:00Z'));
  assert.equal(result.events.length, 1);
  assert.equal(result.events[0].startsAt, '2026-10-23');
  assert.equal(result.events[0].venue, null);
  assert.equal(result.events[0].endsAt, '2026-10-25');
  assert.equal(result.extractionPages.length, 0);
  assert.equal(result.warnings.length, 1);
  const moved = parseTourismCalendar(
    html.replace('23. – 25.10.', '24. – 26.10.'),
    new Date('2026-10-03T10:00:00Z'),
  );
  assert.equal(moved.events[0].externalId, result.events[0].externalId);
});

test('KC ignores past events and subscriptions; detail uses source facts and stable identity', () => {
  const row = (title: string, slug: string, dates: string) =>
    `<div class="datatable__item"><span class="pattern--date">${dates}</span><h4><a href="/dogadjanja/${slug}">${title}</a></h4></div>`;
  const listing = parseKcListing(
    row('5.10. HARLEQUIN ART COLLECTIVE', 'harlequin', '05/10/26 - 05/10/26 @ 20:00') +
      row('UPIS PRETPLATE', 'pretplata', '01/10/26 - 01/12/26 @ 20:00') +
      row('Stari koncert', 'old', '01/01/24 - 01/01/24 @ 20:00'),
    new Date('2026-10-03T10:00:00Z'),
  );
  assert.equal(listing.entries.length, 1);
  assert.equal(listing.entries[0].startsAt, '2026-10-05T20:00:00+02:00');
  const html = `<h1 class="news-item__title">5.10. HARLEQUIN ART COLLECTIVE</h1><div class="news-item__content"><span class="pattern--date">05/10/26</span><span class="pattern--time">20:00</span><article class="article"><p>Koncert u Dvorani Franjo Krežma.</p><p>Ulaz na koncert je slobodan.</p></article></div>`;
  const result = parseKcDetail(html, listing.entries[0]);
  assert.equal(result.event.venue, 'Dvorana Franjo Krežma');
  assert.equal(result.event.price, 'Besplatno');
  assert.equal(result.event.category, 'music');
  assert.equal(result.event.address, null);
  assert.equal(result.extraction, null);
  const changed = parseKcDetail(html.replace('05/10/26', '27/10/26'), listing.entries[0]);
  assert.equal(changed.event.startsAt, '2026-10-27T20:00:00+01:00');
  assert.equal(changed.event.externalId, result.event.externalId);
  assert.equal(changed.warnings.length, 1);
});

test('changed HTML fails visibly rather than pretending the calendar is empty', () => {
  assert.throws(() => parseKcListing('<html>maintenance</html>'), /strukturu/);
  assert.throws(() => parseTourismCalendar('<html>maintenance</html>'), /struktura/);
});

test('public synopsis uses facts while private AI evidence retains the complete article', () => {
  const body = `${'Izvorni osvrt o programu. '.repeat(240)}Koncert u Dvorani Franjo Krežma. Završna rečenica izvornog članka.`;
  const html = `<h1 class="news-item__title">Posebna večer</h1><div class="news-item__content"><span class="pattern--date">05/10/26</span><span class="pattern--time">20:00</span><article class="article"><p>${body}</p></article></div>`;
  const result = parseKcDetail(html, {
    title: 'Posebna večer',
    url: 'https://kulturni-centar.hr/dogadjanja/posebna-vecer',
    startsAt: '2026-10-05',
    endsAt: null,
    dateText: '05/10/26',
  });
  assert.equal(result.event.category, 'music');
  assert.equal(result.event.venue, 'Dvorana Franjo Krežma');
  assert.ok(result.event.description.length < 250);
  assert.match(result.event.description, /Dvorana Franjo Krežma/);
  assert.doesNotMatch(result.event.description, /Izvorni osvrt|Završna rečenica|besplatan/);
  assert.ok(result.extraction?.text.endsWith(body));
  assert.deepEqual(result.warnings, []);
});

test('reader rejects untrusted hosts and uses the API with a reusable disk cache', async () => {
  assert.throws(() => trustedSourceUrl('http://kulturni-centar.hr/dogadjanja/one'));
  assert.throws(() => trustedSourceUrl('https://kulturni-centar.hr.evil.test/'));
  assert.throws(() => trustedSourceUrl('https://user:secret@kulturni-centar.hr/'));
  const directory = await mkdtemp(join(tmpdir(), 'wagz-reader-test-'));
  let calls = 0;
  const mockFetch = (async (input: string | URL | Request, init?: RequestInit) => {
    calls++;
    assert.equal(String(input), 'https://r.jina.ai/https://kulturni-centar.hr/dogadjanja/test');
    assert.equal(new Headers(init?.headers).get('x-respond-with'), 'html');
    assert.equal(new Headers(init?.headers).get('x-max-tokens'), null);
    return new Response('<html><body>event</body></html>');
  }) as typeof fetch;
  try {
    const first = await readSourcePage('https://kulturni-centar.hr/dogadjanja/test', {
      cacheDir: directory,
      fetch: mockFetch,
    });
    const second = await readSourcePage('https://kulturni-centar.hr/dogadjanja/test', {
      cacheDir: directory,
      fetch: mockFetch,
    });
    assert.equal(first.cached, false);
    assert.equal(second.cached, true);
    assert.equal(calls, 1);
  } finally {
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-reader-test-'));
    await rm(resolved, { recursive: true, force: true });
  }
});
