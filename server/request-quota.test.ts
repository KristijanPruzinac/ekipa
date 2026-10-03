import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import type { AddressInfo } from 'node:net';
import { createApp } from './app.ts';
import { PostgresDatabase, SqliteDatabase, type Row } from './database.ts';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';
import type { Config } from './config.ts';

const now = Date.parse('2026-10-03T10:00:00Z');
const config: Config = {
  host: '127.0.0.1',
  port: 0,
  databasePath: ':memory:',
  adminKey: 'quota-test-only',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 1440,
  ai: { apiKey: '', model: 'unused', monthlyBudgetUsd: 0, searchEnabled: false },
};

async function sharedFixture() {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-request-quota-'));
  const path = join(directory, 'quota.sqlite');
  const databases = [new SqliteDatabase(path), new SqliteDatabase(path)];
  const repos = databases.map((database) => new Repository(path, [], true, database));
  return {
    path,
    databases,
    repos,
    async close() {
      await Promise.all(repos.map((repo) => repo.close()));
      const resolved = await realpath(directory);
      assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
      assert.ok(basename(resolved).startsWith('wagz-request-quota-'));
      await rm(resolved, { recursive: true, force: true });
    },
  };
}

test('failed-auth and collection limits serialize across repositories and survive reopen until expiry', async () => {
  const f = await sharedFixture();
  try {
    const failures = await Promise.all(
      Array.from({ length: 45 }, (_, i) =>
        f.repos[i % 2].consumeAdminAuthQuota('198.51.100.42', now),
      ),
    );
    assert.equal(failures.filter(Boolean).length, 30);
    const collections = await Promise.all(
      Array.from({ length: 15 }, (_, i) => f.repos[i % 2].consumeCollectionQuota(now)),
    );
    assert.equal(collections.filter(Boolean).length, 6);
    const rows = await f.databases[0].query(
      'SELECT quota_key,attempts,expires_at FROM request_quotas',
    );
    assert.equal(rows.length, 3);
    assert.ok(!JSON.stringify(rows).includes('198.51.100.42'));
    assert.ok(rows.some((row) => /^admin-auth:[a-f0-9]{64}$/.test(String(row.quota_key))));
    await Promise.all(f.repos.map((repo) => repo.close()));
    const reopened = new Repository(f.path, []);
    try {
      assert.equal(await reopened.consumeAdminAuthQuota('198.51.100.42', now + 899_999), false);
      assert.equal(await reopened.consumeAdminAuthQuota('198.51.100.42', now + 900_000), true);
      assert.equal(await reopened.consumeCollectionQuota(now + 3_599_999), false);
      assert.equal(await reopened.consumeCollectionQuota(now + 3_600_000), true);
    } finally {
      await reopened.close();
    }
  } finally {
    await f.close();
  }
});

test('global failed-auth ceiling bounds rotating-client records without growing counters after denial', async () => {
  const database = new SqliteDatabase(':memory:');
  const repo = new Repository(':memory:', [], true, database);
  try {
    const results = await Promise.all(
      Array.from({ length: 340 }, (_, i) =>
        repo.consumeAdminAuthQuota(`rotating-client-${i}`, now),
      ),
    );
    assert.equal(results.filter(Boolean).length, 300);
    const rows = await database.query('SELECT quota_key,attempts FROM request_quotas');
    assert.equal(rows.length, 301);
    assert.equal(rows.find((row) => row.quota_key === 'admin-auth:global')?.attempts, 300);
    assert.equal(await repo.consumeAdminAuthQuota('brand-new-client', now), false);
    assert.equal((await database.query('SELECT quota_key FROM request_quotas')).length, 301);
  } finally {
    await repo.close();
  }
});

