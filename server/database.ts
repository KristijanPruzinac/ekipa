import { AsyncLocalStorage } from 'node:async_hooks';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { DatabaseSync, type SQLInputValue } from 'node:sqlite';
import { Pool } from 'pg';
import { attachDatabasePool } from '@vercel/functions';

export type Row = Record<string, unknown>;
export interface Database {
  initialize(autoPublish: boolean): Promise<void>;
  query(sql: string, parameters?: unknown[]): Promise<Row[]>;
  transaction<T>(work: () => Promise<T>, write?: boolean): Promise<T>;
  close(): Promise<void>;
}

const schema = (remote: boolean) => `
  CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS evidence (source_id TEXT NOT NULL, external_id TEXT NOT NULL, event_id TEXT NOT NULL REFERENCES events(id), url TEXT NOT NULL, last_seen TEXT NOT NULL, PRIMARY KEY(source_id, external_id));
  CREATE INDEX IF NOT EXISTS ${remote ? 'wagz_' : ''}evidence_event ON evidence(event_id);
  CREATE TABLE IF NOT EXISTS tips (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS tip_quotas (client_key TEXT PRIMARY KEY, attempts INTEGER NOT NULL, expires_at BIGINT NOT NULL);
  CREATE INDEX IF NOT EXISTS ${remote ? 'wagz_' : ''}tip_quotas_expiry ON tip_quotas(expires_at);
  CREATE TABLE IF NOT EXISTS runs (id TEXT PRIMARY KEY, payload TEXT NOT NULL${remote ? ', ordinal BIGSERIAL NOT NULL' : ''});
  CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS ai_charges (id TEXT PRIMARY KEY, month TEXT NOT NULL, amount ${remote ? 'DOUBLE PRECISION' : 'REAL'} NOT NULL, state TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS ai_cache (key TEXT PRIMARY KEY, payload TEXT NOT NULL);
`;
const initialSetting = 'INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO NOTHING';

class SerialQueue {
  private tail: Promise<unknown> = Promise.resolve();
  run<T>(work: () => Promise<T>): Promise<T> {
    const result = this.tail.then(work, work);
    this.tail = result.catch(() => undefined);
    return result;
  }
}

// Connections to the same local file must not block the event loop waiting for
// each other's yielded transaction. SQLite handles coordination across processes.
const localQueues = new Map<string, SerialQueue>();

export class SqliteDatabase implements Database {
  private db: DatabaseSync;
  private context = new AsyncLocalStorage<boolean>();
  private queue: SerialQueue;
  constructor(path: string) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path, { timeout: 5000 });
    this.db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;');
    const key = path === ':memory:' ? null : resolve(path);
    this.queue = (key && localQueues.get(key)) || new SerialQueue();
    if (key) localQueues.set(key, this.queue);
  }
  async initialize(autoPublish: boolean) {
    await this.transaction(async () => {
      this.db.exec(schema(false));
      await this.query(initialSetting, ['autoPublish', JSON.stringify(autoPublish)]);
    });
  }
  async query(sql: string, parameters: unknown[] = []): Promise<Row[]> {
    if (!this.context.getStore()) return this.transaction(() => this.query(sql, parameters));
    const statement = this.db.prepare(sql);
    if (/^\s*(SELECT|WITH)\b/i.test(sql)) return statement.all(...(parameters as SQLInputValue[]));
    statement.run(...(parameters as SQLInputValue[]));
    return [];
  }
  async transaction<T>(work: () => Promise<T>, write = true): Promise<T> {
    if (this.context.getStore()) return work();
    return this.queue.run(() =>
      this.context.run(true, async () => {
        this.db.exec(write ? 'BEGIN IMMEDIATE' : 'BEGIN');
        try {
          const result = await work();
          this.db.exec('COMMIT');
          return result;
        } catch (error) {
          this.db.exec('ROLLBACK');
          throw error;
        }
      }),
    );
  }
  async close() {
    await this.queue.run(async () => this.db.close());
  }
}

export interface PostgresConnection {
  query(sql: string, parameters?: unknown[]): Promise<{ rows: Row[] }>;
  release(error?: Error): void;
}
export interface PostgresPool {
  connect(): Promise<PostgresConnection>;
  end(): Promise<void>;
}

// Keep all domain queries shared. Only fixed, application-owned identifiers and
// positional placeholders are translated; user values always remain parameters.
export function postgresSql(sql: string) {
  let parameter = 0;
  return sql
    .replace(
      /\b(events|evidence|tips|tip_quotas|runs|settings|ai_charges|ai_cache)\b/g,
      'public.wagz_$1',
    )
    .replace(/\browid\b/g, 'ordinal')
    .replace(/\?/g, () => `$${++parameter}`);
}

export function postgresConnectionString(connectionString: string) {
  const url = new URL(connectionString);
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  // node-postgres is adopting libpq's weaker meaning of "require". Hosted
  // connections explicitly verify both the certificate and the server hostname.
  if (!local && url.searchParams.get('sslmode') === 'require')
    url.searchParams.set('sslmode', 'verify-full');
  return url.href;
}

export class PostgresDatabase implements Database {
  private context = new AsyncLocalStorage<PostgresConnection>();
  constructor(private pool: PostgresPool) {}
  static connect(connectionString: string) {
    const pool = new Pool({
      connectionString: postgresConnectionString(connectionString),
      max: 3,
      idleTimeoutMillis: 20_000,
      connectionTimeoutMillis: 15_000,
    });
    pool.on('error', () =>
      console.error('An idle database connection closed; the pool will reconnect.'),
    );
    if (process.env.VERCEL === '1') attachDatabasePool(pool);
    return new PostgresDatabase(pool);
  }
  async initialize(autoPublish: boolean) {
    await this.transaction(async () => {
      await this.query(schema(true));
      await this.query(initialSetting, ['autoPublish', JSON.stringify(autoPublish)]);
    });
  }
  async query(sql: string, parameters: unknown[] = []): Promise<Row[]> {
    const connection = this.context.getStore();
    if (!connection) return this.transaction(() => this.query(sql, parameters));
    return (await connection.query(postgresSql(sql), parameters)).rows;
  }
  async transaction<T>(work: () => Promise<T>, write = true): Promise<T> {
    if (this.context.getStore()) return work();
    const connection = await this.pool.connect();
    let releaseError: Error | undefined;
    try {
      await connection.query(write ? 'BEGIN' : 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
      // All WagZ writes participate in one advisory lock, including settings,
      // operator edits, identity matching and monthly AI budget reservations.
      if (write) await connection.query('SELECT pg_advisory_xact_lock($1,$2)', [0x5741475a, 1]);
      const result = await this.context.run(connection, work);
      await connection.query('COMMIT');
      return result;
    } catch (error) {
      try {
        await connection.query('ROLLBACK');
      } catch (rollbackError) {
        // Preserve the original database failure if the connection also broke.
        releaseError =
          rollbackError instanceof Error ? rollbackError : new Error('Rollback failed');
      }
      throw error;
    } finally {
      connection.release(releaseError);
    }
  }
  async close() {
    await this.pool.end();
  }
}
