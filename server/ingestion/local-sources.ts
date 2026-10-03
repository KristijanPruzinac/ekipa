import { load } from 'cheerio';
import type { EventCandidate, SourceDefinition } from '../../shared/types.ts';
import { inferDiscovery } from '../discovery.ts';
import { localDay, normalize } from '../validation.ts';
import {
  candidate,
  categoryFor,
  clean,
  parseCalendarDate,
  synopsis,
  zagrebTime,
} from './parsers.ts';
import { trustedSourceUrl } from './reader.ts';

export const localSources: SourceDefinition[] = [
  {
    id: 'gisko',
    name: 'Gradska i sveučilišna knjižnica Osijek',
    url: 'https://www.gskos.unios.hr/',
    description:
      'Tekstualne najave knjižnice i ogranaka, s izričitim datumom i uvjetima sudjelovanja.',
    enabled: true,
  },
  {
    id: 'hnk-osijek',
    name: 'Hrvatsko narodno kazalište u Osijeku',
    url: 'https://hnk-osijek.hr/',
    description:
      'Pojedinačne izvedbe iz službenog rasporeda; gostovanja izvan Osijeka se isključuju.',
    enabled: true,
  },
  {
    id: 'coreevent-osijek',
    name: 'CoreEvent — Osijek',
    url: 'https://core-event.co/city/osijek/',
    description: 'Organizatorske najave i zasebni termini ulaznica s potvrđenim gradom Osijekom.',
    enabled: true,
  },
  {
    id: 'dkolektiv',
    name: 'DKolektiv',
    url: 'https://www.dkolektiv.hr/hr/news',
    description:
      'Javni pozivi i datirane radionice, uključujući Volonterski centar; slikovni rasporedi čekaju provjeru.',
    enabled: true,
  },
];

export interface LocalEntry {
  url: string;
  title: string;
  startsAt?: string;
  genre?: string;
}
export interface LocalListing {
  entries: LocalEntry[];
  discovered: number;
  skipped: number;
  warnings: string[];
  nextPageUrl?: string;
}
export interface LocalDetail {
  events: EventCandidate[];
  warnings: string[];
  reviewExternalIds: string[];
}
const months = [
  'sijecnja',
  'veljace',
  'ozujka',
  'travnja',
  'svibnja',
  'lipnja',
  'srpnja',
  'kolovoza',
  'rujna',
  'listopada',
  'studenoga',
  'prosinca',
];
const monthPattern = months.join('|');
const plain = (text: string) =>
  text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

/** Only the event's own explicit year counts. Article, copyright and current years do not. */
export function explicitDates(text: string): string[] {
  const value = plain(text);
  const found: Array<{ at: number; dates: string[] }> = [];
  const named = new RegExp(
    `(?:(\\d{1,2})\\.\\s*(?:i|,)\\s*)?(\\d{1,2})\\.\\s*(${monthPattern})\\s+(20\\d{2})\\.?`,
    'g',
  );
  for (const match of value.matchAll(named)) {
    const month = months.indexOf(match[3]) + 1;
    found.push({
      at: match.index!,
      dates: [match[1], match[2]].filter(Boolean).flatMap((day) => {
        const parsed = parseCalendarDate(`${day}.${month}.${match[4]}.`);
        return parsed ? [parsed.start] : [];
      }),
    });
  }
  for (const match of value.matchAll(
    /(?:(\d{1,2})\.\s*(?:i|,)\s*)?(\d{1,2})\.\s*(\d{1,2})\.\s*(20\d{2})\.?/g,
  )) {
    found.push({
      at: match.index!,
      dates: [match[1], match[2]].filter(Boolean).flatMap((day) => {
        const parsed = parseCalendarDate(`${day}.${match[3]}.${match[4]}.`);
        return parsed ? [parsed.start] : [];
      }),
    });
  }
  return [...new Set(found.sort((a, b) => a.at - b.at).flatMap((item) => item.dates))];
}

function clock(text: string): string | undefined {
  const match = text.match(/\b([01]?\d|2[0-3])[:.]([0-5]\d)(?![\d.])/);
  if (match) return `${match[1].padStart(2, '0')}:${match[2]}`;
  const hour = text.match(/\b(?:u|od)\s+([01]?\d|2[0-3])\s*(?:h\b|sati\b)/i);
  return hour ? `${hour[1].padStart(2, '0')}:00` : undefined;
}

