import assert from 'node:assert/strict';
import test from 'node:test';
import { randomBytes } from 'node:crypto';
import {
  TABLES,
  MAX_BACKUP_ROWS,
  backupKey,
  captureSnapshot,
  createSnapshot,
  decryptSnapshot,
  encryptSnapshot,
  validateSnapshot,
  type BackupConnection,
  type BackupRow,
  type Table,
} from './backup.ts';
import { restoreDrill } from './backup-drill.ts';

function fixture() {
  const raw = Object.fromEntries(
    Object.keys(TABLES).map((name) => [name, [] as BackupRow[]]),
  ) as Record<Table, BackupRow[]>;
  raw.events = [
    {
      id: 'event-1',
      payload: JSON.stringify({
        id: 'event-1',
        title: 'Koncert',
        publication: 'draft',
        manuallyEdited: true,
      }),
    },
  ];
  raw.evidence = [
    {
      source_id: 'source',
      external_id: 'external',
      event_id: 'event-1',
      url: 'https://source.test/event',
      last_seen: '2026-10-03T10:00:00.000Z',
    },
  ];
  raw.tips = [
    {
      id: 'tip-1',
      payload: JSON.stringify({
        id: 'tip-1',
        note: 'Private submission',
        status: 'archived',
        revision: 4,
      }),
    },
  ];
  raw.tip_quotas = [{ client_key: 'a'.repeat(64), attempts: 5, expires_at: '1791025200000' }];
  raw.request_quotas = [{ quota_key: 'tips:global', attempts: 12, expires_at: '1791072000000' }];
  raw.runs = [
    {
      id: 'run-1',
      payload: JSON.stringify({ id: 'run-1', status: 'ok' }),
      ordinal: '9007199254740993',
    },
  ];
  raw.settings = [
    { key: 'autoPublish', value: 'false' },
    {
      key: 'lease:collection',
      value: JSON.stringify({ token: 'opaque-token', until: 1791025200000 }),
    },
  ];
  raw.ai_charges = [{ id: 'charge', month: '2026-10', amount: 0.03, state: 'unknown' }];
  raw.ai_cache = [
    { key: 'cache-key', payload: JSON.stringify({ assessment: 'unverified', draft: null }) },
  ];
  return raw;
}

test('authenticated backup roundtrip preserves every record, editorial decisions and unsettled AI charges', () => {
  const snapshot = createSnapshot(fixture(), '2026-10-03T10:00:00.000Z');
  const key = backupKey(randomBytes(32).toString('base64'));
  const encrypted = encryptSnapshot(snapshot, key);
  assert.deepEqual(decryptSnapshot(encrypted, key), snapshot);
  assert.ok(!encrypted.toString().includes('Private submission'));
  assert.ok(!encrypted.toString().includes('opaque-token'));
  assert.notDeepEqual(
    encryptSnapshot(snapshot, key),
    encrypted,
    'each snapshot gets a fresh nonce',
  );
  assert.equal(
    snapshot.tables.runs.rows[0].ordinal,
    '9007199254740993',
    'BIGINT must not lose precision',
  );
});

test('wrong keys, tampered ciphertext, altered authentication metadata and invalid key encodings fail closed', () => {
  const key = randomBytes(32);
  const encrypted = encryptSnapshot(createSnapshot(fixture()), key);
  assert.throws(() => decryptSnapshot(encrypted, randomBytes(32)));
  for (const field of ['ciphertext', 'iv', 'tag']) {
    const tampered = JSON.parse(encrypted.toString());
    const value = Buffer.from(tampered[field], 'base64');
    value[0] ^= 1;
    tampered[field] = value.toString('base64');
    assert.throws(() => decryptSnapshot(Buffer.from(JSON.stringify(tampered)), key), field);
  }
  const unsupported = JSON.parse(encrypted.toString());
  unsupported.cipher = 'aes-256-cbc';
  assert.throws(() => decryptSnapshot(Buffer.from(JSON.stringify(unsupported)), key));
  for (const value of [
    undefined,
    '',
    'password',
    randomBytes(31).toString('base64'),
    `${key.toString('base64')}\n`,
  ])
    assert.throws(() => backupKey(value));
});

