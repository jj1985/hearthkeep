// Named class synergy bonuses. Pure data; pure lookup.

const PAIRS = [
  ['warrior',     'rogue',       'Vanguard',    { atk: 0.15 }],
  ['warrior',     'wizard',      'Spellblade',  { dmg: 0.10 }],
  ['warrior',     'necromancer', 'Death Knight',{ dmg: 0.10 }],
  ['warrior',     'bard',        'Warden',      { gold: 0.20 }],
  ['rogue',       'wizard',      'Arcanist',    { crit: 0.05 }],
  ['rogue',       'necromancer', 'Shadowstep',  { atk: 0.10, gold: 0.10 }],
  ['rogue',       'bard',        'Trickster',   { atk: 0.10 }],
  ['wizard',      'necromancer', 'Lich',        { dmg: 0.15 }],
  ['wizard',      'bard',        'Loremaster',  { dmg: 0.05, gold: 0.15 }],
  ['necromancer', 'bard',        'Soulsinger',  { gold: 0.20 }],
];

const TRIOS = [
  ['warrior', 'rogue',  'wizard',      'Triumvirate', { dmg: 0.25 }],
  ['warrior', 'wizard', 'bard',        'Concordat',   { dmg: 0.10, atk: 0.10, gold: 0.10 }],
  ['warrior', 'rogue',  'necromancer', 'Reapers',     { dmg: 0.20, atk: 0.05 }],
];

function hasAll(set, items) {
  for (const i of items) if (!set.has(i)) return false;
  return true;
}

// loadout = [primary, secondary?, tertiary?]; secondary/tertiary may be empty.
// Trios checked first when all 3 are filled; pairs scan otherwise.
export function synergyFor(loadout) {
  const filled = loadout.filter(c => c);
  const set = new Set(filled);
  if (filled.length >= 3) {
    for (const [a, b, c, label, mods] of TRIOS) {
      if (hasAll(set, [a, b, c])) return { label, ...mods };
    }
  }
  if (filled.length >= 2) {
    for (const [a, b, label, mods] of PAIRS) {
      if (hasAll(set, [a, b])) return { label, ...mods };
    }
  }
  return null;
}