function detailUrl(raw: string, source: SourceDefinition): string {
  const url = trustedSourceUrl(raw.trim(), source.url);
  const parsed = new URL(url);
  if (
    parsed.hostname.replace(/^www\./, '') !== new URL(source.url).hostname.replace(/^www\./, '') ||
    parsed.search
  )
    throw new Error('Poveznica detalja ne pripada izvoru.');
  const paths: Record<string, RegExp> = {
    gisko: /^\/index\.php\/[^/]+\/$/,
    'hnk-osijek': /^\/show\/[^/]+\/$/,
    'coreevent-osijek': /^\/events\/[^/]+\/$/,
    dkolektiv: /^\/hr\/posts\/[^/]+\/?$/,
  };
  if (!paths[source.id].test(parsed.pathname)) throw new Error('Neispravna putanja detalja.');
  return url;
}

export function parseLocalListing(
  id: string,
  html: string,
  now = new Date(),
  pageUrl?: string,
): LocalListing {
  const source = localSources.find((item) => item.id === id)!;
  const $ = load(html);
  const result: LocalListing = { entries: [], discovered: 0, skipped: 0, warnings: [] };
  const seen = new Set<string>();
  const add = (raw: string, title: string, startsAt?: string, genre?: string) => {
    result.discovered++;
    try {
      const url = detailUrl(raw, source);
      const key = `${url}|${startsAt ?? ''}`;
      if (!title || seen.has(key) || (startsAt && startsAt.slice(0, 10) < localDay(now))) {
        result.skipped++;
        return;
      }
      seen.add(key);
      result.entries.push({ url, title, startsAt, genre });
    } catch {
      result.skipped++;
      result.warnings.push(`${source.name}: nepouzdana poveznica „${title}”.`);
    }
  };
  if (id === 'gisko') {
    const links = $('.td-module-title a');
    if (!links.length) throw new Error('GISKO: nedostaje struktura najava.');
    links.each((_i, el) =>
      add($(el).attr('href') ?? '', clean($(el).attr('title') || $(el).text())),
    );
  } else if (id === 'dkolektiv') {
    const links = $('.title a[href*="/hr/posts/"]');
    if (!links.length) throw new Error('DKolektiv: nedostaje struktura novosti.');
    links.each((_i, el) => add($(el).attr('href') ?? '', clean($(el).text())));
    const next = $('.pagination a[rel="next"]').first().attr('href');
    if (next) {
      const url = new URL(trustedSourceUrl(next, pageUrl ?? source.url));
      if (
        url.origin === new URL(source.url).origin &&
        url.pathname === '/hr/news' &&
        /^\?page=\d+$/.test(url.search)
      )
        result.nextPageUrl = url.href;
    }
  } else if (id === 'hnk-osijek') {
    const rows = $('.slider--schedule__item');
    if (!rows.length) throw new Error('HNK: nedostaje raspored izvedbi.');
    rows.each((_i, el) => {
      const row = $(el),
        title = clean(row.find('.show__title').text()),
        dateText = clean(row.find('.show__date').text());
      const dates = explicitDates(dateText),
        time = clock(dateText);
      // The official theatre's home schedule includes its tours to other cities.
      if (/gostovanje\s+u\b/i.test(title) && !/gostovanje\s+u\s+osijeku\b/i.test(title)) {
        result.discovered++;
        result.skipped++;
        return;
      }
      if (dates.length !== 1) {
        result.discovered++;
        result.skipped++;
        result.warnings.push(`HNK: nečitljiv datum „${title}”.`);
        return;
      }
      add(
        row.parent('a').attr('href') ?? '',
        title,
        zagrebTime(dates[0], time),
        clean(row.find('.show__genre').text()),
      );
    });
    result.entries.sort((a, b) => a.startsAt!.localeCompare(b.startsAt!));
  } else {
    const cards = $('a.event-card-background');
    if (!cards.length) throw new Error('CoreEvent: nedostaje gradski popis događaja.');
    cards.each((_i, el) => {
      const card = $(el),
        title = clean(card.find('.event-title').text()),
        dateText = clean(card.find('.event-description').text());
      const dates = explicitDates(dateText),
        city = clean(card.find('.event-location').text()).split(',').at(-1);
      // For a range the explicit final date is sufficient for discovery, never for a continuous event.
      if (normalize(city ?? '') !== 'osijek' || !dates.length || dates.at(-1)! < localDay(now)) {
        result.discovered++;
        result.skipped++;
        return;
      }
      add(card.attr('href') ?? '', title);
    });
  }
  return result;
}

