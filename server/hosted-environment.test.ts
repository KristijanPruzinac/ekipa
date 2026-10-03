import assert from 'node:assert/strict';
import test from 'node:test';
import { assertProductionEnvironment } from './hosted-environment.ts';

test('hosted preview, development and missing environment cannot access a database', () => {
  for (const VERCEL_ENV of ['preview', 'development', undefined]) {
    assert.throws(() => assertProductionEnvironment({ VERCEL: '1', VERCEL_ENV }));
  }
  assert.doesNotThrow(() => assertProductionEnvironment({ VERCEL: '1', VERCEL_ENV: 'production' }));
  assert.doesNotThrow(() => assertProductionEnvironment({}));
});
