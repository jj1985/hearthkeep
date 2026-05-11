// HTML5 horde arena — canvas renderer, ECS-lite update loop.
import { State, persist, grantXp, checkKillMilestones, recordRun, grantEmbers } from './state.js';
import { bonusDamage, bonusAtk, bonusRange, bonusHp, bonusCrit } from './upgrades.js';
import { synergyFor } from './synergies.js';
import { Sfx } from './sfx.js';

const CLASS_COLOR = {
  warrior: '#d9892e',
  rogue: '#6fd07f',
  wizard: '#5a8fb3',
  necromancer: '#9966c8',
  bard: '#d4a4cc',
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

export function zoneForWave(w) {
  let cur = ZONES[0];
  for (const z of ZONES) if (w >= z.min) cur = z;
  return cur;
}

const BOSS_TYPES = {
  warchief:  { label: 'Krrik III',   color: '#d4a24c', hp: 240,  speed: 50,  gold: 60,  size: 38 },
  vyxhasis:  { label: 'Vyxhasis',    color: '#d44089', hp: 600,  speed: 45,  gold: 200, size: 48 },
  aethyrnax: { label: 'Aethyrnax',   color: '#66d9f2', hp: 1400, speed: 55,  gold: 500, size: 56 },
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
    // Class-signature passive state (per-run)
    this.warriorRage = 0;
    this.wizardHitCount = 0;
    this.frenzy = 0;          // hits taken since last guaranteed-crit
    this.FRENZY_CAP = 5;
    // Companion (unlocks at first boss kill)
    this.companionOrbitT = 0;
    this.companionAtkT = 1;
    // Sunfire pulse (zone 7+)
    this.sunfirePulseT = 8;
    // Boss telegraph countdown
    this.bossWarn = null; // { t, label }
    this.weather = []; // [{x, y, vy, color, size}]
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

  maxHp() {
    let hp = 50;
    hp += Math.floor((State.best_wave || 0) / 2);
    hp += (State.hero_level - 1);
    hp += bonusHp();
    hp += (State.level_perks?.perm_hp || 0) * 5;
    if (State.challenge_active && State.daily_curse === 'glass_cannon') hp = Math.max(10, Math.floor(hp / 2));
    return Math.max(20, hp);
  }

  challengeBonus() {
    return State.challenge_active ? 2 : 1;
  }
  curseDisables(c) {
    return State.challenge_active && State.daily_curse === c;
  }

  // --- Loop ---
  _loop() {
    const now = performance.now();
    let dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    if (!this.paused && !this.deadScreenOpen) {
      this._update(dt);
    }
    this._render();
    requestAnimationFrame(() => this._loop());
  }

  _update(dt) {
    this.spawnTimer -= dt;
    this.attackTimer -= dt;
    this.idleTimer -= dt;
    if (this.skillCd > 0) this.skillCd -= dt;
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
      e.x += (dx / d) * e.speed * dt;
      e.y += (dy / d) * e.speed * dt;
      if (d < 22 + e.size * 0.4) {
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
    const id = pool[Math.floor(Math.random() * pool.length)];
    const def = ENEMY_TYPES[id];
    const isMythic = this.wave >= 5 && Math.random() < (0.03 + this.mythicBonus);
    const sz = isMythic ? def.size * 1.4 : def.size;
    let hpScale = 1 + (this.wave - 1) * 0.18;
    if (this.isTempest()) hpScale *= 0.5;
    const maxHp = Math.round(def.hp * hpScale * (isMythic ? 10 : 1));
    const edge = Math.floor(Math.random() * 4);
    let x, y;
    const m = 30;
    if (edge === 0)      { x = Math.random() * this.size.w; y = -m; }
    else if (edge === 1) { x = this.size.w + m; y = Math.random() * this.size.h; }
    else if (edge === 2) { x = Math.random() * this.size.w; y = this.size.h + m; }
    else                 { x = -m; y = Math.random() * this.size.h; }
    this.enemies.push({
      id, label: def.label, color: def.color, x, y,
      hp: maxHp, maxHp, speed: def.speed + this.wave * 1.5,
      gold: def.gold * (isMythic ? 10 : 1), size: sz,
      mythic: isMythic, boss: false,
      explodes: !!def.explodes,
      ranged: !!def.ranged, shotCd: 1.5,
      heals: !!def.heals, healCd: 3.0,
      summons: !!def.summons, summonCd: 4.0,
    });
    if (isMythic) {
      this.floater(`MYTHIC ${def.label.toUpperCase()}`, this.size.w / 2 - 60, 80, '#e8d2a0');
    }
  }

  _spawnBoss() {
    const id = this.wave >= 50 ? 'aethyrnax' : (this.wave >= 30 ? 'vyxhasis' : 'warchief');
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
      hp: maxHp, maxHp, speed: def.speed,
      gold: def.gold, size: def.size,
      mythic: false, boss: true,
    });
    this.floater(`${def.label} appears!`, this.size.w / 2 - 80, 80, '#d4582c');
  }

  // --- Hero acts ---
  synergy() {
    return synergyFor([this.primaryClass, this.secondaryClass, this.tertiaryClass]);
  }

  atkRate() {
    let r = 2.5 + this.atkBonus + bonusAtk() + (State.level_perks?.perm_atk || 0) * 0.1;
    const s = this.synergy();
    if (s?.atk) r += s.atk;
    return r;
  }

  heroDmg() {
    let d = 4;
    d += Math.floor(this.wave / 2);
    d += (State.hero_level - 1) * 0.5;
    d += bonusDamage();
    d += (State.level_perks?.perm_dmg || 0);
    d *= this.rebirthBonus;
    d *= this.dmgMult;
    if (State.dragonslayer) d *= 1.10;
    if (this.primaryClass === 'bard') d *= 1.05;
    const s = this.synergy();
    if (s?.dmg) d *= 1 + s.dmg;
    if (this.primaryClass === 'warrior') d += this.warriorRage * 0.5;
    let v = Math.max(1, Math.round(d));
    const permCrit = (State.level_perks?.perm_crit || 0) * 0.02;
    let critted = Math.random() < (this.critBonus + bonusCrit() + permCrit);
    if (this.frenzy >= this.FRENZY_CAP) { critted = true; this.frenzy = 0; }
    if (critted) v *= 2;
    return v;
  }

  heroRange() { return 220 + this.rangeBonus + bonusRange() + (State.level_perks?.perm_range || 0) * 10; }

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
    if (this.primaryClass === 'wizard') {
      // Fireball — single nuke
      let best = null, bestHp = 0;
      for (const e of this.enemies) if (e.hp > bestHp) { bestHp = e.hp; best = e; }
      if (best) this._damageEnemy(best, dmg * 12);
    } else if (this.primaryClass === 'rogue') {
      this.heroHp = this.heroMaxHp;
      this.floater('FULL HEAL', this.heroPos.x - 30, this.heroPos.y, '#6fa060');
    } else {
      // Cleave AOE for warrior/necromancer/bard default
      for (const e of this.enemies) this._damageEnemy(e, dmg * 2);
      this.shakeMag = 20;
    }
    this.skillCd = 6;
    Sfx.crit();
  }

  _damageEnemy(e, amount) {
    e.hp -= amount;
    this.floater(`-${Math.round(amount)}`, e.x, e.y, amount < 10 ? '#c8a030' : '#d4582c');
    if (e.hp <= 0) this._killEnemy(e, true);
  }

  _killEnemy(e, byPlayer) {
    if (e.dead) return;
    e.dead = true;
    if (e.explodes) this._detonate(e.x, e.y, 60, Math.max(2, Math.round(this.heroDmg() * 0.5)));
    if (byPlayer) {
      const permGold = 1 + (State.level_perks?.perm_gold || 0) * 0.05;
      const s = this.synergy();
      const synGold = s?.gold ? 1 + s.gold : 1;
      const chal = this.challengeBonus();
      const gold = Math.max(1, Math.round(e.gold * this.rebirthBonus * this.goldMult * this.comboMult() * permGold * synGold * chal));
      State.gold += gold;
      this.combo++;
      this.comboDecay = 1.5;
      if (this.combo > this.comboPeak) this.comboPeak = this.combo;
      if (this.primaryClass === 'warrior') this.warriorRage = Math.min(20, this.warriorRage + 1);
      if (this.primaryClass === 'necromancer') this.heroHp = Math.min(this.heroMaxHp, this.heroHp + 1);
    }
    State.lifetime_kills++;
    this.killsThisRun++;
    const ups = grantXp(1);
    if (ups > 0) {
      this.floater(`LEVEL ${State.hero_level}`, this.heroPos.x, this.heroPos.y - 20, '#d4a24c');
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
      const ember = Math.round((1 + Math.floor(this.wave / 10)) * this.challengeBonus());
      grantEmbers(ember);
      this.runEmbersEarned += ember;
      State.bosses_felled++;
      this.floater(`+${ember} Ember`, e.x, e.y, '#d4582c');
      this.shakeMag = 30;
      this._burst(e.x, e.y);
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

  hasCompanion() { return (State.bosses_felled || 0) >= 1; }

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
    this.wave++;
    this.warriorRage = 0;
    this.waveKillsProgress = 0;
    this.waveKillsTarget = Math.floor(8 + this.wave * 1.5);
    if (this.wave > State.best_wave) State.best_wave = this.wave;
    this.heroHp = Math.min(this.heroMaxHp, this.heroHp + Math.floor(this.heroMaxHp / 4));
    const bonus = Math.round((5 + this.wave * this.wave) * this.waveBonusMult);
    State.gold += bonus;
    this.floater(`WAVE ${this.wave}  +${bonus}g`, this.heroPos.x, this.heroPos.y, '#d4a24c');
    this.log(`Wave ${this.wave} cleared (+${bonus}g)`);
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
    if (this.wave % 5 === 0 && this.onPerkRequest) {
      this.onPerkRequest();
    } else if (this.wave % 7 === 0 && this.onMerchant && !this.curseDisables('spendthrift')) {
      this.onMerchant();
    }
    persist();
  }

  _heroTakeDamage(amount) {
    if (this.deadScreenOpen) return;
    if (this.primaryClass === 'rogue' && Math.random() < 0.05) {
      this.floater('EVADE', this.heroPos.x, this.heroPos.y, '#d4a24c');
      return;
    }
    this.heroHp = Math.max(0, this.heroHp - amount);
    this.frenzy = Math.min(this.FRENZY_CAP, this.frenzy + 1);
    Sfx.hurt();
    this.shakeMag = Math.min(20, 6 + amount * 0.5);
    if (this.heroHp <= 0) this._onDie();
  }

  _onDie() {
    this.deadScreenOpen = true;
    this.paused = true;
    const lost = Math.floor(State.gold / 2);
    State.gold -= lost;
    recordRun({
      wave: this.wave, kills: this.killsThisRun,
      combo: this.comboPeak, embers: this.runEmbersEarned,
      class: this.primaryClass, when: Date.now(),
    });
    persist();
    if (this.onDeath) this.onDeath({
      wave: this.wave, kills: this.killsThisRun,
      combo: this.comboPeak, embers: this.runEmbersEarned,
      gold_lost: lost,
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
      persist();
    }
  }

  // --- FX helpers ---
  _spawnStrike(x, y) {
    this.fx.push({ x, y, vx: 0, vy: 0, life: 0.18, color: '#f5e8a8', size: 14, fade: true });
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
  floater(text, x, y, color = '#e8e2d2') {
    this.floaters.push({ text, x, y, color, life: 0.6, life0: 0.6 });
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

    // bg
    ctx.fillStyle = '#0b0a0f';
    ctx.fillRect(0, 0, w, h);
    // floor — tinted by zone
    ctx.fillStyle = zoneForWave(this.wave).floor;
    ctx.fillRect(0, 96, w, h - 200);
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
    for (const e of this.enemies) {
      ctx.fillStyle = e.color;
      const r = e.size / 2;
      ctx.beginPath();
      ctx.arc(e.x, e.y, r, 0, Math.PI * 2);
      ctx.fill();
      if (e.mythic || e.boss) {
        ctx.strokeStyle = '#d4a24c';
        ctx.lineWidth = 3;
        ctx.stroke();
      }
      // hp bar
      const barW = e.size;
      const frac = Math.max(0, e.hp / e.maxHp);
      ctx.fillStyle = 'rgba(0,0,0,0.5)';
      ctx.fillRect(e.x - barW / 2, e.y - r - 8, barW, 3);
      ctx.fillStyle = '#d95940';
      ctx.fillRect(e.x - barW / 2, e.y - r - 8, barW * frac, 3);
    }

    // arrows
    for (const a of this.arrows) {
      ctx.strokeStyle = '#f5e8a8';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(a.x - a.vx * 0.04, a.y - a.vy * 0.04);
      ctx.stroke();
    }

    // power-ups
    for (const p of this.powerups) {
      const c = p.kind === 'heal' ? '#6fa060' : p.kind === 'gold' ? '#d4a24c' : '#d4582c';
      ctx.fillStyle = c;
      ctx.beginPath();
      ctx.arc(p.x, p.y, 8, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 2;
      ctx.stroke();
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
    const hr = 22 * pulse;
    const hy = this.heroPos.y + bob;
    ctx.fillStyle = CLASS_COLOR[this.primaryClass] || '#d4a24c';
    ctx.beginPath();
    ctx.arc(this.heroPos.x, hy, hr, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.fillStyle = '#1a1208';
    ctx.font = 'bold 16px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(this.primaryClass[0].toUpperCase(), this.heroPos.x, hy);

    // chest
    if (this.chest) {
      const bob = Math.sin(performance.now() / 200) * 3;
      ctx.fillStyle = '#8c6433';
      ctx.fillRect(this.chest.x - 16, this.chest.y - 14 + bob, 32, 22);
      ctx.strokeStyle = '#d4a24c';
      ctx.lineWidth = 2;
      ctx.strokeRect(this.chest.x - 16, this.chest.y - 14 + bob, 32, 22);
      ctx.fillStyle = '#d4a24c';
      ctx.font = 'bold 12px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText(this.chest.t.toFixed(1), this.chest.x, this.chest.y - 22 + bob);
    }

    // boss telegraph
    if (this.bossWarn) {
      const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 100);
      ctx.fillStyle = `rgba(216, 50, 50, ${pulse})`;
      ctx.font = 'bold 22px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText(`INCOMING: ${this.bossWarn.label}  ${this.bossWarn.t.toFixed(1)}s`,
        this.size.w / 2, 110);
    }

    // floaters
    for (const fl of this.floaters) {
      const alpha = fl.life / fl.life0;
      ctx.globalAlpha = Math.max(0, alpha);
      ctx.fillStyle = fl.color;
      ctx.font = 'bold 14px system-ui';
      ctx.textAlign = 'left';
      ctx.fillText(fl.text, fl.x, fl.y);
    }
    ctx.globalAlpha = 1;

    ctx.restore();
  }
}
