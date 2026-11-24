// Браузерное демо «Мир весёлых машинок 3D».
// Самостоятельный прототип на three.js: езда по городу, звёздочки, музыка,
// звук двигателя и русский голос через встроенный синтез речи браузера.
// Ничего не загружается извне, кроме собственной папки vendor/.

import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

// ----------------------------------------------------------------- helpers ---
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = rng(2026);
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

function mat(color, opts = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.0, ...opts });
}

// ----------------------------------------------------------------- renderer ---
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x9edcff);
scene.fog = new THREE.Fog(0x9edcff, 140, 340);

const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.1, 800);

scene.add(new THREE.HemisphereLight(0xddf3ff, 0x6fb35a, 1.0));
const sun = new THREE.DirectionalLight(0xfff1d6, 2.1);
sun.position.set(60, 90, 40);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -120, right: 120, top: 120, bottom: -120, near: 10, far: 300 });
sun.shadow.bias = -0.0008;
scene.add(sun);
scene.add(sun.target);

// ------------------------------------------------------------------ ground ---
const ground = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), mat(0x7ccf6a, { roughness: 0.95 }));
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);

// ------------------------------------------------------------------- road ---
const ROAD_HALF = 4.2;
const SIDE_W = 2.8;
const SAMPLES = 480;
const track = new THREE.CatmullRomCurve3(
  Array.from({ length: 16 }, (_, i) => {
    const a = (i / 16) * Math.PI * 2;
    return new THREE.Vector3(70 * Math.cos(a) + 6 * Math.sin(3 * a), 0, 46 * Math.sin(a) + 5 * Math.cos(2 * a));
  }),
  true,
  'catmullrom',
  0.5,
);
const centerPts = Array.from({ length: SAMPLES }, (_, i) => track.getPointAt(i / SAMPLES));
const tangents = Array.from({ length: SAMPLES }, (_, i) => track.getTangentAt(i / SAMPLES));

function ribbon(a, b, y, material) {
  const pos = [];
  const idx = [];
  for (let i = 0; i < SAMPLES; i++) {
    const p = centerPts[i];
    const t = tangents[i];
    const nx = -t.z;
    const nz = t.x;
    pos.push(p.x + nx * a, y, p.z + nz * a, p.x + nx * b, y, p.z + nz * b);
    const i2 = (i + 1) % SAMPLES;
    const k = i * 2;
    const k2 = i2 * 2;
    // winding chosen so the surface faces up
    idx.push(k, k + 1, k2, k + 1, k2 + 1, k2);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, material);
  m.receiveShadow = true;
  scene.add(m);
  return m;
}
ribbon(-ROAD_HALF, ROAD_HALF, 0.02, mat(0x4a4f57, { roughness: 0.9 }));
ribbon(ROAD_HALF, ROAD_HALF + SIDE_W, 0.12, mat(0xe9e4da));
ribbon(-ROAD_HALF - SIDE_W, -ROAD_HALF, 0.12, mat(0xe9e4da));

const dashMat = mat(0xfff6c8, { emissive: 0x332a00, emissiveIntensity: 0.3 });
const dashGeo = new THREE.BoxGeometry(0.3, 0.05, 2.4);
for (let i = 0; i < SAMPLES; i += 8) {
  const p = centerPts[i];
  const t = tangents[i];
  const d = new THREE.Mesh(dashGeo, dashMat);
  d.position.set(p.x, 0.07, p.z);
  d.rotation.y = Math.atan2(t.x, t.z);
  scene.add(d);
}

// Surface query: distance from the road centre line and nearest sample index.
function roadQuery(x, z) {
  let best = Infinity;
  let bi = 0;
  for (let i = 0; i < SAMPLES; i++) {
    const p = centerPts[i];
    const dx = p.x - x;
    const dz = p.z - z;
    const d = dx * dx + dz * dz;
    if (d < best) { best = d; bi = i; }
  }
  return { dist: Math.sqrt(best), index: bi };
}

// ------------------------------------------------------------- obstacles ---
const obstacles = [];
const decor = new THREE.Group();
scene.add(decor);

