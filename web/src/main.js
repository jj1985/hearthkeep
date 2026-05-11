import { Game } from './game.js';
import { State, persist, processDailyLogin, rebirth, canRebirth } from './state.js';
import { rollPerks, applyPerk } from './perks.js';
import { UPGRADES, rank, cost, canBuy, buy } from './upgrades.js';
import * as Ach from './achievements.js';

const canvas = document.getElementById('game');
const hud = document.getElementById('hud');
const titleScreen = document.getElementById('title-screen');
const titleStats = document.getElementById('title-stats');
const titleTip = document.getElementById('title-tip');
const btnNewRun = document.getElementById('btn-newrun');
const btnShop = document.getElementById('btn-shop');

const wave = document.getElementById('wave');
const kills = document.getElementById('kills');
const gold = document.getElementById('gold');
const embers = document.getElementById('embers');
const level = document.getElementById('level');
const hpfill = document.getElementById('hpfill');
const log = document.getElementById('combatlog');
const overlay = document.getElementById('overlay');
const ovTitle = document.getElementById('overlay-title');
const ovBody = document.getElementById('overlay-body');
const ovChoices = document.getElementById('overlay-choices');

let game = null;

function clearChildren(el) { while (el.firstChild) el.removeChild(el.firstChild); }

function showOverlay(title, body, choices) {
  ovTitle.textContent = title;
  ovBody.textContent = body;
  clearChildren(ovChoices);
  for (const c of choices) {
    const b = document.createElement('button');
    b.textContent = c.label;
    if (c.cls) b.classList.add(c.cls);
    b.addEventListener('click', c.cb);
    ovChoices.appendChild(b);
  }
  overlay.hidden = false;
}
function hideOverlay() { overlay.hidden = true; }

// --- Title scene ---
const PASSIVE_DESC = {
  warrior:     'Rage on kill — stacks until wave clear',
  rogue:       '5% innate dodge, SKILL full heal',
  wizard:      'Every 5th hit chains, SKILL fireball',
  necromancer: 'Kills heal 1 HP, SKILL cleave',
  bard:        '+5% global damage, SKILL cleave',
};

const TIPS = [
  'STRIKE delivers a 4× burst hit on the closest enemy.',
  'SKILL is your class active — 6-second cooldown.',
  'Every 5th wave offers a 3-card perk pick.',
  'Boss every 10th wave drops Embers + screen shake.',
  'Mythic enemies (3% spawn) drop 10× gold.',
  'Treasure chests spawn every 15 waves (3-second open).',
  'Upgrade your hero between runs with gold.',
  'Add to home screen for app-icon access.',
];

function refreshTitle() {
  titleScreen.hidden = false;
  hud.hidden = true;
  canvas.hidden = true;
  clearChildren(titleStats);
  const lines = [];
  if (State.dragonslayer) lines.push(`⚔ Dragonslayer  ·  permanent +10% damage`);
  if (State.rebirths > 0) lines.push(`✦ Mark ${State.rebirths}  ·  +${State.rebirths * 25}% dmg + gold`);
  if (State.best_wave > 0) lines.push(`Best wave: ${State.best_wave}`);
  if (State.bosses_felled > 0) lines.push(`Bosses felled: ${State.bosses_felled}`);
  if (State.lifetime_kills > 0) lines.push(`Lifetime kills: ${State.lifetime_kills}`);
  lines.push(`Gold: ${State.gold}  ·  Embers: ${State.embers}  ·  Level: ${State.hero_level}`);
  if (State.login_streak > 0) lines.push(`Login streak: ${State.login_streak} day(s)`);
  lines.push(`Unlocked: ${State.unlocked_classes.join(', ')}`);
  for (const l of lines) {
    const p = document.createElement('p');
    p.textContent = l;
    titleStats.appendChild(p);
  }
  titleTip.textContent = TIPS[Math.floor(Math.random() * TIPS.length)];
  refreshRebirthButton();
  refreshJumpButtons();
}

