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
  { id: 'ourz_horn',    label: 'Ourzhal Horn',        desc: '+1 max revive per run' },
  { id: 'void_sigil',   label: 'Void Sigil',          desc: '+15% damage' },
  { id: 'sun_token',    label: 'Sunfire Token',       desc: '+0.4 atk/sec' },
  { id: 'forge_anvil',  label: 'Forge Anvil Sliver',  desc: '+10% max HP' },
];

// Map drop pool by boss id.
export const BOSS_DROPS = {
  boss_warchief:  ['krrik_tusk', 'krrik_banner', 'forge_anvil'],
  boss_vyxhasis:  ['vyx_scale', 'vyx_eye', 'sun_token'],
  boss_aethyrnax: ['aeth_feather', 'aeth_crystal', 'void_sigil'],
  boss_ourzhal:   ['ourz_horn', 'void_sigil', 'mythic_shard'],
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
export function dmgBonus()      {
  if (equipped() === 'krrik_tusk') return 0.10;
  if (equipped() === 'void_sigil') return 0.15;
  return 0;
}
export function goldBonus()     { return equipped() === 'krrik_banner' ? 0.10 : 0; }
export function hpBonus()       {
  if (equipped() === 'vyx_scale')   return 0.15;
  if (equipped() === 'forge_anvil') return 0.10;
  return 0;
}
export function critBonus()     { return equipped() === 'vyx_eye'      ? 0.05 : 0; }
export function rangeBonus()    { return equipped() === 'aeth_feather' ? 50   : 0; }
export function atkBonus()      {
  if (equipped() === 'aeth_crystal') return 0.3;
  if (equipped() === 'sun_token')    return 0.4;
  return 0;
}
export function mythicBonus()   { return equipped() === 'mythic_shard' ? 0.02 : 0; }
export function waveBonus()     { return equipped() === 'dragon_heart' ? 0.20 : 0; }
export function bonusReviveTrinket() { return equipped() === 'ourz_horn' ? 1 : 0; }
