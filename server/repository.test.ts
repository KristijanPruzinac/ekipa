import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { Repository } from './repository.ts';
import {
  PostgresDatabase,
  postgresSql,
  postgresConnectionString,
  type PostgresConnection,
  type Row,
} from './database.ts';
import { classifyTip, tipDates, upcoming, validDate, validateDraft } from './validation.ts';
import type { EventCandidate } from '../shared/types.ts';

const source = {
  id: 'a',
  name: 'Official venue',
  url: 'https://example.org/events',
  description: '',
  enabled: true,
};
const candidate = (overrides: Partial<EventCandidate> = {}): EventCandidate => ({
  sourceId: 'a',
  sourceUrl: 'https://example.org/events/1',
  externalId: '1',
  title: 'Koncert mladih',
  description: '',
  startsAt: '2026-10-10T20:00:00+02:00',
  endsAt: null,
  venue: 'Dvorana',
  address: null,
  city: 'Osijek',
  category: 'music',
  price: null,
  status: 'scheduled',
  ...overrides,
});

test('rerunning collection updates the occurrence instead of duplicating it; reschedule is kept', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = await repo.upsert(candidate());
    const second = await repo.upsert(candidate({ startsAt: '2026-10-11T20:00:00+02:00' }));
    assert.equal(second.id, first.id);
    assert.equal((await repo.events()).length, 1);
    assert.equal(second.startsAt, '2026-10-11T20:00:00+02:00');
  } finally {
    await repo.close();
  }
});
test('exact cross-source duplicates retain both provenance links; different performances stay separate', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = await repo.upsert(candidate());
    const duplicate = await repo.upsert(
      candidate({
        sourceId: 'b',
        sourceUrl: 'https://other.org/1',
        externalId: 'b1',
        title: 'KONCERT MLADIH!',
      }),
    );
    assert.equal(duplicate.id, first.id);
    assert.equal(duplicate.sources.length, 2);
    await repo.upsert(candidate({ externalId: '2', startsAt: '2026-10-10T22:00:00+02:00' }));
    assert.equal((await repo.events()).length, 2);
  } finally {
    await repo.close();
  }
});
test('unknown venue stays draft, toggle affects new imports only, rejection survives refetch', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    assert.equal((await repo.upsert(candidate({ venue: null }))).publication, 'draft');
    await repo.setAutoPublish(false);
    const next = await repo.upsert(candidate({ externalId: '2', title: 'Drugi koncert' }));
    assert.equal(next.publication, 'draft');
    await repo.editEvent(next.id, 'rejected');
    await repo.setAutoPublish(true);
    assert.equal(
      (await repo.upsert(candidate({ externalId: '2', title: 'Drugi koncert' }))).publication,
      'rejected',
    );
  } finally {
    await repo.close();
  }
});
test('an incomplete automatic import can publish when source facts arrive, but a manually held draft stays held', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = await repo.upsert(candidate({ venue: null }));
    assert.equal(first.publication, 'draft');
    assert.equal((await repo.upsert(candidate())).publication, 'published');
    await repo.editEvent(first.id, 'draft');
    assert.equal((await repo.upsert(candidate())).publication, 'draft');
  } finally {
    await repo.close();
  }
});
test('operator corrections survive later imports; cancellation is stored for unedited events', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const event = await repo.upsert(candidate());
    assert.equal((await repo.upsert(candidate({ status: 'cancelled' }))).status, 'cancelled');
    await repo.editEvent(event.id, undefined, { title: 'Potvrđeni naslov', venue: 'Novo mjesto' });
    assert.equal((await repo.upsert(candidate())).title, 'Potvrđeni naslov');
    assert.equal((await repo.event(event.id))?.venue, 'Novo mjesto');
  } finally {
    await repo.close();
  }
});
test('budget reservation blocks overspending concurrently and preserves unknown charges', async () => {
  const repo = new Repository(':memory:', []);
  try {
    const first = (await repo.reserveAi(0.6, 1))!;
    assert.ok(first);
    assert.equal(await repo.reserveAi(0.6, 1), null);
    await repo.settleAi(first, 0.01);
    assert.ok(await repo.reserveAi(0.6, 1));
    const unknown = (await repo.reserveAi(0.3, 1))!;
    await repo.settleAi(unknown, null);
    assert.equal(await repo.reserveAi(0.1, 1), null);
  } finally {
    await repo.close();
  }
});
test('approved linkless community tip is idempotent and does not invent a source URL', async () => {
  const repo = new Repository(':memory:', []);
  try {
    const draft = { ...candidate(), sourceUrl: null };
    const first = await repo.publishTip('same-tip', draft);
    assert.equal((await repo.publishTip('same-tip', draft)).id, first.id);
    assert.equal((await repo.events()).length, 1);
    assert.deepEqual(first.sources, []);
  } finally {
    await repo.close();
  }
});
test('calendar dates, unknown times, Zagreb day boundaries and ongoing ranges stay honest', async () => {
  assert.equal(validDate('2026-02-30'), false);
  assert.equal(validDate('2026-10-25T20:00:00'), false);
  assert.equal(validDate('2026-10-25'), true);
  assert.equal(
    upcoming({ startsAt: '2026-10-04', endsAt: null }, new Date('2026-10-03T22:30:00Z')),
    true,
  );
  assert.equal(
    upcoming({ startsAt: '2026-10-03', endsAt: null }, new Date('2026-10-03T22:30:00Z')),
    false,
  );
  assert.equal(
    upcoming({ startsAt: '2026-10-01', endsAt: '2026-10-06' }, new Date('2026-10-03T12:00:00Z')),
    true,
  );
  assert.throws(() => validateDraft({ ...candidate(), sourceUrl: 'javascript:alert(1)' }));
  assert.equal(
    validateDraft({ ...candidate(), startsAt: '2026-10-09T22:30:00Z' }).startsAt,
    '2026-10-10T00:30:00+02:00',
  );
});

