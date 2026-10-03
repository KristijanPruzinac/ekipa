import { config } from './config.ts';
import { sources } from './ingestion/index.ts';
import { createRepository } from './repository.ts';
import { WagzService } from './service.ts';
const repo = await createRepository(
  config.databasePath,
  sources,
  config.autoPublish,
  config.databaseUrl,
);
const service = new WagzService(repo, config);
try {
  await service.collect();
  for (const source of await repo.sourceHealth())
    console.log(
      `${source.name}: ${source.latestRun?.status} · ${source.latestRun?.imported ?? 0} imports`,
    );
  if (service.lastTipBatch) {
    const batch = service.lastTipBatch;
    console.log(
      `Dojave: ${batch.queued} queued · ${batch.processed} checked · ${batch.drafted} drafts · ${batch.archived} archived · ${batch.deferred} pending`,
    );
  }
  if ((await repo.sourceHealth()).some((source) => source.latestRun?.status === 'error'))
    process.exitCode = 1;
} finally {
  await repo.close();
}
