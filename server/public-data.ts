import type { PublicFeed } from '../shared/types.ts';
import type { Repository } from './repository.ts';
import { TIMEZONE } from './validation.ts';

/** One feed contract for HTTP JSON and initial server-rendered HTML. */
export async function publicFeed(repo: Repository, now = new Date()): Promise<PublicFeed> {
  const events = await repo.publicEvents(now);
  return {
    events,
    meta: {
      city: 'Osijek',
      timezone: TIMEZONE,
      now: now.toISOString(),
      lastCheckedAt:
        (await repo.runs()).find((run) => ['success', 'partial'].includes(run.status))
          ?.finishedAt ?? null,
      sourceCount: repo.sources.filter((source) => source.enabled).length,
      totalUpcoming: events.length,
    },
  };
}
