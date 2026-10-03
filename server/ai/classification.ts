import { createHash } from 'node:crypto';
import type { EventCandidate } from '../../shared/types.ts';
import { inferDiscovery } from '../discovery.ts';
import { synopsis } from '../ingestion/parsers.ts';
import {
  CLASSIFICATION_VERSION,
  DEFAULT_MODEL,
  MAX_CLASSIFICATION_BATCH,
  MAX_CLASSIFICATION_TEXT,
  classifyEvents,
  validateSemanticClassification,
  type AiConfig,
  type AiLedger,
  type ClassificationInput,
  type SemanticClassification,
} from './openrouter.ts';

interface Cache {
  cached<T>(key: string): Promise<T | null>;
  cache(key: string, value: unknown): Promise<unknown>;
}

/** Classify unique unchanged source evidence once, not each showing or collection date. */
export async function classifyCandidates(
  candidates: EventCandidate[],
  config: AiConfig,
  ledger: AiLedger,
  cache: Cache,
  options: { deadlineMs?: number; fetch?: typeof fetch; attemptedKeys?: Set<string> } = {},
): Promise<{ events: EventCandidate[]; warnings: string[] }> {
  const inputs = new Map<string, ClassificationInput>();
  const candidateKeys: string[] = [];
  const warnings = new Set<string>();
  for (const event of candidates) {
    const text = event.classificationText ?? '';
    const record = { title: event.title, venue: event.venue, sourceUrl: event.sourceUrl, text };
    const id = createHash('sha256')
      .update(
        JSON.stringify({
          ...record,
          model: config.model ?? DEFAULT_MODEL,
          version: CLASSIFICATION_VERSION,
        }),
      )
      .digest('hex');
    candidateKeys.push(id);
    if (text.length <= MAX_CLASSIFICATION_TEXT) inputs.set(id, { id, ...record });
    else
      warnings.add(
        'AI klasifikacija: izvorni dokaz prelazi dopuštenu veličinu; događaj ostaje nerazvrstan.',
      );
  }
  const results = new Map<string, SemanticClassification>();
  const pending: ClassificationInput[] = [];
  for (const input of inputs.values()) {
    let cached: SemanticClassification | null = null;
    try {
      const saved = await cache.cached<SemanticClassification>(`classify:${input.id}`);
      if (saved) cached = validateSemanticClassification(saved, input);
    } catch {
      /* Invalid/stale cache cannot replace source-grounded inference. */
    }
    if (cached) results.set(input.id, cached);
    else if (!options.attemptedKeys?.has(input.id)) pending.push(input);
  }
  while (pending.length) {
    const batch: ClassificationInput[] = [];
    let size = 0;
    while (
      pending.length &&
      batch.length < MAX_CLASSIFICATION_BATCH &&
      size + pending[0].text.length <= 48_000
    ) {
      const next = pending.shift()!;
      batch.push(next);
      size += next.text.length;
    }
    for (const record of batch) options.attemptedKeys?.add(record.id);
    const result = await classifyEvents(batch, config, ledger, options);
    if (!result.complete) {
      for (const record of pending) options.attemptedKeys?.add(record.id);
      warnings.add(
        `AI klasifikacija: ${result.reason} Nepotvrđene kategorije ostaju nerazvrstane i vidljive.`,
      );
      // No repeated billable attempts within this source after any failed batch.
      break;
    }
    for (const classification of result.classifications) {
      results.set(classification.id, classification);
      await cache.cache(`classify:${classification.id}`, classification);
    }
  }
  const events = candidates.map((event, index) => {
    const result = results.get(candidateKeys[index]);
    const { screening: _oldScreening, ...discovery } =
      event.discovery ?? inferDiscovery(event.title, '', event.sourceUrl, event.price);
    const next: EventCandidate = {
      ...event,
      category: result?.category ?? 'other',
      discovery: {
        ...discovery,
        ...(result && result.category === 'film' && result.screening !== 'unknown'
          ? {
              screening: {
                kind: result.screening,
                reason: result.screeningReason,
                sourceUrl: event.sourceUrl,
              },
            }
          : {}),
      },
    };
    // Generated summaries must reflect the authoritative label too. Original
    // source prose is never rewritten and no keyword classifier runs here.
    const oldLead = synopsis(event).split('.')[0] + '.';
    if (next.description.startsWith(oldLead))
      next.description =
        synopsis(next).split('.')[0] + '.' + next.description.slice(oldLead.length);
    return next;
  });
  return { events, warnings: [...warnings] };
}
