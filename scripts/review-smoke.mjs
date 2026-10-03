import { chromium, expect } from '@playwright/test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { mock } from 'node:test';
import express from 'express';
import { Repository } from '../server/repository.ts';
import { WagzService } from '../server/service.ts';
import { createApp } from '../server/app.ts';

// Repeatable browser regression with real captured source records, an in-memory
// database and no AI/network source calls. No production writes or credentials.
// Pin the capture date so real events do not become expired test fixtures.
const fixture = JSON.parse(
  readFileSync(new URL('./fixtures/review-events.json', import.meta.url), 'utf8'),
);
const directory = resolve('.artifacts', `review-${Date.now()}`);
mkdirSync(directory, { recursive: true });
mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-03T10:00:00Z') });
const repo = new Repository(':memory:', fixture.sources);
const key = randomBytes(32).toString('hex');
const config = {
  host: '127.0.0.1',
  port: 0,
  databasePath: ':memory:',
  adminKey: key,
  autoPublish: true,
  fetchOnStart: false,
  fetchIntervalMinutes: 360,
  ai: { apiKey: '', model: 'disabled-browser-audit', monthlyBudgetUsd: 0, searchEnabled: false },
};
let sourceFetches = 0;
const service = new WagzService(repo, config, async () => {
  sourceFetches++;
  return { events: [], pagesFetched: 0, discovered: 0, skipped: 0, warnings: [] };
});
const app = createApp(service);
let vite;
if (process.argv.includes('--dev')) {
  const { createServer } = await import('vite');
  vite = await createServer({
    envDir: false,
    server: { middlewareMode: true, hmr: false },
    appType: 'spa',
    logLevel: 'error',
  });
  app.use(vite.middlewares);
} else {
  app.use(express.static(resolve('dist')));
  app.get('/{*path}', (_request, response) => response.sendFile(resolve('dist/index.html')));
}
const server = app.listen(0, '127.0.0.1');
await new Promise((resolve) => server.once('listening', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const checks = [];
const errors = [];
let browser;
const headers = { authorization: `Bearer ${key}`, 'content-type': 'application/json' };
const record = (name) => {
  checks.push(name);
  console.log(`PASS ${name}`);
};
const check = async (path, body) => {
  const reply = await fetch(base + path, { method: 'PATCH', headers, body: JSON.stringify(body) });
  return { status: reply.status, body: await reply.json() };
};
async function capture(page, name, locator = page) {
  for (const width of [1280, 320]) {
    await page.setViewportSize({ width, height: width === 1280 ? 900 : 740 });
    await page.mouse.move(0, 0);
    await page.evaluate(() => document.activeElement?.blur());
    assert.equal(
      await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1),
      true,
    );
    await locator.screenshot({
      path: resolve(directory, `${name}-${width}.png`),
      ...(locator === page ? { fullPage: true } : {}),
    });
  }
  await page.setViewportSize({ width: 1280, height: 900 });
}
try {
  for (const event of fixture.events) {
    const source = event.sources[0];
    await repo.upsert(
      {
        ...event,
        sourceId: source.sourceId,
        sourceUrl: source.url,
        externalId: event.id,
      },
      new Date(),
      // Hold one real source event so a daily batch can prepare it for approval.
      event.title.startsWith('HeadOnEast'),
    );
  }
  const initialEvents = await repo.events();
  const actual = initialEvents.find((event) => event.title.includes('DOVIK 2026'));
  const held = initialEvents.find((event) => event.title.startsWith('HeadOnEast'));
  assert.ok(actual?.venue);
  assert.equal(held.publication, 'draft');
  const actualNote = `DOVIK 2026 u Osijeku, ${actual.startsAt.slice(0, 10)}, ${actual.venue}.`;
  const chrome =
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ||
    'C:/Program Files/Google/Chrome/Application/chrome.exe';
  browser = await chromium.launch({
    headless: true,
    ...(existsSync(chrome) ? { executablePath: chrome } : {}),
  });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    timezoneId: 'America/Los_Angeles',
  });
  const admin = await context.newPage();
  admin.on('pageerror', (error) => errors.push(error.message));
  await admin.goto(base + '/admin');
  await admin.getByLabel('Admin ključ').fill('incorrect-test-key');
  await admin.getByRole('button', { name: 'Otvori uredništvo' }).click();
  await expect(admin.getByRole('alert')).toContainText('nije ispravan');
  await admin.getByLabel('Admin ključ').fill(key);
  await admin.getByRole('button', { name: 'Otvori uredništvo' }).click();
  await expect(admin.getByRole('heading', { name: 'Grad pod kontrolom.' })).toBeVisible();
  await expect(admin.getByRole('button', { name: 'Za pregled', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  record('invalid login rejected, authenticated editor opened');

  const publicPage = await context.newPage();
  publicPage.on('pageerror', (error) => errors.push(error.message));
  await publicPage.goto(base);
  await expect(publicPage.locator('.coordinates')).toHaveCount(0);
  await expect(publicPage.locator('body')).not.toContainText('45°33′');
  await expect(publicPage.locator('.station-weekday').first()).toBeVisible();
  await publicPage.setViewportSize({ width: 320, height: 740 });
  await expect(publicPage.locator('body')).not.toContainText('18°41′');
  const skip = publicPage.getByRole('link', { name: 'Preskoči na nadolazeće događaje' });
  await skip.focus();
  await expect(skip).toBeVisible();
  await publicPage.keyboard.press('Enter');
  await expect(publicPage.locator('#upcoming-events')).toBeFocused();
  const cardButton = publicPage.locator('.event-card').first().getByRole('button').first();
  await cardButton.click();
  const dialog = publicPage.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await dialog.evaluate((node) => {
    node.scrollTop = node.scrollHeight;
  });
  const closeButton = publicPage.getByRole('button', { name: 'Zatvori', exact: true });
  const closeBox = await closeButton.boundingBox();
  const dialogBox = await dialog.boundingBox();
  assert.ok(closeBox && dialogBox && closeBox.width >= 44 && closeBox.height >= 44);
  assert.ok(
    closeBox.y >= dialogBox.y && closeBox.y + closeBox.height <= dialogBox.y + dialogBox.height,
  );
  await publicPage.screenshot({ path: resolve(directory, 'modal-scrolled-320.png') });
  await closeButton.click();
  await expect(dialog).toHaveCount(0);
  await expect(cardButton).toBeFocused();
  await cardButton.click();
  await publicPage.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(cardButton).toBeFocused();
  await cardButton.click();
  const pageUrl = publicPage.url();
  await publicPage.goBack();
  await expect(dialog).toHaveCount(0);
  assert.equal(publicPage.url(), pageUrl);
  await publicPage.goForward();
  await expect(dialog).toHaveCount(0);
  await cardButton.click();
  await closeButton.click();
  await expect(dialog).toHaveCount(0);
  await publicPage.getByRole('button', { name: 'Dojavi događaj', exact: true }).first().click();
  await expect(dialog).toBeVisible();
  await publicPage.goBack();
  await expect(dialog).toHaveCount(0);
  assert.equal(publicPage.url(), pageUrl);
  await publicPage.goForward();
  await expect(dialog).toHaveCount(0);
  const secondTitle = await publicPage
    .locator('.event-card')
    .nth(1)
    .getByRole('heading')
    .innerText();
  const historyLength = await publicPage.evaluate(() => history.length);
  for (let trial = 0; trial < 4; trial++) {
    await cardButton.click();
    await publicPage.evaluate(() => {
      document.querySelector('.close-button').click();
      setTimeout(() => document.querySelectorAll('.event-card-button')[1].click(), 0);
    });
    await expect(dialog).toContainText(secondTitle);
    // A history traversal is asynchronous: detect a late close of the new dialog.
    await publicPage.waitForTimeout(80);
    await expect(dialog).toBeVisible();
    await publicPage.keyboard.press('Escape');
    await expect(dialog).toHaveCount(0);
  }
  assert.ok((await publicPage.evaluate(() => history.length)) <= historyLength + 1);
  await publicPage.goBack();
  assert.equal(
    publicPage.url(),
    base + '/',
    'Repeated modal closes must not leave phantom Back stops.',
  );
  await publicPage.goForward();
  await expect(dialog).toHaveCount(0);
  await cardButton.click();
  const sourceLink = dialog.locator('a.source-link').first();
  const sourceUrl = await sourceLink.getAttribute('href');
  await context.route(sourceUrl, (route) =>
    route.fulfill({ contentType: 'text/plain', body: 'Isolated source navigation check.' }),
  );
  const popupPromise = publicPage.waitForEvent('popup');
  await sourceLink.click();
  const popup = await popupPromise;
  await popup.waitForLoadState();
  assert.equal(popup.url(), sourceUrl);
  await popup.close();
  await expect(dialog).toBeVisible();
  await context.unroute(sourceUrl);
  await publicPage.goto(base + '/admin');
  await expect(publicPage.getByLabel('Admin ključ')).toBeVisible();
  await publicPage.goBack();
  await expect(publicPage.getByRole('dialog')).toHaveCount(0);
  await cardButton.click();
  await publicPage.goBack();
  await expect(publicPage.getByRole('dialog')).toHaveCount(0);
  record(
    'next-tick close/reopen survives pending Back; repeated cycles add no phantom stops; source tabs and document navigation remain intact',
  );
  record(
    'keyboard skip reaches upcoming cards;44px close stays visible after long320px scroll; close/Escape restore focus and Back/Forward never revive stale event or tip dialogs',
  );
  await publicPage.setViewportSize({ width: 1280, height: 900 });
  await publicPage.getByRole('button', { name: 'Dojavi događaj', exact: true }).first().click();
  await publicPage.getByLabel(/Tvoja dojava/).fill(actualNote);
  await publicPage.getByLabel(/Poveznica/).fill(actual.sources[0].url);
  await publicPage.getByRole('button', { name: 'Pošalji dojavu' }).click();
  await expect(publicPage.getByRole('heading', { name: 'Dobra dojava. Hvala!' })).toBeVisible();
  await expect(publicPage.locator('.tip-success')).toContainText('sljedeću dnevnu provjeru');
  const submittedTip = (await repo.tips()).find((tip) => tip.note === actualNote);
  assert.equal(submittedTip.status, 'inbox');
  assert.equal(submittedTip.draft, null);
  assert.equal(sourceFetches, 0);
  await capture(publicPage, 'daily-tip-success', publicPage.getByRole('dialog'));
  await admin.bringToFront();
  await admin.evaluate(() => window.dispatchEvent(new Event('focus')));
  const matchedRow = admin
    .locator('.tip-row')
    .filter({ has: admin.locator('.tip-note', { hasText: actualNote }) });
  await expect(admin.getByRole('button', { name: 'Čeka provjeru', exact: true })).toContainText(
    '1',
  );
  await expect(matchedRow).toHaveCount(0);
  await expect(admin.getByText('Nema prijedloga za pregled.', { exact: true })).toBeVisible();
  await capture(admin, 'daily-ready-empty');
  await admin.getByRole('button', { name: 'Čeka provjeru', exact: true }).click();
  await expect(matchedRow).toBeVisible();
  await expect(matchedRow).toContainText('sljedeći dnevni dohvat');
  await capture(admin, 'daily-queued');
  record(
    'submission is durable without immediate processing; truthful daily-check receipt and separate default review/pending views fit desktop and 320px',
  );

  const heldNote = `${held.title}, ${held.startsAt.slice(0, 10)}, ${held.venue}.`;
  const unknownNote = 'Plesna večer u Osijeku, najava bez datuma i poveznice.';
  await service.submitTip({ note: heldNote, url: held.sources[0].url });
  await service.submitTip({ note: unknownNote });
  const spam = await service.submitTip({ note: 'z'.repeat(32) });
  await service.collect();
  assert.equal(sourceFetches, fixture.sources.filter((source) => source.enabled).length);
  assert.deepEqual(service.lastTipBatch, {
    queued: 3,
    processed: 3,
    drafted: 1,
    archived: 1,
    deferred: 1,
  });
  assert.deepEqual(
    await repo.events(),
    initialEvents,
    'Daily tip assessment cannot publish or edit source events',
  );
  await admin.evaluate(() => window.dispatchEvent(new Event('focus')));
  const unknownRow = admin
    .locator('.tip-row')
    .filter({ has: admin.locator('.tip-note', { hasText: unknownNote }) });
  await expect(unknownRow).toContainText('čeka dostupnu AI uslugu ili mjesečni proračun');
  await expect(matchedRow).toHaveCount(0);
  await capture(admin, 'daily-pending-retry');
  await admin.getByRole('button', { name: 'Za pregled', exact: true }).click();
  await expect(admin.locator('.tip-row')).toHaveCount(1);
  await expect(admin.locator('.tip-row')).toContainText(held.title);
  await expect(admin.locator('.tip-row')).toContainText('Moguće podudaranje s izvorom');
  await capture(admin, 'daily-ready');
  await admin.getByRole('button', { name: 'Arhiva', exact: true }).click();
  await expect(matchedRow).toContainText('događaj je već objavljen');
  const spamRow = admin
    .locator('.tip-row')
    .filter({ has: admin.locator('.tip-note', { hasText: spam.note }) });
  await expect(spamRow).toContainText('ponovljeni besmisleni sadržaj');
  await capture(admin, 'daily-archive');
  await spamRow.getByRole('button', { name: 'Vrati na provjeru', exact: true }).click();
  await admin.getByRole('button', { name: 'Čeka provjeru', exact: true }).click();
  await expect(spamRow).toBeVisible();
  await expect(spamRow.getByRole('button', { name: 'Uredi prijedlog', exact: true })).toBeEnabled();
  await spamRow.getByRole('button', { name: 'Arhiviraj', exact: true }).click();
  await admin.getByRole('button', { name: 'Arhiva', exact: true }).click();
  await matchedRow.getByRole('button', { name: 'Vrati na pregled', exact: true }).click();
  await admin.getByRole('button', { name: 'Za pregled', exact: true }).click();
  await expect(matchedRow).toContainText('Moguće podudaranje s izvorom');
  record(
    'daily batch separates source-backed drafts, published duplicates, obvious spam and retryable AI unavailability; archives retain reasons and meaningful restore actions',
  );
  let releasePrepare;
  await admin.route('**/api/admin/tips/*/prepare', async (route) => {
    await new Promise((resolve) => {
      releasePrepare = resolve;
    });
    await route.continue();
  });
  await matchedRow.getByRole('button', { name: 'Pripremi / provjeri izvore' }).click();
  await expect(matchedRow.locator('.tip-progress')).toContainText('Provjeravam izvore');
  await expect(matchedRow.getByRole('button', { name: 'Pregledaj prijedlog' })).toBeDisabled();
  releasePrepare();
  await expect(matchedRow.locator('.tip-progress')).toHaveCount(0);
  await expect(matchedRow.locator('.message')).toContainText('bez stvaranja duplikata');
  await admin.unroute('**/api/admin/tips/*/prepare');
  record('manual preparation shows local progress, useful result and reenables actions');

  await matchedRow.getByRole('button', { name: 'Pregledaj prijedlog' }).click();
  await admin.goBack();
  await expect(admin.getByRole('dialog')).toHaveCount(0);
  assert.equal(admin.url(), base + '/admin');
  await admin.goForward();
  await expect(admin.getByRole('dialog')).toHaveCount(0);
  await expect(admin.getByRole('heading', { name: 'Grad pod kontrolom.' })).toBeVisible();
  await matchedRow.getByRole('button', { name: 'Pregledaj prijedlog' }).click();
  record('Back closes the admin editor without logout and Forward never reopens stale review data');
  await expect(admin.getByLabel('Naziv događaja', { exact: true })).toHaveValue(actual.title);
  await expect(admin.getByLabel('Vrijeme ako je poznato')).toHaveValue('09:00');
  await expect(admin.locator('.original-tip a')).toHaveAttribute('href', actual.sources[0].url);
  await admin.getByRole('button', { name: 'Prihvati i objavi' }).click();
  await expect(admin.getByRole('dialog')).toHaveCount(0);
  assert.deepEqual(
    await repo.events(),
    initialEvents,
    'Unchanged approval must preserve the full source event, metadata and count',
  );
  const accepted = (await repo.tips()).find((tip) => tip.note === actualNote);
  assert.equal(accepted.status, 'accepted');
  assert.equal((await check(`/api/admin/tips/${accepted.id}`, { action: 'accept' })).status, 200);
  assert.deepEqual(await repo.events(), initialEvents);
  record(
    'unchanged real source approval and repeated acceptance preserve all event bytes and create no duplicate',
  );

  const realNote = 'Sajam antikviteta';
  const submitted = await fetch(base + '/api/tips', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ note: realNote }),
  });
  assert.equal(submitted.status, 201);
  await admin.getByRole('button', { name: 'Čeka provjeru', exact: true }).click();
  await admin.evaluate(() => window.dispatchEvent(new Event('focus')));
  const row = admin
    .locator('.tip-row')
    .filter({ has: admin.locator('.tip-note', { hasText: realNote }) });
  await expect(row).toBeVisible();
  await row.getByRole('button', { name: 'Uredi prijedlog' }).click();
  await admin.getByLabel('Naziv događaja', { exact: true }).fill(realNote);
  await admin.getByRole('button', { name: 'Spremi prijedlog' }).click();
  await expect(admin.getByRole('dialog')).toHaveCount(0);
  await admin.getByRole('button', { name: 'Za pregled', exact: true }).click();
  await expect(row).toContainText('Datum još nije poznat');
  let partial = (await repo.tips()).find((tip) => tip.note === realNote);
  assert.equal(partial.draft.startsAt, '');
  assert.equal((await repo.events()).length, initialEvents.length);
  await row.getByRole('button', { name: 'Pregledaj prijedlog' }).click();
  await expect(admin.getByLabel('Datum početka', { exact: true })).toHaveValue('');
  await admin.getByRole('button', { name: 'Prihvati i objavi' }).click();
  assert.equal(
    await admin
      .getByLabel('Datum početka', { exact: true })
      .evaluate((node) => node.validity.valueMissing),
    true,
  );
  await expect(admin.getByRole('dialog')).toBeVisible();
  record('unknown-date proposal saves and reopens safely; incomplete publication remains blocked');

  await admin.getByLabel('Opis', { exact: true }).fill('Provjeriti datum i mjesto prije objave.');
  const changed = await check(`/api/admin/tips/${partial.id}`, {
    action: 'save',
    revision: partial.revision,
    draft: { ...partial.draft, description: 'Provjeriti izvornu najavu.' },
  });
  assert.equal(changed.status, 200);
  const stale = await check(`/api/admin/tips/${partial.id}`, {
    action: 'save',
    revision: partial.revision,
    draft: partial.draft,
  });
  assert.equal(stale.status, 409);
  await admin.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(admin.locator('.editor-conflict')).toBeVisible();
  await expect(admin.getByLabel('Opis', { exact: true })).toHaveValue(
    'Provjeriti datum i mjesto prije objave.',
  );
  await expect(admin.getByRole('button', { name: 'Spremi prijedlog' })).toBeDisabled();
  await admin.getByRole('button', { name: 'Učitaj najnoviji prijedlog' }).click();
  await expect(admin.getByLabel('Opis', { exact: true })).toHaveValue('Provjeriti izvornu najavu.');
  record('concurrent updates return409, preserve unsaved operator text and offer explicit reload');

  await admin.getByLabel('Izvorna poveznica', { exact: true }).fill('javascript:alert(1)');
  await admin.getByRole('button', { name: 'Spremi prijedlog' }).click();
  await expect(admin.getByRole('dialog').getByRole('alert')).toContainText('http ili https');
  assert.equal((await repo.tip(partial.id)).draft.sourceUrl, null);
  await admin.getByLabel('Izvorna poveznica', { exact: true }).fill('');
  await admin.setViewportSize({ width: 320, height: 740 });
  await admin.getByRole('button', { name: 'Spremi prijedlog' }).scrollIntoViewIfNeeded();
  assert.equal(
    await admin.getByRole('dialog').evaluate((node) => node.scrollWidth <= node.clientWidth + 1),
    true,
  );
  for (const button of await admin.locator('.editor-actions button').all()) {
    const box = await button.boundingBox();
    assert.ok(box && box.x >= 0 && box.x + box.width <= 320);
  }
  await admin.screenshot({ path: resolve(directory, 'editor-320.png'), fullPage: true });
  await admin.getByRole('button', { name: 'Spremi prijedlog' }).click();
  await expect(admin.getByRole('dialog')).toHaveCount(0);
  record('unsafe source links rejected without losing draft;320px editor buttons and fields fit');

  for (const [action, filter] of [
    ['Odbij', 'Odbijeno'],
    ['Vrati na pregled', 'Za pregled'],
    ['Arhiviraj', 'Arhiva'],
    ['Vrati na pregled', 'Za pregled'],
  ]) {
    await row.getByRole('button', { name: action, exact: true }).click();
    await expect(row).toHaveCount(0);
    await admin.getByRole('button', { name: filter, exact: true }).click();
    await expect(row).toBeVisible();
  }
  partial = await repo.tip(partial.id);
  assert.equal(partial.note, realNote);
  assert.equal(partial.draft.title, realNote);
  record('reject, restore, archive and restore preserve the original note and saved proposal');

  const lease = await repo.acquireLease(`tip:${partial.id}`, 10000);
  await admin.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(row.locator('.tip-progress')).toContainText('Provjera dojave je u tijeku');
  await expect(row.getByRole('button', { name: 'Provjera u tijeku…' })).toBeDisabled();
  await repo.releaseLease(`tip:${partial.id}`, lease);
  await expect(row.locator('.tip-progress')).toHaveCount(0, { timeout: 6000 });
  await expect(row.getByRole('button', { name: 'Pripremi / provjeri izvore' })).toBeEnabled();
  assert.equal(
    await admin.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1),
    true,
  );
  await admin.screenshot({ path: resolve(directory, 'inbox-320.png'), fullPage: true });
  record(
    'background preparation appears and clears automatically;320px inbox has no horizontal overflow',
  );

  // The primary KC source explicitly announces this actual past performance for
  // 12 September 2026 at 20:00. Retain that date; never advance it for publication.
  const pastNote = 'Marko Kutlić, Moram dalje tour, 12.9.2026. u 20 sati, Dvorana Franjo Krežma.';
  const historical = await fetch(base + '/api/tips', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ note: pastNote }),
  });
  assert.equal(historical.status, 201);
  await admin.getByRole('button', { name: 'Čeka provjeru', exact: true }).click();
  await admin.evaluate(() => window.dispatchEvent(new Event('focus')));
  const historicalRow = admin
    .locator('.tip-row')
    .filter({ has: admin.locator('.tip-note', { hasText: pastNote }) });
  await expect(historicalRow).toBeVisible();
  await historicalRow.getByRole('button', { name: 'Uredi prijedlog' }).click();
  await admin.getByLabel('Naziv događaja', { exact: true }).fill('Marko Kutlić – Moram dalje tour');
  await admin.getByLabel('Datum početka', { exact: true }).fill('2026-09-12');
  await admin.getByLabel('Vrijeme ako je poznato').fill('20:00');
  await admin.getByLabel('Mjesto održavanja', { exact: true }).fill('Dvorana Franjo Krežma');
  await admin
    .getByLabel('Izvorna poveznica', { exact: true })
    .fill('https://kulturni-centar.hr/dogadjanja/129-marko-kutli-moram-dalje-tour');
  await admin.getByRole('button', { name: 'Spremi prijedlog' }).click();
  await expect(admin.getByRole('dialog')).toHaveCount(0);
  await admin.getByRole('button', { name: 'Za pregled', exact: true }).click();
  await historicalRow.getByRole('button', { name: 'Pregledaj prijedlog' }).click();
  await expect(admin.getByLabel('Vrijeme ako je poznato')).toHaveValue('20:00');
  await admin.getByRole('button', { name: 'Prihvati i objavi' }).click();
  await expect(admin.getByRole('dialog').getByRole('alert')).toContainText('već završio');
  const savedHistorical = (await repo.tips()).find((tip) => tip.note === pastNote);
  assert.equal(savedHistorical.status, 'draft');
  assert.equal(savedHistorical.draft.startsAt, '2026-09-12T20:00:00+02:00');
  await admin.getByRole('button', { name: 'Zatvori', exact: true }).click();
  record(
    'actual past Marko Kutlić performance saves with original date and source; publishing shows ended-event error',
  );
  assert.deepEqual(errors, []);
  assert.deepEqual(await repo.events(), initialEvents);
  await admin.getByRole('button', { name: 'Odjavi se' }).click();
  await expect(admin.getByLabel('Admin ključ')).toHaveValue('');
  record('logout clears authentication and no browser runtime errors occurred');
} finally {
  if (browser) await browser.close();
  if (vite) await vite.close();
  await new Promise((resolve) => server.close(resolve));
  await repo.close();
  mock.timers.reset();
  writeFileSync(
    resolve(directory, 'report.json'),
    JSON.stringify({ fixture: fixture.capturedAt, checks, errors }, null, 2),
  );
}
