import assert from 'node:assert/strict';
import test from 'node:test';
import { isFeaturedEvent, rankForAudience } from '../shared/discovery.ts';
import type { PublicEvent } from '../shared/types.ts';

const url = 'https://example.org/screening';
const film = (extra: Partial<PublicEvent> = {}): PublicEvent => ({
  id: 'film',
  title: 'Filmska projekcija',
  description: '',
  category: 'film',
  startsAt: '2026-10-04T18:00:00+02:00',
  endsAt: null,
  venue: 'Gradsko kino',
  address: null,
  city: 'Zagreb',
  price: null,
  status: 'scheduled',
  sources: [{ sourceId: 'source', sourceName: 'Organizator', url, lastSeenAt: '2026-10-03' }],
  firstSeenAt: '2026-10-03',
  updatedAt: '2026-10-03',
  ...extra,
});
const discovery = (screening: unknown) =>
  ({
    audiences: [],
    audienceEvidence: [],
    prominence: null,
    free: false,
    screening,
  }) as PublicEvent['discovery'];
const routine = {
  kind: 'routine',
  reason: 'Redovni kino repertoar s više termina.',
  sourceUrl: url,
};

test('Featured excludes only verified routine films, independently of city or venue', () => {
  for (const city of ['Osijek', 'Zagreb', 'Rijeka']) {
    const event = film({ city, venue: 'Novo kino', discovery: discovery(routine) });
    assert.equal(isFeaturedEvent(event), false);
    assert.equal(isFeaturedEvent({ ...event, category: 'other' }), true);
    assert.equal(isFeaturedEvent({ ...event, category: 'community' }), true);
  }
});

test('outdoor, rooftop, special, absent, malformed and unverified evidence stays Featured', () => {
  for (const title of ['Kino na otvorenom', 'Rooftop projekcija', 'Film uz razgovor s autorom']) {
    assert.equal(isFeaturedEvent(film({ title })), true);
    assert.equal(
      isFeaturedEvent(film({ title, discovery: discovery({ ...routine, kind: 'special' }) })),
      true,
    );
  }
  for (const screening of [
    undefined,
    {},
    { ...routine, kind: 'unknown' },
    { ...routine, reason: null },
    { ...routine, reason: '' },
    { ...routine, sourceUrl: null },
    { ...routine, sourceUrl: 'https://example.org/unrelated' },
    { ...routine, sourceUrl: 'javascript:alert(1)' },
  ])
    assert.equal(isFeaturedEvent(film({ discovery: discovery(screening) })), true);
});

test('Featured filtering preserves chronology and never changes the full Film selection', () => {
  const events = [
    film({ id: 'late', startsAt: '2026-10-06' }),
    film({ id: 'routine', discovery: discovery(routine) }),
    film({ id: 'early', startsAt: '2026-10-03' }),
  ];
  const ranked = rankForAudience(events).map(({ event }) => event);
  assert.deepEqual(
    ranked.filter(isFeaturedEvent).map(({ id }) => id),
    ['early', 'late'],
  );
  assert.deepEqual(
    ranked.filter(({ category }) => category === 'film').map(({ id }) => id),
    ['early', 'routine', 'late'],
  );
});
