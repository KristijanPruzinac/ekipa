import { appendFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { SITE_ORIGIN } from '../shared/site.ts';

/**
 * Collection runs Tuesday and Friday 18:00 Zagreb. The longest normal gap is Fri to Tue (96 h);
 * the daily 07:41 UTC check sees at most ~88 h of age before the Tuesday run. A missed run
 * is therefore flagged by the next morning's check (~112 h).
 */
export const MAX_FEED_AGE_HOURS = 100;

export function assertFreshFeed(value: unknown, now = Date.now()) {
  const feed = value as {
    events?: unknown;
    meta?: { lastCheckedAt?: unknown; sourceCount?: unknown };
  };
  const checked =
    typeof feed?.meta?.lastCheckedAt === 'string' ? Date.parse(feed.meta.lastCheckedAt) : NaN;
  if (
    !Array.isArray(feed?.events) ||
    !Number.isSafeInteger(feed.meta?.sourceCount) ||
    Number(feed.meta?.sourceCount) < 1
  )
    throw new Error('The public event feed is invalid.');
  if (
    !Number.isFinite(checked) ||
    checked > now + 5 * 60_000 ||
    now - checked > MAX_FEED_AGE_HOURS * 60 * 60_000
  )
    throw new Error(
      `No successful source check in the last ${MAX_FEED_AGE_HOURS} hours. Inspect the collection workflow and source health.`,
    );
  return {
    sources: feed.meta!.sourceCount,
    events: feed.events.length,
    checkedAt: new Date(checked).toISOString(),
  };
}

async function main() {
  const response = await fetch(`${SITE_ORIGIN}/api/events`, {
    redirect: 'error',
    signal: AbortSignal.timeout(20_000),
  });
  if (
    response.status !== 200 ||
    !response.headers.get('content-type')?.includes('application/json')
  )
    throw new Error('Public HTTPS event feed is unavailable.');
  const text = await response.text();
  if (Buffer.byteLength(text) > 8 * 1024 * 1024) throw new Error('Unexpectedly large public feed.');
  const report = assertFreshFeed(JSON.parse(text));
  console.log(JSON.stringify(report));
  if (process.env.GITHUB_STEP_SUMMARY)
    await appendFile(
      process.env.GITHUB_STEP_SUMMARY,
      `Public HTTPS feed passed. ${report.events} events; ${report.sources} configured sources. Latest successful source check: ${report.checkedAt}.\n`,
    );
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  void main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : 'Health check failed.');
    process.exitCode = 1;
  });
