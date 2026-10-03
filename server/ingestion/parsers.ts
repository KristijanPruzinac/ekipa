import { createHash } from 'node:crypto';
import { load } from 'cheerio';
import type { Category, EventCandidate, FetchResult } from '../../shared/types.ts';
import { isWorkshopTitle } from '../../shared/discovery.ts';
import { localDay, normalize } from '../validation.ts';
import { inferDiscovery } from '../discovery.ts';
import { trustedSourceUrl } from './reader.ts';

export const TZ_URL = 'https://www.tzosijek.hr/stranica.php?id=1485';
export const KC_URL = 'https://kulturni-centar.hr/dogadjanja/sva-dogadjanja';
export const clean = (value: string) => value.replace(/\s+/g, ' ').trim();
export interface ExtractionPage {
  url: string;
  text: string;
}
export interface ParsedCalendar extends FetchResult {
  extractionPages: ExtractionPage[];
}
export interface ListingEntry {
  title: string;
  url: string;
  startsAt: string;
  endsAt: string | null;
  dateText: string;
}
export const emptyResult = (): ParsedCalendar => ({
  events: [],
  pagesFetched: 0,
  discovered: 0,
  skipped: 0,
  warnings: [],
  extractionPages: [],
});

function date(year: number, month: number, day: number): string | null {
  if (year < 2020 || year > 2100) return null;
  const iso = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const value = new Date(`${iso}T12:00:00Z`);
  return Number.isFinite(value.getTime()) && value.toISOString().slice(0, 10) === iso ? iso : null;
}

export function parseCalendarDate(
  raw: string,
  contextYear?: number,
): { start: string; end: string | null } | null {
  const value = clean(raw).replace(/[–—−]/g, '-');
  const range = value.match(
    /^(\d{1,2})\s*\.\s*(?:(\d{1,2})\s*\.?\s*)?(?:(\d{4})\s*\.?\s*)?(?:-|do)\s*(\d{1,2})\s*\.\s*(\d{1,2})\s*\.\s*(?:(\d{4})\s*\.?)?$/i,
  );
  if (range) {
    const year = Number(range[6] || range[3] || contextYear);
    const start = date(Number(range[3] || year), Number(range[2] || range[5]), Number(range[1]));
    const end = date(year, Number(range[5]), Number(range[4]));
    return start && end && start <= end ? { start, end: end === start ? null : end } : null;
  }
  const single = value.match(/^(\d{1,2})\s*\.\s*(\d{1,2})\s*\.\s*(?:(\d{4})\s*\.?)?$/);
  if (!single) return null;
  const start = date(Number(single[3] || contextYear), Number(single[2]), Number(single[1]));
  return start ? { start, end: null } : null;
}

/** Resolve a local event time using IANA rules; ambiguous/nonexistent hours stay date-only. */
export function zagrebTime(day: string, time?: string): string {
  const match = time?.trim().match(/^(\d{1,2})[:.](\d{2})$/);
  if (!match || Number(match[1]) > 23 || Number(match[2]) > 59) return day;
  const clock = `${match[1].padStart(2, '0')}:${match[2]}`;
  const format = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Europe/Zagreb',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  });
  const matches = ['+01:00', '+02:00']
    .map((offset) => `${day}T${clock}:00${offset}`)
    .filter((iso) => format.format(new Date(iso)) === `${day} ${clock}`);
  return matches.length === 1 ? matches[0] : day;
}

