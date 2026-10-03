import type { FetchResult, SourceDefinition } from '../../shared/types.ts';
import { emptyResult } from './parsers.ts';
import { checkSourceDeadline, type ReaderOptions } from './reader.ts';

/**
 * Instagram announcements through Apify's hosted scraper (no Instagram login is used or stored).
 *
 * The adapter produces text-only extraction pages, one per recent post. Dates, venues and prices
 * come exclusively from the existing AI extraction stage, which accepts a fact only when the
 * caption itself contains a supporting quote with an explicit year. Dates printed only on a
 * poster image, or captions without a year, are therefore rejected by design, never guessed.
 * Events from these sources are always held as drafts for review (see isInstagramSource).
 */
export const APIFY_ACTOR = 'apify~instagram-scraper';
const ENDPOINT = `https://api.apify.com/v2/acts/${APIFY_ACTOR}/run-sync-get-dataset-items`;
export const DEFAULT_POSTS_PER_PROFILE = 5;
export const MAX_POSTS_PER_PROFILE = 5;
export const DEFAULT_MAX_COST_USD = 0.1;
const MAX_POST_AGE_DAYS = 60;
const MAX_CAPTION_CHARS = 4000;
const MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
const REQUEST_TIMEOUT_MS = 150_000;
const POST_URL = /^https:\/\/www\.instagram\.com\/(p|reel)\/([A-Za-z0-9_-]{5,40})\/?$/;
const HANDLE = /^[A-Za-z0-9._]{1,30}$/;

export interface InstagramProfile {
  id: string;
  handle: string;
  name: string;
  organiser: string;
}
/** Add a profile only once its handle is confirmed; a handle is never guessed. */
export const instagramProfiles: readonly InstagramProfile[] = [
  {
    id: 'instagram-dd',
    handle: 'plesni_klub_dd',
    name: 'Plesni klub D&D (Instagram)',
    organiser: 'Plesni klub D&D',
  },
];

export const instagramSources: SourceDefinition[] = instagramProfiles.map((profile) => ({
  id: profile.id,
  name: profile.name,
  url: `https://www.instagram.com/${profile.handle}/`,
  description:
    'Javne objave profila putem Apify čitača, najviše pet najnovijih po pokretanju. Datum se prihvaća samo ako ga tekst objave izričito navodi s godinom; datumi samo na plakatu ostaju nečitljivi. Događaji čekaju pregled.',
  // Off until an Apify token is configured; no token means no request and no cost.
  enabled: Boolean(process.env.APIFY_TOKEN),
}));

export const isInstagramSource = (id: string) =>
  instagramProfiles.some((profile) => profile.id === id);

export interface InstagramOptions extends ReaderOptions {
  now?: Date;
  token?: string;
  postsPerProfile?: number;
  maxCostUsd?: number;
}

const controlCharacters = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g;

function bounded(value: number | undefined, fallback: number, min: number, max: number): number {
  return value !== undefined && Number.isFinite(value)
    ? Math.min(max, Math.max(min, Math.floor(value)))
    : fallback;
}

