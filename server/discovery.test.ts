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

test('recommendation presets never create source eligibility, affordability or popularity claims', () => {
  const discovery = inferDiscovery(
    'Koncert mladih glazbenika',
    'Na pozornici nastupaju studenti akademije.',
    url,
  );
  assert.deepEqual(discovery.audiences, []);
  assert.equal(discovery.free, false);
  for (const audience of ['students', 'adults', 'seniors'] as const) {
    const result = recommendationFor(event(discovery), { audience, interests: [] });
    assert.equal(result.kind, 'suggestion');
    assert.equal(result.personal, false);
    assert.deepEqual(result.reasons, ['Vrsta programa: glazba.']);
  }
});

test('explicit audiences retain source reasons, outrank suggestions and ignore legacy interests', () => {
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
  assert.equal(match.score, 105);
  assert.equal(match.kind, 'source');
  assert.equal(match.personal, true);
  assert.equal(match.reasons.length, 3);
  assert.deepEqual(
    match,
    recommendationFor(event(discovery), { audience: 'students', interests: [] }),
  );
  assert.equal(
    recommendationFor(event(discovery), { audience: 'adults', interests: [] }).kind,
    'suggestion',
  );
});

test('student audiences require student evidence, not a general youth or pupil programme', () => {
  for (const text of [
    'Radionica za mlade.',
    'Program za mlade i učenike.',
    'Ulaz je besplatan mladima.',
    'Pozivamo sve mlade u Osijeku.',
    'Koncert za srednjoškolce i učenike.',
    'Na pozornici nastupaju studenti akademije.',
  ])
    assert.deepEqual(inferDiscovery('Program', text, url).audiences, [], text);
  for (const text of [
    'Radionica za studente.',
    'Studentski popust na ulaznice.',
    'Brucošijada.',
    'Pozivamo sve zainteresirane studente.',
  ]) {
    const result = inferDiscovery('Program', text, url);
    assert.deepEqual(result.audiences, ['students'], text);
    assert.equal(
      result.audienceEvidence[0].reason,
      'Najava navodi program ili pogodnost za studente.',
    );
  }
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
