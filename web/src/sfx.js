// Tiny procedural SFX layer via WebAudio. No assets, no engine fight.
// Lazy-init the AudioContext on first user interaction (mobile autoplay).

import { State } from './state.js';

let ctx = null;
let muted = false;
function masterGain() { return Math.max(0, Math.min(1, State.sfx_volume ?? 0.7)); }

function ensureCtx() {
  if (ctx) return ctx;
  const A = window.AudioContext || window.webkitAudioContext;
  if (!A) return null;
  ctx = new A();
  return ctx;
}

document.addEventListener('pointerdown', () => { ensureCtx(); }, { once: true });

export function setMuted(m) { muted = !!m; }
export function isMuted() { return muted; }

function blip(freq, dur, shape = 'square', gain = 0.08) {
  if (muted) return;
  const c = ensureCtx();
  if (!c) return;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = shape;
  o.frequency.setValueAtTime(freq, c.currentTime);
  g.gain.setValueAtTime(gain * masterGain(), c.currentTime);
  g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
  o.connect(g).connect(c.destination);
  o.start();
  o.stop(c.currentTime + dur);
}

function sweep(f0, f1, dur, gain = 0.08) {
  if (muted) return;
  const c = ensureCtx();
  if (!c) return;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = 'sawtooth';
  o.frequency.setValueAtTime(f0, c.currentTime);
  o.frequency.linearRampToValueAtTime(f1, c.currentTime + dur);
  g.gain.setValueAtTime(gain * masterGain(), c.currentTime);
  g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
  o.connect(g).connect(c.destination);
  o.start();
  o.stop(c.currentTime + dur);
}

export const Sfx = {
  hit:    () => blip(440, 0.06, 'square', 0.05),
  crit:   () => { blip(880, 0.05, 'square'); blip(1320, 0.08, 'triangle', 0.04); },
  strike: () => sweep(220, 660, 0.10, 0.06),
  kill:   () => blip(660, 0.05, 'triangle', 0.04),
  boss:   () => { sweep(120, 60, 0.5, 0.08); blip(220, 0.4, 'sawtooth', 0.06); },
  levelup:() => { blip(523, 0.10, 'triangle'); blip(659, 0.10, 'triangle'); blip(784, 0.20, 'triangle'); },
  pickup: () => blip(780, 0.06, 'sine', 0.06),
  chest:  () => sweep(220, 880, 0.45, 0.06),
  hurt:   () => blip(160, 0.10, 'sawtooth', 0.06),
};