function nearRoad(x, z, margin) {
  return roadQuery(x, z).dist < ROAD_HALF + SIDE_W + margin;
}

function addHouse(x, z, rot) {
  const g = new THREE.Group();
  const walls = [0xffe8c2, 0xffc2c2, 0xc7e8ff, 0xd9ffc7, 0xfff0a8][Math.floor(rand() * 5)];
  const roofs = [0xd9573f, 0x3f7fd9, 0x7b4fd9, 0x3fa36b][Math.floor(rand() * 4)];
  const w = 6 + rand() * 2;
  const h = 4 + rand() * 1.5;
  const body = new THREE.Mesh(new RoundedBoxGeometry(w, h, w * 0.8, 3, 0.25), mat(walls, { roughness: 0.8 }));
  body.position.y = h / 2;
  body.castShadow = true;
  body.receiveShadow = true;
  g.add(body);
  const roof = new THREE.Mesh(new THREE.ConeGeometry(w * 0.78, 2.6, 4), mat(roofs, { roughness: 0.5 }));
  roof.rotation.y = Math.PI / 4;
  roof.position.y = h + 1.3;
  roof.castShadow = true;
  g.add(roof);
  const door = new THREE.Mesh(new THREE.BoxGeometry(1.2, 2.2, 0.15), mat(0x7a4a2a));
  door.position.set(0, 1.1, w * 0.4 + 0.05);
  g.add(door);
  const winMat = mat(0xbfe9ff, { emissive: 0x3a5a70, emissiveIntensity: 0.4, roughness: 0.2 });
  for (const sx of [-1, 1]) {
    const win = new THREE.Mesh(new THREE.BoxGeometry(1.3, 1.2, 0.15), winMat);
    win.position.set(sx * w * 0.28, h * 0.6, w * 0.4 + 0.05);
    g.add(win);
  }
  g.position.set(x, 0, z);
  g.rotation.y = rot;
  decor.add(g);
  obstacles.push({ x, z, r: w * 0.6 });
}

function addTree(x, z, s) {
  const g = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.28 * s, 0.4 * s, 2.2 * s, 8), mat(0x8a5a33, { roughness: 0.9 }));
  trunk.position.y = 1.1 * s;
  trunk.castShadow = true;
  g.add(trunk);
  const leafColor = [0x3fae4f, 0x4cbc57, 0x2f9a5a][Math.floor(rand() * 3)];
  const crown = new THREE.Mesh(new THREE.IcosahedronGeometry(1.5 * s, 1), mat(leafColor, { flatShading: true, roughness: 0.8 }));
  crown.position.y = 3.2 * s;
  crown.castShadow = true;
  g.add(crown);
  g.position.set(x, 0, z);
  decor.add(g);
  obstacles.push({ x, z, r: 1.2 * s });
}

function addFlowers(x, z) {
  const colors = [0xff6f91, 0xffd447, 0xffffff, 0xb39ddb];
  for (let i = 0; i < 6; i++) {
    const f = new THREE.Mesh(new THREE.SphereGeometry(0.18, 8, 6), mat(colors[i % colors.length], { roughness: 0.5 }));
    f.position.set(x + (rand() - 0.5) * 2.2, 0.22, z + (rand() - 0.5) * 2.2);
    decor.add(f);
  }
}

// Scatter the world deterministically: houses on the outside, trees and flowers around.
let placed = 0;
for (let tries = 0; tries < 4000 && placed < 34; tries++) {
  const x = (rand() - 0.5) * 360;
  const z = (rand() - 0.5) * 300;
  if (nearRoad(x, z, 6)) continue;
  if (obstacles.some((o) => Math.hypot(o.x - x, o.z - z) < 14)) continue;
  if (placed < 14) {
    addHouse(x, z, (rand() - 0.5) * 0.4);
  } else {
    addTree(x, z, 0.9 + rand() * 0.7);
  }
  placed++;
}
for (let i = 0; i < 60; i++) {
  const x = (rand() - 0.5) * 320;
  const z = (rand() - 0.5) * 280;
  if (nearRoad(x, z, 3)) continue;
  addFlowers(x, z);
}

