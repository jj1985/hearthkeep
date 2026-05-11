import { Game } from './game.js';
import { State, persist } from './state.js';

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

if (!localStorage.getItem('hearthkeep.tutorial')) {
  showOverlay('HEARTHKEEP',
    'Tap STRIKE for a heavy hit.\nSKILL is your class active (6s cd).\nClear waves to unlock more.\n\nYou auto-attack — survive.',
    [{ label: 'Begin', cls: '', cb: () => { localStorage.setItem('hearthkeep.tutorial', '1'); hideOverlay(); } }]);
}

window.addEventListener('beforeunload', () => persist());
