import { State, persist, grantEmbers } from './state.js';

export const ROWS = [
  { id: 'unlock_rogue',  label: 'Unlock Rogue (100 kills)',        reward: 2,
    progress: () => [Math.min(100, State.lifetime_kills), 100] },
  { id: 'unlock_wizard', label: 'Unlock Wizard (500 kills)',       reward: 3,
    progress: () => [Math.min(500, State.lifetime_kills), 500] },
  { id: 'unlock_necro',  label: 'Unlock Necromancer (1500 kills)', reward: 4,
    progress: () => [Math.min(1500, State.lifetime_kills), 1500] },
  { id: 'unlock_bard',   label: 'Unlock Bard (5000 kills)',        reward: 6,
    progress: () => [Math.min(5000, State.lifetime_kills), 5000] },
  { id: 'wave_10',       label: 'Reach wave 10',                   reward: 2,
    progress: () => [Math.min(10, State.best_wave), 10] },
  { id: 'wave_25',       label: 'Reach wave 25',                   reward: 4,
    progress: () => [Math.min(25, State.best_wave), 25] },
  { id: 'wave_50',       label: 'Reach wave 50',                   reward: 10,
    progress: () => [Math.min(50, State.best_wave), 50] },
  { id: 'first_boss',    label: 'Fell your first boss',            reward: 2,
    progress: () => [Math.min(1, State.bosses_felled), 1] },
  { id: 'five_bosses',   label: 'Fell 5 bosses',                   reward: 5,
    progress: () => [Math.min(5, State.bosses_felled), 5] },
  { id: 'first_rebirth', label: 'First Mark of Rebirth',           reward: 8,
    progress: () => [Math.min(1, State.rebirths), 1] },
  { id: 'streak_7',      label: '7-day login streak',              reward: 7,
    progress: () => [Math.min(7, State.login_streak), 7] },
  { id: 'level_25',      label: 'Hero level 25',                   reward: 6,
    progress: () => [Math.min(25, State.hero_level), 25] },
];

function claimed() {
  if (!State.ach_claimed) State.ach_claimed = {};
  return State.ach_claimed;
}

export function isDone(row) {
  const [a, b] = row.progress();
  return a >= b;
}

export function isClaimed(row) { return !!claimed()[row.id]; }

export function scanAndClaim() {
  let total = 0;
  const c = claimed();
  for (const r of ROWS) {
    if (c[r.id]) continue;
    if (isDone(r)) {
      c[r.id] = true;
      total += r.reward;
    }
  }
  if (total > 0) {
    grantEmbers(total);
    persist();
  }
  return total;
}
