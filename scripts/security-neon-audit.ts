import assert from 'node:assert/strict';
import { randomBytes, randomInt } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { Pool } from 'pg';
import {
  PostgresDatabase,
  postgresConnectionString,
  type PostgresPool,
} from '../server/database.ts';
import { Repository } from '../server/repository.ts';

// Explicit operator-only audit: no public-table or production-quota mutation.
if (process.argv.length !== 3 || process.argv[2] !== '--isolated-schema') {
  console.error('Usage: security-neon-audit.ts --isolated-schema');
  process.exit(1);
}
const schema = `wagz_audit_${randomBytes(16).toString('hex')}`;
assert.match(schema, /^wagz_audit_[a-f0-9]{32}$/);
const qualified = `"${schema}"`;
const advisoryId = randomInt(2, 2_147_483_647);
const url = process.env.DATABASE_URL;
if (!url) throw new Error('DATABASE_URL must be supplied privately by the operator.');
const connect = () =>
  new Pool({
    connectionString: postgresConnectionString(url),
    max: 3,
    connectionTimeoutMillis: 15_000,
    idleTimeoutMillis: 5_000,
  });
const owner = connect();
const pools: Pool[] = [];
const repositories: Repository[] = [];
let created = false,
  stage = 'create',
  cleanup = false;
const report: Record<string, unknown> = { at: new Date().toISOString(), schema, isolated: true };

function isolatedPool(): PostgresPool {
  const pool = connect();
  pools.push(pool);
  pool.on('error', () => {});
  return {
    async connect() {
      const client = await pool.connect();
      return {
        async query(sql: string, parameters?: unknown[]) {
          if (sql === 'SELECT pg_advisory_xact_lock($1,$2)')
            return client.query(sql, [0x5741475a, advisoryId]);
          const mapped = sql.replace(
            /\bpublic\.wagz_(events|evidence|tips|tip_quotas|request_quotas|runs|settings|ai_charges|ai_cache)\b/g,
            `${qualified}.wagz_$1`,
          );
          assert.ok(!/\bpublic\./i.test(mapped), 'Audit must not issue SQL against public.');
          return client.query(mapped, parameters);
        },
        release(error?: Error) {
          client.release(error);
        },
      };
    },
    // Cleanup closes each physical pool once, including after failed initialization.
    async end() {},
  };
}
function repository(migrations: boolean) {
  const repo = new Repository(
    ':memory:',
    [],
    true,
    new PostgresDatabase(isolatedPool(), migrations),
  );
  repositories.push(repo);
  return repo;
}
try {
  await owner.query(`CREATE SCHEMA ${qualified}`);
  created = true;
  const first = repository(true),
    second = repository(true);
  await Promise.all([first.ready, second.ready]);
  const now = Date.now();
  stage = 'tip concurrency';
  const tips = await Promise.all(
    Array.from({ length: 20 }, (_, index) =>
      (index % 2 ? first : second).consumeTipQuota(`synthetic-client-${index}`, now, 7),
    ),
  );
  assert.equal(tips.filter(Boolean).length, 7);
  report.tips = { attempts: tips.length, admitted: 7, dailyLimit: 7 };
  stage = 'authentication concurrency';
  const auth = await Promise.all(
    Array.from({ length: 45 }, (_, index) =>
      (index % 2 ? first : second).consumeAdminAuthQuota('synthetic-auth-client', now),
    ),
  );
  assert.equal(auth.filter(Boolean).length, 30);
  report.auth = { attempts: auth.length, admitted: 30, clientLimit: 30 };
  stage = 'collection concurrency';
  const collection = await Promise.all(
    Array.from({ length: 15 }, (_, index) =>
      (index % 2 ? first : second).consumeCollectionQuota(now),
    ),
  );
  assert.equal(collection.filter(Boolean).length, 6);
  report.collection = { attempts: collection.length, admitted: 6, globalLimit: 6 };
  stage = 'AI reservation concurrency';
  const reservations = await Promise.all(
    Array.from({ length: 12 }, (_, index) => (index % 2 ? first : second).reserveAi(0.25, 1)),
  );
  assert.equal(reservations.filter(Boolean).length, 4);
  assert.equal(await first.aiSpent(), 1);
  report.ai = {
    attempts: reservations.length,
    reserved: 4,
    reservedUsd: 1,
    ceilingUsd: 1,
    providerCalls: 0,
  };
  stage = 'reopen';
  await Promise.all([first.close(), second.close()]);
  // Independent new pool verifies migration-disabled initialization on the audit schema.
  const reopened = repository(false);
  await reopened.ready;
  assert.equal(await reopened.consumeTipQuota('fresh-client', now, 7), false);
  assert.equal(await reopened.consumeAdminAuthQuota('synthetic-auth-client', now), false);
  assert.equal(await reopened.consumeCollectionQuota(now), false);
  assert.equal(await reopened.reserveAi(0.25, 1), null);
  assert.equal(await reopened.aiSpent(), 1);
  report.reopened = {
    allLimitsPersisted: true,
    readOnlyInitialization: true,
    separateRestrictedRole: false,
  };
  stage = 'table verification';
  const counts: Record<string, number> = {};
  for (const table of [
    'events',
    'evidence',
    'tips',
    'tip_quotas',
    'request_quotas',
    'runs',
    'settings',
    'ai_charges',
    'ai_cache',
  ]) {
    const { rows } = await owner.query(
      `SELECT count(*)::text AS count FROM ${qualified}.wagz_${table}`,
    );
    counts[table] = Number(rows[0].count);
  }
  assert.deepEqual(counts, {
    events: 0,
    evidence: 0,
    tips: 0,
    tip_quotas: 7,
    request_quotas: 4,
    runs: 0,
    settings: 1,
    ai_charges: 4,
    ai_cache: 0,
  });
  report.counts = counts;
  report.passed = true;
} catch {
  report.passed = false;
  report.failedStage = stage;
  process.exitCode = 1;
} finally {
  await Promise.allSettled(repositories.map((repo) => repo.close()));
  await Promise.allSettled(pools.map((pool) => pool.end()));
  if (created) {
    try {
      await owner.query(`DROP SCHEMA ${qualified} CASCADE`);
      const { rows } = await owner.query(
        'SELECT count(*)::text AS count FROM pg_namespace WHERE nspname=$1',
        [schema],
      );
      cleanup = rows[0].count === '0';
    } catch {
      cleanup = false;
    }
  }
  await owner.end();
  report.cleaned = cleanup;
  if (!cleanup) {
    report.passed = false;
    process.exitCode = 1;
  }
  await mkdir(resolve('.artifacts'), { recursive: true });
  await writeFile(
    resolve('.artifacts/security-neon-audit-report.json'),
    JSON.stringify(report, null, 2),
  );
  console.log(JSON.stringify(report));
}
