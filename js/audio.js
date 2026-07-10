// audio.js — tiny WebAudio synth for UI sounds + selectable timer ringers.
import { store } from './store.js';

let ctx;
function ac() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

function tone(freq, { t = 0, dur = 0.15, type = 'sine', vol = 0.16, glide = 0 } = {}) {
  if (!store.state.settings.sound) return;
  try {
    const c = ac();
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = type;
    const start = c.currentTime + t;
    o.frequency.setValueAtTime(freq, start);
    if (glide) o.frequency.exponentialRampToValueAtTime(freq * glide, start + dur * 0.7);
    g.gain.setValueAtTime(0.0001, start);
    g.gain.exponentialRampToValueAtTime(vol, start + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, start + dur);
    o.connect(g).connect(c.destination);
    o.start(start);
    o.stop(start + dur + 0.05);
  } catch { /* audio blocked — fine */ }
}

// ---- timer ringers (pick yours in Settings) ----
export const RINGERS = {
  chime: {
    label: 'Chime',
    play: () => [659, 784, 988, 1319].forEach((f, i) => tone(f, { t: i * 0.13, dur: 0.4, vol: 0.14 })),
  },
  bell: {
    label: 'Bell',
    play: () => {
      tone(880, { dur: 1.2, vol: 0.13 }); tone(1760, { dur: 0.7, vol: 0.04 });
      tone(659, { t: 0.55, dur: 1.4, vol: 0.13 }); tone(1318, { t: 0.55, dur: 0.8, vol: 0.04 });
    },
  },
  birdsong: {
    label: 'Birdsong',
    play: () => {
      [[2300, 0], [2700, 0.1], [2450, 0.22], [3000, 0.36], [2600, 0.52], [3150, 0.64]]
        .forEach(([f, t]) => tone(f, { t, dur: 0.1, vol: 0.07, glide: 1.25 }));
    },
  },
  marimba: {
    label: 'Marimba',
    play: () => [1047, 784, 659, 523, 659, 784].forEach((f, i) => tone(f, { t: i * 0.11, dur: 0.28, type: 'triangle', vol: 0.15 })),
  },
  silent: { label: 'Silent', play: () => {} },
};

export function playRinger(name) {
  const key = name || store.state.settings.ringer || 'chime';
  (RINGERS[key] || RINGERS.chime).play();
}

function noiseSource(c, color = 'white') {
  const len = c.sampleRate * 2;
  const buf = c.createBuffer(1, len, c.sampleRate);
  const d = buf.getChannelData(0);
  let last = 0;
  for (let i = 0; i < len; i++) {
    const white = Math.random() * 2 - 1;
    if (color === 'brown') { last = (last + 0.02 * white) / 1.02; d[i] = last * 3.5; }
    else d[i] = white;
  }
  const src = c.createBufferSource();
  src.buffer = buf;
  src.loop = true;
  return src;
}

// ---- background music: a soft generative garden loop, on by default ----
let musicNodes = null;
let musicTimer = null;

export function musicPlaying() { return !!musicNodes; }

