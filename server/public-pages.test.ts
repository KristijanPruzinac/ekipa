import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { AddressInfo } from 'node:net';
import { createApp } from './app.ts';
import { mountPublicPages, PRODUCTION_CSP } from './public-pages.ts';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';
import { ADMIN_PATH } from '../shared/site.ts';

test('production pages preserve root/admin/assets and API 404s without a catch-all homepage', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-public-pages-'));
  await mkdir(join(directory, 'assets'));
  await writeFile(join(directory, 'assets', 'index-test.js'), '/* test asset */');
  await writeFile(
    join(directory, 'index.html'),
    (await readFile(new URL('../index.html', import.meta.url), 'utf8')).replace(
      '/src/main.tsx',
      '/assets/index-test.js',
    ),
  );
  await writeFile(join(directory, 'robots.txt'), 'User-agent: *\nAllow: /\n');
  await writeFile(join(directory, 'sitemap.xml'), '<?xml version="1.0"?><urlset></urlset>');
  const repository = new Repository(':memory:', []);
  const service = new WagzService(repository, {
    host: '127.0.0.1',
    port: 0,
    databasePath: ':memory:',
    adminKey: 'isolated-pages-test',
    autoPublish: false,
    fetchOnStart: false,
    fetchIntervalMinutes: 360,
    ai: { apiKey: '', model: 'disabled', monthlyBudgetUsd: 0, searchEnabled: false },
  });
  const app = createApp(service);
  mountPublicPages(app, directory, repository);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((done) => server.once('listening', done));
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  try {
    for (const path of ['/', '/?from=share', ADMIN_PATH, `${ADMIN_PATH}/`]) {
      const response = await fetch(base + path);
      assert.equal(response.status, 200, path);
      assert.equal(response.headers.get('content-security-policy'), PRODUCTION_CSP);
      assert.match(response.headers.get('content-type')!, /text\/html/);
      assert.match(await response.text(), /<title>WagZ — Događaji u Osijeku<\/title>/);
      if (path.startsWith(ADMIN_PATH)) {
        assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
        assert.equal(response.headers.get('cache-control'), 'no-store');
      } else {
        assert.equal(response.headers.get('x-robots-tag'), null);
      }
    }
    for (const [path, contentType] of [
      ['/robots.txt', /text\/plain/],
      ['/sitemap.xml', /application\/xml/],
    ] as const) {
      const response = await fetch(base + path);
      assert.equal(response.status, 200);
      assert.equal(response.headers.get('content-security-policy'), PRODUCTION_CSP);
      assert.match(response.headers.get('content-type')!, contentType);
      assert.doesNotMatch(await response.text(), /<div id="root">/);
    }
    for (const path of [
      '/events/not-an-event',
      '/admin',
      '/admin/',
      '/admin/missing',
      `${ADMIN_PATH}/missing`,
      '/ADMIN',
      '/missing',
      '/assets/missing.js',
    ]) {
      const response = await fetch(base + path);
      assert.equal(response.status, 404, path);
      assert.equal(response.headers.get('location'), null, 'retired editor paths never redirect');
      assert.equal(response.headers.get('content-security-policy'), PRODUCTION_CSP);
      assert.doesNotMatch(await response.text(), /<div id="root">/);
    }
    const missingApi = await fetch(base + '/api/not-a-route');
    assert.equal(missingApi.status, 404);
    assert.match(missingApi.headers.get('content-type')!, /application\/json/);
    assert.deepEqual(await missingApi.json(), { error: 'Nepoznata API adresa.' });
  } finally {
    await new Promise<void>((done) => server.close(() => done()));
    await repository.close();
    assert.ok(directory.startsWith(join(tmpdir(), 'wagz-public-pages-')));
    await rm(directory, { recursive: true, force: true });
  }
});

test('hosted and local production pages enforce the same CSP without inline scripts or eval', async () => {
  const config = JSON.parse(await readFile(new URL('../vercel.json', import.meta.url), 'utf8'));
  const headers = config.headers.find(
    (route: { source: string }) => route.source === '/(.*)',
  ).headers;
  assert.equal(
    headers.find((header: { key: string }) => header.key === 'Content-Security-Policy').value,
    PRODUCTION_CSP,
  );
  const directives = new Map(
    PRODUCTION_CSP.split('; ').map((entry) => {
      const [name, ...values] = entry.split(' ');
      return [name, values];
    }),
  );
  assert.deepEqual(directives.get('script-src'), ["'self'"]);
  assert.deepEqual(directives.get('connect-src'), ["'self'"]);
  for (const name of ['object-src', 'base-uri', 'frame-src', 'frame-ancestors'])
    assert.deepEqual(directives.get(name), ["'none'"]);
  assert.ok(!PRODUCTION_CSP.includes('unsafe-eval'));
});
