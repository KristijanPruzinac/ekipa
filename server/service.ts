import { createHash, randomUUID } from 'node:crypto';
import type {
  AdminDashboard,
  EventCandidate,
  EventDraft,
  SourceRun,
  Tip,
} from '../shared/types.ts';
import { Repository } from './repository.ts';
import {
  classifyTip,
  ConflictError,
  normalize,
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
} from './ai/openrouter.ts';
import { readTipSource } from './ai/tip-source.ts';
import type { Config } from './config.ts';
import { inferDiscovery, isFree } from './discovery.ts';

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
    const deadlineMs = maxDurationMs === undefined ? Infinity : Date.now() + maxDurationMs;
    this.collecting = true;
    let lease: string | null = null;
    try {
      lease = await this.repo.acquireLease('collection', 30 * 60_000);
      if (!lease) return false;
      const enabledSources = this.repo.sources.filter((source) => source.enabled);
      for (const [sourceIndex, source] of enabledSources.entries()) {
        const sourceStarted = Date.now();
        // A slow source must leave the remaining sources a fair share of the run.
        // Fast/cache-backed sources give their unused time to subsequent sources.
        const sourceDeadlineMs =
          sourceStarted +
          Math.max(0, deadlineMs - sourceStarted) / (enabledSources.length - sourceIndex);
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
          for (const page of result.extractionPages ?? []) {
            const key = createHash('sha256')
              .update(
                JSON.stringify({
                  source: source.id,
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
                if (sourceDeadlineMs - Date.now() < 50_000) {
                  run.warnings.push(
                    `${page.url}: AI obrada odgođena zbog vremenskog ograničenja; izvorni događaji bit će spremljeni.`,
                  );
                  continue;
                }
                extraction = await extractEvents(
                  { ...page, sourceId: source.id, now: new Date().toISOString() },
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
          for (const candidate of candidates) {
            try {
              await this.repo.upsert(candidate);
              run.imported++;
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
      return true;
    } finally {
      this.collecting = false;
      if (lease) await this.repo.releaseLease('collection', lease);
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
          tip.note === note &&
          tip.url === url &&
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
  async prepareTip(id: string, force = false): Promise<Tip> {
    const existing = await this.repo.tip(id);
    if (!existing) throw new ValidationError('Dojava ne postoji.');
    if (['archived', 'accepted', 'rejected'].includes(existing.status) || this.preparing.has(id))
      return existing;
    this.preparing.add(id);
    let lease: string | null = null;
    try {
      lease = await this.repo.acquireLease(`tip:${id}`, 5 * 60_000);
      const tip = await this.repo.tip(id);
      if (!tip) throw new ValidationError('Dojava ne postoji.');
      if (!lease || !['inbox', 'draft'].includes(tip.status)) return tip;
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
      if (matched) {
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
        return await this.savePreparedTip(tip, {
          status: 'draft',
          draft,
          matchedEventId: matched.id,
          verification: 'source_match',
          reason:
            'Pronađen je mogući isti događaj u prikupljenim izvorima. Prihvaćanje povezuje dojavu bez stvaranja duplikata.' +
            (!upcoming(matched)
              ? ' Događaj je već završio i nije za objavu među nadolazećim događajima.'
              : ''),
        });
      }
      const source =
        tip.url && this.config.ai.apiKey && this.config.ai.monthlyBudgetUsd > 0
          ? await this.tipReader(tip.url, { force, deadlineMs: Date.now() + 20_000 })
          : {};
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
            day: new Date().toISOString().slice(0, 10),
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
      return await this.savePreparedTip(tip, {
        draft: draft ?? tip.draft,
        status:
          result.classification === 'spam' && !draft ? 'archived' : draft ? 'draft' : tip.status,
        reason: [source.reason, result.reason].filter(Boolean).join(' '),
        matchedEventId: null,
        verification: 'unverified',
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
        const unchanged =
          matched &&
          Object.entries(draft).every(([key, value]) =>
            key === 'sourceUrl'
              ? matched.sources.some((source) => source.url === value)
              : matched[key as keyof typeof matched] === value,
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
