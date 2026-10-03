import assert from 'node:assert/strict';
import test from 'node:test';
import { PostgresDatabase } from './database.ts';

test('restricted runtime validates schema without DDL, writes or advisory locks', async () => {
  const queries: string[] = [];
  const db = new PostgresDatabase(
    {
      async connect() {
        return {
          async query(sql: string) {
            queries.push(sql);
            return { rows: sql.includes('WHERE key') ? [{ value: 'true' }] : [] };
          },
          release() {},
        };
      },
      async end() {},
    },
    false,
  );
  await db.initialize(true);
  assert.equal(queries[0], 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  assert.equal(queries.at(-1), 'COMMIT');
  assert.equal(queries.filter((sql) => sql.includes('LIMIT 0')).length, 9);
  assert.ok(queries.every((sql) => !/CREATE|INSERT|UPDATE|DELETE|advisory/i.test(sql)));
});

test('restricted runtime fails closed when migration settings are missing', async () => {
  const queries: string[] = [];
  const db = new PostgresDatabase(
    {
      async connect() {
        return {
          async query(sql: string) {
            queries.push(sql);
            return { rows: [] };
          },
          release() {},
        };
      },
      async end() {},
    },
    false,
  );
  await assert.rejects(db.initialize(true), /migrations/);
  assert.equal(queries.at(-1), 'ROLLBACK');
});
