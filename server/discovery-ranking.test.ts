import test from 'node:test';
import assert from 'node:assert/strict';
import {
  durationLabel,
  eventDurationText,
  isOngoing,
  knownEnd,
  rankForAudience,
  recommendationFor,
  timelineFor,
} from '../shared/discovery.ts';
import type { Audience, WagzEvent } from '../shared/types.ts';

const event = (id: string, startsAt: string, extra: Partial<WagzEvent> = {}): WagzEvent => ({
  id,
  title: id,
  description: '',
  startsAt,
  endsAt: null,
  venue: null,
  address: null,
  city: 'Osijek',
  category: 'other',
  price: null,
  status: 'scheduled',
  publication: 'published',
  sources: [],
  firstSeenAt: '',
  updatedAt: '',
  manuallyEdited: false,
  ...extra,
});
const evidence = (audience: Audience) => ({
  audiences: [audience],
  audienceEvidence: [
    { audience, reason: `Program: ${audience}.`, sourceUrl: 'https://example.org/event' },
  ],
  prominence: null,
  free: false,
});
const ids = (rows: ReturnType<typeof rankForAudience>) => rows.map(({ event }) => event.id);

test('Svi is stable Zagreb chronology, retains ongoing and unknown-time entries without mutation', () => {
  const events = [
    event('later', '2026-10-04', { discovery: evidence('students') }),
    event('same-day', '2026-10-02T22:15:00Z'),
    event('unknown', '2026-10-03'),
    event('ongoing', '2026-10-01', { endsAt: '2026-10-05' }),
    event('same-instant', '2026-10-03T00:15:00+02:00'),
  ];
  const copy = structuredClone(events);
  events.forEach(Object.freeze);
  Object.freeze(events);
  assert.deepEqual(ids(rankForAudience(events)), [
    'ongoing',
    'unknown',
    'same-day',
    'same-instant',
    'later',
  ]);
  assert.deepEqual(events, copy);
  assert.ok(rankForAudience(events).every((row) => row.recommendation.score === 0));
});

test('each preset meaningfully reorders source facts while retaining all events', () => {
  const events = [
    event('music', '2026-10-03', { category: 'music' }),
    event('theatre', '2026-10-04', { category: 'theatre' }),
    event('exhibition', '2026-10-05', { title: 'Izložba', category: 'culture' }),
    event('free-workshop', '2026-10-06', {
      title: 'Radionica',
      category: 'community',
      price: 'Besplatno',
    }),
    event('orchestra', '2026-10-07', { title: 'Koncert orkestra', category: 'music' }),
    event('source', '2026-10-08', { discovery: evidence('students') }),
  ];
  assert.deepEqual(ids(rankForAudience(events, 'students')), [
    'source',
    'free-workshop',
    'orchestra',
    'music',
    'exhibition',
    'theatre',
  ]);
  assert.deepEqual(ids(rankForAudience(events, 'adults')), [
    'free-workshop',
    'exhibition',
    'orchestra',
    'theatre',
    'music',
    'source',
  ]);
  assert.deepEqual(ids(rankForAudience(events, 'seniors')), [
    'exhibition',
    'orchestra',
    'free-workshop',
    'theatre',
    'music',
    'source',
  ]);
  for (const audience of ['all', 'students', 'adults', 'seniors'] as const) {
    const ranked = rankForAudience(events, audience);
    assert.deepEqual(new Set(ids(ranked)), new Set(events.map((item) => item.id)));
    assert.ok(ranked.filter((row) => row.recommendation.personal).length < events.length);
    assert.ok(
      ranked
        .filter((row) => row.recommendation.score > 0)
        .every((row) => row.recommendation.reasons.length),
    );
  }
});