test('validation rejects unknown tables/columns, malformed rows, duplicate keys, bad hashes and missing evidence parents', () => {
  const snapshot = createSnapshot(fixture());
  const unknown = structuredClone(snapshot) as unknown as { tables: Record<string, unknown> };
  unknown.tables['public.users'] = { rows: [], sha256: '' };
  assert.throws(() => validateSnapshot(unknown), /fields/);
  const changed = structuredClone(snapshot);
  changed.tables.tips.rows[0].payload = '{}';
  assert.throws(() => validateSnapshot(changed), /integrity/);
  const duplicate = fixture();
  duplicate.events.push(duplicate.events[0]);
  assert.throws(() => createSnapshot(duplicate), /Duplicate/);
  const orphan = fixture();
  orphan.evidence[0].event_id = 'missing';
  assert.throws(() => createSnapshot(orphan), /absent event/);
  const malformed = fixture();
  malformed.tips[0].payload = '{';
  assert.throws(() => createSnapshot(malformed));
  const column = fixture();
  column.events[0].unexpected = 'do not import';
  assert.throws(() => createSnapshot(column), /fields/);
  const integer = fixture();
  integer.runs[0].ordinal = '9223372036854775808';
  assert.throws(() => createSnapshot(integer), /integer range/);
  const unsafeNumber = fixture();
  unsafeNumber.runs[0].ordinal = Number.MAX_SAFE_INTEGER + 1;
  assert.throws(() => createSnapshot(unsafeNumber), /Invalid backup integer/);
});

