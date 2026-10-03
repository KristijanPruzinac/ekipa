import { createHash, randomUUID } from 'node:crypto';
import type {
  AdminDashboard,
  EventCandidate,
  EventDraft,
  SourceRun,
  Tip,
  WagzEvent,
} from '../shared/types.ts';
import { Repository } from './repository.ts';
import {
  classifyTip,
  ConflictError,
  normalize,
  localDay,
  safeUrl,
  tipDates,
  upcoming,
  validateDraft,
  ValidationError,
} from './validation.ts';
import { fetchSource } from './ingestion/index.ts';
import {
  prepareTip as aiPrepareTip,
  extractEvents,
  EXTRACTION_VERSION,
  TIP_PREPARATION_VERSION,
  REQUEST_RESERVATION_USD,
} from './ai/openrouter.ts';
import { readTipSource } from './ai/tip-source.ts';
import type { Config } from './config.ts';
import { inferDiscovery, isFree } from './discovery.ts';
import { supportedTime } from './ai/evidence.ts';
import { classifyCandidates } from './ai/classification.ts';

function submittedTimeMatches(note: string, startsAt: string): boolean {
  const explicitTime =
    /(?<!\d)(?:[01]?\d|2[0-3]):[0-5]\d(?!\d)|\b(?:u|od)\s*(?:[01]?\d|2[0-3])(?:\.[0-5]\d\b|\s*(?:h\b|sati\b))/i.test(
      note,
    );
  const clockText = note.replace(/\b(u|od)\s*((?:[01]?\d|2[0-3]))\.([0-5]\d)\b/gi, '$1 $2:$3');
  return !explicitTime || (startsAt.length > 10 && supportedTime(startsAt, clockText).length > 10);
}

function submissionUrlKey(value: string | null): string | null {
  if (!value) return null;
  const url = new URL(value);
  for (const key of [...url.searchParams.keys()])
    if (/^(?:utm_.+|fbclid|gclid|igshid)$/i.test(key)) url.searchParams.delete(key);
  url.searchParams.sort();
  url.hash = '';
  return url.href;
}

function eventSnapshot(event: WagzEvent): string {
  const { id: _id, updatedAt: _updated, firstSeenAt: _first, sources, ...fields } = event;
  return createHash('sha256')
    .update(
      JSON.stringify({
        ...fields,
        sources: sources.map(({ sourceId, url }) => `${sourceId}:${url}`).sort(),
      }),
    )
    .digest('hex');
}

