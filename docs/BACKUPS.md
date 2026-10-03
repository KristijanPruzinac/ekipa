# Encrypted database backups and recovery

The owner-approved destination is GitHub Actions artifacts, encrypted before upload and retained for **30 days**. `.github/workflows/backup.yml` runs daily at **06:17 UTC** and supports manual dispatch. Only `wagz-backup.wagz`, an AES-256-GCM authenticated ciphertext envelope, is uploaded. Logs contain counts, hashes and timestamps, never records, database URLs or the key. The workflow uses read-only repository permissions and pinned actions. Secrets are passed only to the export step, after dependency installation.

Required repository secrets are the existing `WAGZ_DATABASE_URL` and **`WAGZ_BACKUP_KEY`**, exactly 32 random bytes encoded as canonical base64. Keep a separate recovery-key copy outside the repository, Vercel and downloaded artifacts. The owner's provisioned local copy is `C:/Users/kikom/.wagz-private/backup/recovery-key.txt`; this document contains no key value. A lost key makes every backup encrypted with it unrecoverable. Do not print it, paste it into chat or upload it as an artifact. During rotation, preserve the old key until its last backup has expired and the replacement backup has passed a restore drill.

`scripts/backup.ts` reads all nine allowlisted `public.wagz_*` tables in one `REPEATABLE READ READ ONLY` transaction: events, evidence, tips, tip quotas, shared request quotas, runs, settings, AI charges and AI cache. It preserves payloads, publication/editor decisions, evidence links, revisions, lease/accounting records and run ordering. Database contents never reach a plaintext disk file. Each table has a SHA-256 digest and the complete archive is authenticated with a fresh 96-bit nonce and 128-bit GCM tag. Wrong keys, tampering, unknown table/column names, duplicate identities, invalid payload JSON and orphaned evidence fail validation.

Exports are capped at **100,000 total rows and 32 MiB of plaintext JSON**, with a 2 MiB maximum text field. A size/count preflight runs before each table is retrieved, within the same snapshot. Exceeding a bound fails the job instead of silently truncating data. Investigate growth and review retention or deliberately revise these bounds before another run. Each database statement times out after 60 seconds, lock waits after 5 seconds, and the workflow after 10 minutes. The scripts intentionally do not load `.env` automatically.

## Manual export and isolated restore drill

Load `DATABASE_URL` and `WAGZ_BACKUP_KEY` into the process environment from the owner's private credential storage without displaying them. The export needs only SELECT access to the allowlisted tables. The backup workflow, scheduled collector and web runtime now use the restricted `wagz_runtime` role; the collector and runtime disable migrations. The owner connection remains in local maintenance storage for migrations and restore drills, which require permission to create a temporary schema. No owner database URL is required in GitHub or Vercel.

```powershell
node --import tsx scripts/backup.ts --output .artifacts/backup-verification.wagz
node --import tsx scripts/backup-drill.ts --input .artifacts/backup-verification.wagz
```

Choose a fresh output filename: export refuses to overwrite an existing file. Downloaded Actions artifacts contain the encrypted `.wagz` file; supply that extracted file to the drill. No paid provider or source call is made.

The drill authenticates and validates the entire archive **before connecting to the database**. It creates a cryptographically random `wagz_restore_<32 hex digits>` schema, restores all records with bound values and real primary/foreign-key constraints, aligns and checks the run sequence, commits, rereads the data and compares every table's count and hash. It then removes exactly that schema. It never writes, truncates or restores `public.wagz_*` tables. A schema collision fails because CREATE does not use IF NOT EXISTS; cleanup never adopts an existing schema.

A successful JSON report says `restored: true`, `sequenceVerified: true`, `foreignKeysVerified: true` and `cleaned: true`, with per-table counts/hashes. Preserve this sanitized report as restoration evidence. Unit tests use in-memory records and mocked Postgres interfaces; a successful live drill is separate evidence that the database accepts and returns restored data. Run a drill after format/schema changes and periodically against a downloaded backup.

If the connection is lost after the temporary schema commits, automatic cleanup may fail. Inspect `pg_namespace` for `wagz_restore_%` using an owner connection and correlate the exact schema with that invocation. Remove only the confirmed temporary schema; do not issue wildcard drops or drop another operator's drill. The application does not query these schemas.

## Manual recovery into a new empty target

Provision a **new empty Postgres database**, keep collectors and the web runtime stopped, and load its owner `DATABASE_URL` plus the archive's recovery key privately. The following command requires an explicit `--empty-target` flag and checks that `public` contains no relations before creating its isolated schema. It refuses the existing production database. Do not initialize application tables in the recovery target first.

```powershell
node --import tsx scripts/backup-recover.ts --input .artifacts/backup-verification.wagz --empty-target
```

