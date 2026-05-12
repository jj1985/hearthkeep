// Per-run quest tracker. Three random quests roll each run; complete
// each for an in-run gold + ember bonus. Not persisted across runs.

import { State, grantEmbers } from './state.js';

const TEMPLATES = [
  { kind: 'kills',    target: 100, gold: 150, ember: 2, mk: (n) => `Get ${n} kills this run` },
  { kind: 'kills',    target: 250, gold: 400, ember: 4, mk: (n) => `Get ${n} kills this run` },
  { kind: 'wave',     target: 15,  gold: 200, ember: 3, mk: (n) => `Reach wave ${n}` },
  { kind: 'wave',     target: 25,  gold: 500, ember: 5, mk: (n) => `Reach wave ${n}` },
  { kind: 'bosses',   target: 2,   gold: 300, ember: 4, mk: (n) => `Fell ${n} bosses` },
  { kind: 'combo',    target: 20,  gold: 250, ember: 3, mk: (n) => `Reach a x${n} combo` },
  { kind: 'mythics',  target: 3,   gold: 200, ember: 3, mk: (n) => `Slay ${n} Mythic enemies` },
  { kind: 'chests',   target: 1,   gold: 100, ember: 2, mk: (n) => `Open ${n} treasure chest` },
];

export class Quests {
  constructor() {
    // pick 3 unique templates
    const pool = [...TEMPLATES].sort(() => Math.random() - 0.5).slice(0, 3);
    this.list = pool.map(t => ({
      kind: t.kind, target: t.target, gold: t.gold, ember: t.ember,
      label: t.mk(t.target), progress: 0, done: false,
    }));
  }

  // metric: kills | wave | bosses | combo | mythics | chests
  tick(metric, value) {
    const fired = [];
    for (const q of this.list) {
      if (q.done || q.kind !== metric) continue;
      // For wave/combo we track best snapshot; for kills/bosses/mythics/chests we increment.
      if (metric === 'wave' || metric === 'combo') {
        if (value > q.progress) q.progress = value;
      } else {
        q.progress += value;
      }
      if (q.progress >= q.target) {
        q.done = true;
        State.gold += q.gold;
        grantEmbers(q.ember);
        fired.push(q);
      }
    }
    return fired;
  }

  summary() {
    return this.list.map(q => {
      const mark = q.done ? '✓' : '○';
      return `${mark} ${q.label}  ${Math.min(q.target, q.progress)}/${q.target}  (+${q.gold}g +${q.ember}🜂)`;
    }).join('\n');
  }
}
