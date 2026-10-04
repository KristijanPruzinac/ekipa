import assert from 'node:assert/strict';
import test from 'node:test';
import { dayStrip, ticket } from '../shared/day-strip.ts';

const strip = (startsAt: string, endsAt: string | null = null) =>
  dayStrip({ startsAt, endsAt }).map((cell) =>
    [cell.kind, cell.weekday, cell.date, cell.time ?? '-', cell.hidden ?? ''].join(' ').trim(),
  );

test('same-day event is one box with both times', () => {
  assert.deepEqual(strip('2026-10-04T17:00:00+02:00', '2026-10-04T18:20:00+02:00'), [
    'single nedjelja 4.10. 17:00–18:20',
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

test('daily hours print once under the ticket; stubs carry dates', () => {
  const result = ticket({
    startsAt: '2026-10-22T20:30:00+02:00',
    endsAt: '2026-10-24T21:30:00+02:00',
    dailyHours: { start: '20:30', end: '21:30' },
  });
  assert.equal(result.daily, '20:30–21:30');
  assert.deepEqual(
    result.stubs.map((stub) => `${stub.tone} ${stub.big ?? '-'} ${stub.small}`),
    ['main 22.10. čet', 'mid 23. pet', 'main 24.10. sub'],
  );
});

test('ticket stubs: times big, dates small; mid days, gaps and open ends', () => {
  const show = (startsAt: string, endsAt: string | null = null) =>
    ticket({ startsAt, endsAt }).stubs.map((s) => `${s.tone} ${s.big ?? '-'} ${s.small}`);
  assert.deepEqual(show('2026-10-24T20:30:00+02:00', '2026-10-24T21:30:00+02:00'), [
    'main 20:30–21:30 subota 24.10.',
  ]);
  assert.deepEqual(show('2026-10-22T18:00:00+02:00', '2026-10-24T21:00:00+02:00'), [
    'main 18:00 čet 22.10.',
    'mid - pet',
    'main 21:00 sub 24.10.',
  ]);
  assert.deepEqual(show('2026-10-02T10:00:00+02:00', '2026-11-15'), [
    'main 10:00 pet 2.10.',
    'mid +43 dana',
    'main 15.11. ned',
  ]);
  assert.deepEqual(show('2026-10-09T19:00:00+02:00'), ['main 19:00 pet 9.10.', 'open ? kraj']);
  assert.deepEqual(show('2026-10-10'), ['main 10.10. subota']);
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
