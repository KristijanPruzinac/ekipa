import type { Request, Response } from 'express';
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
      return createApp(new WagzService(repository, { ...config, hosted: true }), {
        background: waitUntil,
      });
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
      .status(503)
      .json({ error: 'Usluga se trenutačno ne može spojiti na bazu. Pokušaj ponovno.' });
  }
}
