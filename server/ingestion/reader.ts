import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, stat, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const HOSTS = new Set([
  'www.tzosijek.hr',
  'tzosijek.hr',
  'kulturni-centar.hr',
  'www.kulturni-centar.hr',
]);
const MAX_BYTES = 2 * 1024 * 1024;
const CACHE_MS = 6 * 60 * 60 * 1000;
let queue: Promise<unknown> = Promise.resolve();
let nextRequest = 0;

export function trustedSourceUrl(raw: string, base?: string): string {
  const url = new URL(raw, base);
  if (
    url.protocol !== 'https:' ||
    !HOSTS.has(url.hostname) ||
    url.port ||
    url.username ||
    url.password
  ) {
    throw new Error('Poveznica nije na popisu pouzdanih izvora.');
  }
  url.hash = '';
  return url.href;
}

export interface ReaderOptions {
  force?: boolean;
  cacheDir?: string;
  fetch?: typeof fetch;
}
export interface ReaderPage {
  html: string;
  cached: boolean;
  fetchedAt: string;
}

async function boundedText(response: Response): Promise<string> {
  if (Number(response.headers.get('content-length') || 0) > MAX_BYTES)
    throw new Error('Jina odgovor prelazi ograničenje od 2 MiB.');
  if (!response.body) throw new Error('Jina Reader vratio je prazan odgovor.');
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_BYTES) {
        await reader.cancel();
        throw new Error(
          'Jina odgovor prelazi ograničenje od 2 MiB; stranica nije skraćena ni uvezena.',
        );
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks).toString('utf8');
}

/** All source traffic goes through Jina Reader, including HTML for exact parsers. */
export async function readSourcePage(
  raw: string,
  options: ReaderOptions = {},
): Promise<ReaderPage> {
  const url = trustedSourceUrl(raw);
  const directory = options.cacheDir ?? process.env.WAGZ_FETCH_CACHE_DIR ?? 'data/source-cache';
  const path = join(directory, `${createHash('sha256').update(url).digest('hex')}.json`);
  if (!options.force) {
    try {
      if ((await stat(path)).size <= MAX_BYTES * 2) {
        const cached = JSON.parse(await readFile(path, 'utf8')) as {
          url: string;
          html: string;
          fetchedAt: string;
        };
        const age = Date.now() - Date.parse(cached.fetchedAt);
        if (
          cached.url === url &&
          typeof cached.html === 'string' &&
          age >= 0 &&
          age < CACHE_MS &&
          /<\/html\s*>/i.test(cached.html)
        ) {
          return { html: cached.html, fetchedAt: cached.fetchedAt, cached: true };
        }
      }
    } catch {
      /* Missing, stale and corrupt cache entries are fetched again. */
    }
  }
  const task = queue
    .catch(() => {})
    .then(async () => {
      const delay = Math.max(0, nextRequest - Date.now());
      if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
      nextRequest = Date.now() + 3100;
      const headers: Record<string, string> = {
        'x-respond-with': 'html',
        'x-cache-tolerance': options.force ? '0' : '3600',
        // Reject oversized pages. x-max-tokens would silently truncate them.
        'x-token-budget': '500000',
        accept: 'text/plain',
      };
      if (process.env.JINA_API_KEY) headers.authorization = `Bearer ${process.env.JINA_API_KEY}`;
      const response = await (options.fetch ?? fetch)(`https://r.jina.ai/${url}`, {
        headers,
        redirect: 'error',
        signal: AbortSignal.timeout(55000),
      });
      if (!response.ok) {
        await response.body?.cancel();
        throw new Error(
          `Jina Reader: HTTP ${response.status}. Izvor nije osvježen; prethodni događaji ostaju sačuvani.`,
        );
      }
      const html = await boundedText(response);
      if (!/<html[\s>]/i.test(html) || !/<\/html\s*>/i.test(html))
        throw new Error('Jina Reader nije vratio potpun HTML dokument.');
      const fetchedAt = new Date().toISOString();
      await mkdir(directory, { recursive: true });
      const temporary = `${path}.${randomUUID()}.tmp`;
      await writeFile(temporary, JSON.stringify({ url, html, fetchedAt }), 'utf8');
      await rename(temporary, path);
      return { html, fetchedAt, cached: false };
    });
  queue = task;
  return task;
}
