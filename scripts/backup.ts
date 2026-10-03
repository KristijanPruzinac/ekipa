import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Pool } from 'pg';
import { postgresConnectionString } from '../server/database.ts';

export const MAX_BACKUP_BYTES = 32 * 1024 * 1024;
export const MAX_BACKUP_ROWS = 100_000;
export const TABLES = {
  events: ['id', 'payload'],
  evidence: ['source_id', 'external_id', 'event_id', 'url', 'last_seen'],
  tips: ['id', 'payload'],
  tip_quotas: ['client_key', 'attempts', 'expires_at'],
  request_quotas: ['quota_key', 'attempts', 'expires_at'],
  runs: ['id', 'payload', 'ordinal'],
  settings: ['key', 'value'],
  ai_charges: ['id', 'month', 'amount', 'state'],
  ai_cache: ['key', 'payload'],
} as const;
export type Table = keyof typeof TABLES;
export type BackupRow = Record<string, string | number>;
export interface BackupConnection {
  query(sql: string, parameters?: unknown[]): Promise<{ rows: Record<string, unknown>[] }>;
}
export interface Snapshot {
  format: 'wagz-snapshot-v1';
  createdAt: string;
  tables: Record<Table, { rows: BackupRow[]; sha256: string }>;
}
const names = Object.keys(TABLES) as Table[];
const aad = Buffer.from('wagz-encrypted-backup-v1:aes-256-gcm');
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');
function object(value: unknown): asserts value is Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new Error('Invalid backup object.');
}
function exactKeys(value: Record<string, unknown>, keys: readonly string[]) {
  if (Object.keys(value).length !== keys.length || keys.some((key) => !Object.hasOwn(value, key)))
    throw new Error('Invalid backup fields.');
}
function primaryKey(table: Table, row: BackupRow) {
  return table === 'evidence'
    ? JSON.stringify([row.source_id, row.external_id])
    : String(row[TABLES[table][0]]);
}
function normalizeRows(table: Table, input: unknown): BackupRow[] {
  if (!Array.isArray(input) || input.length > MAX_BACKUP_ROWS)
    throw new Error('Invalid backup rows.');
  const keys = new Set<string>();
  const rows = input.map((item): BackupRow => {
    object(item);
    exactKeys(item, TABLES[table]);
    const row: BackupRow = {};
    for (const column of TABLES[table]) {
      const value = item[column];
      if (column === 'attempts' || column === 'amount') {
        if (
          typeof value !== 'number' ||
          !Number.isFinite(value) ||
          value < 0 ||
          (column === 'attempts' && (!Number.isInteger(value) || value > 2_147_483_647))
        )
          throw new Error('Invalid backup numeric value.');
        row[column] = value;
      } else if (column === 'expires_at' || column === 'ordinal') {
        if (
          (typeof value !== 'string' && typeof value !== 'number') ||
          (typeof value === 'number' && !Number.isSafeInteger(value)) ||
          !/^(0|[1-9]\d*)$/.test(String(value))
        )
          throw new Error('Invalid backup integer.');
        const integer = BigInt(value);
        if (integer > 9_223_372_036_854_775_807n || (column === 'ordinal' && integer < 1n))
          throw new Error('Invalid backup integer range.');
        row[column] = String(integer);
      } else {
        if (
          typeof value !== 'string' ||
          value.includes('\0') ||
          Buffer.byteLength(value) > 2 * 1024 * 1024
        )
          throw new Error('Invalid backup text.');
        if (column === 'payload' || column === 'value') JSON.parse(value);
        row[column] = value;
      }
    }
    const key = primaryKey(table, row);
    if (keys.has(key)) throw new Error('Duplicate backup primary key.');
    keys.add(key);
    return row;
  });
  return rows.sort((left, right) => {
    const a = primaryKey(table, left),
      b = primaryKey(table, right);
    return a < b ? -1 : a > b ? 1 : 0;
  });
}
export function createSnapshot(
  raw: Record<Table, unknown>,
  createdAt = new Date().toISOString(),
): Snapshot {
  const tables = Object.fromEntries(
    names.map((name) => {
      const rows = normalizeRows(name, raw[name]);
      return [name, { rows, sha256: sha256(JSON.stringify(rows)) }];
    }),
  ) as Snapshot['tables'];
  return validateSnapshot({ format: 'wagz-snapshot-v1', createdAt, tables });
}
export function validateSnapshot(input: unknown): Snapshot {
  object(input);
  exactKeys(input, ['format', 'createdAt', 'tables']);
  if (
    input.format !== 'wagz-snapshot-v1' ||
    typeof input.createdAt !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(input.createdAt) ||
    !Number.isFinite(Date.parse(input.createdAt))
  )
    throw new Error('Invalid backup format.');
  object(input.tables);
  exactKeys(input.tables, names);
  let count = 0;
  const tables = {} as Snapshot['tables'];
  for (const name of names) {
    const entry = input.tables[name];
    object(entry);
    exactKeys(entry, ['rows', 'sha256']);
    const rows = normalizeRows(name, entry.rows);
    count += rows.length;
    const digest = sha256(JSON.stringify(rows));
    if (entry.sha256 !== digest) throw new Error('Backup table integrity failed.');
    tables[name] = { rows, sha256: digest };
  }
  if (count > MAX_BACKUP_ROWS || Buffer.byteLength(JSON.stringify(input)) > MAX_BACKUP_BYTES)
    throw new Error('Backup exceeds the configured bounds.');
  const eventIds = new Set(tables.events.rows.map((row) => row.id));
  if (tables.evidence.rows.some((row) => !eventIds.has(row.event_id)))
    throw new Error('Backup evidence refers to an absent event.');
  const autoPublish = tables.settings.rows.find((row) => row.key === 'autoPublish');
  if (!autoPublish || !['true', 'false'].includes(String(autoPublish.value)))
    throw new Error('Backup lacks its initialized publication setting.');
  return { format: 'wagz-snapshot-v1', createdAt: input.createdAt, tables };
}
export function backupKey(value: string | undefined): Buffer {
  if (!value || !/^[A-Za-z0-9+/]{43}=$/.test(value))
    throw new Error('A 32-byte base64 backup key is required.');
  const key = Buffer.from(value, 'base64');
  if (key.length !== 32 || key.toString('base64') !== value) throw new Error('Invalid backup key.');
  return key;
}
export function encryptSnapshot(snapshot: Snapshot, key: Buffer): Buffer {
  if (key.length !== 32) throw new Error('Invalid backup key.');
  const plaintext = Buffer.from(JSON.stringify(validateSnapshot(snapshot)));
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  cipher.setAAD(aad);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  plaintext.fill(0);
  return Buffer.from(
    JSON.stringify({
      format: 'wagz-encrypted-backup-v1',
      cipher: 'aes-256-gcm',
      iv: iv.toString('base64'),
      tag: cipher.getAuthTag().toString('base64'),
      ciphertext: ciphertext.toString('base64'),
    }),
  );
}
export function decryptSnapshot(encrypted: Buffer, key: Buffer): Snapshot {
  if (key.length !== 32 || encrypted.length > MAX_BACKUP_BYTES * 1.4 + 1024)
    throw new Error('Invalid encrypted backup.');
  const envelope: unknown = JSON.parse(encrypted.toString('utf8'));
  object(envelope);
  exactKeys(envelope, ['format', 'cipher', 'iv', 'tag', 'ciphertext']);
  if (envelope.format !== 'wagz-encrypted-backup-v1' || envelope.cipher !== 'aes-256-gcm')
    throw new Error('Unsupported encrypted backup.');
  const decode = (value: unknown) => {
    if (typeof value !== 'string') throw new Error('Invalid encrypted backup field.');
    const decoded = Buffer.from(value, 'base64');
    if (decoded.toString('base64') !== value) throw new Error('Invalid backup encoding.');
    return decoded;
  };
  const iv = decode(envelope.iv),
    tag = decode(envelope.tag),
    ciphertext = decode(envelope.ciphertext);
  if (iv.length !== 12 || tag.length !== 16 || ciphertext.length > MAX_BACKUP_BYTES)
    throw new Error('Invalid encrypted backup bounds.');
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAAD(aad);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  try {
    return validateSnapshot(JSON.parse(plaintext.toString('utf8')));
  } finally {
    plaintext.fill(0);
  }
}

