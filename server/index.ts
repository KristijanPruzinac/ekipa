import { resolve } from 'node:path';
import express from 'express';
import { config } from './config.ts';
import { sources } from './ingestion/index.ts';
import { createRepository } from './repository.ts';
import { WagzService } from './service.ts';
import { createApp } from './app.ts';

const repository = await createRepository(
  config.databasePath,
  sources,
  config.autoPublish,
  config.databaseUrl,
);
const service = new WagzService(repository, config);
const app = createApp(service);
if (process.argv.includes('--production')) {
  app.use(express.static(resolve('dist')));
  app.get('/{*path}', (_req, res) => res.sendFile(resolve('dist/index.html')));
} else {
  const { createServer } = await import('vite');
  const vite = await createServer({ server: { middlewareMode: true }, appType: 'spa' });
  app.use(vite.middlewares);
}
const server = app.listen(config.port, config.host, () => {
  console.log(`WagZ: http://${config.host}:${config.port}`);
  if (!config.adminKey) console.log('Admin setup: npm run admin-key, then restart.');
  if (config.fetchOnStart) void service.collect();
});
const timer = setInterval(() => {
  void service.collect();
}, config.fetchIntervalMinutes * 60000);
timer.unref();
for (const signal of ['SIGINT', 'SIGTERM'] as const)
  process.on(signal, () => {
    clearInterval(timer);
    server.close(async () => {
      await repository.close();
      process.exit(0);
    });
  });
