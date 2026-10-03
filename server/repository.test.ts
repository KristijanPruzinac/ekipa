import test from 'node:test';
import assert from 'node:assert/strict';
import { Repository } from './repository.ts';
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

test('rerunning collection updates the occurrence instead of duplicating it; reschedule is kept', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = repo.upsert(candidate());
    const second = repo.upsert(candidate({ startsAt: '2026-10-11T20:00:00+02:00' }));
    assert.equal(second.id, first.id);
    assert.equal(repo.events().length, 1);
    assert.equal(second.startsAt, '2026-10-11T20:00:00+02:00');
  } finally {
    repo.close();
  }
});
test('exact cross-source duplicates retain both provenance links; different performances stay separate', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = repo.upsert(candidate());
    const duplicate = repo.upsert(
      candidate({
        sourceId: 'b',
        sourceUrl: 'https://other.org/1',
        externalId: 'b1',
        title: 'KONCERT MLADIH!',
      }),
    );
    assert.equal(duplicate.id, first.id);
    assert.equal(duplicate.sources.length, 2);
    repo.upsert(candidate({ externalId: '2', startsAt: '2026-10-10T22:00:00+02:00' }));
    assert.equal(repo.events().length, 2);
  } finally {
    repo.close();
  }
});
test('unknown venue stays draft, toggle affects new imports only, rejection survives refetch', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    assert.equal(repo.upsert(candidate({ venue: null })).publication, 'draft');
    repo.setAutoPublish(false);
    const next = repo.upsert(candidate({ externalId: '2', title: 'Drugi koncert' }));
    assert.equal(next.publication, 'draft');
    repo.editEvent(next.id, 'rejected');
    repo.setAutoPublish(true);
    assert.equal(
      repo.upsert(candidate({ externalId: '2', title: 'Drugi koncert' })).publication,
      'rejected',
    );
  } finally {
    repo.close();
  }
});
test('an incomplete automatic import can publish when source facts arrive, but a manually held draft stays held', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = repo.upsert(candidate({ venue: null }));
    assert.equal(first.publication, 'draft');
    assert.equal(repo.upsert(candidate()).publication, 'published');
    repo.editEvent(first.id, 'draft');
    assert.equal(repo.upsert(candidate()).publication, 'draft');
  } finally {
    repo.close();
  }
});
test('operator corrections survive later imports; cancellation is stored for unedited events', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const event = repo.upsert(candidate());
    assert.equal(repo.upsert(candidate({ status: 'cancelled' })).status, 'cancelled');
    repo.editEvent(event.id, undefined, { title: 'Potvrđeni naslov', venue: 'Novo mjesto' });
    assert.equal(repo.upsert(candidate()).title, 'Potvrđeni naslov');
    assert.equal(repo.event(event.id)?.venue, 'Novo mjesto');
  } finally {
    repo.close();
  }
});
test('budget reservation blocks overspending concurrently and preserves unknown charges', () => {
  const repo = new Repository(':memory:', []);
  try {
    const first = repo.reserveAi(0.6, 1)!;
    assert.ok(first);
    assert.equal(repo.reserveAi(0.6, 1), null);
    repo.settleAi(first, 0.01);
    assert.ok(repo.reserveAi(0.6, 1));
    const unknown = repo.reserveAi(0.3, 1)!;
    repo.settleAi(unknown, null);
    assert.equal(repo.reserveAi(0.1, 1), null);
  } finally {
    repo.close();
  }
});
test('approved linkless community tip is idempotent and does not invent a source URL', () => {
  const repo = new Repository(':memory:', []);
  try {
    const draft = { ...candidate(), sourceUrl: null };
    const first = repo.publishTip('same-tip', draft);
    assert.equal(repo.publishTip('same-tip', draft).id, first.id);
    assert.equal(repo.events().length, 1);
    assert.deepEqual(first.sources, []);
  } finally {
    repo.close();
  }
});
test('calendar dates, unknown times, Zagreb day boundaries and ongoing ranges stay honest', () => {
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
test('only unmistakable automated junk archives; vague real tips stay for review', () => {
  assert.equal(classifyTip('aaaaaaaaaaaaaaaaaaaaaaaa').archive, true);
  assert.equal(classifyTip('Čuo sam da uskoro ima svirka u Osijeku').archive, false);
  assert.equal(classifyTip('festival').archive, false);
});

test('ambiguous date-only evidence never attaches to or overwrites a true showtime', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const early = repo.upsert(candidate());
    const late = repo.upsert(
      candidate({ externalId: 'late', startsAt: '2026-10-10T22:00:00+02:00' }),
    );
    const unresolved = repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', startsAt: '2026-10-10' }),
    );
    assert.notEqual(unresolved.id, early.id);
    assert.notEqual(unresolved.id, late.id);
    assert.equal(unresolved.publication, 'draft');
    assert.equal(unresolved.autoPublishEligible, false);
    const resolved = repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', startsAt: '2026-10-10T22:00:00+02:00' }),
    );
    assert.equal(resolved.id, unresolved.id);
    assert.equal(
      resolved.publication,
      'draft',
      'resolved collision remains visible for manual reconciliation',
    );
    assert.equal(repo.event(early.id)?.startsAt, '2026-10-10T20:00:00+02:00');
    assert.equal(repo.event(late.id)?.startsAt, '2026-10-10T22:00:00+02:00');
    assert.equal(repo.event(early.id)?.sources.length, 1);
    assert.equal(repo.event(late.id)?.sources.length, 1);
    assert.equal(
      repo.upsert(candidate()).publication,
      'published',
      'a held unknown row does not demote the true occurrence',
    );
    assert.equal(
      repo.upsert(candidate({ externalId: 'late', startsAt: '2026-10-10T22:00:00+02:00' }))
        .publication,
      'published',
      'a resolved but held duplicate does not demote the true occurrence',
    );
    assert.equal(repo.event(late.id)?.publication, 'published');
  } finally {
    repo.close();
  }
});

