import type { FetchResult, SourceDefinition } from '../../shared/types.ts';
import {
  addExtraction,
  KC_URL,
  parseKcDetail,
  parseKcListing,
  parseTourismCalendar,
  TZ_URL,
  emptyResult,
} from './parsers.ts';
import {
  checkSourceDeadline,
  readSourcePage,
  SourceDeadlineError,
  type ReaderOptions,
} from './reader.ts';
import { COUNTY_URL, parseCountyDetail, parseCountyListing } from './county.ts';
import { fetchInstagramProfile, instagramSources, isInstagramSource } from './instagram.ts';
import {
  localSources,
  parseLocalListing,
  parseAnnouncement,
  parseHnkDetail,
  parseCoreEventDetail,
  type LocalEntry,
} from './local-sources.ts';

export const sources: SourceDefinition[] = [
  {
    id: 'tz-osijek',
    name: 'Turistička zajednica Osijeka',
    url: TZ_URL,
    description:
      'Službeni kalendar manifestacija za 2026. Datum bez satnice ostaje bez izmišljenog vremena.',
    enabled: true,
  },
  {
    id: 'kc-osijek',
    name: 'Kulturni centar Osijek',
    url: KC_URL,
    description:
      'Službeni događaji Kulturnog centra i Dvorane Franjo Krežma, s poveznicama na najave.',
    enabled: true,
  },
  {
    id: 'tz-obz',
    name: 'Turistička zajednica Osječko-baranjske županije',
    url: COUNTY_URL,
    description:
      'Službene pojedinačne najave županijskog kalendara; uvoze se samo događaji s potvrđenim gradom Osijekom.',
    enabled: true,
  },
  ...localSources,
  ...instagramSources,
];

export interface FetchOptions extends ReaderOptions {
  now?: Date;
  maxDetails?: number;
  maxListingPages?: number;
}

