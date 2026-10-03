import { chromium, expect } from '@playwright/test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { mock } from 'node:test';
import { createServer as createHttpServer } from 'node:http';
import { Repository } from '../server/repository.ts';
import { WagzService } from '../server/service.ts';
import { createApp } from '../server/app.ts';
import { mountPublicPages } from '../server/public-pages.ts';
import { ADMIN_PATH, eventPath, publicSiteUrl } from '../shared/site.ts';
import { build, createServer } from 'vite';

// Built, isolated SSR + hydration regression. No environment files, paid calls or live writes.
const fixture = JSON.parse(
  readFileSync(new URL('./fixtures/review-events.json', import.meta.url), 'utf8'),
);
const directory = resolve('.artifacts', `seo-pages-${Date.now()}`);
mkdirSync(directory, { recursive: true });
const builtDirectory = resolve(directory, 'build');
await build({ envDir: false, build: { outDir: builtDirectory }, logLevel: 'error' });
mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-03T10:00:00Z') });
const repo = new Repository(':memory:', fixture.sources);
const service = new WagzService(repo, {
  host: '127.0.0.1',
  port: 0,
  databasePath: ':memory:',
  adminKey: 'isolated-seo-test',
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 360,
  ai: { apiKey: '', model: 'disabled', monthlyBudgetUsd: 0, searchEnabled: false },
});
for (const event of fixture.events) {
  const source = event.sources[0];
  await repo.upsert({
    ...event,
    sourceId: source.sourceId,
    sourceUrl: source.url,
    externalId: event.id,
  });
}
const historical = await repo.upsert({
  sourceId: fixture.sources[0].id,
  sourceUrl: 'https://example.org/isolated-past-workshop',
  externalId: 'seo-past',
  title: 'Završena radionica',
  description: 'Izolirani primjer prošlog događaja.',
  startsAt: '2025-10-03T10:00:00+02:00',
  endsAt: '2025-10-03T12:00:00+02:00',
  venue: 'Testna lokacija',
  address: null,
  city: 'Osijek',
  category: 'workshop',
  price: null,
  status: 'scheduled',
});
const app = createApp(service);
mountPublicPages(app, builtDirectory, repo);
const server = app.listen(0, '127.0.0.1');
await new Promise((done) => server.once('listening', done));
const base = `http://127.0.0.1:${server.address().port}`;
const errors = [];
const checks = [];
let browser;
let devVite;
let devServer;
const record = (name) => {
  checks.push(name);
  console.log(`PASS ${name}`);
};
try {
  const feed = await (await fetch(base + '/api/events')).json();
  const event = feed.events.find((item) => !item.endsAt || Date.parse(item.startsAt) > Date.now());
  assert.ok(event);
  const path = eventPath(event.id);
  const html = await (await fetch(base)).text();
  assert.ok(html.includes(`href="${path}"`));
  assert.ok(html.includes('id="wagz-page-data"'));
  for (const oldPath of ['/admin', '/admin/']) {
    const old = await fetch(base + oldPath, { redirect: 'manual' });
    assert.equal(old.status, 404);
    assert.equal(old.headers.get('location'), null);
  }
  const editor = await fetch(base + ADMIN_PATH);
  assert.equal(editor.status, 200);
  assert.equal(editor.headers.get('x-robots-tag'), 'noindex, nofollow');
  const chrome =
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ||
    'C:/Program Files/Google/Chrome/Application/chrome.exe';
  browser = await chromium.launch({
    headless: true,
    ...(existsSync(chrome) ? { executablePath: chrome } : {}),
  });
  const noJs = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 390, height: 900 },
  });
  const staticPage = await noJs.newPage();
  await staticPage.goto(base);
  await expect(staticPage.locator(`a[href^="/admin"], a[href^="${ADMIN_PATH}"]`)).toHaveCount(0);
  await expect(staticPage.locator(`a.event-card-button[href="${path}"]`)).toContainText(
    event.title,
  );
  await staticPage.goto(base + path);
  await expect(staticPage.locator(`a[href^="/admin"], a[href^="${ADMIN_PATH}"]`)).toHaveCount(0);
  await expect(staticPage.locator('h1')).toHaveText(event.title);
  await expect(staticPage.locator('.event-facts')).toContainText(event.venue);
  await expect(staticPage.locator('.source-link').first()).toHaveAttribute(
    'href',
    event.sources[0].url,
  );
  record(
    'Initial homepage/event HTML exposes event links, facts and sources with JavaScript disabled',
  );
  await noJs.close();
  for (const width of [1440, 390, 320]) {
    const context = await browser.newContext({
      viewport: { width, height: 900 },
      reducedMotion: 'reduce',
    });
    await context.addInitScript(() => {
      window.__cspViolations = [];
      document.addEventListener('securitypolicyviolation', (event) =>
        window.__cspViolations.push(`${event.effectiveDirective}: ${event.blockedURI}`),
      );
    });
    const page = await context.newPage();
    page.on('pageerror', (error) => errors.push(error.message));
    page.on('console', (message) => {
      if (/hydration|hydrated|did not match/i.test(message.text())) errors.push(message.text());
    });
    await page.goto(base, { waitUntil: 'networkidle' });
    const card = page.locator(`a.event-card-button[href="${path}"]`);
    const skip = page.getByRole('link', { name: 'Preskoči na nadolazeće događaje' });
    await skip.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('#upcoming-events')).toBeFocused();
    for (const method of ['close', 'Escape', 'Back']) {
      await card.click();
      await expect(page.getByRole('dialog')).toBeVisible();
      await page.getByRole('dialog').evaluate((node) => {
        node.scrollTop = node.scrollHeight;
      });
      if (method === 'close')
        await page.getByRole('button', { name: 'Zatvori', exact: true }).click();
      else if (method === 'Escape') await page.keyboard.press('Escape');
      else await page.goBack();
      await expect(page.getByRole('dialog')).toHaveCount(0);
      await expect(card).toBeFocused();
      await expect(page).toHaveURL(base + '/#upcoming-events');
    }
    await card.focus();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('dialog')).toContainText(event.title);
    await expect(page).toHaveURL(base + path);
    await page.goBack();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(card).toBeFocused();
    await page.goForward();
    await expect(page.getByRole('dialog')).toContainText(event.title);
    await page.reload({ waitUntil: 'networkidle' });
    await expect(page.locator('h1')).toHaveText(event.title);
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
      'href',
      publicSiteUrl(path),
    );
    await expect(page).toHaveTitle(`${event.title} — WagZ`);
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.screenshot({ path: resolve(directory, `event-page-${width}.png`), fullPage: true });
    await page.goto(base + eventPath(historical.id), { waitUntil: 'networkidle' });
    await expect(page.locator('.event-past')).toContainText('Događaj je završio.');
    await expect(page.locator('script[type="application/ld+json"]')).toHaveCount(0);
    await page.screenshot({ path: resolve(directory, `past-event-${width}.png`), fullPage: true });
    await page.goto(base);
    const popupPromise = context.waitForEvent('page');
    await page.locator(`a.event-card-button[href="${path}"]`).click({ modifiers: ['Control'] });
    const popup = await popupPromise;
    await popup.waitForLoadState('networkidle');
    await expect(popup.locator('h1')).toHaveText(event.title);
    assert.equal(popup.url(), base + path);
    await popup.close();
    assert.deepEqual(await page.evaluate(() => window.__cspViolations), []);
    await context.close();
    record(
      `${width}px hydration, hash-origin close/Escape/Back focus, keyboard permalink, Back/Forward, refresh, past notice and Ctrl-click new tab`,
    );
  }
  // Development has no SSR bootstrap; a direct URL must still load the event API.
  const devApp = createApp(service);
  devServer = createHttpServer(devApp);
  devVite = await createServer({
    envDir: false,
    server: {
      middlewareMode: true,
      hmr: false,
      ws: { server: devServer },
      watch: { ignored: ['**/.artifacts/**', '**/apps/mobile/build/**'] },
    },
    appType: 'spa',
    logLevel: 'error',
  });
  devApp.use(devVite.middlewares);
  devServer.listen(0, '127.0.0.1');
  await new Promise((done) => devServer.once('listening', done));
  const devBase = `http://127.0.0.1:${devServer.address().port}`;
  const devContext = await browser.newContext({ viewport: { width: 320, height: 900 } });
  const devPage = await devContext.newPage();
  devPage.on('pageerror', (error) => errors.push(error.message));
  await devPage.goto(devBase + path);
  await expect(devPage.locator('#wagz-page-data')).toHaveCount(0);
  await expect(devPage.locator('h1')).toHaveText(event.title);
  await expect(devPage.locator('.event-facts')).toContainText(event.venue);
  await devPage.reload();
  await expect(devPage.locator('h1')).toHaveText(event.title);
  await devPage.goto(devBase + '/dogadaji/missing-event');
  await expect(devPage.locator('h1')).toHaveText('Događaj nije pronađen.');
  await devPage.goto(devBase + eventPath(historical.id));
  await expect(devPage.locator('.event-past')).toContainText('Događaj je završio.');
  await devContext.close();
  record('Development direct event load/reload, missing-event state and past-event notice');
  assert.deepEqual(errors, []);
  record('No hydration/page errors or captured CSP violations');
  writeFileSync(resolve(directory, 'report.json'), JSON.stringify({ checks, errors }, null, 2));
  console.log(`Screenshots: ${directory}`);
} finally {
  await browser?.close();
  await devVite?.close();
  if (devServer) await new Promise((done) => devServer.close(done));
  await new Promise((done) => server.close(done));
  await repo.close();
  mock.timers.reset();
}
