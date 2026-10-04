import assert from 'node:assert/strict';
import test from 'node:test';
import { dayStrip } from '../shared/day-strip.ts';

const strip = (startsAt: string, endsAt: string | null = null) =>
  dayStrip({ startsAt, endsAt }).map((cell) =>
    [cell.kind, cell.weekday, cell.date, cell.time ?? '-', cell.hidden ?? ''].join(' ').trim(),
  );

test('same-day event is one box with both times', () => {
  assert.deepEqual(strip('2026-10-04T17:00:00+02:00', '2026-10-04T18:20:00+02:00'), [
    'single nedjelja 4.10. 17:00 – 18:20',
  ]);
});

test('past midnight shows two boxes with their own times (Zagreb time, across DST)', () => {
  assert.deepEqual(strip('2026-10-24T20:30:00+02:00', '2026-10-25T02:30:00+02:00'), [
    'start sub 24.10. 20:30',
    'end ned 25.10. 02:30',
  ]);
});

test('date-only range lists every day without inventing times', () => {
  assert.deepEqual(strip('2026-10-22', '2026-10-24'), [
    'start čet 22.10. -',
    'mid pet 23.10. -',
    'end sub 24.10. -',
  ]);
});

test('long run collapses the middle into one gap cell', () => {
  assert.deepEqual(strip('2026-10-02T10:00:00+02:00', '2026-11-15'), [
    'start pet 2.10. 10:00',
    'gap   - 43',
    'end ned 15.11. -',
  ]);
});

test('missing end and missing time are explicit', () => {
  assert.deepEqual(strip('2026-10-09T19:00:00+02:00'), ['start pet 9.10. 19:00', 'open kraj ? -']);
  assert.deepEqual(strip('2026-10-10'), ['single subota 10.10. -']);
  // An end before the start is ignored, like everywhere else.
  assert.deepEqual(strip('2026-10-09T19:00:00+02:00', '2026-10-09T18:00:00+02:00'), [
    'start pet 9.10. 19:00',
    'open kraj ? -',
  ]);
});

test('daily hours put the same hours on every day box', () => {
  const cells = dayStrip({
    startsAt: '2026-10-22T18:00:00+02:00',
    endsAt: '2026-10-24T21:00:00+02:00',
    dailyHours: { start: '18:00', end: '21:00' },
  });
  assert.deepEqual(
    cells.map((cell) => `${cell.kind} ${cell.time}`),
    ['start 18:00–21:00', 'mid 18:00–21:00', 'end 18:00–21:00'],
  );
});

test('in progress only during the daily hours', async () => {
  const { isOngoing } = await import('../shared/discovery.ts');
  const festival = {
    id: 'f',
    title: 'Festival',
    description: '',
    startsAt: '2026-10-22T18:00:00+02:00',
    endsAt: '2026-10-24T21:00:00+02:00',
    venue: null,
    address: null,
    city: 'Osijek',
    category: 'culture' as const,
    price: null,
    status: 'scheduled' as const,
    dailyHours: { start: '18:00', end: '21:00' },
    sources: [],
    firstSeenAt: '',
    updatedAt: '',
  };
  assert.equal(isOngoing(festival, '2026-10-23T17:30:00Z'), true);
  assert.equal(isOngoing(festival, '2026-10-23T01:00:00Z'), false);
  assert.equal(isOngoing({ ...festival, dailyHours: null }, '2026-10-23T01:00:00Z'), true);
});