test('two API instances share authentication and global collection limits; valid keys bypass failed-auth limits', async (context) => {
  const f = await sharedFixture();
  const services = f.repos.map((repo) => new WagzService(repo, { ...config, hosted: true }));
  const collect = services.map((service) =>
    context.mock.method(service, 'collect', async () => {}),
  );
  const servers = services.map((service) => createApp(service).listen(0, '127.0.0.1'));
  const headers = { authorization: `Bearer ${config.adminKey}` };
  try {
    await Promise.all(
      servers.map((server) => new Promise<void>((resolve) => server.once('listening', resolve))),
    );
    const bases = servers.map(
      (server) => `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
    );
    const failed = await Promise.all(
      Array.from({ length: 40 }, (_, i) =>
        fetch(`${bases[i % 2]}/api/admin/dashboard`, {
          headers: { authorization: 'Bearer wrong', 'x-forwarded-for': '198.51.100.42' },
        }),
      ),
    );
    assert.equal(failed.filter((response) => response.status === 401).length, 30);
    assert.equal(failed.filter((response) => response.status === 429).length, 10);
    await Promise.all(failed.map((response) => response.text()));
    // Fill the global failed-auth window too. Correct credentials must remain usable.
    await Promise.all(
      Array.from({ length: 300 }, (_, i) => f.repos[i % 2].consumeAdminAuthQuota(`rotating-${i}`)),
    );
    for (const base of bases) {
      const response = await fetch(`${base}/api/admin/dashboard`, {
        headers: { ...headers, 'x-forwarded-for': '198.51.100.42' },
      });
      assert.equal(response.status, 200);
      await response.text();
    }
    const responses = await Promise.all(
      Array.from({ length: 12 }, (_, i) =>
        fetch(`${bases[i % 2]}/api/admin/collect`, {
          method: 'POST',
          headers: { ...headers, 'x-forwarded-for': `198.51.100.${i + 1}` },
        }),
      ),
    );
    assert.equal(responses.filter((response) => response.status === 202).length, 6);
    assert.equal(responses.filter((response) => response.status === 429).length, 6);
    assert.equal(
      collect.reduce((sum, mock) => sum + mock.mock.callCount(), 0),
      6,
    );
    await Promise.all(responses.map((response) => response.text()));
  } finally {
    await Promise.all(
      servers.map((server) => new Promise<void>((resolve) => server.close(() => resolve()))),
    );
    await f.close();
  }
});

test('quota database failure denies submission, bad credentials and collection before expensive handlers', async (context) => {
  const database = new SqliteDatabase(':memory:');
  const repo = new Repository(':memory:', [], true, database);
  const service = new WagzService(repo, config);
  await repo.ready;
  const query = database.query.bind(database);
  context.mock.method(database, 'query', async (sql: string, parameters?: unknown[]) => {
    if (/\b(?:request_quotas|tip_quotas)\b/.test(sql))
      throw new Error('Synthetic private DB failure');
    return query(sql, parameters);
  });
  context.mock.method(console, 'error', () => {});
  const submits = context.mock.method(service, 'submitTip', async () => {
    throw new Error('Must not submit');
  });
  const collect = context.mock.method(service, 'collect', async () => {
    throw new Error('Must not collect');
  });
  const server = createApp(service).listen(0, '127.0.0.1');
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    for (const [path, method, authorization] of [
      ['/api/tips', 'POST', ''],
      ['/api/admin/dashboard', 'GET', 'Bearer wrong'],
      ['/api/admin/collect', 'POST', `Bearer ${config.adminKey}`],
    ]) {
      const response = await fetch(base + path, { method, headers: { authorization } });
      assert.equal(response.status, 500);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      assert.ok(!(await response.text()).includes('private DB failure'));
    }
    assert.equal(submits.mock.callCount(), 0);
    assert.equal(collect.mock.callCount(), 0);
    const valid = await fetch(base + '/api/admin/dashboard', {
      headers: { authorization: `Bearer ${config.adminKey}` },
    });
    assert.equal(valid.status, 200, 'a quota failure cannot lock out a valid administrator');
    await valid.text();
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await repo.close();
  }
});

test('HTTP public submissions honor the configured daily ceiling across instances and rotating addresses', async () => {
  const f = await sharedFixture();
  const services = f.repos.map(
    (repo) =>
      new WagzService(repo, {
        ...config,
        hosted: true,
        tipDailyLimit: 7,
      }),
  );
  const servers = services.map((service) => createApp(service).listen(0, '127.0.0.1'));
  try {
    await Promise.all(
      servers.map((server) => new Promise<void>((resolve) => server.once('listening', resolve))),
    );
    const bases = servers.map(
      (server) => `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
    );
    const responses = await Promise.all(
      Array.from({ length: 16 }, (_, i) =>
        fetch(`${bases[i % 2]}/api/tips`, {
          method: 'POST',
          headers: { 'content-type': 'application/json', 'x-forwarded-for': `198.51.100.${i + 1}` },
          body: JSON.stringify({ note: `Radionica u Osijeku broj ${i}` }),
        }),
      ),
    );
    assert.equal(responses.filter((response) => response.status === 201).length, 7);
    assert.equal(responses.filter((response) => response.status === 429).length, 9);
    await Promise.all(responses.map((response) => response.text()));
    assert.equal((await f.repos[0].tips()).length, 7);
    assert.equal(await f.repos[0].aiSpent(), 0);
    assert.equal((await f.databases[0].query('SELECT client_key FROM tip_quotas')).length, 7);
  } finally {
    await Promise.all(
      servers.map((server) => new Promise<void>((resolve) => server.close(() => resolve()))),
    );
    await f.close();
  }
});

test('Postgres quota writes share one locked transaction, bind hashed values and rollback on storage failure', async () => {
  const sessions: Array<Array<{ sql: string; parameters?: unknown[] }>> = [];
  let failWrites = false;
  let releases = 0;
  const database = new PostgresDatabase({
    async connect() {
      const session: Array<{ sql: string; parameters?: unknown[] }> = [];
      sessions.push(session);
      return {
        async query(sql: string, parameters?: unknown[]) {
          session.push({ sql, parameters });
          if (failWrites && /^INSERT INTO public\.wagz_request_quotas/.test(sql))
            throw new Error('quota unavailable');
          return { rows: [] as Row[] };
        },
        release() {
          releases++;
        },
      };
    },
    async end() {},
  });
  const repo = new Repository(':memory:', [], true, database);
  try {
    await repo.ready;
    assert.equal(await repo.consumeAdminAuthQuota('198.51.100.42', now), true);
    const success = sessions.at(-1)!;
    assert.equal(success[0].sql, 'BEGIN');
    assert.match(success[1].sql, /pg_advisory_xact_lock/);
    assert.equal(success.at(-1)?.sql, 'COMMIT');
    assert.equal(
      success.filter((query) => /^INSERT INTO public\.wagz_request_quotas/.test(query.sql)).length,
      2,
    );
    assert.ok(!JSON.stringify(success).includes('198.51.100.42'));
    assert.ok(success.some((query) => /WHERE quota_key=\$1/.test(query.sql)));
    failWrites = true;
    await assert.rejects(repo.consumeCollectionQuota(now), /quota unavailable/);
    assert.equal(sessions.at(-1)?.at(-1)?.sql, 'ROLLBACK');
    assert.equal(releases, sessions.length);
  } finally {
    await repo.close();
  }
});