function refreshRebirthButton() {
  const existing = document.getElementById('btn-rebirth');
  if (existing) existing.remove();
  if (!canRebirth()) return;
  const b = document.createElement('button');
  b.id = 'btn-rebirth';
  b.textContent = `REBIRTH — Mark ${State.rebirths + 1} (+25%)`;
  b.style.background = 'var(--secondary)';
  b.style.color = '#1a1208';
  b.addEventListener('click', () => {
    showOverlay('Rebirth?',
      'Wipes upgrades, gold, kills, unlocked classes, and milestones.\nKeeps Embers + hero level + a permanent +25% Mark.',
      [
        { label: 'Yes, ascend', cls: '', cb: () => { rebirth(); hideOverlay(); refreshTitle(); } },
        { label: 'Not yet', cls: 'secondary', cb: () => hideOverlay() },
      ]);
  });
  document.getElementById('title-actions').appendChild(b);
}

function startGame(klass, startWave = 1) {
  titleScreen.hidden = true;
  canvas.hidden = false;
  hud.hidden = false;
  game = new Game(canvas);
  game.primaryClass = klass;
  if (startWave > 1) {
    game.wave = startWave;
    game.waveKillsTarget = Math.floor(8 + startWave * 1.5);
  }
  game.onPerkRequest = showPerkPicker;
  game.onBossBoon = showBossBoon;
  game.onMerchant = showMerchant;
  game.onLevelPick = showLevelPerkPick;
  game.onSlotUnlock = showSlotPicker;
  game.onDeath = onDeath;
}

function showSlotPicker(slot) {
  const taken = new Set([game.primaryClass, game.secondaryClass, game.tertiaryClass]);
  const options = State.unlocked_classes.filter(c => !taken.has(c));
  if (options.length === 0) return;
  game.paused = true;
  const choices = options.map(c => ({
    label: `${c[0].toUpperCase()}${c.slice(1)}`,
    cls: '',
    cb: () => {
      if (slot === 'secondary') game.secondaryClass = c;
      else game.tertiaryClass = c;
      game.paused = false;
      hideOverlay();
      game.log(`${slot} = ${c}`);
    },
  }));
  choices.push({ label: 'Skip', cls: 'secondary', cb: () => { game.paused = false; hideOverlay(); } });
  const s = slot === 'secondary' ? 'secondary' : 'tertiary';
  showOverlay(`Choose your ${s} class`, 'A new slot opened. Synergies fire when class pairs/trios match.', choices);
}

const LEVEL_PERKS = [
  { id: 'perm_dmg',   label: 'Sharpened',   desc: '+1 damage permanently.' },
  { id: 'perm_hp',    label: 'Iron Body',   desc: '+5 max HP permanently.' },
  { id: 'perm_atk',   label: 'Quickened',   desc: '+0.1 atk/sec permanently.' },
  { id: 'perm_gold',  label: 'Coinhand',    desc: '+5% gold drops permanently.' },
  { id: 'perm_range', label: 'Longarm',     desc: '+10 range permanently.' },
  { id: 'perm_crit',  label: 'Keen Eye',    desc: '+2% crit chance permanently.' },
];

function showLevelPerkPick(level) {
  const pool = [...LEVEL_PERKS].sort(() => Math.random() - 0.5).slice(0, 3);
  game.paused = true;
  const choices = pool.map(p => ({
    label: `${p.label} — ${p.desc}`,
    cls: '',
    cb: () => {
      State.level_perks[p.id] = (State.level_perks[p.id] || 0) + 1;
      persist();
      game.paused = false;
      hideOverlay();
      game.log(`Perm: ${p.label}`);
    },
  }));
  showOverlay(`Level ${level} — pick a permanent boost`, 'Carries across all future runs and rebirths.', choices);
}

