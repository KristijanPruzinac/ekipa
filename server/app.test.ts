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
    const tip = (await repo.tips())[0];
    assert.equal(tip.status, 'inbox');
    assert.equal((await repo.publicEvents()).length, 0);
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
    assert.equal(await repo.autoPublish(), false);
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
    await repo.close();
  }
});

test('failed sources do not remove events; one failing source does not prevent another import', async () => {
  const repo = new Repository(':memory:', [source, { ...source, id: 'second' }]);
  await repo.upsert(event);
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
    assert.equal((await repo.events()).length, 2);
    assert.equal((await repo.runs()).find((run) => run.sourceId === 'test')?.status, 'error');
    assert.equal((await repo.runs()).find((run) => run.sourceId === 'second')?.status, 'success');
    assert.equal(service.collecting, false);
  } finally {
    await repo.close();
  }
});

test('a tip URL shared by multiple source events does not choose an arbitrary match', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, testConfig);
  try {
    await repo.upsert(event);
    await repo.upsert({ ...event, externalId: '2', title: 'Drugi koncert' });
    const tip = await service.submitTip({
      note: 'Tu je neki događaj koji nedostaje',
      url: event.sourceUrl,
    });
    const result = await service.prepareTip(tip.id);
    assert.equal(result.matchedEventId, null);
    assert.equal(result.status, 'inbox');
  } finally {
    await repo.close();
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
    for (let i = 0; !flags.length && i < 40; i++)
      await new Promise((resolve) => setTimeout(resolve, 10));
    assert.deepEqual(flags, [true]);
    for (let i = 0; service.collecting && i < 40; i++)
      await new Promise((resolve) => setTimeout(resolve, 10));
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
    await repo.close();
  }
});

test('review API saves incomplete drafts, rejects stale edits and exposes active preparation', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, testConfig);
  const server = createApp(service).listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  const headers = { 'content-type': 'application/json', authorization: 'Bearer test-only-key' };
  try {
    const tip = await service.submitTip({ note: 'Sajam antikviteta' });
    const patch = (body: unknown) =>
      fetch(`${base}/api/admin/tips/${tip.id}`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify(body),
      });
    const partial = { ...event, title: '', startsAt: '', venue: null, sourceUrl: null };
    const saved = await patch({ action: 'save', draft: partial, revision: tip.revision });
    assert.equal(saved.status, 200);
    const draft = await saved.json();
    assert.equal(draft.status, 'draft');
    assert.equal(draft.draft.startsAt, '');
    assert.equal(draft.draft.title, '');
    assert.equal((await repo.publicEvents()).length, 0);
    const stale = await patch({ action: 'reject', revision: tip.revision });
    assert.equal(stale.status, 409);
    assert.match((await stale.json()).error, /promijenjena/);
    assert.equal((await repo.tip(tip.id))!.status, 'draft');
    assert.equal((await patch({ action: 'accept', revision: draft.revision })).status, 400);
    assert.equal(
      (await patch({ action: 'save', draft: { ...partial, sourceUrl: 'javascript:alert(1)' } }))
        .status,
      400,
    );
    assert.equal(
      (await patch({ action: 'save', draft: { ...partial, startsAt: '2026-02-30' } })).status,
      400,
    );
    const lease = await repo.acquireLease(`tip:${tip.id}`, 10000);
    const dashboard = await (await fetch(`${base}/api/admin/dashboard`, { headers })).json();
    assert.deepEqual(dashboard.preparingTipIds, [tip.id]);
    await repo.releaseLease(`tip:${tip.id}`, lease!);
    assert.deepEqual((await service.dashboard()).preparingTipIds, []);
    const flags: boolean[] = [];
    const prepare = service.prepareTip.bind(service);
    service.prepareTip = async (id, force = false) => {
      flags.push(force);
      return prepare(id, force);
    };
    assert.equal(
      (await fetch(`${base}/api/admin/tips/${tip.id}/prepare`, { method: 'POST', headers })).status,
      200,
    );
    assert.deepEqual(flags, [true]);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
    await repo.close();
  }
});

test('reject, archive and restore retain a historical event assessment and source facts', async () => {
  const repo = new Repository(':memory:', [source]);
  const service = new WagzService(repo, testConfig);
  try {
    const tip = await service.submitTip({
      note: 'Marko Kutlić, Moram dalje tour, 12.9.2026. u 20 sati, Dvorana Franjo Krežma.',
      url: 'https://kulturni-centar.hr/dogadjanja/129-marko-kutli-moram-dalje-tour',
    });
    const assessment =
      'Izvor potvrđuje najavu za 12.9.2026. Događaj je već završio; nije nadolazeći događaj.';
    const saved = await repo.saveTip({
      ...tip,
      status: 'draft',
      reason: assessment,
      draft: {
        ...event,
        title: 'Marko Kutlić – Moram dalje tour',
        startsAt: '2026-09-12T20:00:00+02:00',
        venue: 'Dvorana Franjo Krežma',
        sourceUrl: tip.url,
      },
    });
    let current = saved;
    for (const [action, status] of [
      ['reject', 'rejected'],
      ['restore', 'draft'],
      ['archive', 'archived'],
      ['restore', 'draft'],
    ]) {
      current = await service.updateTip(tip.id, action, undefined, current.revision);
      assert.equal(current.status, status);
      assert.equal(current.reason, assessment);
      assert.equal(current.note, tip.note);
      assert.equal(current.url, tip.url);
      assert.deepEqual(current.draft, saved.draft);
    }
  } finally {
    await repo.close();
  }
});