test('source eligibility stays distinct from suggestions; cancelled/postponed get no boost', () => {
  const template = event('workshop', '2026-10-03', {
    title: 'Radionica',
    category: 'community',
    price: 'Besplatno',
    discovery: evidence('students'),
  });
  const profile = { audience: 'students' as const, interests: [] };
  assert.equal(recommendationFor(template, profile).score, 109);
  assert.equal(recommendationFor(template, profile).kind, 'source');
  for (const status of ['cancelled', 'postponed'] as const)
    assert.equal(recommendationFor({ ...template, status }, profile).score, 0);
  const unverified = {
    ...template,
    title: 'Opći program',
    category: 'other' as const,
    price: null,
    discovery: { ...evidence('students'), audienceEvidence: [] },
  };
  assert.equal(recommendationFor(unverified, profile).score, 0);
  const music = event('music', '2026-10-03', { category: 'music' });
  assert.equal(recommendationFor(music, profile).personal, false);
  assert.equal(recommendationFor({ ...music, price: 'Besplatno' }, profile).kind, 'suggestion');
  assert.equal(recommendationFor(music, { audience: 'all', interests: ['music'] }).score, 0);
  assert.equal(recommendationFor({ ...music, price: 'Besplatno za djecu' }, profile).score, 2);
});

test('timeline ranges use real endpoints, chronological overlap lanes and no invented hours', () => {
  const festival = event('HeadOnEast', '2026-10-02T18:00:00+02:00', {
    category: 'music',
    endsAt: '2026-10-04',
  });
  const cycling = event('Febire', '2026-10-04T11:00:00+02:00', {
    category: 'sport',
    endsAt: '2026-10-04T16:00:00+02:00',
  });
  const unknown = event('Unknown', '2026-10-04T17:00:00+02:00');
  const data = timelineFor([festival, cycling, unknown]);
  assert.deepEqual(
    data.moments.map((row) => `${row.event.id}:${row.ending}`),
    ['HeadOnEast:false', 'Febire:false', 'Febire:true', 'Unknown:false', 'HeadOnEast:true'],
  );
  assert.deepEqual(
    data.ranges.map(({ start, end, lane }) => ({ start, end, lane })),
    [
      { start: 0, end: 4, lane: 0 },
      { start: 1, end: 2, lane: 1 },
    ],
  );
  assert.equal(durationLabel(festival), null);
  assert.equal(durationLabel(cycling), '5 h');
  assert.equal(eventDurationText(cycling), 'Traje 5 h');
  assert.equal(eventDurationText(cycling, '2026-10-04T12:00:00Z'), 'Danas do 16:00');
  assert.equal(eventDurationText(festival, '2026-10-03T12:00:00Z'), 'Traje do 4.10.');
  assert.equal(
    eventDurationText(event('dates', '2026-10-02', { endsAt: '2026-10-04' })),
    'Traje 3 dana',
  );
  assert.equal(eventDurationText(unknown), 'Kraj nije naveden');
  assert.equal(durationLabel(unknown), null);
  assert.equal(isOngoing(festival, '2026-10-03T12:00:00Z'), true);
  assert.equal(isOngoing(festival, '2026-10-04T23:00:00Z'), false);
  assert.equal(isOngoing(cycling, '2026-10-04T14:00:00Z'), false);
  assert.equal(isOngoing(unknown, '2026-10-04T18:00:00Z'), false);
  assert.equal(isOngoing({ ...festival, status: 'cancelled' }, '2026-10-03T12:00:00Z'), false);
  assert.equal(knownEnd({ ...cycling, endsAt: '2026-10-03' }), null);
  assert.equal(
    durationLabel(
      event('DST', '2026-10-25T02:30:00+02:00', { endsAt: '2026-10-25T02:30:00+01:00' }),
    ),
    '1 h',
  );
});

test('chronological ties preserve input order through Zagreb DST transitions', () => {
  assert.deepEqual(
    ids(
      rankForAudience([
        event('second', '2026-10-25T02:15:00+01:00'),
        event('first', '2026-10-25T02:45:00+02:00'),
        event('same', '2026-10-25T00:45:00Z'),
      ]),
    ),
    ['first', 'same', 'second'],
  );
});
