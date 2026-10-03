import { DatabaseSync } from 'node:sqlite';
import { randomUUID } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import type {
  EventCandidate,
  EventDraft,
  Publication,
  SourceDefinition,
  SourceHealth,
  SourceRun,
  Tip,
  WagzEvent,
} from '../shared/types.ts';
import {
  normalize,
  upcoming,
  validateCandidate,
  validateDraft,
  ValidationError,
} from './validation.ts';

type Row = Record<string, unknown>;
const decode = <T>(row: Row): T => JSON.parse(String(row.payload)) as T;

export class Repository {
  db: DatabaseSync;
  sources: SourceDefinition[];
  constructor(path: string, sources: SourceDefinition[], autoPublish = true) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path, { timeout: 5000 });
    this.sources = sources;
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
      CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS evidence (source_id TEXT NOT NULL, external_id TEXT NOT NULL, event_id TEXT NOT NULL REFERENCES events(id), url TEXT NOT NULL, last_seen TEXT NOT NULL, PRIMARY KEY(source_id, external_id));
      CREATE INDEX IF NOT EXISTS evidence_event ON evidence(event_id);
      CREATE TABLE IF NOT EXISTS tips (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS runs (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS ai_charges (id TEXT PRIMARY KEY, month TEXT NOT NULL, amount REAL NOT NULL, state TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS ai_cache (key TEXT PRIMARY KEY, payload TEXT NOT NULL);
    `);
    this.db
      .prepare('INSERT OR IGNORE INTO settings(key,value) VALUES (?,?)')
      .run('autoPublish', JSON.stringify(autoPublish));
  }
  close() {
    this.db.close();
  }
  autoPublish(): boolean {
    return JSON.parse(
      String(this.db.prepare('SELECT value FROM settings WHERE key=?').get('autoPublish')!.value),
    );
  }
  setAutoPublish(value: boolean) {
    this.db
      .prepare('UPDATE settings SET value=? WHERE key=?')
      .run(JSON.stringify(value), 'autoPublish');
  }
  private saveEvent(event: WagzEvent) {
    this.db
      .prepare(
        'INSERT INTO events(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      )
      .run(event.id, JSON.stringify(event));
  }
  events(): WagzEvent[] {
    return (this.db.prepare('SELECT payload FROM events').all() as Row[])
      .map((row) => {
        const event = decode<WagzEvent>(row);
        event.sources = (
          this.db
            .prepare('SELECT * FROM evidence WHERE event_id=? ORDER BY last_seen DESC')
            .all(event.id) as Row[]
        ).map((evidence) => ({
          sourceId: String(evidence.source_id),
          sourceName:
            this.sources.find((source) => source.id === evidence.source_id)?.name ??
            'Dojava zajednice',
          url: String(evidence.url),
          lastSeenAt: String(evidence.last_seen),
        }));
        return event;
      })
      .sort((a, b) => a.startsAt.localeCompare(b.startsAt) || a.title.localeCompare(b.title));
  }
  event(id: string): WagzEvent | undefined {
    return this.events().find((event) => event.id === id);
  }
  publicEvents(now = new Date()) {
    return this.events().filter(
      (event) => event.publication === 'published' && upcoming(event, now),
    );
  }

  upsert(raw: EventCandidate, now = new Date(), forceDraft = false): WagzEvent {
    const candidate = validateCandidate(raw);
    const stamp = now.toISOString();
    // Identity lookup and writes share the transaction, including CLI/server overlap.
    this.db.exec('BEGIN IMMEDIATE');
    let eventId: string;
    try {
      const known = this.db
        .prepare('SELECT event_id FROM evidence WHERE source_id=? AND external_id=?')
        .get(candidate.sourceId, candidate.externalId);
      const all = this.events();
      let current = known ? all.find((event) => event.id === known.event_id) : undefined;
      const otherEvidence =
        current?.sources.some((source) => source.sourceId !== candidate.sourceId) ?? false;
      const identityTime =
        current &&
        otherEvidence &&
        candidate.startsAt.length === 10 &&
        current.startsAt.length > 10 &&
        candidate.startsAt === current.startsAt.slice(0, 10)
          ? current.startsAt
          : candidate.startsAt;
      const identityVenue = otherEvidence
        ? (candidate.venue ?? current?.venue ?? null)
        : candidate.venue;
      const possible = all.filter((event) => {
        if (
          event.id === current?.id ||
          normalize(event.title) !== normalize(candidate.title) ||
          event.startsAt.slice(0, 10) !== identityTime.slice(0, 10)
        )
          return false;
        if (
          event.startsAt.length > 10 &&
          identityTime.length > 10 &&
          Date.parse(event.startsAt) !== Date.parse(identityTime)
        )
          return false;
        if (event.venue && identityVenue && normalize(event.venue) !== normalize(identityVenue))
          return false;
        return true;
      });
      // Missing time or venue cannot establish that two independently identified
      // source rows are the same occurrence, even if today's match is unique.
      const exact = possible.filter(
        (event) =>
          event.startsAt.length > 10 &&
          identityTime.length > 10 &&
          event.venue &&
          identityVenue &&
          normalize(event.venue) === normalize(identityVenue),
      );
      if (!current && exact.length === 1) current = exact[0];
      // A collision already held for review must not demote the precise public
      // occurrence on its next ordinary refresh.
      const unresolved = (event: WagzEvent) =>
        event.publication === 'draft' &&
        event.autoPublishEligible === false &&
        !event.manuallyEdited;
      const ambiguous = known
        ? exact.some((event) => !unresolved(event)) ||
          ((identityTime.length === 10 || !identityVenue) &&
            possible.some((event) => !unresolved(event)))
        : !current && possible.length > 0;
      const { sourceId, sourceUrl, externalId, ...fields } = candidate;
      let event: WagzEvent;
      if (current) {
        // A weaker refresh from another source cannot erase an already known
        // venue/time. A genuinely changed source date still remains a change.
        const refreshed = otherEvidence
          ? {
              ...fields,
              startsAt:
                fields.startsAt.length === 10 &&
                current.startsAt.length > 10 &&
                fields.startsAt === current.startsAt.slice(0, 10)
                  ? current.startsAt
                  : fields.startsAt,
              venue: fields.venue ?? current.venue,
              address: fields.address ?? current.address,
              description: fields.description || current.description,
              endsAt: fields.endsAt ?? current.endsAt,
              price: fields.price ?? current.price,
            }
          : fields;
        const nextFields = current.manuallyEdited
          ? {}
          : known
            ? refreshed
            : {
                description: current.description || fields.description,
                endsAt: current.endsAt ?? fields.endsAt,
                address: current.address ?? fields.address,
                price: current.price ?? fields.price,
                status: fields.status !== 'scheduled' ? fields.status : current.status,
              };
        event = { ...current, ...nextFields, updatedAt: stamp };
        const eligible =
          current.autoPublishEligible ??
          (current.publication === 'draft' && !current.venue && !current.manuallyEdited);
        event.autoPublishEligible = eligible;
        if (ambiguous && !current.manuallyEdited) {
          event.autoPublishEligible = false;
          // Preserve explicit operator publication/rejection decisions. Imported
          // collisions remain held even after their source supplies missing facts.
          if (event.publication !== 'rejected' && (eligible || event.publication === 'draft'))
            event.publication = 'draft';
        } else if (
          event.publication === 'draft' &&
          eligible &&
          !forceDraft &&
          this.autoPublish() &&
          event.venue
        )
          event.publication = 'published';
      } else {
        const eligible = !forceDraft && !ambiguous && this.autoPublish();
        event = {
          ...fields,
          id: randomUUID(),
          publication: eligible && fields.venue ? 'published' : 'draft',
          sources: [],
          firstSeenAt: stamp,
          updatedAt: stamp,
          manuallyEdited: false,
          autoPublishEligible: eligible,
        };
      }
      this.saveEvent(event);
      this.db
        .prepare(
          'INSERT INTO evidence(source_id,external_id,event_id,url,last_seen) VALUES (?,?,?,?,?) ON CONFLICT(source_id,external_id) DO UPDATE SET event_id=excluded.event_id,url=excluded.url,last_seen=excluded.last_seen',
        )
        .run(sourceId, externalId, event.id, sourceUrl, stamp);
      eventId = event.id;
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
    return this.event(eventId)!;
  }

  editEvent(id: string, publication?: Publication, fields?: Partial<EventDraft>): WagzEvent {
    const current = this.event(id);
    if (!current) throw new ValidationError('Događaj ne postoji.');
    if (publication && !['published', 'draft', 'rejected'].includes(publication))
      throw new ValidationError('Neispravan status objave.');
    const draft = fields
      ? validateDraft({ ...current, sourceUrl: current.sources[0]?.url ?? null, ...fields })
      : null;
    const event = {
      ...current,
      ...(draft
        ? Object.fromEntries(Object.entries(draft).filter(([key]) => key !== 'sourceUrl'))
        : {}),
      publication: publication ?? current.publication,
      updatedAt: new Date().toISOString(),
      manuallyEdited: fields ? true : current.manuallyEdited,
      autoPublishEligible: false,
    };
    if (event.publication === 'published' && !event.venue)
      throw new ValidationError('Prije objave upiši potvrđeno mjesto održavanja.');
    this.saveEvent(event);
    if (draft?.sourceUrl && draft.sourceUrl !== current.sources[0]?.url)
      this.db
        .prepare(
          'INSERT OR REPLACE INTO evidence(source_id,external_id,event_id,url,last_seen) VALUES (?,?,?,?,?)',
        )
        .run('manual', id, id, draft.sourceUrl, event.updatedAt);
    return this.event(id)!;
  }
  publishTip(tipId: string, input: EventDraft): WagzEvent {
    const draft = validateDraft(input);
    if (!draft.venue)
      throw new ValidationError('Za objavu je potrebno potvrđeno mjesto održavanja.');
    const id = `tip-${tipId}`;
    if (this.event(id)) return this.editEvent(id, 'published', draft);
    const { sourceUrl, ...fields } = draft;
    const stamp = new Date().toISOString();
    this.saveEvent({
      ...fields,
      id,
      publication: 'published',
      sources: [],
      firstSeenAt: stamp,
      updatedAt: stamp,
      manuallyEdited: true,
    });
    if (sourceUrl)
      this.db
        .prepare(
          'INSERT INTO evidence(source_id,external_id,event_id,url,last_seen) VALUES (?,?,?,?,?)',
        )
        .run('community', tipId, id, sourceUrl, stamp);
    return this.event(id)!;
  }
  tips(): Tip[] {
    return (this.db.prepare('SELECT payload FROM tips').all() as Row[])
      .map((row) => decode<Tip>(row))
      .sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));
  }
  tip(id: string) {
    return this.tips().find((tip) => tip.id === id);
  }
  saveTip(tip: Tip): Tip {
    this.db
      .prepare(
        'INSERT INTO tips(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      )
      .run(tip.id, JSON.stringify(tip));
    return tip;
  }
  runs(): SourceRun[] {
    return (
      this.db.prepare('SELECT payload FROM runs ORDER BY rowid DESC LIMIT 100').all() as Row[]
    ).map((row) => decode<SourceRun>(row));
  }
  saveRun(run: SourceRun) {
    this.db
      .prepare(
        'INSERT INTO runs(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      )
      .run(run.id, JSON.stringify(run));
  }
  sourceHealth(): SourceHealth[] {
    const runs = this.runs();
    return this.sources.map((source) => ({
      ...source,
      latestRun: runs.find((run) => run.sourceId === source.id) ?? null,
      lastSuccessAt:
        runs.find(
          (run) =>
            run.sourceId === source.id &&
            (run.status === 'success' || (run.status === 'partial' && run.imported > 0)),
        )?.finishedAt ?? null,
      eventCount: Number(
        this.db
          .prepare('SELECT COUNT(DISTINCT event_id) AS n FROM evidence WHERE source_id=?')
          .get(source.id)!.n,
      ),
    }));
  }
  cached<T>(key: string): T | null {
    const row = this.db.prepare('SELECT payload FROM ai_cache WHERE key=?').get(key);
    return row ? decode<T>(row as Row) : null;
  }
  cache(key: string, value: unknown) {
    this.db
      .prepare('INSERT OR REPLACE INTO ai_cache(key,payload) VALUES (?,?)')
      .run(key, JSON.stringify(value));
  }
  aiSpent(now = new Date()): number {
    return Number(
      this.db
        .prepare('SELECT COALESCE(SUM(amount),0) AS n FROM ai_charges WHERE month=?')
        .get(now.toISOString().slice(0, 7))!.n,
    );
  }
  reserveAi(ceiling: number, budget: number): string | null {
    if (!Number.isFinite(ceiling) || ceiling <= 0 || !Number.isFinite(budget) || budget <= 0)
      return null;
    this.db.exec('BEGIN IMMEDIATE');
    try {
      if (this.aiSpent() + ceiling > budget) {
        this.db.exec('ROLLBACK');
        return null;
      }
      const id = randomUUID();
      this.db
        .prepare('INSERT INTO ai_charges(id,month,amount,state) VALUES (?,?,?,?)')
        .run(id, new Date().toISOString().slice(0, 7), ceiling, 'reserved');
      this.db.exec('COMMIT');
      return id;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }
  settleAi(id: string, actual: number | null) {
    if (actual !== null && Number.isFinite(actual) && actual >= 0)
      this.db
        .prepare('UPDATE ai_charges SET amount=?,state=? WHERE id=?')
        .run(actual, 'settled', id);
    else this.db.prepare('UPDATE ai_charges SET state=? WHERE id=?').run('unknown', id);
  }
}
