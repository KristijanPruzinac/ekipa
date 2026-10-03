import express, { type ErrorRequestHandler } from 'express';
import { timingSafeEqual } from 'node:crypto';
import { WagzService } from './service.ts';
import { TIMEZONE, ValidationError } from './validation.ts';

export function createApp(service: WagzService) {
  const app = express();
  app.disable('x-powered-by');
  app.use((_request, response, next) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('X-Frame-Options', 'DENY');
    response.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    next();
  });
  app.use('/api', express.json({ limit: '24kb' }));
  app.use('/api', (request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    const origin = request.get('origin');
    if (origin && new URL(origin).host !== request.get('host')) {
      response.status(403).json({ error: 'Zahtjev nije poslan s ove aplikacije.' });
      return;
    }
    next();
  });
  const limits = new Map<string, { count: number; until: number }>();
  function allowed(key: string, count: number, minutes: number) {
    const now = Date.now();
    for (const [id, entry] of limits) if (entry.until <= now) limits.delete(id);
    const entry = limits.get(key) ?? { count: 0, until: now + minutes * 60000 };
    entry.count++;
    limits.set(key, entry);
    return entry.count <= count;
  }
  app.get('/api/health', (_req, res) => res.json({ ok: true, collecting: service.collecting }));
  app.get('/api/events', (_req, res) => {
    const now = new Date();
    const events = service.repo.publicEvents(now);
    res.json({
      events,
      meta: {
        city: 'Osijek',
        timezone: TIMEZONE,
        now: now.toISOString(),
        lastCheckedAt:
          service.repo.runs().find((run) => ['success', 'partial'].includes(run.status))
            ?.finishedAt ?? null,
        sourceCount: service.repo.sources.filter((source) => source.enabled).length,
        totalUpcoming: events.length,
      },
    });
  });
  app.post('/api/tips', (req, res) => {
    if (!allowed(`tips:${req.ip}`, 5, 60)) {
      res.status(429).json({ error: 'Previše dojava u kratkom vremenu. Pokušaj ponovno kasnije.' });
      return;
    }
    const tip = service.submitTip(req.body ?? {});
    if (tip.status === 'inbox')
      void service.prepareTip(tip.id).catch(() => {
        /* Original tip is safely persisted; operator can retry. */
      });
    res.status(201).json({ ok: true, message: 'Hvala! Tvoja dojava je spremljena za provjeru.' });
  });
  app.use('/api/admin', (req, res, next) => {
    const expected = service.config.adminKey;
    const token = req.get('authorization')?.replace(/^Bearer /, '') ?? '';
    if (!expected) {
      res.status(503).json({
        error:
          'Admin ključ nije postavljen. Pokreni npm run admin-key i ponovno pokreni aplikaciju.',
      });
      return;
    }
    const a = Buffer.from(token),
      b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      const withinLimit = allowed(`auth:${req.ip}`, 30, 15);
      res
        .status(withinLimit ? 401 : 429)
        .json({ error: withinLimit ? 'Admin ključ nije ispravan.' : 'Previše pokušaja prijave.' });
      return;
    }
    next();
  });
  app.get('/api/admin/dashboard', (_req, res) => res.json(service.dashboard()));
  app.patch('/api/admin/settings', (req, res) => {
    if (typeof req.body?.autoPublish !== 'boolean')
      throw new ValidationError('Postavka mora biti uključena ili isključena.');
    service.repo.setAutoPublish(req.body.autoPublish);
    res.json({ autoPublish: service.repo.autoPublish() });
  });
  app.post('/api/admin/collect', (req, res) => {
    if (!service.collecting && !allowed(`collect:${req.ip}`, 6, 60)) {
      res.status(429).json({ error: 'Dohvat je ograničen radi zaštite izvora. Pokušaj kasnije.' });
      return;
    }
    void service
      .collect(true)
      .catch((error) =>
        console.error('Collection failed:', error instanceof Error ? error.message : 'unknown'),
      );
    res.status(202).json({ ok: true, collecting: service.collecting });
  });
  app.post('/api/admin/tips/:id/prepare', async (req, res) =>
    res.json(await service.prepareTip(String(req.params.id))),
  );
  app.patch('/api/admin/tips/:id', (req, res) =>
    res.json(service.updateTip(String(req.params.id), req.body?.action, req.body?.draft)),
  );
  app.patch('/api/admin/events/:id', (req, res) =>
    res.json(
      service.repo.editEvent(String(req.params.id), req.body?.publication, req.body?.fields),
    ),
  );
  app.use('/api', (_req, res) => res.status(404).json({ error: 'Nepoznata API adresa.' }));
  const errors: ErrorRequestHandler = (error, _req, res, _next) => {
    if (error instanceof ValidationError || error instanceof SyntaxError)
      res
        .status(400)
        .json({ error: error instanceof ValidationError ? error.message : 'Neispravan zahtjev.' });
    else if (error?.type === 'entity.too.large')
      res.status(413).json({ error: 'Zahtjev je prevelik.' });
    else {
      console.error('Request failed:', error instanceof Error ? error.message : 'unknown');
      res.status(500).json({ error: 'Nešto nije uspjelo. Pokušaj ponovno.' });
    }
  };
  app.use(errors);
  return app;
}