const MERCHANT_OFFERS = [
  { id: 'heal',  label: 'Healing Tonic', desc: 'Restore HP to full.',     cost: 40,
    apply: g => { g.heroHp = g.heroMaxHp; } },
  { id: 'oil',   label: 'Whetstone Oil', desc: '+50% damage, 3 waves.',   cost: 60,
    apply: g => { g.dmgMult *= 1.5; setTimeout(() => g.dmgMult /= 1.5, 60_000); } },
  { id: 'drum',  label: 'Battle Drum',   desc: '+1.0 atk/sec, 3 waves.',  cost: 80,
    apply: g => { g.atkBonus += 1.0; setTimeout(() => { g.atkBonus = Math.max(0, g.atkBonus - 1.0); }, 60_000); } },
  { id: 'trade', label: 'Ember Bargain', desc: 'Trade 30g for 1 Ember.',  cost: 30,
    apply: () => { State.embers += 1; persist(); } },
];

function showMerchant() {
  game.paused = true;
  const choices = MERCHANT_OFFERS.map(o => ({
    label: `${o.label} (${o.cost}g) — ${o.desc}`,
    cls: State.gold >= o.cost ? '' : 'secondary',
    cb: () => {
      if (State.gold < o.cost) return;
      State.gold -= o.cost;
      o.apply(game);
      game.log(`Bought: ${o.label}`);
      game.paused = false;
      hideOverlay();
    },
  }));
  choices.push({ label: 'Skip', cls: 'secondary', cb: () => { game.paused = false; hideOverlay(); } });
  showOverlay('Wandering Merchant', `You have ${State.gold} gold.`, choices);
}

const BOSS_BOONS = [
  { id: 'berserk',   label: 'Berserk',   desc: '+40% damage this run.',         apply: g => g.dmgMult *= 1.4 },
  { id: 'sanctuary', label: 'Sanctuary', desc: '+50% max HP this run + full.',  apply: g => { g.heroMaxHp = Math.round(g.heroMaxHp * 1.5); g.heroHp = g.heroMaxHp; } },
  { id: 'hoard',     label: 'Hoard',     desc: '+50% gold drops this run.',     apply: g => g.goldMult *= 1.5 },
  { id: 'storm',     label: 'Storm',     desc: '+0.5 atk/sec this run.',        apply: g => g.atkBonus += 0.5 },
];

function showBossBoon() {
  const pool = [...BOSS_BOONS].sort(() => Math.random() - 0.5).slice(0, 2);
  game.paused = true;
  const choices = pool.map(b => ({
    label: `${b.label} — ${b.desc}`,
    cls: '',
    cb: () => { b.apply(game); game.paused = false; hideOverlay(); game.log(`Boon: ${b.label}`); },
  }));
  showOverlay('Boss boon — pick one', 'A reward for felling the boss. Active this run only.', choices);
}

function onDeath(info) {
  // Scan achievements and apply any newly-completed ember rewards.
  const achPay = Ach.scanAndClaim();
  const body = [
    `Kills: ${info.kills}`,
    `Gold spilled: -${info.gold_lost}`,
    `Peak combo: x${info.combo}`,
    `Embers earned: +${info.embers + achPay}`,
    achPay > 0 ? `(includes +${achPay} achievement embers)` : '',
  ].filter(s => s).join('\n');
  showOverlay(`FALLEN ON WAVE ${info.wave}`, body, [
    { label: 'Upgrades Shop', cls: '', cb: () => showUpgradeShop(true) },
    { label: 'Back to Title', cls: 'secondary', cb: () => { hideOverlay(); refreshTitle(); } },
  ]);
}

function showAchievements() {
  const choices = Ach.ROWS.map(r => {
    const [cur, tgt] = r.progress();
    const done = Ach.isDone(r);
    const claimed = Ach.isClaimed(r);
    const mark = claimed ? '✓' : (done ? '◆' : '○');
    return {
      label: `${mark} ${r.label}  ·  ${cur}/${tgt}  +${r.reward}🜂`,
      cls: claimed ? 'secondary' : '',
      cb: () => {},
    };
  });
  choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('ACHIEVEMENTS', `Claim by reaching the target.`, choices);
}

