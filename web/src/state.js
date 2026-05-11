import { Save } from './save.js';

const DEFAULTS = {
  gold: 0,
  embers: 0,
  lifetime_kills: 0,
  bosses_felled: 0,
  best_wave: 0,
  unlocked_classes: ['warrior'],
  meta_milestones: {},
  hero_level: 1,
  hero_xp: 0,
  upgrades: {},
  rebirths: 0,
};

export const State = Object.assign({}, DEFAULTS, Save.load());
// Re-merge to fill in any missing keys after a schema bump.
for (const k of Object.keys(DEFAULTS)) {
  if (State[k] === undefined) State[k] = DEFAULTS[k];
}

export function persist() { Save.save(State); }

// ---- XP / leveling ----
export function xpToNext() { return 20 + (State.hero_level - 1) * 15; }
export function grantXp(amount) {
  State.hero_xp += amount;
  let ups = 0;
  while (State.hero_xp >= xpToNext()) {
    State.hero_xp -= xpToNext();
    State.hero_level++;
    ups++;
  }
  return ups;
}

// ---- Milestones ----
export const KILL_UNLOCKS = [
  { id: 'unlock_rogue', kills: 100, klass: 'rogue', label: 'Rogue path opens' },
  { id: 'unlock_wizard', kills: 500, klass: 'wizard', label: 'Wizard path opens' },
  { id: 'unlock_necromancer', kills: 1500, klass: 'necromancer', label: 'Necromancer path opens' },
  { id: 'unlock_bard', kills: 5000, klass: 'bard', label: 'Bard path opens' },
];

export function checkKillMilestones() {
  const fired = [];
  for (const m of KILL_UNLOCKS) {
    if (State.meta_milestones[m.id]) continue;
    if (State.lifetime_kills >= m.kills) {
      State.meta_milestones[m.id] = true;
      if (!State.unlocked_classes.includes(m.klass)) {
        State.unlocked_classes.push(m.klass);
      }
      fired.push(m);
    }
  }
  return fired;
}
