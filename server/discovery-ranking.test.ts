import test from 'node:test';
import assert from 'node:assert/strict';
import { rankForAudience, themeForCategory } from '../shared/discovery.ts';
import { categories, type Audience, type WagzEvent } from '../shared/types.ts';

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
const discovery = (audience?: Audience, festival = false): WagzEvent['discovery'] => ({
  audiences: audience ? [audience] : [],
  audienceEvidence: audience
    ? [{ audience, reason: `Program: ${audience}.`, sourceUrl: 'https://example.org/event' }]
    : [],
  prominence: festival
    ? {
        kind: 'festival',
        label: 'Festival',
        reason: 'Festivalski program.',
        sourceUrl: 'https://example.org/event',
      }
    : null,
  free: false,
});
const ids = (rows: ReturnType<typeof rankForAudience>) => rows.map(({ event }) => event.id);

test('all means actual chronology, including ongoing events and date-only Zagreb days', () => {
  const events = [
    event('later', '2026-10-04', { discovery: discovery('students', true) }),
    event('later-instant', '2026-10-03T18:30:00Z'),
    event('same-local-day', '2026-10-02T22:15:00Z'),
    event('earlier-instant', '2026-10-03T20:00:00+02:00'),
    event('unknown-hour', '2026-10-03', { status: 'cancelled' }),
    event('simultaneous', '2026-10-03T18:00:00Z'),
    event('ongoing', '2026-10-01', { endsAt: '2026-10-05' }),
  ];
  const snapshot = structuredClone(events);
  events.forEach(Object.freeze);
  Object.freeze(events);
  const ranked = rankForAudience(events);
  assert.deepEqual(ids(ranked), [
    'ongoing',
    'unknown-hour',
    'same-local-day',
    'earlier-instant',
    'simultaneous',
    'later-instant',
    'later',
  ]);
  assert.deepEqual(events, snapshot);
  assert.equal(ranked[0].event, events[6]);
  assert.ok(ranked.every(({ recommendation }) => !recommendation.personal));
});

test('audience matches come first; unmatched events remain; prominence never changes order', () => {
  const events = [
    event('other-audience', '2026-10-03', { discovery: discovery('seniors') }),
    event('later-match', '2026-10-06', { discovery: discovery('students', true) }),
    event('first-match', '2026-10-05', { discovery: discovery('students') }),
    event('unlabelled-festival', '2026-10-04', { discovery: discovery(undefined, true) }),
  ];
  const ranked = rankForAudience(events, 'students');
  assert.deepEqual(ids(ranked), [
    'first-match',
    'later-match',
    'other-audience',
    'unlabelled-festival',
  ]);
  assert.deepEqual(
    ranked.map(({ recommendation }) => recommendation.personal),
    [true, true, false, false],
  );
  assert.deepEqual(ranked[0].recommendation.reasons, ['Program: students.']);
  for (const audience of ['all', 'students', 'adults', 'seniors'] as const) {
    const result = rankForAudience(events, audience);
    assert.equal(result.length, events.length);
    assert.deepEqual(new Set(ids(result)), new Set(events.map(({ id }) => id)));
  }
  assert.deepEqual(ids(rankForAudience(events, 'adults')), [
    'other-audience',
    'unlabelled-festival',
    'first-match',
    'later-match',
  ]);
});

test('cancelled and postponed evidence cannot earn a boost, and category never implies age', () => {
  const events = [
    event('cancelled', '2026-10-03', {
      status: 'cancelled',
      discovery: discovery('students', true),
    }),
    event('postponed', '2026-10-03', { status: 'postponed', discovery: discovery('students') }),
    event('nightlife', '2026-10-03', { category: 'nightlife' }),
    event('unchecked-audience-list', '2026-10-04', {
      discovery: { ...discovery()!, audiences: ['students'] },
    }),
    event('source-match', '2026-10-05', { discovery: discovery('students') }),
  ];
  const ranked = rankForAudience(events, 'students');
  assert.deepEqual(ids(ranked), [
    'source-match',
    'cancelled',
    'postponed',
    'nightlife',
    'unchecked-audience-list',
  ]);
  assert.ok(ranked.slice(1).every(({ recommendation }) => !recommendation.personal));
  assert.equal(ranked[1].recommendation.score, 0);
  assert.equal(ranked[2].recommendation.score, 0);
});

test('chronological ties remain stable across Zagreb DST changes and equivalent offsets', () => {
  const events = [
    event('autumn-second', '2026-10-25T02:15:00+01:00'),
    event('autumn-first', '2026-10-25T02:45:00+02:00'),
    event('spring-later', '2026-03-29T03:30:00+02:00'),
    event('spring-earlier', '2026-03-29T01:30:00+01:00'),
    event('same-spring-instant', '2026-03-29T00:30:00Z'),
  ];
  assert.deepEqual(ids(rankForAudience(events)), [
    'spring-earlier',
    'same-spring-instant',
    'spring-later',
    'autumn-first',
    'autumn-second',
  ]);
  assert.deepEqual(rankForAudience([], 'students'), []);
});

test('display-only themes share exact categories and leave other unassigned', () => {
  assert.deepEqual(categories.map(themeForCategory), [
    'go-out',
    'go-out',
    'culture',
    'culture',
    'join-in',
    'join-in',
    null,
  ]);
});
