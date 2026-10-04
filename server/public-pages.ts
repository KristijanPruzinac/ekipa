import { resolve } from 'node:path';
import express, { type ErrorRequestHandler, type Express } from 'express';
import { ADMIN_PATH, publicSiteUrl } from '../shared/site.ts';
import { readPageTemplate, renderPublicPage, renderSitemap } from './event-pages.ts';
import { publicFeed } from './public-data.ts';
import type { Repository } from './repository.ts';

// Keep the production host's matching header in vercel.json aligned with this policy.
// Timeline geometry uses inline styles; application scripts remain same-origin only.
export const PRODUCTION_CSP =
  "default-src 'self'; script-src 'self'; connect-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://*.basemaps.cartocdn.com; object-src 'none'; base-uri 'none'; frame-src 'none'; frame-ancestors 'none'; form-action 'self'";

/** Serve only the public app's real routes; missing pages must not become homepage duplicates. */
export function mountPublicPages(app: Express, directory: string, repository: Repository) {
  const root = resolve(directory);
  let template: Promise<string> | undefined;
  const pageTemplate = () =>
    (template ??= readPageTemplate(root).catch((error) => {
      template = undefined;
      throw error;
    }));
  app.use((_req, res, next) => {
    res.set('Content-Security-Policy', PRODUCTION_CSP);
    next();
  });
  // Keep the legacy hostname available while public DNS caches settle. Canonical
  // URLs still use the explicit site origin; enable the prepared redirect later.
  app.get([ADMIN_PATH, `${ADMIN_PATH}/`], (_req, res) => {
    res.set('X-Robots-Tag', 'noindex, nofollow');
    res.set('Cache-Control', 'no-store');
    res.sendFile('index.html', { root });
  });
  app.get('/index.html', (_req, res) => res.redirect(308, '/'));
  app.get('/robots.txt', (_req, res) => {
    res.type('text').send(`User-agent: *\nAllow: /\n\nSitemap: ${publicSiteUrl('/sitemap.xml')}\n`);
  });
  app.get('/sitemap.xml', async (_req, res) => {
    res.set('Cache-Control', 'no-store');
    try {
      res.type('application/xml').send(renderSitemap(await repository.publicEvents()));
    } catch {
      res
        .set('X-Robots-Tag', 'noindex, nofollow')
        .status(503)
        .type('text')
        .send('Usluga trenutačno nije dostupna. Pokušaj ponovno.');
    }
  });
  app.get(['/', '/dogadaji/:id'], async (req, res) => {
    res.set('Cache-Control', 'no-store');
    try {
      const now = new Date();
      const id = req.params.id;
      const event = id ? await repository.publicEvent(String(id)) : null;
      if (id && !event) {
        res
          .set('X-Robots-Tag', 'noindex, nofollow')
          .status(404)
          .type('text')
          .send('Događaj nije pronađen.');
        return;
      }
      const page = event
        ? { kind: 'event' as const, event, now: now.toISOString() }
        : { kind: 'feed' as const, feed: await publicFeed(repository, now) };
      res.type('html').send(renderPublicPage(await pageTemplate(), page));
    } catch {
      res
        .set('X-Robots-Tag', 'noindex, nofollow')
        .status(503)
        .type('text')
        .send('Usluga trenutačno nije dostupna. Pokušaj ponovno.');
    }
  });
  app.use(express.static(root, { index: false }));
  app.get('/{*path}', (_req, res) => {
    res.set('X-Robots-Tag', 'noindex, nofollow');
    res.set('Cache-Control', 'no-store');
    res.status(404).type('text').send('Stranica nije pronađena.');
  });
  // Route decoding and static-file failures can happen before a page handler runs.
  const errors: ErrorRequestHandler = (error, _req, res, next) => {
    if (res.headersSent) {
      next(error);
      return;
    }
    res
      .set('Cache-Control', 'no-store')
      .set('X-Robots-Tag', 'noindex, nofollow')
      .status(error instanceof URIError ? 400 : 503)
      .type('text')
      .send(
        error instanceof URIError
          ? 'Neispravna adresa.'
          : 'Usluga trenutačno nije dostupna. Pokušaj ponovno.',
      );
  };
  app.use(errors);
}
