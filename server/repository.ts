import { createHash, randomUUID } from 'node:crypto';
import { PostgresDatabase, SqliteDatabase, type Database, type Row } from './database.ts';
import { isFree, mergeDiscovery } from './discovery.ts';
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
  ConflictError,
  normalize,
  upcoming,
  validateCandidate,
  validateDraft,
  ValidationError,
} from './validation.ts';

const decode = <T>(row: Row): T => JSON.parse(String(row.payload)) as T;

export class Repository {
  private database: Database;
  private closePromise?: Promise<void>;
  readonly ready: Promise<void>;
  sources: SourceDefinition[];
  constructor(path: string, sources: SourceDefinition[], autoPublish = true, database?: Database) {
    this.database = database ?? new SqliteDatabase(path);
    this.sources = sources;
    this.ready = this.database.initialize(autoPublish);
  }
  static async fromPostgres(databaseUrl: string, sources: SourceDefinition[], autoPublish = true) {
    const repository = new Repository(
      ':memory:',
      sources,
      autoPublish,
      PostgresDatabase.connect(databaseUrl),
    );
    try {
      await repository.ready;
      return repository;
    } catch (error) {
      await repository.close();
      throw error;
    }
  }
  async close() {
    this.closePromise ??= this.ready.catch(() => undefined).then(() => this.database.close());
    await this.closePromise;
  }
  private async operation<T>(work: () => Promise<T>, write = false): Promise<T> {
    await this.ready;
    return this.database.transaction(work, write);
  }
  async transaction<T>(work: (repository: Repository) => Promise<T>): Promise<T> {
    return this.operation(() => work(this), true);
  }
  async autoPublish(): Promise<boolean> {
    return this.operation(async () => {
      const [setting] = await this.database.query('SELECT value FROM settings WHERE key=?', [
        'autoPublish',
      ]);
      return JSON.parse(String(setting.value));
    });
  }
  async setAutoPublish(value: boolean) {
    await this.operation(async () => {
      await this.database.query('UPDATE settings SET value=? WHERE key=?', [
        JSON.stringify(value),
        'autoPublish',
      ]);
    }, true);
  }
  private async saveEvent(event: WagzEvent) {
    await this.database.query(
      'INSERT INTO events(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      [event.id, JSON.stringify(event)],
    );
  }
  async events(): Promise<WagzEvent[]> {
    return this.operation(async () => {
      const rows = await this.database.query('SELECT payload FROM events');
      const evidence = await this.database.query('SELECT * FROM evidence ORDER BY last_seen DESC');
      return rows
        .map((row) => {
          const event = decode<WagzEvent>(row);
          event.sources = evidence
            .filter((item) => item.event_id === event.id)
            .map((item) => ({
              sourceId: String(item.source_id),
              sourceName:
                this.sources.find((source) => source.id === item.source_id)?.name ??
                'Dojava zajednice',
              url: String(item.url),
              lastSeenAt: String(item.last_seen),
            }));
          return event;
        })
        .sort((a, b) => a.startsAt.localeCompare(b.startsAt) || a.title.localeCompare(b.title));
    });
  }
  async event(id: string): Promise<WagzEvent | undefined> {
    return (await this.events()).find((event) => event.id === id);
  }
  async publicEvents(now = new Date()) {
    return (await this.events()).filter(
      (event) => event.publication === 'published' && upcoming(event, now),
    );
  }