// Clouds drift slowly across the sky.
const clouds = [];
for (let i = 0; i < 9; i++) {
  const c = new THREE.Group();
  const cm = mat(0xffffff, { roughness: 1, emissive: 0x444444, emissiveIntensity: 0.15 });
  for (let k = 0; k < 4; k++) {
    const s = new THREE.Mesh(new THREE.SphereGeometry(3 + rand() * 1.5, 12, 10), cm);
    s.position.set(k * 3.2 - 4.5, rand() * 0.8, (rand() - 0.5) * 2);
    c.add(s);
  }
  c.position.set((rand() - 0.5) * 300, 45 + rand() * 15, (rand() - 0.5) * 300);
  scene.add(c);
  clouds.push(c);
}

// ----------------------------------------------------------------- stars ---
const starShape = new THREE.Shape();
for (let i = 0; i < 10; i++) {
  const r = i % 2 === 0 ? 1.0 : 0.45;
  const a = (i / 10) * Math.PI * 2 + Math.PI / 2;
  const x = Math.cos(a) * r;
  const y = Math.sin(a) * r;
  if (i === 0) starShape.moveTo(x, y); else starShape.lineTo(x, y);
}
starShape.closePath();
const starGeo = new THREE.ExtrudeGeometry(starShape, { depth: 0.25, bevelEnabled: true, bevelSize: 0.08, bevelThickness: 0.08, bevelSegments: 2 });
starGeo.center();
const starMat = mat(0xffc93c, { emissive: 0xff9a00, emissiveIntensity: 0.35, metalness: 0.3, roughness: 0.3 });

const STAR_COUNT = 12;
const stars = [];
for (let i = 0; i < STAR_COUNT; i++) {
  const u = (i + 0.5) / STAR_COUNT;
  const p = track.getPointAt(u);
  const m = new THREE.Mesh(starGeo, starMat);
  m.position.set(p.x, 2.2, p.z);
  m.castShadow = true;
  scene.add(m);
  stars.push({ mesh: m, base: 2.2, got: false, phase: i });
}

// ------------------------------------------------------------------ car ---
// Forward is +Z in the car group. Built from rounded parts, with lights and glass.
function buildCar(color) {
  const g = new THREE.Group();
  const paint = mat(color, { roughness: 0.32, metalness: 0.15 });
  const glass = mat(0x9fd8ff, { roughness: 0.08, metalness: 0.2, transparent: true, opacity: 0.82 });
  const dark = mat(0x222427, { roughness: 0.7 });
  const chrome = mat(0xd9dee6, { roughness: 0.2, metalness: 0.85 });

  const body = new THREE.Mesh(new RoundedBoxGeometry(1.8, 0.7, 3.8, 4, 0.28), paint);
  body.position.y = 0.7;
  body.castShadow = true;
  g.add(body);

  const cabin = new THREE.Mesh(new RoundedBoxGeometry(1.5, 0.62, 2.0, 4, 0.26), paint);
  cabin.position.set(0, 1.35, -0.2);
  cabin.castShadow = true;
  g.add(cabin);

  const windshield = new THREE.Mesh(new RoundedBoxGeometry(1.42, 0.52, 0.08, 2, 0.12), glass);
  windshield.position.set(0, 1.35, 0.8);
  windshield.rotation.x = -0.35;
  g.add(windshield);
  const rearGlass = windshield.clone();
  rearGlass.position.set(0, 1.35, -1.2);
  rearGlass.rotation.x = 0.35;
  g.add(rearGlass);
  for (const sx of [-1, 1]) {
    const side = new THREE.Mesh(new RoundedBoxGeometry(0.06, 0.45, 1.6, 2, 0.08), glass);
    side.position.set(sx * 0.77, 1.38, -0.2);
    g.add(side);
  }

  for (const sx of [-1, 1]) {
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.22, 12, 10), mat(0xfff7c2, { emissive: 0xffe680, emissiveIntensity: 1.2 }));
    head.position.set(sx * 0.6, 0.85, 1.92);
    head.scale.set(1, 0.7, 0.5);
    g.add(head);
    const tail = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.16, 0.08), mat(0xff3b3b, { emissive: 0x880000, emissiveIntensity: 0.6 }));
    tail.position.set(sx * 0.6, 0.85, -1.92);
    g.add(tail);
  }
  const bumperF = new THREE.Mesh(new RoundedBoxGeometry(1.7, 0.2, 0.25, 2, 0.08), dark);
  bumperF.position.set(0, 0.42, 1.93);
  g.add(bumperF);
  const bumperR = bumperF.clone();
  bumperR.position.z = -1.93;
  g.add(bumperR);
  const grille = new THREE.Mesh(new RoundedBoxGeometry(0.9, 0.22, 0.05, 2, 0.05), chrome);
  grille.position.set(0, 0.78, 1.91);
  g.add(grille);

  // wheels: each one is a group so it can spin around its axle
  const wheels = [];
  const tyreGeo = new THREE.CylinderGeometry(0.44, 0.44, 0.36, 18);
  const hubGeo = new THREE.CylinderGeometry(0.22, 0.22, 0.38, 12);
  for (const [x, z] of [[-0.95, 1.22], [0.95, 1.22], [-0.95, -1.22], [0.95, -1.22]]) {
    const w = new THREE.Group();
    const tyre = new THREE.Mesh(tyreGeo, dark);
    tyre.rotation.z = Math.PI / 2;
    tyre.castShadow = true;
    w.add(tyre);
    const hub = new THREE.Mesh(hubGeo, chrome);
    hub.rotation.z = Math.PI / 2;
    w.add(hub);
    w.position.set(x, 0.44, z);
    g.add(w);
    wheels.push(w);
  }
  return { group: g, wheels };
}

