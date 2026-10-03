import { randomBytes } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  TABLES,
  MAX_BACKUP_BYTES,
  backupKey,
  backupPool,
  createSnapshot,
  decryptSnapshot,
  snapshotSummary,
  validateSnapshot,
  type BackupConnection,
  type Snapshot,
  type Table,
} from './backup.ts';

/** These identifiers are generated here, never read from the archive or CLI. */
function schemaName() {
  return `wagz_restore_${randomBytes(16).toString('hex')}`;
}
function quotedSchema(schema: string) {
  if (!/^wagz_restore_[a-f0-9]{32}$/.test(schema)) throw new Error('Unsafe restoration schema.');
  return `"${schema}"`;
}
function schemaSql(schema: string) {
  const target = quotedSchema(schema);
  return [
    `CREATE TABLE ${target}.wagz_events (id TEXT PRIMARY KEY, payload TEXT NOT NULL)`,
    `CREATE TABLE ${target}.wagz_evidence (source_id TEXT NOT NULL, external_id TEXT NOT NULL, event_id TEXT NOT NULL REFERENCES ${target}.wagz_events(id), url TEXT NOT NULL, last_seen TEXT NOT NULL, PRIMARY KEY(source_id,external_id))`,
    `CREATE TABLE ${target}.wagz_tips (id TEXT PRIMARY KEY, payload TEXT NOT NULL)`,
    `CREATE TABLE ${target}.wagz_tip_quotas (client_key TEXT PRIMARY KEY, attempts INTEGER NOT NULL, expires_at BIGINT NOT NULL)`,
    `CREATE TABLE ${target}.wagz_request_quotas (quota_key TEXT PRIMARY KEY, attempts INTEGER NOT NULL, expires_at BIGINT NOT NULL)`,
    `CREATE TABLE ${target}.wagz_runs (id TEXT PRIMARY KEY, payload TEXT NOT NULL, ordinal BIGSERIAL NOT NULL)`,
    `CREATE TABLE ${target}.wagz_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)`,
    `CREATE TABLE ${target}.wagz_ai_charges (id TEXT PRIMARY KEY, month TEXT NOT NULL, amount DOUBLE PRECISION NOT NULL, state TEXT NOT NULL)`,
    `CREATE TABLE ${target}.wagz_ai_cache (key TEXT PRIMARY KEY, payload TEXT NOT NULL)`,
  ];
}