function titleKey(title: string): string {
  return normalize(
    title
      .replace(/^\s*\d{1,2}\.\s*(?:(?:[-–—]|i)\s*\d{1,2}\.\s*)?\d{1,2}\.(?:\s*20\d{2}\.)?\s*/, '')
      .replace(/\s*[/([]\s*(?:predstava|koncert|festival)\s*[/)\]]\s*$/i, '')
      .replace(/\s*,\s*Osijek\s*$/i, ''),
  )
    .replace(/\b20\d{2}\b/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function relatedTitles(first: string, second: string, sourceText: string): boolean {
  const a = titleKey(first),
    b = titleKey(second);
  if (!a || !b) return false;
  if (a === b) return true;
  const core = (value: string) =>
    value
      .replace(/\b(?:festival|koncert|predstava)\b/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  if (core(a).length >= 6 && core(a) === core(b)) return true;
  const short = a.length < b.length ? a : b;
  const long = a.length < b.length ? b : a;
  // A full source title can add the organizer to a substantial event name.
  // Short artist names and shared individual words cannot establish identity.
  return (
    short.length >= 12 &&
    short.split(' ').length >= 2 &&
    long.startsWith(`${short} `) &&
    normalize(sourceText).includes(long) &&
    !/\b(?:koncert|predstava|izvedba|nastup|radionica|otvorenje|program)\b/.test(
      long.slice(short.length),
    )
  );
}

const sameTime = (a: string, b: string) =>
  a.slice(0, 10) === b.slice(0, 10) &&
  (a.length === 10 || b.length === 10 || Date.parse(a) === Date.parse(b));

function pageHasDate(text: string, day: string): boolean {
  const dates = tipDates(text);
  return (
    dates.dates.includes(day) ||
    (new RegExp(`\\b${day.slice(0, 4)}\\b`).test(text) && dates.dates.includes(`--${day.slice(5)}`))
  );
}

function pageHasTime(text: string, startsAt: string): boolean {
  if (startsAt.length === 10) return true;
  const hour = Number(startsAt.slice(11, 13));
  const minute = startsAt.slice(14, 16);
  return (
    new RegExp(`(?<!\\d)0?${hour}[:.]${minute}(?!\\d)`).test(text) ||
    (minute === '00' &&
      new RegExp(`\\b(?:u|od)\\s+0?${hour}(?=\\s+(?:sati|h\\b|do\\b)|\\s*[-–])`, 'i').test(text))
  );
}

/** Merge page interpretations before persistence so structured identity always wins. */
export function reconcileExtraction(
  originals: EventCandidate[],
  extracted: EventCandidate[],
  page: { url: string; text: string },
): { events: EventCandidate[]; skipped: number; warnings: string[] } {
  const events = originals.map((event) => ({ ...event }));
  const warnings: string[] = [];
  let skipped = 0;
  const reject = (event: EventCandidate, reason: string) => {
    skipped++;
    warnings.push(`${page.url}: AI prijedlog „${event.title}” nije uvezen: ${reason}.`);
  };
  const targets = originals.filter((event) => event.sourceUrl === page.url);
  const planned = extracted.map((event) => ({
    event,
    related: targets.filter(
      (target) =>
        target.sourceId === event.sourceId && relatedTitles(target.title, event.title, page.text),
    ),
  }));
  const mapped = planned.map(({ event, related }) => ({
    event,
    related,
    matches: related.filter((target) => sameTime(target.startsAt, event.startsAt)),
  }));
  for (const { event, related, matches } of mapped) {
    if (event.sourceUrl !== page.url) {
      reject(event, 'poveznica ne odgovara obrađenom izvoru');
      continue;
    }
    if (matches.length > 1) {
      reject(event, 'više izvedbi odgovara datumu bez dovoljne potvrde satnice');
      continue;
    }
    if (matches.length === 1) {
      const target = matches[0];
      const alternatives = mapped.filter((item) => item.matches.includes(target));
      if (alternatives.length > 1) {
        reject(event, 'više AI tumačenja odgovara istom izvornom događaju');
        continue;
      }
      if (target.endsAt && event.endsAt && !sameTime(target.endsAt, event.endsAt)) {
        reject(event, 'datum završetka proturječi preciznom izvornom zapisu');
        continue;
      }
      // AI can fill missing fields but cannot rewrite a source title, time, status or identity.
      const merged = { ...target };
      for (const key of ['venue', 'address', 'price', 'endsAt'] as const) {
        if (merged[key] === null) merged[key] = event[key];
      }
      if (merged.category === 'other') merged.category = event.category;
      const discovery =
        target.discovery ?? inferDiscovery(target.title, page.text, page.url, merged.price);
      merged.discovery = { ...discovery, free: isFree(merged.price) };
      events[originals.indexOf(target)] = merged;
      continue;
    }
    if (related.length) {
      const separateDate = related.every((target) => {
        const day = event.startsAt.slice(0, 10);
        return (
          day < target.startsAt.slice(0, 10) ||
          day > (target.endsAt ?? target.startsAt).slice(0, 10)
        );
      });
      const separateShowtime = related.every(
        (target) =>
          target.startsAt.length > 10 &&
          event.startsAt.length > 10 &&
          !sameTime(target.startsAt, event.startsAt) &&
          pageHasTime(page.text, target.startsAt),
      );
      if (
        (!separateDate && !separateShowtime) ||
        !pageHasDate(page.text, event.startsAt.slice(0, 10)) ||
        !pageHasTime(page.text, event.startsAt)
      ) {
        reject(event, 'termin se razlikuje od izvora bez potvrde zasebne izvedbe');
        continue;
      }
    } else if (
      targets.length &&
      (targets.some((target) => sameTime(target.startsAt, event.startsAt)) ||
        !normalize(page.text).includes(titleKey(event.title)) ||
        !pageHasDate(page.text, event.startsAt.slice(0, 10)) ||
        !pageHasTime(page.text, event.startsAt))
    ) {
      reject(event, 'nije potvrđen zaseban događaj uz postojeći izvorni zapis');
      continue;
    }
    events.push({
      ...event,
      classificationText: page.text,
      discovery: inferDiscovery(
        event.title,
        extracted.length === 1 ? page.text : '',
        page.url,
        event.price,
      ),
    });
  }
  return { events, skipped, warnings };
}

export class WagzService {
  collecting = false;
  lastTipBatch: {
    queued: number;
    processed: number;
    drafted: number;
    archived: number;
    deferred: number;
  } | null = null;
  private preparing = new Set<string>();
  constructor(
    public repo: Repository,
    public config: Config,
    private fetcher = fetchSource,
    private tipReader = readTipSource,
  ) {}
  ledger = {
    reserve: (ceiling: number) => this.repo.reserveAi(ceiling, this.config.ai.monthlyBudgetUsd),
    settle: (id: string, actual: number | null) => this.repo.settleAi(id, actual),
  };
  async dashboard(): Promise<AdminDashboard> {
    const [events, tips, sources, runs, autoPublish, aiSpent, collectionLease, preparingTipIds] =
      await Promise.all([
        this.repo.events(),
        this.repo.tips(),
        this.repo.sourceHealth(),
        this.repo.runs(),
        this.repo.autoPublish(),
        this.repo.aiSpent(),
        this.repo.isLeaseActive('collection'),
        this.repo.activeLeaseIds('tip:'),
      ]);
    return {
      events,
      tips,
      preparingTipIds,
      sources,
      runs,
      collecting: this.collecting || collectionLease,
      autoPublish,
      ai: {
        enabled: Boolean(this.config.ai.apiKey) && this.config.ai.monthlyBudgetUsd > 0,
        description: this.config.ai.apiKey
          ? `OpenRouter · ${this.config.ai.model} · ovaj mjesec $${aiSpent.toFixed(3)} / $${this.config.ai.monthlyBudgetUsd.toFixed(2)}. AI prijedlozi čekaju pregled.`
          : 'OpenRouter je pripremljen. Dodaj OPENROUTER_API_KEY u .env. Mjesečni proračun: $1. Bez ključa nema AI poziva ni troška.',
      },
    };
  }
  async collect(force = false, maxDurationMs?: number): Promise<boolean> {
    if (this.collecting) return false;
    if (maxDurationMs !== undefined && (!Number.isFinite(maxDurationMs) || maxDurationMs <= 0))
      throw new ValidationError('Neispravno vremensko ograničenje prikupljanja.');
    // Finish before the collection lease expires, including local/CLI runs.
    const deadlineMs = Date.now() + Math.min(maxDurationMs ?? 20 * 60_000, 20 * 60_000);
    this.collecting = true;
    let lease: string | null = null;
    try {
      lease = await this.repo.acquireLease('collection', 30 * 60_000);
      if (!lease) return false;
      this.lastTipBatch = null;
      const queued = (await this.repo.tips()).some((tip) => this.isQueuedTip(tip));
      // Sources run first so today's imports can resolve duplicate submissions.
      // Reserve up to two AI calls plus a source read for the queued submissions.
      const sourceBudgetEnd =
        deadlineMs - (queued ? Math.min(120_000, (deadlineMs - Date.now()) / 2) : 0);
      const enabledSources = this.repo.sources.filter((source) => source.enabled);
      const classificationAttempts = new Set<string>();
      const enrichment: Array<{
        sourceId: string;
        candidates: EventCandidate[];
        pages: Array<{ url: string; text: string }>;
        reviewExternalIds: string[];
        run: SourceRun;
        savedIds: Set<string>;
      }> = [];
      for (const [sourceIndex, source] of enabledSources.entries()) {
        const sourceStarted = Date.now();
        // A slow source must leave the remaining sources a fair share of the run.
        // Fast/cache-backed sources give their unused time to subsequent sources.
        const sourceDeadlineMs =
          sourceStarted +
          Math.max(0, sourceBudgetEnd - sourceStarted) / (enabledSources.length - sourceIndex);
        // Leave time for database imports, completed run records and lease release.
        const fetchDeadlineMs = sourceDeadlineMs - 15_000;
        const run: SourceRun = {
          id: randomUUID(),
          sourceId: source.id,
          startedAt: new Date().toISOString(),
          finishedAt: null,
          status: 'running',
          discovered: 0,
          imported: 0,
          skipped: 0,
          pagesFetched: 0,
          warnings: [],
        };
        await this.repo.saveRun(run);
        try {
          if (Date.now() >= fetchDeadlineMs) {
            run.status = 'partial';
            run.warnings.push(
              'Vremensko ograničenje prikupljanja: izvor čeka sljedeće pokretanje. Prethodni događaji ostaju sačuvani.',
            );
            run.finishedAt = new Date().toISOString();
            await this.repo.saveRun(run);
            continue;
          }
          const result = await this.fetcher(source.id, {
            force,
            ...(Number.isFinite(fetchDeadlineMs) ? { deadlineMs: fetchDeadlineMs } : {}),
          });
          run.discovered = result.discovered;
          run.skipped = result.skipped;
          run.pagesFetched = result.pagesFetched;
          run.warnings = result.warnings;
          let candidates = result.events;
          // Mandatory semantic labels receive budget before optional field enrichment.
          const initialClassification = await classifyCandidates(
            candidates,
            this.config.ai,
            this.ledger,
            this.repo,
            {
              deadlineMs: sourceDeadlineMs - 5000,
              attemptedKeys: classificationAttempts,
            },
          );
          candidates = initialClassification.events;
          run.warnings.push(...initialClassification.warnings);
          if (result.extractionPages?.length)
            enrichment.push({
              sourceId: source.id,
              candidates,
              pages: result.extractionPages,
              reviewExternalIds: result.reviewExternalIds ?? [],
              run,
              savedIds: new Set(),
            });
          const savedIds =
            enrichment.at(-1)?.run === run ? enrichment.at(-1)!.savedIds : new Set<string>();
          for (const candidate of candidates) {
            try {
              await this.repo.upsert(
                candidate,
                new Date(),
                result.reviewExternalIds?.includes(candidate.externalId) ?? false,
              );
              run.imported++;
              savedIds.add(candidate.externalId);
            } catch (error) {
              run.skipped++;
              run.warnings.push(
                `Neispravan događaj (${candidate.title.slice(0, 80)}): ${error instanceof Error ? error.message : 'validacija'}`,
              );
            }
          }
          run.status = run.warnings.length ? 'partial' : 'success';
        } catch (error) {
          run.status = 'error';
          run.warnings.push(error instanceof Error ? error.message : 'Izvor nije dostupan.');
        }
        run.finishedAt = new Date().toISOString();
        await this.repo.saveRun(run);
      }
      // All sources receive their mandatory semantic labels before optional
      // enrichment. Mixed pages keep their additional dated events in this phase.
      for (const job of enrichment) {
        const { run } = job;
        let candidates = job.candidates;
        try {
          for (const page of job.pages) {
            const key = createHash('sha256')
              .update(
                JSON.stringify({
                  source: job.sourceId,
                  url: page.url,
                  text: page.text,
                  model: this.config.ai.model,
                  version: EXTRACTION_VERSION,
                }),
              )
              .digest('hex');
            type Extraction = Awaited<ReturnType<typeof extractEvents>>;
            let extraction: Extraction | null;
            try {
              extraction = await this.repo.cached<Extraction>(`extract:${key}`);
              if (!extraction) {
                if (sourceBudgetEnd - Date.now() < 50_000) {
                  run.warnings.push(
                    `${page.url}: AI obrada odgođena zbog vremenskog ograničenja; izvorni događaji bit će spremljeni.`,
                  );
                  continue;
                }
                extraction = await extractEvents(
                  { ...page, sourceId: job.sourceId, now: new Date().toISOString() },
                  this.config.ai,
                  this.ledger,
                );
                if (extraction.complete || extraction.events.length)
                  await this.repo.cache(`extract:${key}`, extraction);
              }
            } catch {
              run.warnings.push(
                `${page.url}: AI obrada nije uspjela; izvorni događaji bit će spremljeni.`,
              );
              continue;
            }
            if (!extraction.events.length || !extraction.complete)
              run.warnings.push(`${page.url}: ${extraction.reason}`);
            const reconciled = reconcileExtraction(candidates, extraction.events, page);
            candidates = reconciled.events;
            run.skipped += reconciled.skipped;
            run.warnings.push(...reconciled.warnings);
          }
          const classified = await classifyCandidates(
            candidates,
            this.config.ai,
            this.ledger,
            this.repo,
            {
              deadlineMs: sourceBudgetEnd - 5000,
              attemptedKeys: classificationAttempts,
            },
          );
          run.warnings.push(...classified.warnings);

          for (const candidate of classified.events) {
            try {
              await this.repo.upsert(
                candidate,
                new Date(),
                job.reviewExternalIds.includes(candidate.externalId),
              );
              if (!job.savedIds.has(candidate.externalId)) {
                run.imported++;
                job.savedIds.add(candidate.externalId);
              }
            } catch (error) {
              run.skipped++;
              run.warnings.push(
                error instanceof Error ? error.message : 'Neispravan obogaćeni zapis.',
              );
            }
          }
          run.status = run.warnings.length ? 'partial' : 'success';
        } catch {
          run.status = 'partial';
          run.warnings.push('Dodatna obrada nije dovršena; izvorni događaji ostaju sačuvani.');
        }
        run.finishedAt = new Date().toISOString();
        await this.repo.saveRun(run);
      }
      await this.processQueuedTips(deadlineMs);
      return true;
    } finally {
      this.collecting = false;
      if (lease) await this.repo.releaseLease('collection', lease);
    }
  }
  private isQueuedTip(tip: Tip): boolean {
    return (
      tip.status === 'inbox' &&
      !tip.draft &&
      (!tip.lastAutomaticAttemptAt || localDay(new Date(tip.lastAutomaticAttemptAt)) !== localDay())
    );
  }
  private async processQueuedTips(deadlineMs: number): Promise<void> {
    const queued = (await this.repo.tips())
      .filter((tip) => this.isQueuedTip(tip))
      .sort(
        (a, b) =>
          (a.lastAutomaticAttemptAt ?? a.submittedAt).localeCompare(
            b.lastAutomaticAttemptAt ?? b.submittedAt,
          ) ||
          a.submittedAt.localeCompare(b.submittedAt) ||
          a.id.localeCompare(b.id),
      );
    const summary = {
      queued: queued.length,
      processed: 0,
      drafted: 0,
      archived: 0,
      deferred: queued.length,
    };
    this.lastTipBatch = summary;
    // Limit both queue size and elapsed work; overflow remains pending tomorrow.
    for (const tip of queued.slice(0, 20)) {
      if (Date.now() >= deadlineMs - 15_000) break;
      const prepared = await this.prepareTip(tip.id, false, {
        automatic: true,
        expectedRevision: tip.revision ?? 0,
        deadlineMs: Math.min(deadlineMs - 10_000, Date.now() + 110_000),
      });
      if (prepared.lastAutomaticAttemptAt !== tip.lastAutomaticAttemptAt) summary.processed++;
      if (prepared.status === 'draft') summary.drafted++;
      if (prepared.status === 'archived') summary.archived++;
      summary.deferred = summary.queued - summary.drafted - summary.archived;
    }
  }
  async submitTip(input: { note?: unknown; url?: unknown; website?: unknown }): Promise<Tip> {
    if (typeof input.note !== 'string' || input.note.trim().length < 3 || input.note.length > 2000)
      throw new ValidationError('Napiši dojavu od 3 do 2000 znakova.');
    const note = input.note.trim();
    const url = safeUrl(input.url);
    return this.repo.transaction(async () => {
      const existing = (await this.repo.tips()).find(
        (tip) =>
          normalize(tip.note) === normalize(note) &&
          submissionUrlKey(tip.url) === submissionUrlKey(url) &&
          Date.now() - Date.parse(tip.submittedAt) < 86400000,
      );
      if (existing) return existing;
      const classification = classifyTip(
        note,
        typeof input.website === 'string' ? input.website : '',
      );
      const stamp = new Date().toISOString();
      return this.repo.saveTip({
        id: randomUUID(),
        note,
        url,
        status: classification.archive ? 'archived' : 'inbox',
        reason: classification.reason,
        submittedAt: stamp,
        updatedAt: stamp,
        draft: null,
        matchedEventId: null,
        verification: 'unverified',
      });
    });
  }
  private async savePreparedTip(tip: Tip, changes: Partial<Tip>): Promise<Tip> {
    return this.repo.transaction(async () => {
      const latest = await this.repo.tip(tip.id);
      if (!latest) throw new ValidationError('Dojava ne postoji.');
      // Revisions detect edits even when timestamps are equal or status is restored.
      // The read and write must hold the same database transaction across instances.
      if ((latest.revision ?? 0) !== (tip.revision ?? 0) || latest.status !== tip.status)
        return latest;
      return this.repo.saveTip({ ...latest, ...changes, updatedAt: new Date().toISOString() });
    });
  }
  private async prepareSourceMatch(tip: Tip, matched: WagzEvent, automatic: boolean): Promise<Tip> {
    const draft: EventDraft = {
      title: matched.title,
      description: matched.description,
      startsAt: matched.startsAt,
      endsAt: matched.endsAt,
      venue: matched.venue,
      address: matched.address,
      city: matched.city,
      category: matched.category,
      price: matched.price,
      status: matched.status,
      sourceUrl: matched.sources[0]?.url ?? null,
    };
    const invalid = !upcoming(matched)
      ? 'Događaj je već završio.'
      : matched.status !== 'scheduled'
        ? 'Događaj je otkazan ili odgođen bez potvrđenog termina.'
        : !matched.venue
          ? 'Mjesto održavanja nije potvrđeno.'
          : matched.publication === 'rejected'
            ? 'Ovaj događaj je uredništvo već odbilo.'
            : null;
    const archive = automatic && (Boolean(invalid) || matched.publication === 'published');
    return this.savePreparedTip(tip, {
      status: archive ? 'archived' : 'draft',
      draft,
      matchedEventId: matched.id,
      matchedEventSnapshot: eventSnapshot(matched),
      verification: 'source_match',
      reason: archive
        ? `Automatski arhivirano: ${invalid ?? 'događaj je već objavljen u pregledu; duplikat nije stvoren.'}`
        : 'Pronađen je mogući isti događaj u prikupljenim izvorima. Prihvaćanje povezuje dojavu bez stvaranja duplikata.' +
          (invalid ? ` ${invalid}` : ''),
    });
  }
  async prepareTip(
    id: string,
    force = false,
    options: {
      automatic?: boolean;
      expectedRevision?: number;
      deadlineMs?: number;
    } = {},
  ): Promise<Tip> {
    const existing = await this.repo.tip(id);
    if (!existing) throw new ValidationError('Dojava ne postoji.');
    if (['archived', 'accepted', 'rejected'].includes(existing.status) || this.preparing.has(id))
      return existing;
    this.preparing.add(id);
    let lease: string | null = null;
    let preparingTip: Tip | undefined;
    try {
      lease = await this.repo.acquireLease(`tip:${id}`, 5 * 60_000);
      let tip = await this.repo.tip(id);
      if (!tip) throw new ValidationError('Dojava ne postoji.');
      if (!lease || !['inbox', 'draft'].includes(tip.status)) return tip;
      if (options.automatic) {
        if (!this.isQueuedTip(tip) || (tip.revision ?? 0) !== options.expectedRevision) return tip;
        const classification = classifyTip(tip.note);
        const previousRevision = tip.revision ?? 0;
        const attemptAt = new Date().toISOString();
        tip = await this.savePreparedTip(tip, {
          lastAutomaticAttemptAt: attemptAt,
          ...(classification.archive ? { status: 'archived', reason: classification.reason } : {}),
        });
        if (tip.revision !== previousRevision + 1 || tip.lastAutomaticAttemptAt !== attemptAt)
          return tip;
        if (tip.status !== 'inbox' || tip.draft) return tip;
      }
      preparingTip = tip;
      const all = await this.repo.events();
      const byUrl = tip.url
        ? all.filter((event) => event.sources.some((source) => source.url === tip.url))
        : [];
      const byTitle = all.filter((event) => {
        const title = normalize(event.title);
        return title.length >= 12 && normalize(tip.note).includes(title);
      });
      const dates = tipDates(tip.note);
      const years: string[] = tip.note.match(/\b20\d{2}\b/g) ?? [];
      const compatibleDate = (event: (typeof all)[number]) =>
        !dates.invalid &&
        (!options.automatic || submittedTimeMatches(tip.note, event.startsAt)) &&
        (!years.length || years.includes(event.startsAt.slice(0, 4))) &&
        dates.dates.every((date) =>
          date.startsWith('--')
            ? event.startsAt.slice(5, 10) === date.slice(2)
            : event.startsAt.slice(0, 10) === date,
        );
      // Intersect independent evidence rather than letting one contradict another.
      // A title alone cannot identify a repeat performance on another date.
      const pool = byUrl.length
        ? byUrl.filter(
            (event) =>
              (!byTitle.length || byTitle.some((named) => named.id === event.id)) &&
              compatibleDate(event),
          )
        : dates.hasYear
          ? byTitle.filter(compatibleDate)
          : [];
      const matched =
        pool.length === 1 && (byUrl.length <= 1 || dates.hasYear) ? pool[0] : undefined;
      if (
        matched &&
        (!options.automatic ||
          matched.venue ||
          !upcoming(matched) ||
          matched.status !== 'scheduled' ||
          matched.publication === 'rejected')
      ) {
        return await this.prepareSourceMatch(tip, matched, Boolean(options.automatic));
      }
      if (
        options.automatic &&
        (!this.config.ai.apiKey ||
          (await this.repo.aiSpent()) + REQUEST_RESERVATION_USD > this.config.ai.monthlyBudgetUsd)
      )
        return await this.savePreparedTip(tip, {
          reason:
            'Automatska provjera čeka dostupnu AI uslugu ili mjesečni proračun. Dojava ostaje u redu za ponovni pokušaj.',
        });
      const source =
        tip.url && this.config.ai.apiKey && this.config.ai.monthlyBudgetUsd > 0
          ? await this.tipReader(tip.url, {
              force,
              deadlineMs: Math.min(options.deadlineMs ?? Infinity, Date.now() + 20_000),
            })
          : {};
      if (options.automatic && (source.reason || (!source.text && !this.config.ai.searchEnabled)))
        return await this.savePreparedTip(tip, {
          reason: `${source.reason ?? 'Pretraživanje izvora nije uključeno.'} Dojava čeka ponovni pokušaj; nije arhivirana.`,
        });
      const key = createHash('sha256')
        .update(
          JSON.stringify({
            note: tip.note,
            url: tip.url,
            model: this.config.ai.model,
            searchEnabled: this.config.ai.searchEnabled,
            lookupModel: this.config.ai.lookupModel,
            version: TIP_PREPARATION_VERSION,
            sourceText: source.text ?? null,
            day: localDay(),
          }),
        )
        .digest('hex');
      type Result = Awaited<ReturnType<typeof aiPrepareTip>>;
      let result = force ? null : await this.repo.cached<Result>(`tip:${key}`);
      if (!result?.complete) {
        result = await aiPrepareTip(
          { note: tip.note, url: tip.url, now: new Date().toISOString(), sourceText: source.text },
          { ...this.config.ai, searchEnabled: this.config.ai.searchEnabled && !source.reason },
          this.ledger,
          { deadlineMs: options.deadlineMs },
        );
        if (result.complete && result.costUsd !== null && !source.reason)
          await this.repo.cache(`tip:${key}`, result);
      }
      // Uncertain classifications remain in the inbox. Spam stays recoverable.
      let draft: EventDraft | null = null;
      if (result.draft) {
        try {
          draft = validateDraft(result.draft);
        } catch {
          /* Keep the original tip in the inbox. */
        }
      }
      if (options.automatic) {
        if (!result.complete || (result.draft && !draft))
          return await this.savePreparedTip(tip, {
            reason: `${result.reason} Dojava čeka ponovni pokušaj.`,
          });
        if (draft && !submittedTimeMatches(tip.note, draft.startsAt))
          return await this.savePreparedTip(tip, {
            reason:
              'Pronađeni termin ne odgovara izričitoj satnici u dojavi. Dojava čeka ponovnu provjeru; nije odabrana druga izvedba.',
          });
        const invalid =
          !draft || result.classification !== 'plausible'
            ? result.classification === 'spam'
              ? 'sadržaj je prepoznat kao spam.'
              : 'nije pronađen potvrđen događaj za objavu.'
            : !upcoming(draft)
              ? `događaj je već završio (${(draft.endsAt ?? draft.startsAt).slice(0, 10)}).`
              : draft.status !== 'scheduled'
                ? 'događaj je otkazan ili odgođen bez potvrđenog termina.'
                : !draft.venue
                  ? 'mjesto održavanja nije potvrđeno.'
                  : !draft.sourceUrl || !result.sourceEvidence
                    ? 'datum i godina nisu potvrđeni u neovisnom izvoru.'
                    : null;
        if (invalid)
          return await this.savePreparedTip(tip, {
            status: 'archived',
            draft: null,
            matchedEventId: null,
            verification: 'unverified',
            reason: `Automatski arhivirano: ${invalid} ${result.reason}`,
          });
        // The note may be vague, but the completed draft can identify an import.
        const known = (await this.repo.events()).filter(
          (event) =>
            normalize(event.title) === normalize(draft!.title) &&
            sameTime(event.startsAt, draft!.startsAt) &&
            (!event.venue || normalize(event.venue) === normalize(draft!.venue!)),
        );
        const identified = known.filter(
          (event) =>
            (event.startsAt.length > 10 && draft!.startsAt.length > 10 && event.venue) ||
            event.sources.some((source) => source.url === draft!.sourceUrl),
        );
        if (known.length === 1 && identified.length === 1) {
          if (identified[0].venue) return await this.prepareSourceMatch(tip, identified[0], true);
          // A newly sourced venue completes a known unpublished event. Keep the
          // better draft for the operator rather than restoring stale missing fields.
          return await this.savePreparedTip(tip, {
            status: 'draft',
            draft,
            matchedEventId: identified[0].id,
            matchedEventSnapshot: eventSnapshot(identified[0]),
            verification: 'source_match',
            reason: `Dopunjeni podaci postojećeg događaja čekaju pregled. ${result.reason}`,
          });
        }
        if (known.length)
          return await this.savePreparedTip(tip, {
            status: 'draft',
            draft,
            matchedEventId: null,
            verification: 'unverified',
            reason:
              'Pronađen je valjan prijedlog, ali i mogući postojeći događaj. Provjeri točan termin i podudaranje prije objave; automatsko stvaranje duplikata je blokirano.',
          });
      }
      return await this.savePreparedTip(tip, {
        draft: draft ?? tip.draft,
        status:
          result.classification === 'spam' && !draft ? 'archived' : draft ? 'draft' : tip.status,
        reason: [source.reason, result.reason].filter(Boolean).join(' '),
        matchedEventId: null,
        matchedEventSnapshot: null,
        verification: 'unverified',
      });
    } catch (error) {
      if (!options.automatic || !preparingTip) throw error;
      return await this.savePreparedTip(preparingTip, {
        reason:
          'Automatska provjera nije dovršena zbog nedostupne usluge. Dojava ostaje u redu za ponovni pokušaj.',
      });
    } finally {
      this.preparing.delete(id);
      if (lease) await this.repo.releaseLease(`tip:${id}`, lease);
    }
  }
  async updateTip(
    id: string,
    action: string,
    rawDraft?: unknown,
    expectedRevision?: unknown,
  ): Promise<Tip> {
    return this.repo.transaction(async () => {
      const tip = await this.repo.tip(id);
      if (!tip) throw new ValidationError('Dojava ne postoji.');
      if (expectedRevision !== undefined && expectedRevision !== (tip.revision ?? 0))
        throw new ConflictError(
          'Dojava je u međuvremenu promijenjena. Otvori najnoviji prijedlog prije spremanja.',
        );
      const stamp = new Date().toISOString();
      // Keep the assessment with the tip; action confirmations belong in the UI.
      if (action === 'archive')
        return this.repo.saveTip({
          ...tip,
          status: 'archived',
          updatedAt: stamp,
        });
      if (action === 'restore')
        return this.repo.saveTip({
          ...tip,
          status: tip.draft ? 'draft' : 'inbox',
          updatedAt: stamp,
          lastAutomaticAttemptAt: null,
        });
      if (action === 'reject')
        return this.repo.saveTip({
          ...tip,
          status: 'rejected',
          updatedAt: stamp,
        });
      if (!['save', 'accept'].includes(action)) throw new ValidationError('Nepoznata radnja.');
      if (action === 'accept' && tip.status === 'accepted') return tip;
      const draft = validateDraft(rawDraft ?? tip.draft, { allowIncomplete: action === 'save' });
      if (action === 'save')
        return this.repo.saveTip({ ...tip, draft, status: 'draft', updatedAt: stamp });
      if (!upcoming(draft))
        throw new ValidationError(
          'Događaj je već završio i ne može se objaviti među nadolazećim događajima. Nacrt možeš spremiti za evidenciju.',
        );
      if (!draft.venue)
        throw new ValidationError('Za objavu je potrebno potvrđeno mjesto održavanja.');
      let eventId = tip.matchedEventId;
      if (eventId) {
        const matched = await this.repo.event(eventId);
        if (
          matched &&
          tip.matchedEventSnapshot &&
          tip.matchedEventSnapshot !== eventSnapshot(matched)
        )
          throw new ConflictError(
            'Povezani događaj promijenjen je nakon pripreme dojave. Ponovno provjeri izvore i pregledaj najnovije podatke prije objave.',
          );
        const unchanged =
          matched &&
          Object.entries(draft).every(([key, value]) =>
            key === 'sourceUrl'
              ? matched.sources.some((source) => source.url === value)
              : matched[key as keyof typeof matched] === value,
          );
        if (matched && !tip.matchedEventSnapshot && !unchanged)
          throw new ConflictError(
            'Ovaj stariji prijedlog nema spremljenu verziju povezanog događaja. Ponovno provjeri izvore prije promjene ili objave.',
          );
        if (!unchanged) await this.repo.editEvent(eventId, 'published', draft);
        else if (matched.publication !== 'published')
          await this.repo.editEvent(eventId, 'published');
      } else {
        eventId = (await this.repo.publishTip(tip.id, draft)).id;
      }
      return this.repo.saveTip({
        ...tip,
        draft,
        matchedEventId: eventId,
        status: 'accepted',
        reason: 'Događaj je odobren i objavljen.',
        updatedAt: stamp,
      });
    });
  }
}
