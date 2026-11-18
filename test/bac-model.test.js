// Teste pentru modelul de alcoolemie. Rulare: npm test  (foloseste node:test, fara dependinte)
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { advance, drink, breathFromBac, verdict, minutesUntilBelow } = require('../js/bac-model');

const close = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`);

test('o bere (0,20‰) trece in sange in ~2 minute', () => {
  let s = drink({ bac: 0, pending: 0 }, 0.20);
  s = advance(s, 1);
  close(s.bac, 0.09);     // 0,10 absorbit - 0,01 eliminat
  s = advance(s, 1);
  close(s.pending, 0);
  close(s.bac, 0.18);
});

test('alcoolemia nu devine niciodata negativa', () => {
  const s = advance({ bac: 0.05, pending: 0 }, 600);
  assert.equal(s.bac, 0);
  assert.equal(s.pending, 0);
});

test('eliminarea este de 0,1‰ la 10 minute', () => {
  const s = advance({ bac: 1.0, pending: 0 }, 10);
  close(s.bac, 0.9, 1e-6);
});

test('nu modifica starea primita', () => {
  const start = Object.freeze({ bac: 0.5, pending: 0.2 });
  advance(start, 5);
  assert.deepEqual(start, { bac: 0.5, pending: 0.2 });
});

test('etilotest: 0,80 g/L sange = 0,40 mg/L aer', () => {
  assert.equal(breathFromBac(0.80), 0.40);
  assert.equal(breathFromBac(1.46), 0.73);
});

test('incadrarea legala dupa mg/L', () => {
  assert.equal(verdict(0.00), 'negativ');
  assert.equal(verdict(0.04), 'negativ');
  assert.equal(verdict(0.05), 'contraventie');
  assert.equal(verdict(0.39), 'contraventie');
  assert.equal(verdict(0.40), 'infractiune');
});

test('dupa 4 beri, sub 0,2‰ in ~60 de minute', () => {
  // 0,80‰ intra in sange in 8 min (eliminand 0,08‰ intre timp) -> varf 0,72‰;
  // apoi (0,72 - 0,20) / 0,01 = 52 min -> ~60 min in total.
  let s = { bac: 0, pending: 0 };
  for (let i = 0; i < 4; i++) s = drink(s, 0.20);
  const m = minutesUntilBelow(s, 0.20);
  assert.ok(m >= 58 && m <= 62, `minute: ${m}`);
});