function textLines(html: string, selector: string): string[] {
  const $ = load(html),
    body = $(selector).first().clone();
  body.find('script,style,noscript,del,s,.meta,.image,.td-post-featured-image').remove();
  body.find('br').replaceWith('\n');
  body.find('p,li,h2,h3').append('\n');
  return body.text().split('\n').map(clean).filter(Boolean);
}

function finish(event: EventCandidate, body: string, extra = '') {
  // Conditions remain visible in the public description, including membership and guardian exceptions.
  const conditions = body
    .split(/\n|(?<=[.!?])\s+(?=[A-ZČĆŽŠĐ*])/u)
    .filter((line) =>
      /prijav|za korisnike|članstv|clanstv|starij.{0,8}od|mlađi.{0,50}pratnj|dobna granica|pretplat|ulaznic|naknad|besplat|rezerv|rasprodan|\b\d+\s*(?:eura|EUR|€)/i.test(
        line,
      ),
    );
  event.description = [synopsis(event), extra, ...conditions]
    .filter(Boolean)
    .join(' ')
    .slice(0, 5000);
  event.discovery = inferDiscovery(event.title, body, event.sourceUrl, event.price);
  return event;
}

export function parseAnnouncement(
  id: 'gisko' | 'dkolektiv',
  html: string,
  entry: LocalEntry,
  now = new Date(),
): LocalDetail {
  const $ = load(html),
    result: LocalDetail = { events: [], warnings: [], reviewExternalIds: [] };
  const selector = id === 'gisko' ? '.td-post-content' : '.single-news';
  if (!$(selector).length) throw new Error(`${id}: nedostaje sadržaj najave.`);
  const title =
    clean(
      $(id === 'gisko' ? 'h1.entry-title' : '.title-page')
        .first()
        .text(),
    ) || entry.title;
  const allLines = textLines(html, selector);
  const boilerplate = allLines.findIndex((line) =>
    /^Projekt .{0,40}provodi|^Ovaj projekt sufinancira|^Izneseni stavovi/i.test(line),
  );
  const lines = boilerplate < 0 ? allLines : allLines.slice(0, boilerplate);
  const body = lines.join('\n'),
    value = plain(`${title}\n${body}`);
  if (
    /\b(?:odrzana|odrzan|odrzano|odrzali|izvjestaj|osvrt|sto smo naucili)\b/.test(plain(title)) ||
    /\b(?:svaki|svakog|redovni|tjedni)\b.{0,40}\b(?:sat|termin|trening|tecaj)/.test(value)
  )
    return result;
  const invitation =
    /\b(?:odrzat ce|odrzava se|organizira|pozivamo|pridruzite|pridruzu|svratite|dodite|pocinje|pocetak|otvorenih vrata)\b/.test(
      value,
    );
  const dated = lines.filter(
    (line) =>
      explicitDates(line).length &&
      !/\b(?:prijav\w*|rok\w*|do kada|natjecaj\w*|odrzan[aoi]?|odrzali)\b/.test(
        plain(line).split(/\d{1,2}\./)[0],
      ),
  );
  if (!invitation || !dated.length) {
    if (/kalendar|raspored|radionic|tecaj|plesn|pricaonic|knjizevn|izlozb/.test(plain(title)))
      result.warnings.push(
        `${id}: „${title}” nema potvrđen datum događaja s godinom u tekstu; slikovni raspored ili rok nije uvezen (${entry.url}).`,
      );
    return result;
  }
  if (dated.some((line) => /\d{1,2}\.\s*(?:-|–|—|do)\s*\d{1,2}\./.test(line))) {
    result.warnings.push(
      `${id}: „${title}” ima raspon datuma bez potvrđenih pojedinačnih termina; potreban je pregled (${entry.url}).`,
    );
    return result;
  }
  let venue: string | null = null;
  if (id === 'gisko') {
    const local = dated.join(' ');
    if (!/knjižnic[ae] Osijek|GISKO|Ogranku|Studijske čitaonice/i.test(local)) return result;
    venue =
      local.match(
        /\bu\s+(?:prostoru\s+)?(Studijske čitaonice|Ogranku\s+[^,.;]+?)(?=\s+(?:organizira|održat|održava)|[,.;]|$)/i,
      )?.[1] ?? null;
    if (venue)
      venue = `GISKO — ${venue.replace(/^Ogranku\b/i, 'Ogranak').replace(/^Studijske čitaonice$/i, 'Studijska čitaonica')}`;
  } else {
    const location = lines.find((line) => /^(?:📍|Lokacija\s*:|Mjesto\s*:)/iu.test(line));
    if (location && /\bOsijek\b/.test(location))
      venue = clean(
        location.replace(/^(?:📍|Lokacija\s*:|Mjesto\s*:)/iu, '').replace(/,?\s*Osijek\s*$/i, ''),
      );
    // No organization address or partner-school list may stand in for the event location.
    if (!venue) {
      result.warnings.push(
        `DKolektiv: „${title}” nema jednoznačno mjesto i grad u najavi (${entry.url}).`,
      );
      return result;
    }
  }
  const days = [...new Set(dated.flatMap(explicitDates))];
  for (const day of days) {
    if (day < localDay(now)) continue;
    const line = dated.find((line) => explicitDates(line).includes(day))!;
    const timeLine = line.match(/\b\d{1,2}[:.]\d{2}\s*(?:sati|h|do|–|-)/i)
      ? line
      : lines.find((line) => /^(?:🕔|Vrijeme\s*:|početak\s+u)/iu.test(line));
    // Remove date tokens before reading dotted clocks, so 14.10.2026 cannot become 14:10.
    const schedule = (timeLine ?? line).replace(/\d{1,2}\.\s*\d{1,2}\.\s*20\d{2}\.?/g, '');
    const startClock = clock(schedule),
      startsAt = zagrebTime(day, startClock);
    const endClock = schedule
      .match(/(?:do|–|—|-)\s*([01]?\d|2[0-3])[:.]([0-5]\d)/)
      ?.slice(1)
      .join(':');
    const endsAt = endClock ? zagrebTime(day, endClock) : null;
    const externalId = `${new URL(entry.url).pathname}#${day}`;
    const event = candidate(
      id,
      entry.url,
      externalId,
      title,
      startsAt,
      endsAt && endsAt > startsAt ? endsAt : null,
      body,
    );
    event.venue = venue;
    if (/\b(?:ulaz|sudjelovanje) je besplat|besplatan ulaz/i.test(body)) event.price = 'Besplatno';
    if (id === 'gisko' && /književn|pričaonic/i.test(title))
      event.category = /pričaonic/i.test(title)
        ? 'community'
        : categoryFor(`knjiga ${title}`, title);
    if (id === 'dkolektiv' && /STEM/i.test(title) && /radionic/i.test(body))
      event.category = 'workshop';
    result.events.push(finish(event, body));
    if ((startClock && startsAt.length === 10) || (endClock && endsAt?.length === 10)) {
      result.reviewExternalIds.push(externalId);
      result.warnings.push(
        `${id}: nejednoznačna satnica pri promjeni sata za „${title}”; potreban je pregled.`,
      );
    }
  }
  return result;
}