function showBestiary() {
  const seen = State.bestiary || {};
  const choices = [];
  // Show all enemies in order they unlock, mask name if not seen.
  const order = [
    'skeleton', 'goblin', 'brute', 'ghoul', 'drake', 'wraith', 'ogre',
    'sapper', 'archer', 'shaman', 'boss_warchief', 'boss_vyxhasis',
  ];
  for (const id of order) {
    const e = seen[id];
    const lbl = e ? `${id} — ${e.kills} kills` : '? ? ? ? ?';
    choices.push({ label: lbl, cls: e ? '' : 'secondary', cb: () => {} });
  }
  choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('BESTIARY', 'Discovered enemies and lifetime kill counts.', choices);
}

const statusrow = document.getElementById('statusrow');
function refreshHud() {
  if (!game || canvas.hidden) return;
  const c = game.combo;
  wave.textContent = c > 1
    ? `WAVE ${game.wave}  ·  x${c} (${game.comboMult().toFixed(2)}×)`
    : `WAVE ${game.wave}`;
  kills.textContent = `${State.lifetime_kills} kills`;
  gold.textContent = `${State.gold} g`;
  embers.textContent = `${State.embers} 🜂`;
  level.textContent = `L${State.hero_level}`;
  hpfill.style.width = (100 * game.heroHp / game.heroMaxHp).toFixed(1) + '%';
  log.textContent = game.combatLog.join('\n');
  refreshStatusRow();
}

function refreshStatusRow() {
  clearChildren(statusrow);
  const add = (text, cls = '') => {
    const c = document.createElement('span');
    c.className = 'chip' + (cls ? ' ' + cls : '');
    c.textContent = text;
    statusrow.appendChild(c);
  };
  if (game.dmgMult > 1.001) add(`Dmg ${game.dmgMult.toFixed(2)}×`);
  if (game.goldMult > 1.001) add(`Gold ${game.goldMult.toFixed(2)}×`);
  if (game.atkBonus > 0.05) add(`Spd +${game.atkBonus.toFixed(1)}`);
  if (game.waveBonusMult > 1.001) add(`Wave ${game.waveBonusMult.toFixed(2)}×`);
  if (game.critBonus > 0.001) add(`Crit +${Math.round(game.critBonus * 100)}%`);
  if (game.contactReduction > 0.001) add(`Aegis ${Math.round(game.contactReduction * 100)}%`, 'def');
  if (game.primaryClass === 'warrior' && game.warriorRage > 0) add(`Rage x${game.warriorRage}`, 'temp');
  if (game.skillCd > 0) add(`Skill ${game.skillCd.toFixed(1)}s`, 'def');
  if (game.frenzy > 0) {
    add(game.frenzy >= game.FRENZY_CAP ? `Frenzy READY` : `Frenzy ${game.frenzy}/${game.FRENZY_CAP}`, 'temp');
  }
  const syn = game.synergy && game.synergy();
  if (syn) add(`✦ ${syn.label}`);
}
setInterval(refreshHud, 100);

