// HTML5 horde arena — canvas renderer, ECS-lite update loop.
import { State, persist, grantXp, checkKillMilestones, recordRun, grantEmbers, tickWeekly, hasGlory, skillRank, colorForClass, mulberry32, todaySeedInt, recordDailyRun } from './state.js';
import { bonusDamage, bonusAtk, bonusRange, bonusHp, bonusCrit, emberDmgMult, emberGoldMult, maxRevives } from './upgrades.js';
import { synergyFor } from './synergies.js';
import { Sfx } from './sfx.js';
import { Music } from './music.js';
import * as Trinkets from './trinkets.js';
import { scanAndClaimVerbose } from './achievements.js';
import { Quests } from './quests.js';

const CLASS_COLOR = {
  warrior: '#d9892e',
  rogue: '#6fd07f',
  wizard: '#5a8fb3',
  necromancer: '#9966c8',
  bard: '#d4a4cc',
};

// Per-class stat-profile multipliers. Skewed so each class plays differently.
const CLASS_STATS = {
  warrior:     { dmg: 1.15, atk: 0.95, hp: 1.20, range: 0.90 },
  rogue:       { dmg: 1.00, atk: 1.20, hp: 0.95, range: 1.00 },
  wizard:      { dmg: 1.25, atk: 0.85, hp: 0.85, range: 1.20 },
  necromancer: { dmg: 1.05, atk: 1.00, hp: 1.05, range: 1.05 },
  bard:        { dmg: 0.95, atk: 1.10, hp: 1.10, range: 1.10 },
};

const ENEMY_TYPES = {
  skeleton:   { label: 'Skeleton',   color: '#ddd5b5', hp: 6,   speed: 70,  gold: 1, size: 18, minWave: 1 },
  goblin:     { label: 'Goblin',     color: '#73c059', hp: 10,  speed: 95,  gold: 2, size: 18, minWave: 3 },
  brute:      { label: 'Bone Brute', color: '#bfb088', hp: 24,  speed: 55,  gold: 5, size: 22, minWave: 6 },
  ghoul:      { label: 'Ghoul',      color: '#8ab080', hp: 40,  speed: 110, gold: 9, size: 20, minWave: 9 },
  drake:      { label: 'Drake',      color: '#d95940', hp: 60,  speed: 75,  gold: 14, size: 24, minWave: 12 },
  wraith:     { label: 'Wraith',     color: '#8c72d9', hp: 90,  speed: 130, gold: 24, size: 20, minWave: 16 },
  ogre:       { label: 'Ogre',       color: '#8a8a4d', hp: 220, speed: 40,  gold: 55, size: 30, minWave: 20 },
  sapper:     { label: 'Sapper',     color: '#f27333', hp: 30,  speed: 50,  gold: 8,  size: 20, minWave: 14, explodes: true },
  archer:     { label: 'Archer',     color: '#b3d966', hp: 25,  speed: 50,  gold: 6,  size: 18, minWave: 11, ranged: true },
  shaman:     { label: 'Shaman',     color: '#73d98c', hp: 50,  speed: 60,  gold: 16, size: 20, minWave: 18, heals: true },
  summoner:   { label: 'Summoner',   color: '#b380d9', hp: 70,  speed: 45,  gold: 18, size: 22, minWave: 22, summons: true },
  spider:     { label: 'Spider',     color: '#73a039', hp: 18,  speed: 140, gold: 4,  size: 16, minWave: 7  },
  witch:      { label: 'Witch',      color: '#c266c2', hp: 80,  speed: 75,  gold: 22, size: 22, minWave: 24, ranged: true },
  zealot:     { label: 'Zealot',     color: '#e8b85e', hp: 110, speed: 85,  gold: 26, size: 22, minWave: 28 },
  reaver:     { label: 'Reaver',     color: '#a06044', hp: 180, speed: 65,  gold: 40, size: 26, minWave: 32 },
  lich:       { label: 'Lich',       color: '#cbb0e8', hp: 260, speed: 55,  gold: 75, size: 28, minWave: 36, ranged: true, summons: true },
  hellhound:  { label: 'Hellhound',  color: '#e84c2c', hp: 90,  speed: 165, gold: 18, size: 20, minWave: 40 },
  warlock:    { label: 'Warlock',    color: '#a04ce8', hp: 200, speed: 70,  gold: 60, size: 24, minWave: 44, ranged: true },
  golem:      { label: 'Stone Golem',color: '#9a9a9a', hp: 500, speed: 35,  gold: 150,size: 32, minWave: 48 },
};

const ZONES = [
  { min: 1,  name: 'Greenmarch', floor: '#101a10' },
  { min: 11, name: 'Ashen Vale', floor: '#1c1610' },
  { min: 21, name: 'Frostwatch', floor: '#101620' },
  { min: 31, name: 'Emberlands', floor: '#1f0d09' },
  { min: 41, name: 'The Void',   floor: '#0d0a18' },
  { min: 51, name: 'Forgehold',  floor: '#291408' },
  { min: 71, name: 'Sunfire',    floor: '#332108' },
];

function _lighten(hex, frac) {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  const f = Math.max(0, Math.min(1, frac));
  const nr = Math.round(r + (255 - r) * f);
  const ng = Math.round(g + (255 - g) * f);
  const nb = Math.round(b + (255 - b) * f);
  return '#' + [nr, ng, nb].map(x => x.toString(16).padStart(2, '0')).join('');
}

export function zoneForWave(w) {
  let cur = ZONES[0];
  for (const z of ZONES) if (w >= z.min) cur = z;
  return cur;
}