test('ongoing eligibility uses an exclusive known end and never invents an unknown duration', () => {
  const timed = { startsAt: '2026-10-03T20:00:00+02:00', endsAt: '2026-10-03T22:00:00+02:00' };
  assert.equal(upcoming(timed, new Date('2026-10-03T19:00:00Z')), true);
  assert.equal(upcoming(timed, new Date('2026-10-03T19:59:59.999Z')), true);
  assert.equal(upcoming(timed, new Date('2026-10-03T20:00:00Z')), false);
  assert.equal(upcoming(timed, new Date('2026-10-03T20:00:00.001Z')), false);
  const unknownEnd = { startsAt: timed.startsAt, endsAt: null };
  assert.equal(upcoming(unknownEnd, new Date('2026-10-03T18:00:00Z')), true);
  assert.equal(upcoming(unknownEnd, new Date('2026-10-03T18:00:00.001Z')), false);
});

test('date-only end days and repeated DST hours follow Zagreb boundaries', () => {
  const autumn = { startsAt: '2026-10-24', endsAt: '2026-10-25' };
  assert.equal(upcoming(autumn, new Date('2026-10-25T22:59:59.999Z')), true);
  assert.equal(upcoming(autumn, new Date('2026-10-25T23:00:00Z')), false);
  const spring = { startsAt: '2026-03-28', endsAt: '2026-03-29' };
  assert.equal(upcoming(spring, new Date('2026-03-29T21:59:59.999Z')), true);
  assert.equal(upcoming(spring, new Date('2026-03-29T22:00:00Z')), false);
  const repeatedHour = {
    startsAt: '2026-10-25T02:30:00+02:00',
    endsAt: '2026-10-25T02:30:00+01:00',
  };
  assert.equal(upcoming(repeatedHour, new Date('2026-10-25T01:00:00Z')), true);
  assert.equal(upcoming(repeatedHour, new Date('2026-10-25T01:30:00Z')), false);
  const unknownTime = { startsAt: '2026-10-25', endsAt: null };
  assert.equal(upcoming(unknownTime, new Date('2026-10-25T22:59:59.999Z')), true);
  assert.equal(upcoming(unknownTime, new Date('2026-10-25T23:00:00Z')), false);
});

test('public feed retains known ongoing ranges and future starts but removes ended and unknown-duration past starts', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const ongoing = await repo.upsert(
      candidate({
        externalId: 'ongoing',
        title: 'Ongoing concert',
        startsAt: '2026-10-03T20:00:00+02:00',
        endsAt: '2026-10-03T22:00:00+02:00',
      }),
    );
    await repo.upsert(
      candidate({
        externalId: 'ended',
        title: 'Ended concert',
        startsAt: '2026-10-03T19:00:00+02:00',
        endsAt: '2026-10-03T21:00:00+02:00',
      }),
    );
    await repo.upsert(
      candidate({
        externalId: 'unknown',
        title: 'Unknown duration concert',
        startsAt: '2026-10-03T20:00:00+02:00',
      }),
    );
    const future = await repo.upsert(
      candidate({
        externalId: 'future',
        title: 'Future concert',
        startsAt: '2026-10-03T23:00:00+02:00',
      }),
    );
    const dateRange = await repo.upsert(
      candidate({
        externalId: 'range',
        title: 'Multi-day festival',
        startsAt: '2026-10-01',
        endsAt: '2026-10-03',
      }),
    );
    const feed = await repo.publicEvents(new Date('2026-10-03T19:00:00Z'));
    assert.deepEqual(
      new Set(feed.map((event) => event.id)),
      new Set([ongoing.id, future.id, dateRange.id]),
    );
    assert.equal(
      (await repo.events()).length,
      5,
      'Temporal filtering never deletes source records.',
    );
  } finally {
    await repo.close();
  }
});
test('only unmistakable automated junk archives; vague real tips stay for review', async () => {
  assert.equal(classifyTip('aaaaaaaaaaaaaaaaaaaaaaaa').archive, true);
  assert.equal(classifyTip('Čuo sam da uskoro ima svirka u Osijeku').archive, false);
  assert.equal(classifyTip('festival').archive, false);
});

