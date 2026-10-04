import test from 'node:test';
import assert from 'node:assert/strict';
import {
  durationLabel,
  eventDurationText,
  isOngoing,
  knownEnd,
  rankForAudience,
  sourceAudienceEvidence,
  sourceAudienceLabels,
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

test('all legacy audience choices preserve identical stable Zagreb chronology and every event', () => {
  const events = [
    event('later', '2026-10-04', { discovery: evidence('students') }),
    event('same-day', '2026-10-02T22:15:00Z', { category: 'nightlife', price: 'Besplatno' }),
    event('unknown', '2026-10-03'),
    event('ongoing', '2026-10-01', { endsAt: '2026-10-05' }),
    event('same-instant', '2026-10-03T00:15:00+02:00', { status: 'cancelled' }),
  ];
  const copy = structuredClone(events);
  events.forEach(Object.freeze);
  Object.freeze(events);
  for (const audience of ['all', 'students', 'adults', 'seniors'] as const) {
    assert.deepEqual(ids(rankForAudience(events, audience, '2026-10-03T12:00:00Z')), [
      'ongoing',
      'unknown',
      'same-day',
      'same-instant',
      'later',
    ]);
  }
  assert.deepEqual(events, copy);
});

test('source audience labels allow multiple mentions, deduplicate and keep a fixed order', () => {
  const sourceUrl = 'https://example.org/event';
  const tagged = event('tagged', '2026-10-03', {
    sources: [{ sourceId: 'source', sourceName: 'Source', url: sourceUrl, lastSeenAt: '' }],
    discovery: {
      ...evidence('students'),
      audienceEvidence: [
        { audience: 'seniors', reason: 'Poziv starijima.', sourceUrl },
        { audience: 'students', reason: 'Studentski popust.', sourceUrl },
        { audience: 'students', reason: 'Poziv studentima.', sourceUrl },
      ],
    },
  });
  assert.deepEqual(sourceAudienceLabels(tagged), ['Studenti', 'Stariji']);
  assert.deepEqual(
    sourceAudienceEvidence(tagged).map((item) => item.reason),
    ['Studentski popust.', 'Poziv starijima.'],
  );
  for (const audience of ['all', 'students', 'adults', 'seniors'] as const) {
    assert.deepEqual(ids(rankForAudience([tagged], audience)), ['tagged']);
  }
});

test('tags reject bare audiences, genre, free entry, missing reason, unrelated or unsafe evidence', () => {
  const sourceUrl = 'https://example.org/event';
  const template = event('music', '2026-10-03', {
    title: 'Studentska radionica i koncert za sve',
    category: 'music',
    price: 'Besplatno',
    sources: [{ sourceId: 'source', sourceName: 'Source', url: sourceUrl, lastSeenAt: '' }],
  });
  assert.deepEqual(sourceAudienceLabels(template), []);
  assert.deepEqual(
    sourceAudienceLabels({
      ...template,
      discovery: { ...evidence('students'), audienceEvidence: [] },
    }),
    [],
  );
  for (const [audience, reason, url] of [
    ['students', ' ', sourceUrl],
    ['unknown', 'Program.', sourceUrl],
    ['students', 'Program.', 'https://unrelated.example/event'],
    ['students', 'Program.', 'javascript:alert(1)'],
    ['students', 'Program.', 'https://user:password@example.org/event'],
    ['students', 'Program.', 'https://example.invalid/event'],
  ]) {
    const invalid = {
      ...template,
      discovery: {
        ...evidence('students'),
        audienceEvidence: [{ audience, reason, sourceUrl: url }],
      },
    } as WagzEvent;
    assert.deepEqual(sourceAudienceLabels(invalid), []);
    if (url !== 'https://unrelated.example/event') {
      invalid.sources = [{ ...template.sources[0], url }];
      assert.deepEqual(sourceAudienceLabels(invalid), []);
    }
  }
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
      // The nested range is inside; the long festival wraps around it, so nothing crosses.
      { start: 0, end: 4, lane: 1 },
      { start: 1, end: 2, lane: 0 },
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
