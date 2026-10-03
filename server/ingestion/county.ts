import { load } from 'cheerio';
import type { EventCandidate } from '../../shared/types.ts';
import { localDay, normalize } from '../validation.ts';
import { inferDiscovery } from '../discovery.ts';
import {
  candidate,
  categoryFor,
  clean,
  parseCalendarDate,
  synopsis,
  zagrebTime,
  type ExtractionPage,
  type ListingEntry,
} from './parsers.ts';
import { trustedSourceUrl } from './reader.ts';

export const COUNTY_URL = 'https://visitslavoniabaranja.com/dogadaji/';

function sourceDate(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}:\d{2})(?::00)?)?$/);
  if (!match) return null;
  const day = parseCalendarDate(`${match[3]}.${match[2]}.${match[1]}.`)?.start;
  if (!day || (match[4] && !/^([01]\d|2[0-3]):[0-5]\d$/.test(match[4]))) return null;
  return zagrebTime(day, match[4]);
}

/** Cards contain full ISO dates, including rows initially hidden by the site's filters. */
export function parseCountyListing(html: string, now = new Date()) {
  const $ = load(html);
  const container = $('#event-listing-view');
  const rows = container.children('[data-start]');
  if (!container.length || (!rows.length && !container.find('.js-events-empty').length))
    throw new Error('TZ OBŽ: struktura popisa događaja je promijenjena ili nedostaje.');
  const result = {
    entries: [] as ListingEntry[],
    discovered: rows.length,
    skipped: 0,
    warnings: [] as string[],
  };
  const seen = new Set<string>();
  rows.each((_index, element) => {
    const row = $(element);
    const link = row.find('a.c-btn--card').first();
    const title = clean(link.text());
    const start = sourceDate(row.attr('data-start'));
    const endRaw = row.attr('data-end');
    const end = endRaw ? sourceDate(endRaw) : null;
    if (!title || !start || (endRaw && !end) || (end && end < start)) {
      result.skipped++;
      result.warnings.push(`TZ OBŽ: nečitljiv naslov ili datum: ${title || '(bez naslova)'}.`);
      return;
    }
    // The destination also contains Dalj and Erdut. Confirm the city on the detail page.
    if (
      (end ?? start) < localDay(now) ||
      (row.attr('data-destination') && row.attr('data-destination') !== 'osijek_i_podunavlje')
    ) {
      result.skipped++;
      return;
    }
    let url: string;
    try {
      url = trustedSourceUrl(link.attr('href') ?? '', COUNTY_URL);
      const parsed = new URL(url);
      if (
        parsed.hostname.replace(/^www\./, '') !== 'visitslavoniabaranja.com' ||
        !/^\/event\/[^/]+\/$/.test(parsed.pathname) ||
        parsed.search
      )
        throw new Error('Neispravna poveznica detalja.');
    } catch {
      result.skipped++;
      result.warnings.push(`TZ OBŽ: nepouzdana poveznica za „${title}”.`);
      return;
    }
    if (seen.has(url)) {
      result.skipped++;
      return;
    }
    seen.add(url);
    result.entries.push({
      title,
      url,
      startsAt: start,
      endsAt: end && end !== start ? end : null,
      dateText: `${start}${end && end !== start ? ` – ${end}` : ''}`,
    });
  });
  result.entries.sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  return result;
}

type JsonObject = Record<string, unknown>;
function object(value: unknown): JsonObject | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? (value as JsonObject) : null;
}

function eventNodes(value: unknown): JsonObject[] {
  if (Array.isArray(value)) return value.flatMap(eventNodes);
  const node = object(value);
  if (!node) return [];
  const types = Array.isArray(node['@type']) ? node['@type'] : [node['@type']];
  return types.some(
    (type) => typeof type === 'string' && /^(?:https?:\/\/schema\.org\/)?Event$/.test(type),
  )
    ? [node]
    : eventNodes(node['@graph']);
}

// This WordPress source leaves HTML entities inside JSON-LD names and addresses.
const field = (value: unknown) =>
  typeof value === 'string' ? clean(load(value, undefined, false).text()) : '';

