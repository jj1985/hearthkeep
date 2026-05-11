// Persistent upgrade tracks. Survive death; reset on Rebirth.

import { State, persist } from './state.js';

export const UPGRADES = [
  { id: 'dmg',   label: 'Sharper Steel',  desc: '+2 damage / rank',         base: 40,  growth: 1.55 },
  { id: 'atk',   label: 'Practiced Form', desc: '+0.20 atk/sec / rank',     base: 80,  growth: 1.65 },
  { id: 'range', label: 'Long Reach',     desc: '+30 range / rank',         base: 60,  growth: 1.5  },
  { id: 'hp',    label: 'Iron Body',      desc: '+5 max HP / rank',         base: 50,  growth: 1.6  },
  { id: 'crit',  label: 'Lucky Strike',   desc: '+5% crit chance / rank',   base: 160, growth: 1.9  },
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

export function canBuy(id) {
  const c = cost(id);
  return c > 0 && State.gold >= c && rank(id) < MAX_RANK;
}

export function buy(id) {
  if (!canBuy(id)) return false;
  const c = cost(id);
  State.gold -= c;
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