  async upsert(raw: EventCandidate, now = new Date(), forceDraft = false): Promise<WagzEvent> {
    const candidate = validateCandidate(raw);
    const stamp = now.toISOString();
    // Identity lookup and writes share the transaction, including CLI/server overlap.
    return this.operation(async () => {
      const [known] = await this.database.query(
        'SELECT event_id FROM evidence WHERE source_id=? AND external_id=?',
        [candidate.sourceId, candidate.externalId],
      );
      const all = await this.events();
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
        if (!current.manuallyEdited)
          event.discovery = mergeDiscovery(
            current.discovery,
            fields.discovery,
            sourceUrl,
            event.price,
          );
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
          (await this.autoPublish()) &&
          event.venue
        )
          event.publication = 'published';
      } else {
        const eligible = !forceDraft && !ambiguous && (await this.autoPublish());
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
      await this.saveEvent(event);
      await this.database.query(
        'INSERT INTO evidence(source_id,external_id,event_id,url,last_seen) VALUES (?,?,?,?,?) ON CONFLICT(source_id,external_id) DO UPDATE SET event_id=excluded.event_id,url=excluded.url,last_seen=excluded.last_seen',
        [sourceId, externalId, event.id, sourceUrl, stamp],
      );
      return (await this.event(event.id))!;
    }, true);
  }

  async editEvent(
    id: string,
    publication?: Publication,
    fields?: Partial<EventDraft>,
  ): Promise<WagzEvent> {
    return this.operation(async () => {
      const current = await this.event(id);
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
      if (draft)
        event.discovery = {
          audiences: [],
          audienceEvidence: [],
          prominence: null,
          free: isFree(event.price),
        };
      if (event.publication === 'published' && !event.venue)
        throw new ValidationError('Prije objave upiši potvrđeno mjesto održavanja.');
      await this.saveEvent(event);
      if (draft?.sourceUrl && draft.sourceUrl !== current.sources[0]?.url)
        await this.database.query(
          'INSERT INTO evidence(source_id,external_id,event_id,url,last_seen) VALUES (?,?,?,?,?) ON CONFLICT(source_id,external_id) DO UPDATE SET event_id=excluded.event_id,url=excluded.url,last_seen=excluded.last_seen',
          ['manual', id, id, draft.sourceUrl, event.updatedAt],
        );
      return (await this.event(id))!;
    }, true);
  }
  async publishTip(tipId: string, input: EventDraft): Promise<WagzEvent> {
    const draft = validateDraft(input);
    if (!draft.venue)
      throw new ValidationError('Za objavu je potrebno potvrđeno mjesto održavanja.');
    return this.operation(async () => {
      const id = `tip-${tipId}`;
      if (await this.event(id)) return this.editEvent(id, 'published', draft);
      // A source import or another approval may have arrived after preparation.
      // Resolve identity under the same write lock as publication.
      const possible = (await this.events()).filter(
        (event) =>
          normalize(event.title) === normalize(draft.title) &&
          event.startsAt.slice(0, 10) === draft.startsAt.slice(0, 10) &&
          (event.startsAt.length === 10 ||
            draft.startsAt.length === 10 ||
            Date.parse(event.startsAt) === Date.parse(draft.startsAt)) &&
          (!event.venue || normalize(event.venue) === normalize(draft.venue!)),
      );
      const exact = possible.filter(
        (event) =>
          event.startsAt.length > 10 &&
          draft.startsAt.length > 10 &&
          event.venue &&
          normalize(event.venue) === normalize(draft.venue!),
      );
      if (possible.length === 1 && exact.length === 1) {
        const existing = exact[0];
        if (existing.publication === 'rejected' || existing.status !== 'scheduled')
          throw new ConflictError(
            'Isti događaj već postoji kao odbijen, otkazan ili odgođen. Pregledaj postojeći događaj.',
          );
        return existing.publication === 'published'
          ? existing
          : this.editEvent(existing.id, 'published');
      }
      if (possible.length)
        throw new ConflictError(
          'Mogući isti događaj već postoji. Provjeri točan termin i poveži dojavu prije objave.',
        );
      const { sourceUrl, ...fields } = draft;
      const stamp = new Date().toISOString();
      await this.saveEvent({
        ...fields,
        id,
        publication: 'published',
        sources: [],
        firstSeenAt: stamp,
        updatedAt: stamp,
        manuallyEdited: true,
      });
      if (sourceUrl)
        await this.database.query(
          'INSERT INTO evidence(source_id,external_id,event_id,url,last_seen) VALUES (?,?,?,?,?)',
          ['community', tipId, id, sourceUrl, stamp],
        );
      return (await this.event(id))!;
    }, true);
  }
  /** Shared by all API instances; raw client addresses are never persisted. */
  async consumeTipQuota(client: string, now = Date.now()): Promise<boolean> {
    if (!client || client.length > 256 || !Number.isSafeInteger(now) || now < 0)
      throw new ValidationError('Neispravni podaci ograničenja dojava.');
    const clientKey = createHash('sha256').update(`wagz-tip-quota:${client}`).digest('hex');
    return this.operation(async () => {
      // Cap cleanup work per request; expired rows never constrain a new window.
      await this.database.query(
        'DELETE FROM tip_quotas WHERE client_key IN (SELECT client_key FROM tip_quotas WHERE expires_at<=? ORDER BY expires_at LIMIT 128)',
        [now],
      );
      const [row] = await this.database.query(
        'SELECT attempts,expires_at FROM tip_quotas WHERE client_key=?',
        [clientKey],
      );
      const active = row && Number(row.expires_at) > now;
      if (active && Number(row.attempts) >= 5) return false;
      await this.database.query(
        'INSERT INTO tip_quotas(client_key,attempts,expires_at) VALUES (?,?,?) ON CONFLICT(client_key) DO UPDATE SET attempts=excluded.attempts,expires_at=excluded.expires_at',
        [
          clientKey,
          active ? Number(row.attempts) + 1 : 1,
          active ? Number(row.expires_at) : now + 60 * 60_000,
        ],
      );
      return true;
    }, true);
  }
  async tips(): Promise<Tip[]> {
    return this.operation(async () =>
      (await this.database.query('SELECT payload FROM tips'))
        .map((row) => decode<Tip>(row))
        .sort((a, b) => b.submittedAt.localeCompare(a.submittedAt)),
    );
  }
  async tip(id: string) {
    return (await this.tips()).find((tip) => tip.id === id);
  }
  async saveTip(tip: Tip): Promise<Tip> {
    return this.operation(async () => {
      const current = await this.tip(tip.id);
      const saved = { ...tip, revision: (current?.revision ?? 0) + 1 };
      await this.database.query(
        'INSERT INTO tips(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        [tip.id, JSON.stringify(saved)],
      );
      return saved;
    }, true);
  }
  async runs(): Promise<SourceRun[]> {
    return this.operation(async () =>
      (await this.database.query('SELECT payload FROM runs ORDER BY rowid DESC LIMIT 100')).map(
        (row) => decode<SourceRun>(row),
      ),
    );
  }
  async saveRun(run: SourceRun) {
    await this.operation(async () => {
      await this.database.query(
        'INSERT INTO runs(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        [run.id, JSON.stringify(run)],
      );
    }, true);
  }
  async sourceHealth(): Promise<SourceHealth[]> {
    return this.operation(async () => {
      const runs = await this.runs();
      const counts = await this.database.query(
        'SELECT source_id,COUNT(DISTINCT event_id) AS n FROM evidence GROUP BY source_id',
      );
      return this.sources.map((source) => ({
        ...source,
        latestRun: runs.find((run) => run.sourceId === source.id) ?? null,
        lastSuccessAt:
          runs.find(
            (run) =>
              run.sourceId === source.id &&
              (run.status === 'success' || (run.status === 'partial' && run.imported > 0)),
          )?.finishedAt ?? null,
        eventCount: Number(counts.find((row) => row.source_id === source.id)?.n ?? 0),
      }));
    });
  }
  async cached<T>(key: string): Promise<T | null> {
    return this.operation(async () => {
      const [row] = await this.database.query('SELECT payload FROM ai_cache WHERE key=?', [key]);
      return row ? decode<T>(row) : null;
    });
  }
  async cache(key: string, value: unknown) {
    await this.operation(async () => {
      await this.database.query(
        'INSERT INTO ai_cache(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
        [key, JSON.stringify(value)],
      );
    }, true);
  }
  async aiSpent(now = new Date()): Promise<number> {
    return this.operation(async () => {
      const [row] = await this.database.query(
        'SELECT COALESCE(SUM(amount),0) AS n FROM ai_charges WHERE month=?',
        [now.toISOString().slice(0, 7)],
      );
      return Number(row.n);
    });
  }
  async reserveAi(ceiling: number, budget: number): Promise<string | null> {
    if (!Number.isFinite(ceiling) || ceiling <= 0 || !Number.isFinite(budget) || budget <= 0)
      return null;
    return this.operation(async () => {
      if ((await this.aiSpent()) + ceiling > budget) return null;
      const id = randomUUID();
      await this.database.query('INSERT INTO ai_charges(id,month,amount,state) VALUES (?,?,?,?)', [
        id,
        new Date().toISOString().slice(0, 7),
        ceiling,
        'reserved',
      ]);
      return id;
    }, true);
  }
  async settleAi(id: string, actual: number | null) {
    await this.operation(async () => {
      if (actual !== null && Number.isFinite(actual) && actual >= 0)
        await this.database.query('UPDATE ai_charges SET amount=?,state=? WHERE id=?', [
          actual,
          'settled',
          id,
        ]);
      else await this.database.query('UPDATE ai_charges SET state=? WHERE id=?', ['unknown', id]);
    }, true);
  }

  async acquireLease(name: string, ttlMs: number): Promise<string | null> {
    if (!name || !Number.isFinite(ttlMs) || ttlMs <= 0)
      throw new ValidationError('Neispravno trajanje ili naziv zaključavanja.');
    return this.operation(async () => {
      if (await this.isLeaseActive(name)) return null;
      const token = randomUUID();
      await this.database.query(
        'INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
        [`lease:${name}`, JSON.stringify({ token, until: Date.now() + ttlMs })],
      );
      return token;
    }, true);
  }
  async releaseLease(name: string, token: string): Promise<void> {
    await this.operation(async () => {
      const [row] = await this.database.query('SELECT value FROM settings WHERE key=?', [
        `lease:${name}`,
      ]);
      if (row && JSON.parse(String(row.value)).token === token)
        await this.database.query('DELETE FROM settings WHERE key=?', [`lease:${name}`]);
    }, true);
  }
  async isLeaseActive(name: string): Promise<boolean> {
    return this.operation(async () => {
      const [row] = await this.database.query('SELECT value FROM settings WHERE key=?', [
        `lease:${name}`,
      ]);
      return Boolean(row && JSON.parse(String(row.value)).until > Date.now());
    });
  }
  async activeLeaseIds(prefix: string): Promise<string[]> {
    return this.operation(async () => {
      const stem = `lease:${prefix}`;
      return (await this.database.query('SELECT key,value FROM settings'))
        .filter((row) => String(row.key).startsWith(stem))
        .filter((row) => JSON.parse(String(row.value)).until > Date.now())
        .map((row) => String(row.key).slice(stem.length));
    });
  }
}

export async function createRepository(
  path: string,
  sources: SourceDefinition[],
  autoPublish = true,
  databaseUrl?: string,
): Promise<Repository> {
  if (databaseUrl) return Repository.fromPostgres(databaseUrl, sources, autoPublish);
  const repository = new Repository(path, sources, autoPublish);
  try {
    await repository.ready;
    return repository;
  } catch (error) {
    await repository.close();
    throw error;
  }
}
