import assert from 'node:assert/strict';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { chromium, expect } from '@playwright/test';
import { base, eventId, production, rotateFixtureKey, stop } from './security-browser-fixture.mjs';
import { PRODUCTION_CSP } from '../server/public-pages.ts';
import { ADMIN_PATH } from '../shared/site.ts';

const directory = resolve('.artifacts', `security-browser-${Date.now()}`);
mkdirSync(directory, { recursive: true });
const checks = [];
const record = (name) => {
  checks.push(name);
  console.log(`PASS ${name}`);
};
const executablePath = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
let browser;
try {
  browser = await chromium.launch({
    headless: true,
    ...(existsSync(executablePath) ? { executablePath } : {}),
  });
  const context = await browser.newContext();
  const violations = [];
  const fontFailures = [];
  await context.exposeBinding('__recordSecurityViolation', (_source, violation) => {
    violations.push(violation);
  });
  await context.addInitScript(() => {
    document.addEventListener('securitypolicyviolation', (event) => {
      void window.__recordSecurityViolation({
        directive: event.effectiveDirective,
        blockedURI: event.blockedURI,
      });
    });
  });
  context.on('requestfailed', (request) => {
    if (/fonts\.(?:googleapis|gstatic)\.com/.test(request.url()))
      fontFailures.push({ url: request.url(), failure: request.failure()?.errorText });
  });
  await context.route('https://organizer.example/event', (route) =>
    route.fulfill({ contentType: 'text/html', body: '<h1>Isolated organizer page</h1>' }),
  );
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('dialog', async (dialog) => {
    errors.push('Unexpected script dialog');
    await dialog.dismiss();
  });
  const initial = await page.goto(base);
  assert.equal(
    initial.headers()['content-security-policy'] ?? null,
    production ? PRODUCTION_CSP : null,
  );
  await expect(page.locator('.event-card-button').first()).toContainText(
    '<img id="security-xss-canary"',
  );
  await expect(page.locator('#security-xss-canary')).toHaveCount(0);
  await page.locator('.event-card-button').first().click();
  await expect(page.getByRole('dialog')).toContainText(
    'Literal untrusted description </script><img',
  );
  await expect(page.locator('#security-xss-canary')).toHaveCount(0);
  await page.screenshot({ path: resolve(directory, 'hostile-public-text.png'), fullPage: true });
  record('Public title and description render hostile HTML as literal text without injected nodes');
  const popupPromise = page.waitForEvent('popup');
  await page.locator('.source-link').first().click();
  const source = await popupPromise;
  await expect(source.getByRole('heading', { name: 'Isolated organizer page' })).toBeVisible();
  await source.close();
  record('The source link opens its expected external page under the production policy');
  const fontState = await page.evaluate(async () => {
    await document.fonts.ready;
    return {
      dmSans: document.fonts.check('16px "DM Sans"'),
      spaceGrotesk: document.fonts.check('700 16px "Space Grotesk"'),
      loaded: Array.from(document.fonts)
        .filter((font) => font.status === 'loaded')
        .map((font) => font.family),
    };
  });
  assert.equal(fontState.dmSans, true);
  assert.equal(fontState.spaceGrotesk, true);
  assert.ok(fontState.loaded.some((family) => family.includes('DM Sans')));
  assert.ok(fontState.loaded.some((family) => family.includes('Space Grotesk')));
  record('Google Fonts stylesheet and both font families load successfully');
  await page.keyboard.press('Escape');
  await page.getByRole('button', { name: 'Dojavi događaj', exact: true }).first().click();
  await page.getByLabel(/Tvoja dojava/).fill('CSP public submission audit: koncert u Osijeku.');
  await page.getByRole('button', { name: 'Pošalji dojavu' }).click();
  await expect(page.getByRole('heading', { name: 'Dobra dojava. Hvala!' })).toBeVisible();
  record('The public submission dialog posts successfully to the same-origin API');

  if (production) {
    const eventResponse = await page.goto(`${base}/dogadaji/${eventId}`);
    assert.equal(eventResponse.status(), 200);
    assert.equal(eventResponse.headers()['cache-control'], 'no-store');
    assert.equal(eventResponse.headers()['content-security-policy'], PRODUCTION_CSP);
    await expect(page.getByRole('heading', { level: 1 })).toContainText('</script><img');
    await expect(page.locator('#security-xss-canary')).toHaveCount(0);
    const embedded = await page.evaluate(() => ({
      page: JSON.parse(document.getElementById('wagz-page-data').textContent),
      schema: JSON.parse(document.querySelector('script[type="application/ld+json"]').textContent),
    }));
    assert.equal(embedded.page.kind, 'event');
    assert.equal(embedded.schema.name, embedded.page.event.title);
    assert.ok(!Object.hasOwn(embedded.page.event, 'publication'));
    await page.reload();
    await expect(page.getByRole('heading', { level: 1 })).toContainText('</script><img');
    await page.getByRole('button', { name: 'Dojavi događaj', exact: true }).click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(page.locator('#security-xss-canary')).toHaveCount(0);
    record(
      'Direct event HTML, JSON-LD, hydration, refresh and dialog preserve hostile text under CSP',
    );
  }

  await page.goto(base + ADMIN_PATH);
  await page.getByLabel('Admin ključ').fill('incorrect-fixture-key');
  await page.getByRole('button', { name: 'Otvori uredništvo' }).click();
  await expect(page.getByRole('alert')).toContainText('nije ispravan');
  await expect(page.locator('.tip-card')).toHaveCount(0);
  record('Wrong administrator key stays on sign-in');

  const login = async () => {
    await page.getByLabel('Admin ključ').fill('fixture-admin-key');
    await page.getByRole('button', { name: 'Otvori uredništvo' }).click();
    await expect(page.getByRole('heading', { name: 'Grad pod kontrolom.' })).toBeVisible();
    await page.getByRole('button', { name: 'Čeka provjeru', exact: true }).click();
  };
  await login();
  await expect(page.getByText(/Security tip <\/textarea>/)).toBeVisible();
  await expect(page.locator('#security-xss-canary')).toHaveCount(0);
  await page
    .locator('article')
    .filter({ hasText: 'Security tip' })
    .getByRole('button', { name: /Uredi|Pregledaj|Otvori|Dopuni/ })
    .first()
    .click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
  record('The administrator review dialog opens and closes under the policy');
  // Only this newly created synthetic browser context is inspected.
  const storedCredential = await page.evaluate(() =>
    JSON.stringify([
      Object.entries(localStorage),
      Object.entries(sessionStorage),
      document.cookie,
    ]).includes('fixture-admin-key'),
  );
  assert.equal(storedCredential, false);
  record(
    'Admin tip text is escaped and the synthetic key is absent from local storage, session storage and cookies',
  );

  await page.reload();
  await expect(page.getByLabel('Admin ključ')).toBeVisible();
  await expect(page.getByLabel('Admin ključ')).toHaveValue('');
  await expect(page.getByText(/Security tip <\/textarea>/)).toHaveCount(0);
  record('Reload clears the operator session and private dashboard');

  await login();
  await page.getByRole('button', { name: 'Odjavi se' }).click();
  await expect(page.getByLabel('Admin ključ')).toHaveValue('');
  await expect(page.getByText(/Security tip <\/textarea>/)).toHaveCount(0);
  record('Logout clears the key input and private dashboard');

  await login();
  const fresh = await context.newPage();
  await fresh.goto(base + ADMIN_PATH);
  await expect(fresh.getByLabel('Admin ključ')).toBeVisible();
  await fresh.close();
  record('A new tab does not inherit the in-memory administrator session');

  rotateFixtureKey();
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(page.getByLabel('Admin ključ')).toBeVisible();
  await expect(page.getByText(/Security tip <\/textarea>/)).toHaveCount(0);
  record('A rejected refresh after key rotation clears private UI state');
  assert.deepEqual(errors, []);
  assert.deepEqual(violations, []);
  assert.deepEqual(fontFailures, []);
  record('Public, admin, dialogs and source flows finish with no CSP violations');
  const expectedBlockedProbes = [];
  if (production) {
    await page.evaluate(() => {
      const script = document.createElement('script');
      script.textContent = "document.documentElement.dataset.cspProbe = 'executed'";
      document.head.append(script);
    });
    await expect.poll(() => violations.length).toBe(1);
    assert.equal(await page.locator('html').getAttribute('data-csp-probe'), null);
    assert.equal(violations[0].directive, 'script-src-elem');
    assert.equal(violations[0].blockedURI, 'inline');
    expectedBlockedProbes.push(...violations.splice(0));
    record('An intentional inline-script probe is blocked by the enforced production CSP');
  }
  writeFileSync(
    resolve(directory, 'report.json'),
    JSON.stringify(
      {
        checkedAt: new Date().toISOString(),
        isolated: true,
        production,
        checks,
        errors,
        violations,
        fontFailures,
        fontState,
        expectedBlockedProbes,
      },
      null,
      2,
    ),
  );
  console.log(`Report: ${directory}`);
} finally {
  await browser?.close();
  await stop();
}
