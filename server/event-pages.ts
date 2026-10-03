import { readFile, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { createElement } from 'react';
import { renderToString } from 'react-dom/server';
import { EventPage, PublicApp } from '../src/App.tsx';
import { eventPath, publicSiteUrl } from '../shared/site.ts';
import type { PublicEvent, PublicPageData } from '../shared/types.ts';
import { upcoming } from './validation.ts';

const ROOT = '<div id="root"></div>';
const METADATA_START = '<!-- wagz:metadata:start -->';
const METADATA_END = '<!-- wagz:metadata:end -->';
const HOME_TITLE = 'Događaji u Osijeku | WagZ';
const HOME_DESCRIPTION =
  'Pronađi koncerte, predstave, radionice i druga događanja u Osijeku. Datumi, lokacije i izvorne najave na jednom mjestu.';

export function escapeMarkup(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]!,
  );
}

/** Non-executable script payloads must never be able to close their HTML element. */
export function scriptJson(value: unknown): string {
  return JSON.stringify(value).replace(
    /[<>&\u2028\u2029]/g,
    (character) => `\\u${character.charCodeAt(0).toString(16).padStart(4, '0')}`,
  );
}

/** Read the actual Vite output; never guess a hashed asset filename or fall back to an empty SPA. */
export async function readPageTemplate(directory: string): Promise<string> {
  const template = await readFile(join(directory, 'index.html'), 'utf8');
  for (const marker of [ROOT, METADATA_START, METADATA_END, '</head>', '</body>']) {
    if (template.split(marker).length !== 2) throw new Error('Invalid public page template.');
  }
  if (template.indexOf(METADATA_START) > template.indexOf(METADATA_END))
    throw new Error('Invalid public page metadata.');
  const assets = [
    ...template.matchAll(/<(?:script|link)\b[^>]*\b(?:src|href)="(\/assets\/[^"<>]+)"[^>]*>/g),
  ].map((match) => match[1]);
  if (!assets.some((asset) => asset.endsWith('.js')) || /["']\/src\//.test(template))
    throw new Error('Public build is unavailable.');
  for (const asset of assets) {
    if (
      !/^\/assets\/[a-zA-Z0-9_.-]+\.(?:js|css)$/.test(asset) ||
      !(await stat(join(directory, asset.slice(1)))).isFile()
    ) {
      throw new Error('Invalid public build asset.');
    }
  }
  return template;
}

/** Only announce facts already visible in the event. Unknown time/address/price stay unknown. */
export function eventStructuredData(event: PublicEvent, now: Date): Record<string, unknown> | null {
  if (!upcoming(event, now) || !event.venue) return null;
  return {
    '@context': 'https://schema.org',
    '@type': 'Event',
    name: event.title,
    ...(event.description ? { description: event.description } : {}),
    url: publicSiteUrl(eventPath(event.id)),
    startDate: event.startsAt,
    ...(event.endsAt ? { endDate: event.endsAt } : {}),
    eventStatus: `https://schema.org/${{ scheduled: 'EventScheduled', cancelled: 'EventCancelled', postponed: 'EventPostponed' }[event.status]}`,
    location: {
      '@type': 'Place',
      name: event.venue,
      address: {
        '@type': 'PostalAddress',
        ...(event.address ? { streetAddress: event.address } : {}),
        addressLocality: event.city,
        addressCountry: 'HR',
      },
    },
  };
}

export function renderPublicPage(template: string, page: PublicPageData): string {
  const event = page.kind === 'event' ? page.event : null;
  const title = event ? `${event.title} — WagZ` : HOME_TITLE;
  const description = event
    ? (
        event.description ||
        `${event.title} · ${event.venue || event.city} · ${event.startsAt.slice(0, 10)}. Detalji događaja i poveznice na izvore.`
      )
        .replace(/\s+/g, ' ')
        .slice(0, 180)
    : HOME_DESCRIPTION;
  const canonical = publicSiteUrl(event ? eventPath(event.id) : '/');
  const metadata = [
    `<title>${escapeMarkup(title)}</title>`,
    `<meta name="description" content="${escapeMarkup(description)}" />`,
    `<link rel="canonical" href="${escapeMarkup(canonical)}" />`,
    '<meta property="og:type" content="website" />',
    '<meta property="og:locale" content="hr_HR" />',
    '<meta property="og:site_name" content="WagZ" />',
    `<meta property="og:url" content="${escapeMarkup(canonical)}" />`,
    `<meta property="og:title" content="${escapeMarkup(title)}" />`,
    `<meta property="og:description" content="${escapeMarkup(description)}" />`,
    `<meta property="og:image" content="${publicSiteUrl('/share.png')}" />`,
    '<meta property="og:image:type" content="image/png" />',
    '<meta property="og:image:width" content="1200" />',
    '<meta property="og:image:height" content="630" />',
    '<meta property="og:image:alt" content="WagZ — Osijek, vidimo se vani. We Are Gen Z." />',
    '<meta name="twitter:card" content="summary_large_image" />',
  ].join('\n');
  const component =
    page.kind === 'feed'
      ? createElement(PublicApp, { initialFeed: page.feed })
      : createElement(EventPage, { event: page.event, now: page.now });
  const schema = page.kind === 'event' ? eventStructuredData(page.event, new Date(page.now)) : null;
  const data = `<script id="wagz-page-data" type="application/json">${scriptJson(page)}</script>${schema ? `<script type="application/ld+json">${scriptJson(schema)}</script>` : ''}`;
  return template
    .replace(/<!-- wagz:metadata:start -->[\s\S]*?<!-- wagz:metadata:end -->/, () => metadata)
    .replace(ROOT, () => `<div id="root">${renderToString(component)}</div>${data}`)
    .replace(/<noscript>[\s\S]*?<\/noscript>/g, '');
}

export function renderSitemap(events: PublicEvent[]): string {
  const entries = [
    `<url><loc>${publicSiteUrl('/')}</loc></url>`,
    ...events.map(
      (event) =>
        `<url><loc>${escapeMarkup(publicSiteUrl(eventPath(event.id)))}</loc><lastmod>${escapeMarkup(event.updatedAt)}</lastmod></url>`,
    ),
  ];
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${entries.join('')}</urlset>`;
}