export function categoryFor(text: string, title = text): Category {
  const value = normalize(text);
  const primary = normalize(title);
  const danceTopic =
    /\b(?:ples[a-z]*|balet[a-z]*|sals[a-z]*|bachat[a-z]*|kizomb[a-z]*|tango|tanga|swing|dance)\b/.test(
      primary,
    ) &&
    !/\b(?:kuh[a-z]*|kulin[a-z]*|umak[a-z]*|gastronom[a-z]*|fotograf[a-z]*|snimanj[a-z]*|crtanj[a-z]*|slikanj[a-z]*|music|glazb[a-z]*|produkcij[a-z]*)\b/.test(
      primary,
    );
  if (isWorkshopTitle(title)) return danceTopic ? 'dance' : 'workshop';
  // The announced activity takes precedence over incidental programme/body words.
  const filmEvent =
    /\b(?:projekcij[a-z]*\s+(?:(?:dokumentarn[a-z]*|igran[a-z]*|kratk[a-z]*|animiran[a-z]*)\s+)?film[a-z]*|filmsk[a-z]*\s+(?:projekcij[a-z]*|vecer[a-z]*|festival[a-z]*|matinej[a-z]*)|kino\s+(?:vecer|matineja)|screening)\b/;
  const literaryEvent =
    /\b(?:knjizevn[a-z]*\s+(?:vecer[a-z]*|susret[a-z]*|razgovor[a-z]*|festival[a-z]*)|(?:promocij[a-z]*|predstavljanj[a-z]*)\s+(?:knjig[a-z]*|roman[a-z]*|zbirke|slikovnic[a-z]*)|citateljsk[a-z]*\s+klub[a-z]*|(?:vecer|citanje)\s+poezij[a-z]*)\b/;
  if (filmEvent.test(primary)) return 'film';
  if (literaryEvent.test(primary)) return 'literature';
  const danceEvent =
    /\b(?:plesnjak[a-z]*|balet)\b/.test(primary) ||
    /\b(?:plesn[a-z]*|baletn[a-z]*)\s+(?:vecer[a-z]*|druzenj[a-z]*|predstav[a-z]*|izvedb[a-z]*|performans[a-z]*|natjecanj[a-z]*|festival[a-z]*)\b/.test(
      primary,
    ) ||
    /\b(?:sals[a-z]*|bachat[a-z]*|kizomb[a-z]*|tang[oa]|swing)(?:\s+(?:i|and))?(?:\s+(?:sals[a-z]*|bachat[a-z]*|kizomb[a-z]*|tang[oa]|swing))?\s+(?:social|party|night|festival|vecer)\b/.test(
      primary,
    ) ||
    /\b(?:vecer|festival|party|social)\s+(?:plesa|sals[a-z]*|bachat[a-z]*|kizomb[a-z]*|tang[oa]|swing)\b/.test(
      primary,
    ) ||
    (danceTopic &&
      /\b(?:pocetak|pocinje|pocetn[a-z]*|prvi sat|nova grupa)\b/.test(primary) &&
      /\b(?:tecaj[a-z]*|skol[a-z]*|grup[a-z]*)\b/.test(primary) &&
      !/\b(?:svaki|svakog|tjedn[a-z]*|redovn[a-z]*)\b/.test(primary)) ||
    (danceTopic &&
      /\b(?:dan(?:i)? otvorenih vrata|otvoren[ai] dan)\b/.test(primary) &&
      /\b(?:plesn[a-z]*|baletn[a-z]*)\s+(?:skol[a-z]*|studij[a-z]*)\b/.test(primary));
  if (
    danceEvent &&
    !/\b(?:koncert[a-z]*|glazb[a-z]*|film[a-z]*|izlozb[a-z]*|knjig[a-z]*|predavanj[a-z]*)\b/.test(
      primary,
    )
  )
    return 'dance';
  if (/\b(predstava|kazalist|komedij|teatar)/.test(value)) return 'theatre';
  if (/\b(sport|utrka|maraton|atletik|nogomet|gimnastik|natjecanje|bicikl|rekreacij)/.test(value))
    return 'sport';
  if (/\b(koncert|glazb|orkest|jazz|pjev|tambur|vibrafon)/.test(value)) return 'music';
  if (/\b(party|night|dj)\b/.test(value)) return 'nightlife';
  if (filmEvent.test(value)) return 'film';
  if (literaryEvent.test(value)) return 'literature';
  if (/\b(izlozb|umjet|kultur|knjig|film|muzej|festival)/.test(value)) return 'culture';
  if (/\b(sajam|radionic|djec|obitelj|advent)/.test(value)) return 'community';
  return 'other';
}

export function synopsis(event: EventCandidate): string {
  const labels: Record<Category, string> = {
    music: 'Glazbeni događaj',
    nightlife: 'Noćni program',
    dance: 'Plesni događaj',
    workshop: 'Radionica',
    theatre: 'Kazališna predstava',
    film: 'Filmska projekcija',
    literature: 'Književni događaj',
    culture: 'Kulturni događaj',
    sport: 'Sportski događaj',
    community: 'Događaj zajednice',
    other: 'Događaj u Osijeku',
  };
  return [
    `${labels[event.category]}.`,
    event.venue ? `Mjesto održavanja: ${event.venue}.` : '',
    event.price === 'Besplatno' ? 'Ulaz je besplatan.' : '',
    'Program i ostali detalji dostupni su u službenoj najavi.',
  ]
    .filter(Boolean)
    .join(' ');
}