/** Read one consistent snapshot. No DDL, leases, reservations or application mutations. */
export async function captureSnapshot(connection: BackupConnection): Promise<Snapshot> {
  await connection.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  try {
    await connection.query("SET LOCAL statement_timeout = '60s'");
    await connection.query("SET LOCAL lock_timeout = '5s'");
    const raw = {} as Record<Table, unknown>;
    let totalRows = 0,
      totalBytes = 0;
    for (const table of names) {
      const {
        rows: [size],
      } = await connection.query(
        `SELECT count(*)::text AS count, COALESCE(sum(octet_length(row_to_json(t)::text)),0)::text AS bytes FROM public.wagz_${table} t`,
      );
      const count = Number(size?.count),
        bytes = Number(size?.bytes);
      if (!Number.isSafeInteger(count) || count < 0 || !Number.isSafeInteger(bytes) || bytes < 0)
        throw new Error('Could not verify backup bounds.');
      totalRows += count;
      totalBytes += bytes;
      if (totalRows > MAX_BACKUP_ROWS || totalBytes > MAX_BACKUP_BYTES)
        throw new Error('Backup exceeds the configured bounds.');
      const { rows } = await connection.query(
        `SELECT ${TABLES[table].join(',')} FROM public.wagz_${table}`,
      );
      if (rows.length !== count) throw new Error('Backup row count changed inside snapshot.');
      raw[table] = rows;
    }
    const snapshot = createSnapshot(raw);
    await connection.query('COMMIT');
    return snapshot;
  } catch (error) {
    await connection.query('ROLLBACK');
    throw error;
  }
}
export function snapshotSummary(snapshot: Snapshot) {
  return {
    createdAt: snapshot.createdAt,
    tables: Object.fromEntries(
      names.map((table) => [
        table,
        {
          rows: snapshot.tables[table].rows.length,
          sha256: snapshot.tables[table].sha256,
        },
      ]),
    ),
  };
}
export function backupPool(databaseUrl: string | undefined) {
  if (!databaseUrl) throw new Error('DATABASE_URL is required.');
  const pool = new Pool({
    connectionString: postgresConnectionString(databaseUrl),
    max: 1,
    connectionTimeoutMillis: 15_000,
    idleTimeoutMillis: 5_000,
  });
  pool.on('error', () => {});
  return pool;
}
async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 2 || args[0] !== '--output')
    throw new Error('Usage: backup.ts --output path.wagz');
  const key = backupKey(process.env.WAGZ_BACKUP_KEY);
  const pool = backupPool(process.env.DATABASE_URL);
  try {
    const client = await pool.connect();
    try {
      const snapshot = await captureSnapshot(client);
      const encrypted = encryptSnapshot(snapshot, key);
      const path = resolve(args[1]);
      await mkdir(dirname(path), { recursive: true });
      await writeFile(path, encrypted, { flag: 'wx', mode: 0o600 });
      console.log(
        JSON.stringify({
          backup: 'encrypted',
          bytes: encrypted.length,
          ...snapshotSummary(snapshot),
        }),
      );
    } finally {
      client.release();
    }
  } finally {
    key.fill(0);
    await pool.end();
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  void main().catch(() => {
    console.error(
      'Encrypted backup failed. No plaintext output was written; check configuration, schema and storage bounds.',
    );
    process.exitCode = 1;
  });
