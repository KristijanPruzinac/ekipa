import {
  eventDurationText,
  isFeaturedEvent,
  isOngoing,
  rankForAudience,
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
// Stored source audience evidence never adds UI labels, alters chronology or hides events.
const events = [
  fixture('first', 'Izložba bez dobne oznake', '2026-10-03T08:00:00Z', 'culture', studentDiscovery),
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
  fixture(
    'student',
    'Studentska radionica',
    '2026-10-05T12:00:00Z',
    'community',
    studentDiscovery,
    {
      description: 'Program je namijenjen studentima. Izvorni opis ostaje prikazan.',
    },
  ),
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
  fixture('film', 'Filmska večer', '2026-10-14', 'film'),
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
const server = await createServer({
  envDir: false,
  server: {
    host: '127.0.0.1',
    port: 0,
    hmr: false,
    watch: {
      ignored: ['**/.artifacts/**', '**/apps/mobile/build/**', '**/dist/**', '**/.wagz-server/**'],
    },
  },
});
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
  const button = (name) =>
    page
      .getByRole('button', { name, exact: true })
      .or(page.getByRole('link', { name, exact: true }));
  const eventLink = (title, scope = cards) =>
    scope.getByRole('link', {
      name: new RegExp(
        `^(?:U tijeku\\. )?Detalji: ${title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\.`,
      ),
    });
  const chronological = () =>
    rankForAudience(currentFeed.events.filter(isFeaturedEvent)).map((row) => row.event);
  async function expectNoAudienceLabels(scope = page) {
    await expect(scope.locator('.card-audience')).toHaveCount(0);
    await expect(scope.getByText('Publika navedena u najavi', { exact: true })).toHaveCount(0);
    await expect(
      scope.getByText(/^(?:Studenti|Odrasli|Stariji)(?: · (?:Studenti|Odrasli|Stariji))*$/),
    ).toHaveCount(0);
  }
  async function expectCards() {
    const ranked = rankForAudience(currentFeed.events.filter(isFeaturedEvent));
    const ongoing = ranked.filter((row) => isOngoing(row.event, currentFeed.meta.now));
    const upcoming = ranked.filter((row) => !isOngoing(row.event, currentFeed.meta.now));
    await expect(cards).toHaveCount(upcoming.length);
    await expect(titles).toHaveText(upcoming.map((row) => row.event.title));
    await expect(page.locator('.card-duration')).toHaveText(
      upcoming.map((row) => eventDurationText(row.event)),
    );
    await expect(page.locator('.card-personal')).toHaveCount(0);
    await expectNoAudienceLabels();
    await expect(page.locator('.ongoing-event strong')).toHaveText(
      ongoing.slice(0, 2).map((row) => row.event.title),
    );
    if (ongoing.length > 2) await button(`Prikaži sve u tijeku (${ongoing.length})`).click();
    const allTitles = [
      ...(await titles.allTextContents()),
      ...(await page.locator('.ongoing-event strong').allTextContents()),
    ];
    expect(new Set(allTitles).size).toBe(currentFeed.events.filter(isFeaturedEvent).length);
    if (ongoing.length > 2) await button('Sažmi događaje u tijeku').click();
  }
  async function expectNoPhoneTimeline() {
    await expect(timeline).toHaveCount(0);
    await expect(
      page.locator('.timeline-mobile-toggle, .timeline-expand, .timeline-spine'),
    ).toHaveCount(0);
    await expect(page.getByRole('button', { name: /vremensku crtu|vremenska crta/i })).toHaveCount(
      0,
    );
    const first = page.locator('.card-feed');
    const layout = page.locator('.discovery-layout');
    expect((await first.boundingBox()).y).toBe((await layout.boundingBox()).y);
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
    if (Math.max(size.document, size.body) > size.viewport + 1) {
      console.log(
        'Overflow candidates',
        await page.evaluate(() =>
          [...document.querySelectorAll('body *')]
            .filter(
              (element) =>
                element.getBoundingClientRect().right > innerWidth + 1 &&
                getComputedStyle(element).position !== 'absolute',
            )
            .slice(0, 15)
            .map((element) => ({
              tag: element.tagName,
              class: element.className,
              right: element.getBoundingClientRect().right,
              text: element.textContent?.slice(0, 80),
            })),
        ),
      );
      await page.screenshot({ path: resolve(directory, `overflow-${width}.png`), fullPage: true });
    }
    expect(Math.max(size.document, size.body), `overflow at ${width}px`).toBeLessThanOrEqual(
      size.viewport + 1,
    );
  }
  await expectCards('all');
  await expectTimeline(6);
  const ongoingDetail = chronological().find((event) => isOngoing(event, currentFeed.meta.now));
  if (ongoingDetail) {
    await eventLink(ongoingDetail.title, page.locator('.ongoing-events')).click();
    await expect(page.locator('.detail-ongoing strong')).toHaveText('U tijeku');
    await expect(page.locator('.detail-ongoing')).toContainText(
      eventDurationText(ongoingDetail, currentFeed.meta.now),
    );
    if (ongoingDetail.endsAt.length === 10) {
      await expect(page.locator('.detail-ongoing')).toContainText('završni sat nije naveden');
    }
    await page.keyboard.press('Escape');
  }
  await cards.first().getByRole('link').click();
  await expect(page.locator('.detail-ongoing')).toHaveCount(0);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(cards.first().getByRole('link')).toBeFocused();
  // Starts still open details; the return endpoint is an informational date marker.
  const rangeEvent = chronological()
    .slice(0, 6)
    .find((event) => event.endsAt);
  if (rangeEvent) {
    const station = eventLink(rangeEvent.title, timeline);
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
    (event) => !isOngoing(event, currentFeed.meta.now) && event.discovery?.audienceEvidence?.length,
  );
  if (tagged) {
    await eventLink(tagged.title).click();
    await expectNoAudienceLabels(page.getByRole('dialog'));
    await expect(page.locator('dialog .event-description')).toHaveText(tagged.description);
    if (!tagged.discovery?.prominence)
      await expect(page.locator('dialog .detail-discovery')).toHaveCount(0);
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
      await expectNoPhoneTimeline();
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
    if (tagged) {
      const card = cards.filter({
        has: page.getByRole('heading', { name: tagged.title, exact: true }),
      });
      await expectNoAudienceLabels();
      await card.screenshot({ path: resolve(directory, `no-audience-card-${width}.png`) });
      await eventLink(tagged.title).click();
      await page
        .getByRole('dialog')
        .screenshot({ path: resolve(directory, `no-audience-detail-${width}.png`) });
      await expectNoAudienceLabels(page.getByRole('dialog'));
      await page.keyboard.press('Escape');
    }
    await page.evaluate(() => document.activeElement?.blur());
    await page.mouse.move(0, 0);
    await expectCards();
    if (width > 760) {
      await timeline.screenshot({
        path: resolve(directory, `${live ? 'live' : 'fixture'}-timeline-${width}.png`),
      });
      await button('Cijela vremenska crta').focus();
      await page.keyboard.press('Enter');
      await expectTimeline(currentFeed.events.filter(isFeaturedEvent).length);
      await noOverflow(width);
      await button('Prikaži manje').click();
    } else await expectNoPhoneTimeline();
  }
  if (!live) {
    // Isolated examples informed by KCO's separately announced dance workshops and
    // OLJK practical workshops; dates below are synthetic, never published/source edits.
    // https://kulturni-centar.hr/dogadjanja/otvorene-prijave-za-4-vikend-radionicu-suvremenog-plesa--radionica-plesne-improvizacije
    currentFeed = {
      ...fixtureFeed,
      events: [
        fixture(
          'dance-workshop',
          'Radionica plesne improvizacije',
          '2026-10-04T10:00:00+02:00',
          'dance',
          blankDiscovery,
          { endsAt: '2026-10-04T12:00:00+02:00' },
        ),
        fixture(
          'workshop',
          'Radionica keramike',
          '2026-10-04T11:00:00+02:00',
          'workshop',
          blankDiscovery,
          { endsAt: '2026-10-04T13:00:00+02:00' },
        ),
        fixture('dance-social', 'Salsa i bachata party', '2026-10-04T20:00:00+02:00', 'dance'),
      ],
    };
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: 1000 });
      await page.reload();
      await expectCards();
      const dance = cards.filter({ hasText: 'Radionica plesne improvizacije' });
      const workshop = cards.filter({ hasText: 'Radionica keramike' });
      await expect(dance).toHaveClass(/theme-dance/);
      await expect(workshop).toHaveClass(/theme-workshop/);
      await expect(dance.locator('[data-motif="dance"]')).toHaveCount(1);
      await expect(workshop.locator('[data-motif="workshop"]')).toHaveCount(1);
      await expect(dance.locator('.category-label')).toHaveText('Ples');
      await expect(workshop.locator('.category-label')).toHaveText('Radionica');
      await expect(
        cards.filter({ hasText: 'Salsa i bachata party' }).locator('.category-label'),
      ).toHaveText('Ples');
      await expect(dance.locator('.card-visual')).toHaveCSS(
        'background-color',
        'rgb(245, 220, 225)',
      );
      await expect(workshop.locator('.card-visual')).toHaveCSS(
        'background-color',
        'rgb(220, 231, 245)',
      );
      await dance.screenshot({ path: resolve(directory, `dance-card-${width}.png`) });
      await workshop.screenshot({ path: resolve(directory, `workshop-card-${width}.png`) });
      await eventLink('Radionica plesne improvizacije').click();
      await expect(page.locator('dialog .eyebrow').first()).toHaveText('Ples');
      await page.keyboard.press('Escape');
      if (width > 760) {
        await expectTimeline(3);
        await expect(timeline.locator('.timeline-legend span')).toHaveText(['Ples', 'Radionice']);
        await expect(timeline.locator('.timeline-range.theme-dance')).toHaveCount(1);
        await expect(timeline.locator('.timeline-range.theme-workshop')).toHaveCount(1);
        await timeline.screenshot({ path: resolve(directory, `category-timeline-${width}.png`) });
        const biggerLegend = await page.addStyleTag({
          content: '.timeline-legend { font-size: 22px; }',
        });
        await noOverflow(width);
        const legendBounds = await timeline.locator('.timeline-legend').boundingBox();
        for (const item of await timeline.locator('.timeline-legend span').all()) {
          const bounds = await item.boundingBox();
          expect(bounds.x + bounds.width).toBeLessThanOrEqual(
            legendBounds.x + legendBounds.width + 1,
          );
        }
        await timeline
          .locator('.timeline-legend')
          .screenshot({ path: resolve(directory, `category-legend-large-${width}.png`) });
        await biggerLegend.evaluate((element) => element.remove());
      } else await expectNoPhoneTimeline();
    }
    const activityFeed = {
      ...currentFeed,
      events: [
        ...currentFeed.events,
        fixture(
          'dance-ongoing',
          'Plesni susret u tijeku',
          '2026-10-03T09:00:00+02:00',
          'dance',
          blankDiscovery,
          { endsAt: '2026-10-03T18:00:00+02:00' },
        ),
        fixture(
          'workshop-ongoing',
          'Radionica u tijeku',
          '2026-10-03T08:00:00+02:00',
          'workshop',
          blankDiscovery,
          { endsAt: '2026-10-03T17:00:00+02:00' },
        ),
        fixture('community-filter', 'Susret zajednice', '2026-10-05', 'community'),
      ],
    };
    for (const width of [1440, 390, 320]) {
      currentFeed = activityFeed;
      await page.setViewportSize({ width, height: 1000 });
      await page.reload();
      const filters = page.getByRole('group', { name: 'Vrsta događaja' });
      await expect(filters.getByRole('button')).toHaveText([
        'Izdvojeno 6',
        'Ples 3',
        'Radionica 2',
        'Zajednica 1',
      ]);
      await expect(
        filters.getByRole('button', { name: 'Izdvojeno 6', exact: true }),
      ).toHaveAttribute('aria-pressed', 'true');
      await expectCards();
      const danceFilter = filters.getByRole('button', { name: 'Ples 3', exact: true });
      await danceFilter.focus();
      await page.keyboard.press('Enter');
      await expect(danceFilter).toHaveAttribute('aria-pressed', 'true');
      await expect(filters.locator('[aria-pressed="true"]')).toHaveCount(1);
      await expect(titles).toHaveText(['Radionica plesne improvizacije', 'Salsa i bachata party']);
      await expect(page.locator('.ongoing-event strong')).toHaveText(['Plesni susret u tijeku']);
      await expect(page.locator('.results-line')).toContainText('3 događaja');
      if (width > 760)
        await expect(stations.locator('strong')).toHaveText([
          'Plesni susret u tijeku',
          'Radionica plesne improvizacije',
          'Salsa i bachata party',
        ]);
      await noOverflow(width);
      await filters.screenshot({ path: resolve(directory, `activity-filters-${width}.png`) });
      await page.screenshot({
        path: resolve(directory, `dance-filtered-${width}.png`),
        fullPage: true,
      });
      await filters.getByRole('button', { name: 'Radionica 2', exact: true }).click();
      await expect(titles).toHaveText(['Radionica keramike']);
      await expect(page.locator('.ongoing-event strong')).toHaveText(['Radionica u tijeku']);
      if (width > 760)
        await expect(stations.locator('strong')).toHaveText([
          'Radionica u tijeku',
          'Radionica keramike',
        ]);
      await filters.getByRole('button', { name: 'Izdvojeno 6', exact: true }).click();
      await expectCards();
      await danceFilter.click();
      // A refreshed feed can remove the selected type: show zero and an explicit reset.
      currentFeed = {
        ...activityFeed,
        events: activityFeed.events.filter((event) => event.category !== 'dance'),
      };
      await page.evaluate(() => window.dispatchEvent(new Event('focus')));
      await expect(page.locator('.activity-empty')).toContainText(
        'Trenutno nema događaja vrste ples',
      );
      await expect(filters.getByRole('button')).toHaveText([
        'Izdvojeno 3',
        'Radionica 2',
        'Zajednica 1',
      ]);
      await expect(cards).toHaveCount(0);
      await expect(page.locator('.ongoing-event')).toHaveCount(0);
      await expect(stations).toHaveCount(0);
      await button('Prikaži izdvojeno').click();
      await expectCards();
      if (width === 320) {
        const enlarged = await page.addStyleTag({
          content:
            '.activity-filters button { font-size: 26px; } .activity-filters button span { font-size: 22px; }',
        });
        await noOverflow(width);
        await filters.screenshot({ path: resolve(directory, 'activity-filters-large-320.png') });
        await enlarged.evaluate((element) => element.remove());
      }
    }
    // Featured is conservative and city-agnostic; all films remain selectable.
    const screeningDiscovery = (kind) => ({
      ...blankDiscovery,
      screening: { kind, reason: 'Izvor potvrđuje kontekst projekcije.', sourceUrl },
    });
    const featuredFeed = {
      ...fixtureFeed,
      events: [
        fixture(
          'routine',
          'Redovni kino termin',
          '2026-10-04T17:00:00+02:00',
          'film',
          screeningDiscovery('routine'),
          { city: 'Zagreb' },
        ),
        fixture(
          'outdoor',
          'Kino na otvorenom',
          '2026-10-04T18:00:00+02:00',
          'film',
          screeningDiscovery('special'),
        ),
        fixture(
          'rooftop',
          'Rooftop filmska večer',
          '2026-10-05',
          'film',
          screeningDiscovery('special'),
          { city: 'Zagreb' },
        ),
        fixture('unknown-film', 'Projekcija bez potvrđenog konteksta', '2026-10-06', 'film'),
        fixture('other-event', 'Susret u susjedstvu', '2026-10-03', 'other'),
      ],
    };
    currentFeed = featuredFeed;
    await page.setViewportSize({ width: 390, height: 1000 });
    await page.reload();
    await expectCards();
    const featuredFilters = page.getByRole('group', { name: 'Vrsta događaja' });
    await expect(featuredFilters.getByRole('button')).toHaveText(['Izdvojeno 4', 'Film 4']);
    await expect(featuredFilters.getByRole('button', { name: /Ostalo|Sve/ })).toHaveCount(0);
    await expect(titles).toHaveText([
      'Susret u susjedstvu',
      'Kino na otvorenom',
      'Rooftop filmska večer',
      'Projekcija bez potvrđenog konteksta',
    ]);
    await expect(page.locator('.event-count')).toHaveAccessibleName('Izdvojeno, 4 događaja');
    await expectNoPhoneTimeline();
    await featuredFilters.getByRole('button', { name: 'Film 4', exact: true }).click();
    await expect(titles).toHaveText([
      'Redovni kino termin',
      'Kino na otvorenom',
      'Rooftop filmska večer',
      'Projekcija bez potvrđenog konteksta',
    ]);
    await expectNoPhoneTimeline();
    await eventLink('Redovni kino termin').click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await page.goBack();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(
      featuredFilters.getByRole('button', { name: 'Film 4', exact: true }),
    ).toHaveAttribute('aria-pressed', 'true');
    await featuredFilters.getByRole('button', { name: 'Izdvojeno 4', exact: true }).click();
    await expectCards();
    await noOverflow(390);
    await page.screenshot({ path: resolve(directory, 'featured-cinema-390.png'), fullPage: true });
    currentFeed = { ...featuredFeed, events: [featuredFeed.events[0]] };
    await page.reload();
    await expect(featuredFilters.getByRole('button')).toHaveText(['Izdvojeno 0', 'Film 1']);
    await expect(cards).toHaveCount(0);
    await expect(page.locator('.activity-empty')).toContainText(
      'Trenutno nema izdvojenih događaja.',
    );
    await button('Prikaži filmove').click();
    await expect(titles).toHaveText(['Redovni kino termin']);
    // New source-backed types retain distinct motifs, useful filter counts and
    // complete action names at 200% text size, including on a narrow phone.
    currentFeed = {
      ...fixtureFeed,
      events: [
        fixture(
          'film-accessible',
          'Projekcija dokumentarnog filma',
          '2026-10-04T18:00:00+02:00',
          'film',
          blankDiscovery,
          { endsAt: '2026-10-04T19:30:00+02:00' },
        ),
        fixture(
          'literature-accessible',
          'Književna večer i razgovor s autorom',
          '2026-10-05',
          'literature',
        ),
      ],
    };
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: 1000 });
      await page.reload();
      const textZoom = await page.addStyleTag({ content: 'html { font-size: 200%; }' });
      await expectCards();
      await noOverflow(width);
      const filters = page.getByRole('group', { name: 'Vrsta događaja' });
      await expect(filters.getByRole('button')).toHaveText([
        'Izdvojeno 2',
        'Film 1',
        'Književnost 1',
      ]);
      for (const category of ['film', 'literature']) {
        const card = cards.filter({ has: page.locator(`[data-motif="${category}"]`) });
        await expect(card).toHaveCount(1);
        await expect(card).toHaveClass(new RegExp(`theme-${category}`));
        await expect(card.locator('.card-open')).toHaveText('Detalji');
        await expect(card.getByRole('link')).toHaveAccessibleName(
          /Detalji: .*Testna lokacija.*Cijena nije navedena/,
        );
        await card.screenshot({
          path: resolve(directory, `${category}-card-text200-${width}.png`),
        });
      }
      if (width > 760) {
        await expectTimeline(2);
        await expect(timeline.locator('.timeline-legend span')).toHaveText(['Film', 'Književnost']);
        await timeline.screenshot({
          path: resolve(directory, `film-literature-timeline-text200-${width}.png`),
        });
      } else await expectNoPhoneTimeline();
      await noOverflow(width);
      await eventLink('Projekcija dokumentarnog filma').focus();
      await page.keyboard.press('Enter');
      await expect(page.getByRole('dialog')).toContainText('1 h 30 min');
      await noOverflow(width);
      await page
        .getByRole('dialog')
        .screenshot({ path: resolve(directory, `film-detail-text200-${width}.png`) });
      await page.keyboard.press('Escape');
      await filters.getByRole('button', { name: 'Književnost 1', exact: true }).click();
      await expect(titles).toHaveText(['Književna večer i razgovor s autorom']);
      if (width > 760)
        await expect(timeline.locator('.timeline-legend span')).toHaveText(['Književnost']);
      await textZoom.evaluate((element) => element.remove());
    }
    currentFeed = baseFeed;
    await page.reload();
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
  await page.setViewportSize({ width: 1440, height: 1100 });
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
  await page.setViewportSize({ width: 1440, height: 1100 });
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
  await eventLink('Višednevni program 3', page.locator('.ongoing-events')).click();
  await expect(page.getByRole('dialog')).toContainText('Višednevni program 3');
  await page.keyboard.press('Escape');
  await button('Sažmi događaje u tijeku').click();
  await eventLink('Kratki program').click();
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
    `Discovery passed (${live ? 'live data' : 'fixtures'}): chronology, audience labels absent with source descriptions preserved, activity filters, exact/date-only/unknown spans, shared spine, keyboard, ignored legacy preferences, refreshed details, film/literature motifs, complete accessible link names and 200% text, 320/390/1440px. Screenshots: ${directory}`,
  );
} finally {
  await browser?.close();
  await server.close();
}