export function candidate(
  sourceId: string,
  sourceUrl: string,
  externalId: string,
  title: string,
  startsAt: string,
  endsAt: string | null,
  sourceText: string,
): EventCandidate {
  const event: EventCandidate = {
    sourceId,
    sourceUrl,
    externalId,
    title,
    startsAt,
    endsAt,
    description: '',
    venue: null,
    address: null,
    city: 'Osijek',
    category: categoryFor(`${title} ${sourceText}`, title),
    price: null,
    status: 'scheduled',
    discovery: inferDiscovery(title, sourceText, sourceUrl),
  };
  event.description = synopsis(event);
  return event;
}

export function addExtraction(result: ParsedCalendar, url: string, text: string) {
  if (text.length > 12000) {
    result.warnings.push(
      `Tekst za AI prelazi 12.000 znakova: ${url}. Sačuvan je izvor; tekst nije tiho skraćen.`,
    );
    return;
  }
  result.extractionPages.push({ url, text });
}

export function parseTourismCalendar(html: string, now = new Date()): ParsedCalendar {
  const $ = load(html);
  const container = $('.postcontent.text-center');
  if (!container.length)
    throw new Error('TZ Osijek: struktura kalendara je promijenjena ili nedostaje.');
  const result = emptyResult();
  const titleCounts = new Map<string, number>();
  const firstHeading = container
    .text()
    .match(
      /(SIJEČANJ|VELJAČA|OŽUJAK|TRAVANJ|SVIBANJ|LIPANJ|SRPANJ|KOLOVOZ|RUJAN|LISTOPAD|STUDENI|PROSINAC)\s+(20\d{2})/i,
    );
  let year = firstHeading ? Number(firstHeading[2]) : undefined;
  container.find('p').each((_index, element) => {
    const paragraph = $(element);
    const text = clean(paragraph.text());
    if (!text) return;
    const heading = text.match(
      /^(SIJEČANJ|VELJAČA|OŽUJAK|TRAVANJ|SVIBANJ|LIPANJ|SRPANJ|KOLOVOZ|RUJAN|LISTOPAD|STUDENI|PROSINAC)\s+(20\d{2})\.?$/i,
    );
    if (heading) {
      year = Number(heading[2]);
      return;
    }
    const title = clean(paragraph.find('strong,b').first().text());
    if (
      !title ||
      title.length < 3 ||
      title === text ||
      /Turistička zajednica.*odgovorna/i.test(text)
    )
      return;
    result.discovered++;
    const identity = normalize(title);
    const ordinal = (titleCounts.get(identity) ?? 0) + 1;
    titleCounts.set(identity, ordinal);
    const beforeTitle = clean(text.slice(0, text.indexOf(title)));
    const previous = clean(paragraph.prev().text());
    const dateText =
      beforeTitle ||
      (/^(siječanj|veljača|ožujak|travanj|svibanj|lipanj|srpanj|kolovoz|rujan|listopad|studeni|prosinac)$/i.test(
        previous,
      )
        ? previous
        : '');
    const dates = parseCalendarDate(dateText, year);
    if (!dates) {
      result.skipped++;
      result.warnings.push(
        `TZ: nije naveden precizan datum za „${title}” (${dateText || 'bez datuma'}).`,
      );
      // This page supplies no exact date and extraction cannot search other sources.
      // Sending a month-only entry to AI cannot legitimately resolve its missing day.
      return;
    }
    if ((dates.end ?? dates.start) < localDay(now)) {
      result.skipped++;
      return;
    }
    const externalId = `calendar-${createHash('sha256').update(identity).digest('hex').slice(0, 20)}-${ordinal}`;
    result.events.push(
      candidate('tz-osijek', TZ_URL, externalId, title, dates.start, dates.end, text),
    );
  });
  if (!result.discovered)
    throw new Error('TZ Osijek: nisu pronađene stavke kalendara. Provjeri strukturu izvora.');
  return result;
}

