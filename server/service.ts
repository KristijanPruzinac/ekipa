import { createHash, randomUUID } from 'node:crypto';
import type { AdminDashboard, EventDraft, SourceRun, Tip } from '../shared/types.ts';
import { Repository } from './repository.ts';
import {
  classifyTip,
  normalize,
  safeUrl,
  tipDates,
  validateDraft,
  ValidationError,
} from './validation.ts';
import { fetchSource } from './ingestion/index.ts';
import { prepareTip as aiPrepareTip, extractEvents } from './ai/openrouter.ts';
import type { Config } from './config.ts';

export class WagzService {
  collecting = false;
  private preparing = new Set<string>();
  constructor(
    public repo: Repository,
    public config: Config,
    private fetcher = fetchSource,
  ) {}
  ledger = {
    reserve: (ceiling: number) => this.repo.reserveAi(ceiling, this.config.ai.monthlyBudgetUsd),
    settle: (id: string, actual: number | null) => this.repo.settleAi(id, actual),
  };
  dashboard(): AdminDashboard {
    return {
      events: this.repo.events(),
      tips: this.repo.tips(),
      sources: this.repo.sourceHealth(),
      runs: this.repo.runs(),
      collecting: this.collecting,
      autoPublish: this.repo.autoPublish(),
      ai: {
        enabled: Boolean(this.config.ai.apiKey) && this.config.ai.monthlyBudgetUsd > 0,
        description: this.config.ai.apiKey
          ? `OpenRouter · ${this.config.ai.model} · ovaj mjesec $${this.repo.aiSpent().toFixed(3)} / $${this.config.ai.monthlyBudgetUsd.toFixed(2)}. AI prijedlozi čekaju pregled.`
          : 'OpenRouter je pripremljen. Dodaj OPENROUTER_API_KEY u .env. Mjesečni proračun: $1. Bez ključa nema AI poziva ni troška.',
      },
    };
  }
  async collect(force = false): Promise<boolean> {
    if (this.collecting) return false;
    this.collecting = true;
    try {
      for (const source of this.repo.sources.filter((source) => source.enabled)) {
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
        this.repo.saveRun(run);
        try {
          const result = await this.fetcher(source.id, { force });
          run.discovered = result.discovered;
          run.skipped = result.skipped;
          run.pagesFetched = result.pagesFetched;
          run.warnings = result.warnings;
          for (const page of result.extractionPages ?? []) {
            const key = createHash('sha256')
              .update(
                JSON.stringify({
                  source: source.id,
                  url: page.url,
                  text: page.text,
                  model: this.config.ai.model,
                }),
              )
              .digest('hex');
            type Extraction = Awaited<ReturnType<typeof extractEvents>>;
            let extraction = this.repo.cached<Extraction>(`extract:${key}`);
            if (!extraction) {
              extraction = await extractEvents(
                { ...page, sourceId: source.id, now: new Date().toISOString() },
                this.config.ai,
                this.ledger,
              );
              if (extraction.complete || extraction.events.length)
                this.repo.cache(`extract:${key}`, extraction);
            }
            if (!extraction.events.length || !extraction.complete)
              run.warnings.push(`${page.url}: ${extraction.reason}`);
            result.events.push(...extraction.events);
          }
          for (const candidate of result.events) {
            try {
              this.repo.upsert(candidate);
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
        this.repo.saveRun(run);
      }
      return true;
    } finally {
      this.collecting = false;
    }
  }
  submitTip(input: { note?: unknown; url?: unknown; website?: unknown }): Tip {
    if (typeof input.note !== 'string' || input.note.trim().length < 3 || input.note.length > 2000)
      throw new ValidationError('Napiši dojavu od 3 do 2000 znakova.');
    const note = input.note.trim();
    const url = safeUrl(input.url);
    const existing = this.repo
      .tips()
      .find(
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
  }
  async prepareTip(id: string): Promise<Tip> {
    const tip = this.repo.tip(id);
    if (!tip) throw new ValidationError('Dojava ne postoji.');
    if (['archived', 'accepted', 'rejected'].includes(tip.status) || this.preparing.has(id))
      return tip;
    this.preparing.add(id);
    try {
      const all = this.repo.events();
      const byUrl = tip.url
        ? all.filter((event) => event.sources.some((source) => source.url === tip.url))
        : [];
      const byTitle = all.filter((event) => {
        const title = normalize(event.title);
        return title.length >= 12 && normalize(tip.note).includes(title);
      });
      const dates = tipDates(tip.note);
      const compatibleDate = (event: (typeof all)[number]) =>
        !dates.invalid &&
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
        return this.repo.saveTip({
          ...tip,
          status: 'draft',
          draft,
          matchedEventId: matched.id,
          verification: 'source_match',
          reason:
            'Pronađen je mogući isti događaj u prikupljenim izvorima. Prihvaćanje povezuje dojavu bez stvaranja duplikata.',
          updatedAt: new Date().toISOString(),
        });
      }
      const key = createHash('sha256')
        .update(
          JSON.stringify({
            note: tip.note,
            url: tip.url,
            model: this.config.ai.model,
            searchEnabled: this.config.ai.searchEnabled,
            day: new Date().toISOString().slice(0, 10),
          }),
        )
        .digest('hex');
      type Result = Awaited<ReturnType<typeof aiPrepareTip>>;
      let result = this.repo.cached<Result>(`tip:${key}`);
      if (!result) {
        result = await aiPrepareTip(
          { note: tip.note, url: tip.url, now: new Date().toISOString() },
          this.config.ai,
          this.ledger,
        );
        if (result.attempted && result.costUsd !== null) this.repo.cache(`tip:${key}`, result);
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
      const latest = this.repo.tip(id)!;
      if (latest.updatedAt !== tip.updatedAt || !['inbox', 'draft'].includes(latest.status))
        return latest;
      return this.repo.saveTip({
        ...latest,
        draft: draft ?? latest.draft,
        status:
          result.classification === 'spam' && !draft ? 'archived' : draft ? 'draft' : latest.status,
        reason: result.reason,
        matchedEventId: null,
        verification: 'unverified',
        updatedAt: new Date().toISOString(),
      });
    } finally {
      this.preparing.delete(id);
    }
  }
  updateTip(id: string, action: string, rawDraft?: unknown): Tip {
    const tip = this.repo.tip(id);
    if (!tip) throw new ValidationError('Dojava ne postoji.');
    const stamp = new Date().toISOString();
    if (action === 'archive')
      return this.repo.saveTip({
        ...tip,
        status: 'archived',
        reason: 'Ručno arhivirano. Dojava se može vratiti.',
        updatedAt: stamp,
      });
    if (action === 'restore')
      return this.repo.saveTip({
        ...tip,
        status: tip.draft ? 'draft' : 'inbox',
        reason: 'Dojava je vraćena na pregled.',
        updatedAt: stamp,
      });
    if (action === 'reject')
      return this.repo.saveTip({
        ...tip,
        status: 'rejected',
        reason: 'Odbijeno nakon pregleda.',
        updatedAt: stamp,
      });
    if (!['save', 'accept'].includes(action)) throw new ValidationError('Nepoznata radnja.');
    const draft = validateDraft(rawDraft ?? tip.draft);
    if (action === 'save')
      return this.repo.saveTip({ ...tip, draft, status: 'draft', updatedAt: stamp });
    if (tip.status === 'accepted') return tip;
    if (!draft.venue)
      throw new ValidationError('Za objavu je potrebno potvrđeno mjesto održavanja.');
    let eventId = tip.matchedEventId;
    if (eventId) this.repo.editEvent(eventId, 'published', draft);
    else {
      eventId = this.repo.publishTip(tip.id, draft).id;
    }
    return this.repo.saveTip({
      ...tip,
      draft,
      matchedEventId: eventId,
      status: 'accepted',
      reason: 'Događaj je odobren i objavljen.',
      updatedAt: stamp,
    });
  }
}
