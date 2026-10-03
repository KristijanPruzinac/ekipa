import assert from 'node:assert/strict';
import test from 'node:test';
import { assertFreshFeed, MAX_FEED_AGE_HOURS } from '../scripts/health-check.ts';

test('health monitor rejects broken, stale and future checks while allowing a fresh empty feed', () => {
  const now = Date.parse('2026-10-03T12:00:00Z');
  const feed = (lastCheckedAt: string | null) => ({
    events: [],
    meta: { sourceCount: 7, lastCheckedAt },
  });
  assert.equal(assertFreshFeed(feed('2026-10-03T06:00:00Z'), now).events, 0);
  for (const timestamp of [null, 'not-a-date', '2026-09-28T06:00:00Z', '2026-10-04T06:00:00Z'])
    assert.throws(() => assertFreshFeed(feed(timestamp), now), /108 hours/);
  for (const value of [null, {}, { events: {}, meta: {} }])
    assert.throws(() => assertFreshFeed(value, now));
});

test('health accepts the four-day collection gap including DST but detects a missed Tuesday', () => {
  const friday = Date.parse('2026-10-02T16:00:00Z');
  const feed = {
    events: [],
    meta: { sourceCount: 7, lastCheckedAt: new Date(friday).toISOString() },
  };
  for (const hours of [96, 97, MAX_FEED_AGE_HOURS])
    assert.equal(assertFreshFeed(feed, friday + hours * 3_600_000).sources, 7);
  assert.throws(
    () => assertFreshFeed(feed, friday + MAX_FEED_AGE_HOURS * 3_600_000 + 1),
    /108 hours/,
  );
  assert.throws(() => assertFreshFeed(feed, Date.parse('2026-10-07T07:41:00Z')), /108 hours/);
});