/** Restore, commit and reread only a fresh private schema; drills always remove it. */
export async function restoreDrill(
  connection: BackupConnection,
  input: unknown,
  options: { retainInEmptyTarget?: boolean } = {},
) {
  // Entire archive validation precedes even CREATE SCHEMA.
  const snapshot = validateSnapshot(input);
  const maxOrdinal = snapshot.tables.runs.rows.reduce(
    (max, row) => (BigInt(row.ordinal) > max ? BigInt(row.ordinal) : max),
    0n,
  );
  if (maxOrdinal >= 9_223_372_036_854_775_807n)
    throw new Error('Restored run sequence is exhausted.');
  const schema = schemaName();
  const target = quotedSchema(schema);
  const names = Object.keys(TABLES) as Table[];
  let transaction = false,
    committedSchema = false,
    verified = false;
  try {
    await connection.query('BEGIN');
    transaction = true;
    await connection.query("SET LOCAL statement_timeout = '60s'");
    await connection.query("SET LOCAL lock_timeout = '5s'");
    if (options.retainInEmptyTarget) {
      const {
        rows: [objects],
      } = await connection.query(
        "SELECT count(*)::text AS count FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'",
      );
      if (objects?.count !== '0') throw new Error('Recovery requires an empty public schema.');
    }
    // No IF NOT EXISTS: a collision must fail rather than adopt anybody else's schema.
    await connection.query(`CREATE SCHEMA ${target}`);
    for (const sql of schemaSql(schema)) await connection.query(sql);
    for (const table of names) {
      const columns = TABLES[table];
      // Batches keep parameter and query size bounded while avoiding one round trip per row.
      const rows = snapshot.tables[table].rows;
      for (let offset = 0; offset < rows.length; offset += 100) {
        const batch = rows.slice(offset, offset + 100);
        const values = batch.flatMap((row) => columns.map((column) => row[column]));
        const placeholders = batch
          .map(
            (_, row) =>
              `(${columns.map((_, column) => `$${row * columns.length + column + 1}`).join(',')})`,
          )
          .join(',');
        await connection.query(
          `INSERT INTO ${target}.wagz_${table} (${columns.join(',')}) VALUES ${placeholders}`,
          values,
        );
      }
    }
    // No sequence in public is touched.
    await connection.query('SELECT setval(pg_get_serial_sequence($1,$2),$3,$4)', [
      `${schema}.wagz_runs`,
      'ordinal',
      String(maxOrdinal || 1n),
      maxOrdinal > 0n,
    ]);
    const {
      rows: [sequence],
    } = await connection.query('SELECT nextval(pg_get_serial_sequence($1,$2))::text AS ordinal', [
      `${schema}.wagz_runs`,
      'ordinal',
    ]);
    if (sequence?.ordinal !== String(maxOrdinal + 1n))
      throw new Error('Restored sequence verification failed.');
    await connection.query('SELECT setval(pg_get_serial_sequence($1,$2),$3,$4)', [
      `${schema}.wagz_runs`,
      'ordinal',
      String(maxOrdinal || 1n),
      maxOrdinal > 0n,
    ]);
    await connection.query('COMMIT');
    transaction = false;
    committedSchema = true;

    await connection.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    transaction = true;
    await connection.query("SET LOCAL statement_timeout = '60s'");
    const raw = {} as Record<Table, unknown>;
    for (const table of names)
      raw[table] = (
        await connection.query(`SELECT ${TABLES[table].join(',')} FROM ${target}.wagz_${table}`)
      ).rows;
    const restored = createSnapshot(raw, snapshot.createdAt);
    for (const table of names)
      if (
        restored.tables[table].rows.length !== snapshot.tables[table].rows.length ||
        restored.tables[table].sha256 !== snapshot.tables[table].sha256
      )
        throw new Error('Restored record verification failed.');
    const {
      rows: [constraints],
    } = await connection.query(
      "SELECT count(*)::text AS count FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname=$1 AND c.contype='f' AND c.convalidated",
      [schema],
    );
    if (constraints?.count !== '1') throw new Error('Restored foreign key verification failed.');
    await connection.query('COMMIT');
    transaction = false;
    verified = true;
    return {
      restored: true,
      schema,
      sequenceVerified: true,
      foreignKeysVerified: true,
      ...snapshotSummary(snapshot),
    };
  } finally {
    if (transaction) await connection.query('ROLLBACK');
    // Only a schema this invocation successfully created and committed is removable.
    // On pre-commit failure ROLLBACK already removes the entire new schema.
    if (committedSchema && !(options.retainInEmptyTarget && verified))
      await connection.query(`DROP SCHEMA ${target} CASCADE`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 2 || args[0] !== '--input')
    throw new Error('Usage: backup-drill.ts --input path.wagz');
  const path = resolve(args[1]);
  if ((await stat(path)).size > MAX_BACKUP_BYTES * 1.4 + 1024)
    throw new Error('Encrypted backup too large.');
  const key = backupKey(process.env.WAGZ_BACKUP_KEY);
  let snapshot: Snapshot;
  try {
    snapshot = decryptSnapshot(await readFile(path), key);
  } finally {
    key.fill(0);
  }
  // Authentication/validation finishes before opening the target database connection.
  const pool = backupPool(process.env.DATABASE_URL);
  try {
    const client = await pool.connect();
    try {
      console.log(JSON.stringify({ ...(await restoreDrill(client, snapshot)), cleaned: true }));
    } finally {
      client.release();
    }
  } finally {
    await pool.end();
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  void main().catch(() => {
    console.error(
      'Restore drill failed. Public application tables were not modified. Check the isolated restore schema for cleanup if its database connection was lost.',
    );
    process.exitCode = 1;
  });
