import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  collectionScheduleDecision,
  SUMMER_COLLECTION_CRON,
  WINTER_COLLECTION_CRON,
} from '../scripts/collection-schedule.ts';

const scheduled = (cron: string, date: string) =>
  collectionScheduleDecision('schedule', cron, new Date(date));

test('summer and winter Tuesday/Friday slots run at 18:00 Zagreb, once per day', () => {
  for (const date of ['2026-07-07', '2026-07-10']) {
    assert.equal(scheduled(SUMMER_COLLECTION_CRON, `${date}T16:00:00Z`).collect, true);
    assert.equal(scheduled(WINTER_COLLECTION_CRON, `${date}T17:00:00Z`).collect, false);
  }
  for (const date of ['2026-01-06', '2026-01-09']) {
    assert.equal(scheduled(SUMMER_COLLECTION_CRON, `${date}T16:00:00Z`).collect, false);
    assert.equal(scheduled(WINTER_COLLECTION_CRON, `${date}T17:00:00Z`).collect, true);
  }
});

test('both DST transitions select the right UTC slot before and after the change', () => {
  for (const [date, hour, selected, skipped] of [
    ['2026-03-27', '17', WINTER_COLLECTION_CRON, SUMMER_COLLECTION_CRON],
    ['2026-03-31', '16', SUMMER_COLLECTION_CRON, WINTER_COLLECTION_CRON],
    ['2026-10-23', '16', SUMMER_COLLECTION_CRON, WINTER_COLLECTION_CRON],
    ['2026-10-27', '17', WINTER_COLLECTION_CRON, SUMMER_COLLECTION_CRON],
  ]) {
    assert.equal(scheduled(selected, `${date}T${hour}:45:00Z`).collect, true);
    assert.equal(scheduled(skipped, `${date}T19:00:00Z`).collect, false);
  }
});

test('delayed jobs work after their hour/day, including Friday delayed across DST', () => {
  const delayed = scheduled(SUMMER_COLLECTION_CRON, '2026-07-08T09:30:00Z');
  assert.equal(delayed.collect, true);
  assert.equal(delayed.nominalScheduledAt, '2026-07-07T16:00:00.000Z');
  assert.equal(scheduled(WINTER_COLLECTION_CRON, '2026-07-08T09:30:00Z').collect, false);
  assert.equal(scheduled(WINTER_COLLECTION_CRON, '2026-03-29T20:00:00Z').collect, true);
  assert.equal(scheduled(SUMMER_COLLECTION_CRON, '2026-03-29T20:00:00Z').collect, false);
  assert.equal(scheduled(SUMMER_COLLECTION_CRON, '2026-10-25T20:00:00Z').collect, true);
  assert.equal(scheduled(WINTER_COLLECTION_CRON, '2026-10-25T20:00:00Z').collect, false);
});

test('manual dispatch is immediate while unknown triggers and crons fail closed', () => {
  assert.equal(
    collectionScheduleDecision('workflow_dispatch', '', new Date('2026-10-04')).collect,
    true,
  );
  assert.throws(() => collectionScheduleDecision('push', ''), /Unsupported/);
  assert.throws(() => scheduled('0 16 * * 4,5', '2026-10-01'), /Unknown/);
  assert.throws(() => scheduled(SUMMER_COLLECTION_CRON, 'invalid'), /Invalid/);
});

test('workflow gates dependency installation and collection using both approved cron slots', async () => {
  const workflow = await readFile(
    new URL('../.github/workflows/collect.yml', import.meta.url),
    'utf8',
  );
  const crons = [...workflow.matchAll(/cron: '([^']+)'/g)].map((match) => match[1]);
  assert.deepEqual(crons, [SUMMER_COLLECTION_CRON, WINTER_COLLECTION_CRON]);
  assert.match(workflow, /WAGZ_TRIGGER_SCHEDULE: \$\{\{ github\.event\.schedule \}\}/);
  assert.match(workflow, /run: npm ci\s+if: steps\.schedule\.outputs\.collect == 'true'/);
  assert.match(workflow, /run: npm run collect\s+if: steps\.schedule\.outputs\.collect == 'true'/);
  assert.ok(
    workflow.indexOf('node scripts/collection-schedule.ts') < workflow.indexOf('run: npm ci'),
  );
});