export function parseKcListing(
  html: string,
  now = new Date(),
): { entries: ListingEntry[]; discovered: number; skipped: number; warnings: string[] } {
  const $ = load(html);
  const rows = $('.datatable__item');
  if (!rows.length)
    throw new Error('Kulturni centar: popis događaja nedostaje ili je promijenio strukturu.');
  const result = {
    entries: [] as ListingEntry[],
    discovered: rows.length,
    skipped: 0,
    warnings: [] as string[],
  };
  const seen = new Set<string>();
  rows.each((_index, element) => {
    const row = $(element);
    const link = row.find('h4 a').first();
    const title = clean(link.text())
      .replace(/^\d{1,2}\.\d{1,2}\.\s*/, '')
      .replace(/\s*\/predstava\/\s*$/i, '');
    const dateText = clean(row.find('.pattern--date').text());
    const matches = [...dateText.matchAll(/(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})(?!\d)/g)];
    const parseMatch = (match: RegExpMatchArray) =>
      date(
        match[3].length === 2 ? 2000 + Number(match[3]) : Number(match[3]),
        Number(match[2]),
        Number(match[1]),
      );
    const start = matches[0] ? parseMatch(matches[0]) : null;
    const end = matches[1] ? parseMatch(matches[1]) : null;
    if (!title || !start || (end && end < start)) {
      result.skipped++;
      result.warnings.push(`KC: nečitljiv naslov ili datum: ${title || '(bez naslova)'}.`);
      return;
    }
    if ((end ?? start) < localDay(now) || /upis\s+pretplat|prodaja\s+pretplat/i.test(title)) {
      result.skipped++;
      return;
    }
    let url: string;
    try {
      url = trustedSourceUrl(link.attr('href') ?? '', KC_URL);
    } catch {
      result.skipped++;
      result.warnings.push(`KC: nepouzdana poveznica za „${title}”.`);
      return;
    }
    if (!new URL(url).pathname.startsWith('/dogadjanja/') || url === KC_URL || seen.has(url)) {
      result.skipped++;
      return;
    }
    seen.add(url);
    const time = dateText.match(/@\s*(\d{1,2}[:.]\d{2})/)?.[1];
    const startsAt = zagrebTime(start, time);
    result.entries.push({
      title,
      url,
      startsAt,
      endsAt: end && end !== start ? end : null,
      dateText,
    });
  });
  result.entries.sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  return result;
}