function showClassPicker(after) {
  if (State.unlocked_classes.length === 1) {
    after(State.unlocked_classes[0]);
    return;
  }
  const choices = State.unlocked_classes.map(cid => ({
    label: `${cid[0].toUpperCase()}${cid.slice(1)} — ${PASSIVE_DESC[cid] || ''}`,
    cls: '',
    cb: () => { hideOverlay(); after(cid); },
  }));
  choices.push({ label: 'Cancel', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('Choose primary class', 'Each class shapes the SKILL and passive.', choices);
}

function showPerkPicker() {
  if (!game) return;
  const taken = game.takenPerks;
  const picks = rollPerks(game.primaryClass, taken, 3);
  if (picks.length === 0) return;
  game.paused = true;
  const choices = picks.map(p => ({
    label: `${p.label} — ${p.desc}`,
    cls: '',
    cb: () => {
      applyPerk(game, p);
      game.paused = false;
      hideOverlay();
      game.log(`Perk: ${p.label}`);
    },
  }));
  showOverlay(`Wave ${game.wave} — pick a perk`, 'Choose a power to carry into the next push.', choices);
}

function showUpgradeShop(reloadOnBack) {
  function rebuild() {
    const choices = UPGRADES.map(u => {
      const c = cost(u.id);
      const r = rank(u.id);
      const buyable = canBuy(u.id);
      const text = c < 0
        ? `${u.label} (MAXED)`
        : `${u.label} — ${u.desc}  ·  Rank ${r}/30  ·  ${c}g`;
      return {
        label: text,
        cls: buyable ? '' : 'secondary',
        cb: () => { if (buy(u.id)) rebuild(); },
      };
    });
    choices.push({
      label: reloadOnBack ? 'Back to Title' : 'Resume',
      cls: 'secondary',
      cb: () => {
        if (reloadOnBack) {
          hideOverlay();
          refreshTitle();
        } else hideOverlay();
      },
    });
    showOverlay('UPGRADES', `Spend gold. Survives death.\n${State.gold} gold`, choices);
  }
  rebuild();
}

document.getElementById('btn-strike').addEventListener('click', () => game && game.strike());
document.getElementById('btn-skill').addEventListener('click', () => game && game.skill());
document.getElementById('btn-pause').addEventListener('click', () => {
  if (!game) return;
  game.paused = !game.paused;
  if (game.paused) {
    showOverlay('Paused', '', [
      { label: 'Resume', cls: '', cb: () => { game.paused = false; hideOverlay(); } },
      { label: 'Upgrades', cls: 'secondary', cb: () => showUpgradeShop(false) },
      { label: 'Quit to Title', cls: 'secondary', cb: () => { hideOverlay(); refreshTitle(); } },
    ]);
  } else hideOverlay();
});

btnNewRun.addEventListener('click', () => {
  showClassPicker(startGame);
});
btnShop.addEventListener('click', () => showUpgradeShop(true));

// Expose Achievements + Bestiary as title-screen extras.
function ensureExtraTitleButtons() {
  const wrap = document.getElementById('title-actions');
  const addBtn = (id, label, cb, primary = false) => {
    if (document.getElementById(id)) return;
    const b = document.createElement('button');
    b.id = id;
    b.textContent = label;
    if (!primary) {
      b.style.background = 'var(--surface-bright)';
      b.style.color = 'var(--on-surface)';
    }
    b.addEventListener('click', cb);
    wrap.appendChild(b);
  };
  addBtn('btn-ach',      'ACHIEVEMENTS', showAchievements);
  addBtn('btn-bestiary', 'BESTIARY',     showBestiary);
}
ensureExtraTitleButtons();

function refreshJumpButtons() {
  for (const tier of [10, 25, 50]) {
    const id = `btn-jump-${tier}`;
    const existing = document.getElementById(id);
    if (existing) existing.remove();
    if (State.best_wave < tier) continue;
    const b = document.createElement('button');
    b.id = id;
    b.textContent = `JUMP TO WAVE ${tier}`;
    b.style.background = 'var(--surface-bright)';
    b.style.color = 'var(--on-surface)';
    b.addEventListener('click', () => {
      showClassPicker(cls => startGame(cls, tier));
    });
    document.getElementById('title-actions').appendChild(b);
  }
}

// Daily-login: fire once per page-load if the day rolled over.
const daily = processDailyLogin();
if (daily) {
  showOverlay(
    `Day ${daily.streak} streak`,
    daily.broke
      ? `+${daily.bonus} Embers for today's login.`
      : `+${daily.bonus} Embers — keep the streak alive.`,
    [{ label: 'Continue', cls: '', cb: () => { hideOverlay(); refreshTitle(); } }],
  );
}


window.addEventListener('beforeunload', () => persist());
refreshTitle();
