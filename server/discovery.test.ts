import test from 'node:test';
import assert from 'node:assert/strict';
import { inferDiscovery, mergeDiscovery, validateDiscovery } from './discovery.ts';

const url = 'https://example.org/event';

test('negated audiences and unavailable benefits do not become affirmative audience tags', () => {
  for (const text of [
    'Program nije namijenjen studentima.',
    'Popust za studente nije dostupan.',
    'Popust za studente\nnije dostupan.',
    'Popust za studente od 10. listopada nije dostupan.',
    'Nema popusta za studente.',
    'Studentski popust je ukinut.',
    'Bez posebnog popusta za studente.',
    'Ovo nije program za odrasle.',
    'Radionica za umirovljenike je otkazana.',
    'Program nije za starije osobe.',
    'Ulaz studentima nije dozvoljen.',
  ])
    assert.deepEqual(inferDiscovery('Program', text, url).audiences, [], text);
  assert.deepEqual(inferDiscovery('Studentski popust', 'nije dostupan.', url).audiences, []);
});

test('independent positive audience clauses survive negative clauses without borrowing their subjects', () => {
  for (const text of [
    'Program nije za studente, nego za umirovljenike.',
    'Program nije namijenjen studentima. Besplatno za umirovljenike.',
    'Popust za studente nije dostupan, ali ulaz je besplatan za umirovljenike.',
    'Besplatno za umirovljenike, ne za studente.',
    'Nema popusta za studente, ulaz je besplatan za umirovljenike.',
  ])
    assert.deepEqual(inferDiscovery('Program', text, url).audiences, ['seniors'], text);
  assert.deepEqual(
    inferDiscovery(
      'Program',
      'Popust za studente nije dostupan. Radionica je namijenjena studentima.',
      url,
    ).audiences,
    ['students'],
  );
  assert.deepEqual(
    inferDiscovery('Program', 'Radionica za studente, a program za odrasle nije dostupan.', url)
      .audiences,
    ['students'],
  );
});

test('bare senior terminology cannot identify older people, including sporting divisions', () => {
  for (const text of [
    'Program za seniore: prvenstvo u nogometu.',
    'Sportski program za seniore i juniore.',
    'Program za seniore u knjižnici.',
  ])
    assert.deepEqual(inferDiscovery('Program', text, url).audiences, [], text);
  for (const text of [
    'Program za seniore i umirovljenike. Besplatan ulaz umirovljenicima.',
    'Radionica za starije osobe.',
    'Radionica za osobe treće životne dobi.',
    'Nogomet za umirovljenike.',
  ])
    assert.deepEqual(inferDiscovery('Program', text, url).audiences, ['seniors'], text);
});

test('affirmative invitations preserve listed students and multiple audiences', () => {
  const body =
    'Pozivaju sve mlade vizionare, inovatore, studente i entuzijaste na nadolazeći summit!';
  assert.deepEqual(inferDiscovery('Summit', body, url).audiences, ['students']);
  assert.deepEqual(
    inferDiscovery('Program', 'Radionica za studente, za odrasle i za umirovljenike.', url)
      .audiences,
    ['students', 'adults', 'seniors'],
  );
});

test('fresh conservative inference withdraws a stale claim when its source is fetched again', () => {
  const old = inferDiscovery('Program', 'Popust za studente.', url);
  const fresh = inferDiscovery('Program', 'Popust za studente nije dostupan.', url);
  assert.deepEqual(mergeDiscovery(old, fresh, url, null).audiences, []);
});

test('performer identity never creates audience or affordability claims', () => {
  const discovery = inferDiscovery(
    'Koncert mladih glazbenika',
    'Na pozornici nastupaju studenti akademije.',
    url,
  );
  assert.deepEqual(discovery.audiences, []);
  assert.equal(discovery.free, false);
});

test('explicit multiple audiences retain individual source reasons', () => {
  const discovery = inferDiscovery(
    'Radionica',
    'Radionica za studente. Besplatno za umirovljenike.',
    url,
    'Besplatno',
  );
  assert.deepEqual(discovery.audiences, ['students', 'seniors']);
  assert.equal(discovery.free, true);
  assert.ok(discovery.audienceEvidence.every((item) => item.sourceUrl === url));
  assert.equal(discovery.audienceEvidence.length, 2);
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

test('festival cue states an event format, not audience or another event in its description', () => {
  const discovery = inferDiscovery('Festival svjetla', 'Program.', url);
  assert.equal(discovery.prominence?.kind, 'festival');
  assert.deepEqual(discovery.audiences, []);
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