export function parseHnkDetail(html: string, entries: LocalEntry[], now = new Date()): LocalDetail {
  const $ = load(html),
    title = clean($('.single__title').first().text()),
    body = textLines(html, '.single__content__description').join('\n');
  if (!title || !body) throw new Error('HNK: nedostaje opis predstave.');
  const result: LocalDetail = { events: [], warnings: [], reviewExternalIds: [] };
  const tickets = $('.list--ensemble-dates__link')
    .map((_i, el) => ({ day: explicitDates($(el).text())[0], url: $(el).attr('href') ?? '' }))
    .get();
  for (const entry of entries) {
    if (!entry.startsAt || entry.startsAt.slice(0, 10) < localDay(now)) continue;
    const matches = tickets.filter((ticket) => ticket.day === entry.startsAt!.slice(0, 10));
    const sameDayEntries = entries.filter(
      (item) => item.startsAt?.slice(0, 10) === entry.startsAt!.slice(0, 10),
    );
    const ticket =
      sameDayEntries.length === 1 &&
      matches.length === 1 &&
      /^\/ulaznice\/predstava\?\d+$/.test(matches[0].url)
        ? matches[0].url
        : null;
    const externalId =
      ticket ??
      `${new URL(entry.url).pathname}#${sameDayEntries.length === 1 ? entry.startsAt.slice(0, 10) : entry.startsAt}`;
    const event = candidate(
      'hnk-osijek',
      entry.url,
      externalId,
      entry.title,
      entry.startsAt,
      null,
      `${entry.genre}\n${body}`,
    );
    event.venue = 'Hrvatsko narodno kazalište u Osijeku';
    event.category = /balet/i.test(entry.genre ?? '')
      ? 'dance'
      : /koncert|glazbena|opera/i.test(`${entry.title} ${entry.genre}`)
        ? 'music'
        : 'theatre';
    result.events.push(
      finish(
        event,
        body,
        /pretplat/i.test(entry.title)
          ? 'Termin iz pretplatničkog programa; provjerite dostupnost ulaznica.'
          : '',
      ),
    );
    if (
      (tickets.length && matches.length !== 1) ||
      sameDayEntries.length > 1 ||
      entry.startsAt.length === 10
    ) {
      result.reviewExternalIds.push(externalId);
      result.warnings.push(
        `HNK: termin „${entry.title}” traži provjeru satnice ili podudaranja s ulaznicom.`,
      );
    }
  }
  return result;
}