export function parseCountyDetail(
  html: string,
  entry: ListingEntry,
  now = new Date(),
): { event: EventCandidate | null; extraction: ExtractionPage | null; warnings: string[] } {
  const $ = load(html);
  const content = $('.c-event__content').first();
  const title = clean(content.find('h1').first().text());
  if (!title) throw new Error(`TZ OBŽ: nedostaje sadržaj događaja ${entry.url}.`);
  const nodes: JsonObject[] = [];
  $('script[type="application/ld+json"]').each((_index, element) => {
    try {
      nodes.push(...eventNodes(JSON.parse($(element).text())));
    } catch {
      /* A malformed SEO script must not hide another valid Event script. */
    }
  });
  const matches = nodes.filter((node) => normalize(field(node.name)) === normalize(title));
  if (matches.length !== 1)
    throw new Error(`TZ OBŽ: nedostaje jednoznačan strukturirani događaj ${entry.url}.`);
  const node = matches[0];
  const location = object(node.location) ?? object(node.Location);
  const address = object(location?.address);
  const sidebarCity = clean($('.c-aside .c-info-tag').has('.u-icon--location').find('span').text());
  const structuredCity = field(address?.addressLocality);
  if (sidebarCity && structuredCity && normalize(sidebarCity) !== normalize(structuredCity))
    throw new Error(`TZ OBŽ: neusklađen grad događaja ${entry.url}.`);
  const city = sidebarCity || structuredCity;
  const warnings: string[] = [];
  if (!city) warnings.push(`TZ OBŽ: nije potvrđen grad za „${title}”; stavka nije uvezena.`);
  if (normalize(city) !== 'osijek') return { event: null, extraction: null, warnings };
  let startsAt = sourceDate(node.startDate);
  let endsAt = node.endDate ? sourceDate(node.endDate) : null;
  if (!startsAt || (node.endDate && !endsAt) || (endsAt && endsAt < startsAt))
    throw new Error(`TZ OBŽ: neispravan strukturirani datum za „${title}”.`);
  // The site's unfilled time fields render as 00:00–00:00 (e.g. Green Matrix Summit).
  // Preserve the known dates without presenting that placeholder as a real schedule.
  if (startsAt.includes('T00:00:00') && endsAt?.includes('T00:00:00')) {
    startsAt = startsAt.slice(0, 10);
    endsAt = endsAt.slice(0, 10);
  }
  // Multi-day cards expose recurring daily hours, not a confirmed final-day closing time.
  if (endsAt && endsAt.slice(0, 10) !== startsAt.slice(0, 10)) endsAt = endsAt.slice(0, 10);
  if ((endsAt ?? startsAt).slice(0, 10) < localDay(now))
    return { event: null, extraction: null, warnings };
  if (startsAt.slice(0, 10) !== entry.startsAt.slice(0, 10))
    warnings.push(
      `TZ OBŽ: detalj navodi drukčiji datum od popisa za „${title}”; koristi se detalj.`,
    );
  const article = content.children('div').not('.c-event__info').first().clone();
  article.find('script,style,noscript').remove();
  article.find('br').replaceWith('\n');
  const body = article
    .find('p,li')
    .map((_index, element) => clean($(element).text()))
    .get()
    .filter(Boolean)
    .join('\n');
  if (!body) throw new Error(`TZ OBŽ: prazan tekst događaja ${entry.url}.`);
  const event = candidate(
    'tz-obz',
    entry.url,
    new URL(entry.url).pathname,
    title,
    startsAt,
    endsAt,
    body,
  );
  event.venue =
    clean($('.c-aside .c-info-tag').has('.u-icon--building').find('span').text()) ||
    field(location?.name) ||
    null;
  event.address = field(address?.streetAddress) || field(location?.address) || null;
  const categories = content
    .find('.c-event__info__type a')
    .map((_index, element) => $(element).text())
    .get()
    .join(' ');
  event.category = categoryFor(`${title} ${categories}`, title);
  // Only explicit admission metadata establishes a free event; free subprograms do not.
  const offer = object(node.offers);
  if (node.isAccessibleForFree === true || (offer && (offer.price === 0 || offer.price === '0')))
    event.price = 'Besplatno';
  const status = field(node.eventStatus).replace(/^https?:\/\/schema\.org\//, '');
  if (status === 'EventCancelled') event.status = 'cancelled';
  else if (status === 'EventPostponed') event.status = 'postponed';
  event.description = synopsis(event);
  event.classificationText = `${categories}\n${body}`;
  event.discovery = inferDiscovery(title, body, entry.url, event.price);
  const extraction =
    !event.venue || !event.price || event.category === 'other'
      ? {
          url: entry.url,
          text: `Naslov: ${title}\nDatum početka iz izvora: ${startsAt}\nDatum završetka iz izvora: ${endsAt ?? 'nije naveden'}\nGrad iz izvora: ${city}\nMjesto iz izvora: ${event.venue ?? 'nije navedeno'}\n\n${body}`,
        }
      : null;
  return { event, extraction, warnings };
}
