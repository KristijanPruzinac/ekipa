import { normalize } from './validation.ts';

/**
 * Venue geocoding through OpenStreetMap Nominatim (https://operations.osmfoundation.org/policies/nominatim/):
 * identified User-Agent, at most one request per second, results cached (also negative ones).
 * A venue is placed only when the hit is a specific place within the event's city, never the
 * city centre itself, so a vague venue gets no map rather than a wrong pin.
 */
export interface GeoPoint {
  lat: number;
  lon: number;
}
export interface GeoCacheEntry {
  lat?: number;
  lon?: number;
  none?: boolean;
  at: string;
}
const ENDPOINT = 'https://nominatim.openstreetmap.org/search';
const USER_AGENT = 'WagZ events calendar (https://wagz.com.hr)';
const AREA_TYPES = new Set([
  'city',
  'town',
  'village',
  'hamlet',
  'municipality',
  'county',
  'state',
  'region',
  'country',
  'postcode',
  'suburb',
  'city_district',
  'district',
  'borough',
  'quarter',
  'neighbourhood',
]);
export const MAX_DISTANCE_KM = 15;
export const NEGATIVE_RETRY_DAYS = 14;

export const GEO_PREFIX = 'geo:v2:';
export const geocodeKey = (venue: string, city: string) =>
  `${GEO_PREFIX}${normalize(venue)}|${normalize(city)}`;
export const cityKey = (city: string) => `${GEO_PREFIX}city|${normalize(city)}`;

export function distanceKm(a: GeoPoint, b: GeoPoint): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 12_742 * Math.asin(Math.sqrt(h));
}

export async function nominatim(
  query: string,
  fetchImpl: typeof fetch = globalThis.fetch,
): Promise<(GeoPoint & { type: string; name: string }) | null> {
  const url = new URL(ENDPOINT);
  url.searchParams.set('q', query);
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('limit', '1');
  const response = await fetchImpl(url, {
    headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
    signal: AbortSignal.timeout(10_000),
    redirect: 'error',
  });
  if (!response.ok) throw new Error(`Nominatim HTTP ${response.status}`);
  const rows = (await response.json()) as Array<Record<string, unknown>>;
  const row = Array.isArray(rows) ? rows[0] : undefined;
  if (!row) return null;
  const lat = Number(row.lat),
    lon = Number(row.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  return {
    lat,
    lon,
    type: String(row.addresstype ?? row.type ?? ''),
    name: `${String(row.name ?? '')} ${String(row.display_name ?? '')}`,
  };
}

const words = (text: string) =>
  normalize(text)
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
/** Inflected forms share a stem: compare the first five letters (or the whole short word). */
const stem = (word: string) => word.slice(0, 5);

/**
 * Nominatim matches loosely ("Gospodarska zona 10" can return "Gospodarski centar").
 * A hit counts only when every distinctive word of the query appears in the hit's name or
 * address, so a fuzzy neighbour never becomes a pin.
 */
export function namesMatch(query: string, hitName: string, city: string): boolean {
  const skip = new Set(words(city));
  const wanted = words(query).filter((w) => !skip.has(w) && (w.length >= 3 || /\d/.test(w)));
  if (!wanted.length) return false;
  const have = new Set(words(hitName).map(stem));
  return wanted.every((w) => have.has(stem(w)));
}

/**
 * Tries each query in order and returns the first specific place inside the city whose name
 * matches the query. Area-level, far-away and loosely matched hits are rejected.
 * `beforeRequest` paces requests (Nominatim allows one per second).
 */
export async function geocodeVenue(
  queries: string[],
  city: string,
  centre: GeoPoint,
  fetchImpl: typeof fetch = globalThis.fetch,
  beforeRequest: () => Promise<void> = async () => {},
): Promise<GeoPoint | null> {
  const seen = new Set<string>();
  for (const query of queries) {
    const key = normalize(query).trim();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    await beforeRequest();
    const hit = await nominatim(`${query}, ${city}`, fetchImpl);
    if (
      hit &&
      !AREA_TYPES.has(hit.type) &&
      distanceKm(hit, centre) <= MAX_DISTANCE_KM &&
      namesMatch(query, hit.name, city)
    )
      return { lat: Number(hit.lat.toFixed(6)), lon: Number(hit.lon.toFixed(6)) };
  }
  return null;
}
