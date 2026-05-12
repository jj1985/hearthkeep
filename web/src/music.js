// Procedural ambient drone. Two layered oscillators detuned a fifth
// apart, slow LFO on filter cutoff for a "breathing" feel. Calm by
// default; tense layer adds when bossActive=true.

import { State } from './state.js';

let ctx = null;
let started = false;
let nodes = null;
let muted = false;

export function setMusicMuted(m) { muted = !!m; if (nodes) updateGain(); }

function masterGain() {
  return muted ? 0 : Math.max(0, Math.min(1, (State.sfx_volume ?? 0.7) * 0.35));
}

function ensureCtx() {
  if (ctx) return ctx;
  const A = window.AudioContext || window.webkitAudioContext;
  if (!A) return null;
  ctx = new A();
  return ctx;
}

function start() {
  if (started) return;
  const c = ensureCtx();
  if (!c) return;
  started = true;
  const out = c.createGain();
  out.gain.value = masterGain();
  out.connect(c.destination);

  const filter = c.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.value = 600;
  filter.Q.value = 0.7;
  filter.connect(out);

  const lfo = c.createOscillator();
  lfo.frequency.value = 0.07;
  const lfoGain = c.createGain();
  lfoGain.gain.value = 200;
  lfo.connect(lfoGain).connect(filter.frequency);
  lfo.start();

  function pad(freq, type = 'sine') {
    const o = c.createOscillator();
    o.type = type;
    o.frequency.value = freq;
    const g = c.createGain();
    g.gain.value = 0.18;
    o.connect(g).connect(filter);
    o.start();
    return o;
  }

  pad(110, 'sine');
  pad(165, 'triangle');         // fifth above
  // Tense layer (silent by default, fades in on boss)
  const tense = c.createGain();
  tense.gain.value = 0;
  tense.connect(filter);
  const t1 = c.createOscillator();
  t1.type = 'sawtooth';
  t1.frequency.value = 55;
  t1.connect(tense);
  t1.start();

  nodes = { out, tense };
}

document.addEventListener('pointerdown', () => start(), { once: true });

export function setIntensity(level) {
  // 0..1 → blend tense layer
  if (!nodes || !ctx) return;
  const t = Math.max(0, Math.min(1, level));
  nodes.tense.gain.cancelScheduledValues(ctx.currentTime);
  nodes.tense.gain.linearRampToValueAtTime(t * 0.30, ctx.currentTime + 0.6);
}

function updateGain() {
  if (!nodes || !ctx) return;
  nodes.out.gain.cancelScheduledValues(ctx.currentTime);
  nodes.out.gain.linearRampToValueAtTime(masterGain(), ctx.currentTime + 0.3);
}

export const Music = { start, setIntensity, updateGain };
