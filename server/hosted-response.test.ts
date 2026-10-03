import assert from 'node:assert/strict';
import test from 'node:test';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import type { Request, Response } from 'express';
import { PostgresDatabase } from './database.ts';

test('preview startup denial returns generic uncached JSON through a native ServerResponse before Express or database initialization', async (context) => {
  const previous = { VERCEL: process.env.VERCEL, VERCEL_ENV: process.env.VERCEL_ENV };
  process.env.VERCEL = '1';
  process.env.VERCEL_ENV = 'preview';
  context.after(() => {
    for (const key of ['VERCEL', 'VERCEL_ENV'] as const)
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
  });
  // Import the actual entry point without loading any local credentials.
  context.mock.method(process, 'loadEnvFile', () => {});
  const database = context.mock.method(PostgresDatabase, 'connect', () => {
    throw new Error('The preview must not attempt a database connection.');
  });
  const { default: handler } = await import('../api/index.ts');
  const server = createServer((request, response) => {
    assert.equal('set' in response, false, 'This must be a native Node response.');
    void handler(request as Request, response as Response);
  }).listen(0, '127.0.0.1');
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    for (const path of ['/api/health', '/api/events']) {
      const response = await fetch(base + path, { signal: AbortSignal.timeout(5_000) });
      assert.equal(response.status, 503);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      assert.equal(response.headers.get('x-robots-tag'), 'noindex, nofollow');
      assert.match(response.headers.get('content-type')!, /^application\/json/);
      const body = await response.json();
      assert.deepEqual(Object.keys(body), ['error']);
      assert.equal(body.error, 'Usluga se trenutačno ne može spojiti na bazu. Pokušaj ponovno.');
    }
    assert.equal(database.mock.callCount(), 0);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
