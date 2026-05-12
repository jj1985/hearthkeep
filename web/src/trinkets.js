// Trinket catalog — persistent boss drops. One equipped at a time.
// Each kind maps to a small bonus the game accessors fold in.

import { State, persist } from './state.js';

export const TRINKETS = [
  { id: 'krrik_tusk',   label: "Krrik's Tusk",        desc: '+10% damage' },
  { id: 'krrik_banner', label: "Warband Banner",      desc: '+10% gold from kills' },
  { id: 'vyx_scale',    label: 'Vyxhasis Scale',      desc: '+15% max HP' },
  { id: 'vyx_eye',      label: 'Vyxhasis Eye',        desc: '+5% crit chance' },
  { id: 'aeth_feather', label: 'Aethyrnax Feather',   desc: '+50 range' },
  { id: 'aeth_crystal', label: 'Aethyrnax Crystal',   desc: '+0.3 atk/sec' },
  { id: 'mythic_shard', label: 'Mythic Shard',        desc: '+2% Mythic chance' },
  { id: 'dragon_heart', label: 'Dragon Heart',        desc: '+20% wave-clear gold' },
];

// Map drop pool by boss id.
export const BOSS_DROPS = {
  boss_warchief:  ['krrik_tusk', 'krrik_banner'],
  boss_vyxhasis:  ['vyx_scale', 'vyx_eye'],
  boss_aethyrnax: ['aeth_feather', 'aeth_crystal'],
};

export function tryDrop(bossId) {
  if (Math.random() >= 0.25) return null;
  const pool = BOSS_DROPS[bossId] || ['mythic_shard', 'dragon_heart'];
  const id = pool[Math.floor(Math.random() * pool.length)];
  if (!State.trinkets) State.trinkets = {};
  if (State.trinkets[id]) return null; // already owned
  State.trinkets[id] = true;
  persist();
  return TRINKETS.find(t => t.id === id);
}

export function equipped() {
  return State.equipped_trinket || '';
}

export function equip(id) {
  State.equipped_trinket = id;
  persist();
}

// Accessors — each returns 0 if the trinket isn't equipped.
export function dmgBonus()      { return equipped() === 'krrik_tusk'   ? 0.10 : 0; }
export function goldBonus()     { return equipped() === 'krrik_banner' ? 0.10 : 0; }
export function hpBonus()       { return equipped() === 'vyx_scale'    ? 0.15 : 0; }
export function critBonus()     { return equipped() === 'vyx_eye'      ? 0.05 : 0; }
export function rangeBonus()    { return equipped() === 'aeth_feather' ? 50   : 0; }
export function atkBonus()      { return equipped() === 'aeth_crystal' ? 0.3  : 0; }
export function mythicBonus()   { return equipped() === 'mythic_shard' ? 0.02 : 0; }
export function waveBonus()     { return equipped() === 'dragon_heart' ? 0.20 : 0; }