export async function fetchSource(id: string, options: FetchOptions = {}): Promise<FetchResult> {
  const source = sources.find((item) => item.id === id);
  if (!source) throw new Error('Nepoznat izvor događaja.');
  const now = options.now ?? new Date();
  // Instagram is read through Apify, not the page reader, and yields extraction pages only.
  if (isInstagramSource(id)) return fetchInstagramProfile(id, { ...options, now });
  const listing = await readSourcePage(source.url, options);
  if (localSources.some((item) => item.id === id)) {
    const result = emptyResult();
    result.pagesFetched = listing.cached ? 0 : 1;
    const reviewExternalIds: string[] = [];
    const grouped = new Map<string, LocalEntry[]>();
    const maxPages = Math.max(1, Math.min(2, options.maxListingPages ?? 2));
    let parsed = parseLocalListing(id, listing.html, now, source.url);
    for (let pageIndex = 0; ; pageIndex++) {
      result.discovered += parsed.discovered;
      result.skipped += parsed.skipped;
      result.warnings.push(...parsed.warnings);
      for (const entry of parsed.entries) {
        const previous = grouped.get(entry.url) ?? [];
        if (!previous.some((item) => item.startsAt === entry.startsAt)) previous.push(entry);
        grouped.set(entry.url, previous);
      }
      if (!parsed.nextPageUrl || pageIndex + 1 >= maxPages) break;
      try {
        const page = await readSourcePage(parsed.nextPageUrl, options);
        if (!page.cached) result.pagesFetched++;
        parsed = parseLocalListing(id, page.html, now, parsed.nextPageUrl);
      } catch (error) {
        result.warnings.push(
          `${source.name}: sljedeća stranica nije dostupna; već otkrivene najave ostaju u obradi (${error instanceof Error ? error.message : 'dohvat'}).`,
        );
        break;
      }
    }
    const limit = Math.max(0, Math.min(30, options.maxDetails ?? (id === 'dkolektiv' ? 24 : 20)));
    const entries = [...grouped.values()];
    if (entries.length > limit) {
      result.skipped += entries.length - limit;
      result.warnings.push(
        `${source.name}: ${entries.length - limit} najava čeka dohvat; ograničenje je ${limit} detaljnih stranica.`,
      );
    }
    for (const [index, group] of entries.slice(0, limit).entries()) {
      try {
        const page = await readSourcePage(group[0].url, options);
        if (!page.cached) result.pagesFetched++;
        const detail =
          id === 'hnk-osijek'
            ? parseHnkDetail(page.html, group, now)
            : id === 'coreevent-osijek'
              ? parseCoreEventDetail(page.html, group[0], now)
              : parseAnnouncement(id as 'gisko' | 'dkolektiv', page.html, group[0], now);
        result.events.push(...detail.events);
        result.warnings.push(...detail.warnings);
        reviewExternalIds.push(...detail.reviewExternalIds);
        if (!detail.events.length) result.skipped++;
      } catch (error) {
        if (
          error instanceof SourceDeadlineError ||
          Date.now() >= (options.deadlineMs ?? Infinity)
        ) {
          result.skipped += Math.min(entries.length, limit) - index;
          result.warnings.push(
            `${source.name}: vremensko ograničenje dohvata; preostale najave čekaju sljedeće pokretanje.`,
          );
          break;
        }
        result.skipped++;
        result.warnings.push(
          `${group[0].title}: ${error instanceof Error ? error.message : 'dohvat nije uspio'}`,
        );
      }
    }
    // These text-first adapters intentionally produce no AI extraction work or invented fallbacks.
    return { ...result, reviewExternalIds };
  }
  if (id === 'tz-osijek') {
    const result = parseTourismCalendar(listing.html, now);
    result.pagesFetched = listing.cached ? 0 : 1;
    return result;
  }
  const county = id === 'tz-obz';
  const label = county ? 'TZ OBŽ' : 'KC';
  const parsed = county ? parseCountyListing(listing.html, now) : parseKcListing(listing.html, now);
  const result = emptyResult();
  result.pagesFetched = listing.cached ? 0 : 1;
  result.discovered = parsed.discovered;
  result.skipped = parsed.skipped;
  result.warnings.push(...parsed.warnings);
  const limit = Math.max(0, Math.min(50, options.maxDetails ?? 30));
  if (parsed.entries.length > limit) {
    result.skipped += parsed.entries.length - limit;
    result.warnings.push(
      `${label}: ${parsed.entries.length - limit} budućih najava čeka dohvat; ograničenje je ${limit} detaljnih stranica po pokretanju.`,
    );
  }
  const entries = parsed.entries.slice(0, limit);
  for (const [index, entry] of entries.entries()) {
    try {
      checkSourceDeadline(options);
      const page = await readSourcePage(entry.url, options);
      if (!page.cached) result.pagesFetched++;
      const detail = county
        ? parseCountyDetail(page.html, entry, now)
        : parseKcDetail(page.html, entry);
      if (detail.event) result.events.push(detail.event);
      else result.skipped++;
      result.warnings.push(...detail.warnings);
      if (detail.extraction) addExtraction(result, detail.extraction.url, detail.extraction.text);
    } catch (error) {
      if (error instanceof SourceDeadlineError || Date.now() >= (options.deadlineMs ?? Infinity)) {
        const pending = entries.length - index;
        result.skipped += pending;
        result.warnings.push(
          `${label}: vremensko ograničenje dohvata; ${pending} najava čeka sljedeće pokretanje. Već dohvaćeni događaji bit će spremljeni.`,
        );
        break;
      }
      result.skipped++;
      result.warnings.push(
        `${entry.title}: ${error instanceof Error ? error.message : 'dohvat nije uspio'}`,
      );
      // County listing destination includes other towns. Do not label failed details as Osijek.
      if (!county)
        addExtraction(
          result,
          entry.url,
          `Naslov iz službenog popisa: ${entry.title}\nDatum početka iz izvora: ${entry.startsAt}\nDatum završetka iz izvora: ${entry.endsAt ?? 'nije naveden'}\nDetaljna stranica nije dostupna. Mjesto i cijena nisu poznati.`,
        );
    }
  }
  return result;
}