const CAR_COLORS = [0xe53935, 0x1e88e5, 0xfdd835, 0x43a047];
const car = buildCar(CAR_COLORS[0]);
const carRoot = new THREE.Group();
carRoot.add(car.group);
scene.add(carRoot);

// Start on the road, facing along the track direction.
const startU = 0.0;
const startP = track.getPointAt(startU);
const startT = track.getTangentAt(startU);
const state = {
  x: startP.x,
  z: startP.z,
  heading: Math.atan2(startT.x, startT.z),
  speed: 0,
  steer: 0,
  wheelSpin: 0,
};

// ---------------------------------------------------------------- input ---
const input = { gas: false, brake: false, left: false, right: false };
const keyMap = {
  ArrowUp: 'gas', KeyW: 'gas',
  ArrowDown: 'brake', KeyS: 'brake', Space: 'brake',
  ArrowLeft: 'left', KeyA: 'left',
  ArrowRight: 'right', KeyD: 'right',
};
window.addEventListener('keydown', (e) => {
  if (e.code === 'KeyC') { toggleCamera(); return; }
  if (e.code === 'KeyM') { toggleMusic(); return; }
  if (e.code === 'KeyN') { toggleSfx(); return; }
  const k = keyMap[e.code];
  if (k) { input[k] = true; e.preventDefault(); }
});
window.addEventListener('keyup', (e) => {
  const k = keyMap[e.code];
  if (k) input[k] = false;
});

document.querySelectorAll('.btn').forEach((btn) => {
  const k = btn.dataset.k;
  const down = (e) => { e.preventDefault(); input[k] = true; btn.classList.add('active'); try { btn.setPointerCapture(e.pointerId); } catch (_) {} };
  const up = (e) => { e.preventDefault(); input[k] = false; btn.classList.remove('active'); };
  btn.addEventListener('pointerdown', down);
  btn.addEventListener('pointerup', up);
  btn.addEventListener('pointercancel', up);
  btn.addEventListener('lostpointercapture', up);
});

// --------------------------------------------------------------- audio ---
let ctx = null;
let masterMusic = null;
let masterSfx = null;
let engineOsc = null;
let engineGain = null;
let musicTimer = null;
let nextNoteTime = 0;
let noteIndex = 0;
const settings = { music: true, sfx: true, voice: true };

