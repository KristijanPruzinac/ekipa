import { createApp } from '../server/app.ts';
import { Repository } from '../server/repository.ts';
import { WagzService } from '../server/service.ts';
import { createServer, build } from 'vite';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// Local security-review fixture only: no environment loading, real credentials,
// persistent database, source requests or paid provider calls.
const repo = new Repository(':memory:', []);
const config = {
  host: '127.0.0.1',
  port: 0,
  databasePath: ':memory:',
  adminKey: 'fixture-admin-key',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 1440,
  ai: { apiKey: '', model: 'disabled', monthlyBudgetUsd: 0, searchEnabled: false },
};
const service = new WagzService(repo, config);
const hostile = '</script><img id="security-xss-canary" src=x onerror="alert(1)">';
const fixtureEvent = await repo.upsert({
  sourceId: 'fixture',
  externalId: 'security-rendering',
  sourceUrl: 'https://organizer.example/event',
  title: `Security fixture ${hostile}`,
  description: `Literal untrusted description ${hostile}`,
  startsAt: '2099-10-03',
  endsAt: null,
  venue: 'Osijek',
  address: null,
  city: 'Osijek',
  category: 'music',
  price: null,
  status: 'scheduled',
});
await service.submitTip({
  note: `Security tip </textarea><script id="security-xss-canary">alert(1)</script> ${hostile}`,
});
const app = createApp(service);
export const production = process.argv.includes('--production');
let vite;
if (production) {
  const directory = resolve('.artifacts', `security-production-build-${Date.now()}`);
  await build({
    envDir: false,
    logLevel: 'error',
    build: { outDir: directory, emptyOutDir: false },
  });
  const serverDirectory = `${directory}-server`;
  await build({
    envDir: false,
    logLevel: 'error',
    build: { ssr: 'server/public-pages.ts', outDir: serverDirectory, emptyOutDir: false },
  });
  // Exercise the same self-contained SSR bundle that the hosted function loads.
  const { mountPublicPages: mountBuiltPages } = await import(
    pathToFileURL(resolve(serverDirectory, 'public-pages.js')).href
  );
  mountBuiltPages(app, directory, repo);
} else {
  vite = await createServer({
    envDir: false,
    server: { middlewareMode: true, hmr: false },
    appType: 'spa',
    logLevel: 'error',
  });
  app.use(vite.middlewares);
}
const server = app.listen(0, '127.0.0.1');
await new Promise((resolve) => server.once('listening', resolve));
export const base = `http://127.0.0.1:${server.address().port}`;
export const eventId = fixtureEvent.id;
export const rotateFixtureKey = () => {
  config.adminKey = 'rotated-fixture-admin-key';
};
export const stop = async () => {
  await new Promise((resolve) => server.close(() => resolve()));
  await vite?.close();
  await repo.close();
};
console.log(`Security fixture: ${base}`);
for (const signal of ['SIGINT', 'SIGTERM'])
  process.on(signal, () => {
    void stop().then(() => process.exit(0));
  });
