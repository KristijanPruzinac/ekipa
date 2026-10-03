import { chromium, expect } from '@playwright/test';
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';

// Real browser interaction in an isolated copy: never publishes QA content to the app database.
const runId = Date.now().toString();
const directory = resolve('.artifacts', `smoke-${runId}`);
mkdirSync(directory, { recursive: true });
const database = resolve(directory, 'qa.sqlite');
if (existsSync('data/wagz.sqlite')) copyFileSync('data/wagz.sqlite', database);
const key = randomBytes(32).toString('hex');
const port = process.env.WAGZ_SMOKE_PORT || '3001';
const base = `http://127.0.0.1:${port}`;
const child = spawn(process.execPath, ['--import', 'tsx', 'server/index.ts', '--production'], {
  cwd: process.cwd(),
  windowsHide: true,
  stdio: ['ignore', 'pipe', 'pipe'],
  env: {
    ...process.env,
    HOST: '127.0.0.1',
    PORT: port,
    WAGZ_DATABASE_PATH: database,
    WAGZ_ADMIN_KEY: key,
    WAGZ_FETCH_ON_START: 'false',
    OPENROUTER_API_KEY: '',
  },
});
let serverOutput = '';
child.stdout.on('data', (chunk) => {
  serverOutput += chunk;
});
child.stderr.on('data', (chunk) => {
  serverOutput += chunk;
});
let browser;
const failures = [];
try {
  let ready = false;
  for (let attempt = 0; attempt < 80; attempt++) {
    try {
      if ((await fetch(`${base}/api/health`)).ok) {
        ready = true;
        break;
      }
    } catch {
      /* Startup is asynchronous. */
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  if (!ready) throw new Error(`Test server failed to start: ${serverOutput}`);
  const chrome =
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ||
    'C:/Program Files/Google/Chrome/Application/chrome.exe';
  browser = await chromium.launch({
    headless: true,
    ...(existsSync(chrome) ? { executablePath: chrome } : {}),
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
    timezoneId: 'America/Los_Angeles',
  });
  const page = await context.newPage();
  page.on('pageerror', (error) => failures.push(error.message));
  await page.goto(base);
  await expect(page.getByRole('heading', { name: /Osijek,.*vidimo se vani\./ })).toBeVisible();
  await expect(page.locator('.feed-loading')).toHaveCount(0);
  const realCount = await page.locator('.event-card').count();
  await page.screenshot({ path: resolve(directory, 'desktop.png'), fullPage: true });
  if (realCount) {
    await page.locator('.event-card-button').first().click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await expect(page.locator('.source-link').first()).toHaveAttribute('href', /^https:\/\//);
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toHaveCount(0);
  }
  await page.getByRole('textbox', { name: 'Pretraži događaje' }).fill('zzzz-no-such-event');
  await expect(page.getByRole('heading', { name: 'Ovdje je zasad mirno.' })).toBeVisible();
  await page.getByRole('button', { name: 'Prikaži sve događaje' }).click();
  await expect(page.locator('.event-card')).toHaveCount(realCount);
  await page.getByRole('button', { name: 'Dojavi događaj', exact: true }).first().click();
  const note = `QA provjera sučelja ${runId}, bez stvarne objave u aplikaciji.`;
  await page.getByLabel(/Tvoja dojava/).fill(note);
  await page.getByRole('button', { name: 'Pošalji dojavu' }).click();
  await expect(page.getByRole('heading', { name: 'Dobra dojava. Hvala!' })).toBeVisible();
  await page.getByRole('button', { name: 'Natrag na događaje' }).click();
  const junk = 'z'.repeat(32);
  await context.request.post(`${base}/api/tips`, { data: { note: junk } });
  await page.goto(`${base}/admin`);
  await page.getByLabel('Admin ključ').fill('incorrect-test-key');
  await page.getByRole('button', { name: 'Otvori uredništvo' }).click();
  await expect(page.getByRole('alert')).toContainText('nije ispravan');
  await page.getByLabel('Admin ključ').fill(key);
  await page.getByRole('button', { name: 'Otvori uredništvo' }).click();
  await expect(page.getByRole('heading', { name: 'Grad pod kontrolom.' })).toBeVisible();
  await page.getByRole('button', { name: 'Arhiva', exact: true }).click();
  const archived = page.locator('article').filter({ hasText: junk });
  await expect(archived).toBeVisible();
  await archived.getByRole('button', { name: 'Vrati na pregled' }).click();
  await expect(archived).toHaveCount(0);
  await page.getByRole('button', { name: 'Za pregled', exact: true }).click();
  await expect(page.locator('article').filter({ hasText: junk })).toBeVisible();
  const row = page.locator('article').filter({ hasText: note });
  await expect(row).toBeVisible();
  await row
    .getByRole('button', { name: /Uredi|Pregledaj|Otvori|Dopuni/ })
    .first()
    .click();
  await page.getByLabel('Naziv događaja', { exact: true }).fill(`QA događaj ${runId}`);
  await page.getByLabel('Datum početka', { exact: true }).fill('2099-10-10');
  await page.getByLabel('Mjesto održavanja', { exact: true }).fill('Testna lokacija');
  await page.getByRole('button', { name: 'Prihvati i objavi' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByRole('status')).toContainText('prihvaćena');
  await page.getByRole('button', { name: /^Izvori/ }).click();
  const toggle = page.getByRole('checkbox', { name: 'Automatska objava prikupljenih događaja' });
  const wasChecked = await toggle.isChecked();
  await toggle.click();
  await expect(toggle).toBeChecked({ checked: !wasChecked });
  await page.reload();
  await expect(page.getByLabel('Admin ključ')).toBeVisible();
  await page.getByLabel('Admin ključ').fill(key);
  await page.getByRole('button', { name: 'Otvori uredništvo' }).click();
  await page.getByRole('button', { name: /^Izvori/ }).click();
  await expect(
    page.getByRole('checkbox', { name: 'Automatska objava prikupljenih događaja' }),
  ).toBeChecked({ checked: !wasChecked });
  await page.screenshot({ path: resolve(directory, 'admin.png'), fullPage: true });
  await page.goto(base);
  await page.getByRole('textbox', { name: 'Pretraži događaje' }).fill(`QA događaj ${runId}`);
  await expect(page.locator('.event-card')).toHaveCount(1);
  const mobile = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    deviceScaleFactor: 1,
    timezoneId: 'Europe/Zagreb',
  });
  const phone = await mobile.newPage();
  phone.on('pageerror', (error) => failures.push(error.message));
  await phone.goto(base);
  await expect(phone.locator('.feed-loading')).toHaveCount(0);
  const overflow = await phone.evaluate(
    () => document.documentElement.scrollWidth > window.innerWidth + 1,
  );
  if (overflow) throw new Error('Mobile page overflows horizontally.');
  await phone.screenshot({ path: resolve(directory, 'mobile.png'), fullPage: true });
  await phone.screenshot({ path: resolve(directory, 'mobile-viewport.png') });
  await phone.getByRole('button', { name: 'Dojavi događaj', exact: true }).first().click();
  await expect(phone.getByRole('dialog')).toBeVisible();
  await expect(phone.getByRole('button', { name: 'Pošalji dojavu' })).toBeVisible();
  if (failures.length) throw new Error(`Browser errors: ${failures.join('; ')}`);
  console.log(
    `Browser checks passed: ${realCount} real events, detail dialog, search, tip, spam restore, admin auth, approval, persistent publish toggle, mobile layout. Screenshots: ${directory}`,
  );
} finally {
  await browser?.close();
  child.kill();
}
