import { Game, zoneForWave } from './game.js';
import { State, persist, processDailyLogin, rebirth, canRebirth, grantEmbers, processWeekly, exportSave, importSave, nextKillMilestone, gloryTier, nextGlory, GLORY_TIERS, skillRank, skillNextCost, skillBuy, SKINS, ownsSkin, activeSkinFor, buySkin, equipSkin, todaySeedKey } from './state.js';
import { rollPerks, applyPerk } from './perks.js';
import { UPGRADES, rank, cost, canBuy, buy, currencyOf } from './upgrades.js';
import * as Ach from './achievements.js';
import { TRINKETS, equipped, equip } from './trinkets.js';
import { CURSES } from './state.js';
import { setMuted, isMuted } from './sfx.js';
import { Save } from './save.js';
import { setMusicMuted, Music } from './music.js';

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
const timer = document.getElementById('timer');
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
  warrior:     'Rage on kill; +15% dmg, +20% HP, slow swing',
  rogue:       'Innate dodge; +20% atk speed, frail',
  wizard:      'Chain hits; +25% dmg, +20% range, fragile',
  necromancer: 'Kills heal; balanced stats',
  bard:        '+5% global dmg; +10% atk + HP + range',
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
  'Tempest waves (every 13th) double spawns at half HP.',
  'Trinkets drop from bosses — equip one at a time.',
  'Felling all 3 dragons grants permanent Dragonslayer +10%.',
  'Wizard fireballs are single-target nukes; Bard anthems boost speed.',
  'Daily curse opt-in doubles all rewards.',
  'Save export lets you back up your progress across devices.',
  'Wave 50+ unlocks Rebirth — permanent +25% per Mark.',
  'Ember Edge stacks +10% damage forever, per rank.',
];

function tipOfDay() {
  const day = Math.floor(Date.now() / 86400000);
  return TIPS[day % TIPS.length];
}

