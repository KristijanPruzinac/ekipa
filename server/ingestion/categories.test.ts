import test from 'node:test';
import assert from 'node:assert/strict';
import { categoryFor } from './parsers.ts';
import { isWorkshopEvent, themeForCategory } from '../../shared/discovery.ts';
import { categories } from '../../shared/types.ts';

test('explicit dance formats and practical workshops have distinct categories', () => {
  for (const title of [
    'Salsa i bachata party',
    'Bachata social',
    'Plesnjak za odrasle',
    'Plesna večer',
    'Festival plesa',
    'Početak tečaja salse',
    'Nova grupa tečaja tanga',
    'Dani otvorenih vrata plesne škole',
    'Radionica bachate za početnike',
    'Plesna radionica u sklopu festivala',
    'Dance workshop',
    'Početni plesni tečaj swinga',
    'Balet za odrasle — početak tečaja',
    'Dan otvorenih vrata baletne škole',
    'Radionica baleta za odrasle',
  ])
    assert.equal(categoryFor(title), 'dance', title);
  for (const title of [
    'Plesna predstava',
    'Baletna predstava',
    'Labuđe jezero — balet',
    'Plesna izvedba',
    'Baletni performans',
    'Baletna večer',
    'Baletna gala',
    'Plesna večer — plesna predstava ansambla',
  ])
    assert.equal(categoryFor(title), 'theatre', title);
  for (const title of [
    'Radionica keramike',
    'Kreativna radionica za djecu',
    'Workshop fotografije',
    'Radionica u sklopu festivala',
    'Radionica kuhanja salsa umaka',
    'Radionica fotografiranja plesa',
    'Dance music production workshop',
    'Radionica izrade baletnih kostima',
  ]) {
    assert.equal(categoryFor(title), 'workshop', title);
  }
  assert.ok(categories.includes('dance'));
  assert.ok(categories.includes('workshop'));
  assert.equal(themeForCategory('dance'), 'dance');
  assert.equal(themeForCategory('workshop'), 'workshop');
});

test('incidental dancing/workshops do not replace a main concert, festival or open day', () => {
  for (const [title, body, expected] of [
    ['Koncert elektroničke dance glazbe', 'Publika će plesati cijelu večer.', 'music'],
    ['Salsa koncert', 'Nakon koncerta slijedi plesna radionica.', 'music'],
    ['Koncert i radionica plesa', 'Glazbeni program.', 'music'],
    ['Festival grada', 'Program sadrži radionice keramike i plesne radionice.', 'culture'],
    ['Festival grada — radionice plesa', '', 'culture'],
    ['Dan otvorenih vrata i dan karijera', 'Radionica robotike i radionica plesa.', 'community'],
    ['Dani otvorenih vrata — radionice plesa', '', 'community'],
    ['Izložba fotografija baleta', '', 'culture'],
    ['Filmska večer o plesu', '', 'film'],
    ['Projekcija filma Balet', 'Priča o baletnoj predstavi.', 'film'],
    ['Redovni satovi salse utorkom i četvrtkom', '', 'other'],
    ['Početni plesni tečaj swinga — redovni tjedni satovi', '', 'other'],
    [
      'Sportski dan — učimo, istražujemo i stvaramo zajedno',
      'Razvijamo znanje i kompetencije uz sportska natjecanja.',
      'sport',
    ],
    ['Koncert — učimo i stvaramo zajedno', 'Glazbeni program promiče znanje.', 'music'],
    [
      'Festival grada',
      'Učimo, istražujemo i stvaramo zajedno na radionicama digitalnih kompetencija.',
      'culture',
    ],
  ])
    assert.equal(categoryFor(`${title} ${body}`, title), expected, title);
});

test('screenings and literary programmes have precise categories, independent of venue', () => {
  for (const title of [
    'Projekcija dokumentarnog filma',
    'Filmska večer o kazalištu',
    'Filmski festival',
    'Kino matineja',
  ]) {
    assert.equal(categoryFor(title), 'film', title);
  }
  for (const title of [
    'Književna večer',
    'Predstavljanje knjige',
    'Promocija romana',
    'Čitateljski klub',
    'Večer poezije',
  ]) {
    assert.equal(categoryFor(title), 'literature', title);
  }
  for (const [title, body, expected] of [
    ['Radionica snimanja filma', 'Projekcija filma nastalog na radionici.', 'workshop'],
    ['Radionica pisanja', 'Književna večer u knjižnici.', 'workshop'],
    ['Sportska radionica', 'U knjižnici GISKO.', 'workshop'],
    ['Koncert filmske glazbe', 'Sviranje glazbe iz filmova.', 'music'],
    ['Književna večer s autorom', 'Autor je pisao glazbu za kazalište.', 'literature'],
    ['Projekcija filma o plesu', 'Nakon filma razgovor o kazališnoj predstavi.', 'film'],
  ])
    assert.equal(categoryFor(`${title} ${body}`, title), expected, title);
  assert.equal(themeForCategory('film'), 'film');
  assert.equal(themeForCategory('literature'), 'literature');
});

test('secondary workshop wording is explicit and does not promote incidental programme items', () => {
  for (const [title, description, expected] of [
    ['Radionica bachate', '', true],
    ['Bachata za početnike', 'Plesna radionica otvorena početnicima.', true],
    ['Plesnjak', 'Nakon druženja spominjemo radionicu idući tjedan.', false],
    ['Festival plesa', 'Radionica je jedan dio festivalskog programa.', false],
    ['Plesna večer i radionica', '', false],
  ] as const)
    assert.equal(isWorkshopEvent({ title, description }), expected, title);
});
