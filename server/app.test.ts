import test from 'node:test';
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';
import { createApp } from './app.ts';
import type { Config } from './config.ts';

const testConfig: Config = {
  host: '127.0.0.1',
  port: 3000,
  databasePath: ':memory:',
  adminKey: 'test-only-key',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 360,
  ai: { apiKey: '', model: 'test-model', monthlyBudgetUsd: 1, searchEnabled: false },
};
const source = {
  id: 'test',
  name: 'Test source',
  url: 'https://example.org',
  description: '',
  enabled: true,
};
const event = {
  sourceId: 'test',
  externalId: '1',
  sourceUrl: 'https://example.org/1',
  title: 'Koncert na otvorenom',
  description: '',
  startsAt: '2099-10-10T20:00:00+02:00',
  endsAt: null,
  venue: 'Osijek',
  address: null,
  city: 'Osijek',
  category: 'music' as const,
  price: null,
  status: 'scheduled' as const,
};

test('public feed stays public; inbox and settings require admin; tip can publish without duplicates', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, testConfig);
  const server = createApp(service).listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  const headers = { 'content-type': 'application/json', authorization: 'Bearer test-only-key' };
  try {
    assert.equal((await fetch(`${base}/api/admin/dashboard`)).status, 401);
    assert.equal(
      (
        await fetch(`${base}/api/admin/settings`, {
          method: 'PATCH',
          headers: { 'content-type': 'application/json' },
          body: '{"autoPublish":false}',
        })
      ).status,
      401,
    );
    const response = await fetch(`${base}/api/tips`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ note: 'Lokalni koncert u listopadu u Osijeku.' }),
    });
    assert.equal(response.status, 201);
    assert.equal((await response.json()).ok, true);
    await new Promise((resolve) => setTimeout(resolve, 20));
    const tip = repo.tips()[0];
    assert.equal(tip.status, 'inbox');
    assert.equal(repo.publicEvents().length, 0);
    const draft = { ...event, sourceUrl: null };
    const accept = () =>
      fetch(`${base}/api/admin/tips/${tip.id}`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ action: 'accept', draft }),
      });
    assert.equal((await accept()).status, 200);
    assert.equal((await accept()).status, 200);
    assert.equal((await (await fetch(`${base}/api/events`)).json()).events.length, 1);
    assert.equal(
      (
        await fetch(`${base}/api/admin/settings`, {
          method: 'PATCH',
          headers,
          body: '{"autoPublish":false}',
        })
      ).status,
      200,
    );
    assert.equal(repo.autoPublish(), false);
    assert.equal(
      (
        await fetch(`${base}/api/admin/settings`, {
          method: 'PATCH',
          headers: { ...headers, origin: 'https://evil.example' },
          body: '{"autoPublish":true}',
        })
      ).status,
      403,
    );
    assert.equal(
      (
        await fetch(`${base}/api/tips`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ note: 'Događaj', url: 'javascript:alert(1)' }),
        })
      ).status,
      400,
    );
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
    repo.close();
  }
});

test('failed sources do not remove events; one failing source does not prevent another import', async () => {
  const repo = new Repository(':memory:', [source, { ...source, id: 'second' }]);
  repo.upsert(event);
  const service = new WagzService(repo, testConfig, async (id) => {
    if (id === 'test') throw new Error('Source unavailable');
    return {
      events: [{ ...event, sourceId: 'second', externalId: '2', title: 'Drugi događaj' }],
      discovered: 1,
      skipped: 0,
      pagesFetched: 1,
      warnings: [],
    };
  });
  try {
    await service.collect();
    assert.equal(repo.events().length, 2);
    assert.equal(repo.runs().find((run) => run.sourceId === 'test')?.status, 'error');
    assert.equal(repo.runs().find((run) => run.sourceId === 'second')?.status, 'success');
    assert.equal(service.collecting, false);
  } finally {
    repo.close();
  }
});

test('a tip URL shared by multiple source events does not choose an arbitrary match', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, testConfig);
  try {
    repo.upsert(event);
    repo.upsert({ ...event, externalId: '2', title: 'Drugi koncert' });
    const tip = service.submitTip({
      note: 'Tu je neki događaj koji nedostaje',
      url: event.sourceUrl,
    });
    const result = await service.prepareTip(tip.id);
    assert.equal(result.matchedEventId, null);
    assert.equal(result.status, 'inbox');
  } finally {
    repo.close();
  }
});

test('the administrator refresh endpoint forces a fresh reader request', async () => {
  const repo = new Repository(':memory:', [source]);
  const flags: boolean[] = [];
  const service = new WagzService(repo, testConfig, async (_id, options) => {
    flags.push(options?.force ?? false);
    return { events: [], discovered: 0, skipped: 0, pagesFetched: 1, warnings: [] };
  });
  const server = createApp(service).listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  try {
    const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    const response = await fetch(`${base}/api/admin/collect`, {
      method: 'POST',
      headers: { authorization: 'Bearer test-only-key' },
    });
    assert.equal(response.status, 202);
    assert.deepEqual(flags, [true]);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
    repo.close();
  }
});