test('capture uses one consistent read-only transaction, bounds rows before retrieval and rolls back failures', async () => {
  const raw = fixture();
  const calls: string[] = [];
  const connection: BackupConnection = {
    async query(sql) {
      calls.push(sql);
      const table = sql.match(/FROM public\.wagz_(\w+)/)?.[1] as Table | undefined;
      if (!table) return { rows: [] };
      const rows = raw[table];
      return /count\(\*\)/.test(sql)
        ? {
            rows: [
              {
                count: String(rows.length),
                bytes: String(Buffer.byteLength(JSON.stringify(rows))),
              },
            ],
          }
        : { rows };
    },
  };
  const result = await captureSnapshot(connection);
  assert.equal(result.tables.ai_charges.rows[0].state, 'unknown');
  assert.equal(calls[0], 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  assert.equal(calls.at(-1), 'COMMIT');
  assert.ok(calls.every((sql) => !/^(INSERT|UPDATE|DELETE|CREATE|DROP)\b/.test(sql)));
  const rejected: string[] = [];
  await assert.rejects(
    captureSnapshot({
      async query(sql) {
        rejected.push(sql);
        return {
          rows: sql.startsWith('SELECT')
            ? [{ count: String(MAX_BACKUP_ROWS + 1), bytes: '0' }]
            : [],
        };
      },
    }),
    /bounds/,
  );
  assert.equal(rejected.at(-1), 'ROLLBACK');
  assert.ok(!rejected.some((sql) => sql.startsWith('SELECT id,payload')));
});

function drillConnection(
  options: {
    corruptRead?: boolean;
    rejectCreate?: boolean;
    rejectInsert?: boolean;
    publicObjects?: number;
  } = {},
) {
  const calls: Array<{ sql: string; parameters?: unknown[] }> = [];
  const restored = Object.fromEntries(
    Object.keys(TABLES).map((table) => [table, [] as BackupRow[]]),
  ) as Record<Table, BackupRow[]>;
  let sequence = 1n,
    called = false;
  const connection: BackupConnection = {
    async query(sql, parameters = []) {
      calls.push({ sql, parameters });
      if (sql.includes('FROM pg_class'))
        return { rows: [{ count: String(options.publicObjects ?? 0) }] };
      if (options.rejectCreate && sql.startsWith('CREATE SCHEMA'))
        throw new Error('schema collision');
      const table = sql.match(/\.wagz_(\w+)/)?.[1] as Table | undefined;
      if (sql.startsWith('INSERT INTO')) {
        if (options.rejectInsert) throw new Error('write failure');
        assert.ok(!sql.includes('public.'));
        assert.match(sql, /^INSERT INTO "wagz_restore_[a-f0-9]{32}"\./);
        assert.ok(table && TABLES[table]);
        const columns = TABLES[table];
        for (let i = 0; i < parameters.length; i += columns.length)
          restored[table].push(
            Object.fromEntries(
              columns.map((column, j) => [column, parameters[i + j]]),
            ) as BackupRow,
          );
      }
      if (sql.startsWith('SELECT setval')) {
        sequence = BigInt(String(parameters[2]));
        called = Boolean(parameters[3]);
      }
      if (sql.startsWith('SELECT nextval')) {
        if (called) sequence++;
        called = true;
        return { rows: [{ ordinal: String(sequence) }] };
      }
      if (sql.includes('FROM pg_constraint')) return { rows: [{ count: '1' }] };
      if (sql.startsWith('SELECT') && table) {
        const rows = structuredClone(restored[table]);
        if (options.corruptRead && table === 'tips') rows[0].payload = '{}';
        return { rows };
      }
      return { rows: [] };
    },
  };
  return { calls, restored, connection };
}

test('restore drill commits/rereads exact rows in a generated isolated schema, verifies sequence/FK, then cleans only that schema', async () => {
  const f = drillConnection();
  const snapshot = createSnapshot(fixture());
  const report = await restoreDrill(f.connection, snapshot);
  assert.match(report.schema, /^wagz_restore_[a-f0-9]{32}$/);
  assert.equal(report.foreignKeysVerified, true);
  assert.equal(report.sequenceVerified, true);
  assert.deepEqual(createSnapshot(f.restored, snapshot.createdAt), snapshot);
  assert.equal(f.calls.at(-1)?.sql, `DROP SCHEMA "${report.schema}" CASCADE`);
  assert.equal(f.calls.filter((call) => call.sql === 'COMMIT').length, 2);
  assert.ok(f.calls.every((call) => !/\bpublic\./.test(call.sql)));
  assert.equal(
    f.calls.filter((call) => call.sql.startsWith('SELECT setval'))[0].parameters?.[2],
    '9007199254740993',
  );
});

test('restore rejects malformed input before SQL and rolls back failed writes without dropping pre-existing schemas', async () => {
  const bad = drillConnection();
  await assert.rejects(restoreDrill(bad.connection, { tables: { users: [] } }));
  assert.equal(bad.calls.length, 0);
  for (const options of [{ rejectCreate: true }, { rejectInsert: true }]) {
    const f = drillConnection(options);
    await assert.rejects(restoreDrill(f.connection, createSnapshot(fixture())));
    assert.equal(f.calls.at(-1)?.sql, 'ROLLBACK');
    assert.ok(!f.calls.some((call) => call.sql.startsWith('DROP')));
  }
  const corrupt = drillConnection({ corruptRead: true });
  await assert.rejects(restoreDrill(corrupt.connection, createSnapshot(fixture())), /verification/);
  assert.equal(corrupt.calls.at(-2)?.sql, 'ROLLBACK');
  assert.match(corrupt.calls.at(-1)!.sql, /^DROP SCHEMA "wagz_restore_[a-f0-9]{32}" CASCADE$/);
});

test('explicit recovery retains a verified isolated schema only in an empty target; failed verification cleans it', async () => {
  const snapshot = createSnapshot(fixture());
  const nonempty = drillConnection({ publicObjects: 1 });
  await assert.rejects(
    restoreDrill(nonempty.connection, snapshot, { retainInEmptyTarget: true }),
    /empty public schema/,
  );
  assert.ok(!nonempty.calls.some((call) => /^(CREATE|INSERT|DROP)\b/.test(call.sql)));
  const empty = drillConnection();
  const result = await restoreDrill(empty.connection, snapshot, { retainInEmptyTarget: true });
  assert.equal(result.restored, true);
  assert.equal(empty.calls.at(-1)?.sql, 'COMMIT');
  assert.ok(!empty.calls.some((call) => /^(DROP|ALTER)\b/.test(call.sql)));
  const corrupt = drillConnection({ corruptRead: true });
  await assert.rejects(
    restoreDrill(corrupt.connection, snapshot, { retainInEmptyTarget: true }),
    /verification/,
  );
  assert.match(corrupt.calls.at(-1)!.sql, /^DROP SCHEMA "wagz_restore_[a-f0-9]{32}" CASCADE$/);
});