This performs the same restore, sequence, FK and hash checks as the drill, retaining the generated schema **only after verification succeeds**. Failed restores roll back or remove their own temporary schema. A successful report includes `retainedIsolatedSchema: true`, `publicUnchanged: true` and the exact schema name. No automatic public-table promotion or production connection change occurs.

Review the report and compare table counts/hashes, public/draft/rejected decisions, tips/revisions and AI accounting with the export report. After confirming the **new empty target**, an owner may promote only the allowlisted tables in a transaction. The following is a manual `psql` template: replace the placeholder with the exact verified schema and stop on any error. No `DROP public` or `CASCADE` is used. Moving a table also moves its associated indexes, constraints and owned sequence. [Postgres ALTER TABLE documentation](https://www.postgresql.org/docs/17/sql-altertable.html)

```sql
\set ON_ERROR_STOP on
\set restored_schema wagz_restore_REPLACE_WITH_VERIFIED_32_HEX_DIGITS
BEGIN;
ALTER TABLE :"restored_schema".wagz_events SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_evidence SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_tips SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_tip_quotas SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_request_quotas SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_runs SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_settings SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_ai_charges SET SCHEMA public;
ALTER TABLE :"restored_schema".wagz_ai_cache SET SCHEMA public;
CREATE INDEX wagz_evidence_event ON public.wagz_evidence(event_id);
CREATE INDEX wagz_tip_quotas_expiry ON public.wagz_tip_quotas(expires_at);
CREATE INDEX wagz_request_quotas_expiry ON public.wagz_request_quotas(expires_at);
DROP SCHEMA :"restored_schema";
COMMIT;
```

Recreate a dedicated runtime LOGIN role using a fresh password via private credential handling. It must have `CONNECT` to the target database, `USAGE` on `public`, `SELECT/INSERT/UPDATE/DELETE` on the nine application tables, and `USAGE/SELECT` on `public.wagz_runs_ordinal_seq`. Do not grant table ownership, schema CREATE, CREATEDB, CREATEROLE, SUPERUSER or migration privileges. Keep a separate owner/migration connection in local maintenance storage. Configure Vercel and the GitHub collector/backup secret with the restricted URL only after startup/read checks pass; the web runtime and collector must set `WAGZ_DATABASE_MIGRATIONS=disabled`. Verify public/admin reads with provider calls disabled before enabling collection and selecting the new database for production.

## Scope and retention

Backups are application-record snapshots, not Postgres cluster dumps. They do not contain database roles/grants, provider/admin keys, Vercel/GitHub settings, source-reader file caches, deployment code or DNS settings. Keep those separate recovery materials available. The archive preserves AI charges including reserved/unknown costs; do not zero the ledger during recovery. Expired quota rows and collection leases may remain in the snapshot; inspect lease timestamps before restarting collection and preserve accounting/provenance.

GitHub scheduling and artifact retention do not guarantee recovery. Check successful workflow runs and downloaded-file drills; 30-day expiry is the configured artifact policy, subject to repository/platform limits. Loss of the repository/account can also remove these backups. The separate recovery-key copy is required but does not itself preserve ciphertext. No historical backup success or restore-point objective is claimed until live evidence is recorded by the release owner.

The seven isolated backup tests run in `npm test` and cover authenticated roundtrip, wrong keys/tampering, malformed/unknown data, consistent read-only export, limits, restore commit/reread/FK/sequence behavior, safe failure cleanup and empty-target recovery.

**Live verification, 3 October 2026 at 09:20 UTC:** the release owner exported a 214,377-byte encrypted archive and successfully restored all nine tables into a fresh isolated Neon schema. Counts and SHA-256 hashes matched for 33 events, 33 evidence links, 8 tips, 26 runs, 1 setting, 144 AI charges, 59 AI cache entries and empty quota tables. Run sequence and foreign-key checks passed; the isolated schema was removed. Sanitized reports: `.artifacts/backup-live-export-report.json` and `.artifacts/backup-live-drill-report.json`; encrypted archive: `.artifacts/release-backup-20261003.wagz`. This verifies one real restore, not future scheduled backup execution or artifact availability.

**GitHub artifact verification, 3 October 2026:** [backup run `37114397226`](https://github.com/KristijanPruzinac/ekipa/actions/runs/37114397226) succeeded after the expanded source collection. Its 295,461-byte encrypted artifact (`wagz-encrypted-backup-37114397226`, artifact `11271327221`) expires on 2 November 2026 at 09:50:43 UTC. The downloaded ciphertext authenticated with the separately stored recovery key and restored successfully: 72 events, 73 evidence rows, 8 tips, 0 tip quotas, 2 request quotas, 33 runs, 1 setting, 155 AI charges and 65 cache entries. Every table count/hash, foreign-key and sequence check passed; the temporary schema was cleaned. No production records were rewritten. Sanitized evidence: `.artifacts/release-workflow-verification.json` and `.artifacts/backup-actions-restore-report.json`. This proves the first manual Actions export and downloaded-file restore; later scheduled runs still need observation.
