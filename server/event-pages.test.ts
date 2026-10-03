import test, { type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { AddressInfo } from 'node:net';
import { request as httpRequest } from 'node:http';
import { load } from 'cheerio';
import { createApp } from './app.ts';
import { mountPublicPages, PRODUCTION_CSP } from './public-pages.ts';
import { eventStructuredData, readPageTemplate } from './event-pages.ts';
import { ADMIN_PATH, SITE_ORIGIN, eventPath, publicSiteUrl } from '../shared/site.ts';
import type { EventCandidate, PublicPageData } from '../shared/types.ts';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';

const source = {
  id: 'test',
  name: 'Javna najava',
  url: 'https://example.org',
  description: '',
  enabled: true,
};
const candidate = (overrides: Partial<EventCandidate> = {}): EventCandidate => ({
  sourceId: source.id,
  externalId: 'future',
  sourceUrl: 'https://example.org/future',
  title: 'Radionica javnog programa',
  description: 'Otvorena radionica u Osijeku.',
  startsAt: '2099-10-10T20:00:00+02:00',
  endsAt: null,
  venue: 'Dvorana',
  address: null,
  city: 'Osijek',
  category: 'workshop',
  price: null,
  status: 'scheduled',
  ...overrides,
});

// Node's fetch transport can normalize Host back to the URL origin. Use a raw
// HTTP request so these regressions exercise the actual production Host header.
function fetchWithHost(
  url: string,
  options: { headers: Record<string, string>; method?: string; body?: string; redirect?: string },
): Promise<Response> {
  return new Promise((resolve, reject) => {
    const request = httpRequest(
      url,
      { method: options.method, headers: options.headers },
      (response) => {
        const headers = new Headers();
        for (const [key, values] of Object.entries(response.headers)) {
          for (const value of Array.isArray(values) ? values : values === undefined ? [] : [values])
            headers.append(key, value);
        }
        response.setEncoding('utf8');
        let body = '';
        response.on('data', (chunk: string) => {
          body += chunk;
        });
        response.on('end', () =>
          resolve(
            new Response(options.method === 'HEAD' ? null : body, {
              status: response.statusCode,
              headers,
            }),
          ),
        );
        response.on('error', reject);
      },
    );
    request.on('error', reject);
    request.end(options.body);
  });
}

async function fixture(context: TestContext, hosted = false) {
  const directory = await mkdtemp(join(tmpdir(), 'wagz-event-pages-'));
  await mkdir(join(directory, 'assets'));
  const template = (await readFile(new URL('../index.html', import.meta.url), 'utf8')).replace(
    '/src/main.tsx',
    '/assets/index-fixture.js',
  );
  await writeFile(join(directory, 'index.html'), template);
  await writeFile(join(directory, 'assets', 'index-fixture.js'), '/* fixture asset */');
  await writeFile(join(directory, 'sitemap.xml'), '<urlset><url>stale-static-file</url></urlset>');
  const repository = new Repository(':memory:', [source]);
  const service = new WagzService(repository, {
    host: '127.0.0.1',
    port: 0,
    databasePath: ':memory:',
    adminKey: 'isolated-pages-test',
    autoPublish: true,
    hosted,
    fetchOnStart: false,
    fetchIntervalMinutes: 360,
    ai: { apiKey: '', model: 'disabled', monthlyBudgetUsd: 0, searchEnabled: false },
  });
  const app = createApp(service);
  mountPublicPages(app, directory, repository);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((done) => server.once('listening', done));
  context.after(async () => {
    await new Promise<void>((done) => server.close(() => done()));
    await repository.close();
    assert.ok(directory.startsWith(join(tmpdir(), 'wagz-event-pages-')));
    await rm(directory, { recursive: true, force: true });
  });
  return {
    directory,
    repository,
    base: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
  };
}

test('legacy-host public documents remain available while metadata advertises the custom origin', async (context) => {
  const { base, repository } = await fixture(context, true);
  const event = await repository.upsert(candidate());
  const query = '?from=share&utm_content=ples%20i%20glazba&next=%2Fapi%2Fevents&tag=a&tag=b';
  for (const method of ['GET', 'HEAD']) {
    for (const path of [
      '/',
      eventPath(event.id),
      `${eventPath(event.id)}/`,
      '/robots.txt',
      '/sitemap.xml',
    ]) {
      const response = await fetchWithHost(base + path + query, {
        method,
        redirect: 'manual',
        headers: { host: 'wagz.vercel.app', 'x-forwarded-host': 'attacker.invalid' },
      });
      assert.equal(response.status, 200, `${method} ${path}`);
      assert.equal(response.headers.get('location'), null, `${method} ${path}`);
      if (method === 'GET') {
        const body = await response.text();
        if (path === '/robots.txt') {
          assert.match(body, /Sitemap: https:\/\/wagz\.com\.hr\/sitemap\.xml/);
        } else if (path === '/sitemap.xml') {
          const $ = load(body, { xml: true });
          assert.deepEqual(
            $('loc')
              .map((_, element) => $(element).text())
              .get(),
            ['https://wagz.com.hr/', `https://wagz.com.hr${eventPath(event.id)}`],
          );
        } else {
          const $ = load(body);
          const canonical =
            path === '/' ? 'https://wagz.com.hr/' : `https://wagz.com.hr${eventPath(event.id)}`;
          assert.equal($('link[rel="canonical"]').attr('href'), canonical);
          assert.equal($('meta[property="og:url"]').attr('content'), canonical);
        }
      }
    }
  }
  for (const host of [
    'wagz.com.hr',
    'www.wagz.com.hr',
    'localhost',
    '127.0.0.1:3000',
    'wagz-preview.vercel.app',
    'wagz.vercel.app.attacker.invalid',
    'wagz.vercel.app:8443',
  ]) {
    const response = await fetchWithHost(base + '/?from=share', {
      redirect: 'manual',
      headers: { host, 'x-forwarded-host': 'wagz.vercel.app' },
    });
    assert.equal(response.status, 200, host);
    assert.equal(response.headers.get('location'), null, host);
    const $ = load(await response.text());
    assert.equal($('link[rel="canonical"]').attr('href'), 'https://wagz.com.hr/');
  }
  for (const host of ['wagz.vercel.app', 'wagz.com.hr']) {
    for (const path of [ADMIN_PATH, `${ADMIN_PATH}/`]) {
      const response = await fetchWithHost(base + path + '?from=bookmark', {
        redirect: 'manual',
        headers: { host },
      });
      assert.equal(response.status, 200, `${host}${path}`);
      assert.equal(response.headers.get('location'), null);
      assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
      assert.equal(response.headers.get('cache-control'), 'no-store');
    }
  }
  for (const [path, status] of [
    ['/assets/index-fixture.js', 200],
    ['/unrecognized', 404],
    ['/admin', 404],
    ['/dogadaji/id/extra', 404],
  ] as const) {
    const response = await fetchWithHost(base + path, {
      redirect: 'manual',
      headers: { host: 'wagz.vercel.app' },
    });
    assert.equal(response.status, status, path);
    assert.equal(response.headers.get('location'), null, path);
  }
});

test('legacy-host APIs continue serving directly with same-origin requests and authorization', async (context) => {
  const { base, repository } = await fixture(context, true);
  const event = await repository.upsert(candidate());
  const headers = { host: 'wagz.vercel.app', origin: 'https://wagz.vercel.app' };
  for (const [path, status] of [
    ['/api/health', 200],
    ['/api/events?from=mobile', 200],
    [`/api/events/${event.id}`, 200],
    ['/api/not-a-route', 404],
    ['/api/admin/dashboard', 401],
  ] as const) {
    const response = await fetchWithHost(base + path, { headers, redirect: 'manual' });
    assert.equal(response.status, status, path);
    assert.equal(response.headers.get('location'), null, path);
    assert.match(response.headers.get('content-type')!, /application\/json/);
  }
  const admin = await fetchWithHost(base + '/api/admin/dashboard', {
    headers: { ...headers, authorization: 'Bearer isolated-pages-test' },
    redirect: 'manual',
  });
  assert.equal(admin.status, 200);
  assert.equal(admin.headers.get('location'), null);
  const tip = await fetchWithHost(base + '/api/tips', {
    method: 'POST',
    headers: { ...headers, 'content-type': 'application/json' },
    body: JSON.stringify({ note: 'Isolated legacy-host compatibility check.' }),
    redirect: 'manual',
  });
  assert.equal(tip.status, 201);
  assert.equal(tip.headers.get('location'), null);
  assert.equal((await repository.tips()).length, 1);
  const detail = await (await fetchWithHost(base + `/api/events/${event.id}`, { headers })).json();
  assert.deepEqual(detail.event, await repository.publicEvent(event.id));
});

test('static fallback metadata uses the same explicit custom origin as rendered pages', async () => {
  assert.equal(SITE_ORIGIN, 'https://wagz.com.hr');
  const $ = load(await readFile(new URL('../index.html', import.meta.url), 'utf8'));
  assert.equal($('link[rel="canonical"]').attr('href'), publicSiteUrl('/'));
  assert.equal($('meta[property="og:url"]').attr('content'), publicSiteUrl('/'));
  assert.equal($('meta[property="og:image"]').attr('content'), publicSiteUrl('/share.png'));
});

test('server-rendered feed and stable pages expose only published events, including their past records', async (context) => {
  const { base, repository } = await fixture(context);
  const future = await repository.upsert(candidate());
  const past = await repository.upsert(
    candidate({
      externalId: 'past',
      title: 'Prošla radionica',
      startsAt: '2020-01-01',
      endsAt: '2020-01-02',
    }),
  );
  const draft = await repository.upsert(
    candidate({ externalId: 'draft', title: 'Privatni nacrt' }),
    new Date(),
    true,
  );
  const rejected = await repository.upsert(
    candidate({ externalId: 'rejected', title: 'Odbijena najava' }),
  );
  await repository.editEvent(rejected.id, 'rejected');
  const home = await fetchWithHost(base + '/?from=share', {
    headers: { host: 'attacker.invalid', 'x-forwarded-host': 'attacker.invalid' },
  });
  assert.equal(home.status, 200);
  assert.equal(home.headers.get('content-security-policy'), PRODUCTION_CSP);
  const $home = load(await home.text());
  const homeDescription =
    'Pronađi koncerte, predstave, radionice i druga događanja u Osijeku. Datumi, lokacije i izvorne najave na jednom mjestu.';
  assert.equal($home('html').attr('lang'), 'hr');
  assert.equal($home('title').text(), 'Događaji u Osijeku | WagZ');
  assert.equal($home('meta[name="description"]').attr('content'), homeDescription);
  assert.equal($home('meta[property="og:title"]').attr('content'), $home('title').text());
  assert.equal($home('meta[property="og:description"]').attr('content'), homeDescription);
  assert.equal($home('h2#feed-title').text(), 'Događanja u Osijeku');
  const $fallback = load(await readFile(new URL('../index.html', import.meta.url), 'utf8'));
  assert.equal($fallback('title').text(), $home('title').text());
  assert.equal($fallback('meta[name="description"]').attr('content'), homeDescription);
  assert.equal($fallback('meta[property="og:description"]').attr('content'), homeDescription);
  assert.ok($home(`#root a[href="${eventPath(future.id)}"]`).length > 0);
  assert.match($home('#root').text(), /Radionica javnog programa/);
  assert.doesNotMatch($home('#root').text(), /Privatni nacrt|Odbijena najava|Prošla radionica/);
  assert.equal($home('link[rel="canonical"]').attr('href'), publicSiteUrl('/'));
  assert.equal($home('script[type="application/ld+json"]').length, 0, 'listing is not one Event');
  assert.equal($home('noscript').length, 0);
  const page = JSON.parse($home('#wagz-page-data').text()) as PublicPageData;
  assert.equal(page.kind, 'feed');
  assert.doesNotMatch(JSON.stringify(page), /publication|manuallyEdited|autoPublishEligible/);

  const detail = await fetch(base + eventPath(future.id));
  assert.equal(detail.status, 200);
  const $detail = load(await detail.text());
  assert.equal($detail('title').text(), `${future.title} — WagZ`);
  assert.equal($detail('title').length, 1);
  assert.equal($detail('meta[name="description"]').length, 1);
  assert.equal($detail('meta[name="description"]').attr('content'), future.description);
  assert.equal($detail('html').attr('lang'), 'hr');
  assert.equal($detail('link[rel="canonical"]').attr('href'), publicSiteUrl(eventPath(future.id)));
  assert.equal(
    $detail('meta[property="og:url"]').attr('content'),
    publicSiteUrl(eventPath(future.id)),
  );
  assert.equal($detail('h1').text(), future.title);
  assert.ok($detail('a[href="https://example.org/future"]').length > 0);
  const schema = JSON.parse($detail('script[type="application/ld+json"]').text());
  assert.equal(schema.name, future.title);
  assert.equal(schema.startDate, future.startsAt);
  assert.equal(schema.location.name, future.venue);
  assert.equal(schema.location.address.addressLocality, 'Osijek');
  for (const unknown of ['image', 'offers', 'organizer', 'endDate'])
    assert.equal(schema[unknown], undefined);
  assert.equal(schema.location.address.streetAddress, undefined);
  const old = await fetch(base + eventPath(past.id));
  assert.equal(old.status, 200);
  const $old = load(await old.text());
  assert.match($old('.event-past').text(), /Događaj je završio/);
  assert.equal($old('script[type="application/ld+json"]').length, 0);
  assert.equal($old('link[rel="canonical"]').attr('href'), publicSiteUrl(eventPath(past.id)));
  for (const event of [future, past]) {
    const response = await fetch(`${base}/api/events/${event.id}`);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    const payload = await response.json();
    assert.deepEqual(payload.event, await repository.publicEvent(event.id));
    assert.equal(payload.meta.timezone, 'Europe/Zagreb');
    assert.equal(payload.event.sources[0].sourceName, source.name);
    assert.doesNotMatch(JSON.stringify(payload), /publication|manuallyEdited|autoPublishEligible/);
  }
  for (const id of [draft.id, rejected.id, 'unknown']) {
    const response = await fetch(base + eventPath(id));
    assert.equal(response.status, 404);
    assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
    assert.equal(await response.text(), 'Događaj nije pronađen.');
    const json = await fetch(`${base}/api/events/${id}`);
    assert.equal(json.status, 404);
    assert.deepEqual(await json.json(), { error: 'Događaj nije pronađen.' });
  }
  const sitemap = await fetch(base + '/sitemap.xml');
  assert.match(sitemap.headers.get('content-type')!, /application\/xml/);
  const xml = await sitemap.text();
  assert.ok(xml.includes(future.id));
  for (const absent of [past.id, draft.id, rejected.id, 'stale-static-file'])
    assert.ok(!xml.includes(absent));
  assert.ok(
    (await (await fetch(base + '/robots.txt')).text()).includes(publicSiteUrl('/sitemap.xml')),
  );
  await repository.editEvent(future.id, 'draft');
  assert.equal(
    (await fetch(base + eventPath(future.id))).status,
    404,
    'cached build never caches publication',
  );
  await repository.editEvent(draft.id, 'published');
  assert.equal(
    (await fetch(base + eventPath(draft.id))).status,
    200,
    'previous 404 does not persist',
  );
});

test('HTML and non-executable JSON safely preserve hostile titles and replacement tokens', async (context) => {
  const { base, repository } = await fixture(context);
  const title = 'Predstava $& </script><img src=x onerror=alert(1)> & "publika"';
  const event = await repository.upsert(candidate({ title }));
  const response = await fetch(base + eventPath(event.id));
  assert.equal(response.status, 200);
  const html = await response.text();
  const $ = load(html);
  assert.equal($('h1').text(), title);
  assert.equal($('title').text(), `${title} — WagZ`);
  assert.equal($('img[src="x"], [onerror]').length, 0);
  assert.equal($('script').length, 3);
  assert.equal(JSON.parse($('#wagz-page-data').text()).event.title, title);
  assert.equal(JSON.parse($('script[type="application/ld+json"]').text()).name, title);
  assert.ok(!html.includes('</script><img'));
  assert.ok(html.includes('\\u003c/script\\u003e'));
});

test('invalid builds and database outages return generic 503/no-store/noindex and can recover', async (context) => {
  const { base, repository, directory } = await fixture(context);
  const template = await readFile(join(directory, 'index.html'), 'utf8');
  await writeFile(join(directory, 'index.html'), '<div id="root"></div>');
  for (const broken of ['template', 'asset']) {
    if (broken === 'asset')
      await writeFile(
        join(directory, 'index.html'),
        template.replace('index-fixture.js', '../missing.js'),
      );
    const response = await fetch(base + '/');
    assert.equal(response.status, 503, broken);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
    assert.equal(await response.text(), 'Usluga trenutačno nije dostupna. Pokušaj ponovno.');
  }
  await writeFile(join(directory, 'index.html'), template);
  assert.equal((await fetch(base + '/')).status, 200);
  context.mock.method(repository, 'publicEvents', async () => {
    throw new Error('private-database-path-or-credential');
  });
  for (const path of ['/', '/sitemap.xml']) {
    const response = await fetch(base + path);
    assert.equal(response.status, 503);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
    assert.doesNotMatch(await response.text(), /private-database|Error|\.ts/);
  }
  assert.equal((await fetch(base + ADMIN_PATH)).status, 200);
});

test('malformed URL decoding returns generic errors before a public route can run', async (context) => {
  const { base } = await fixture(context);
  for (const path of ['/dogadaji/%E0%A4%A', '/assets/%E0%A4%A', '/%E0%A4%A']) {
    const response = await fetch(base + path);
    assert.equal(response.status, 400, path);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
    assert.equal(response.headers.get('content-security-policy'), PRODUCTION_CSP);
    assert.equal(await response.text(), 'Neispravna adresa.');
  }
});

test('structured data retains date-only dates and cancellation without inventing facts', async () => {
  const repository = new Repository(':memory:', [source]);
  try {
    const record = await repository.upsert(
      candidate({ startsAt: '2099-10-10', status: 'cancelled' }),
    );
    const event = (await repository.publicEvent(record.id))!;
    const schema = eventStructuredData(event, new Date('2099-10-09T22:30:00Z'))!;
    assert.equal(schema.startDate, '2099-10-10');
    assert.equal(schema.eventStatus, 'https://schema.org/EventCancelled');
    assert.equal(eventStructuredData({ ...event, venue: null }, new Date('2099-10-09')), null);
    assert.equal(
      eventStructuredData(event, new Date('2099-10-10T22:01:00Z')),
      null,
      'Zagreb next day',
    );
  } finally {
    await repository.close();
  }
});

test('template loader requires metadata/root markers and actual local build assets', async (context) => {
  const { directory } = await fixture(context);
  const template = await readPageTemplate(directory);
  assert.ok(template.includes('/assets/index-fixture.js'));
  await writeFile(
    join(directory, 'index.html'),
    template.replace('/assets/index-fixture.js', '/src/main.tsx'),
  );
  await assert.rejects(readPageTemplate(directory), /Public build is unavailable/);
});

test('Vercel bundles the Vite output and routes public HTML and sitemap through SSR', async () => {
  const config = JSON.parse(await readFile(new URL('../vercel.json', import.meta.url), 'utf8'));
  assert.equal(config.functions['api/index.ts'].includeFiles, '{dist,.wagz-server}/**');
  // Explicit routes run before filesystem matching; a rewrite would lose to index.html.
  const homepage = config.routes.find((route: { src: string }) => route.src === '^/$');
  assert.equal(homepage.dest, '/api');
  const globalHeaders = config.headers.find(
    (route: { source: string }) => route.source === '/(.*)',
  );
  assert.deepEqual(
    homepage.headers,
    Object.fromEntries(
      globalHeaders.headers.map(({ key, value }: { key: string; value: string }) => [key, value]),
    ),
    'root headers also cover function initialization failures before application middleware',
  );
  assert.equal(
    config.rewrites.some((rewrite: { source: string }) => rewrite.source === '/'),
    false,
  );
  for (const source of ['/dogadaji/:id', '/sitemap.xml', '/robots.txt']) {
    assert.equal(
      config.rewrites.find((rewrite: { source: string }) => rewrite.source === source).destination,
      '/api',
    );
  }
  assert.deepEqual(
    config.redirects.find((redirect: { source: string }) => redirect.source === '/index.html'),
    { source: '/index.html', destination: '/', permanent: true },
  );
  for (const source of [ADMIN_PATH, `${ADMIN_PATH}/`]) {
    assert.equal(
      config.rewrites.find((rewrite: { source: string }) => rewrite.source === source).destination,
      '/index.html',
    );
  }
  assert.equal(
    config.rewrites.some((route: { source: string }) => /^\/admin\/?$/.test(route.source)),
    false,
  );
  for (const source of [`${ADMIN_PATH}/:path*`, `${ADMIN_PATH}/`, '/admin/:path*', '/admin/']) {
    const headers = config.headers.find(
      (route: { source: string }) => route.source === source,
    ).headers;
    assert.equal(
      headers.find((header: { key: string }) => header.key === 'Cache-Control').value,
      'no-store',
    );
    assert.equal(
      headers.find((header: { key: string }) => header.key === 'X-Robots-Tag').value,
      'noindex, nofollow',
    );
  }
});
