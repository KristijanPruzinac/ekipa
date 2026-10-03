import test from 'node:test';
import assert from 'node:assert/strict';
import { inferDiscovery, mergeDiscovery, validateDiscovery } from './discovery.ts';
import { parseProfile, recommendationFor } from '../shared/discovery.ts';
import type { WagzEvent } from '../shared/types.ts';

const url = 'https://example.org/event';
const event = (discovery?: WagzEvent['discovery']): WagzEvent => ({
  id: 'event',
  title: 'Koncert',
  description: '',
  startsAt: '2099-10-10',
  endsAt: null,
  venue: 'Osijek',
  address: null,
  city: 'Osijek',
  category: 'music',
  price: null,
  status: 'scheduled',
  publication: 'published',
  sources: [],
  firstSeenAt: '',
  updatedAt: '',
  manuallyEdited: false,
  discovery,
});

test('age choices never imply a genre, student eligibility, affordability or popularity', () => {
  const discovery = inferDiscovery(
    'Koncert mladih glazbenika',
    'Na pozornici nastupaju studenti akademije.',
    url,
  );
  assert.deepEqual(discovery.audiences, []);
  assert.equal(discovery.free, false);
  for (const audience of ['students', 'adults', 'seniors'] as const)
    assert.deepEqual(recommendationFor(event(discovery), { audience, interests: [] }), {
      score: 0,
      reasons: [],
      personal: false,
    });
});

test('explicit audiences retain source reasons and independent chosen interests affect recommendations', () => {
  const discovery = inferDiscovery(
    'Radionica',
    'Radionica za studente. Besplatno za umirovljenike.',
    url,
    'Besplatno',
  );
  assert.deepEqual(discovery.audiences, ['students', 'seniors']);
  assert.equal(discovery.free, true);
  assert.ok(discovery.audienceEvidence.every((item) => item.sourceUrl === url));
  const match = recommendationFor(event(discovery), { audience: 'students', interests: ['music'] });
  assert.equal(match.score, 6);
  assert.equal(match.personal, true);
  assert.equal(match.reasons.length, 2);
  assert.equal(recommendationFor(event(discovery), { audience: 'adults', interests: [] }).score, 0);
});

test('festival cue states a format, not popularity; cancellation removes recommendations', () => {
  const discovery = inferDiscovery('Festival svjetla', 'Program.', url);
  assert.equal(discovery.prominence?.kind, 'festival');
  assert.equal(
    recommendationFor(event(discovery), { audience: 'all', interests: [] }).personal,
    false,
  );
  assert.equal(
    recommendationFor(
      { ...event(discovery), status: 'cancelled' },
      { audience: 'all', interests: ['music'] },
    ).score,
    0,
  );
  assert.equal(
    inferDiscovery('Recital', 'Nastupao je na festivalima diljem svijeta.', url).prominence,
    null,
  );
});

test('refresh withdraws stale source audience cues while preserving other evidence and actual free price', () => {
  const first = inferDiscovery('Radionica', 'Program za studente.', url, 'Besplatno');
  const other = inferDiscovery('Radionica', 'Program za odrasle.', 'https://other.example/event');
  const combined = mergeDiscovery(first, other, 'https://other.example/event', null);
  assert.deepEqual(combined.audiences, ['students', 'adults']);
  const refreshed = mergeDiscovery(combined, inferDiscovery('Radionica', '', url), url, '10 €');
  assert.deepEqual(refreshed.audiences, ['adults']);
  assert.equal(refreshed.free, false);
  assert.deepEqual(validateDiscovery(first, 'https://other.example/event')?.audiences, []);
});

test('device preferences discard corrupted or unsupported input', () => {
  assert.deepEqual(parseProfile(null), { audience: 'all', interests: [] });
  assert.deepEqual(
    parseProfile({ audience: 'invented', interests: ['music', 'music', 'nonsense', 42] }),
    { audience: 'all', interests: ['music'] },
  );
});