export function startMusic() {
  if (musicNodes) return;
  if (!store.state.settings.sound || store.state.settings.music === false) return;
  try {
    const c = ac();
    const master = c.createGain();
    master.gain.setValueAtTime(0.0001, c.currentTime);
    master.gain.exponentialRampToValueAtTime(1, c.currentTime + 3);
    master.connect(c.destination);

    // faint warm air under everything
    const air = noiseSource(c, 'brown');
    const airF = c.createBiquadFilter();
    airF.type = 'lowpass';
    airF.frequency.value = 260;
    const airG = c.createGain();
    airG.gain.value = 0.008;
    air.connect(airF).connect(airG).connect(master);
    air.start();

    musicNodes = [master, air, airF, airG];

    const padNote = (f, t, dur) => {
      const o = c.createOscillator();
      o.type = 'sine';
      o.frequency.value = f;
      const g = c.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.016, t + 0.9);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g).connect(master);
      o.start(t);
      o.stop(t + dur + 0.1);
    };
    const bassNote = (f, t, dur) => {
      const o = c.createOscillator();
      o.type = 'sine';
      o.frequency.value = f;
      const g = c.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.02, t + 0.3);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g).connect(master);
      o.start(t);
      o.stop(t + dur + 0.1);
    };
    const pluck = (f, t) => {
      const o = c.createOscillator();
      o.type = 'triangle';
      o.frequency.value = f;
      const filt = c.createBiquadFilter();
      filt.type = 'lowpass';
      filt.frequency.value = 2200;
      const g = c.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.026, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 1.5);
      o.connect(filt).connect(g).connect(master);
      o.start(t);
      o.stop(t + 1.6);
    };

    // Fmaj7 → Em7 → Dm7 → Cmaj7, slow and low
    const CHORDS = [
      [174.61, 220.0, 261.63, 329.63],
      [164.81, 196.0, 246.94, 293.66],
      [146.83, 174.61, 220.0, 261.63],
      [130.81, 164.81, 196.0, 246.94],
    ];
    const PENTA = [392.0, 440.0, 523.25, 587.33, 659.25, 783.99];
    const BAR = 3.6;
    let bar = 0;
    let nextBar = c.currentTime + 0.15;
    const scheduleBar = () => {
      const chord = CHORDS[bar % CHORDS.length];
      chord.forEach((f, i) => padNote(f, nextBar + i * 0.04, BAR + 1));
      bassNote(chord[0] / 2, nextBar, BAR);
      const n = 1 + ((Math.random() * 3) | 0);
      for (let i = 0; i < n; i++) {
        if (Math.random() < 0.85) pluck(PENTA[(Math.random() * PENTA.length) | 0], nextBar + 0.5 + Math.random() * (BAR - 1.2));
      }
      bar++;
      nextBar += BAR;
    };
    scheduleBar();
    scheduleBar();
    musicTimer = setInterval(() => {
      if (!musicNodes) return;
      while (nextBar < c.currentTime + BAR * 1.5) scheduleBar();
    }, 800);

    document.addEventListener('pointerdown', () => { if (c.state === 'suspended') c.resume(); }, { once: true });
  } catch { /* audio unavailable — fine */ }
}

export function stopMusic(fade = true) {
  clearInterval(musicTimer);
  musicTimer = null;
  if (!musicNodes) return;
  const nodes = musicNodes;
  musicNodes = null;
  try {
    const master = nodes[0];
    const c = master.context;
    if (fade) {
      master.gain.cancelScheduledValues(c.currentTime);
      master.gain.setValueAtTime(Math.max(master.gain.value, 0.0001), c.currentTime);
      master.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + 1);
    }
    setTimeout(() => {
      for (const n of nodes) { try { n.stop?.(); } catch { } try { n.disconnect?.(); } catch { } }
    }, fade ? 1100 : 0);
  } catch { /* already torn down */ }
}

export function syncMusic() {
  if (store.state.settings.sound && store.state.settings.music !== false) startMusic();
  else stopMusic();
}

export const sfx = {
  click: () => tone(660, { dur: 0.07, vol: 0.07, type: 'triangle' }),
  pop: () => { tone(520, { dur: 0.09, type: 'triangle' }); tone(784, { t: 0.07, dur: 0.13, type: 'triangle' }); },
  start: () => { tone(440, { dur: 0.1, type: 'sine' }); tone(660, { t: 0.1, dur: 0.16, type: 'sine' }); },
  chime: () => playRinger(),
  level: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, { t: i * 0.09, dur: 0.32, type: 'triangle' })),
  uhoh: () => { tone(330, { dur: 0.12, type: 'triangle' }); tone(262, { t: 0.11, dur: 0.18, type: 'triangle' }); },
};