export async function fetchInstagramProfile(
  id: string,
  options: InstagramOptions = {},
): Promise<FetchResult> {
  const profile = instagramProfiles.find((item) => item.id === id);
  if (!profile || !HANDLE.test(profile.handle)) throw new Error('Nepoznat Instagram izvor.');
  const token = options.token ?? process.env.APIFY_TOKEN;
  if (!token || /\s/.test(token))
    throw new Error('Apify token nije postavljen; Instagram nije dohvaćen.');
  const posts = bounded(
    options.postsPerProfile ??
      (process.env.WAGZ_INSTAGRAM_POSTS ? Number(process.env.WAGZ_INSTAGRAM_POSTS) : undefined),
    DEFAULT_POSTS_PER_PROFILE,
    1,
    MAX_POSTS_PER_PROFILE,
  );
  const maxCost =
    options.maxCostUsd ??
    (process.env.WAGZ_APIFY_MAX_COST_USD
      ? Number(process.env.WAGZ_APIFY_MAX_COST_USD)
      : DEFAULT_MAX_COST_USD);
  if (!Number.isFinite(maxCost) || maxCost <= 0 || maxCost > 1)
    throw new Error('Apify ograničenje troška nije valjano (dopušteno do 1 USD).');
  checkSourceDeadline(options);
  const now = options.now ?? new Date();
  const timeoutMs = Math.max(
    1,
    Math.min(REQUEST_TIMEOUT_MS, Math.floor((options.deadlineMs ?? Infinity) - Date.now())),
  );
  const url = new URL(ENDPOINT);
  // A run that would exceed this ceiling is stopped by Apify, never silently billed further.
  url.searchParams.set('maxTotalChargeUsd', String(maxCost));
  url.searchParams.set('timeout', String(Math.min(120, Math.ceil(timeoutMs / 1000))));
  const response = await (options.fetch ?? globalThis.fetch)(url, {
    method: 'POST',
    // The token travels only in this header, never in a URL that could reach logs.
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      directUrls: [`https://www.instagram.com/${profile.handle}/`],
      resultsType: 'posts',
      resultsLimit: posts,
    }),
    signal: AbortSignal.timeout(timeoutMs),
    redirect: 'error',
  });
  if (response.status !== 200 && response.status !== 201) {
    await response.body?.cancel();
    throw new Error(
      `Apify nije vratio podatke (HTTP ${response.status}); Instagram nije dohvaćen.`,
    );
  }
  if (Number(response.headers.get('content-length') || 0) > MAX_RESPONSE_BYTES) {
    await response.body?.cancel();
    throw new Error('Apify odgovor je prevelik; Instagram nije dohvaćen.');
  }
  const raw = await response.text();
  if (Buffer.byteLength(raw) > MAX_RESPONSE_BYTES)
    throw new Error('Apify odgovor je prevelik; Instagram nije dohvaćen.');
  let items: unknown;
  try {
    items = JSON.parse(raw);
  } catch {
    throw new Error('Apify je vratio neispravan odgovor; Instagram nije dohvaćen.');
  }
  if (!Array.isArray(items))
    throw new Error('Apify je vratio neispravan odgovor; Instagram nije dohvaćen.');

  const result = emptyResult();
  result.pagesFetched = 1;
  result.discovered = items.length;
  const seen = new Set<string>();
  const usable: Array<{ url: string; caption: string; at: number }> = [];
  let foreign = 0,
    textless = 0,
    stale = 0;
  for (const item of items) {
    if (!item || typeof item !== 'object') {
      result.skipped++;
      continue;
    }
    const row = item as Record<string, unknown>;
    const match = typeof row.url === 'string' ? row.url.match(POST_URL) : null;
    const at = typeof row.timestamp === 'string' ? Date.parse(row.timestamp) : NaN;
    if (!match || !Number.isFinite(at) || seen.has(match[2])) {
      result.skipped++;
      continue;
    }
    seen.add(match[2]);
    if (
      typeof row.ownerUsername === 'string' &&
      row.ownerUsername.toLowerCase() !== profile.handle.toLowerCase()
    ) {
      foreign++;
      continue;
    }
    if (now.getTime() - at > MAX_POST_AGE_DAYS * 86_400_000) {
      stale++;
      continue;
    }
    const caption =
      typeof row.caption === 'string'
        ? row.caption.replace(controlCharacters, ' ').trim().slice(0, MAX_CAPTION_CHARS)
        : '';
    if (!caption) {
      textless++;
      continue;
    }
    usable.push({ url: `https://www.instagram.com/${match[1]}/${match[2]}/`, caption, at });
  }
  usable.sort((a, b) => b.at - a.at);
  for (const post of usable.slice(0, posts))
    result.extractionPages.push({
      url: post.url,
      // Captions are untrusted DATA for the extraction stage. The publication date is left out
      // on purpose: it must never be mistaken for the date of the announced event.
      text: `Instagram objava profila @${profile.handle} (${profile.organiser}).\n\n${post.caption}`,
    });
  result.skipped += foreign + textless + stale + Math.max(0, usable.length - posts);
  if (textless)
    result.warnings.push(
      `${profile.name}: ${textless} objava nema tekst; datum otisnut samo na slici nije čitljiv i ne uvozi se.`,
    );
  if (foreign)
    result.warnings.push(
      `${profile.name}: ${foreign} objava pripada drugom računu (suradnja ili oznaka) i preskočena je.`,
    );
  return result;
}