const BOSS_TYPES = {
  warchief:  { label: 'Krrik III',   color: '#d4a24c', hp: 240,  speed: 50,  gold: 60,  size: 38,
               hint: 'Krrik charges every 4s — back off when he tints red.' },
  vyxhasis:  { label: 'Vyxhasis',    color: '#d44089', hp: 600,  speed: 45,  gold: 200, size: 48,
               hint: 'Vyxhasis goes airborne — wait for her to land before swinging.' },
  aethyrnax: { label: 'Aethyrnax',   color: '#66d9f2', hp: 1400, speed: 55,  gold: 500, size: 56,
               hint: 'Aethyrnax alternates charge + fly. Position carefully.' },
  ourzhal:   { label: 'Ourzhal',     color: '#f08533', hp: 3200, speed: 65,  gold: 1200, size: 68,
               hint: 'Ourzhal cycles charge + fly + summons. Endgame challenge.' },
};

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.enemies = [];
    this.fx = [];        // ephemeral particles: { x, y, vx, vy, life, color, size }
    this.floaters = [];  // { text, x, y, color, life }
    this.combatLog = [];
    this.arrows = [];    // { x, y, vx, vy, dmg, life }
    this.powerups = [];  // { x, y, tx, ty, kind, life }
    this.coins = [];     // visible gold pickups [{ x, y, vx, vy, life }]
    this.wave = 1;
    this.waveKillsTarget = 8;
    this.waveKillsProgress = 0;
    this.spawnTimer = 1.4;
    this.attackTimer = 0;
    this.idleTimer = 1;
    this.skillCd = 0;
    this.heroHp = this.maxHp();
    this.heroMaxHp = this.heroHp;
    this.primaryClass = 'warrior';
    this.secondaryClass = '';
    this.tertiaryClass = '';
    this.killsThisRun = 0;
    this.paused = false;
    this.deadScreenOpen = false;
    this.shakeMag = 0;
    this.runEmbersEarned = 0;
    this.combo = 0;
    this.comboDecay = 0;
    this.comboPeak = 0;
    this.rebirthBonus = 1.0 + (State.rebirths || 0) * 0.25;
    // Hardcore mode disables this multiplier; constructor runs before
    // game.hardcore is set by main, so we expose a setter that recomputes.
    // Class-signature passive state (per-run)
    this.warriorRage = 0;
    this.wizardHitCount = 0;
    this.frenzy = 0;          // hits taken since last guaranteed-crit
    this.FRENZY_CAP = 5;
    this.iframeT = 0;
    this.untouchedSinceWave = true; // perfect-clear tracker
    this.killsByType = {};          // run-scoped: id -> count
    this.peakDps = 0;
    this.dpsSamples = [];           // recent dmg events: {t, amount}
    this.runStartT = performance.now();
    this.revivesUsed = 0;
    this.preRunBestWave = State.best_wave || 0;
    this.quests = new Quests();
    this.speedrun = false;
    this.speedrunDone = false;
    this.hardcore = false;
    this.dailySeed = false;
    this.rng = Math.random;
    // Companion (unlocks at first boss kill)
    this.companionOrbitT = 0;
    this.companionAtkT = 1;
    // Sunfire pulse (zone 7+)
    this.sunfirePulseT = 8;
    // Boss telegraph countdown
    this.bossWarn = null; // { t, label }
    this.weather = []; // [{x, y, vy, color, size}]
    this.bgDots = [];  // long-lived parallax dots
    this.flash = 0;    // 0..1 white-screen flash on big events
    this.timeScale = 1;
    this.timeScaleEndAt = 0;
    this.banner = null;     // { text, color, t, t0 }
    this.lastCritted = false;
    this.heroThrust = { x: 0, y: 0, t: 0 }; // animated push toward last target
    this.weaponAngle = -Math.PI / 4;        // pointing-at-last-target angle
    // Perk accumulators (per-run)
    this.takenPerks = new Set();
    this.onBossBoon = null;     // fn(picks, applyCb)
    this.dmgMult = 1.0;
    this.goldMult = 1.0;
    this.waveBonusMult = 1.0;
    this.critBonus = 0.0;
    this.atkBonus = 0.0;
    this.rangeBonus = 0.0;
    this.spawnSlow = 0.0;
    this.mythicBonus = 0.0;
    this.contactReduction = 0.0;
    this.onPerkRequest = null;    // fn(picks, applyCb) → modal opens
    this.onMerchant = null;       // fn() → modal opens
    this.onLevelPick = null;      // fn(level)
    this.onSlotUnlock = null;     // fn('secondary'|'tertiary')
    this.onSpeedrunFinish = null; // fn(ms)
    this.lastSeenLevel = State.hero_level;
    this.size = { w: 0, h: 0 };
    this.heroPos = { x: 0, y: 0 };
    this._resize();
    window.addEventListener('resize', () => this._resize());
    this.last = performance.now();
    requestAnimationFrame(() => this._loop());
  }

  _resize() {
    const r = window.devicePixelRatio || 1;
    const w = window.innerWidth, h = window.innerHeight;
    this.canvas.width = w * r;
    this.canvas.height = h * r;
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    this.ctx.setTransform(r, 0, 0, r, 0, 0);
    this.size = { w, h };
    this.heroPos = { x: w / 2, y: h / 2 + 30 };
  }

  _drawZoneDecor(ctx, w, h) {
    // Cheap noise-free decor: hash a few fixed points off the zone name.
    const zone = zoneForWave(this.wave).name;
    const seed = (() => { let s = 0; for (const c of zone) s = ((s * 31) + c.charCodeAt(0)) >>> 0; return s; })();
    const rng = mulberry32(seed);
    ctx.save();
    ctx.globalAlpha = 0.12;
    const palette = {
      'Greenmarch':  '#6fa060',
      'Ashen Vale':  '#6c5848',
      'Frostwatch':  '#80c8e0',
      'Emberlands':  '#d4582c',
      'The Void':    '#9966c8',
      'Forgehold':   '#e8b85e',
      'Sunfire':     '#f5d96e',
    };
    ctx.fillStyle = palette[zone] || 'rgba(255,255,255,0.1)';
    for (let i = 0; i < 40; i++) {
      const x = rng() * w;
      const y = 96 + rng() * (h - 200);
      const s = 2 + rng() * 4;
      ctx.beginPath();
      ctx.arc(x, y, s, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  _drawWeapon(x, y, r) {
    const ctx = this.ctx;
    const a = this.weaponAngle;
    const cx = Math.cos(a);
    const sx = Math.sin(a);
    const base = { x: x + cx * (r + 2), y: y + sx * (r + 2) };
    const k = this.primaryClass;
    ctx.strokeStyle = '#e8e2d2';
    ctx.lineWidth = 3;
    switch (k) {
      case 'warrior': {  // long sword
        const tip = { x: x + cx * (r + 28), y: y + sx * (r + 28) };
        ctx.beginPath();
        ctx.moveTo(base.x, base.y);
        ctx.lineTo(tip.x, tip.y);
        ctx.stroke();
        // Cross-guard
        const px = -sx, py = cx;
        ctx.beginPath();
        ctx.moveTo(base.x - px * 6, base.y - py * 6);
        ctx.lineTo(base.x + px * 6, base.y + py * 6);
        ctx.stroke();
        break;
      }
      case 'rogue': {  // short dagger
        const tip = { x: x + cx * (r + 18), y: y + sx * (r + 18) };
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(base.x, base.y);
        ctx.lineTo(tip.x, tip.y);
        ctx.stroke();
        break;
      }
      case 'wizard': {  // staff with glowing orb
        const tip = { x: x + cx * (r + 30), y: y + sx * (r + 30) };
        ctx.strokeStyle = '#8a6d3b';
        ctx.beginPath();
        ctx.moveTo(base.x, base.y);
        ctx.lineTo(tip.x, tip.y);
        ctx.stroke();
        ctx.fillStyle = '#5a8fb3';
        ctx.beginPath();
        ctx.arc(tip.x, tip.y, 5, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case 'necromancer': {  // scythe — line + curved blade
        const tip = { x: x + cx * (r + 26), y: y + sx * (r + 26) };
        ctx.strokeStyle = '#5a4a3a';
        ctx.beginPath();
        ctx.moveTo(base.x, base.y);
        ctx.lineTo(tip.x, tip.y);
        ctx.stroke();
        const px = -sx, py = cx;
        ctx.strokeStyle = '#9966c8';
        ctx.beginPath();
        ctx.arc(tip.x + px * 7, tip.y + py * 7, 10, a - 0.4, a + 1.6);
        ctx.stroke();
        break;
      }
      case 'bard': {  // lute body
        ctx.fillStyle = '#a07050';
        ctx.beginPath();
        ctx.ellipse(base.x + cx * 8, base.y + sx * 8, 9, 6, a, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#d4a4cc';
        ctx.beginPath();
        ctx.moveTo(base.x, base.y);
        ctx.lineTo(base.x + cx * 22, base.y + sx * 22);
        ctx.stroke();
        break;
      }
    }
  }

  _drawHeroShape(x, y, r) {
    const ctx = this.ctx;
    const k = this.primaryClass;
    ctx.beginPath();
    let sides = 0, rot = 0;
    switch (k) {
      case 'warrior':     sides = 4; rot = Math.PI / 4;       break; // square (diamond rotated)
      case 'rogue':       sides = 3; rot = -Math.PI / 2;      break; // triangle, point up
      case 'wizard':      sides = 4; rot = 0;                 break; // diamond (rotated square)
      case 'necromancer': sides = 6; rot = 0;                 break; // hexagon
      case 'bard':        sides = 5; rot = -Math.PI / 2;      break; // pentagon
      default:            sides = 0;                          break; // circle
    }
    if (sides === 0) {
      ctx.arc(x, y, r, 0, Math.PI * 2);
      return;
    }
    for (let i = 0; i < sides; i++) {
      const a = rot + (Math.PI * 2 * i) / sides;
      const px = x + Math.cos(a) * r;
      const py = y + Math.sin(a) * r;
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.closePath();
  }

  classMul(stat) {
    const p = CLASS_STATS[this.primaryClass] || CLASS_STATS.warrior;
    return p[stat] ?? 1;
  }

  maxHp() {
    let hp = 50;
    hp += Math.floor((State.best_wave || 0) / 2);
    hp += (State.hero_level - 1);
    hp += bonusHp();
    hp += (State.level_perks?.perm_hp || 0) * 5;
    hp = Math.round(hp * (1 + Trinkets.hpBonus()) * this.classMul('hp'));
    if (hasGlory('ascendant')) hp = Math.round(hp * 1.10);
    if (State.challenge_active && State.daily_curse === 'glass_cannon') hp = Math.max(10, Math.floor(hp / 2));
    return Math.max(20, hp);
  }

  challengeBonus() {
    let m = 1;
    if (State.challenge_active) m *= 2;
    if (this.hardcore) m *= 2;
    return m;
  }
  curseDisables(c) {
    return State.challenge_active && State.daily_curse === c;
  }

  // --- Loop ---
  _loop() {
    const now = performance.now();
    let dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    // Apply kill-cam time scale (real-time UI keeps ticking, only the
    // simulation slows).
    if (this.timeScaleEndAt && now >= this.timeScaleEndAt) {
      this.timeScale = 1;
      this.timeScaleEndAt = 0;
    }
    if (!this.paused && !this.deadScreenOpen) {
      this._update(dt * this.timeScale);
    }
    this._render();
    requestAnimationFrame(() => this._loop());
  }

  setTimeScale(scale, durationMs) {
    this.timeScale = scale;
    this.timeScaleEndAt = performance.now() + durationMs;
  }

  setHardcore(on) {
    this.hardcore = !!on;
    if (this.hardcore) this.rebirthBonus = 1.0;  // strip rebirth boost
  }

  setDailySeed(on) {
    this.dailySeed = !!on;
    this.rng = on ? mulberry32(todaySeedInt()) : Math.random;
  }

  _update(dt) {
    this.spawnTimer -= dt;
    this.attackTimer -= dt;
    this.idleTimer -= dt;
    if (this.skillCd > 0) this.skillCd -= dt;
    if (this.iframeT > 0) this.iframeT -= dt;
    if (this.comboDecay > 0) {
      this.comboDecay -= dt;
      if (this.comboDecay <= 0) this.combo = 0;
    }

    if (this.spawnTimer <= 0) {
      this._spawn();
      const soft = this.wave > 5 ? 1.0 : (2.2 - (this.wave - 1) * 0.2);
      let t = soft - this.wave * 0.04;
      t /= Math.max(0.4, 1.0 - this.spawnSlow);
      if (this.isTempest()) t *= 0.5;
      this.spawnTimer = Math.max(0.15, t);
    }
    if (this.attackTimer <= 0) {
      this._heroAuto();
      this.attackTimer = 1.0 / this.atkRate();
    }
    if (this.hasCompanion()) this._tickCompanion(dt);

    // Sunfire ambient pulse (enemy-only AoE).
    if (this.wave >= 71) {
      this.sunfirePulseT -= dt;
      if (this.sunfirePulseT <= 0) {
        this.sunfirePulseT = 8;
        const dmg = Math.max(1, Math.round(this.heroDmg() * 0.2));
        for (const e of this.enemies) {
          if (e.dead) continue;
          const d = Math.hypot(e.x - this.heroPos.x, e.y - this.heroPos.y);
          if (d < 280) this._damageEnemy(e, dmg);
        }
        // Ring visual
        for (let i = 0; i < 16; i++) {
          const a = (Math.PI * 2 * i) / 16;
          this.fx.push({
            x: this.heroPos.x, y: this.heroPos.y,
            vx: Math.cos(a) * 280, vy: Math.sin(a) * 280,
            life: 0.5, color: '#ff8533', size: 6, fade: true,
          });
        }
      }
    }

    // Boss telegraph countdown.
    if (this.bossWarn) {
      this.bossWarn.t -= dt;
      if (this.bossWarn.t <= 0) {
        const id = this.bossWarn.id;
        this.bossWarn = null;
        this._actuallySpawnBoss(id);
      }
    }
    if (this.idleTimer <= 0) {
      this.idleTimer = 1;
      const idle = Math.round(0.4 + (State.best_wave || 0) * 0.15);
      if (idle > 0) {
        State.gold += idle;
      }
    }

    // Move enemies + contact
    for (const e of this.enemies) {
      if (e.dead) continue;
      if (e.hitFlash > 0) e.hitFlash -= dt;
      if (e.spawnFade > 0) e.spawnFade = Math.max(0, e.spawnFade - dt * 2.5);  // 0.4s fade
      if (e.boss) this._bossPhaseTick(e, dt);
      const dx = this.heroPos.x - e.x;
      const dy = this.heroPos.y - e.y;
      const d = Math.hypot(dx, dy) || 1;
      // Archer: kite at 220px and fire arrows.
      if (e.ranged) {
        e.shotCd -= dt;
        const want = 220;
        const step = e.speed * dt * (d < want ? -1 : 0.6);
        e.x += (dx / d) * step;
        e.y += (dy / d) * step;
        if (e.shotCd <= 0) {
          this.arrows.push({
            x: e.x, y: e.y,
            vx: (dx / d) * 220, vy: (dy / d) * 220,
            dmg: 3 + Math.floor(this.wave / 3), life: 2.5,
          });
          e.shotCd = 2.0;
        }
        continue;
      }
      // Summoner: kite + periodically spawn a skeleton minion.
      if (e.summons) {
        e.summonCd -= dt;
        const want = 260;
        const step = e.speed * dt * (d < want ? -1 : 0.4);
        e.x += (dx / d) * step;
        e.y += (dy / d) * step;
        if (e.summonCd <= 0) {
          this._spawnMinion(e.x, e.y);
          e.summonCd = 5.0;
        }
        continue;
      }
      // Shaman: kite at 240px and heal a wounded ally.
      if (e.heals) {
        e.healCd -= dt;
        const want = 240;
        const step = e.speed * dt * (d < want ? -1 : 0.4);
        e.x += (dx / d) * step;
        e.y += (dy / d) * step;
        if (e.healCd <= 0) {
          let target = null, tgap = 0;
          for (const o of this.enemies) {
            if (o === e || o.dead || o.heals) continue;
            const gap = o.maxHp - o.hp;
            if (gap > tgap) { tgap = gap; target = o; }
          }
          if (target) {
            const amt = Math.max(1, Math.round(tgap * 0.2));
            target.hp = Math.min(target.maxHp, target.hp + amt);
            this.floater(`+${amt}`, target.x, target.y, '#6fa060');
          }
          e.healCd = 4.0;
        }
        continue;
      }
      // Default chase + bite.
      let mvx = (dx / d) * e.speed * dt;
      let mvy = (dy / d) * e.speed * dt;
      // Spider: weave side-to-side toward hero.
      if (e.id === 'spider') {
        const px = -dy / d, py = dx / d;
        const w = Math.sin(performance.now() / 200 + (e.x * 0.01)) * 0.6;
        mvx += px * e.speed * dt * w;
        mvy += py * e.speed * dt * w;
      }
      e.x += mvx;
      e.y += mvy;
      if (d < 22 + e.size * 0.4) {
        if (e.boss && e.phase === 'fly') continue; // airborne ignores contact
        let bite = 2 + Math.floor(this.wave / 4) * (e.boss ? 6 : (e.mythic ? 3 : 1));
        bite = Math.max(1, Math.round(bite * (1 - this.contactReduction)));
        this._heroTakeDamage(bite);
        this._killEnemy(e, false);
      }
    }

    // Arrows
    for (const a of this.arrows) {
      a.x += a.vx * dt;
      a.y += a.vy * dt;
      a.life -= dt;
      const adx = a.x - this.heroPos.x;
      const ady = a.y - this.heroPos.y;
      if (adx * adx + ady * ady < 24 * 24) {
        this._heroTakeDamage(a.dmg);
        a.life = 0;
      }
    }
    this.arrows = this.arrows.filter(a => a.life > 0);

    // Coins: small arc, then magnet to hero. Don't grant gold (already
    // applied at kill time) — these are pure visual feedback.
    for (const c of this.coins) {
      c.life -= dt;
      c.magnetT -= dt;
      if (c.magnetT > 0) {
        c.x += c.vx * dt;
        c.y += c.vy * dt;
        c.vy += 120 * dt;
      } else {
        const dx2 = this.heroPos.x - c.x;
        const dy2 = this.heroPos.y - c.y;
        const d2 = Math.hypot(dx2, dy2) || 1;
        c.x += (dx2 / d2) * 380 * dt;
        c.y += (dy2 / d2) * 380 * dt;
        if (d2 < 26) c.life = 0;
      }
    }
    this.coins = this.coins.filter(c => c.life > 0);
    // Power-ups: magnetic pull to hero.
    for (const p of this.powerups) {
      p.life -= dt;
      const dx2 = this.heroPos.x - p.x;
      const dy2 = this.heroPos.y - p.y;
      const d2 = Math.hypot(dx2, dy2) || 1;
      p.x += (dx2 / d2) * 320 * dt;
      p.y += (dy2 / d2) * 320 * dt;
      if (d2 < 28) {
        this._applyPowerup(p.kind);
        p.life = 0;
      }
    }
    this.powerups = this.powerups.filter(p => p.life > 0);

    // FX
    for (const f of this.fx) {
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.life -= dt;
    }
    this.fx = this.fx.filter(f => f.life > 0);
    for (const fl of this.floaters) {
      fl.life -= dt;
      fl.y -= 40 * dt;
    }
    this.floaters = this.floaters.filter(fl => fl.life > 0);

    if (this.shakeMag > 0) this.shakeMag = Math.max(0, this.shakeMag - 80 * dt);
    if (this.flash > 0) this.flash = Math.max(0, this.flash - 4 * dt);
    if (this.banner) { this.banner.t -= dt; if (this.banner.t <= 0) this.banner = null; }
    if (this.heroThrust.t > 0) {
      this.heroThrust.t -= dt;
      if (this.heroThrust.t <= 0) { this.heroThrust.x = 0; this.heroThrust.y = 0; this.heroThrust.t = 0; }
    }
    // Hero combo trail — class-colored embers drift up while combo ≥ 5.
    if (this.combo >= 5 && Math.random() < 0.5) {
      this.fx.push({
        x: this.heroPos.x + (Math.random() - 0.5) * 30,
        y: this.heroPos.y + 18,
        vx: (Math.random() - 0.5) * 20,
        vy: -30 - Math.random() * 40,
        life: 0.6,
        color: colorForClass(this.primaryClass, '#d4a24c'),
        size: 2 + Math.random() * 2,
        fade: true,
      });
    }

    this._tickWeather(dt);
    this._tickChest(dt);

    this.enemies = this.enemies.filter(e => !e.dead);
  }

  // --- Spawning ---
  _spawn() {
    const pool = [];
    for (const [id, def] of Object.entries(ENEMY_TYPES)) {
      if (this.wave >= def.minWave) pool.push(id);
    }
    if (pool.length === 0) pool.push('skeleton');
    const id = pool[Math.floor(this.rng() * pool.length)];
    const def = ENEMY_TYPES[id];
    const isMythic = this.wave >= 5 && this.rng() < (0.03 + this.mythicBonus + Trinkets.mythicBonus());
    const sz = isMythic ? def.size * 1.4 : def.size;
    let hpScale = 1 + (this.wave - 1) * 0.18;
    if (this.isTempest()) hpScale *= 0.5;
    const maxHp = Math.round(def.hp * hpScale * (isMythic ? 10 : 1));
    const edge = Math.floor(this.rng() * 4);
    let x, y;
    const m = 30;
    if (edge === 0)      { x = this.rng() * this.size.w; y = -m; }
    else if (edge === 1) { x = this.size.w + m; y = this.rng() * this.size.h; }
    else if (edge === 2) { x = this.rng() * this.size.w; y = this.size.h + m; }
    else                 { x = -m; y = this.rng() * this.size.h; }
    this.enemies.push({
      id, label: def.label, color: def.color, x, y,
      hp: maxHp, maxHp, speed: def.speed + this.wave * 1.5,
      gold: def.gold * (isMythic ? 10 : 1), size: sz,
      mythic: isMythic, boss: false,
      explodes: !!def.explodes,
      ranged: !!def.ranged, shotCd: 1.5,
      heals: !!def.heals, healCd: 3.0,
      summons: !!def.summons, summonCd: 4.0,
      spawnFade: 1.0,    // 1 → 0 over 0.4s after spawn
    });
    if (isMythic) {
      this.floater(`MYTHIC ${def.label.toUpperCase()}`, this.size.w / 2 - 60, 80, '#e8d2a0');
    }
  }

  _spawnBoss() {
    const id = this.wave >= 70 ? 'ourzhal'
      : this.wave >= 50 ? 'aethyrnax'
      : this.wave >= 30 ? 'vyxhasis'
      : 'warchief';
    this.bossWarn = { t: 3.0, id, label: BOSS_TYPES[id].label };
    this.floater(`INCOMING: ${BOSS_TYPES[id].label}`, this.size.w / 2 - 100, 60, '#d4582c');
    this.log(`Telegraph: ${BOSS_TYPES[id].label} in 3s`);
  }

  _actuallySpawnBoss(id) {
    const def = BOSS_TYPES[id];
    const hpScale = 1 + (this.wave - 1) * 0.18;
    const maxHp = Math.round(def.hp * hpScale);
    this.enemies.push({
      id: `boss_${id}`, label: def.label, color: def.color,
      x: this.size.w / 2, y: -def.size,
      hp: maxHp, maxHp, speed: def.speed, baseSpeed: def.speed,
      gold: def.gold, size: def.size,
      mythic: false, boss: true,
      phase: '', phaseT: 0, phaseCd: 4.0, phaseCount: 0, alpha: 1,
    });
    this.floater(`${def.label} appears!`, this.size.w / 2 - 80, 80, '#d4582c');
    if (!State.seen_boss_hints) State.seen_boss_hints = {};
    if (!State.seen_boss_hints[id] && def.hint) {
      State.seen_boss_hints[id] = true;
      this.banner = { text: def.hint, color: '#d4582c', t: 4.5, t0: 4.5 };
      persist();
    }
    Music.setIntensity(1);
  }

  _bossPhaseTick(e, dt) {
    if (e.phaseT > 0) {
      e.phaseT -= dt;
      if (e.phaseT <= 0) {
        e.phase = '';
        e.speed = e.baseSpeed;
        e.alpha = 1;
        e.phaseCd = 4.0;
      }
      return;
    }
    e.phaseCd -= dt;
    if (e.phaseCd > 0) return;
    e.phaseCount++;
    const id = e.id;
    if (id === 'boss_warchief') {
      e.phase = 'charge';
      e.phaseT = 1.0;
      e.speed = e.baseSpeed * 4;
      this.floater('CHARGE!', e.x, e.y, '#d4582c');
    } else if (id === 'boss_vyxhasis') {
      e.phase = 'fly';
      e.phaseT = 1.2;
      e.speed = e.baseSpeed * 0.5;
      e.alpha = 0.35;
      this.floater('AIRBORNE', e.x, e.y, '#5a8fb3');
    } else if (id === 'boss_aethyrnax') {
      // Aethyrnax alternates CHARGE and FLY.
      if (e.phaseCount % 2 === 1) {
        e.phase = 'charge';
        e.phaseT = 0.8;
        e.speed = e.baseSpeed * 5;
        this.floater('CHARGE!', e.x, e.y, '#d4582c');
      } else {
        e.phase = 'fly';
        e.phaseT = 1.4;
        e.speed = e.baseSpeed * 0.6;
        e.alpha = 0.4;
        this.floater('SOARING', e.x, e.y, '#5a8fb3');
      }
    } else if (id === 'boss_ourzhal') {
      // Ourzhal: charge → fly → summon, repeating.
      const cycle = e.phaseCount % 3;
      if (cycle === 1) {
        e.phase = 'charge';
        e.phaseT = 0.9;
        e.speed = e.baseSpeed * 5.5;
        this.floater('CHARGE!', e.x, e.y, '#d4582c');
      } else if (cycle === 2) {
        e.phase = 'fly';
        e.phaseT = 1.6;
        e.speed = e.baseSpeed * 0.5;
        e.alpha = 0.35;
        this.floater('SOARING', e.x, e.y, '#5a8fb3');
      } else {
        // Summon 3 skeletons in a triangle near boss
        for (let i = 0; i < 3; i++) {
          const a = (i / 3) * Math.PI * 2;
          this._spawnMinion(e.x + Math.cos(a) * 30, e.y + Math.sin(a) * 30);
        }
        this.floater('SUMMON', e.x, e.y, '#b380d9');
        e.phaseCd = 4.5;
      }
    }
  }

  // --- Hero acts ---
  synergy() {
    return synergyFor([this.primaryClass, this.secondaryClass, this.tertiaryClass]);
  }

  atkRate() {
    let r = 2.5 * this.classMul('atk') + this.atkBonus + bonusAtk() + (State.level_perks?.perm_atk || 0) * 0.1;
    r += Trinkets.atkBonus();
    if (hasGlory('mythic')) r += 0.2;
    const s = this.synergy();
    if (s?.atk) r += s.atk;
    return r;
  }

  heroDmg() {
    let d = 4 * this.classMul('dmg');
    d += Math.floor(this.wave / 2);
    d += (State.hero_level - 1) * 0.5;
    d += bonusDamage();
    d += (State.level_perks?.perm_dmg || 0);
    d *= this.rebirthBonus;
    d *= this.dmgMult;
    if (State.dragonslayer) d *= 1.10;
    if (this.primaryClass === 'bard') d *= 1.05;
    d *= 1 + Trinkets.dmgBonus();
    d *= emberDmgMult();
    if (hasGlory('novice')) d *= 1.05;
    const s = this.synergy();
    if (s?.dmg) d *= 1 + s.dmg;
    if (this.primaryClass === 'warrior') d += this.warriorRage * 0.5;
    let v = Math.max(1, Math.round(d));
    const permCrit = (State.level_perks?.perm_crit || 0) * 0.02;
    let critted = Math.random() < (this.critBonus + bonusCrit() + permCrit + Trinkets.critBonus());
    if (this.frenzy >= this.FRENZY_CAP) { critted = true; this.frenzy = 0; }
    if (critted) v *= 2;
    this.lastCritted = critted;
    return v;
  }

  heroRange() {
    return (220 * this.classMul('range')) + this.rangeBonus + bonusRange()
      + (State.level_perks?.perm_range || 0) * 10 + Trinkets.rangeBonus();
  }

  _heroAuto() {
    const r = this.heroRange();
    let best = null, bestD = r;
    for (const e of this.enemies) {
      if (e.dead) continue;
      const d = Math.hypot(e.x - this.heroPos.x, e.y - this.heroPos.y);
      if (d < bestD) { bestD = d; best = e; }
    }
    if (!best) return;
    const dmg = this.heroDmg();
    // Animate hero thrust toward the target.
    const dxh = best.x - this.heroPos.x;
    const dyh = best.y - this.heroPos.y;
    const dn = Math.hypot(dxh, dyh) || 1;
    this.heroThrust = { x: (dxh / dn) * 8, y: (dyh / dn) * 8, t: 0.15 };
    this.weaponAngle = Math.atan2(dyh, dxh);
    this._damageEnemy(best, dmg);
    this._spawnStrike(best.x, best.y);
    Sfx.hit();
    // Wizard signature: every 5th hit chains to a 2nd target.
    if (this.primaryClass === 'wizard') {
      this.wizardHitCount++;
      if (this.wizardHitCount % 5 === 0) {
        let second = null, secondD = this.heroRange();
        for (const e of this.enemies) {
          if (e.dead || e === best) continue;
          const d = Math.hypot(e.x - best.x, e.y - best.y);
          if (d < secondD) { secondD = d; second = e; }
        }
        if (second) {
          this._damageEnemy(second, dmg);
          this._spawnStrike(second.x, second.y);
        }
      }
    }
  }

  strike() {
    if (this.paused) return;
    if (this.curseDisables('steady_pace')) return;
    const r = this.heroRange() * 1.3;
    let best = null, bestD = r;
    for (const e of this.enemies) {
      if (e.dead) continue;
      const d = Math.hypot(e.x - this.heroPos.x, e.y - this.heroPos.y);
      if (d < bestD) { bestD = d; best = e; }
    }
    if (!best) return;
    this._damageEnemy(best, this.heroDmg() * 4);
    this._spawnStrike(best.x, best.y);
    this.shakeMag = 14;
    Sfx.strike();
  }

  skill() {
    if (this.paused || this.skillCd > 0) return;
    if (this.curseDisables('bare_hands')) return;
    const dmg = this.heroDmg();
    const k = this.primaryClass;
    const r = skillRank(k);                  // 0..3
    const skillMult = 1 + r * 0.4;           // +40% per rank
    if (k === 'wizard') {
      let best = null, bestHp = 0;
      for (const e of this.enemies) if (e.hp > bestHp) { bestHp = e.hp; best = e; }
      if (best) {
        this._damageEnemy(best, dmg * 12 * skillMult);
        this._spawnStrike(best.x, best.y);
      }
      this.floater(`FIREBALL${r ? ' R' + r : ''}`, this.heroPos.x - 30, this.heroPos.y - 30, '#5a8fb3');
    } else if (k === 'rogue') {
      this.heroHp = this.heroMaxHp;
      this.iframeT = 1.5 + r * 0.5;
      this.floater(`BLINK ${(1.5 + r * 0.5).toFixed(1)}s i-frames`, this.heroPos.x - 60, this.heroPos.y - 30, '#6fd07f');
    } else if (k === 'necromancer') {
      for (const e of this.enemies) this._damageEnemy(e, dmg * skillMult);
      this.floater(`REAP${r ? ' R' + r : ''}`, this.heroPos.x - 20, this.heroPos.y - 30, '#9966c8');
      this.shakeMag = 14;
    } else if (k === 'bard') {
      const bonus = 0.5 + r * 0.3;
      this.atkBonus += bonus;
      this.floater(`ANTHEM +${bonus.toFixed(1)} 8s`, this.heroPos.x - 80, this.heroPos.y - 30, '#d4a4cc');
      setTimeout(() => { this.atkBonus = Math.max(0, this.atkBonus - bonus); }, 8000);
    } else {
      for (const e of this.enemies) this._damageEnemy(e, dmg * 2 * skillMult);
      this.floater(`CLEAVE${r ? ' R' + r : ''}`, this.heroPos.x - 30, this.heroPos.y - 30, '#d9892e');
      this.shakeMag = 20;
    }
    this.skillCd = 6;
    Sfx.crit();
  }

  _damageEnemy(e, amount) {
    if (e.boss && e.phase === 'fly') {
      this.floater('MISS', e.x, e.y, '#a39a85');
      return;
    }
    e.hp -= amount;
    e.hitFlash = 0.12;
    // Vampiric lifesteal — heal a fraction of damage dealt.
    if (this.lifesteal) {
      const heal = Math.max(1, Math.round(amount * this.lifesteal));
      this.heroHp = Math.min(this.heroMaxHp, this.heroHp + heal);
    }
    // DPS sampling: keep the last 2s of damage events.
    const tnow = performance.now();
    this.dpsSamples.push({ t: tnow, a: amount });
    while (this.dpsSamples.length && this.dpsSamples[0].t < tnow - 2000) this.dpsSamples.shift();
    const dps = this.dpsSamples.reduce((s, x) => s + x.a, 0) / 2;
    if (dps > this.peakDps) this.peakDps = dps;
    const crit = this.lastCritted; this.lastCritted = false;
    const txt = crit ? `-${Math.round(amount)}!` : `-${Math.round(amount)}`;
    const clr = crit ? '#e8d2a0' : (amount < 10 ? '#c8a030' : '#d4582c');
    this.floater(txt, e.x, e.y, clr, crit);
    if (e.hp <= 0) this._killEnemy(e, true);
  }

  _killEnemy(e, byPlayer) {
    if (e.dead) return;
    e.dead = true;
    // Death particles: 6-12 colored shards explode out from the enemy.
    const n = e.boss ? 24 : (e.mythic ? 16 : 8);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const s = 90 + Math.random() * 140;
      this.fx.push({
        x: e.x, y: e.y,
        vx: Math.cos(a) * s, vy: Math.sin(a) * s,
        life: 0.4 + Math.random() * 0.3,
        color: e.color, size: 2 + Math.random() * 3,
        fade: true,
      });
    }
    if (e.explodes) this._detonate(e.x, e.y, 60, Math.max(2, Math.round(this.heroDmg() * 0.5)));
    if (byPlayer) {
      const permGold = 1 + (State.level_perks?.perm_gold || 0) * 0.05;
      const s = this.synergy();
      const synGold = s?.gold ? 1 + s.gold : 1;
      const chal = this.challengeBonus();
      const trkGold = 1 + Trinkets.goldBonus();
      const gloryGold = hasGlory('rising') ? 1.05 : 1;
      const gold = Math.max(1, Math.round(e.gold * this.rebirthBonus * this.goldMult * this.comboMult() * permGold * synGold * chal * trkGold * emberGoldMult() * gloryGold));
      // Spawn a magnet coin sprite for the kill.
      const aLaunch = -Math.PI / 2 + (Math.random() - 0.5) * 0.8;
      this.coins.push({
        x: e.x, y: e.y,
        vx: Math.cos(aLaunch) * 120, vy: Math.sin(aLaunch) * 120,
        life: 3.0, magnetT: 0.3,
      });
      // Coin sparkle on the kill spot — a few gold flecks fanning out.
      for (let i = 0; i < 4; i++) {
        const a = Math.random() * Math.PI * 2;
        const s = 60 + Math.random() * 80;
        this.fx.push({
          x: e.x, y: e.y,
          vx: Math.cos(a) * s, vy: Math.sin(a) * s,
          life: 0.4, color: '#f5d96e', size: 2 + Math.random() * 2,
          fade: true,
        });
      }
      // For big drops (≥10 gold), float a "+Ng" with upward drift.
      if (gold >= 10) {
        this.floater(`+${gold}g`, e.x, e.y - 8, '#f5d96e');
      }
      State.gold += gold;
      this.combo++;
      this.comboDecay = 1.5;
      if (this.combo > this.comboPeak) this.comboPeak = this.combo;
      this._questTick('combo', this.combo);
      if (this.primaryClass === 'warrior') this.warriorRage = Math.min(20, this.warriorRage + 1);
      if (this.primaryClass === 'necromancer') this.heroHp = Math.min(this.heroMaxHp, this.heroHp + 2);
    }
    State.lifetime_kills++;
    this.killsThisRun++;
    this.killsByType[e.id] = (this.killsByType[e.id] || 0) + 1;
    if (byPlayer) {
      this._questTick('kills', 1);
      if (e.mythic) this._questTick('mythics', 1);
      if (e.boss) this._questTick('bosses', 1);
    }
    const ups = grantXp(1);
    if (ups > 0) {
      this.banner = { text: `LEVEL ${State.hero_level}!`, color: '#d4a24c', t: 1.6, t0: 1.6 };
      this.floater(`LEVEL ${State.hero_level}`, this.heroPos.x, this.heroPos.y - 20, '#d4a24c');
      this.flash = Math.max(this.flash, 0.4);
      this.heroMaxHp = this.maxHp();
      this.heroHp = Math.min(this.heroMaxHp, this.heroHp + 10);
      // Every 5th level → perk pick.
      if (State.hero_level % 5 === 0 && this.onLevelPick) {
        this.onLevelPick(State.hero_level);
      }
    }
    const fired = checkKillMilestones();
    for (const m of fired) {
      this._showBanner(m.label);
    }
    // Bestiary tally + first-seen stamp.
    const bid = e.id;
    if (!State.bestiary[bid]) State.bestiary[bid] = { first_seen: Date.now(), kills: 0 };
    State.bestiary[bid].kills++;
    if (e.mythic) this._dropPowerup(e.x, e.y);
    if (e.boss) {
      Sfx.boss();
      Music.setIntensity(0);
      this.flash = 0.7;
      this.setTimeScale(0.3, 400);
      const ember = Math.round((1 + Math.floor(this.wave / 10)) * this.challengeBonus());
      grantEmbers(ember);
      this.runEmbersEarned += ember;
      State.bosses_felled++;
      this._bossesThisRun = (this._bossesThisRun || 0) + 1;
      tickWeekly('bosses', this._bossesThisRun);
      tickWeekly('embers', 0);
      this.floater(`+${ember} Ember`, e.x, e.y, '#d4582c');
      this.shakeMag = 30;
      this._burst(e.x, e.y);
      // Live achievement scan on boss kill.
      const firedB = scanAndClaimVerbose();
      for (const r of firedB) {
        this.banner = { text: `✦ ${r.label}  +${r.reward}🜂`, color: '#d4a24c', t: 2.8, t0: 2.8 };
        this.runEmbersEarned += r.reward;
        this.log(`Achievement: ${r.label}`);
      }
      // Trinket drop?
      const drop = Trinkets.tryDrop(e.id);
      if (drop) {
        this.floater(`+ ${drop.label}`, this.size.w / 2 - 80, 130, '#d4a24c');
        this.log(`Trinket: ${drop.label}`);
      }
      // Dragonslayer honor: all 3 named bosses ever felled.
      const bossKey = e.id.replace('boss_', '');
      if (!State.defeated_dragons.includes(bossKey)) State.defeated_dragons.push(bossKey);
      const have = new Set(State.defeated_dragons);
      if (!State.dragonslayer
          && have.has('warchief') && have.has('vyxhasis') && have.has('aethyrnax')) {
        State.dragonslayer = true;
        grantEmbers(15);
        this.runEmbersEarned += 15;
        this.floater('DRAGONSLAYER — +10% perm dmg', this.size.w / 2 - 110, 80, '#e8d2a0');
        this.log('DRAGONSLAYER honor earned');
      }
      persist();
      if (this.onBossBoon) this.onBossBoon();
    } else {
      this.waveKillsProgress++;
      if (this.waveKillsProgress >= this.waveKillsTarget) {
        Sfx.levelup();
        this._nextWave();
      }
    }
  }

  isTempest() { return this.wave > 0 && this.wave % 13 === 0; }

  hasCompanion() { return !this.hardcore && (State.bosses_felled || 0) >= 1; }

  _companionPos() {
    const r = 60;
    return {
      x: this.heroPos.x + Math.cos(this.companionOrbitT) * r,
      y: this.heroPos.y + Math.sin(this.companionOrbitT) * r,
    };
  }

  _tickCompanion(dt) {
    this.companionOrbitT += dt * 1.5;
    this.companionAtkT -= dt;
    if (this.companionAtkT > 0) return;
    const cp = this._companionPos();
    let best = null, bestD = 180;
    for (const e of this.enemies) {
      if (e.dead) continue;
      const d = Math.hypot(e.x - cp.x, e.y - cp.y);
      if (d < bestD) { bestD = d; best = e; }
    }
    if (!best) return;
    const dmg = Math.max(1, Math.round(this.heroDmg() * 0.5));
    this._damageEnemy(best, dmg);
    this._spawnStrike(best.x, best.y);
    this.companionAtkT = 1.0;
  }

  comboMult() {
    if (this.combo <= 0) return 1;
    // Saturating: at combo=30 ≈ 1.5x, asymptote 2.0x.
    return 1 + this.combo / (this.combo + 30);
  }

  _nextWave() {
    // Perfect-clear bonus on the wave we just finished.
    if (this.untouchedSinceWave && this.wave > 1) {
      const bonus = 5 + this.wave * 10;
      State.gold += bonus;
      this.floater(`PERFECT +${bonus}g`, this.heroPos.x, this.heroPos.y - 20, '#d4a24c');
      this.log(`Perfect clear: +${bonus}g`);
    }
    this.untouchedSinceWave = true;
    this.wave++;
    // Speedrun: wave 20 reached → record time, end run.
    if (this.speedrun && !this.speedrunDone && this.wave >= 20) {
      this.speedrunDone = true;
      const ms = performance.now() - this.runStartT;
      if (State.speedrun_best_ms === 0 || ms < State.speedrun_best_ms) {
        State.speedrun_best_ms = Math.round(ms);
        this.floater('NEW BEST!', this.size.w / 2 - 40, 80, '#d4a24c');
      }
      persist();
      if (this.onSpeedrunFinish) this.onSpeedrunFinish(Math.round(ms));
    }
    this.warriorRage = 0;
    this.waveKillsProgress = 0;
    this.waveKillsTarget = Math.floor(8 + this.wave * 1.5);
    if (this.wave > State.best_wave) State.best_wave = this.wave;
    if (this.hardcore && this.wave > (State.hardcore_best_wave || 0)) State.hardcore_best_wave = this.wave;
    this._questTick('wave', this.wave);
    // Live achievement scan — banner each one as it fires.
    const fired = scanAndClaimVerbose();
    for (const r of fired) {
      this.banner = { text: `✦ ${r.label}  +${r.reward}🜂`, color: '#d4a24c', t: 2.8, t0: 2.8 };
      this.runEmbersEarned += r.reward;
      this.log(`Achievement: ${r.label}`);
    }
    tickWeekly('wave', this.wave);
    tickWeekly('kills', this.killsThisRun);
    this.heroHp = Math.min(this.heroMaxHp, this.heroHp + Math.floor(this.heroMaxHp / 4));
    const bonus = Math.round((5 + this.wave * this.wave) * this.waveBonusMult * (1 + Trinkets.waveBonus()));
    State.gold += bonus;
    this.floater(`+${bonus}g`, this.heroPos.x, this.heroPos.y, '#d4a24c');
    this.log(`Wave ${this.wave} cleared (+${bonus}g)`);
    this.banner = { text: `WAVE ${this.wave}  ·  +${bonus}g`, color: '#d4a24c', t: 1.4, t0: 1.4 };
    if (this.isTempest()) {
      this.floater('TEMPEST — 2× spawns, ½ HP', this.size.w / 2 - 100, 60, '#d4582c');
      this.log('TEMPEST wave incoming');
    }
    if (this.wave === 10 && !this.secondaryClass && this.onSlotUnlock) this.onSlotUnlock('secondary');
    if (this.wave === 25 && !this.tertiaryClass && this.onSlotUnlock) this.onSlotUnlock('tertiary');
    if (this.wave % 10 === 0) this._spawnBoss();
    if (this.wave % 15 === 0) this.spawnChest();
    if (this.wave === 30 && State.challenge_active && !this._claimedCurseToday) {
      this._claimedCurseToday = true;
      State.curses_cleared = (State.curses_cleared || 0) + 1;
      grantEmbers(5);
      this.runEmbersEarned += 5;
      this.floater('CURSE BROKEN — +5 Ember', this.size.w / 2 - 100, 60, '#d4582c');
      persist();
    }
    if (!this.hardcore && this.wave % 5 === 0 && this.onPerkRequest) {
      this.onPerkRequest();
    } else if (!this.hardcore && this.wave % 7 === 0 && this.onMerchant && !this.curseDisables('spendthrift')) {
      this.onMerchant();
    }
    persist();
  }

  _heroTakeDamage(amount) {
    if (this.deadScreenOpen) return;
    if (this.iframeT > 0) {
      this.floater('IFRAME', this.heroPos.x, this.heroPos.y, '#6fd07f');
      return;
    }
    if (this.primaryClass === 'rogue' && Math.random() < 0.05) {
      this.floater('EVADE', this.heroPos.x, this.heroPos.y, '#d4a24c');
      return;
    }
    this.heroHp = Math.max(0, this.heroHp - amount);
    this.untouchedSinceWave = false;
    this.frenzy = Math.min(this.FRENZY_CAP, this.frenzy + 1);
    Sfx.hurt();
    this.shakeMag = Math.min(20, 6 + amount * 0.5);
    if (this.heroHp <= 0) this._onDie();
  }

  _onDie() {
    // Second Wind: spend a revive if any left.
    if (this.revivesUsed < maxRevives()) {
      this.revivesUsed++;
      this.heroHp = Math.floor(this.heroMaxHp / 2);
      this.enemies.length = 0;
      this.iframeT = 2.0;
      this.shakeMag = 20;
      this.floater('SECOND WIND', this.heroPos.x - 60, this.heroPos.y, '#d4a24c');
      this.log('Revived');
      return;
    }
    this.deadScreenOpen = true;
    this.paused = true;
    const lost = Math.floor(State.gold / 2);
    State.gold -= lost;
    recordRun({
      wave: this.wave, kills: this.killsThisRun,
      combo: this.comboPeak, embers: this.runEmbersEarned,
      class: this.primaryClass, when: Date.now(),
    });
    if (this.dailySeed) recordDailyRun(this.wave);
    persist();
    if (this.onDeath) this.onDeath({
      wave: this.wave, kills: this.killsThisRun,
      combo: this.comboPeak, embers: this.runEmbersEarned,
      gold_lost: lost,
      kills_by_type: this.killsByType,
      peak_dps: Math.round(this.peakDps),
      duration_s: Math.round((performance.now() - this.runStartT) / 1000),
      primary: this.primaryClass, secondary: this.secondaryClass, tertiary: this.tertiaryClass,
      pre_best: this.preRunBestWave,
    });
  }

  _detonate(x, y, radius, dmg) {
    // Visual: short orange burst
    for (let i = 0; i < 12; i++) {
      const a = (Math.PI * 2 * i) / 12;
      this.fx.push({
        x, y, vx: Math.cos(a) * 200, vy: Math.sin(a) * 200,
        life: 0.35, color: '#f08533', size: 8, fade: true,
      });
    }
    for (const o of this.enemies) {
      if (o.dead || o === undefined) continue;
      const dx = o.x - x, dy = o.y - y;
      if (dx * dx + dy * dy <= radius * radius) {
        this._damageEnemy(o, dmg);
      }
    }
    this.shakeMag = Math.max(this.shakeMag, 10);
  }

  _spawnMinion(x, y) {
    const def = ENEMY_TYPES.skeleton;
    const hpScale = 1 + (this.wave - 1) * 0.18;
    const maxHp = Math.round(def.hp * hpScale);
    this.enemies.push({
      id: 'skeleton', label: def.label, color: def.color,
      x, y, hp: maxHp, maxHp,
      speed: def.speed + this.wave * 1.5,
      gold: 0,  // minions don't pay
      size: def.size, mythic: false, boss: false,
      explodes: false, ranged: false, heals: false, summons: false,
    });
  }

  _dropPowerup(x, y) {
    const pool = ['heal', 'gold', 'haste'];
    const kind = pool[Math.floor(Math.random() * pool.length)];
    this.powerups.push({ x, y, kind, life: 5.0 });
  }

  _applyPowerup(kind) {
    if (kind === 'heal') {
      const amt = Math.floor(this.heroMaxHp / 4);
      this.heroHp = Math.min(this.heroMaxHp, this.heroHp + amt);
      this.floater(`+${amt} HP`, this.heroPos.x, this.heroPos.y, '#6fa060');
    } else if (kind === 'gold') {
      State.gold += 50;
      this.floater(`+50g`, this.heroPos.x, this.heroPos.y, '#d4a24c');
    } else {
      this.atkBonus += 1.0;
      setTimeout(() => { this.atkBonus = Math.max(0, this.atkBonus - 1.0); }, 8000);
      this.floater(`+1 atk/s 8s`, this.heroPos.x, this.heroPos.y, '#d4582c');
    }
  }

  _zoneWeather() {
    const z = zoneForWave(this.wave).name;
    return ({
      'Greenmarch':  { color: 'rgba(140, 215, 140, 0.4)', density: 14 },
      'Ashen Vale':  { color: 'rgba(170, 140, 110, 0.5)', density: 22 },
      'Frostwatch':  { color: 'rgba(210, 230, 255, 0.6)', density: 28 },
      'Emberlands':  { color: 'rgba(255, 140, 70, 0.5)',  density: 24 },
      'The Void':    { color: 'rgba(160, 120, 220, 0.4)', density: 18 },
      'Forgehold':   { color: 'rgba(255, 165, 80, 0.55)', density: 28 },
      'Sunfire':     { color: 'rgba(255, 215, 100, 0.55)',density: 30 },
    })[z] || { color: 'rgba(255,255,255,0.3)', density: 12 };
  }

  _tickWeather(dt) {
    const cfg = this._zoneWeather();
    // Maintain population.
    while (this.weather.length < cfg.density) {
      this.weather.push({
        x: Math.random() * this.size.w,
        y: -Math.random() * 40,
        vy: 14 + Math.random() * 30,
        size: 1 + Math.random() * 2,
      });
    }
    for (const p of this.weather) {
      p.y += p.vy * dt;
      if (p.y > this.size.h + 8) { p.y = -10; p.x = Math.random() * this.size.w; }
    }
    this._weatherColor = cfg.color;
  }

  spawnChest() {
    this.chest = {
      x: this.size.w * 0.5 + 80,
      y: this.size.h * 0.45,
      t: 3.0,
    };
  }

  _tickChest(dt) {
    if (!this.chest) return;
    this.chest.t -= dt;
    if (this.chest.t <= 0) {
      const roll = Math.random();
      if (roll < 0.6) {
        const g = 150 + this.wave * 10;
        State.gold += g;
        this.floater(`+${g} gold`, this.chest.x, this.chest.y, '#d4a24c');
        this.log(`Chest: +${g} gold`);
      } else if (roll < 0.9) {
        grantEmbers(3);
        this.runEmbersEarned += 3;
        this.floater('+3 Ember', this.chest.x, this.chest.y, '#d4582c');
        this.log('Chest: +3 ember');
      } else {
        this.heroHp = this.heroMaxHp;
        this.floater('FULL HEAL', this.chest.x, this.chest.y, '#6fa060');
        this.log('Chest: full heal');
      }
      this.shakeMag = 14;
      this.chest = null;
      this._questTick('chests', 1);
      persist();
    }
  }

  _questTick(metric, value) {
    const fired = this.quests.tick(metric, value);
    for (const q of fired) {
      this.banner = { text: `Quest: ${q.label}  +${q.gold}g +${q.ember}🜂`, color: '#d4a24c', t: 2.6, t0: 2.6 };
      this.runEmbersEarned += q.ember;
      this.log(`Quest complete: ${q.label}`);
    }
  }

  // --- FX helpers ---
  _spawnStrike(x, y) {
    const c = colorForClass(this.primaryClass, '#f5e8a8');
    // Central flash
    this.fx.push({ x, y, vx: 0, vy: 0, life: 0.18, color: c, size: 14, fade: true });
    // 4 short radial sparks
    for (let i = 0; i < 4; i++) {
      const a = Math.random() * Math.PI * 2;
      const s = 80 + Math.random() * 60;
      this.fx.push({
        x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s,
        life: 0.22, color: c, size: 2.5 + Math.random() * 2,
        fade: true,
      });
    }
  }
  _burst(x, y) {
    for (let i = 0; i < 8; i++) {
      const a = (Math.PI * 2 * i) / 8;
      this.fx.push({
        x, y, vx: Math.cos(a) * 240, vy: Math.sin(a) * 240,
        life: 0.45, color: '#d4a24c', size: 10, fade: true,
      });
    }
  }
  floater(text, x, y, color = '#e8e2d2', big = false) {
    this.floaters.push({ text, x, y, color, life: big ? 0.9 : 0.6, life0: big ? 0.9 : 0.6, big: !!big });
  }
  log(s) {
    this.combatLog.push(s);
    while (this.combatLog.length > 4) this.combatLog.shift();
  }
  _showBanner(label) {
    this.floater(`✦ ${label} ✦`, this.size.w / 2 - 100, 60, '#d4a24c');
    this.log(label);
  }

  // --- Render ---
  _render() {
    const ctx = this.ctx;
    let { w, h } = this.size;
    ctx.save();
    const sx = (Math.random() - 0.5) * this.shakeMag;
    const sy = (Math.random() - 0.5) * this.shakeMag;
    ctx.translate(sx, sy);

    // bg + radial vignette for depth
    const bgGrad = ctx.createRadialGradient(w / 2, h / 2, 60, w / 2, h / 2, Math.max(w, h));
    bgGrad.addColorStop(0, '#15131c');
    bgGrad.addColorStop(1, '#06060a');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, w, h);
    // floor — tinted by zone
    ctx.fillStyle = zoneForWave(this.wave).floor;
    ctx.fillRect(0, 96, w, h - 200);
    // Subtle grid that scrolls along the hero's facing direction.
    ctx.strokeStyle = 'rgba(255,255,255,0.04)';
    ctx.lineWidth = 1;
    const off = (performance.now() / 60) % 40;
    for (let x = -off; x < w; x += 40) {
      ctx.beginPath();
      ctx.moveTo(x, 96);
      ctx.lineTo(x, h - 104);
      ctx.stroke();
    }
    for (let y = 96; y < h - 104; y += 40) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
    // Parallax bg dots — slow-drifting, deep behind everything.
    if (this.bgDots.length === 0) {
      for (let i = 0; i < 60; i++) {
        this.bgDots.push({
          x: Math.random() * w, y: Math.random() * h,
          vx: -3 - Math.random() * 6, vy: -1 - Math.random() * 2,
          size: 0.5 + Math.random() * 1.5,
          alpha: 0.05 + Math.random() * 0.12,
        });
      }
    }
    for (const d of this.bgDots) {
      d.x += d.vx * 0.016;  // ~60fps
      d.y += d.vy * 0.016;
      if (d.x < -4) d.x = w + 4;
      if (d.y < -4) d.y = h + 4;
      ctx.fillStyle = `rgba(232,210,160,${d.alpha})`;
      ctx.fillRect(d.x, d.y, d.size, d.size);
    }
    // Per-zone floor decor — fixed-position glyphs sized by viewport.
    this._drawZoneDecor(ctx, w, h);
    // weather
    if (this._weatherColor) {
      ctx.fillStyle = this._weatherColor;
      for (const p of this.weather) ctx.fillRect(p.x, p.y, p.size, p.size + 1);
    }
    // range ring (faint)
    ctx.strokeStyle = 'rgba(212, 162, 76, 0.12)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(this.heroPos.x, this.heroPos.y, this.heroRange(), 0, Math.PI * 2);
    ctx.stroke();

    // enemies
    const now = performance.now();
    for (const e of this.enemies) {
      ctx.globalAlpha = (e.alpha ?? 1);
      // Per-enemy idle bob (cheap deterministic phase off id+x+y)
      const phase = (e.x + e.y) * 0.01;
      const bobE = Math.sin(now / 280 + phase) * 1.5;
      const r = e.size / 2;
      // Shadow ellipse
      ctx.fillStyle = 'rgba(0,0,0,0.25)';
      ctx.beginPath();
      ctx.ellipse(e.x, e.y + r + 2, r * 0.9, r * 0.4, 0, 0, Math.PI * 2);
      ctx.fill();
      // Apply bob to draw-position only.
      e._drawY = e.y + bobE;
      const ey = e._drawY ?? e.y;
      // Radial gradient body for depth.
      const grad = ctx.createRadialGradient(e.x - r * 0.3, ey - r * 0.3, 1, e.x, ey, r);
      grad.addColorStop(0, _lighten(e.color, 0.4));
      grad.addColorStop(1, e.color);
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(e.x, ey, r, 0, Math.PI * 2);
      ctx.fill();
      if (e.hitFlash > 0) {
        ctx.fillStyle = `rgba(255,255,255,${(e.hitFlash * 6).toFixed(2)})`;
        ctx.beginPath();
        ctx.arc(e.x, ey, r, 0, Math.PI * 2);
        ctx.fill();
      }
      // Boss outer glow rim.
      if (e.boss) {
        const ringR = r + 6 + 2 * Math.sin(now / 200);
        const rg = ctx.createRadialGradient(e.x, ey, r, e.x, ey, ringR + 4);
        rg.addColorStop(0, 'rgba(212,162,76,0.6)');
        rg.addColorStop(1, 'rgba(212,162,76,0.0)');
        ctx.fillStyle = rg;
        ctx.beginPath();
        ctx.arc(e.x, ey, ringR + 4, 0, Math.PI * 2);
        ctx.fill();
      }
      // Spawn-in pulse — bright ring expanding outward as the spawn settles.
      if (e.spawnFade > 0) {
        const sR = r + (1 - e.spawnFade) * 30;
        const sA = e.spawnFade * 0.7;
        ctx.strokeStyle = `rgba(255,255,255,${sA.toFixed(2)})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(e.x, ey, sR, 0, Math.PI * 2);
        ctx.stroke();
      }
      // Sapper warning aura — bright orange that intensifies as HP drops.
      if (e.explodes && e.hp < e.maxHp) {
        const danger = 1 - (e.hp / e.maxHp);
        const pulseA = 0.25 + 0.5 * danger * (0.7 + 0.3 * Math.sin(now / 120));
        const rg = ctx.createRadialGradient(e.x, ey, r, e.x, ey, r + 30 * danger);
        rg.addColorStop(0, `rgba(240,133,51,${pulseA.toFixed(2)})`);
        rg.addColorStop(1, 'rgba(240,133,51,0)');
        ctx.fillStyle = rg;
        ctx.beginPath();
        ctx.arc(e.x, ey, r + 30 * danger, 0, Math.PI * 2);
        ctx.fill();
      }
      if (e.mythic) {
        const t = (performance.now() / 200) % (Math.PI * 2);
        const a = 0.6 + 0.3 * Math.sin(t);
        ctx.strokeStyle = `rgba(232,210,160,${a.toFixed(2)})`;
        ctx.lineWidth = 3.5;
        ctx.beginPath();
        ctx.arc(e.x, ey, r, 0, Math.PI * 2);
        ctx.stroke();
      } else if (e.boss) {
        ctx.strokeStyle = '#d4a24c';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(e.x, ey, r, 0, Math.PI * 2);
        ctx.stroke();
      }
      // hp bar
      const barW = e.size;
      const frac = Math.max(0, e.hp / e.maxHp);
      ctx.fillStyle = 'rgba(0,0,0,0.5)';
      ctx.fillRect(e.x - barW / 2, ey - r - 8, barW, 3);
      ctx.fillStyle = '#d95940';
      ctx.fillRect(e.x - barW / 2, ey - r - 8, barW * frac, 3);
      ctx.globalAlpha = 1;
    }

    // arrows + soft trail + glow
    for (const a of this.arrows) {
      // Outer glow
      const glow = ctx.createRadialGradient(a.x, a.y, 0, a.x, a.y, 10);
      glow.addColorStop(0, 'rgba(245, 232, 168, 0.5)');
      glow.addColorStop(1, 'rgba(245, 232, 168, 0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(a.x, a.y, 10, 0, Math.PI * 2);
      ctx.fill();
      ctx.lineWidth = 4;
      ctx.strokeStyle = 'rgba(245, 232, 168, 0.30)';
      ctx.beginPath();
      ctx.moveTo(a.x - a.vx * 0.10, a.y - a.vy * 0.10);
      ctx.lineTo(a.x - a.vx * 0.04, a.y - a.vy * 0.04);
      ctx.stroke();
      ctx.lineWidth = 3;
      ctx.strokeStyle = '#f5e8a8';
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(a.x - a.vx * 0.04, a.y - a.vy * 0.04);
      ctx.stroke();
    }

    // coins
    for (const c of this.coins) {
      ctx.fillStyle = '#f5d96e';
      ctx.beginPath();
      ctx.arc(c.x, c.y, 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#b08230';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    // power-ups
    for (const p of this.powerups) {
      const c = p.kind === 'heal' ? '#6fa060' : p.kind === 'gold' ? '#d4a24c' : '#d4582c';
      // Pulsing radial gradient body
      const pp = 1 + 0.15 * Math.sin(performance.now() / 150);
      const radius = 10 * pp;
      const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, radius);
      g.addColorStop(0, _lighten(c, 0.5));
      g.addColorStop(1, c);
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 2;
      ctx.stroke();
      // Glyph
      ctx.fillStyle = '#1a1208';
      ctx.font = 'bold 12px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      const glyph = p.kind === 'heal' ? '+' : p.kind === 'gold' ? '$' : '!';
      ctx.fillText(glyph, p.x, p.y);
    }

    // fx
    for (const f of this.fx) {
      const alpha = Math.max(0, f.life / 0.45);
      ctx.globalAlpha = alpha;
      ctx.fillStyle = f.color;
      ctx.beginPath();
      ctx.arc(f.x, f.y, f.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    // companion
    if (this.hasCompanion()) {
      const cp = this._companionPos();
      const cc = CLASS_COLOR[this.secondaryClass || this.primaryClass] || '#d4a24c';
      ctx.fillStyle = cc;
      ctx.beginPath();
      ctx.arc(cp.x, cp.y, 10, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // hero — subtle idle bob + breathing pulse
    const bob = Math.sin(performance.now() / 350) * 2;
    const pulse = 1 + 0.06 * Math.sin(performance.now() / 700);
    const lvlGrow = 1 + Math.min(0.4, (State.hero_level - 1) * 0.012);
    const hr = 22 * pulse * lvlGrow;
    const hx = this.heroPos.x + this.heroThrust.x;
    const hy = this.heroPos.y + bob + this.heroThrust.y;
    // Hero shadow (soft ellipse below)
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.beginPath();
    ctx.ellipse(hx, hy + hr + 4, hr * 0.95, hr * 0.42, 0, 0, Math.PI * 2);
    ctx.fill();
    // Hero aura — soft outer ring that grows slightly with wave depth.
    const auraR = hr + 6 + Math.min(20, this.wave * 0.3);
    const auraA = 0.18 + 0.08 * Math.sin(performance.now() / 400);
    const auraColor = colorForClass(this.primaryClass, '#d4a24c');
    const auraGrad = ctx.createRadialGradient(hx, hy, hr * 0.8, hx, hy, auraR);
    auraGrad.addColorStop(0, auraColor + Math.round(255 * auraA).toString(16).padStart(2, '0'));
    auraGrad.addColorStop(1, auraColor + '00');
    ctx.fillStyle = auraGrad;
    ctx.beginPath();
    ctx.arc(hx, hy, auraR, 0, Math.PI * 2);
    ctx.fill();

    // Combo halo — radial gradient that grows with stack count.
    if (this.combo > 1) {
      const haloR = hr + 8 + Math.min(this.combo, 30) * 1.5;
      const cclr = colorForClass(this.primaryClass, CLASS_COLOR[this.primaryClass] || '#d4a24c');
      const grad = ctx.createRadialGradient(hx, hy, hr, hx, hy, haloR);
      grad.addColorStop(0, cclr + '88');
      grad.addColorStop(1, cclr + '00');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(hx, hy, haloR, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = colorForClass(this.primaryClass, CLASS_COLOR[this.primaryClass] || '#d4a24c');
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 2;
    this._drawHeroShape(hx, hy, hr);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#1a1208';
    ctx.font = 'bold 16px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(this.primaryClass[0].toUpperCase(), hx, hy);
    // Class weapon — short line / shape jutting out toward last target.
    this._drawWeapon(hx, hy, hr);
    // Wave-progress ring: fills clockwise as kills approach target.
    const frac = Math.max(0, Math.min(1, this.waveKillsProgress / Math.max(1, this.waveKillsTarget)));
    if (frac > 0) {
      const rR = hr + 6;
      ctx.strokeStyle = 'rgba(212, 162, 76, 0.85)';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(hx, hy, rR, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
      ctx.stroke();
    }

    // chest — bobs, glows, emits gold sparkles
    if (this.chest) {
      const bob = Math.sin(performance.now() / 200) * 3;
      const ch = this.chest;
      // Gradient glow under the chest
      const glow = ctx.createRadialGradient(ch.x, ch.y + bob, 6, ch.x, ch.y + bob, 38);
      glow.addColorStop(0, 'rgba(245, 217, 110, 0.4)');
      glow.addColorStop(1, 'rgba(245, 217, 110, 0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(ch.x, ch.y + bob, 38, 0, Math.PI * 2);
      ctx.fill();
      // Random sparkle
      if (Math.random() < 0.6) {
        this.fx.push({
          x: ch.x + (Math.random() - 0.5) * 22,
          y: ch.y + bob - 8,
          vx: (Math.random() - 0.5) * 16,
          vy: -20 - Math.random() * 20,
          life: 0.5, color: '#f5d96e', size: 2,
          fade: true,
        });
      }
      // Chest body
      ctx.fillStyle = '#8c6433';
      ctx.fillRect(ch.x - 16, ch.y - 14 + bob, 32, 22);
      ctx.fillStyle = '#5a4220';
      ctx.fillRect(ch.x - 16, ch.y - 14 + bob, 32, 6); // lid hint
      ctx.strokeStyle = '#d4a24c';
      ctx.lineWidth = 2;
      ctx.strokeRect(ch.x - 16, ch.y - 14 + bob, 32, 22);
      // Lock
      ctx.fillStyle = '#d4a24c';
      ctx.fillRect(ch.x - 2, ch.y - 6 + bob, 4, 4);
      ctx.fillStyle = '#d4a24c';
      ctx.font = 'bold 12px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText(ch.t.toFixed(1), ch.x, ch.y - 22 + bob);
    }

    // boss telegraph + spawn reticle at the centre
    if (this.bossWarn) {
      const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 100);
      ctx.fillStyle = `rgba(216, 50, 50, ${pulse})`;
      ctx.font = 'bold 22px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText(`INCOMING: ${this.bossWarn.label}  ${this.bossWarn.t.toFixed(1)}s`,
        this.size.w / 2, 110);
      // Reticle at the spawn point (top center of arena).
      const rx = this.size.w / 2;
      const ry = 140;
      const rad = 36 + 8 * Math.sin(performance.now() / 80);
      ctx.strokeStyle = `rgba(216, 50, 50, ${pulse})`;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(rx, ry, rad, 0, Math.PI * 2);
      ctx.stroke();
      // Cross-hairs
      ctx.beginPath();
      ctx.moveTo(rx - rad - 10, ry); ctx.lineTo(rx - rad + 6, ry);
      ctx.moveTo(rx + rad + 10, ry); ctx.lineTo(rx + rad - 6, ry);
      ctx.moveTo(rx, ry - rad - 10); ctx.lineTo(rx, ry - rad + 6);
      ctx.moveTo(rx, ry + rad + 10); ctx.lineTo(rx, ry + rad - 6);
      ctx.stroke();
    }

    // Mini-radar at bottom-right showing all enemies relative to hero.
    if (this.enemies.length > 0) {
      const mr_size = 80;
      const mrx = w - mr_size - 16;
      const mry = h - mr_size - 96;  // above the bottom button bar
      ctx.fillStyle = 'rgba(11, 10, 15, 0.55)';
      ctx.fillRect(mrx, mry, mr_size, mr_size);
      ctx.strokeStyle = 'rgba(212, 162, 76, 0.35)';
      ctx.lineWidth = 1;
      ctx.strokeRect(mrx, mry, mr_size, mr_size);
      // Hero dot
      ctx.fillStyle = colorForClass(this.primaryClass, '#d4a24c');
      ctx.beginPath();
      ctx.arc(mrx + mr_size / 2, mry + mr_size / 2, 3, 0, Math.PI * 2);
      ctx.fill();
      // Enemy dots — sample each within a 600px radius into the radar.
      const scale = mr_size / 1200;
      for (const e of this.enemies) {
        if (e.dead) continue;
        const dx = e.x - this.heroPos.x;
        const dy = e.y - this.heroPos.y;
        const px = mrx + mr_size / 2 + dx * scale;
        const py = mry + mr_size / 2 + dy * scale;
        if (px < mrx || px > mrx + mr_size || py < mry || py > mry + mr_size) continue;
        ctx.fillStyle = e.boss ? '#d4a24c' : (e.mythic ? '#e8d2a0' : e.color);
        const ds = e.boss ? 3 : (e.mythic ? 2.5 : 1.5);
        ctx.fillRect(px - ds / 2, py - ds / 2, ds, ds);
      }
    }

    // Off-screen enemy arrows — point at threats outside the viewport.
    const mt = 24, mb = 24, ml = 24, mr = 24;  // viewport margin for the marker
    for (const e of this.enemies) {
      if (e.dead) continue;
      const visible = e.x > -10 && e.x < w + 10 && e.y > -10 && e.y < h + 10;
      if (visible) continue;
      // Clamp to inside the viewport edge.
      const mx = Math.max(ml, Math.min(w - mr, e.x));
      const my = Math.max(mt, Math.min(h - mb, e.y));
      const dx = e.x - mx, dy = e.y - my;
      const ang = Math.atan2(dy, dx);
      ctx.save();
      ctx.translate(mx, my);
      ctx.rotate(ang);
      ctx.fillStyle = e.boss ? '#d4a24c' : (e.mythic ? '#e8d2a0' : 'rgba(255,255,255,0.7)');
      ctx.beginPath();
      ctx.moveTo(10, 0); ctx.lineTo(-4, -5); ctx.lineTo(-4, 5);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    // Boss HP bar at the top of the arena (largest live boss).
    let boss = null;
    for (const e of this.enemies) {
      if (e.dead || !e.boss) continue;
      if (!boss || e.maxHp > boss.maxHp) boss = e;
    }
    if (boss) {
      const bw = Math.min(540, w - 32);
      const bx = (w - bw) / 2;
      const by = 76;
      ctx.fillStyle = 'rgba(0,0,0,0.55)';
      ctx.fillRect(bx - 2, by - 2, bw + 4, 16);
      ctx.fillStyle = '#222';
      ctx.fillRect(bx, by, bw, 12);
      const bfrac = Math.max(0, boss.hp / boss.maxHp);
      const grad = ctx.createLinearGradient(bx, 0, bx + bw, 0);
      grad.addColorStop(0, '#d4582c');
      grad.addColorStop(1, '#d4a24c');
      ctx.fillStyle = grad;
      ctx.fillRect(bx, by, bw * bfrac, 12);
      ctx.fillStyle = '#e8e2d2';
      ctx.font = 'bold 12px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`${boss.label}  ·  ${Math.max(0, Math.round(boss.hp))} / ${boss.maxHp}`,
        w / 2, by + 6);
    }

    // Wave-clear banner — slides in from top, holds, fades.
    if (this.banner) {
      const t = this.banner.t;
      const t0 = this.banner.t0;
      const elapsed = t0 - t;
      const slide = Math.min(1, elapsed / 0.25);   // 0..1 over first 250ms
      const fade = Math.max(0, Math.min(1, t / 0.35));
      const y = 60 + (1 - slide) * -40;
      ctx.fillStyle = `rgba(11, 10, 15, ${0.7 * fade})`;
      ctx.fillRect(0, y - 28, w, 56);
      ctx.fillStyle = this.banner.color + Math.round(255 * fade).toString(16).padStart(2, '0');
      ctx.font = 'bold 24px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(this.banner.text, w / 2, y);
    }

    // Low-HP red edge vignette.
    const hpFrac = this.heroHp / Math.max(1, this.heroMaxHp);
    if (hpFrac < 0.3 && hpFrac > 0) {
      const danger = (0.3 - hpFrac) / 0.3;  // 0..1
      const pulse = 0.4 + 0.4 * Math.sin(performance.now() / 200);
      const rg = ctx.createRadialGradient(w / 2, h / 2, Math.max(w, h) * 0.25,
                                          w / 2, h / 2, Math.max(w, h) * 0.7);
      rg.addColorStop(0, 'rgba(168, 50, 50, 0)');
      rg.addColorStop(1, `rgba(168, 50, 50, ${(0.4 * danger * pulse).toFixed(3)})`);
      ctx.fillStyle = rg;
      ctx.fillRect(0, 0, w, h);
    }

    // White flash overlay (boss kill, big moments)
    if (this.flash > 0) {
      ctx.fillStyle = `rgba(255,255,255,${this.flash.toFixed(3)})`;
      ctx.fillRect(0, 0, w, h);
    }

    // floaters
    for (const fl of this.floaters) {
      const alpha = fl.life / fl.life0;
      ctx.globalAlpha = Math.max(0, alpha);
      ctx.fillStyle = fl.color;
      if (fl.big) {
        // Crit floaters are bigger, with a soft drop-shadow.
        ctx.font = 'bold 20px system-ui';
        ctx.shadowColor = 'rgba(0,0,0,0.5)';
        ctx.shadowBlur = 4;
      } else {
        ctx.font = 'bold 14px system-ui';
        ctx.shadowBlur = 0;
      }
      ctx.textAlign = 'left';
      ctx.fillText(fl.text, fl.x, fl.y);
      ctx.shadowBlur = 0;
    }
    ctx.globalAlpha = 1;

    ctx.restore();
  }
}
