// Run-only perks. State accumulates into the Game instance.

export const PERKS = [
  { id: 'hot_steel',   label: 'Hot Steel',     desc: '+25% damage.',          tags: ['warrior','melee'],     kind: 'dmg', value: 0.25 },
  { id: 'glass_bones', label: 'Glass Bones',   desc: '+10% crit chance.',     tags: ['rogue','crit'],        kind: 'crit', value: 0.10 },
  { id: 'arcane_arc',  label: 'Arcane Arc',    desc: '+80 range.',            tags: ['wizard','arcane'],     kind: 'range', value: 80 },
  { id: 'reaping',     label: 'Reaping',       desc: '+50% gold per kill.',   tags: ['necromancer','death'], kind: 'gold', value: 0.5 },
  { id: 'tempo',       label: 'Tempo',         desc: '+0.5 atk/sec.',         tags: ['bard','support'],      kind: 'atk', value: 0.5 },
  { id: 'ember_in',    label: 'Ember Within',  desc: '+15% damage globally.', tags: ['any'],                 kind: 'dmg', value: 0.15 },
  { id: 'hoarder',     label: 'Hoarder',       desc: '+30% wave bonus.',      tags: ['any'],                 kind: 'wave', value: 0.30 },
  { id: 'bloodlust',   label: 'Bloodlust',     desc: '+0.4 atk/sec.',         tags: ['warrior','melee'],     kind: 'atk', value: 0.4 },
  { id: 'phantom',     label: 'Phantom',       desc: '+10% crit + 50 range.', tags: ['rogue','crit'],        kind: 'phantom', value: 0.10 },
  { id: 'frostbite',   label: 'Frostbite',     desc: '+20% dmg + slower spawns.', tags: ['wizard','arcane'], kind: 'frostbite', value: 0.20 },
  { id: 'chime',       label: 'Resonant Chime',desc: '+30% wave + +20% gold.',tags: ['bard','support'],      kind: 'chime', value: 0.20 },
  { id: 'fortunate',   label: 'Fortunate',     desc: '+3% Mythic chance.',    tags: ['any'],                 kind: 'mythic', value: 0.03 },
  { id: 'aegis',       label: 'Aegis',         desc: '-40% contact damage.',  tags: ['warrior','melee'],     kind: 'aegis', value: 0.40 },
];

export function rollPerks(klass, taken, count = 3) {
  const classes = [klass];
  const pool = [];
  for (const p of PERKS) {
    if (taken.has(p.id)) continue;
    let w = 1;
    for (const t of p.tags) {
      if (t === 'any') w = Math.max(w, 2);
      else if (classes.includes(t)) w += 4;
    }
    for (let i = 0; i < w; i++) pool.push(p);
  }
  const picks = [];
  while (picks.length < count && pool.length > 0) {
    const idx = Math.floor(Math.random() * pool.length);
    const pick = pool[idx];
    if (!picks.includes(pick)) picks.push(pick);
    for (let i = pool.length - 1; i >= 0; i--) if (pool[i] === pick) pool.splice(i, 1);
  }
  return picks;
}

export function applyPerk(game, perk) {
  game.takenPerks.add(perk.id);
  const v = perk.value;
  switch (perk.kind) {
    case 'dmg': game.dmgMult *= (1 + v); break;
    case 'crit': game.critBonus += v; break;
    case 'range': game.rangeBonus += v; break;
    case 'gold': game.goldMult *= (1 + v); break;
    case 'atk': game.atkBonus += v; break;
    case 'wave': game.waveBonusMult *= (1 + v); break;
    case 'phantom': game.critBonus += v; game.rangeBonus += 50; break;
    case 'frostbite': game.dmgMult *= 1.2; game.spawnSlow = Math.min(0.6, game.spawnSlow + 0.15); break;
    case 'chime': game.waveBonusMult *= 1.30; game.goldMult *= 1.20; break;
    case 'mythic': game.mythicBonus += v; break;
    case 'aegis': game.contactReduction = Math.min(0.9, game.contactReduction + v); break;
  }
}
