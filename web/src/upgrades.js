// Persistent upgrade tracks. Survive death; reset on Rebirth.

import { State, persist } from './state.js';

export const UPGRADES = [
  { id: 'dmg',   label: 'Sharper Steel',  desc: '+2 damage / rank',         base: 40,  growth: 1.55, currency: 'gold' },
  { id: 'atk',   label: 'Practiced Form', desc: '+0.20 atk/sec / rank',     base: 80,  growth: 1.65, currency: 'gold' },
  { id: 'range', label: 'Long Reach',     desc: '+30 range / rank',         base: 60,  growth: 1.5,  currency: 'gold' },
  { id: 'hp',    label: 'Iron Body',      desc: '+5 max HP / rank',         base: 50,  growth: 1.6,  currency: 'gold' },
  { id: 'crit',  label: 'Lucky Strike',   desc: '+5% crit chance / rank',   base: 160, growth: 1.9,  currency: 'gold' },
  { id: 'ember_dmg',  label: 'Ember Edge', desc: '+10% global damage / rank', base: 1, growth: 1.6,  currency: 'embers' },
  { id: 'ember_gold', label: 'Hoard Pact', desc: '+25% gold drops / rank',    base: 2, growth: 1.55, currency: 'embers' },
  { id: 'ember_rev',  label: 'Second Wind',desc: '+1 free revive per run',    base: 4, growth: 2.0,  currency: 'embers' },
  { id: 'ember_skill',label: 'Quickened',  desc: '-0.5s skill cooldown / rank', base: 3, growth: 1.7, currency: 'embers' },
  { id: 'ember_aura', label: 'Ember Aura', desc: '+10% damage to enemies in range / rank', base: 5, growth: 1.8, currency: 'embers' },
];

export const MAX_RANK = 30;

function ranks() {
  if (!State.upgrades) State.upgrades = {};
  return State.upgrades;
}

export function rank(id) { return Number(ranks()[id] || 0); }

export function cost(id) {
  const u = UPGRADES.find(x => x.id === id);
  if (!u) return 0;
  const r = rank(id);
  if (r >= MAX_RANK) return -1;
  return Math.round(u.base * Math.pow(u.growth, r));
}

export function currencyOf(id) {
  const u = UPGRADES.find(x => x.id === id);
  return u?.currency || 'gold';
}

export function canBuy(id) {
  const c = cost(id);
  if (c <= 0 || rank(id) >= MAX_RANK) return false;
  return currencyOf(id) === 'embers' ? State.embers >= c : State.gold >= c;
}

export function buy(id) {
  if (!canBuy(id)) return false;
  const c = cost(id);
  if (currencyOf(id) === 'embers') State.embers -= c;
  else State.gold -= c;
  ranks()[id] = rank(id) + 1;
  persist();
  return true;
}

// Effective stat helpers consumed by game.js.
export function bonusDamage() { return rank('dmg') * 2; }
export function bonusAtk() { return rank('atk') * 0.20; }
export function bonusRange() { return rank('range') * 30; }
export function bonusHp() { return rank('hp') * 5; }
export function bonusCrit() { return Math.min(0.95, rank('crit') * 0.05); }

// Ember-priced multipliers.
export function emberDmgMult() { return 1 + rank('ember_dmg') * 0.10; }
export function emberGoldMult() { return 1 + rank('ember_gold') * 0.25; }
export function maxRevives() { return rank('ember_rev'); }
export function emberSkillReduction() { return rank('ember_skill') * 0.5; }
export function emberAuraDmgMult() { return 1 + rank('ember_aura') * 0.10; }
