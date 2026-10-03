import {
  eventDurationText,
  isOngoing,
  rankForAudience,
  sourceAudienceLabels,
  timelineFor,
} from '../shared/discovery.ts';
import { chromium, expect } from '@playwright/test';
import { createServer } from 'vite';
import { existsSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// Default: isolated in-memory fixtures, no database/.env. --live reads the public feed only.
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
const studentDiscovery = {
  ...audienceDiscovery('students', 'Program je namijenjen studentima.'),
  audiences: ['students', 'seniors'],
  audienceEvidence: [
    ...audienceDiscovery('students', 'Program je namijenjen studentima.').audienceEvidence,
    ...audienceDiscovery('seniors', 'Najava poziva i starije osobe.').audienceEvidence,
  ],
};
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
// Source audience tags never alter chronology or hide unknown-audience/cancelled events.
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
// Durations include a multi-day ongoing range, an overlapping five-hour event, and unknown ends.
events[0].startsAt = '2026-10-02T18:00:00+02:00';
events[0].endsAt = '2026-10-04';
events[2].endsAt = '2026-10-04T03:15:00Z';
const fixtureFeed = {
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
const live = process.argv.includes('--live');
let currentFeed = live
  ? await (await fetch('https://wagz.vercel.app/api/events')).json()
  : fixtureFeed;
const baseFeed = currentFeed;
const server = await createServer({ envDir: false, server: { host: '127.0.0.1', port: 0 } });
let browser;
const failures = [];
let feedRequests = 0;
let failFeed = false;
try {
  await server.listen();
  const address = server.httpServer.address();
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
    if (
      route.request().method() === 'GET' &&
      new URL(route.request().url()).pathname === '/api/events'
    ) {
      feedRequests++;
      return route.fulfill(
        failFeed
          ? { status: 503, json: { error: 'Temporary test outage' } }
          : { json: currentFeed },
      );
    }
    failures.push(`Unexpected request: ${route.request().method()} ${route.request().url()}`);
    return route.abort();
  });
  const page = await context.newPage();
  page.on('pageerror', (error) => failures.push(error.message));
  await page.goto(`http://127.0.0.1:${address.port}`);
  const cards = page.locator('.event-card');
  const titles = page.locator('.event-card h3');
  const timeline = page.locator('.event-timeline');
  const stations = timeline.locator('.station-start');
  const button = (name) => page.getByRole('button', { name, exact: true });
  const chronological = () => rankForAudience(currentFeed.events).map((row) => row.event);
  async function expectCards() {
    const ranked = rankForAudience(currentFeed.events);
    const ongoing = ranked.filter((row) => isOngoing(row.event, currentFeed.meta.now));
    const upcoming = ranked.filter((row) => !isOngoing(row.event, currentFeed.meta.now));
    await expect(cards).toHaveCount(upcoming.length);
    await expect(titles).toHaveText(upcoming.map((row) => row.event.title));
    await expect(page.locator('.card-duration')).toHaveText(
      upcoming.map((row) => eventDurationText(row.event)),
    );
    await expect(page.locator('.card-personal')).toHaveCount(0);
    await expect(page.locator('.card-audience')).toHaveText(
      upcoming.flatMap(({ event }) => {
        const labels = sourceAudienceLabels(event);
        return labels.length ? [labels.join(' · ')] : [];
      }),
    );
    await expect(page.locator('.ongoing-event strong')).toHaveText(
      ongoing.slice(0, 2).map((row) => row.event.title),
    );
    if (ongoing.length > 2) await button(`Prikaži sve u tijeku (${ongoing.length})`).click();
    const allTitles = [
      ...(await titles.allTextContents()),
      ...(await page.locator('.ongoing-event strong').allTextContents()),
    ];
    expect(new Set(allTitles).size).toBe(currentFeed.events.length);
    if (ongoing.length > 2) await button('Sažmi događaje u tijeku').click();
  }
  async function expectTimeline(limit) {
    const visible = chronological().slice(0, limit);
    await expect(stations.locator('strong')).toHaveText(visible.map((event) => event.title));
    await expect(timeline.locator('.timeline-spine')).toHaveCount(1);
    await expect(timeline.locator('.timeline-rails')).toHaveCount(0);
    await expect(timeline.locator('.timeline-range')).toHaveCount(
      timelineFor(visible).ranges.length,
    );
    await expect(timeline.locator('.station-ending')).toHaveCount(
      timelineFor(visible).ranges.length,
    );
    await expect(timeline.locator('.timeline-symbols')).toContainText('Početak');
    await expect(timeline.locator('.timeline-symbols')).toContainText('Kraj');
    expect((await timeline.locator('.timeline-scale-note').boundingBox()).y).toBeLessThan(
      (await timeline.locator('.timeline-track').boundingBox()).y,
    );
    await expect(timeline.locator('.station-open')).toHaveCount(visible.length);
    const endings = timeline.locator('.station-ending');
    await expect(endings.locator('button, a, [tabindex]')).toHaveCount(0);
    await expect(
      endings.locator('.station-end-title, .station-end-label, .station-open'),
    ).toHaveCount(0);
    await expect(endings.locator('.station-end-context')).toHaveText(
      timelineFor(visible)
        .moments.filter((moment) => moment.ending)
        .map((moment) => `Završetak: ${moment.event.title}.`),
    );
    for (const ending of await endings.all()) {
      const row = await ending.boundingBox(),
        date = await ending.locator('time').boundingBox();
      expect(date.y + date.height).toBeLessThanOrEqual(row.y + row.height);
    }
  }
  async function noOverflow(width) {
    await page.setViewportSize({ width, height: width > 760 ? 1100 : 844 });
    await page.waitForTimeout(70);
    const size = await page.evaluate(() => ({
      document: document.documentElement.scrollWidth,
      body: document.body.scrollWidth,
      viewport: innerWidth,
    }));
    expect(Math.max(size.document, size.body), `overflow at ${width}px`).toBeLessThanOrEqual(
      size.viewport + 1,
    );
  }
  await expectCards('all');
  await expectTimeline(6);
  const ongoingDetail = chronological().find((event) => isOngoing(event, currentFeed.meta.now));
  if (ongoingDetail) {
    await button(`U tijeku: ${ongoingDetail.title}`).click();
    await expect(page.locator('.detail-ongoing strong')).toHaveText('U tijeku');
    await expect(page.locator('.detail-ongoing')).toContainText(
      eventDurationText(ongoingDetail, currentFeed.meta.now),
    );
    if (ongoingDetail.endsAt.length === 10) {
      await expect(page.locator('.detail-ongoing')).toContainText('završni sat nije naveden');
    }
    await page.keyboard.press('Escape');
  }
  await cards.first().getByRole('button').click();
  await expect(page.locator('.detail-ongoing')).toHaveCount(0);
  await page.keyboard.press('Escape');
  // Starts still open details; the return endpoint is an informational date marker.
  const rangeEvent = chronological()
    .slice(0, 6)
    .find((event) => event.endsAt);
  if (rangeEvent) {
    const station = button(`Na vremenskoj crti: ${rangeEvent.title}`);
    await station.focus();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('dialog')).toContainText(rangeEvent.title);
    await expect(page.getByRole('dialog')).toContainText('Do ');
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(station).toBeFocused();
    await expect(button(`Završetak: ${rangeEvent.title}`)).toHaveCount(0);
  }
  await expect(page.locator('.audience-picker')).toHaveCount(0);
  await expect(page.getByRole('textbox')).toHaveCount(0);
  await expect(page.getByRole('combobox')).toHaveCount(0);
  const tagged = chronological().find(
    (event) => !isOngoing(event, currentFeed.meta.now) && sourceAudienceLabels(event).length,
  );
  if (tagged) {
    await button(`Detalji: ${tagged.title}`).click();
    await expect(page.getByRole('dialog')).toContainText('Publika navedena u najavi');
    await expect(page.getByRole('dialog')).not.toContainText('Prijedlog za tebe');
    await page.keyboard.press('Escape');
  }
  if (!live) {
    await expect(timeline).toContainText('U TIJEKU');
    // Zagreb Sunday starts while the browser (Los Angeles) is still on Saturday.
    // Weekdays must also appear at real endpoints, including date-only endings.
    await expect(stations.locator('.station-weekday')).toHaveText([
      'pet',
      'sub',
      'ned',
      'ned',
      'ned',
      'pon',
    ]);
    await expect(timeline.locator('.station-ending .station-weekday')).toHaveText(['ned', 'ned']);
    await expect(timeline.locator('.station-duration')).toContainText([
      '02. 10. – 04. 10.',
      'Kraj nije naveden',
      '5 h',
      'Kraj nije naveden',
      'Kraj nije naveden',
      'Kraj nije naveden',
    ]);
  }
  for (const width of [1440, 390, 320]) {
    await noOverflow(width);
    if (width > 760) await expectTimeline(6);
    else {
      await expect(button('Otvori vremensku crtu')).toHaveAttribute('aria-expanded', 'false');
      await expect(stations).toHaveCount(0);
      expect((await timeline.boundingBox()).height).toBeLessThanOrEqual(80);
    }
    await page.screenshot({
      path: resolve(directory, `${live ? 'live' : 'fixture'}-${width}.png`),
      fullPage: true,
    });
    await page
      .locator('#dogadaji')
      .evaluate((element) => element.scrollIntoView({ block: 'start' }));
    await page.screenshot({
      path: resolve(directory, `${live ? 'live' : 'fixture'}-radar-${width}.png`),
    });
    if (width <= 760) {
      await button('Otvori vremensku crtu').focus();
      await page.keyboard.press('Enter');
      await expectTimeline(3);
    }
    if (tagged) {
      const card = cards.filter({
        has: page.getByRole('heading', { name: tagged.title, exact: true }),
      });
      await card.screenshot({ path: resolve(directory, `audience-card-${width}.png`) });
      await button(`Detalji: ${tagged.title}`).click();
      await page
        .getByRole('dialog')
        .screenshot({ path: resolve(directory, `audience-detail-${width}.png`) });
      await page.keyboard.press('Escape');
    }
    await page.evaluate(() => document.activeElement?.blur());
    await page.mouse.move(0, 0);
    await timeline.screenshot({
      path: resolve(directory, `${live ? 'live' : 'fixture'}-timeline-${width}.png`),
    });
    await expectCards();
    await button('Cijela vremenska crta').focus();
    await page.keyboard.press('Enter');
    await expectTimeline(currentFeed.events.length);
    await noOverflow(width);
    if (width === 320) {
      const largerLabels = await page.addStyleTag({
        content: '.station-ending .station-time > * { font-size: 160%; }',
      });
      await expectTimeline(currentFeed.events.length);
      await noOverflow(width);
      await largerLabels.evaluate((element) => element.remove());
    }
    await button('Prikaži manje').click();
    if (width <= 760) {
      await button('Zatvori vremensku crtu').click();
      await expect(stations).toHaveCount(0);
      await expect(button('Otvori vremensku crtu')).toHaveAttribute('aria-expanded', 'false');
    }
  }
  // Saved legacy preferences, including malformed data, never change the feed or add controls.
  for (const saved of [
    '{broken',
    JSON.stringify({ audience: 'students', interests: ['nightlife'] }),
    JSON.stringify({ audience: 'unknown', interests: ['music'] }),
  ]) {
    await page.evaluate(({ key, saved }) => localStorage.setItem(key, saved), {
      key: storageKey,
      saved,
    });
    await page.reload();
    await expectCards();
  }
  // A sparse unclassified feed stays visible without fabricated audience labels.
  currentFeed = {
    ...baseFeed,
    events: [fixture('unknown', 'Bez klasifikacije', '2026-10-04', 'other')],
  };
  await page.reload();
  await expectCards('students');
  await expect(page.locator('.card-audience')).toHaveCount(0);
  await expect(button('Cijela vremenska crta')).toHaveCount(0);
  await button('Otvori vremensku crtu').click();
  await expectTimeline(1);
  await expect(timeline.locator('.station-weekday')).toHaveText(['ned']);
  // The repeated hour during the Zagreb autumn clock change retains Sunday at both ends.
  currentFeed = {
    ...fixtureFeed,
    events: [
      fixture('dst', 'Promjena sata', '2026-10-24T22:30:00Z', 'music', blankDiscovery, {
        endsAt: '2026-10-25T01:30:00Z',
      }),
    ],
  };
  await page.reload();
  await button('Otvori vremensku crtu').click();
  await expectTimeline(1);
  await expect(timeline.locator('.station-weekday')).toHaveText(['ned', 'ned']);
  await expect(timeline.locator('.station-duration')).toContainText(['3 h']);
  // Compact ongoing rows retain every event; a real timed event moves at start/end.
  const timed = fixture(
    'timed',
    'Kratki program',
    '2026-10-03T12:01:00Z',
    'music',
    blankDiscovery,
    { endsAt: '2026-10-03T12:02:00Z' },
  );
  const ongoingFixtures = [1, 2, 3].map((index) =>
    fixture(
      `ongoing-${index}`,
      `Višednevni program ${index}`,
      '2026-10-02',
      'culture',
      blankDiscovery,
      { endsAt: '2026-10-04' },
    ),
  );
  currentFeed = {
    ...fixtureFeed,
    events: [...ongoingFixtures, timed],
    meta: { ...fixtureFeed.meta, now: '2026-10-03T12:00:30Z' },
  };
  await page.clock.install();
  await page.reload();
  await expectCards('all');
  await expect(titles).toHaveText(['Kratki program']);
  await expect(page.locator('.ongoing-event')).toHaveCount(2);
  await button('Prikaži sve u tijeku (3)').click();
  await expect(page.locator('.ongoing-event')).toHaveCount(3);
  await button('U tijeku: Višednevni program 3').click();
  await expect(page.getByRole('dialog')).toContainText('Višednevni program 3');
  await page.keyboard.press('Escape');
  await button('Sažmi događaje u tijeku').click();
  await button('Detalji: Kratki program').click();
  currentFeed = {
    ...currentFeed,
    events: currentFeed.events.map((event) =>
      event.id === 'timed' ? { ...event, venue: 'Novo mjesto' } : event,
    ),
    meta: { ...currentFeed.meta, now: '2026-10-03T12:01:30Z' },
  };
  await page.clock.fastForward(60001);
  await expect(cards).toHaveCount(0);
  await expect(page.getByRole('dialog')).toContainText('Novo mjesto');
  await expect(page.locator('.detail-ongoing')).toContainText('Danas do 14:02');
  await expect(button('Prikaži sve u tijeku (4)')).toBeVisible();
  failFeed = true;
  await page.clock.fastForward(60001);
  await expect(button('Prikaži sve u tijeku (4)')).toBeVisible();
  failFeed = false;
  currentFeed = {
    ...currentFeed,
    events: ongoingFixtures,
    meta: { ...currentFeed.meta, now: '2026-10-03T12:02:00Z' },
  };
  await page.clock.fastForward(60001);
  await expect(button('Prikaži sve u tijeku (3)')).toBeVisible();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  const beforeHidden = feedRequests;
  await page.evaluate(() => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'hidden' });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.fastForward(120001);
  expect(feedRequests).toBe(beforeHidden);
  await page.evaluate(() => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'visible' });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(() => feedRequests).toBe(beforeHidden + 1);
  expect(failures).toEqual([]);
  console.log(
    `Discovery passed (${live ? 'live data' : 'fixtures'}): chronology, source-only audience tags, source reasons, exact/date-only/unknown spans, shared spine, keyboard, ignored legacy preferences, refreshed details, 320/390/1440px. Screenshots: ${directory}`,
  );
} finally {
  await browser?.close();
  await server.close();
}
