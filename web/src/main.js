import { Game } from './game.js';
import { State, persist } from './state.js';
import { rollPerks, applyPerk } from './perks.js';
import { UPGRADES, rank, cost, canBuy, buy } from './upgrades.js';

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
  if (State.best_wave > 0) lines.push(`Best wave: ${State.best_wave}`);
  if (State.bosses_felled > 0) lines.push(`Bosses felled: ${State.bosses_felled}`);
  if (State.lifetime_kills > 0) lines.push(`Lifetime kills: ${State.lifetime_kills}`);
  lines.push(`Gold: ${State.gold}  ·  Embers: ${State.embers}  ·  Level: ${State.hero_level}`);
  lines.push(`Unlocked: ${State.unlocked_classes.join(', ')}`);
  for (const l of lines) {
    const p = document.createElement('p');
    p.textContent = l;
    titleStats.appendChild(p);
  }
  titleTip.textContent = TIPS[Math.floor(Math.random() * TIPS.length)];
}

function startGame(klass) {
  titleScreen.hidden = true;
  canvas.hidden = false;
  hud.hidden = false;
  game = new Game(canvas);
  game.primaryClass = klass;
  game.onPerkRequest = showPerkPicker;
  game.onDeath = onDeath;
}

function onDeath(info) {
  const body = [
    `Kills: ${info.kills}`,
    `Gold spilled: -${info.gold_lost}`,
    `Peak combo: x${info.combo}`,
    `Embers earned: +${info.embers}`,
  ].join('\n');
  showOverlay(`FALLEN ON WAVE ${info.wave}`, body, [
    { label: 'Upgrades Shop', cls: '', cb: () => showUpgradeShop(true) },
    { label: 'Back to Title', cls: 'secondary', cb: () => { hideOverlay(); refreshTitle(); } },
  ]);
}

function refreshHud() {
  if (!game || canvas.hidden) return;
  wave.textContent = `WAVE ${game.wave}`;
  kills.textContent = `${State.lifetime_kills} kills`;
  gold.textContent = `${State.gold} g`;
  embers.textContent = `${State.embers} 🜂`;
  level.textContent = `L${State.hero_level}`;
  hpfill.style.width = (100 * game.heroHp / game.heroMaxHp).toFixed(1) + '%';
  log.textContent = game.combatLog.join('\n');
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

window.addEventListener('beforeunload', () => persist());
refreshTitle();