const MELODY = [523.25, 659.25, 783.99, 659.25, 880.0, 783.99, 659.25, 523.25, 587.33, 698.46, 880.0, 698.46, 587.33, 493.88, 587.33, 523.25];

function initAudio() {
  if (ctx) return;
  ctx = new (window.AudioContext || window.webkitAudioContext)();
  masterMusic = ctx.createGain();
  masterMusic.gain.value = settings.music ? 0.12 : 0;
  masterMusic.connect(ctx.destination);
  masterSfx = ctx.createGain();
  masterSfx.gain.value = settings.sfx ? 0.5 : 0;
  masterSfx.connect(ctx.destination);

  engineOsc = ctx.createOscillator();
  engineOsc.type = 'sawtooth';
  engineOsc.frequency.value = 60;
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 500;
  engineGain = ctx.createGain();
  engineGain.gain.value = 0.0;
  engineOsc.connect(lp);
  lp.connect(engineGain);
  engineGain.connect(masterSfx);
  engineOsc.start();

  nextNoteTime = ctx.currentTime + 0.1;
  musicTimer = setInterval(scheduleMusic, 80);
}

function scheduleMusic() {
  if (!ctx) return;
  while (nextNoteTime < ctx.currentTime + 0.25) {
    const f = MELODY[noteIndex % MELODY.length];
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = 'triangle';
    o.frequency.value = f;
    g.gain.setValueAtTime(0.0001, nextNoteTime);
    g.gain.exponentialRampToValueAtTime(0.5, nextNoteTime + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, nextNoteTime + 0.24);
    o.connect(g);
    g.connect(masterMusic);
    o.start(nextNoteTime);
    o.stop(nextNoteTime + 0.25);
    // a soft bass on every fourth note
    if (noteIndex % 4 === 0) {
      const b = ctx.createOscillator();
      const bg = ctx.createGain();
      b.type = 'sine';
      b.frequency.value = f / 4;
      bg.gain.setValueAtTime(0.4, nextNoteTime);
      bg.gain.exponentialRampToValueAtTime(0.0001, nextNoteTime + 0.9);
      b.connect(bg);
      bg.connect(masterMusic);
      b.start(nextNoteTime);
      b.stop(nextNoteTime + 0.95);
    }
    nextNoteTime += 0.24;
    noteIndex++;
  }
}

function beep(freqs, step = 0.07, dur = 0.16) {
  if (!ctx || !settings.sfx) return;
  freqs.forEach((f, i) => {
    const t = ctx.currentTime + i * step;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = 'triangle';
    o.frequency.value = f;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.45, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g);
    g.connect(masterSfx);
    o.start(t);
    o.stop(t + dur + 0.02);
  });
}

function say(text) {
  if (!settings.voice || !('speechSynthesis' in window)) return;
  const u = new SpeechSynthesisUtterance(text);
  u.lang = 'ru-RU';
  u.rate = 1.0;
  u.pitch = 1.3;
  speechSynthesis.cancel();
  speechSynthesis.speak(u);
}

function syncToggles() {
  const set = (id, on, label) => {
    const b = document.getElementById(id);
    b.classList.toggle('off', !on);
    b.textContent = label + (on ? ': вкл' : ': выкл');
  };
  set('tMusic', settings.music, 'Музыка');
  set('tSfx', settings.sfx, 'Звуки');
  set('tVoice', settings.voice, 'Голос');
  document.getElementById('tCam').textContent = 'Камера: ' + CAM_NAMES[camMode];
}

function toggleMusic() {
  settings.music = !settings.music;
  if (masterMusic) masterMusic.gain.setTargetAtTime(settings.music ? 0.12 : 0, ctx.currentTime, 0.05);
  syncToggles();
}
function toggleSfx() {
  settings.sfx = !settings.sfx;
  if (masterSfx) masterSfx.gain.setTargetAtTime(settings.sfx ? 0.5 : 0, ctx.currentTime, 0.05);
  syncToggles();
}
function toggleVoice() {
  settings.voice = !settings.voice;
  if (!settings.voice && 'speechSynthesis' in window) speechSynthesis.cancel();
  syncToggles();
}

