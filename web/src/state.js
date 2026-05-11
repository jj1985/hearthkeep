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
  last_login_day: 0,
  login_streak: 0,
  bestiary: {},          // enemy_id -> { first_seen, kills }
  ach_claimed: {},
  dragonslayer: false,
  defeated_dragons: [],  // ids of named bosses ever felled
  level_perks: {},       // perm_dmg / perm_hp / perm_atk / perm_gold / perm_range / perm_crit -> stacks
  top_runs: [],          // [{wave, kills, combo, class, when}] sorted desc by wave, cap 5
  run_history: [],       // [{wave, kills, combo, embers, class, when}] cap 8
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

// Daily login. Returns null (no claim today) or {bonus, streak, broke}.
export function processDailyLogin() {
  const day = Math.floor(Date.now() / 86400000);
  if (day === State.last_login_day) return null;
  let broke = false;
  if (State.last_login_day === 0 || day - State.last_login_day > 1) {
    State.login_streak = 1; broke = true;
  } else {
    State.login_streak++;
  }
  State.last_login_day = day;
  const bonus = 1 + Math.min(6, Math.floor(State.login_streak / 2));
  State.embers += bonus;
  persist();
  return { bonus, streak: State.login_streak, broke };
}

// Rebirth: wipes per-track upgrades, gold, lifetime kills, best_wave,
// bosses_felled. Preserves embers + rebirths count + hero_level.
export function rebirth() {
  State.rebirths++;
  State.gold = 0;
  State.lifetime_kills = 0;
  State.bosses_felled = 0;
  State.best_wave = 0;
  State.unlocked_classes = ['warrior'];
  State.meta_milestones = {};
  State.upgrades = {};
  persist();
}

export function canRebirth() { return State.best_wave >= 50; }

// Push a run summary onto history + top-runs leaderboard.
export function recordRun(entry) {
  if (!State.run_history) State.run_history = [];
  if (!State.top_runs) State.top_runs = [];
  State.run_history.push(entry);
  while (State.run_history.length > 8) State.run_history.shift();
  State.top_runs.push(entry);
  State.top_runs.sort((a, b) => (b.wave || 0) - (a.wave || 0));
  while (State.top_runs.length > 5) State.top_runs.pop();
  persist();
}

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
