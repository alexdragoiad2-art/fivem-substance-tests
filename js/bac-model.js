// bac-model.js - modelul de alcoolemie din it_substante, portat in JavaScript (pur, fara dependinte).
// Aceeasi formula ruleaza pe server (Lua, server/corp.lua) si pe client (Lua, client/efecte.lua).
//
// Modelul: alcoolul baut intra intai in "stomac" (pending) si trece in sange cu o viteza fixa (absorbtie);
// in acelasi timp ficatul elimina o cantitate fixa pe minut (eliminare de ordin zero, ca in realitate).
// Unitatea: promile (‰ = g/L sange).

'use strict';

const DEFAULTS = Object.freeze({
  absorbPerMin: 0.10, // ‰ trecute din stomac in sange pe minut
  eliminPerMin: 0.01, // ‰ eliminate pe minut (0,1‰ la 10 minute)
  max: 4.0,           // plafon pentru cantitatea din stomac
});

/**
 * Avanseaza starea cu `minutes` minute, in pasi de cel mult 1 minut (ca pe server).
 * @param {{bac:number, pending:number}} state
 * @param {number} minutes
 * @param {Partial<typeof DEFAULTS>} [opts]
 * @returns {{bac:number, pending:number}} stare noua (nu modifica intrarea)
 */
function advance(state, minutes, opts = {}) {
  const { absorbPerMin, eliminPerMin } = { ...DEFAULTS, ...opts };
  let { bac, pending } = state;
  let left = Math.min(Math.max(0, minutes), 600);
  while (left > 0) {
    const step = Math.min(1, left);
    const absorbed = Math.min(pending, absorbPerMin * step);
    pending -= absorbed;
    bac = Math.max(0, bac + absorbed - eliminPerMin * step);
    left -= step;
  }
  if (bac < 0.001 && pending < 0.001) { bac = 0; pending = 0; }
  return { bac, pending };
}

/** O bautura noua: alcoolul ajunge intai in stomac. */
function drink(state, amount, opts = {}) {
  const { max } = { ...DEFAULTS, ...opts };
  return { bac: state.bac, pending: Math.min(max, state.pending + amount) };
}

/** Etilotestul masoara aerul expirat: in Romania 0,40 mg/L aer = 0,80 g/L sange (raport 2). */
function breathFromBac(bac, ratio = 2.0) {
  return Math.round((bac / ratio) * 100) / 100;
}

/** Incadrarea rezultatului etilotestului (mg/L aer expirat). */
function verdict(mgPerL) {
  if (mgPerL >= 0.40) return 'infractiune';
  if (mgPerL >= 0.05) return 'contraventie';
  return 'negativ';
}

/** Cate minute pana cand alcoolemia scade sub un prag (simulare, max 24 h). */
function minutesUntilBelow(state, threshold, opts = {}) {
  let s = state;
  for (let m = 0; m <= 1440; m++) {
    if (s.bac < threshold && s.pending === 0) return m;
    s = advance(s, 1, opts);
  }
  return Infinity;
}

module.exports = { DEFAULTS, advance, drink, breathFromBac, verdict, minutesUntilBelow };