function refreshTitle() {
  titleScreen.hidden = false;
  hud.hidden = true;
  canvas.hidden = true;
  // Dynamic subtitle by progression milestone.
  const subEl = document.getElementById('title-subtitle');
  if (subEl) {
    let sub = 'of the Sundered Realms';
    if (State.best_wave >= 150) sub = 'walker beyond the Plateau';
    else if (State.best_wave >= 100) sub = 'no longer mortal in any old sense';
    else if (State.best_wave >= 75) sub = 'voidsworn';
    else if (State.dragonslayer) sub = 'Dragonslayer of the Sundered Realms';
    else if (State.best_wave >= 50) sub = 'ember-bearer';
    else if (State.best_wave >= 30) sub = 'of the Sundered Realms';
    subEl.textContent = sub;
  }
  clearChildren(titleStats);
  const lines = [];
  if (State.daily_curse && CURSES[State.daily_curse]) {
    const c = CURSES[State.daily_curse];
    const tag = State.challenge_active ? '✦ ACTIVE  ·  ' : '';
    lines.push(`${tag}Daily curse: ${c.label} — ${c.desc} (toggle for 2× rewards)`);
  }
  if (State.dragonslayer) lines.push(`⚔ Dragonslayer  ·  permanent +10% damage`);
  if (State.curses_cleared > 0) lines.push(`Curses cleared: ${State.curses_cleared}`);
  if ((State.speedrun_best_ms || 0) > 0) lines.push(`Speedrun → W20 best: ${(State.speedrun_best_ms / 1000).toFixed(2)}s`);
  if ((State.hardcore_best_wave || 0) > 0) lines.push(`Hardcore best wave: ${State.hardcore_best_wave}`);
  const today = State.daily_seed_runs?.[todaySeedKey()] || 0;
  if (today > 0) lines.push(`Today's seed (${todaySeedKey()}) best: W${today}`);
  // Next-class milestone progress
  const nm = nextKillMilestone();
  if (nm) {
    const pct = Math.min(100, Math.round(State.lifetime_kills / nm.kills * 100));
    lines.push(`Next class: ${nm.klass} — ${State.lifetime_kills}/${nm.kills} (${pct}%)`);
  } else {
    lines.push('All classes unlocked.');
  }
  // Weekly mission line
  const w = processWeekly();
  if (w) {
    const mark = w.claimed ? '✓' : '○';
    lines.push(`${mark} Weekly: ${w.label}  (${w.progress}/${w.target}, +${w.reward}🜂)`);
  }
  if (State.rebirths > 0) lines.push(`✦ Mark ${State.rebirths}  ·  +${State.rebirths * 25}% dmg + gold`);
  if (State.best_wave > 0) lines.push(`Best wave: ${State.best_wave}`);
  if (State.bosses_felled > 0) lines.push(`Bosses felled: ${State.bosses_felled}`);
  if (State.lifetime_kills > 0) lines.push(`Lifetime kills: ${State.lifetime_kills}`);
  if ((State.lifetime_embers || 0) > 0) {
    const tier = gloryTier();
    const next = nextGlory();
    let line = `Glory: ${State.lifetime_embers} 🜂`;
    if (tier) line += ` · ${tier.title} (${tier.desc})`;
    if (next) line += ` · next: ${next.title} at ${next.threshold}`;
    lines.push(line);
  }
  lines.push(`Gold: ${State.gold}  ·  Embers: ${State.embers}  ·  Level: ${State.hero_level}`);
  if (State.login_streak > 0) lines.push(`Login streak: ${State.login_streak} day(s)`);
  lines.push(`Unlocked: ${State.unlocked_classes.join(', ')}`);
  for (const l of lines) {
    const p = document.createElement('p');
    p.textContent = l;
    titleStats.appendChild(p);
  }
  titleTip.textContent = '💡 ' + tipOfDay();
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

function startGame(klass, startWave = 1, opts = {}) {
  titleScreen.hidden = true;
  canvas.hidden = false;
  hud.hidden = false;
  game = new Game(canvas);
  game.primaryClass = klass;
  if (startWave > 1) {
    game.wave = startWave;
    game.waveKillsTarget = Math.floor(8 + startWave * 1.5);
  }
  if (opts.speedrun) game.speedrun = true;
  if (opts.hardcore) game.setHardcore(true);
  if (opts.dailySeed) game.setDailySeed(true);
  game.onPerkRequest = showPerkPicker;
  game.onBossBoon = showBossBoon;
  game.onMerchant = showMerchant;
  game.onLevelPick = showLevelPerkPick;
  game.onSlotUnlock = showSlotPicker;
  game.onDeath = onDeath;
  game.onSpeedrunFinish = onSpeedrunFinish;
}

function onSpeedrunFinish(ms) {
  const s = (ms / 1000).toFixed(2);
  const best = State.speedrun_best_ms ? (State.speedrun_best_ms / 1000).toFixed(2) : s;
  showOverlay('SPEEDRUN — wave 20 cleared', `Time: ${s}s\nBest: ${best}s`, [
    { label: 'Back to Title', cls: '', cb: () => { hideOverlay(); refreshTitle(); } },
  ]);
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
    apply: () => { grantEmbers(1); persist(); } },
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
  const mm = Math.floor(info.duration_s / 60);
  const ss = info.duration_s % 60;
  // Top-3 killed enemy types.
  const top = Object.entries(info.kills_by_type || {})
    .sort((a, b) => b[1] - a[1]).slice(0, 3)
    .map(([k, v]) => `${k.replace('boss_', '')} x${v}`).join(', ');
  const loadout = [info.primary, info.secondary, info.tertiary].filter(Boolean)
    .map(c => c[0].toUpperCase() + c.slice(1)).join(' / ');
  const best = info.pre_best || 0;
  const cmp = best === 0
    ? `first run on this slot`
    : (info.wave > best ? `★ NEW BEST! (was ${best})`
      : (info.wave === best ? `tied best (${best})` : `your best is wave ${best}`));
  const body = [
    `Loadout: ${loadout}`,
    cmp,
    `Run length: ${mm}:${ss.toString().padStart(2, '0')}`,
    `Kills: ${info.kills}  ·  Peak DPS: ${info.peak_dps}`,
    top ? `Top kills: ${top}` : '',
    `Peak combo: x${info.combo}`,
    `Embers earned: +${info.embers + achPay}` + (achPay > 0 ? ` (incl. +${achPay} achievement)` : ''),
    `Gold spilled: -${info.gold_lost}`,
  ].filter(Boolean).join('\n');

  const lastLoadout = { p: info.primary, s: info.secondary, t: info.tertiary };
  showOverlay(`FALLEN ON WAVE ${info.wave}`, body, [
    {
      label: 'Rerun same loadout',
      cls: '',
      cb: () => {
        hideOverlay();
        startGame(lastLoadout.p, 1);
        // Apply remembered secondary/tertiary classes after init.
        setTimeout(() => {
          if (game) {
            game.secondaryClass = lastLoadout.s || '';
            game.tertiaryClass = lastLoadout.t || '';
          }
        }, 50);
      },
    },
    { label: 'Upgrades Shop', cls: 'secondary', cb: () => showUpgradeShop(true) },
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

const BESTIARY_LORE = {
  skeleton:      'Rattling bones held together by old necromancy.',
  rat:           'Plague-fat vermin. Fast, fragile, swarms in sewers.',
  goblin:        'Forest scrappers. Cunning enough to mob, dumb enough to charge.',
  goblin_a:      'Goblin Archer — kites at range, lobs crude bone-tipped arrows.',
  brute:         'Slab-shouldered tribal champion. Slow but ruinous on impact.',
  ghoul:         'Hungering corpse. Faster the longer it has gone unfed.',
  drake:         'Juvenile cousin of dragons. Wing-batters at close range.',
  wraith:        'Spirit of a slain priest. Phases through the living.',
  ogre:          'Hill ogre. Treats trees like clubs and clubs like toothpicks.',
  sapper:        'Goblin sapper. Lights a fuse, sprints in to detonate.',
  archer:        'Hardened bandit marksman. Soft body, hard arrows.',
  shaman:        'Goblin shaman. Heals nearby allies, kite him fast.',
  summoner:      'Bone-conjurer. Raises a fresh skeleton every 5 seconds.',
  spider:        'Cave widow. Weaves side-to-side to throw off targeting.',
  witch:         'Coven witch. Hurls cursed bolts from a safe distance.',
  zealot:        'Cult zealot. Will sprint to martyr itself on your blade.',
  reaver:        'Bandit reaver. Berserk dual-wielding swordsman.',
  lich:          'Risen archmage. Summons minions and snipes from range.',
  hellhound:     'Soulforged hound. Leaves embers wherever it steps.',
  warlock:       'Pact-bound caster. Drains life with each ranged hex.',
  golem:         'Forgehold golem. Walking rune-stone. Hits like a wall.',
  cinder_imp:    'Cinder Imp. Sprints in, detonates on contact.',
  wisp:          'Bone Wisp. Lost spirit. Drifts toward warmth — yours.',
  knight:        'Dread Knight. Cursed plate, undying oath, slow strike.',
  boss_warchief: 'Krrik III, Warchief — goblin king of the southern crags.',
  boss_vyxhasis: 'Vyxhasis the Ember — dragon, scourge of the Emberlands.',
  boss_aethyrnax:'Aethyrnax — ancient sky-wyrm of the void seas.',
  boss_ourzhal:  'Ourzhal — bone-dragon raised by forbidden rite.',
};

function showBestiary() {
  const seen = State.bestiary || {};
  const choices = [];
  const order = [
    'skeleton', 'rat', 'goblin', 'goblin_a', 'brute', 'ghoul', 'drake', 'wraith',
    'ogre', 'sapper', 'archer', 'shaman', 'summoner', 'spider', 'witch', 'zealot',
    'reaver', 'lich', 'hellhound', 'warlock', 'golem',
    'cinder_imp', 'wisp', 'knight',
    'boss_warchief', 'boss_vyxhasis', 'boss_aethyrnax', 'boss_ourzhal',
  ];
  for (const id of order) {
    const e = seen[id];
    if (e) {
      const lore = BESTIARY_LORE[id] || '';
      choices.push({ label: `${id} — ${e.kills} kills\n${lore}`, cls: '', cb: () => {} });
    } else {
      choices.push({ label: '? ? ? ? ?', cls: 'secondary', cb: () => {} });
    }
  }
  choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('BESTIARY', 'Discovered enemies, kill counts, and lore.', choices);
}

const statusrow = document.getElementById('statusrow');
function refreshHud() {
  if (!game || canvas.hidden) return;
  const c = game.combo;
  const z = zoneForWave(game.wave).name;
  if (c > 1) {
    let tier = '';
    if (c >= 30) tier = ' ✦';
    else if (c >= 15) tier = ' ★';
    else if (c >= 5)  tier = ' ·';
    wave.textContent = `WAVE ${game.wave} · ${z} · x${c}${tier} (${game.comboMult().toFixed(2)}×)`;
    wave.style.color = c >= 30 ? '#e8d2a0' : c >= 15 ? '#d4a24c' : c >= 5 ? '#c8a030' : '';
  } else {
    wave.textContent = `WAVE ${game.wave} · ${z}`;
    wave.style.color = '';
  }
  const wavesToBoss = (10 - (game.wave % 10)) % 10;
  if (wavesToBoss > 0 && wavesToBoss <= 3) {
    kills.textContent = `BOSS in ${wavesToBoss}`;
    kills.style.color = '#d4582c';
  } else {
    kills.textContent = `${State.lifetime_kills} kills`;
    kills.style.color = '';
  }
  gold.textContent = `${State.gold} g`;
  embers.textContent = `${State.embers} 🜂`;
  level.textContent = `L${State.hero_level}`;
  // Run timer
  if (game.runStartT) {
    const sec = Math.floor((performance.now() - game.runStartT) / 1000);
    const mm = Math.floor(sec / 60);
    const ss = (sec % 60).toString().padStart(2, '0');
    timer.textContent = `${mm}:${ss}`;
  }
  hpfill.style.width = (100 * game.heroHp / game.heroMaxHp).toFixed(1) + '%';
  log.textContent = game.combatLog.join('\n');
  refreshStatusRow();
  // Update SKILL button: name + cooldown countdown
  const k = game.primaryClass;
  const r = skillRank(k);
  const skillLabels = { warrior: 'CLEAVE', rogue: 'BLINK', wizard: 'FIREBALL', necromancer: 'REAP', bard: 'ANTHEM' };
  const baseLbl = skillLabels[k] || 'SKILL';
  if (game.skillCd > 0) {
    btnSkill.textContent = `${baseLbl} ${game.skillCd.toFixed(1)}s`;
    btnSkill.style.opacity = '0.5';
  } else {
    btnSkill.textContent = r ? `${baseLbl} R${r}` : baseLbl;
    btnSkill.style.opacity = '';
  }
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
  if (game.berserkerT > 0) add(`Berserker ${game.berserkerT.toFixed(1)}s`, 'temp');
  if (game.quicksilverT > 0) add(`Quicksilver ${game.quicksilverT.toFixed(1)}s`, 'temp');
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
      const cur = currencyOf(u.id);
      const sfx = cur === 'embers' ? '🜂' : 'g';
      const text = c < 0
        ? `${u.label} (MAXED)`
        : `${u.label} — ${u.desc}  ·  Rank ${r}/30  ·  ${c}${sfx}`;
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
    showOverlay('UPGRADES', `Gold = combat. Embers = prestige.\n${State.gold} gold  ·  ${State.embers} 🜂`, choices);
  }
  rebuild();
}

document.getElementById('btn-strike').addEventListener('click', () => game && game.strike());
const btnSkill = document.getElementById('btn-skill');
btnSkill.addEventListener('click', () => game && game.skill());
document.getElementById('btn-pause').addEventListener('click', () => {
  if (!game) return;
  game.paused = !game.paused;
  if (game.paused) {
    const stats = [
      `Damage: ${game.heroDmg()}   ·   Atk/sec: ${game.atkRate().toFixed(2)}`,
      `Range: ${Math.round(game.heroRange())}   ·   Crit: ${Math.round((game.critBonus + 0) * 100)}%`,
      `Gold mult: ${(game.goldMult * game.rebirthBonus * (1 + (State.level_perks?.perm_gold || 0) * 0.05) * game.challengeBonus()).toFixed(2)}×`,
      game.synergy ? (game.synergy()?.label ? `Synergy: ${game.synergy().label}` : '') : '',
      '',
      'QUESTS',
      game.quests ? game.quests.summary() : '',
    ].filter(Boolean).join('\n');
    showOverlay('Paused', stats, [
      { label: 'Resume', cls: '', cb: () => { game.paused = false; hideOverlay(); } },
      { label: 'Upgrades', cls: 'secondary', cb: () => showUpgradeShop(false) },
      { label: 'Quit to Title', cls: 'secondary', cb: () => { hideOverlay(); refreshTitle(); } },
    ]);
  } else hideOverlay();
});

btnNewRun.addEventListener('click', () => {
  showClassPicker(startGame);
});

function speedrunStart() {
  showClassPicker((cls) => startGame(cls, 1, { speedrun: true }));
}

function hardcoreStart() {
  showClassPicker((cls) => startGame(cls, 1, { hardcore: true }));
}

function dailySeedStart() {
  showClassPicker((cls) => startGame(cls, 1, { dailySeed: true }));
}
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
  addBtn('btn-history',  'RUN HISTORY',  showRunHistory);
  addBtn('btn-trinkets', 'TRINKETS',     showTrinkets);
  addBtn('btn-speedrun', 'SPEEDRUN',     speedrunStart);
  addBtn('btn-hardcore', 'HARDCORE',     hardcoreStart);
  addBtn('btn-daily',    'DAILY SEED',   dailySeedStart);
  addBtn('btn-stats',    'STATS',        showStats);
  addBtn('btn-glory',    'GLORY',        showGlory);
  addBtn('btn-skills',   'SKILL RANKS',  showSkillRanks);
  addBtn('btn-skins',    'SKINS',        showSkins);
  addBtn('btn-curse',    'DAILY CURSE',  toggleCurse);
  addBtn('btn-settings', 'SETTINGS',     showSettings);
}

function showProfiles() {
  const choices = [];
  for (let i = 0; i < 3; i++) {
    const sum = Save.slotSummary(i);
    const desc = sum
      ? `W${sum.best_wave} · ${sum.embers} 🜂 · Mark ${sum.rebirths} · L${sum.hero_level}`
      : 'empty';
    const active = Save.activeSlot() === i;
    choices.push({
      label: `${active ? '✦' : '○'} Slot ${i + 1} — ${desc}`,
      cls: active ? '' : 'secondary',
      cb: () => {
        if (active) return;
        Save.setActiveSlot(i);
        location.reload();
      },
    });
  }
  choices.push({ label: 'Back', cls: 'secondary', cb: () => showSettings() });
  showOverlay('PROFILES',
    'Three independent save slots.\nSwitching slots reloads with that slot\'s state.',
    choices);
}

function showSkins() {
  function rebuild() {
    const choices = SKINS.map(s => {
      const owned = ownsSkin(s.id);
      const active = activeSkinFor(s.klass) === s.id;
      const mark = active ? '✦' : (owned ? '○' : '✗');
      let label = `${mark} ${s.label} (${s.klass}) — ${s.color}`;
      if (!owned) label += `  ·  ${s.cost}🜂`;
      else if (active) label += `  · equipped`;
      return {
        label,
        cls: owned && active ? '' : 'secondary',
        cb: () => {
          if (!owned) {
            if (buySkin(s.id)) rebuild();
          } else if (active) {
            equipSkin(s.klass, '');
            rebuild();
          } else {
            equipSkin(s.klass, s.id);
            rebuild();
          }
        },
      };
    });
    choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
    showOverlay('SKINS', `Cosmetic palette swaps per class.\nYou have ${State.embers} 🜂.`, choices);
  }
  rebuild();
}

function showSkillRanks() {
  const classes = ['warrior', 'rogue', 'wizard', 'necromancer', 'bard'];
  function rebuild() {
    const choices = classes.map(c => {
      const r = skillRank(c);
      const next = skillNextCost(c);
      const label = next < 0
        ? `${c[0].toUpperCase()}${c.slice(1)} — R${r}/3 (MAX)`
        : `${c[0].toUpperCase()}${c.slice(1)} — R${r}/3  ·  ${next}🜂`;
      return {
        label,
        cls: (next > 0 && State.embers >= next) ? '' : 'secondary',
        cb: () => { if (skillBuy(c)) rebuild(); },
      };
    });
    choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
    showOverlay('SKILL RANKS',
      `Spend embers to strengthen each class's SKILL.\nYou have ${State.embers} 🜂.`,
      choices);
  }
  rebuild();
}

function showGlory() {
  const g = State.lifetime_embers || 0;
  const choices = GLORY_TIERS.map(t => {
    const earned = g >= t.threshold;
    const mark = earned ? '✓' : '○';
    return {
      label: `${mark} ${t.title} (${t.threshold} 🜂) — ${t.desc}`,
      cls: earned ? '' : 'secondary',
      cb: () => {},
    };
  });
  choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('GLORY', `Lifetime embers: ${g}\nEach tier grants a permanent bonus.`, choices);
}

function showStats() {
  const top = State.top_runs?.[0];
  const lines = [
    `Mark: ${State.rebirths}   ·   Hero level: ${State.hero_level}`,
    `Best wave: ${State.best_wave}   ·   Bosses felled: ${State.bosses_felled}`,
    `Lifetime kills: ${State.lifetime_kills}   ·   Curses cleared: ${State.curses_cleared}`,
    `Glory (lifetime 🜂): ${State.lifetime_embers || 0}`,
    `Login streak: ${State.login_streak}`,
    top ? `#1 run: W${top.wave}, ${top.kills} kills (${top.class})` : '',
    `Trinkets owned: ${Object.keys(State.trinkets || {}).length} / 8`,
    `Dragonslayer: ${State.dragonslayer ? '⚔ yes' : 'no'}`,
  ].filter(Boolean).join('\n');
  showOverlay('STATS', lines, [{ label: 'Back', cls: 'secondary', cb: () => hideOverlay() }]);
}

function showTrinkets() {
  const owned = State.trinkets || {};
  const eq = equipped();
  const choices = [];
  for (const t of TRINKETS) {
    const owns = !!owned[t.id];
    const isEq = eq === t.id;
    const mark = isEq ? '✦' : (owns ? '○' : '✗');
    choices.push({
      label: `${mark} ${t.label} — ${t.desc}`,
      cls: owns ? '' : 'secondary',
      cb: () => {
        if (!owns) return;
        equip(isEq ? '' : t.id);
        showTrinkets();
      },
    });
  }
  choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('TRINKETS', `One equipped at a time. Boss kills drop new ones.\nEquipped: ${eq || '— none —'}`, choices);
}

function showSettings() {
  // We can't put a real slider into a button-only modal, so step
  // through 0 / 25 / 50 / 75 / 100 with a single button that cycles.
  function nextVol(curr) { return Math.round(((curr * 100 + 25) % 125)) / 100; }
  function rebuild() {
    const muted = isMuted();
    const choices = [
      {
        label: `Volume: ${Math.round((State.sfx_volume || 0) * 100)}%`,
        cls: 'secondary',
        cb: () => {
          State.sfx_volume = nextVol(State.sfx_volume || 0);
          persist();
          Music.updateGain();
          rebuild();
        },
      },
      {
        label: muted ? 'Audio: MUTED' : 'Audio: ON',
        cls: 'secondary',
        cb: () => { const m = !isMuted(); setMuted(m); setMusicMuted(m); rebuild(); },
      },
      {
        label: `Profiles — slot ${Save.activeSlot() + 1} of 3`,
        cls: 'secondary',
        cb: () => showProfiles(),
      },
      {
        label: 'Export save (to clipboard)',
        cls: 'secondary',
        cb: () => {
          const blob = exportSave();
          if (navigator.clipboard?.writeText) {
            navigator.clipboard.writeText(blob).then(() => {
              showOverlay('Exported', 'Save copied to clipboard.\nPaste into a text file to back up.',
                [{ label: 'Back', cls: '', cb: () => showSettings() }]);
            });
          } else {
            // Fallback: show in body, user can long-press to copy
            showOverlay('Save data', blob,
              [{ label: 'Back', cls: '', cb: () => showSettings() }]);
          }
        },
      },
      {
        label: 'Import save (paste)',
        cls: 'secondary',
        cb: () => {
          const v = prompt('Paste your save blob:');
          if (!v) return showSettings();
          if (importSave(v)) location.reload();
          else showOverlay('Import failed', 'That doesn\'t look like a valid save.',
            [{ label: 'Back', cls: '', cb: () => showSettings() }]);
        },
      },
      {
        label: 'Reset save (DANGER)',
        cls: 'secondary',
        cb: () => {
          showOverlay('Reset save?',
            'This wipes ALL progress permanently.',
            [
              { label: 'Yes, wipe everything', cls: '',
                cb: () => { localStorage.clear(); location.reload(); } },
              { label: 'Cancel', cls: 'secondary', cb: () => showSettings() },
            ]);
        },
      },
      {
        label: 'Credits / About',
        cls: 'secondary',
        cb: () => showCredits(),
      },
      { label: 'Back', cls: 'secondary', cb: () => hideOverlay() },
    ];
    showOverlay('SETTINGS', `Volume cycles 0 → 100% in 25% steps.`, choices);
  }
  rebuild();
}

function showCredits() {
  const body =
    `HEARTHKEEP of the Sundered Realms\n` +
    `Mobile horde-survival roguelike\n\n` +
    `An indie passion project. Iron Vesper Studios.\n` +
    `Built with HTML5 Canvas + Capacitor 6.\n\n` +
    `Every commit hits GitHub Pages and auto-updates the APK on launch.\n` +
    `Sources, audio, art all CC0 or original.\n\n` +
    `Thanks for playing.`;
  showOverlay('CREDITS', body, [
    { label: 'Back', cls: 'secondary', cb: () => showSettings() },
  ]);
}

function toggleCurse() {
  if (!State.daily_curse) return;
  State.challenge_active = !State.challenge_active;
  persist();
  refreshTitle();
}

ensureExtraTitleButtons();

function showRunHistory() {
  const choices = [];
  const top = State.top_runs || [];
  if (top.length > 0) {
    for (let i = 0; i < top.length; i++) {
      const r = top[i];
      const cls = (r.class || '?')[0].toUpperCase() + (r.class || '?').slice(1);
      choices.push({
        label: `#${i + 1}  W${r.wave}  ·  ${r.kills} kills  ·  ${cls}`,
        cls: 'secondary',
        cb: () => {},
      });
    }
  }
  const recent = State.run_history || [];
  if (recent.length > 0) {
    choices.push({ label: '— recent runs —', cls: 'secondary', cb: () => {} });
    for (let i = recent.length - 1; i >= 0 && i >= recent.length - 5; i--) {
      const r = recent[i];
      const cls = (r.class || '?')[0].toUpperCase() + (r.class || '?').slice(1);
      const combo = r.combo >= 5 ? `  combo x${r.combo}` : '';
      choices.push({
        label: `W${r.wave}  ·  ${r.kills} kills  ·  +${r.embers}🜂 (${cls})${combo}`,
        cls: 'secondary',
        cb: () => {},
      });
    }
  }
  if (choices.length === 0) {
    choices.push({ label: 'No runs yet.', cls: 'secondary', cb: () => {} });
  }
  choices.push({ label: 'Back', cls: 'secondary', cb: () => hideOverlay() });
  showOverlay('RUN HISTORY', 'Top 5 + recent 5 runs.', choices);
}

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


// First-run tutorial — appears once per browser/save slot
if (!State.tutorial_seen) {
  showOverlay('HEARTHKEEP',
    `Auto-attack runs by itself — you just survive.

STRIKE: tap for a 4× burst hit
SKILL: class active (6s cd)
PAUSE: live build stats + quests

Every 5 waves → perk pick
Every 7 waves → merchant
Every 10 waves → BOSS (telegraphed)
Every 13 waves → TEMPEST
Every 15 waves → treasure chest

Gold buys upgrades. Embers buy prestige.
Wave 50 unlocks REBIRTH (perm +25%).`,
    [{ label: 'Begin', cls: '', cb: () => { State.tutorial_seen = true; persist(); hideOverlay(); } }]);
}

window.addEventListener('beforeunload', () => persist());

// Register the service worker. Cache-first means after first load
// the game runs entirely offline.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}
refreshTitle();
