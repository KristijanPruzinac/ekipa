import { chromium, expect } from '@playwright/test';
import { createServer } from 'vite';
import { existsSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// Exercise the public interface against in-memory fixtures. No database, .env or live API is used.
const directory = resolve('.artifacts', `discovery-${Date.now()}`);
mkdirSync(directory, { recursive: true });
const sourceUrl = 'https://kulturni-centar.hr/qa-discovery-fixture';
const storageKey = 'wagz.discovery.preferences.v1';
const blankDiscovery = { audiences: [], audienceEvidence: [], prominence: null, free: false };
const audienceDiscovery = (audience, reason) => ({
  ...blankDiscovery,
  audiences: [audience],
  audienceEvidence: [{ audience, reason, sourceUrl }],
});
const studentDiscovery = audienceDiscovery('students', 'Program je namijenjen studentima.');
const prominence = {
  kind: 'festival',
  label: 'Festival',
  reason: 'Najava navodi festivalski program.',
  sourceUrl,
};
const fixture = (id, title, startsAt, category, discovery = blankDiscovery, extra = {}) => ({
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
  ...extra,
});
// A sparse feed: each audience has just one confirmed match, across different categories.
// Selecting an audience must retain all 23 cards, including unknown-audience and cancelled events.
const events = [
  fixture('first', 'Izložba bez dobne oznake', '2026-10-03T08:00:00Z', 'culture'),
  fixture(
    'unverified',
    'Studentski susret bez potvrđene publike',
    '2026-10-03T20:00:00Z',
    'other',
    {
      ...blankDiscovery,
      audiences: ['students'],
    },
  ),
  fixture('midnight', 'Ponoćna šetnja', '2026-10-03T22:15:00Z', 'sport'),
  fixture('sunday', 'Nedjeljna predstava', '2026-10-04T08:00:00Z', 'theatre'),
  fixture('festival', 'Glazbeni festival', '2026-10-04T17:00:00Z', 'music', {
    ...blankDiscovery,
    free: true,
    prominence,
  }),
  fixture('student', 'Studentska radionica', '2026-10-05T12:00:00Z', 'community', studentDiscovery),
  fixture(
    'cancelled',
    'Otkazani studentski koncert',
    '2026-10-06T18:00:00Z',
    'music',
    { ...studentDiscovery, prominence },
    { status: 'cancelled' },
  ),
  fixture('gallery', 'Galerijska večer', '2026-10-07', 'culture'),
  fixture('jazz', 'Jazz četvrtkom', '2026-10-08', 'music'),
  fixture('dance', 'Studentska večer bez dobne oznake', '2026-10-09', 'nightlife'),
  fixture('bikes', 'Jesenska biciklijada', '2026-10-10', 'sport'),
  fixture('magic', 'Čarobna večer', '2026-10-11', 'theatre'),
  fixture('games', 'Društvene igre', '2026-10-12', 'community'),
  fixture(
    'lecture',
    'Otvoreno predavanje',
    '2026-10-13',
    'other',
    audienceDiscovery('adults', 'Predavanje je namijenjeno odraslima.'),
  ),
  fixture('film', 'Filmska večer', '2026-10-14', 'culture'),
  fixture('orchestra', 'Koncert orkestra', '2026-10-15', 'music'),
  fixture('stage', 'Mala pozornica', '2026-10-16', 'theatre'),
  fixture('running', 'Jutarnje trčanje', '2026-10-17', 'sport'),
  fixture(
    'records',
    'Večer vinila',
    '2026-10-18',
    'nightlife',
    audienceDiscovery('seniors', 'Večer je namijenjena starijim osobama.'),
  ),
  fixture('quiz', 'Kviz u susjedstvu', '2026-10-19', 'community'),
  fixture('fair', 'Sajam rukotvorina', '2026-10-20', 'other'),
  fixture('photos', 'Fotografije grada', '2026-10-21', 'culture'),
  fixture('choir', 'Koncert zbora', '2026-10-22', 'music'),
];
const chronologicalTitles = events.map((event) => event.title);
const feed = {
  // Deliberately shuffled: chronology must not rely on network response order.
  events: [...events.slice(10), ...events.slice(0, 10)],
  meta: {
    city: 'Osijek',
    timezone: 'Europe/Zagreb',
    now: '2026-10-03T09:00:00Z',
    lastCheckedAt: null,
    sourceCount: 1,
    totalUpcoming: events.length,
  },
};
const audienceLabels = ['Svi', 'Studenti', 'Odrasli', 'Stariji'];
let currentFeed = feed;
const server = await createServer({ envDir: false, server: { host: '127.0.0.1', port: 0 } });
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
  await context.route('**/api/**', (route) => {
    const request = route.request();
    if (request.method() === 'GET' && new URL(request.url()).pathname === '/api/events') {
      return route.fulfill({ json: currentFeed });
    }
    failures.push(`Unexpected API request: ${request.method()} ${new URL(request.url()).pathname}`);
    return route.abort();
  });
  const page = await context.newPage();
  page.on('pageerror', (error) => failures.push(error.message));
  await page.goto(base);
  const cards = page.locator('.event-card');
  const titles = page.locator('.event-card h3');
  const timeline = page.locator('.event-timeline');
  const stations = timeline.getByRole('button', { name: /^Na vremenskoj crti: / });
  const button = (name) => page.getByRole('button', { name, exact: true });
  const timelineTitles = () =>
    stations.evaluateAll((nodes) =>
      nodes.map((node) => node.getAttribute('aria-label').replace('Na vremenskoj crti: ', '')),
    );
  async function expectAllCards() {
    await expect(cards).toHaveCount(events.length);
    expect([...(await titles.allTextContents())].sort()).toEqual([...chronologicalTitles].sort());
    await expect(page.locator('.empty-state')).toHaveCount(0);
  }
  async function expectTimeline(expected = chronologicalTitles) {
    await expect(stations).toHaveCount(expected.length);
    expect(await timelineTitles()).toEqual(expected);
  }
  async function expectAudience(name) {
    for (const label of audienceLabels) {
      await expect(button(label)).toHaveAttribute('aria-pressed', String(label === name));
    }
  }
  async function expectNoOverflow(width) {
    await page.setViewportSize({ width, height: width === 1440 ? 1100 : 844 });
    const dimensions = await page.evaluate(() => ({
      document: document.documentElement.scrollWidth,
      body: document.body.scrollWidth,
      viewport: innerWidth,
    }));
    expect(
      Math.max(dimensions.document, dimensions.body),
      `Horizontal overflow at ${width}px`,
    ).toBeLessThanOrEqual(dimensions.viewport + 1);
  }
  await expectAllCards();
  await expect(titles).toHaveText(chronologicalTitles);
  await expectTimeline(chronologicalTitles.slice(0, 6));
  await expectAudience('Svi');
  await expect(page.locator('.card-personal')).toHaveCount(0);
  await expect(page.locator('.card-prominent')).toHaveCount(1);
  await expect(page.getByRole('textbox')).toHaveCount(0);
  await expect(page.getByRole('combobox')).toHaveCount(0);
  await expect(page.getByRole('radio')).toHaveCount(0);
  for (const name of [
    'Studenti i mladi',
    'Prilagodi preporuke',
    'Pretraži',
    'Besplatan ulaz',
    'Danas prvo',
    'Vikend prvo',
    'Glazba i izlasci',
    'Pozornica i kultura',
    'Pokret i druženje',
    'Glazba',
    'Noćni život',
    'Kazalište',
    'Kultura',
    'Sport',
    'Zajednica',
    'Ostalo',
  ]) {
    await expect(button(name)).toHaveCount(0);
  }
  await expectNoOverflow(1440);
  await page.screenshot({ path: resolve(directory, 'discovery-desktop.png'), fullPage: true });
  await page.locator('.audience-picker').scrollIntoViewIfNeeded();
  await page.screenshot({ path: resolve(directory, 'discovery-desktop-viewport.png') });
  await button('Cijela vremenska crta').click();
  await expectTimeline();

  // Source evidence moves one match to the front. Every other event keeps chronological order.
  // Student-like names, unverified audience labels, festival status and genre do not create matches.
  for (const [audience, eventIndex] of [
    ['Studenti', 5],
    ['Odrasli', 13],
    ['Stariji', 18],
  ]) {
    await button(audience).click();
    await expectAudience(audience);
    await expectAllCards();
    await expect(titles).toHaveText([
      events[eventIndex].title,
      ...chronologicalTitles.filter((title) => title !== events[eventIndex].title),
    ]);
    await expectTimeline();
    await expect(page.locator('.card-personal')).toHaveCount(1);
    await expect(page.locator('.card-personal')).toContainText(events[eventIndex].title);
    await expect(page.locator('.card-inactive')).not.toHaveClass(/card-personal|card-prominent/);
  }
  await button('Svi').focus();
  await page.keyboard.press('Space');
  await expectAudience('Svi');
  await expectAllCards();
  await expect(titles).toHaveText(chronologicalTitles);
  await expect(page.locator('.card-personal')).toHaveCount(0);
  await expectTimeline();

  // Both surfaces open the same source-backed details and restore keyboard focus on Escape.
  await button('Studenti').focus();
  await page.keyboard.press('Enter');
  for (const name of [`Detalji: ${events[5].title}`, `Na vremenskoj crti: ${events[5].title}`]) {
    const trigger = button(name);
    await trigger.focus();
    await page.keyboard.press('Enter');
    const dialog = page.getByRole('dialog', { name: events[5].title, exact: true });
    await expect(dialog).toBeVisible();
    await expect(dialog.getByRole('region', { name: 'Razlozi oznaka' })).toContainText(
      'Program je namijenjen studentima.',
    );
    await expect(dialog.getByRole('link', { name: 'Provjeri u najavi' })).toHaveAttribute(
      'href',
      sourceUrl,
    );
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(trigger).toBeFocused();
  }
  await page.reload();
  await expectAllCards();
  await expectAudience('Studenti');
  await expect(titles.first()).toHaveText(events[5].title);
  await expectTimeline(chronologicalTitles.slice(0, 6));
  await button('Svi').click();
  await page.reload();
  await expectAudience('Svi');
  await expect(titles).toHaveText(chronologicalTitles);

  // Keep the age selector and three-rail timeline usable on both common and very narrow phones.
  for (const width of [390, 320]) {
    await expectNoOverflow(width);
    await page.locator('.audience-picker').scrollIntoViewIfNeeded();
    await expectTimeline(chronologicalTitles.slice(0, 3));
    for (const label of audienceLabels) {
      const bounds = await button(label).boundingBox();
      expect(bounds.height).toBeGreaterThanOrEqual(48);
      expect(bounds.width).toBeGreaterThanOrEqual(44);
    }
    await page.screenshot({
      path: resolve(directory, `discovery-mobile-${width}.png`),
      fullPage: true,
    });
    await page.screenshot({ path: resolve(directory, `discovery-mobile-${width}-viewport.png`) });
    await button('Stariji').focus();
    await page.keyboard.press('Enter');
    await expectAudience('Stariji');
    await expect(titles.first()).toHaveText(events[18].title);
    await expectAllCards();
    await button('Cijela vremenska crta').focus();
    await page.keyboard.press('Enter');
    await expectTimeline();
    await expectNoOverflow(width);
    await button('Prikaži manje').focus();
    await page.keyboard.press('Enter');
    await expectTimeline(chronologicalTitles.slice(0, 3));
    await button('Svi').click();
  }

  // Recover malformed storage and retain only valid age choices from the previous profile shape.
  await page.evaluate((key) => localStorage.setItem(key, '{broken json'), storageKey);
  await page.reload();
  await expectAllCards();
  await expectAudience('Svi');
  await expect(titles).toHaveText(chronologicalTitles);
  await expect(page.locator('.card-personal')).toHaveCount(0);
  for (const stored of [
    { audience: 'unknown', interests: ['music', 'music', 'unknown', null] },
    { audience: 'students', interests: ['music', 'nightlife'] },
  ]) {
    await page.evaluate(({ key, value }) => localStorage.setItem(key, JSON.stringify(value)), {
      key: storageKey,
      value: stored,
    });
    await page.reload();
    await expectAllCards();
    const isStudent = stored.audience === 'students';
    await expectAudience(isStudent ? 'Studenti' : 'Svi');
    await expect(titles).toHaveText(
      isStudent
        ? [events[5].title, ...chronologicalTitles.filter((title) => title !== events[5].title)]
        : chronologicalTitles,
    );
    await expect(page.locator('.card-personal')).toHaveCount(isStudent ? 1 : 0);
    await expect(page.locator('.interest-options')).toHaveCount(0);
  }
  await button('Svi').click();
  await page.reload();
  await expectAudience('Svi');
  await expectAllCards();
  await expect(page.locator('.card-personal')).toHaveCount(0);
  // A small feed has no dead expansion button, and a choice with no evidence explains the fallback.
  currentFeed = { ...feed, events: events.slice(0, 3) };
  await page.reload();
  await button('Studenti').click();
  await expect(titles).toHaveText(chronologicalTitles.slice(0, 3));
  await expect(page.locator('.discovery-feedback')).toBeVisible();
  await expectTimeline(chronologicalTitles.slice(0, 3));
  await expect(button('Cijela vremenska crta')).toHaveCount(0);
  currentFeed = { ...feed, events: events.slice(0, 5) };
  await page.reload();
  await expectTimeline(chronologicalTitles.slice(0, 3));
  await button('Cijela vremenska crta').click();
  await expectTimeline(chronologicalTitles.slice(0, 5));
  await button('Prikaži manje').click();
  await expectNoOverflow(1440);
  await expectTimeline(chronologicalTitles.slice(0, 5));
  await expect(button('Cijela vremenska crta')).toHaveCount(0);
  if (failures.length) throw new Error(`Browser errors: ${failures.join('; ')}`);
  console.log(
    `Discovery browser checks passed: 23 retained events, four age choices, evidence-only audience ranking, independent chronology, cancellation, shared details, preference persistence/recovery, ignored legacy interests, keyboard, 320/390/1440 px layouts. Screenshots: ${directory}`,
  );
} finally {
  await browser?.close();
  await server.close();
}