test('ambiguous date-only evidence never attaches to or overwrites a true showtime', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const early = await repo.upsert(candidate());
    const late = await repo.upsert(
      candidate({ externalId: 'late', startsAt: '2026-10-10T22:00:00+02:00' }),
    );
    const unresolved = await repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', startsAt: '2026-10-10' }),
    );
    assert.notEqual(unresolved.id, early.id);
    assert.notEqual(unresolved.id, late.id);
    assert.equal(unresolved.publication, 'draft');
    assert.equal(unresolved.autoPublishEligible, false);
    const resolved = await repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', startsAt: '2026-10-10T22:00:00+02:00' }),
    );
    assert.equal(resolved.id, unresolved.id);
    assert.equal(
      resolved.publication,
      'draft',
      'resolved collision remains visible for manual reconciliation',
    );
    assert.equal((await repo.event(early.id))?.startsAt, '2026-10-10T20:00:00+02:00');
    assert.equal((await repo.event(late.id))?.startsAt, '2026-10-10T22:00:00+02:00');
    assert.equal((await repo.event(early.id))?.sources.length, 1);
    assert.equal((await repo.event(late.id))?.sources.length, 1);
    assert.equal(
      (await repo.upsert(candidate())).publication,
      'published',
      'a held unknown row does not demote the true occurrence',
    );
    assert.equal(
      (await repo.upsert(candidate({ externalId: 'late', startsAt: '2026-10-10T22:00:00+02:00' })))
        .publication,
      'published',
      'a resolved but held duplicate does not demote the true occurrence',
    );
    assert.equal((await repo.event(late.id))?.publication, 'published');
  } finally {
    await repo.close();
  }
});

test('unknown venue is not an alias even with one plausible match; later venue facts cannot hijack it', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const original = await repo.upsert(candidate());
    const unknown = await repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', venue: null }),
    );
    assert.notEqual(unknown.id, original.id);
    assert.equal(unknown.publication, 'draft');
    const changed = await repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', venue: 'Druga dvorana' }),
    );
    assert.equal(changed.id, unknown.id);
    assert.equal(changed.publication, 'draft');
    assert.equal((await repo.event(original.id))?.venue, 'Dvorana');
    assert.equal((await repo.event(original.id))?.publication, 'published');
  } finally {
    await repo.close();
  }
});

test('a weaker refresh on an exact cross-source alias preserves known time and venue', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const original = await repo.upsert(candidate());
    const alias = await repo.upsert(candidate({ sourceId: 'b', externalId: 'alias' }));
    assert.equal(alias.id, original.id);
    await repo.upsert(candidate({ externalId: 'later', startsAt: '2026-10-10T22:00:00+02:00' }));
    const weak = await repo.upsert(
      candidate({ sourceId: 'b', externalId: 'alias', startsAt: '2026-10-10', venue: null }),
    );
    assert.equal(weak.id, original.id);
    assert.equal(weak.startsAt, original.startsAt);
    assert.equal(weak.venue, original.venue);
    assert.equal(weak.publication, 'published');
    assert.equal((await repo.events()).length, 2);
  } finally {
    await repo.close();
  }
});

test('a reschedule colliding with another exact occurrence is held without changing its evidence', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = await repo.upsert(candidate());
    const second = await repo.upsert(
      candidate({ externalId: 'second', startsAt: '2026-10-11T20:00:00+02:00' }),
    );
    const moved = await repo.upsert(candidate({ startsAt: second.startsAt }));
    assert.equal(moved.id, first.id);
    assert.equal(moved.publication, 'draft');
    assert.equal((await repo.event(second.id))?.publication, 'published');
    assert.equal((await repo.event(second.id))?.sources.length, 1);
    assert.equal((await repo.events()).length, 2);
  } finally {
    await repo.close();
  }
});

