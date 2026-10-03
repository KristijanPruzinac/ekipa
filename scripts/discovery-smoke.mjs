import { chromium, expect } from '@playwright/test';
import { createServer } from 'vite';
import { existsSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// Exercise the public interface against in-memory fixtures; no database or external API is used.
const directory = resolve('.artifacts', `discovery-${Date.now()}`);
mkdirSync(directory, { recursive: true });
const sourceUrl = 'https://kulturni-centar.hr/qa-discovery-fixture';
const blankDiscovery = { audiences: [], audienceEvidence: [], prominence: null, free: false };
const fixture = (id, title, startsAt, category, discovery = blankDiscovery) => ({
  id,
  title,
  startsAt,
  category,
  discovery,
  description: 'Izolirani primjer za provjeru prikaza.',
  venue: 'Testna lokacija',
  address: null,
  city: 'Osijek',
  endsAt: null,
  price: discovery.free ? 'Besplatan ulaz' : null,
  status: 'scheduled',
  publication: 'published',
  manuallyEdited: false,
  firstSeenAt: '2026-10-03T09:00:00Z',
  updatedAt: '2026-10-03T09:00:00Z',
  sources: [
    {
      sourceId: 'qa-source',
      sourceName: 'Testni izvor',
      url: sourceUrl,
      lastSeenAt: '2026-10-03T09:00:00Z',
    },
  ],
});
const events = [
  fixture('first', 'Izložba bez dobne oznake', '2026-10-03', 'culture'),
  fixture('festival', 'Glazbeni festival', '2026-10-04', 'music', {
    ...blankDiscovery,
    free: true,
    prominence: {
      kind: 'festival',
      label: 'Festival',
      reason: 'Najava navodi festivalski program.',
      sourceUrl,
    },
  }),
  fixture('student', 'Studentska radionica', '2026-10-05', 'community', {
    ...blankDiscovery,
    audiences: ['students'],
    audienceEvidence: [
      { audience: 'students', reason: 'Program je namijenjen studentima.', sourceUrl },
    ],
  }),
  fixture('cancelled', 'Otkazani studentski koncert', '2026-10-06', 'music', {
    ...blankDiscovery,
    audiences: ['students'],
    audienceEvidence: [
      { audience: 'students', reason: 'Program je namijenjen studentima.', sourceUrl },
    ],
  }),
];
events[3].status = 'cancelled';
const feed = {
  events,
  meta: {
    city: 'Osijek',
    timezone: 'Europe/Zagreb',
    now: '2026-10-03T09:00:00Z',
    lastCheckedAt: null,
    sourceCount: 1,
    totalUpcoming: events.length,
  },
};
const server = await createServer({ server: { host: '127.0.0.1', port: 0 } });
let browser;
const failures = [];
try {
  await server.listen();
  const address = server.httpServer.address();
  const base = `http://127.0.0.1:${address.port}`;
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
  await context.route('**/api/events', (route) => route.fulfill({ json: feed }));
  const page = await context.newPage();
  page.on('pageerror', (error) => failures.push(error.message));
  await page.goto(base);
  const cards = page.locator('.event-card');
  const titles = page.locator('.event-card h3');
  await expect(cards).toHaveCount(4);
  await expect(titles).toHaveText(events.map((event) => event.title));
  await expect(page.getByLabel('Redoslijed')).toHaveValue('date');
  await expect(page.locator('.card-personal')).toHaveCount(0);
  await expect(page.locator('.card-prominent')).toHaveCount(1);

  await page.getByRole('button', { name: 'Prilagodi sebi' }).click();
  await page.getByRole('radio', { name: 'Studenti i mladi' }).check();
  await expect(cards).toHaveCount(4);
  await expect(titles).toHaveText(events.map((event) => event.title));
  await expect(page.locator('.card-personal')).toHaveCount(1);
  await expect(page.locator('.card-personal')).toContainText('Studentska radionica');
  await page.locator('.interest-options').getByRole('button', { name: 'Glazba' }).click();
  await expect(page.locator('.card-personal')).toHaveCount(2);
  await page.getByLabel('Redoslijed').selectOption('personal');
  await expect(titles).toHaveText([
    events[2].title,
    events[1].title,
    events[0].title,
    events[3].title,
  ]);
  await expect(page.locator('.card-inactive')).not.toHaveClass(/card-personal|card-prominent/);
  await page.getByRole('button', { name: `Detalji: ${events[2].title}`, exact: true }).click();
  await expect(page.getByRole('region', { name: 'Razlozi oznaka' })).toContainText(
    'Program je namijenjen studentima.',
  );
  await expect(page.getByRole('link', { name: 'Provjeri u najavi' })).toHaveAttribute(
    'href',
    sourceUrl,
  );
  await page.keyboard.press('Escape');
  await page.screenshot({ path: resolve(directory, 'personalized-desktop.png'), fullPage: true });

  await page.reload();
  await expect(cards).toHaveCount(4);
  await expect(page.getByLabel('Redoslijed')).toHaveValue('date');
  await expect(titles).toHaveText(events.map((event) => event.title));
  await page.getByRole('button', { name: 'Promijeni odabir' }).click();
  await expect(page.getByRole('radio', { name: 'Studenti i mladi' })).toBeChecked();
  await expect(
    page.locator('.interest-options').getByRole('button', { name: 'Glazba' }),
  ).toHaveAttribute('aria-pressed', 'true');

  await page.getByRole('button', { name: 'Besplatan ulaz', exact: true }).click();
  await expect(titles).toHaveText([events[1].title]);
  await page.getByRole('button', { name: 'Danas', exact: true }).click();
  await expect(cards).toHaveCount(0);
  await expect(page.locator('.empty-state')).toContainText('potvrđenim besplatnim ulazom');
  await page.getByRole('button', { name: 'Ovaj vikend', exact: true }).click();
  await expect(titles).toHaveText([events[1].title]);
  await page.getByRole('button', { name: 'Očisti filtre', exact: true }).click();
  await expect(cards).toHaveCount(4);
  await expect(page.getByRole('radio', { name: 'Studenti i mladi' })).toBeChecked();

  await page.getByRole('radio', { name: 'Stariji', exact: true }).check();
  await expect(cards).toHaveCount(4);
  await expect(page.locator('.discovery-feedback')).toContainText(
    'nema posebno označenih programa',
  );
  await expect(page.locator('.card-personal')).toHaveCount(1);
  await page.setViewportSize({ width: 320, height: 800 });
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1);
  if (overflow) throw new Error('Personalization overflows a 320 px viewport.');
  await page.screenshot({ path: resolve(directory, 'personalized-mobile.png'), fullPage: true });
  await page.getByRole('button', { name: 'Poništi odabir', exact: true }).click();
  await expect(page.getByRole('radio', { name: 'Za sve', exact: true })).toBeChecked();
  await expect(page.locator('.card-personal')).toHaveCount(0);
  await expect(cards).toHaveCount(4);

  await page.evaluate(() => localStorage.setItem('wagz.discovery.preferences.v1', '{broken json'));
  await page.reload();
  await expect(cards).toHaveCount(4);
  await expect(page.locator('.card-personal')).toHaveCount(0);
  await page.evaluate(() =>
    localStorage.setItem(
      'wagz.discovery.preferences.v1',
      JSON.stringify({ audience: 'unknown', interests: ['music', 'music', 'unknown', null] }),
    ),
  );
  await page.reload();
  await expect(cards).toHaveCount(4);
  await page.getByRole('button', { name: 'Promijeni odabir' }).click();
  await expect(page.getByRole('radio', { name: 'Za sve', exact: true })).toBeChecked();
  await expect(page.locator('.interest-options button[aria-pressed="true"]')).toHaveCount(1);
  if (failures.length) throw new Error(`Browser errors: ${failures.join('; ')}`);
  console.log(
    `Discovery browser checks passed: optional audience/interests, chronological default, explainable ranking, source links, no hidden events, cancellation, free/date filters, local preference recovery, 320 px mobile. Screenshots: ${directory}`,
  );
} finally {
  await browser?.close();
  await server.close();
}
