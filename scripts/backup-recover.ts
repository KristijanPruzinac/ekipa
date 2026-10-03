import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  MAX_BACKUP_BYTES,
  backupKey,
  backupPool,
  decryptSnapshot,
  type Snapshot,
} from './backup.ts';
import { restoreDrill } from './backup-drill.ts';

async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 3 || args[0] !== '--input' || args[2] !== '--empty-target')
    throw new Error('Usage: backup-recover.ts --input path.wagz --empty-target');
  const path = resolve(args[1]);
  if ((await stat(path)).size > MAX_BACKUP_BYTES * 1.4 + 1024)
    throw new Error('Encrypted backup too large.');
  const key = backupKey(process.env.WAGZ_BACKUP_KEY);
  let snapshot: Snapshot;
  try {
    snapshot = decryptSnapshot(await readFile(path), key);
  } finally {
    key.fill(0);
  }
  const pool = backupPool(process.env.DATABASE_URL);
  try {
    const client = await pool.connect();
    try {
      const report = await restoreDrill(client, snapshot, { retainInEmptyTarget: true });
      console.log(
        JSON.stringify({ ...report, retainedIsolatedSchema: true, publicUnchanged: true }),
      );
    } finally {
      client.release();
    }
  } finally {
    await pool.end();
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  void main().catch(() => {
    console.error(
      'Recovery failed. The public schema was not modified. Use a new empty target and check isolated-schema cleanup if the connection was lost.',
    );
    process.exitCode = 1;
  });