test('a partial run with imports counts as last successful contact without losing warnings', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const base = {
      sourceId: source.id,
      startedAt: '2026-10-01T10:00:00Z',
      finishedAt: '2026-10-01T10:01:00Z',
      status: 'partial' as const,
      discovered: 18,
      imported: 18,
      skipped: 0,
      pagesFetched: 2,
      warnings: ['Optional enrichment unavailable'],
    };
    await repo.saveRun({ ...base, id: 'imported' });
    await repo.saveRun({ ...base, id: 'empty', imported: 0, finishedAt: '2026-10-02T10:01:00Z' });
    const health = (await repo.sourceHealth())[0];
    assert.equal(health.lastSuccessAt, base.finishedAt);
    assert.equal(health.latestRun?.id, 'empty');
    assert.equal(health.latestRun?.status, 'partial');
    assert.deepEqual(health.latestRun?.warnings, base.warnings);
  } finally {
    await repo.close();
  }
});

test('date ranges compare Zagreb-normalized dates and still reject reversed instants', async () => {
  const draft = validateDraft({
    ...candidate(),
    startsAt: '2026-10-04T00:30:00+02:00',
    endsAt: '2026-10-03T23:00:00Z',
  });
  assert.equal(draft.startsAt, '2026-10-04T00:30:00+02:00');
  assert.equal(draft.endsAt, '2026-10-04T01:00:00+02:00');
  assert.throws(() =>
    validateDraft({
      ...candidate(),
      startsAt: '2026-10-04T00:30:00+02:00',
      endsAt: '2026-10-03T22:00:00Z',
    }),
  );
  assert.doesNotThrow(() =>
    validateDraft({ ...candidate(), startsAt: '2026-10-03T22:30:00Z', endsAt: '2026-10-04' }),
  );
  assert.throws(() =>
    validateDraft({ ...candidate(), startsAt: '2026-10-03T22:30:00Z', endsAt: '2026-10-03' }),
  );
});

test('tip dates preserve explicit ISO and Croatian dates without inferring missing years', async () => {
  for (const date of [
    '2026-10-10',
    '10.10.2026.',
    '10. 10. 2026.',
    '10/10/26',
    '10. listopada 2026.',
    '10 listopad 2026',
  ]) {
    assert.deepEqual(
      tipDates(`Koncert ${date}`),
      { dates: ['2026-10-10'], hasYear: true, invalid: false },
      date,
    );
  }
  assert.deepEqual(tipDates('Koncert 10. listopada'), {
    dates: ['--10-10'],
    hasYear: false,
    invalid: false,
  });
  assert.equal(tipDates('Koncert 31. veljače 2026.').invalid, true);
  assert.equal(tipDates('Koncert 2026-02-30').invalid, true);
});

test('concurrent calls serialize deduplication and AI reservations on one connection', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const imports = await Promise.all(Array.from({ length: 8 }, () => repo.upsert(candidate())));
    assert.equal(new Set(imports.map((event) => event.id)).size, 1);
    assert.equal((await repo.events()).length, 1);
    const reservations = await Promise.all(Array.from({ length: 8 }, () => repo.reserveAi(0.3, 1)));
    assert.equal(reservations.filter(Boolean).length, 3);
    assert.ok((await repo.aiSpent()) <= 1);
  } finally {
    await repo.close();
  }
});

test('separate connections share leases, deduplication and budget and preserve data after reopen', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'wagz-repository-'));
  const path = join(directory, 'test.sqlite');
  const first = new Repository(path, [source]);
  const second = new Repository(path, [source]);
  let reopened: Repository | undefined;
  try {
    const acquired = await Promise.all([
      first.acquireLease('collection', 30_000),
      second.acquireLease('collection', 30_000),
    ]);
    assert.equal(acquired.filter(Boolean).length, 1);
    assert.equal(await second.isLeaseActive('collection'), true);
    await second.releaseLease('collection', 'wrong-token');
    assert.equal(await first.acquireLease('collection', 30_000), null);
    await second.releaseLease('collection', acquired.find(Boolean)!);
    assert.equal(await first.isLeaseActive('collection'), false);
    const next = await second.acquireLease('collection', 30_000);
    assert.ok(next);
    const [one, two] = await Promise.all([first.upsert(candidate()), second.upsert(candidate())]);
    assert.equal(one.id, two.id);
    const reservations = await Promise.all([first.reserveAi(0.6, 1), second.reserveAi(0.6, 1)]);
    assert.equal(reservations.filter(Boolean).length, 1);
    await first.setAutoPublish(false);
    await first.close();
    await second.close();
    reopened = new Repository(path, [source], true);
    assert.equal(await reopened.autoPublish(), false);
    assert.equal((await reopened.events()).length, 1);
    assert.equal(await reopened.aiSpent(), 0.6);
    assert.equal(await reopened.acquireLease('collection', 30_000), null);
    await reopened.releaseLease('collection', next);
  } finally {
    await reopened?.close();
    await first.close();
    await second.close();
    // This directory is created by the test under the OS temporary directory.
    assert.equal(dirname(resolve(directory)), resolve(tmpdir()));
    rmSync(directory, { recursive: true, force: true });
  }
});

