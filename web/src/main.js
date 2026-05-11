import { Game } from './game.js';
import { State, persist } from './state.js';
import { rollPerks, applyPerk } from './perks.js';

const canvas = document.getElementById('game');
const game = new Game(canvas);

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

function refreshHud() {
  wave.textContent = `WAVE ${game.wave}`;
  kills.textContent = `${State.lifetime_kills} kills`;
  gold.textContent = `${State.gold} g`;
  embers.textContent = `${State.embers} 🜂`;
  level.textContent = `L${State.hero_level}`;
  hpfill.style.width = (100 * game.heroHp / game.heroMaxHp).toFixed(1) + '%';
  log.textContent = game.combatLog.join('\n');
}
setInterval(refreshHud, 100);

function clearChildren(el) {
  while (el.firstChild) el.removeChild(el.firstChild);
}
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

// --- Class picker (when ≥2 unlocked) ---
const PASSIVE_DESC = {
  warrior:     'Hot Steel start — heavy melee',
  rogue:       'Quick — heals on SKILL',
  wizard:      'Long range — fireball SKILL',
  necromancer: 'Death tag — slow start, scales',
  bard:        '+5% global damage',
};

function showClassPicker(after) {
  const choices = State.unlocked_classes.map(cid => ({
    label: `${cid[0].toUpperCase()}${cid.slice(1)} — ${PASSIVE_DESC[cid] || ''}`,
    cls: '',
    cb: () => { game.primaryClass = cid; hideOverlay(); after(); },
  }));
  showOverlay('Choose primary class', 'Each class shapes the SKILL and stat scaling.', choices);
}

// --- Perk picker every 5 waves ---
function showPerkPicker() {
  const taken = game.takenPerks;
  const picks = rollPerks(game.primaryClass, taken, 3);
  if (picks.length === 0) return;
  game.paused = true;
  const choices = picks.map(p => ({
    label: `${p.label} — ${p.desc}`,
    cls: '',
    cb: () => { applyPerk(game, p); game.paused = false; hideOverlay(); game.log(`Perk: ${p.label}`); },
  }));
  showOverlay(`Wave ${game.wave} — pick a perk`, 'Choose a power to carry into the next push.', choices);
}
game.onPerkRequest = showPerkPicker;

// --- Buttons ---
document.getElementById('btn-strike').addEventListener('click', () => game.strike());
document.getElementById('btn-skill').addEventListener('click', () => game.skill());
document.getElementById('btn-pause').addEventListener('click', () => {
  game.paused = !game.paused;
  if (game.paused) {
    showOverlay('Paused', '', [
      { label: 'Resume', cls: '', cb: () => { game.paused = false; hideOverlay(); } },
      { label: 'Restart Run', cls: 'secondary', cb: () => location.reload() },
    ]);
  } else hideOverlay();
});

game.onDeath = (info) => {
  const body = [
    `Kills: ${info.kills}`,
    `Gold spilled: -${info.gold_lost}`,
    `Peak combo: x${info.combo}`,
    `Embers earned: +${info.embers}`,
  ].join('\n');
  showOverlay(`FALLEN ON WAVE ${info.wave}`, body, [
    { label: 'Try Again', cls: '', cb: () => location.reload() },
  ]);
};

// First-run flow: show class picker if ≥2 unlocked, else tutorial.
function bootFlow() {
  if (State.unlocked_classes.length >= 2) {
    showClassPicker(() => {
      if (!localStorage.getItem('hearthkeep.tutorial')) showTutorial();
    });
  } else if (!localStorage.getItem('hearthkeep.tutorial')) {
    showTutorial();
  }
}
function showTutorial() {
  showOverlay('HEARTHKEEP',
    'Tap STRIKE for a heavy hit.\nSKILL is your class active (6s cd).\nBoss every 10 waves.\nPerk pick every 5 waves.\n\nYou auto-attack — survive.',
    [{ label: 'Begin', cls: '', cb: () => { localStorage.setItem('hearthkeep.tutorial', '1'); hideOverlay(); } }]);
}
bootFlow();

window.addEventListener('beforeunload', () => persist());
