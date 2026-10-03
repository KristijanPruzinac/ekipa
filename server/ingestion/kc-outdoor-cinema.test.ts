import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { Repository } from '../repository.ts';
import { WagzService } from '../service.ts';
import type { Config } from '../config.ts';
import { fetchSource, sources } from './index.ts';
import { KC_URL, parseKcDetail, parseKcListing } from './parsers.ts';
import { isFeaturedEvent } from '../../shared/discovery.ts';

const fixture = JSON.parse(
  await readFile(new URL('./fixtures/kc-outdoor-cinema.json', import.meta.url), 'utf8'),
) as { entries: { url: string; listingHtml: string; detailHtml: string }[] };
const beforeScreenings = new Date('2026-08-23T10:00:00Z');
const listingHtml = fixture.entries.map((entry) => entry.listingHtml).join('\n');

test('actual KC outdoor cinema announcements retain their exact venue, including a rain relocation', () => {
  const listing = parseKcListing(listingHtml, beforeScreenings);
  assert.equal(listing.entries.length, 3);
  const events = listing.entries.map(
    (entry) =>
      parseKcDetail(fixture.entries.find((page) => page.url === entry.url)!.detailHtml, entry)
        .event,
  );
  assert.deepEqual(
    events.map(({ startsAt, venue }) => ({ startsAt, venue })),
    [
      {
        startsAt: '2026-08-24T20:00:00+02:00',
        venue: 'Dvorište Prehrambeno-tehnološkog fakulteta',
      },
      { startsAt: '2026-08-25T20:00:00+02:00', venue: 'Mala dvorana Kulturnog centra' },
      {
        startsAt: '2026-08-26T20:00:00+02:00',
        venue: 'Dvorište Prehrambeno-tehnološkog fakulteta',
      },
    ],
  );
  assert.equal(events[0].price, null, 'A venue must not imply free admission.');
  assert.equal(events[1].price, 'Besplatno');
  assert.equal(events[2].price, null);
});

test('KC schedule venues cannot leak from another date, clock, range or superseded location', () => {
  const page = fixture.entries[0];
  const entry = parseKcListing(page.listingHtml, beforeScreenings).entries[0];
  const paragraph =
    '<p><u>Ponedjeljak, 24.8./20.00 sati/ Dvorište Prehrambeno-tehnološkog fakulteta</u></p>';
  assert.ok(page.detailHtml.includes(paragraph));
  const venueFrom = (replacement: string) =>
    parseKcDetail(page.detailHtml.replace(paragraph, replacement), entry).event.venue;
  assert.equal(venueFrom(paragraph.replace('24.8.', '25.8.')), null);
  assert.equal(venueFrom(paragraph.replace('20.00', '21.00')), null);
  assert.equal(venueFrom(paragraph.replace('24.8.', '24.8.2025.')), null);
  assert.equal(
    venueFrom(paragraph.replace('Dvorište Prehrambeno-tehnološkog fakulteta', 'Lokacija naknadno')),
    null,
  );
  assert.equal(venueFrom(paragraph.replace('<u>', '<del>').replace('</u>', '</del>')), null);
  assert.equal(
    venueFrom(paragraph.replace('<u>', '<u style="text-decoration: line-through;">')),
    null,
  );
  assert.equal(
    venueFrom(paragraph + '<p>Projekcija se premješta; nova lokacija bit će objavljena.</p>'),
    null,
  );
  assert.equal(
    venueFrom(
      paragraph + paragraph.replace('Dvorište Prehrambeno-tehnološkog fakulteta', 'Drugo dvorište'),
    ),
    null,
  );
  assert.equal(
    parseKcDetail(page.detailHtml, { ...entry, endsAt: '2026-08-26' }).event.venue,
    null,
  );
  assert.equal(
    venueFrom(paragraph + '<p>Utorak, 25.8./20.00 sati/ Drugo dvorište</p>'),
    'Dvorište Prehrambeno-tehnološkog fakulteta',
  );
  assert.equal(
    venueFrom('<p><del>U Dvorani Franjo Krežma</del></p>' + paragraph),
    'Dvorište Prehrambeno-tehnološkog fakulteta',
  );
  assert.equal(
    venueFrom('<p style="text-decoration: line-through">U Maloj dvorani KC-a</p>' + paragraph),
    'Dvorište Prehrambeno-tehnološkog fakulteta',
  );
});

test('recorded cinema pages pass offline fetch, collection and public feed with AI disabled at a fixed historical date', async (context) => {
  context.mock.timers.enable({ apis: ['Date'], now: beforeScreenings });
  const source = sources.find((item) => item.id === 'kc-osijek')!;
  const repo = new Repository(':memory:', [source]);
  const directory = await mkdtemp(join(tmpdir(), 'wagz-cinema-replay-'));
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
  try {
    for (const page of [
      { url: KC_URL, html: listingHtml },
      ...fixture.entries.map((page) => ({ url: page.url, html: page.detailHtml })),
    ]) {
      await writeFile(
        join(directory, `${createHash('sha256').update(page.url).digest('hex')}.json`),
        JSON.stringify({
          ...page,
          html: `<html><body>${page.html}</body></html>`,
          fetchedAt: beforeScreenings.toISOString(),
        }),
      );
    }
    let fetches = 0;
    const service = new WagzService(repo, config, (id) =>
      fetchSource(id, {
        now: beforeScreenings,
        cacheDir: directory,
        fetch: async () => {
          fetches++;
          throw new Error('Offline replay must not use the network.');
        },
      }),
    );
    assert.equal(await service.collect(), true);
    assert.equal(fetches, 0);
    assert.equal((await repo.events()).length, 3);
    assert.equal((await repo.publicEvents(beforeScreenings)).length, 3);
    const screenings = await repo.publicEvents(beforeScreenings);
    // AI disabled: no event is left as `other`; each keeps its source category.
    assert.ok(screenings.every((event) => event.category !== 'other'));
    assert.ok(screenings.every((event) => !event.discovery?.screening));
    assert.ok(
      screenings.every(isFeaturedEvent),
      'Actual courtyard screenings and the rain relocation stay Featured.',
    );
    assert.ok((await repo.events()).every((event) => event.publication === 'published'));
    assert.equal((await repo.runs())[0].pagesFetched, 0);
    assert.equal(await repo.aiSpent(), 0);
    assert.equal((await repo.publicEvents(new Date('2026-08-26T10:00:00Z'))).length, 1);
    assert.equal((await repo.publicEvents(new Date('2026-08-27T10:00:00Z'))).length, 0);
    assert.equal(parseKcListing(listingHtml, new Date('2026-08-27T10:00:00Z')).entries.length, 0);
  } finally {
    await repo.close();
    const resolved = await realpath(directory);
    assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    assert.ok(basename(resolved).startsWith('wagz-cinema-replay-'));
    await rm(resolved, { recursive: true, force: true });
  }
});