test('composed transactions roll back settings, imports and AI reservations together', async () => {
  const repo = new Repository(':memory:', [source]);
  try {
    await assert.rejects(
      repo.transaction(async (transaction) => {
        await transaction.setAutoPublish(false);
        await transaction.upsert(candidate());
        await transaction.reserveAi(0.6, 1);
        throw new Error('Abort the composed operation');
      }),
      /Abort the composed operation/,
    );
    assert.equal(await repo.autoPublish(), true);
    assert.deepEqual(await repo.events(), []);
    assert.equal(await repo.aiSpent(), 0);
    assert.equal((await repo.upsert(candidate())).publication, 'published');
  } finally {
    await repo.close();
  }
});

test('Postgres adapter confines identifiers and keeps values parameterized', () => {
  assert.equal(
    postgresSql('SELECT payload FROM runs WHERE id=? ORDER BY rowid DESC'),
    'SELECT payload FROM public.wagz_runs WHERE id=$1 ORDER BY ordinal DESC',
  );
  assert.equal(
    postgresSql('INSERT INTO evidence(source_id,event_id) VALUES (?,?)'),
    'INSERT INTO public.wagz_evidence(source_id,event_id) VALUES ($1,$2)',
  );
});

test('hosted require-mode database URLs explicitly verify the TLS certificate and hostname', () => {
  assert.equal(
    new URL(
      postgresConnectionString('postgresql://user:example@database.example/wagz?sslmode=require'),
    ).searchParams.get('sslmode'),
    'verify-full',
  );
  assert.equal(
    postgresConnectionString('postgresql://localhost/wagz'),
    'postgresql://localhost/wagz',
  );
  assert.equal(
    new URL(
      postgresConnectionString('postgresql://127.0.0.1/wagz?sslmode=require'),
    ).searchParams.get('sslmode'),
    'require',
  );
});

test('Postgres writes lock a dedicated connection and release it after commit or rollback', async () => {
  const sessions: Array<{
    statements: Array<{ sql: string; values?: unknown[] }>;
    released: boolean;
  }> = [];
  const database = new PostgresDatabase({
    async connect(): Promise<PostgresConnection> {
      const session = {
        statements: [] as Array<{ sql: string; values?: unknown[] }>,
        released: false,
      };
      sessions.push(session);
      return {
        async query(sql, values) {
          session.statements.push({ sql, values });
          return { rows: [] as Row[] };
        },
        release() {
          session.released = true;
        },
      };
    },
    async end() {},
  });
  await database.transaction(async () => {
    await database.query('INSERT INTO tips(id,payload) VALUES (?,?)', [
      'user-id',
      'untrusted payload',
    ]);
    await database.transaction(async () => {
      await database.query('SELECT payload FROM tips WHERE id=?', ['user-id']);
    }, false);
  });
  assert.equal(sessions.length, 1, 'nested repository calls reuse the same transaction');
  assert.equal(sessions[0].statements[0].sql, 'BEGIN');
  assert.match(sessions[0].statements[1].sql, /pg_advisory_xact_lock/);
  assert.deepEqual(sessions[0].statements[2].values, ['user-id', 'untrusted payload']);
  assert.equal(sessions[0].statements.at(-1)?.sql, 'COMMIT');
  assert.equal(sessions[0].released, true);
  await assert.rejects(
    database.transaction(async () => {
      throw new Error('write failed');
    }),
    /write failed/,
  );
  assert.equal(sessions[1].statements.at(-1)?.sql, 'ROLLBACK');
  assert.equal(sessions[1].released, true);
  await database.transaction(() => database.query('SELECT payload FROM events'), false);
  assert.equal(sessions[2].statements[0].sql, 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  assert.equal(
    sessions[2].statements.some((item) => item.sql.includes('advisory')),
    false,
  );
  assert.equal(sessions[2].released, true);
});
