import assert from 'node:assert/strict';
import test from 'node:test';
import { geocodeKey, geocodeVenue, namesMatch, type GeoPoint } from './geocode.ts';
import { Repository } from './repository.ts';

const centre: GeoPoint = { lat: 45.555, lon: 18.695 };
const reply = (rows: unknown[]) =>
  (async (url: string | URL | Request, init?: RequestInit) => {
    assert.match(String(url), /^https:\/\/nominatim\.openstreetmap\.org\/search\?/);
    assert.match(String((init?.headers as Record<string, string>)['User-Agent']), /WagZ/);
    return new Response(JSON.stringify(rows), { status: 200 });
  }) as typeof fetch;

test('a specific place inside the city is placed', async () => {
  const point = await geocodeVenue(
    ['Hrvatsko narodno kazalište'],
    'Osijek',
    centre,
    reply([
      {
        lat: '45.5590123',
        lon: '18.6789456',
        addresstype: 'theatre',
        name: 'Hrvatsko narodno kazalište u Osijeku',
      },
    ]),
  );
  assert.deepEqual(point, { lat: 45.559012, lon: 18.678946 });
});

test('city-level, far-away and empty hits give no pin rather than a wrong one', async () => {
  for (const rows of [
    [{ lat: '45.555', lon: '18.695', addresstype: 'city' }],
    [{ lat: '45.81', lon: '15.98', addresstype: 'amenity' }],
    [],
  ])
    assert.equal(await geocodeVenue(['Plesni klub D&D'], 'Osijek', centre, reply(rows)), null);
});

test('the public feed carries cached coordinates for the event venue only', async () => {
  const repo = new Repository(':memory:', [
    { id: 'test', name: 'Test', url: 'https://example.org', description: '', enabled: true },
  ]);
  try {
    await repo.upsert({
      sourceId: 'test',
      sourceUrl: 'https://example.org/e',
      externalId: '1',
      title: 'Predstava',
      description: '',
      startsAt: '2099-10-10T20:00:00+02:00',
      endsAt: null,
      venue: 'HNK Osijek',
      address: null,
      city: 'Osijek',
      category: 'theatre',
      price: null,
      status: 'scheduled',
    });
    assert.equal((await repo.publicEvents())[0].location, undefined);
    await repo.cache(geocodeKey('HNK Osijek', 'Osijek'), { lat: 45.559, lon: 18.679, at: 'x' });
    assert.deepEqual((await repo.publicEvents())[0].location, { lat: 45.559, lon: 18.679 });
    await repo.cache(geocodeKey('HNK Osijek', 'Osijek'), { none: true, at: 'x' });
    assert.equal((await repo.publicEvents())[0].location, undefined);
  } finally {
    await repo.close();
  }
});

test('a loose name match is not a pin; inflected and city words are tolerated', () => {
  assert.equal(
    namesMatch('Gospodarska zona 10', 'Gospodarski centar Osijek, Osijek', 'Osijek'),
    false,
  );
  assert.equal(
    namesMatch('Osnovna škola Mladost', "Osnovna škola ''Mladost'' Osijek, Osijek", 'Osijek'),
    true,
  );
  assert.equal(
    namesMatch('Trg Svetog Trojstva', 'Trg Svetog Trojstva, Tvrđa, Osijek', 'Osijek'),
    true,
  );
  assert.equal(
    namesMatch(
      'Hrvatsko narodno kazalište u Osijeku',
      'Hrvatsko narodno kazalište, Osijek',
      'Osijek',
    ),
    true,
  );
});

test('queries are tried in order until one names a real place', async () => {
  const asked: string[] = [];
  const fetchImpl = (async (url: string | URL | Request) => {
    const q = new URL(String(url)).searchParams.get('q')!;
    asked.push(q);
    return new Response(
      JSON.stringify(
        q.startsWith('Kulturni centar')
          ? [
              {
                lat: '45.555978',
                lon: '18.695191',
                addresstype: 'amenity',
                name: 'Kulturni centar Osijek',
              },
            ]
          : [],
      ),
    );
  }) as typeof fetch;
  const point = await geocodeVenue(
    ['Mala dvorana Kulturnog centra', 'Kulturni centar Osijek'],
    'Osijek',
    centre,
    fetchImpl,
  );
  assert.deepEqual(point, { lat: 45.555978, lon: 18.695191 });
  assert.deepEqual(asked, [
    'Mala dvorana Kulturnog centra, Osijek',
    'Kulturni centar Osijek, Osijek',
  ]);
});
