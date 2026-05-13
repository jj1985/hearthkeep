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
  speedrun_best_ms: 0,   // best time to reach wave 20 (0 = unset)
  skill_ranks: {},       // class -> rank (0..3)
  hardcore_best_wave: 0,
  seen_boss_hints: {},   // boss_id -> true once first hint shown
  skins: {},             // class -> [{id}] owned skins
  active_skin: {},       // class -> skin id (default falls back to base color)
  daily_seed_runs: {},   // 'yyyy-mm-dd' -> best wave for that seed
};

// Tiny seeded RNG — Mulberry32. Returns a function() -> float in [0,1).
export function mulberry32(seed) {
  let t = seed >>> 0;
  return function () {
    t = (t + 0x6D2B79F5) >>> 0;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

export function todaySeedKey() {
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function todaySeedInt() {
  // Hash the date key into a 32-bit integer.
  const s = todaySeedKey();
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function recordDailyRun(wave) {
  const k = todaySeedKey();
  if (!State.daily_seed_runs) State.daily_seed_runs = {};
  const prev = State.daily_seed_runs[k] || 0;
  if (wave > prev) {
    State.daily_seed_runs[k] = wave;
    persist();
    return true;
  }
  return false;
}

export const SKINS = [
  { id: 'warrior_crimson', klass: 'warrior',     color: '#c03828', label: 'Crimson Plate',  cost: 12 },
  { id: 'warrior_ivory',   klass: 'warrior',     color: '#e8e0c0', label: 'Ivory Plate',    cost: 18 },
  { id: 'rogue_shadow',    klass: 'rogue',       color: '#506060', label: 'Shadow Cowl',    cost: 12 },
  { id: 'rogue_emerald',   klass: 'rogue',       color: '#2eb878', label: 'Emerald Garb',   cost: 18 },
  { id: 'wizard_violet',   klass: 'wizard',      color: '#9966c8', label: 'Violet Sage',    cost: 12 },
  { id: 'wizard_frost',    klass: 'wizard',      color: '#80c8e0', label: 'Frost Mage',     cost: 18 },
  { id: 'necro_bone',      klass: 'necromancer', color: '#e0d8c0', label: 'Bonewright',     cost: 12 },
  { id: 'necro_blood',     klass: 'necromancer', color: '#a02838', label: 'Blood Adept',    cost: 18 },
  { id: 'bard_gold',       klass: 'bard',        color: '#e8b85e', label: 'Gilded Singer',  cost: 12 },
  { id: 'bard_indigo',     klass: 'bard',        color: '#5566c8', label: 'Indigo Minstrel', cost: 18 },
];

export function ownsSkin(id) {
  return !!(State.skins && State.skins[id]);
}
export function activeSkinFor(klass) {
  return (State.active_skin || {})[klass] || '';
}
export function buySkin(id) {
  const s = SKINS.find(x => x.id === id);
  if (!s) return false;
  if (ownsSkin(id)) return false;
  if (State.embers < s.cost) return false;
  State.embers -= s.cost;
  if (!State.skins) State.skins = {};
  State.skins[id] = true;
  persist();
  return true;
}
export function equipSkin(klass, id) {
  if (!State.active_skin) State.active_skin = {};
  if (id && !ownsSkin(id)) return false;
  State.active_skin[klass] = id || '';
  persist();
  return true;
}
export function colorForClass(klass, baseColor) {
  const id = activeSkinFor(klass);
  if (!id) return baseColor;
  const s = SKINS.find(x => x.id === id);
  return s ? s.color : baseColor;
}

export const SKILL_RANK_COSTS = [5, 12, 25]; // embers to go 0→1→2→3
export function skillRank(klass) { return (State.skill_ranks || {})[klass] || 0; }
export function skillNextCost(klass) {
  const r = skillRank(klass);
  return r >= SKILL_RANK_COSTS.length ? -1 : SKILL_RANK_COSTS[r];
}
export function skillBuy(klass) {
  const r = skillRank(klass);
  if (r >= SKILL_RANK_COSTS.length) return false;
  const c = SKILL_RANK_COSTS[r];
  if (State.embers < c) return false;
  State.embers -= c;
  if (!State.skill_ranks) State.skill_ranks = {};
  State.skill_ranks[klass] = r + 1;
  persist();
  return true;
}

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

// Glory tiers — earned by lifetime embers. Each tier confers a permanent
// stat bonus that game.js folds in via gloryTier helpers below.
export const GLORY_TIERS = [
  { id: 'novice',  title: 'Novice',   threshold: 50,   desc: '+5% damage' },
  { id: 'rising',  title: 'Rising',   threshold: 200,  desc: '+5% gold drops' },
  { id: 'ascendant', title: 'Ascendant', threshold: 500, desc: '+10% max HP' },
  { id: 'mythic',  title: 'Mythic',   threshold: 1500, desc: '+0.2 atk/sec' },
];

export function gloryTier() {
  const g = State.lifetime_embers || 0;
  let tier = null;
  for (const t of GLORY_TIERS) {
    if (g >= t.threshold) tier = t;
  }
  return tier;
}

export function hasGlory(id) {
  const g = State.lifetime_embers || 0;
  const t = GLORY_TIERS.find(x => x.id === id);
  return t ? g >= t.threshold : false;
}

export function nextGlory() {
  const g = State.lifetime_embers || 0;
  for (const t of GLORY_TIERS) if (g < t.threshold) return t;
  return null;
}

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
