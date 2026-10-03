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
import { readSourcePage, type ReaderOptions } from './reader.ts';

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
  const parsed = parseKcListing(listing.html, now);
  const result = emptyResult();
  result.pagesFetched = listing.cached ? 0 : 1;
  result.discovered = parsed.discovered;
  result.skipped = parsed.skipped;
  result.warnings.push(...parsed.warnings);
  const limit = Math.max(0, Math.min(50, options.maxDetails ?? 30));
  if (parsed.entries.length > limit) {
    result.skipped += parsed.entries.length - limit;
    result.warnings.push(
      `KC: ${parsed.entries.length - limit} budućih najava čeka dohvat; ograničenje je ${limit} detaljnih stranica po pokretanju.`,
    );
  }
  for (const entry of parsed.entries.slice(0, limit)) {
    try {
      const page = await readSourcePage(entry.url, options);
      if (!page.cached) result.pagesFetched++;
      const detail = parseKcDetail(page.html, entry);
      result.events.push(detail.event);
      result.warnings.push(...detail.warnings);
      if (detail.extraction) addExtraction(result, detail.extraction.url, detail.extraction.text);
    } catch (error) {
      result.skipped++;
      result.warnings.push(
        `${entry.title}: ${error instanceof Error ? error.message : 'dohvat nije uspio'}`,
      );
      addExtraction(
        result,
        entry.url,
        `Naslov iz službenog popisa: ${entry.title}\nDatum početka iz izvora: ${entry.startsAt}\nDatum završetka iz izvora: ${entry.endsAt ?? 'nije naveden'}\nDetaljna stranica nije dostupna. Mjesto i cijena nisu poznati.`,
      );
    }
  }
  return result;
}
