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

export const geocodeKey = (venue: string, city: string) =>
  `geo:v1:${normalize(venue)}|${normalize(city)}`;
export const cityKey = (city: string) => `geo:v1:city|${normalize(city)}`;

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
): Promise<(GeoPoint & { type: string }) | null> {
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
  return { lat, lon, type: String(row.addresstype ?? row.type ?? '') };
}

/** Returns a point only for a specific place inside the city; area-level hits are rejected. */
export async function geocodeVenue(
  venue: string,
  address: string | null,
  city: string,
  centre: GeoPoint,
  fetchImpl: typeof fetch = globalThis.fetch,
): Promise<GeoPoint | null> {
  const hit = await nominatim([venue, address, city].filter(Boolean).join(', '), fetchImpl);
  if (!hit || AREA_TYPES.has(hit.type) || distanceKm(hit, centre) > MAX_DISTANCE_KM) return null;
  return { lat: Number(hit.lat.toFixed(6)), lon: Number(hit.lon.toFixed(6)) };
}
