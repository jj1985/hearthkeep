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
  daily_curse: '',       // one of CURSES keys (rolled per day)
  challenge_active: false,
  curses_cleared: 0,
  lifetime_embers: 0,    // Glory — never-decreasing total
  sfx_volume: 0.7,
  weekly: null,          // {week, target, kind, progress, reward, claimed}
  trinkets: {},          // id -> true (owned)
  equipped_trinket: '',
};

const WEEKLY_MISSIONS = [
  { kind: 'wave',     target: 30, reward: 30, label: 'Reach wave 30 in one run' },
  { kind: 'kills',    target: 500, reward: 25, label: 'Get 500 kills in a single run' },
  { kind: 'bosses',   target: 3,  reward: 30, label: 'Fell 3 bosses in a single run' },
  { kind: 'embers',   target: 50, reward: 30, label: 'Bank 50 Embers this week' },
  { kind: 'rebirths', target: 1,  reward: 50, label: 'Earn one Rebirth Mark' },
];

export function processWeekly() {
  const week = Math.floor(Date.now() / (7 * 86400000));
  if (!State.weekly || State.weekly.week !== week) {
    const m = WEEKLY_MISSIONS[week % WEEKLY_MISSIONS.length];
    State.weekly = { week, ...m, progress: 0, claimed: false };
    persist();
    return State.weekly;
  }
  return State.weekly;
}

// Called whenever a metric that might satisfy the weekly progresses.
// `metric` = 'wave' | 'kills' | 'bosses' | 'embers' | 'rebirths'
export function tickWeekly(metric, runValue) {
  const w = State.weekly;
  if (!w || w.kind !== metric || w.claimed) return false;
  // Track "best in window" for wave/kills/bosses (single-run snapshots).
  // For embers + rebirths, accumulate via current totals since week start.
  if (metric === 'wave' || metric === 'kills' || metric === 'bosses') {
    if (runValue > w.progress) w.progress = runValue;
  } else if (metric === 'embers') {
    if (State.embers > w.progress) w.progress = State.embers;
  } else if (metric === 'rebirths') {
    w.progress = State.rebirths;
  }
  if (w.progress >= w.target) {
    w.claimed = true;
    grantEmbers(w.reward);
    persist();
    return true;
  }
  persist();
  return false;
}

export const CURSES = {
  bare_hands:   { label: 'Bare Hands',   desc: 'SKILL is disabled.' },
  glass_cannon: { label: 'Glass Cannon', desc: 'Hero HP halved.' },
  spendthrift:  { label: 'Spendthrift',  desc: 'No mid-run merchant.' },
  steady_pace:  { label: 'Pacifist',     desc: 'STRIKE is disabled.' },
};

export const State = Object.assign({}, DEFAULTS, Save.load());
// Re-merge to fill in any missing keys after a schema bump.
for (const k of Object.keys(DEFAULTS)) {
  if (State[k] === undefined) State[k] = DEFAULTS[k];
}

export function persist() { Save.save(State); }

export function exportSave() {
  return btoa(unescape(encodeURIComponent(JSON.stringify(State))));
}

export function importSave(s) {
  try {
    const obj = JSON.parse(decodeURIComponent(escape(atob(s.trim()))));
    if (typeof obj !== 'object') return false;
    for (const k of Object.keys(obj)) State[k] = obj[k];
    persist();
    return true;
  } catch (e) {
    return false;
  }
}

export function grantEmbers(amount) {
  if (!amount || amount <= 0) return;
  State.embers += amount;
  State.lifetime_embers = (State.lifetime_embers || 0) + amount;
}

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
  grantEmbers(bonus);
  // Roll the daily curse deterministically off the day number.
  const keys = Object.keys(CURSES);
  State.daily_curse = keys[day % keys.length];
  State.challenge_active = false;
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

export function nextKillMilestone() {
  for (const m of KILL_UNLOCKS) {
    if (State.meta_milestones[m.id]) continue;
    return m;
  }
  return null;
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
