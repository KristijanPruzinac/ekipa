import assert from 'node:assert/strict';
import test from 'node:test';
import { assertFreshFeed } from '../scripts/health-check.ts';

test('health monitor rejects broken, stale and future checks while allowing a fresh empty feed', () => {
  const now = Date.parse('2026-10-03T12:00:00Z');
  const feed = (lastCheckedAt: string | null) => ({
    events: [],
    meta: { sourceCount: 7, lastCheckedAt },
  });
  assert.equal(assertFreshFeed(feed('2026-10-03T06:00:00Z'), now).events, 0);
  for (const timestamp of [null, 'not-a-date', '2026-10-01T06:00:00Z', '2026-10-04T06:00:00Z'])
    assert.throws(() => assertFreshFeed(feed(timestamp), now), /36 hours/);
  for (const value of [null, {}, { events: {}, meta: {} }])
    assert.throws(() => assertFreshFeed(value, now));
});
