import { appendFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export const SUMMER_COLLECTION_CRON = '0 16 * * 2,5';
export const WINTER_COLLECTION_CRON = '0 17 * * 2,5';
const zone = new Intl.DateTimeFormat('en', {
  timeZone: 'Europe/Zagreb',
  timeZoneName: 'shortOffset',
});

export function collectionScheduleDecision(eventName: string, schedule: string, now = new Date()) {
  // Explicit refreshes remain available on any day and at any time.
  if (eventName === 'workflow_dispatch')
    return { collect: true, reason: 'Manual collection requested.' };
  if (eventName !== 'schedule') throw new Error('Unsupported collection trigger.');
  if (![SUMMER_COLLECTION_CRON, WINTER_COLLECTION_CRON].includes(schedule))
    throw new Error('Unknown collection schedule.');
  if (!Number.isFinite(now.getTime())) throw new Error('Invalid scheduler time.');

  // GitHub jobs can start late, even on the following day. Find the nominal
  // Tuesday/Friday slot for this cron instead of testing the runner's hour/day.
  // Using that slot's season also preserves a Friday job delayed across a Sunday
  // DST transition. Delays spanning another occurrence cannot be distinguished
  // from the schedule payload, which supplies the cron but no scheduled date.
  const nominal = new Date(now);
  nominal.setUTCHours(schedule === SUMMER_COLLECTION_CRON ? 16 : 17, 0, 0, 0);
  if (nominal.getTime() > now.getTime()) nominal.setUTCDate(nominal.getUTCDate() - 1);
  while (![2, 5].includes(nominal.getUTCDay())) nominal.setUTCDate(nominal.getUTCDate() - 1);
  const offset = zone.formatToParts(nominal).find((part) => part.type === 'timeZoneName')?.value;
  if (offset !== 'GMT+1' && offset !== 'GMT+2')
    throw new Error('Unexpected Europe/Zagreb UTC offset.');
  const expectedSchedule = offset === 'GMT+2' ? SUMMER_COLLECTION_CRON : WINTER_COLLECTION_CRON;
  const collect = schedule === expectedSchedule;
  return {
    collect,
    reason: collect ? 'Selected Zagreb 18:00 slot.' : 'Skipped the other seasonal UTC slot.',
    nominalScheduledAt: nominal.toISOString(),
    expectedSchedule,
  };
}

async function main() {
  const decision = collectionScheduleDecision(
    process.env.WAGZ_TRIGGER_EVENT ?? '',
    process.env.WAGZ_TRIGGER_SCHEDULE ?? '',
  );
  if (process.env.GITHUB_OUTPUT)
    await appendFile(process.env.GITHUB_OUTPUT, `collect=${decision.collect}\n`);
  console.log(JSON.stringify(decision));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  void main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : 'Collection schedule check failed.');
    process.exitCode = 1;
  });