// ---------------------------------------------------------------- camera ---
const CAM_NAMES = ['Рядом', 'Сверху'];
let camMode = 0;
const camPos = new THREE.Vector3();
const camLook = new THREE.Vector3();
let camInit = false;

function toggleCamera() {
  camMode = (camMode + 1) % CAM_NAMES.length;
  syncToggles();
}

function updateCamera(dt) {
  const fx = Math.sin(state.heading);
  const fz = Math.cos(state.heading);
  let back = 7.5;
  let up = 3.2;
  if (camMode === 1) { back = 12; up = 11; }
  // speed-dependent pull back keeps fast driving readable
  back += clamp(Math.abs(state.speed) - 10, 0, 10) * 0.2;
  const target = new THREE.Vector3(state.x - fx * back, up, state.z - fz * back);
  if (!camInit) { camPos.copy(target); camInit = true; }
  const k = 1 - Math.exp(-dt * 4.5);
  camPos.lerp(target, k);
  camera.position.copy(camPos);
  camLook.set(state.x + fx * 3, 1.0, state.z + fz * 3);
  camera.lookAt(camLook);
}

// ----------------------------------------------------------------- physics ---
const MAX_SPEED = 19;
const GRASS_MAX = 8;
const ACCEL = 13;
const BRAKE = 26;
const DRAG = 3.5;
const REVERSE_MAX = 6;

function stepCar(dt) {
  const q = roadQuery(state.x, state.z);
  const onRoad = q.dist < ROAD_HALF + 0.6;
  const vmax = onRoad ? MAX_SPEED : GRASS_MAX;

  if (input.gas) state.speed += ACCEL * dt;
  if (input.brake) {
    if (state.speed > 0.2) state.speed -= BRAKE * dt;
    else state.speed = Math.max(-REVERSE_MAX, state.speed - ACCEL * dt);
  }
  if (!input.gas && !input.brake) {
    state.speed -= Math.sign(state.speed) * Math.min(Math.abs(state.speed), DRAG * dt);
  }
  // grass slows the car down gently
  if (!onRoad && state.speed > vmax) state.speed = lerp(state.speed, vmax, 1 - Math.exp(-dt * 3));
  state.speed = clamp(state.speed, -REVERSE_MAX, vmax);

  const steerTarget = (input.left ? 1 : 0) - (input.right ? 1 : 0);
  state.steer = lerp(state.steer, steerTarget, 1 - Math.exp(-dt * 8));
  const turnRate = 1.9 * state.steer * clamp(Math.abs(state.speed) / 6, 0, 1) * Math.sign(state.speed || 1);
  state.heading += turnRate * dt;

  state.x += Math.sin(state.heading) * state.speed * dt;
  state.z += Math.cos(state.heading) * state.speed * dt;

  // push out of trees and houses
  for (const o of obstacles) {
    const dx = state.x - o.x;
    const dz = state.z - o.z;
    const d = Math.hypot(dx, dz);
    const minD = o.r + 1.4;
    if (d < minD && d > 0.0001) {
      const push = minD - d;
      state.x += (dx / d) * push;
      state.z += (dz / d) * push;
      state.speed *= 0.6;
    }
  }
  // the world edge
  state.x = clamp(state.x, -440, 440);
  state.z = clamp(state.z, -440, 440);

  state.wheelSpin += state.speed * dt / 0.44;
  return { onRoad };
}

function updateCarVisuals(dt, t) {
  carRoot.position.set(state.x, 0, state.z);
  carRoot.rotation.y = state.heading;
  car.group.position.y = 0;
  // a little body roll when turning
  car.group.rotation.z = -state.steer * clamp(state.speed / MAX_SPEED, 0, 1) * 0.05;
  for (const w of car.wheels) {
    w.rotation.x = state.wheelSpin;
  }
  // the front wheels follow the steering
  car.wheels[0].rotation.y = state.steer * 0.45;
  car.wheels[1].rotation.y = state.steer * 0.45;
  // headlights: the glow flickers slightly so it feels alive
  car.group.traverse((o) => {
    if (o.material && o.material.emissiveIntensity !== undefined && o.material.emissive && o.material.emissive.getHex() === 0xffe680) {
      o.material.emissiveIntensity = 1.1 + Math.sin(t * 9) * 0.05;
    }
  });
}

