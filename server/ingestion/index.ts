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
];

export interface FetchOptions extends ReaderOptions {
  now?: Date;
  maxDetails?: number;
}

export async function fetchSource(id: string, options: FetchOptions = {}): Promise<FetchResult> {
  const source = sources.find((item) => item.id === id);
  if (!source) throw new Error('Nepoznat izvor događaja.');
  const now = options.now ?? new Date();
  const listing = await readSourcePage(source.url, options);
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
