import test from 'node:test';
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { createApp } from './app.ts';
import { SqliteDatabase, postgresSql } from './database.ts';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';
import type { Config } from './config.ts';

async function removeTemporary(directory: string) {
  const resolved = await realpath(directory);
  assert.equal(dirname(resolved).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
  assert.ok(basename(resolved).startsWith('wagz-tip-quota-'));
  await rm(resolved, { recursive: true, force: true });
}

test('submission quota is atomic across repositories, persists on reopen, and expires without storing raw addresses', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-tip-quota-'));
  const path = join(directory, 'quota.sqlite');
  const first = new Repository(path, []);
  const second = new Repository(path, []);
  const client = '198.51.100.42';
  const now = Date.parse('2026-10-03T10:00:00Z');
  try {
    const results = await Promise.all(
      Array.from({ length: 12 }, (_, index) =>
        (index % 2 ? first : second).consumeTipQuota(client, now),
      ),
    );
    assert.equal(results.filter(Boolean).length, 5);
    assert.equal(await first.consumeTipQuota('198.51.100.43', now), true);
    await first.close();
    await second.close();

    const database = new SqliteDatabase(path);
    const reopened = new Repository(path, [], true, database);
    try {
      assert.equal(await reopened.consumeTipQuota(client, now + 3_599_999), false);
      const rows = await database.query('SELECT client_key,attempts,expires_at FROM tip_quotas');
      assert.equal(rows.length, 2);
      assert.ok(rows.every((row) => /^[a-f0-9]{64}$/.test(String(row.client_key))));
      assert.ok(rows.every((row) => !JSON.stringify(row).includes('198.51.100.')));
      assert.ok(rows.every((row) => Number(row.attempts) <= 5));
      assert.equal(await reopened.consumeTipQuota(client, now + 3_600_000), true);
      const reset = await database.query('SELECT attempts,expires_at FROM tip_quotas');
      assert.deepEqual(
        reset.map((row) => ({ ...row })),
        [{ attempts: 1, expires_at: now + 7_200_000 }],
      );
    } finally {
      await reopened.close();
    }
  } finally {
    await first.close();
    await second.close();
    await removeTemporary(directory);
  }
});

test('quota cleanup deletes at most 128 expired clients per request and keeps active clients', async () => {
  const database = new SqliteDatabase(':memory:');
  const repo = new Repository(':memory:', [], true, database);
  try {
    await repo.ready;
    await database.transaction(async () => {
      for (let index = 0; index < 130; index++)
        await database.query(
          'INSERT INTO tip_quotas(client_key,attempts,expires_at) VALUES (?,?,?)',
          [index.toString(16).padStart(64, '0'), 5, 1000],
        );
    });
    assert.equal(await repo.consumeTipQuota('203.0.113.10', 2000), true);
    assert.equal((await database.query('SELECT client_key FROM tip_quotas')).length, 3);
    assert.equal(await repo.consumeTipQuota('203.0.113.10', 2000), true);
    assert.deepEqual(
      (await database.query('SELECT attempts FROM tip_quotas')).map((row) => ({ ...row })),
      [{ attempts: 2 }],
    );
  } finally {
    await repo.close();
  }
});

test('separate public API instances share five submissions per hour and reject excess work before preparation', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-tip-quota-'));
  const path = join(directory, 'quota.sqlite');
  const config: Config = {
    host: '127.0.0.1',
    port: 3000,
    databasePath: path,
    adminKey: 'test-only',
    autoPublish: true,
    fetchOnStart: false,
    fetchIntervalMinutes: 1440,
    ai: { apiKey: '', model: 'unused', monthlyBudgetUsd: 0, searchEnabled: false },
  };
  const repositories = [new Repository(path, []), new Repository(path, [])];
  const services = repositories.map((repo) => new WagzService(repo, config));
  const prepares = services.map((service) =>
    context.mock.method(service, 'prepareTip', async () => {
      throw new Error('A public submission must not prepare a tip.');
    }),
  );
  const backgrounds: Promise<unknown>[] = [];
  const servers = services.map((service) =>
    createApp(service, {
      background: (promise) => backgrounds.push(promise),
    }).listen(0, '127.0.0.1'),
  );
  try {
    await Promise.all(
      servers.map((server) => new Promise<void>((resolve) => server.once('listening', resolve))),
    );
    const bases = servers.map(
      (server) => `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
    );
    const replies = await Promise.all(
      Array.from({ length: 10 }, (_, index) =>
        fetch(`${bases[index % 2]}/api/tips`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ note: `Radionica u Osijeku broj ${index}` }),
        }),
      ),
    );
    assert.equal(replies.filter((reply) => reply.status === 201).length, 5);
    assert.equal(replies.filter((reply) => reply.status === 429).length, 5);
    await Promise.all(replies.map((reply) => reply.json()));
    assert.equal((await repositories[0].tips()).length, 5);
    assert.equal(await repositories[0].aiSpent(), 0);
    assert.ok(prepares.every((prepare) => prepare.mock.callCount() === 0));
    assert.equal(backgrounds.length, 0);
  } finally {
    await Promise.all(
      servers.map((server) => new Promise<void>((resolve) => server.close(() => resolve()))),
    );
    await Promise.all(repositories.map((repo) => repo.close()));
    await removeTemporary(directory);
  }
});

test('Postgres quota queries use the application schema and bound client keys', () => {
  assert.equal(
    postgresSql('SELECT attempts FROM tip_quotas WHERE client_key=? AND expires_at>?'),
    'SELECT attempts FROM public.wagz_tip_quotas WHERE client_key=$1 AND expires_at>$2',
  );
});
