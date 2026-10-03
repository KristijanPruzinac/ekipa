/**
 * Real-model comparison on live sources (run in CI with the OPENROUTER_API_KEY secret):
 * fetches every non-Instagram source, classifies each event with the production classifier,
 * and compares against the previous keyword categories. Writes a Markdown report to
 * GITHUB_STEP_SUMMARY and exits 1 if any event is left as `other` or classification fails.
 */
import { appendFile } from 'node:fs/promises';
import { classifyCandidates } from '../server/ai/classification.ts';
import { categoryFor } from '../server/ingestion/parsers.ts';
import { fetchSource, sources } from '../server/ingestion/index.ts';
import { isInstagramSource } from '../server/ingestion/instagram.ts';
import { validateCandidate } from '../server/validation.ts';
import type { EventCandidate } from '../shared/types.ts';

const apiKey = process.env.OPENROUTER_API_KEY;
if (!apiKey) throw new Error('OPENROUTER_API_KEY is required.');
const store = new Map<string, unknown>();
const cache = {
  cached: async <T>(key: string) => (store.get(key) as T) ?? null,
  cache: async (key: string, value: unknown) => void store.set(key, value),
};
let spent = 0;
const ledger = {
  reserve: () => (spent < 0.3 ? 'compare' : null),
  settle: (_id: string, cost: number | null) => void (spent += cost ?? 0.03),
};
const rows: string[] = [];
let routine = 0,
  special = 0,
  other = 0,
  total = 0,
  agree = 0;
const warnings: string[] = [];
for (const source of sources.filter((item) => !isInstagramSource(item.id))) {
  let events: EventCandidate[] = [];
  try {
    const result = await fetchSource(source.id, { deadlineMs: Date.now() + 120_000 });
    events = result.events;
  } catch (error) {
    warnings.push(`${source.name}: ${error instanceof Error ? error.message : 'fetch failed'}`);
    continue;
  }
  const keyword = events.map((event) =>
    categoryFor(`${event.title} ${event.classificationText ?? ''}`, event.title),
  );
  const classified = await classifyCandidates(
    events,
    { apiKey, model: process.env.OPENROUTER_MODEL, monthlyBudgetUsd: 1, searchEnabled: false },
    ledger,
    cache,
  );
  warnings.push(...classified.warnings.map((item) => `${source.name}: ${item}`));
  classified.events.forEach((raw, index) => {
    // Mirror persistence: only what survives validation reaches the public feed.
    let event = raw;
    try {
      event = validateCandidate(raw);
    } catch {
      warnings.push(`${source.name}: ${raw.title} failed validation`);
    }
    total++;
    if (event.category === 'other') other++;
    if (event.category === keyword[index]) agree++;
    const screening = event.discovery?.screening?.kind ?? '';
    if (screening === 'routine') routine++;
    if (screening === 'special') special++;
    rows.push(
      `| ${source.name} | ${event.title.replace(/\|/g, '/').slice(0, 70)} | ${keyword[index]} | **${event.category}**${screening ? ` (${screening})` : ''} |`,
    );
  });
}
const report = [
  `## Classification comparison`,
  `${total} events · AI \`other\`: ${other} · agrees with keyword rules: ${agree}/${total} · persisted screenings: ${routine} routine, ${special} special · cost ≈ $${spent.toFixed(4)}`,
  '',
  '| Source | Title | Keyword (before) | AI (now) |',
  '| - | - | - | - |',
  ...rows,
  '',
  ...warnings.map((item) => `- ${item}`),
].join('\n');
console.log(report);
if (process.env.GITHUB_STEP_SUMMARY)
  await appendFile(process.env.GITHUB_STEP_SUMMARY, report + '\n');
if (other || !total) process.exitCode = 1;
