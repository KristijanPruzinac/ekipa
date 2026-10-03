import { config } from './config.ts';
import { sources } from './ingestion/index.ts';
import { Repository } from './repository.ts';
import { WagzService } from './service.ts';
const repo = new Repository(config.databasePath, sources, config.autoPublish);
const service = new WagzService(repo, config);
try {
  await service.collect();
  for (const source of repo.sourceHealth())
    console.log(
      `${source.name}: ${source.latestRun?.status} · ${source.latestRun?.imported ?? 0} imports`,
    );
  if (repo.sourceHealth().some((source) => source.latestRun?.status === 'error'))
    process.exitCode = 1;
} finally {
  repo.close();
}