// -------------------------------------------------------------- engine sfx ---
function updateEngine(dt, onRoad) {
  if (!ctx || !engineOsc) return;
  const v = Math.abs(state.speed);
  const throttle = input.gas ? 1 : 0;
  const pitch = 55 + v * 5.5 + throttle * 40;
  engineOsc.frequency.setTargetAtTime(pitch, ctx.currentTime, 0.08);
  const level = (v > 0.2 ? 0.07 + v * 0.008 : 0.02) * (settings.sfx ? 1 : 0);
  engineGain.gain.setTargetAtTime(level, ctx.currentTime, 0.1);
}

// -------------------------------------------------------------- game flow ---
let collected = 0;
let doneShown = false;
let running = false;

function collectStar(s) {
  s.got = true;
  s.mesh.visible = false;
  collected++;
  document.getElementById('stars').textContent = String(collected);
  beep([784, 988, 1175, 1568]);
  say('Получилось! Молодец!');
  if (collected === STAR_COUNT && !doneShown) {
    doneShown = true;
    beep([523, 659, 784, 1046, 1318], 0.1, 0.25);
    setTimeout(() => say('Ура! Все звёздочки собраны!'), 900);
    const d = document.getElementById('done');
    d.style.opacity = '1';
    setTimeout(() => { d.style.opacity = '0'; }, 3200);
  }
}

function resetStars() {
  collected = 0;
  doneShown = false;
  document.getElementById('stars').textContent = '0';
  for (const s of stars) { s.got = false; s.mesh.visible = true; }
}

function updateStars(t) {
  for (const s of stars) {
    if (s.got) continue;
    s.mesh.rotation.y = t * 1.8 + s.phase;
    s.mesh.position.y = s.base + Math.sin(t * 2.2 + s.phase) * 0.25;
    if (Math.hypot(s.mesh.position.x - state.x, s.mesh.position.z - state.z) < 2.6) {
      collectStar(s);
    }
  }
}

function menu() {
  running = false;
  input.gas = input.brake = input.left = input.right = false;
  document.getElementById('overlay').style.display = 'flex';
  if (ctx && engineGain) engineGain.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
  if ('speechSynthesis' in window) speechSynthesis.cancel();
}

document.getElementById('start').addEventListener('click', () => {
  initAudio();
  if (ctx.state === 'suspended') ctx.resume();
  document.getElementById('overlay').style.display = 'none';
  running = true;
  say('Привет! Давай покатаемся!');
});
document.getElementById('tMusic').addEventListener('click', () => { initAudio(); toggleMusic(); });
document.getElementById('tSfx').addEventListener('click', () => { initAudio(); toggleSfx(); });
document.getElementById('tVoice').addEventListener('click', toggleVoice);
document.getElementById('tCam').addEventListener('click', toggleCamera);
document.getElementById('btnMenu').addEventListener('click', () => {
  menu();
});
document.getElementById('total').textContent = String(STAR_COUNT);
syncToggles();

// ------------------------------------------------------------------- loop ---
let last = performance.now();
let time = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  time += dt;

  if (running) {
    const { onRoad } = stepCar(dt);
    updateEngine(dt, onRoad);
    updateStars(time);
    if (input.brake === false && input.gas === false && Math.abs(state.speed) < 0.05) {
      state.speed = 0;
    }
  }
  updateCarVisuals(dt, time);
  for (const c of clouds) {
    c.position.x += dt * 1.2;
    if (c.position.x > 180) c.position.x = -180;
  }
  // the sun follows the car so shadows stay sharp around it
  sun.position.set(state.x + 60, 90, state.z + 40);
  sun.target.position.set(state.x, 0, state.z);
  updateCamera(dt);
  renderer.render(scene, camera);
}

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

requestAnimationFrame((t) => { last = t; frame(t); });

// Exposed for quick checks in the browser console.
window.__demo = { state, input, stars, get collected() { return collected; }, resetStars, menu };