export function parseKcDetail(
  html: string,
  entry: ListingEntry,
): { event: EventCandidate; extraction: ExtractionPage | null; warnings: string[] } {
  const $ = load(html);
  const title = clean($('.news-item__title').first().text())
    .replace(/^\d{1,2}\.\d{1,2}\.\s*/, '')
    .replace(/\s*\/predstava\/\s*$/i, '');
  const article = $('article.article').first();
  if (!title || !article.length) throw new Error(`KC: nedostaje sadržaj događaja ${entry.url}.`);
  article.find('br').replaceWith('\n');
  article.find('script,style,del,s,strike').remove();
  article.find('[style]').each((_index, element) => {
    if (/text-decoration(?:-line)?\s*:[^;]*\bline-through\b/i.test($(element).attr('style') ?? ''))
      $(element).remove();
  });
  const paragraphs = article
    .find('p')
    .map((_index, element) => clean($(element).text()))
    .get()
    .filter(Boolean);
  const body = paragraphs.length ? paragraphs.join('\n\n') : clean(article.text());
  if (!body) throw new Error(`KC: prazan tekst događaja ${entry.url}.`);
  const warnings: string[] = [];
  const detailDate = clean($('.news-item__content .pattern--date').first().text());
  const detailMatch = detailDate.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})$/);
  const exactDay = detailMatch
    ? date(
        detailMatch[3].length === 2 ? 2000 + Number(detailMatch[3]) : Number(detailMatch[3]),
        Number(detailMatch[2]),
        Number(detailMatch[1]),
      )
    : null;
  const detailTime = clean($('.news-item__content .pattern--time').first().text());
  const startsAt = exactDay ? zagrebTime(exactDay, detailTime) : entry.startsAt;
  if (exactDay && exactDay !== entry.startsAt.slice(0, 10))
    warnings.push(`KC: detalj navodi drukčiji datum od popisa za „${title}”; koristi se detalj.`);
  const endsAt = entry.endsAt && entry.endsAt >= startsAt.slice(0, 10) ? entry.endsAt : null;
  const event = candidate(
    'kc-osijek',
    entry.url,
    new URL(entry.url).pathname,
    title,
    startsAt,
    endsAt,
    body,
  );
  const venuePatterns: [RegExp, string][] = [
    [/\bdvoran[aeiou]\s+[„"']?Franjo\s+Krežma/i, 'Dvorana Franjo Krežma'],
    [
      /\bmalo[jmu]?\s+dvoran[aeiou]\s+(?:Kulturnog\s+centra|KC-a)/i,
      'Mala dvorana Kulturnog centra',
    ],
    [
      /\bmal[aeiou]\s+dvoran[aeiou]\s+(?:Kulturnog\s+centra|KC-a)/i,
      'Mala dvorana Kulturnog centra',
    ],
    [/\batrij[au]?\s+Kulturnog\s+centra/i, 'Atrij Kulturnog centra'],
    [/\bgalerij[aeiu]\s+Kulturnog\s+centra/i, 'Galerija Kulturnog centra'],
  ];
  const multipleSpaces = body.match(
    /Foaje\s+KC-a,\s*Predvorje\s+1\.\s*kat,\s*Mala\s+dvorana/i,
  )?.[0];
  // Some KC announcements put the venue in a date/time/place programme line.
  // Only a line for this exact occurrence may supply it, never a neighbouring
  // programme item or an old location retained in a relocation announcement.
  const scheduleVenues = new Set<string>();
  if (
    !endsAt &&
    startsAt.length > 10 &&
    !/\b(?:premjest|prebac|preselj|seli se|nova lokacij|promjen[ae] lokacij)/.test(
      normalize(`${title} ${body}`),
    )
  ) {
    article.find('p').each((_index, element) => {
      const schedule = clean($(element).text()).match(
        /^(?:Ponedjeljak|Utorak|Srijeda|Četvrtak|Petak|Subota|Nedjelja)\s*,?\s*(\d{1,2})\.\s*(\d{1,2})\.\s*(?:(\d{4})\.\s*)?\/\s*(\d{1,2})[.:](\d{2})\s*(?:sati|sat)?\s*\/\s*([^/]+)$/i,
      );
      if (!schedule) return;
      const day = date(
        Number(schedule[3] ?? startsAt.slice(0, 4)),
        Number(schedule[2]),
        Number(schedule[1]),
      );
      const clock = `${schedule[4].padStart(2, '0')}:${schedule[5]}`;
      const venue = clean(schedule[6]);
      if (
        day === startsAt.slice(0, 10) &&
        clock === startsAt.slice(11, 16) &&
        venue.length >= 3 &&
        venue.length <= 300 &&
        !/\b(?:naknadno|uskoro|tba|tbc|vise lokacija)\b/.test(normalize(venue))
      )
        scheduleVenues.add(venue);
    });
  }
  event.venue =
    multipleSpaces ??
    venuePatterns.find(([pattern]) => pattern.test(`${title}\n${body}`))?.[1] ??
    (scheduleVenues.size === 1 ? [...scheduleVenues][0] : null);
  if (/\bulaz(?:\s+na\s+\S+)?\s+(?:je\s+)?slobodan\b|\bbesplatan\s+ulaz\b/i.test(body))
    event.price = 'Besplatno';
  if (/\botkazano\b|\bdogađaj\s+je\s+otkazan\b/i.test(`${title} ${body}`))
    event.status = 'cancelled';
  else if (/\bodgođeno\b|\bdogađaj\s+je\s+odgođen\b/i.test(`${title} ${body}`))
    event.status = 'postponed';
  event.description = synopsis(event);
  const evidence = `Naslov: ${title}\nDatum početka iz izvora: ${startsAt.slice(0, 10)}\nVrijeme iz izvora (Europe/Zagreb): ${detailTime || entry.dateText.match(/@\s*(\d{1,2}[:.]\d{2})/)?.[1] || 'nije navedeno'}\nDatum završetka iz popisa: ${endsAt ?? 'nije zasebno naveden'}\n\n${body}`;
  event.discovery = inferDiscovery(title, body, entry.url, event.price);
  // Structured date + known explicit venue are usable without AI. The model reads
  // prose when fields are unresolved; it never supplies invented source facts.
  const extraction =
    !event.venue || !event.price || event.category === 'other'
      ? { url: entry.url, text: evidence }
      : null;
  return { event, extraction, warnings };
}
