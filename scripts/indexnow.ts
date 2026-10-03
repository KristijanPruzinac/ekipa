import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { load } from 'cheerio';
import { SITE_ORIGIN } from '../shared/site.ts';

// Public ownership proof, not an administrator credential. Keep the root file deployed.
export const INDEXNOW_KEY = 'c0eaa6f755a47ff632a1050e704ecdb2';
export const INDEXNOW_ENDPOINT = 'https://api.indexnow.org/indexnow';
export const MAX_URLS = 500;
const MAX_SITEMAP_BYTES = 256 * 1024;
const SITEMAP_URL = `${SITE_ORIGIN}/sitemap.xml`;
const KEY_LOCATION = `${SITE_ORIGIN}/${INDEXNOW_KEY}.txt`;

/** Initial launch only: take public page URLs from the deployed sitemap, never a database. */
export function sitemapUrls(xml: string): string[] {
  if (Buffer.byteLength(xml, 'utf8') > MAX_SITEMAP_BYTES || /<!DOCTYPE|<!ENTITY/i.test(xml))
    throw new Error('Sitemap is too large or contains unsupported XML declarations.');
  const $ = load(xml, { xmlMode: true });
  const root = $.root().children();
  const entries = root.children('url');
  if (
    root.length !== 1 ||
    root[0].tagName !== 'urlset' ||
    root.attr('xmlns') !== 'http://www.sitemaps.org/schemas/sitemap/0.9' ||
    root.children().length !== entries.length ||
    root.find('loc').length !== entries.length ||
    entries.length < 1 ||
    entries.length > MAX_URLS
  )
    throw new Error(`Expected a public URL sitemap with 1–${MAX_URLS} entries.`);
  const origin = new URL(SITE_ORIGIN);
  if (origin.protocol !== 'https:' || origin.origin !== SITE_ORIGIN)
    throw new Error('SITE_ORIGIN must be an explicit HTTPS origin.');
  const urls = entries.toArray().map((entry) => {
    const loc = $(entry).children('loc');
    if (loc.length !== 1 || loc.children().length) throw new Error('Invalid sitemap location.');
    const value = loc.text().trim();
    const url = new URL(value);
    if (
      url.protocol !== 'https:' ||
      url.origin !== SITE_ORIGIN ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      url.href !== value ||
      !(url.pathname === '/' || /^\/dogadaji\/[a-zA-Z0-9_-]{1,128}$/.test(url.pathname))
    )
      throw new Error('Sitemap contains a noncanonical or nonpublic page URL.');
    return value;
  });
  return [...new Set(urls)];
}

async function publicText(url: string, limit: number, mime: RegExp, fetcher: typeof fetch) {
  const response = await fetcher(url, { redirect: 'error', signal: AbortSignal.timeout(15_000) });
  if (response.status !== 200 || !mime.test(response.headers.get('content-type') ?? '')) {
    await response.body?.cancel();
    throw new Error(`Public verification GET failed (${response.status}) for ${url}.`);
  }
  if (Number(response.headers.get('content-length')) > limit) {
    await response.body?.cancel();
    throw new Error('Public verification response exceeds its size limit.');
  }
  if (!response.body) throw new Error('Public verification response is empty.');
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > limit) throw new Error('Public verification response exceeds its size limit.');
      chunks.push(value);
    }
    return new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks));
  } finally {
    await reader.cancel();
  }
}

/** No retries or scheduler: the caller deliberately chooses each initial notification. */
export async function notifyIndexNow(submit = false, fetcher: typeof fetch = fetch) {
  const localKey = await readFile(
    new URL(`../public/${INDEXNOW_KEY}.txt`, import.meta.url),
    'utf8',
  );
  if (localKey.trim() !== INDEXNOW_KEY) throw new Error('Local public key file does not match.');
  const [liveKey, xml] = await Promise.all([
    publicText(KEY_LOCATION, 256, /^text\/plain(?:;|$)/i, fetcher),
    publicText(SITEMAP_URL, MAX_SITEMAP_BYTES, /^(?:application|text)\/xml(?:;|$)/i, fetcher),
  ]);
  if (liveKey.trim() !== INDEXNOW_KEY)
    throw new Error('Deploy the matching public key before submitting.');
  const urls = sitemapUrls(xml);
  const report = {
    mode: submit ? 'submit' : 'dry-run',
    sitemap: SITEMAP_URL,
    endpoint: INDEXNOW_ENDPOINT,
    keyLocation: KEY_LOCATION,
    urlCount: urls.length,
    urls,
  };
  if (!submit) return { ...report, result: 'Verified; no submission sent.' };
  const response = await fetcher(INDEXNOW_ENDPOINT, {
    method: 'POST',
    redirect: 'error',
    signal: AbortSignal.timeout(15_000),
    headers: { 'content-type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      host: new URL(SITE_ORIGIN).host,
      key: INDEXNOW_KEY,
      keyLocation: KEY_LOCATION,
      urlList: urls,
    }),
  });
  await response.body?.cancel();
  if (response.status !== 200 && response.status !== 202)
    throw new Error(`IndexNow returned HTTP ${response.status}; no automatic retry was made.`);
  return {
    ...report,
    httpStatus: response.status,
    result:
      response.status === 202
        ? 'Received; search-engine key validation is pending. Crawling and indexing are not guaranteed.'
        : 'Received by IndexNow. Crawling and indexing are not guaranteed.',
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  if (args.length === 1 && args[0] === '--help') {
    console.log(
      'npm run indexnow -- [--dry-run | --submit]\nDefault: verify the live key and current sitemap without POSTing. Use --submit once for the new-domain launch; do not repeatedly submit unchanged URLs.',
    );
  } else if (
    args.length > 1 ||
    (args.length === 1 && !['--dry-run', '--submit'].includes(args[0]))
  ) {
    console.error('Use --dry-run (default) or --submit, with no URL or origin overrides.');
    process.exitCode = 1;
  } else {
    notifyIndexNow(args[0] === '--submit')
      .then((report) => console.log(JSON.stringify(report, null, 2)))
      .catch((error: unknown) => {
        console.error(error instanceof Error ? error.message : 'IndexNow verification failed.');
        process.exitCode = 1;
      });
  }
}
