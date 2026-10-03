import type { Request, Response } from 'express';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { waitUntil } from '@vercel/functions';
import { config } from '../server/config.ts';
import { sources } from '../server/ingestion/index.ts';
import { createRepository } from '../server/repository.ts';
import { WagzService } from '../server/service.ts';
import { createApp } from '../server/app.ts';

// Source files are a disposable fetching cache. All application data and AI accounting live in Postgres.
process.env.WAGZ_FETCH_CACHE_DIR = '/tmp/wagz-source-cache';
let app: Promise<ReturnType<typeof createApp>> | undefined;
function application() {
  if (!app)
    app = (async () => {
      if (!config.databaseUrl) throw new Error('Hosted database is not configured.');
      const repository = await createRepository(
        config.databasePath,
        sources,
        config.autoPublish,
        config.databaseUrl,
      );
      const application = createApp(new WagzService(repository, { ...config, hosted: true }), {
        background: waitUntil,
      });
      // Vite compiles and bundles the SSR TSX graph independently of Vercel's file tracer.
      // The bundle stays outside the public asset directory and contains no server config.
      const { mountPublicPages } = (await import(
        pathToFileURL(resolve('.wagz-server/public-pages.js')).href
      )) as typeof import('../server/public-pages.ts');
      mountPublicPages(application, resolve('dist'), repository);
      return application;
    })().catch((error) => {
      app = undefined;
      throw error;
    });
  return app;
}

export default async function handler(request: Request, response: Response) {
  try {
    (await application())(request, response);
  } catch {
    response
      .set('Cache-Control', 'no-store')
      .set('X-Robots-Tag', 'noindex, nofollow')
      .status(503)
      .json({ error: 'Usluga se trenutačno ne može spojiti na bazu. Pokušaj ponovno.' });
  }
}
