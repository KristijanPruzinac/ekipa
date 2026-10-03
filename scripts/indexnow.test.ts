import assert from 'node:assert/strict';
import test from 'node:test';
import { SITE_ORIGIN } from '../shared/site.ts';
import {
  INDEXNOW_ENDPOINT,
  INDEXNOW_KEY,
  MAX_URLS,
  notifyIndexNow,
  sitemapUrls,
} from './indexnow.ts';

const xml = (urls: string[]) =>
  `<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.map((url) => `<url><loc>${url}</loc></url>`).join('')}</urlset>`;
const published = [`${SITE_ORIGIN}/`, `${SITE_ORIGIN}/dogadaji/published-event`];

test('initial batch accepts only canonical same-origin public sitemap pages', () => {
  assert.deepEqual(sitemapUrls(xml([...published, published[0]])), published);
  for (const url of [
    'https://other.example/dogadaji/event',
    SITE_ORIGIN.replace('https:', 'http:') + '/',
    SITE_ORIGIN.replace('https://', 'https://user:password@') + '/',
    `${SITE_ORIGIN}/api/events`,
    `${SITE_ORIGIN}/ured-231b67e86427`,
    `${SITE_ORIGIN}/sitemap.xml`,
    `${SITE_ORIGIN}/share.png`,
    `${SITE_ORIGIN}/?activity=concert`,
    `${SITE_ORIGIN}/#events`,
    `${SITE_ORIGIN}/dogadaji/../`,
    `${SITE_ORIGIN}/dogadaji/%2e%2e`,
  ])
    assert.throws(() => sitemapUrls(xml([url])));
  assert.throws(() => sitemapUrls(xml(Array.from({ length: MAX_URLS + 1 }, () => published[0]))));
  assert.throws(() => sitemapUrls('<html><loc>https://example.com/</loc></html>'));
  assert.throws(() => sitemapUrls('<!DOCTYPE urlset>' + xml(published)));
});

function mockFetch(key = INDEXNOW_KEY, status = 200) {
  const calls: { url: string; init?: RequestInit }[] = [];
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init });
    if (url === INDEXNOW_ENDPOINT) return new Response(null, { status });
    return url.endsWith('.txt')
      ? new Response(key, { headers: { 'content-type': 'text/plain' } })
      : new Response(xml(published), { headers: { 'content-type': 'application/xml' } });
  }) as typeof fetch;
  return { calls, fetcher };
}

test('default dry run verifies live key and sitemap without notifying any engine', async () => {
  const { calls, fetcher } = mockFetch();
  const report = await notifyIndexNow(undefined, fetcher);
  assert.equal(report.mode, 'dry-run');
  assert.deepEqual(report.urls, published);
  assert.equal(calls.length, 2);
  assert.ok(calls.every(({ init }) => !init?.method && init?.redirect === 'error' && init.signal));
});

test('wrong live key prevents notification; explicit submit sends one bounded batch', async () => {
  const mismatch = mockFetch('different-key');
  await assert.rejects(notifyIndexNow(true, mismatch.fetcher), /matching public key/);
  assert.equal(mismatch.calls.length, 2);
  const accepted = mockFetch(INDEXNOW_KEY, 202);
  const report = await notifyIndexNow(true, accepted.fetcher);
  assert.match(report.result, /validation is pending/);
  const posts = accepted.calls.filter(({ init }) => init?.method === 'POST');
  assert.equal(posts.length, 1);
  assert.equal(posts[0].url, INDEXNOW_ENDPOINT);
  assert.equal(posts[0].init?.redirect, 'error');
  assert.deepEqual(JSON.parse(String(posts[0].init?.body)).urlList, published);
  const limited = mockFetch(INDEXNOW_KEY, 429);
  await assert.rejects(notifyIndexNow(true, limited.fetcher), /429.*no automatic retry/);
  assert.equal(limited.calls.length, 3);
});
