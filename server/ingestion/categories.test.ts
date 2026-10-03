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
    'Plesna predstava',
    'Baletna predstava',
    'Labuđe jezero — balet',
    'Festival plesa',
    'Početak tečaja salse',
    'Nova grupa tečaja tanga',
    'Dani otvorenih vrata plesne škole',
    'Radionica bachate za početnike',
    'Plesna radionica u sklopu festivala',
    'Dance workshop',
    'Početni plesni tečaj swinga',
  ])
    assert.equal(categoryFor(title), 'dance', title);
  for (const title of [
    'Radionica keramike',
    'Kreativna radionica za djecu',
    'Workshop fotografije',
    'Radionica u sklopu festivala',
    'Radionica kuhanja salsa umaka',
    'Radionica fotografiranja plesa',
    'Dance music production workshop',
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
    ['Filmska večer o plesu', '', 'culture'],
    ['Redovni satovi salse utorkom i četvrtkom', '', 'other'],
    ['Početni plesni tečaj swinga — redovni tjedni satovi', '', 'other'],
  ])
    assert.equal(categoryFor(`${title} ${body}`, title), expected, title);
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