type JsonObject = Record<string, unknown>;
const object = (value: unknown): JsonObject | null =>
  value && typeof value === 'object' && !Array.isArray(value) ? (value as JsonObject) : null;
function eventNodes(value: unknown): JsonObject[] {
  if (Array.isArray(value)) return value.flatMap(eventNodes);
  const node = object(value);
  if (!node) return [];
  return [node['@type']].flat().includes('Event') ? [node] : eventNodes(node['@graph']);
}
function instant(value: unknown): string | null {
  if (
    typeof value !== 'string' ||
    !/^20\d{2}-\d\d-\d\dT\d\d:\d\d/.test(value) ||
    !Number.isFinite(Date.parse(value))
  )
    return null;
  const local = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Europe/Zagreb',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(value));
  return zagrebTime(local.slice(0, 10), local.slice(11, 16));
}

export function parseCoreEventDetail(
  html: string,
  entry: LocalEntry,
  now = new Date(),
): LocalDetail {
  const $ = load(html),
    title = clean($('.single-event-cover-title').text());
  if (!title) throw new Error('CoreEvent: nedostaje naslov događaja.');
  const nodes: JsonObject[] = [];
  $('script[type="application/ld+json"]').each((_i, el) => {
    try {
      nodes.push(...eventNodes(JSON.parse($(el).text())));
    } catch {}
  });
  const matching = nodes.filter(
    (node) => typeof node.name === 'string' && normalize(node.name) === normalize(title),
  );
  if (matching.length !== 1)
    throw new Error('CoreEvent: nedostaje jednoznačan strukturirani događaj.');
  const node = matching[0],
    location = object(node.location),
    address = object(location?.address);
  const result: LocalDetail = { events: [], warnings: [], reviewExternalIds: [] };
  if (
    typeof address?.addressLocality !== 'string' ||
    normalize(address.addressLocality) !== 'osijek'
  )
    return result;
  const venue = typeof location?.name === 'string' ? clean(location.name) : null;
  const body = textLines(html, '.single-event__description-container').join('\n');
  const useful = $('.single-event__highlighted-data-container').text();
  const ageText =
    clean($('.single-event').text()).match(/Dobna granica:\s*(\d{1,2})\b/)?.[1] ??
    clean($('body').text()).match(/Dobna granica:\s*(\d{1,2})\b/)?.[1];
  const rows = $('.single-event__single-ticket-container');
  if (!rows.length) throw new Error('CoreEvent: nema čitljivih termina ulaznica.');
  const seen = new Set<string>();
  rows.each((_i, el) => {
    const row = $(el),
      text = clean(row.find('.single-event__ticket-info-container').text());
    const dates = explicitDates(text),
      clocks =
        text
          .replace(/\d{1,2}\.\s*\d{1,2}\.\s*20\d{2}\.?/g, '')
          .match(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g) ?? [];
    if (!dates.length) {
      result.warnings.push(`CoreEvent: „${title}” ima nečitljiv termin.`);
      return;
    }
    const start = zagrebTime(dates[0], clocks[0]);
    let end = dates[1] ? zagrebTime(dates[1], clocks[1]) : null;
    const reasons: string[] = [];
    if ((clocks[0] && start.length === 10) || (clocks[1] && end?.length === 10))
      reasons.push('nejednoznačna satnica pri promjeni sata');
    if (rows.length === 1) {
      const structuredStart = instant(node.startDate),
        structuredEnd = instant(node.endDate);
      if (!structuredStart || structuredStart !== start)
        reasons.push('satnica ulaznice i strukturiranog zapisa nije usklađena');
      if (end && structuredEnd && end !== structuredEnd)
        reasons.push('završetak ulaznice i strukturiranog zapisa nije usklađen');
      if (!end && structuredEnd && structuredEnd.slice(0, 10) === start.slice(0, 10))
        end = structuredEnd;
    }
    if ((end ?? start).slice(0, 10) < localDay(now)) return;
    let externalId = `${new URL(entry.url).pathname}#${start}`;
    const ticketRaw = row.find('a.single-event__buy-ticket-button').attr('href');
    if (ticketRaw) {
      try {
        const ticket = new URL(ticketRaw);
        if (
          ticket.protocol === 'https:' &&
          ticket.hostname === 'app.core-event.co' &&
          /^\/events\/[^/]+\/register$/.test(ticket.pathname)
        )
          externalId = ticket.pathname;
      } catch {}
    }
    if (seen.has(externalId)) {
      result.warnings.push(`CoreEvent: ponovljen identitet termina „${title}”; potreban pregled.`);
      result.reviewExternalIds.push(externalId);
      return;
    }
    seen.add(externalId);
    // Ticket headings wrap some play names with type/city labels. KC gives the same
    // play as TITLE /predstava/; removing only those explicit wrappers enables exact dedup.
    const eventTitle = title.replace(/^PREDSTAVA\s+["“„](.+)["”]\s+U OSIJEKU$/i, '$1');
    const event = candidate(
      'coreevent-osijek',
      entry.url,
      externalId,
      eventTitle,
      start,
      end,
      body,
    );
    event.venue = venue;
    event.address =
      typeof address?.streetAddress === 'string' && address.streetAddress
        ? address.streetAddress
        : null;
    const offer = object(node.offers);
    if (
      offer &&
      (typeof offer.price === 'number' || typeof offer.price === 'string') &&
      /^\d+(?:[.,]\d{1,2})?$/.test(String(offer.price)) &&
      offer.priceCurrency === 'EUR'
    )
      event.price =
        Number(offer.price) === 0
          ? 'Besplatno'
          : `Od ${String(offer.price).replace('.', ',')} €; provjerite naknade i vrstu ulaznice`;
    const genre = clean($('.single-event-cover__genre-text-wrapper').text());
    event.category = categoryFor(`${title} ${genre} ${body}`, title);
    if (/stand.?up|comedy/i.test(title)) event.category = 'theatre';
    if (/Music/i.test(genre)) event.category = 'music';
    if (
      /\bkino\b/i.test(venue ?? '') &&
      (/\bfilm(?:a|u|om|ovi)?\b/i.test(body) || /\bSINK\b/.test(title))
    )
      event.category = 'film';
    if (/\bREDATELJ\s*:/i.test(body) && /ŽANR\s*:/i.test(body) && /\bTR(A|I)JANJE\s*:/i.test(body))
      event.category = 'film';
    if (/EventCancelled$/.test(String(node.eventStatus))) event.status = 'cancelled';
    if (/EventPostponed$/.test(String(node.eventStatus))) event.status = 'postponed';
    result.events.push(
      finish(
        event,
        `${body}\n${useful}`,
        ageText ? `Dobna granica navedena na ulaznici: ${ageText} godina.` : '',
      ),
    );
    if (reasons.length) {
      result.reviewExternalIds.push(externalId);
      result.warnings.push(
        `CoreEvent: „${title}” ostaje nacrt: ${reasons.join('; ')}. ${entry.url}`,
      );
    }
  });
  return result;
}
