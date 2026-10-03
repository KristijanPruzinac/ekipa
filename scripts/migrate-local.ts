import { DatabaseSync } from 'node:sqlite';
import { Pool } from 'pg';
import { config } from '../server/config.ts';
import { createRepository } from '../server/repository.ts';
import { sources } from '../server/ingestion/index.ts';

// One-time bootstrap only. Never overwrite an already populated hosted database.
if (!config.databaseUrl) throw new Error('Set DATABASE_URL before migrating.');
const repository = await createRepository(
  config.databasePath,
  sources,
  config.autoPublish,
  config.databaseUrl,
);
await repository.close();
const connectionUrl = new URL(config.databaseUrl);
connectionUrl.searchParams.set('sslmode', 'verify-full');
const pool = new Pool({ connectionString: connectionUrl.href, max: 1 });
const local = new DatabaseSync(config.databasePath, { readOnly: true });
const tables: Record<string, string[]> = {
  events: ['id', 'payload'],
  evidence: ['source_id', 'external_id', 'event_id', 'url', 'last_seen'],
  tips: ['id', 'payload'],
  runs: ['id', 'payload'],
  settings: ['key', 'value'],
  ai_charges: ['id', 'month', 'amount', 'state'],
  ai_cache: ['key', 'payload'],
};
const client = await pool.connect();
try {
  local.exec('BEGIN');
  await client.query('BEGIN');
  await client.query('SELECT pg_advisory_xact_lock($1,$2)', [0x5741475a, 1]);
  for (const table of Object.keys(tables).filter((name) => name !== 'settings')) {
    const result = await client.query(`SELECT COUNT(*) AS count FROM public.wagz_${table}`);
    if (Number(result.rows[0].count))
      throw new Error('Hosted database already contains data; migration refused.');
  }
  const counts: Record<string, number> = {};
  for (const [table, columns] of Object.entries(tables)) {
    const rows = local
      .prepare(
        `SELECT ${columns.join(',')} FROM ${table}${table === 'runs' ? ' ORDER BY rowid ASC' : ''}`,
      )
      .all();
    for (const row of rows) {
      // A running local collection lease does not move between hosts.
      if (table === 'settings' && String(row.key).startsWith('lease:')) continue;
      const conflict =
        table === 'settings' ? 'ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value' : '';
      await client.query(
        `INSERT INTO public.wagz_${table} (${columns.join(',')}) VALUES (${columns.map((_, i) => `$${i + 1}`).join(',')}) ${conflict}`,
        columns.map((column) => row[column]),
      );
    }
    counts[table] = rows.length;
  }
  await client.query('COMMIT');
  console.log({ migrated: true, counts, monthlyAiChargesPreserved: true });
} catch {
  await client.query('ROLLBACK');
  console.error('Migration stopped and rolled back; hosted data was not overwritten.');
  process.exitCode = 1;
} finally {
  local.exec('ROLLBACK');
  local.close();
  client.release();
  await pool.end();
}
