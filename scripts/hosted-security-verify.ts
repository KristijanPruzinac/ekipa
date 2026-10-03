import assert from 'node:assert/strict';
import { lookup, Resolver } from 'node:dns/promises';
import { get } from 'node:https';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { load } from 'cheerio';
import { ADMIN_PATH, SITE_ORIGIN, eventPath } from '../shared/site.ts';

// Operator-invoked, GET-only release check. No credentials, submissions or collection calls.
if (process.argv.length !== 4 || process.argv[2] !== '--release') {
  console.error('Usage: hosted-security-verify.ts --release <deployed-commit>');
  process.exit(1);
}
const release = process.argv[3];
assert.match(release, /^[a-f0-9]{7,40}$/);
interface Reply {
  status: number;
  body: string;
  headers: Record<string, string>;
}
const report = {
  checkedAt: new Date().toISOString(),
  release,
  method: 'GET',
  submissions: 0,
  collectionRequests: 0,
  providerCalls: 0,
  origins: [] as Array<Record<string, unknown>>,
  passed: true,
};
const origins = [SITE_ORIGIN, 'https://wagz.vercel.app'];
async function address(hostname: string) {
  try {
    return { ...(await lookup(hostname, { family: 4 })), resolver: 'system' };
  } catch {
    const resolver = new Resolver({ timeout: 5_000, tries: 1 });
    resolver.setServers(['8.8.8.8']);
    const [resolved] = await resolver.resolve4(hostname);
    if (!resolved) throw new Error('Hostname resolution failed.');
    return { address: resolved, family: 4, resolver: 'google-fallback' };
  }
}
for (const origin of origins) {
  const results: Array<Record<string, unknown>> = [];
  const entry: Record<string, unknown> = { origin, results, passed: false };
  report.origins.push(entry);
  let stage = 'DNS';
  try {
    const network = await address(new URL(origin).hostname);
    entry.resolver = network.resolver;
    entry.tlsCertificateValidation = true;
    async function request(path: string, originHeader?: string): Promise<Reply> {
      const url = new URL(path, origin);
      assert.equal(url.origin, origin, 'All requests must remain on the reviewed origin.');
      return new Promise((resolveReply, reject) => {
        const req = get(
          url,
          {
            signal: AbortSignal.timeout(20_000),
            headers: {
              'user-agent': 'WagZ-release-readonly-check/1.0',
              ...(originHeader === undefined ? {} : { origin: originHeader }),
            },
            // Keep the original hostname/SNI and normal TLS verification with either resolver.
            lookup: (_hostname, _options, callback) =>
              callback(null, [{ address: network.address, family: 4 }]),
          },
          (res) => {
            const chunks: Buffer[] = [];
            let size = 0;
            res.on('data', (chunk: Buffer) => {
              size += chunk.length;
              if (size > 4 * 1024 * 1024) {
                req.destroy(new Error('Unexpected response size.'));
                return;
              }
              chunks.push(chunk);
            });
            res.on('error', reject);
            res.on('end', () => {
              const body = Buffer.concat(chunks).toString('utf8');
              const headers = Object.fromEntries(
                [
                  'content-type',
                  'cache-control',
                  'content-security-policy',
                  'x-robots-tag',
                  'x-content-type-options',
                  'location',
                ].map((name) => [name, String(res.headers[name] ?? '')]),
              );
              const reply = { status: res.statusCode ?? 0, body, headers };
              results.push({
                path,
                ...(originHeader === undefined ? {} : { originHeader }),
                status: reply.status,
                bytes: size,
                sha256: createHash('sha256').update(body).digest('hex'),
                headers,
              });
              resolveReply(reply);
            });
          },
        );
        req.on('error', reject);
      });
    }
    function expect(reply: Reply, status: number, noIndex = false, noStore = true) {
      assert.equal(reply.status, status, `${stage}: status`);
      if (noStore) assert.match(reply.headers['cache-control'], /no-store/, `${stage}: cache`);
      assert.match(
        reply.headers['content-security-policy'],
        /script-src 'self'(?:;|$)/,
        `${stage}: script policy`,
      );
      assert.match(
        reply.headers['content-security-policy'],
        /frame-ancestors 'none'/,
        `${stage}: framing policy`,
      );
      assert.equal(
        reply.headers['x-content-type-options'],
        'nosniff',
        `${stage}: content type policy`,
      );
      if (noIndex) assert.match(reply.headers['x-robots-tag'], /noindex/, `${stage}: indexing`);
    }
    stage = 'public feed';
    const feedReply = await request('/api/events');
    expect(feedReply, 200, true);
    const feed = JSON.parse(feedReply.body);
    assert.ok(
      Array.isArray(feed.events) && feed.events.length > 0,
      'Public feed must have events.',
    );
    for (const event of feed.events)
      for (const privateField of [
        'publication',
        'manuallyEdited',
        'autoPublishEligible',
        'internalReviewNote',
      ])
        assert.ok(
          !Object.hasOwn(event, privateField),
          'Public projection excludes editorial fields.',
        );
    entry.events = feed.events.length;
    entry.sources = feed.meta.sourceCount;
    const event = feed.events[0] as { id: string; title: string };
    assert.equal(typeof event.id, 'string');
    entry.detailId = event.id;
    stage = 'homepage SSR';
    const home = await request('/');
    expect(home, 200);
    const $home = load(home.body);
    assert.ok($home('#root').children().length > 0, 'Homepage must have rendered content.');
    const data = JSON.parse($home('#wagz-page-data').text());
    assert.equal(data.kind, 'feed');
    assert.ok(data.feed.events.length > 0);
    assert.equal($home('link[rel="canonical"]').attr('href'), `${SITE_ORIGIN}/`);
    assert.equal(
      $home(`a[href^="${ADMIN_PATH}"]`).length,
      0,
      'Public navigation exposes no editor link.',
    );
    const asset = $home('script[src^="/assets/"]').first().attr('src');
    assert.ok(asset && /^\/assets\/[a-zA-Z0-9_.-]+\.js$/.test(asset));
    stage = 'built asset';
    assert.equal((await request(asset)).status, 200);
    stage = 'detail SSR';
    const detail = await request(eventPath(event.id));
    expect(detail, 200);
    const $detail = load(detail.body);
    assert.ok($detail('#root').text().includes(event.title));
    assert.equal(
      $detail('link[rel="canonical"]').attr('href'),
      `${SITE_ORIGIN}${eventPath(event.id)}`,
    );
    assert.equal(JSON.parse($detail('#wagz-page-data').text()).event.id, event.id);
    stage = 'detail API';
    const detailApi = await request(`/api/events/${encodeURIComponent(event.id)}`);
    expect(detailApi, 200, true);
    assert.equal(JSON.parse(detailApi.body).event.id, event.id);
    for (const path of [ADMIN_PATH, `${ADMIN_PATH}/`]) {
      stage = 'editor shell';
      const editor = await request(path);
      expect(editor, 200, true);
      const $editor = load(editor.body);
      assert.equal($editor('#wagz-page-data').length, 0);
      assert.equal($editor('#root').children().length, 0);
    }
    for (const path of ['/admin', '/admin/']) {
      stage = 'retired editor path';
      const old = await request(path);
      expect(old, 404, true);
      assert.equal(old.headers.location, '');
    }
    stage = 'anonymous admin denial';
    const denied = await request('/api/admin/dashboard');
    expect(denied, 401, true);
    assert.deepEqual(Object.keys(JSON.parse(denied.body)), ['error']);
    stage = 'native health and restricted runtime startup';
    const health = await request('/api/health');
    expect(health, 200, true);
    assert.equal(JSON.parse(health.body).ok, true);
    for (const [originHeader, status] of [
      [origin, 200],
      [origin.replace('https:', 'http:'), 403],
      [`${origin}:8443`, 403],
      ['null', 403],
      [`${origin}/`, 403],
    ] as const) {
      stage = `Origin ${status}`;
      expect(await request('/api/health', originHeader), status, true);
    }
    stage = 'sitemap';
    const sitemap = await request('/sitemap.xml');
    expect(sitemap, 200);
    const locations = [...sitemap.body.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
    assert.ok(locations.length > 1 && locations.every((url) => url.startsWith(`${SITE_ORIGIN}/`)));
    assert.ok(!sitemap.body.includes(ADMIN_PATH));
    entry.sitemapUrls = locations.length;
    entry.passed = true;
  } catch (error) {
    entry.failedStage = stage;
    entry.error = error instanceof Error ? error.message : 'Verification failed.';
    report.passed = false;
  }
}
await mkdir(resolve('.artifacts'), { recursive: true });
await writeFile(
  resolve('.artifacts/hosted-security-final-report.json'),
  JSON.stringify(report, null, 2),
);
console.log(JSON.stringify(report));
if (!report.passed) process.exitCode = 1;