test('unknown venue is not an alias even with one plausible match; later venue facts cannot hijack it', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const original = repo.upsert(candidate());
    const unknown = repo.upsert(candidate({ sourceId: 'b', externalId: 'unknown', venue: null }));
    assert.notEqual(unknown.id, original.id);
    assert.equal(unknown.publication, 'draft');
    const changed = repo.upsert(
      candidate({ sourceId: 'b', externalId: 'unknown', venue: 'Druga dvorana' }),
    );
    assert.equal(changed.id, unknown.id);
    assert.equal(changed.publication, 'draft');
    assert.equal(repo.event(original.id)?.venue, 'Dvorana');
    assert.equal(repo.event(original.id)?.publication, 'published');
  } finally {
    repo.close();
  }
});

test('a weaker refresh on an exact cross-source alias preserves known time and venue', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const original = repo.upsert(candidate());
    const alias = repo.upsert(candidate({ sourceId: 'b', externalId: 'alias' }));
    assert.equal(alias.id, original.id);
    repo.upsert(candidate({ externalId: 'later', startsAt: '2026-10-10T22:00:00+02:00' }));
    const weak = repo.upsert(
      candidate({ sourceId: 'b', externalId: 'alias', startsAt: '2026-10-10', venue: null }),
    );
    assert.equal(weak.id, original.id);
    assert.equal(weak.startsAt, original.startsAt);
    assert.equal(weak.venue, original.venue);
    assert.equal(weak.publication, 'published');
    assert.equal(repo.events().length, 2);
  } finally {
    repo.close();
  }
});

test('a reschedule colliding with another exact occurrence is held without changing its evidence', () => {
  const repo = new Repository(':memory:', [source]);
  try {
    const first = repo.upsert(candidate());
    const second = repo.upsert(
      candidate({ externalId: 'second', startsAt: '2026-10-11T20:00:00+02:00' }),
    );
    const moved = repo.upsert(candidate({ startsAt: second.startsAt }));
    assert.equal(moved.id, first.id);
    assert.equal(moved.publication, 'draft');
    assert.equal(repo.event(second.id)?.publication, 'published');
    assert.equal(repo.event(second.id)?.sources.length, 1);
    assert.equal(repo.events().length, 2);
  } finally {
    repo.close();
  }
});

test('a partial run with imports counts as last successful contact without losing warnings', () => {
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
    repo.saveRun({ ...base, id: 'imported' });
    repo.saveRun({ ...base, id: 'empty', imported: 0, finishedAt: '2026-10-02T10:01:00Z' });
    const health = repo.sourceHealth()[0];
    assert.equal(health.lastSuccessAt, base.finishedAt);
    assert.equal(health.latestRun?.id, 'empty');
    assert.equal(health.latestRun?.status, 'partial');
    assert.deepEqual(health.latestRun?.warnings, base.warnings);
  } finally {
    repo.close();
  }
});

test('date ranges compare Zagreb-normalized dates and still reject reversed instants', () => {
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

test('tip dates preserve explicit ISO and Croatian dates without inferring missing years', () => {
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
