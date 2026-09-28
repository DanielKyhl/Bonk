// Momentum Lab: a top-down survivor prototype built around movement.
// The map is a real heightfield, so jumps, slides, crests, ramps and landings
// use actual slope physics even though everything is drawn in 2D.
'use strict';
(() => {

// ---------------------------------------------------------------------------
// Tuning. Everything that shapes how movement feels lives here.
// 1 world unit is about 1 px at zoom 1, and 24 units = 1 m.
// ---------------------------------------------------------------------------
const CFG = {
  gravity: 2200,
  jumpVel: 640,            // apex ~93 units (3.9 m), ~0.58 s of air on flat ground
  runSpeed: 300,           // 45 km/h
  groundAccel: 2600,
  stopDecel: 2800,
  overspeedDecel: 620,     // extra speed bleeds off this fast once you stay on the ground
  brakeDecel: 2400,
  groundTurn: 7,           // rad/s of steering while running faster than run speed
  airTurn: 2.6,
  airAccel: 1100,
  airBrake: 420,
  hopWindowBefore: 0.14,   // a jump pressed this long before landing still counts as perfect
  hopWindowAfter: 0.07,    // ...or this long after landing
  hopBoost: 0.12,          // a perfect hop adds 12% speed...
  hopCap: 820,             // ...up to this speed (123 km/h)
  slideMinSpeed: 140,
  slideBoost: 110,         // kick when a slide starts
  slideBoostCd: 0.9,
  slideFriction: 150,
  slideTurn: 1.5,
  slopeSlide: 2300,        // downhill pull while sliding, per unit of gradient
  slopeRun: 380,           // downhill pull while running
  slamVel: 1700,
  slamBoost: 260,          // speed from sliding out of a slam (up to hopCap + 150)
  padLaunch: 1150,
  coyote: 0.08,
  stepHeight: 20,          // taller than this per step counts as a wall (ramp sides)
  maxSpeed: 2200,
};

const WORLD = 4000;
const CENTER = WORLD / 2;
const KMH = 3.6 / 24;       // world units per second -> km/h
const CONTOUR = 24;         // contour interval: 1 m
const GRAV = CFG.gravity;
const PR = 13;              // player radius
const TAU = Math.PI * 2;
const MAX_ENEMIES = 600;
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
function mulberry32(a) {
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
// Rotate unit vector (x, y) toward unit vector (tx, ty) by at most maxAng radians.
const ROT = { x: 0, y: 0 };
function rotateToward(x, y, tx, ty, maxAng) {
  const a = clamp(Math.atan2(x * ty - y * tx, x * tx + y * ty), -maxAng, maxAng);
  const c = Math.cos(a), s = Math.sin(a);
  ROT.x = x * c - y * s;
  ROT.y = x * s + y * c;
}

// ---------------------------------------------------------------------------
// Terrain: rolling ground + gaussian hills and bowls + a raised rim, plus ramps.
// ground(x, y) returns the height and leaves the gradient in gx, gy.
// ---------------------------------------------------------------------------
const hills = [];
const ramps = [];
const BIN = 250, BN = WORLD / BIN;
const bins = [];
let gx = 0, gy = 0;

function addHill(x, y, h, s) {
  hills.push({ x, y, h, s, inv: 1 / (2 * s * s), r2: (4 * s) * (4 * s) });
}

function addRamp(x, y, ang, L = 150, width = 96, h = 92) {
  const dx = Math.cos(ang), dy = Math.sin(ang), hw = width / 2;
  const lx = x + dx * L, ly = y + dy * L, nx = -dy * hw, ny = dx * hw;
  const xs = [x + nx, x - nx, lx + nx, lx - nx], ys = [y + ny, y - ny, ly + ny, ly - ny];
  ramps.push({
    x, y, dx, dy, L, hw, H: h, slope: h / L, cx: (x + lx) / 2, cy: (y + ly) / 2,
    x0: Math.min(...xs), x1: Math.max(...xs), y0: Math.min(...ys), y1: Math.max(...ys),
  });
}

function buildWorld() {
  const rnd = mulberry32(20250917);
  const farFromSpawn = (x, y, d) => Math.hypot(x - CENTER, y - CENTER) > d;
  const inside = (m) => m + rnd() * (WORLD - 2 * m);

  // Hand-placed features near spawn so each trick has an obvious place to try it.
  addHill(CENTER + 430, CENTER - 280, 230, 260);   // Big Hill
  addHill(CENTER - 520, CENTER + 330, -170, 240);  // The Bowl
  addHill(CENTER + 230, CENTER + 420, 62, 72);     // Kicker bump
  addRamp(CENTER - 90, CENTER + 175, 0);           // first ramp, pointing east

  let n = 0;
  while (n < 16) { const x = inside(300), y = inside(300); if (!farFromSpawn(x, y, 850)) continue; addHill(x, y, 110 + rnd() * 170, 200 + rnd() * 260); n++; }
  n = 0;
  while (n < 7) { const x = inside(350), y = inside(350); if (!farFromSpawn(x, y, 900)) continue; addHill(x, y, -(90 + rnd() * 90), 190 + rnd() * 170); n++; }
  n = 0;
  while (n < 70) { const x = inside(250), y = inside(250); if (!farFromSpawn(x, y, 380)) continue; addHill(x, y, 35 + rnd() * 45, 55 + rnd() * 45); n++; }
  n = 0;
  while (n < 18) {
    const x = inside(420), y = inside(420);
    if (!farFromSpawn(x, y, 500) || ramps.some((r) => Math.hypot(r.cx - x, r.cy - y) < 400)) continue;
    addRamp(x, y, rnd() * TAU); n++;
  }

  for (let i = 0; i < BN * BN; i++) bins.push([]);
  hills.forEach((hl, i) => {
    const r = 4 * hl.s;
    const bx0 = clamp(Math.floor((hl.x - r) / BIN), 0, BN - 1), bx1 = clamp(Math.floor((hl.x + r) / BIN), 0, BN - 1);
    const by0 = clamp(Math.floor((hl.y - r) / BIN), 0, BN - 1), by1 = clamp(Math.floor((hl.y + r) / BIN), 0, BN - 1);
    for (let by = by0; by <= by1; by++) for (let bx = bx0; bx <= bx1; bx++) bins[by * BN + bx].push(i);
  });

  const prnd = mulberry32(77);
  pads.push({ x: CENTER - 190, y: CENTER - 150, r: 30, flash: 0 });
  while (pads.length < 34) {
    const x = 320 + prnd() * (WORLD - 640), y = 320 + prnd() * (WORLD - 640);
    if (!farFromSpawn(x, y, 300)) continue;
    if (pads.some((q) => Math.hypot(q.x - x, q.y - y) < 260) || ramps.some((r) => Math.hypot(r.cx - x, r.cy - y) < 180)) continue;
    pads.push({ x, y, r: 30, flash: 0 });
  }

  for (const hl of hills) {
    if (hl.h > 150) spots.push({ x: hl.x, y: hl.y, text: `▲ ${(baseGround(hl.x, hl.y) / 24).toFixed(1)}` });
  }
}

const RIM = 280, RIM_H = 420;
function baseGround(x, y) {
  const sx = Math.sin(x / 310), cx = Math.cos(x / 310), sy = Math.sin(y / 270), cy = Math.cos(y / 270);
  const sxy = Math.sin((x + y) / 190), cxy = Math.cos((x + y) / 190);
  let h = 18 * sx * cy + 12 * sxy;
  let dx = (18 / 310) * cx * cy + (12 / 190) * cxy;
  let dy = -(18 / 270) * sx * sy + (12 / 190) * cxy;

  const list = bins[clamp((y / BIN) | 0, 0, BN - 1) * BN + clamp((x / BIN) | 0, 0, BN - 1)];
  for (let i = 0; i < list.length; i++) {
    const hl = hills[list[i]];
    const ox = x - hl.x, oy = y - hl.y, d2 = ox * ox + oy * oy;
    if (d2 > hl.r2) continue;
    const e = hl.h * Math.exp(-d2 * hl.inv), k = -2 * hl.inv * e;
    h += e; dx += k * ox; dy += k * oy;
  }

  // A raised rim keeps you in the map and doubles as a quarter-pipe.
  if (x < RIM) { const t = (RIM - x) / RIM; h += RIM_H * t * t; dx -= (2 * RIM_H * t) / RIM; }
  else if (x > WORLD - RIM) { const t = (x - WORLD + RIM) / RIM; h += RIM_H * t * t; dx += (2 * RIM_H * t) / RIM; }
  if (y < RIM) { const t = (RIM - y) / RIM; h += RIM_H * t * t; dy -= (2 * RIM_H * t) / RIM; }
  else if (y > WORLD - RIM) { const t = (y - WORLD + RIM) / RIM; h += RIM_H * t * t; dy += (2 * RIM_H * t) / RIM; }

  gx = dx; gy = dy;
  return h;
}

function ground(x, y) {
  const h = baseGround(x, y);
  for (let i = 0; i < ramps.length; i++) {
    const r = ramps[i];
    if (x < r.x0 || x > r.x1 || y < r.y0 || y > r.y1) continue;
    const ox = x - r.x, oy = y - r.y;
    const u = ox * r.dx + oy * r.dy;
    if (u < 0 || u > r.L) continue;
    const w = -ox * r.dy + oy * r.dx;
    if (w < -r.hw || w > r.hw) continue;
    gx += r.slope * r.dx; gy += r.slope * r.dy;
    return h + r.slope * u;
  }
  return h;
}

// Paint the map once: hypsometric tint, hillshade and 1 m contour lines.
const TEX = 2, GRID = 8, GN = WORLD / GRID + 1;
function paintTerrain() {
  // Heights and exact gradients on a grid; interpolating both keeps the shading smooth.
  const HG = new Float32Array(GN * GN), HX = new Float32Array(GN * GN), HY = new Float32Array(GN * GN);
  for (let j = 0; j < GN; j++) {
    for (let i = 0; i < GN; i++) { const q = j * GN + i; HG[q] = baseGround(i * GRID, j * GRID); HX[q] = gx; HY[q] = gy; }
  }

  const stops = [[-260, 0x16323a], [-90, 0x1e4443], [0, 0x2a5243], [90, 0x4b6843], [170, 0x7a7a4a], [260, 0xa58e5d], [360, 0xcab68a], [640, 0xe4dbc0]];
  const LUT_MIN = -400, LUT_N = 1400;
  const LR = new Float32Array(LUT_N), LG = new Float32Array(LUT_N), LB = new Float32Array(LUT_N);
  for (let i = 0; i < LUT_N; i++) {
    const h = i + LUT_MIN;
    let k = 0;
    while (k < stops.length - 2 && h > stops[k + 1][0]) k++;
    const [h0, c0] = stops[k], [h1, c1] = stops[k + 1];
    const t = clamp((h - h0) / (h1 - h0), 0, 1);
    LR[i] = lerp((c0 >> 16) & 255, (c1 >> 16) & 255, t);
    LG[i] = lerp((c0 >> 8) & 255, (c1 >> 8) & 255, t);
    LB[i] = lerp(c0 & 255, c1 & 255, t);
  }

  const n = WORLD / TEX;
  const cv = document.createElement('canvas');
  cv.width = cv.height = n;
  const c = cv.getContext('2d');
  const img = c.createImageData(n, n), px = img.data;
  const EX = 1.8;  // hillshade exaggeration
  let Lx = -0.5, Ly = -0.62, Lz = 0.6;
  const ll = Math.hypot(Lx, Ly, Lz); Lx /= ll; Ly /= ll; Lz /= ll;
  let o = 0;
  for (let j = 0; j < n; j++) {
    const wy = (j + 0.5) * TEX, fy = wy / GRID, iy = fy | 0, ty = fy - iy;
    for (let i = 0; i < n; i++) {
      const wx = (i + 0.5) * TEX, fx = wx / GRID, ix = fx | 0, tx = fx - ix;
      const q0 = iy * GN + ix;
      const a = HG[q0], b = HG[q0 + 1], cc = HG[q0 + GN], d = HG[q0 + GN + 1];
      const h = (a + (b - a) * tx) * (1 - ty) + (cc + (d - cc) * tx) * ty;
      const dx = (HX[q0] + (HX[q0 + 1] - HX[q0]) * tx) * (1 - ty) + (HX[q0 + GN] + (HX[q0 + GN + 1] - HX[q0 + GN]) * tx) * ty;
      const dy = (HY[q0] + (HY[q0 + 1] - HY[q0]) * tx) * (1 - ty) + (HY[q0 + GN] + (HY[q0 + GN + 1] - HY[q0 + GN]) * tx) * ty;

      const li = clamp((h - LUT_MIN) | 0, 0, LUT_N - 1);
      let r = LR[li], g = LG[li], bl = LB[li];

      const nl = 1 / Math.sqrt(dx * dx * EX * EX + dy * dy * EX * EX + 1);
      const sh = (-dx * EX * Lx - dy * EX * Ly + Lz) * nl;
      const f = clamp(1 + (sh - Lz) * 1.15, 0.55, 1.35);
      r *= f; g *= f; bl *= f;

      const gm = Math.sqrt(dx * dx + dy * dy);
      if (gm > 0.004) {
        const qf = h / CONTOUR, qi = Math.round(qf);
        const dist = (Math.abs(qf - qi) * CONTOUR) / gm / TEX;   // distance to the nearest contour, in texels
        const major = qi % 5 === 0;
        const al = clamp((major ? 1.0 : 0.6) - dist + 0.5, 0, 1) * (major ? 0.42 : 0.2);
        if (al > 0) { r += (236 - r) * al; g += (240 - g) * al; bl += (228 - bl) * al; }
      }
      if (wx % 500 < TEX || wy % 500 < TEX) { r += (236 - r) * 0.07; g += (240 - g) * 0.07; bl += (228 - bl) * 0.07; }

      px[o] = r; px[o + 1] = g; px[o + 2] = bl; px[o + 3] = 255;
      o += 4;
    }
  }
  c.putImageData(img, 0, 0);
  return cv;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const pads = [];
const spots = [];
const LABELS = [
  { x: CENTER + 430, y: CENTER - 170, text: 'BIG HILL', sub: 'slide down it' },
  { x: CENTER - 520, y: CENTER + 330, text: 'THE BOWL', sub: 'slide in, hop out' },
  { x: CENTER + 230, y: CENTER + 500, text: 'KICKER', sub: 'hit it fast' },
  { x: CENTER - 20, y: CENTER + 250, text: 'RAMP', sub: 'jump off the lip' },
];
const ETYPES = [
  { name: 'grunt', r: 12, h: 26, speed: 150, hp: 20, dmg: 8, xp: 1, color: '#ff4d6d' },
  { name: 'runner', r: 9, h: 20, speed: 238, hp: 12, dmg: 6, xp: 1, color: '#ffa0c8' },
  { name: 'brute', r: 22, h: 46, speed: 100, hp: 150, dmg: 18, xp: 6, color: '#b52f6e' },
];
const enemies = [];
const bolts = [];
const gems = [];
const flames = [];
const waves = [];
const parts = [];
const texts = [];
let partI = 0;

const game = { state: 'title', t: 0, kills: 0, spawnAcc: 0, nextRing: 25, ring: 0, banner: null, choices: [], levelOpenAt: 0, burnTick: 0 };
const cam = { x: CENTER, y: CENTER, zoom: 1, shake: 0 };
const view = { x0: 0, y0: 0, x1: 0, y1: 0 };
const player = {};

const keys = new Set();
const input = { jumpHeld: false, jumpSeq: 0, slideHeld: false, slideSeq: 0, mx: 0, my: 0, tJump: false, tSlide: false };
const JUMP_KEYS = ['Space', 'KeyJ'];
const SLIDE_KEYS = ['ShiftLeft', 'ShiftRight', 'KeyC', 'KeyK'];
const GAME_KEYS = new Set(['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ShiftLeft', 'ShiftRight']);

const xpNeed = (lv) => Math.round(3 + lv * 3 + lv * lv * 0.6);

function resetPlayer() {
  Object.assign(player, {
    x: CENTER, y: CENTER, z: 0, vx: 0, vy: 0, vz: 0, wx: 0, wy: 0, fx: 1, fy: 0,
    grounded: true, sliding: false, slideAir: false, slamming: false,
    groundTime: 1, air: 0, lastAir: 0, coyote: 0, chain: 0, jumpBuf: -1,
    jumpSeen: input.jumpSeq, slideSeen: input.slideSeq,
    airJumpsLeft: 0, slideCd: 0, padCd: 0, iframes: 0, hurt: 0, squash: 0,
    hp: 100, maxHp: 100, xp: 0, level: 1, need: xpNeed(1), pending: 0,
    boltT: 0.5, burnDist: 0, trailT: 0, trail: [],
    best: { speed: 0, chain: 0, air: 0 },
    lv: {},
    st: {
      runSpeed: CFG.runSpeed, jumpVel: CFG.jumpVel, airJumps: 0, hopBoost: CFG.hopBoost, hopCap: CFG.hopCap,
      slideFriction: CFG.slideFriction, slideBoost: CFG.slideBoost, airTurn: CFG.airTurn, airAccel: CFG.airAccel,
      bonkMult: 1, landMult: 1, slamRadius: 1, momentum: 0.5, fireRate: 2.5, bolts: 1, pierce: 0, burn: 0, magnet: 110,
    },
  });
  player.z = ground(player.x, player.y);
}

// ---------------------------------------------------------------------------
// Spatial hash for enemies (rebuilt every frame with a counting sort)
// ---------------------------------------------------------------------------
const HC = 64, HN = Math.ceil(WORLD / HC);
const cellCount = new Int32Array(HN * HN), cellStart = new Int32Array(HN * HN);
let sorted = new Int32Array(1024);
const near = new Int32Array(2048);

function rebuildHash() {
  const n = enemies.length;
  if (sorted.length < n) sorted = new Int32Array(n * 2);
  cellCount.fill(0);
  for (let i = 0; i < n; i++) {
    const e = enemies[i];
    e.cell = clamp((e.y / HC) | 0, 0, HN - 1) * HN + clamp((e.x / HC) | 0, 0, HN - 1);
    cellCount[e.cell]++;
  }
  let acc = 0;
  for (let c = 0; c < cellCount.length; c++) { cellStart[c] = acc; acc += cellCount[c]; cellCount[c] = 0; }
  for (let i = 0; i < n; i++) { const c = enemies[i].cell; sorted[cellStart[c] + cellCount[c]++] = i; }
}

// Fills `near` with indices of enemies in cells overlapping the circle. Returns the count.
function queryNear(x, y, r) {
  let n = 0;
  const x0 = Math.max(0, ((x - r) / HC) | 0), x1 = Math.min(HN - 1, ((x + r) / HC) | 0);
  const y0 = Math.max(0, ((y - r) / HC) | 0), y1 = Math.min(HN - 1, ((y + r) / HC) | 0);
  for (let cy = y0; cy <= y1; cy++) {
    for (let cx = x0; cx <= x1; cx++) {
      const c = cy * HN + cx, s1 = cellStart[c] + cellCount[c];
      for (let k = cellStart[c]; k < s1 && n < near.length; k++) near[n++] = sorted[k];
    }
  }
  return n;
}

// ---------------------------------------------------------------------------
// Player movement
// ---------------------------------------------------------------------------
function readWish() {
  const p = player;
  let x = input.mx, y = input.my;
  if (keys.has('KeyA') || keys.has('ArrowLeft')) x -= 1;
  if (keys.has('KeyD') || keys.has('ArrowRight')) x += 1;
  if (keys.has('KeyW') || keys.has('ArrowUp')) y -= 1;
  if (keys.has('KeyS') || keys.has('ArrowDown')) y += 1;
  const l = Math.hypot(x, y);
  if (l < 0.25) { p.wx = 0; p.wy = 0; return false; }
  p.wx = x / l; p.wy = y / l;
  return true;
}

function setSpeed(p, ns) {
  const sp = Math.hypot(p.vx, p.vy);
  if (sp > 0.001) { p.vx *= ns / sp; p.vy *= ns / sp; }
}

function onJumpPress() {
  const p = player;
  if (p.grounded) { p.jumpBuf = game.t; return; }
  if (p.coyote > 0 && !p.slamming) {
    // Jumping right after the ground drops away (a crest or a ramp lip) stacks on your upward speed.
    const big = p.vz > 150;
    p.vz = Math.max(p.vz, 0) + p.st.jumpVel;
    p.coyote = 0; p.jumpBuf = -1;
    dust(p.x, p.y, 8);
    if (big) floatText('LIP JUMP', '#ffd23f');
    return;
  }
  const hA = Math.max(0, p.z - ground(p.x, p.y));
  const tLand = (p.vz + Math.sqrt(p.vz * p.vz + 2 * GRAV * hA)) / GRAV;
  if (tLand > CFG.hopWindowBefore && p.airJumpsLeft > 0) airJump();
  else p.jumpBuf = game.t;   // close to landing: buffer it for a perfect hop
}

function onSlidePress() {
  const p = player;
  if (p.grounded || p.slamming) return;
  if (p.z - ground(p.x, p.y) > 22) {
    p.slamming = true;
    p.vz = -CFG.slamVel;
  }
}

function doJump(perfect) {
  const p = player, s = p.st;
  p.vz = s.jumpVel + Math.max(0, p.vz) * 0.7;   // jumping on an upslope carries its rise
  p.grounded = false; p.sliding = false; p.slideAir = false; p.air = 0; p.coyote = 0; p.jumpBuf = -1;
  p.airJumpsLeft = s.airJumps;
  if (perfect) {
    p.chain++;
    const sp = Math.hypot(p.vx, p.vy);
    if (sp > 60 && sp < s.hopCap) setSpeed(p, Math.min(s.hopCap, sp * (1 + s.hopBoost)));
    p.best.chain = Math.max(p.best.chain, p.chain);
    floatText(p.chain > 1 ? `HOP ×${p.chain}` : 'HOP', '#ff8a3d');
  }
  dust(p.x, p.y, perfect ? 7 : 4);
}

function airJump() {
  const p = player, s = p.st;
  p.airJumpsLeft--;
  p.vz = s.jumpVel * 0.92;
  p.slamming = false; p.jumpBuf = -1;
  if (p.wx || p.wy) {
    const sp = Math.hypot(p.vx, p.vy);
    if (sp > 1) { rotateToward(p.vx / sp, p.vy / sp, p.wx, p.wy, 1.3); p.vx = ROT.x * sp; p.vy = ROT.y * sp; }
    if (sp < s.runSpeed) { p.vx = p.wx * s.runSpeed; p.vy = p.wy * s.runSpeed; }
  }
  const hA = p.z - ground(p.x, p.y);
  for (let k = 0; k < 14; k++) { const a = (k / 14) * TAU; emit(p.x, p.y, hA, Math.cos(a) * 160, Math.sin(a) * 160, -40, 0.35, 4, '#fff4d6'); }
}

function startSlide(sp) {
  const p = player, s = p.st;
  p.sliding = true;
  if (p.slideCd <= 0 && sp < s.hopCap) {
    setSpeed(p, Math.min(s.hopCap, sp + s.slideBoost));
    p.slideCd = CFG.slideBoostCd;
    dust(p.x, p.y, 6);
  }
}

function moveRun(p, s, dt, hasWish, sgx, sgy) {
  let vx = p.vx, vy = p.vy, sp = Math.hypot(vx, vy);
  const R = s.runSpeed;
  const grace = p.groundTime <= CFG.hopWindowAfter;   // just landed: keep every bit of speed
  if (hasWish) {
    if (sp <= R + 1) {
      const tx = p.wx * R - vx, ty = p.wy * R - vy, tl = Math.hypot(tx, ty), step = CFG.groundAccel * dt;
      if (tl <= step) { vx = p.wx * R; vy = p.wy * R; } else { vx += (tx / tl) * step; vy += (ty / tl) * step; }
    } else {
      // Carrying momentum: steer, and let the extra speed bleed off slowly.
      const dx = vx / sp, dy = vy / sp;
      if (dx * p.wx + dy * p.wy < -0.3) sp = Math.max(0, sp - CFG.brakeDecel * dt);
      else if (!grace) sp = Math.max(R, sp - CFG.overspeedDecel * dt);
      rotateToward(dx, dy, p.wx, p.wy, CFG.groundTurn * dt);
      vx = ROT.x * sp; vy = ROT.y * sp;
    }
  } else if (!grace || sp <= R) {
    const dec = (sp > R ? CFG.overspeedDecel * 1.8 : CFG.stopDecel) * dt;
    if (sp <= dec) { vx = 0; vy = 0; } else { vx -= (vx / sp) * dec; vy -= (vy / sp) * dec; }
  }
  p.vx = vx - sgx * CFG.slopeRun * dt;
  p.vy = vy - sgy * CFG.slopeRun * dt;
}

function moveSlide(p, s, dt, hasWish, sgx, sgy) {
  let vx = p.vx, vy = p.vy, sp = Math.hypot(vx, vy);
  if (sp > 1) {
    let dx = vx / sp, dy = vy / sp;
    if (hasWish) { rotateToward(dx, dy, p.wx, p.wy, CFG.slideTurn * dt); dx = ROT.x; dy = ROT.y; }
    sp = Math.max(0, sp - s.slideFriction * dt);
    vx = dx * sp; vy = dy * sp;
  }
  p.vx = vx - sgx * CFG.slopeSlide * dt;
  p.vy = vy - sgy * CFG.slopeSlide * dt;
  if (!input.slideHeld || Math.hypot(p.vx, p.vy) < 90) p.sliding = false;
}

function moveAir(p, s, dt, hasWish) {
  if (!hasWish) return;
  let vx = p.vx, vy = p.vy, sp = Math.hypot(vx, vy);
  const R = s.runSpeed;
  if (sp < R * 0.9) {
    const tx = p.wx * R - vx, ty = p.wy * R - vy, tl = Math.hypot(tx, ty), step = s.airAccel * dt;
    if (tl <= step) { vx = p.wx * R; vy = p.wy * R; } else { vx += (tx / tl) * step; vy += (ty / tl) * step; }
  } else {
    const dx = vx / sp, dy = vy / sp;
    if (dx * p.wx + dy * p.wy < -0.5) sp = Math.max(R * 0.9, sp - CFG.airBrake * dt);
    rotateToward(dx, dy, p.wx, p.wy, s.airTurn * dt);
    vx = ROT.x * sp; vy = ROT.y * sp;
  }
  p.vx = vx; p.vy = vy;
}

function updatePlayer(dt) {
  const p = player, s = p.st;
  const hasWish = readWish();
  p.slideCd -= dt; p.padCd -= dt; p.iframes -= dt; p.hurt = Math.max(0, p.hurt - dt);
  p.squash = Math.max(0, p.squash - dt * 5);

  if (input.jumpSeq !== p.jumpSeen) { p.jumpSeen = input.jumpSeq; onJumpPress(); }
  if (input.slideSeq !== p.slideSeen) { p.slideSeen = input.slideSeq; onSlidePress(); }

  if (p.grounded) {
    p.groundTime += dt;
    const buffered = p.jumpBuf >= 0 && game.t - p.jumpBuf <= CFG.hopWindowBefore;
    const inWindow = p.groundTime <= CFG.hopWindowAfter && p.lastAir >= 0.15;
    if (buffered) doJump(inWindow);
    else if (input.jumpHeld && inWindow) doJump(false);   // auto-hop keeps speed, no boost
    else if (p.chain && p.groundTime > CFG.hopWindowAfter) p.chain = 0;
  }

  const g0 = ground(p.x, p.y);
  const sgx = gx, sgy = gy;

  if (p.grounded) {
    const sp = Math.hypot(p.vx, p.vy);
    if (!p.sliding && input.slideHeld && sp > CFG.slideMinSpeed) startSlide(sp);
    if (p.sliding) moveSlide(p, s, dt, hasWish, sgx, sgy);
    else moveRun(p, s, dt, hasWish, sgx, sgy);
  } else {
    moveAir(p, s, dt, hasWish);
  }
  const sp = Math.hypot(p.vx, p.vy);
  if (sp > CFG.maxSpeed) setSpeed(p, CFG.maxSpeed);
  if (sp > 20) { p.fx = p.vx / sp; p.fy = p.vy / sp; } else if (hasWish) { p.fx = p.wx; p.fy = p.wy; }

  // Move, treating anything taller than a step (ramp sides) as a wall.
  const ox = p.x, oy = p.y;
  p.x = clamp(p.x + p.vx * dt, 20, WORLD - 20);
  p.y = clamp(p.y + p.vy * dt, 20, WORLD - 20);
  let g1 = ground(p.x, p.y);
  if (g1 - p.z > CFG.stepHeight) {
    p.y = oy;
    if (ground(p.x, p.y) - p.z > CFG.stepHeight) { p.x = ox; p.vx = 0; }
    p.y = clamp(oy + p.vy * dt, 20, WORLD - 20);
    if (ground(p.x, p.y) - p.z > CFG.stepHeight) { p.y = oy; p.vy = 0; }
    g1 = ground(p.x, p.y);
  }
  const ngx = gx, ngy = gy;

  if (p.grounded) {
    // Follow the ground unless it falls away faster than gravity would pull us down.
    const zb = p.z + p.vz * dt - 0.5 * GRAV * dt * dt;
    if (zb > g1 + 0.02) {
      p.grounded = false; p.z = zb; p.vz -= GRAV * dt;
      p.air = 0; p.coyote = CFG.coyote; p.airJumpsLeft = s.airJumps;
      p.slideAir = p.sliding;   // a slide that pops off a bump is still a slide
      p.sliding = false;
    } else {
      p.z = g1;
      p.vz = (g1 - g0) / dt;
    }
  } else {
    const prevZ = p.z;
    p.vz -= GRAV * dt;
    p.z += p.vz * dt;
    p.air += dt; p.coyote -= dt;
    if (!(p.vz < 0 && checkStomp(prevZ)) && p.z <= g1) land(g1, ngx, ngy);
  }

  if (p.grounded && p.padCd <= 0) {
    for (const pad of pads) {
      const dx = p.x - pad.x, dy = p.y - pad.y;
      if (dx * dx + dy * dy > pad.r * pad.r) continue;
      p.grounded = false; p.sliding = false; p.slideAir = false; p.vz = CFG.padLaunch; p.air = 0; p.coyote = 0;
      p.airJumpsLeft = s.airJumps; p.padCd = 0.4; pad.flash = 0.35;
      addShake(4);
      for (let k = 0; k < 18; k++) { const a = (k / 18) * TAU; emit(pad.x, pad.y, 4, Math.cos(a) * 220, Math.sin(a) * 220, 120, 0.45, 4, '#ffd23f'); }
      break;
    }
  }
}

function land(g1, ngx, ngy) {
  const p = player, s = p.st;
  const impact = -p.vz;
  // Keep the part of the velocity that runs along the surface:
  // landing on a downslope turns fall speed into ground speed, an upslope eats it.
  const nl = Math.sqrt(ngx * ngx + ngy * ngy + 1);
  const nx = -ngx / nl, ny = -ngy / nl, nz = 1 / nl;
  const vn = p.vx * nx + p.vy * ny + p.vz * nz;
  if (vn < 0) { p.vx -= vn * nx; p.vy -= vn * ny; }
  const sp = Math.hypot(p.vx, p.vy);
  if (sp > CFG.maxSpeed) setSpeed(p, CFG.maxSpeed);

  p.z = g1; p.grounded = true; p.slideAir = false;
  p.vz = ngx * p.vx + ngy * p.vy;
  const airT = p.air;
  if (airT >= 0.1) { p.groundTime = 0; p.lastAir = airT; }   // tiny hops over bumps don't count as landings
  if (airT > p.best.air) p.best.air = airT;
  if (airT > 1.0) floatText(`AIR ${airT.toFixed(1)}s`, '#6ee7f0');

  if (p.slamming) slamImpact(impact);
  else if (airT >= 0.1) { p.squash = Math.min(1, impact / 1500); dust(p.x, p.y, 3 + Math.min(8, impact / 150)); }
  if (input.slideHeld && Math.hypot(p.vx, p.vy) > CFG.slideMinSpeed) p.sliding = true;   // slide landing keeps momentum
}

function slamImpact(impact) {
  const p = player, s = p.st;
  p.slamming = false;
  const power = clamp(impact / 1500, 0.6, 2.2);
  shockwave(p.x, p.y, (95 + 45 * power) * s.slamRadius, 18 * power * s.landMult);
  let sp = Math.hypot(p.vx, p.vy), dx = 0, dy = 0;
  if (sp > 40) { dx = p.vx / sp; dy = p.vy / sp; } else if (p.wx || p.wy) { dx = p.wx; dy = p.wy; sp = 0; }
  if (dx || dy) {
    const cap = s.hopCap + 150;
    const ns = sp < cap ? Math.min(cap, sp + CFG.slamBoost) : sp;
    p.vx = dx * ns; p.vy = dy * ns;
    p.sliding = true;
  }
  p.squash = 1;
  addShake(9 * power);
  floatText('SLAM', '#fff4d6');
}

function checkStomp(prevZ) {
  const p = player;
  const n = queryNear(p.x, p.y, 48);
  for (let i = 0; i < n; i++) {
    const e = enemies[near[i]];
    if (e.dead) continue;
    const dx = e.x - p.x, dy = e.y - p.y, rr = e.r + PR * 0.8;
    if (dx * dx + dy * dy > rr * rr) continue;
    const top = ground(e.x, e.y) + e.h;
    if (prevZ >= top - 1 && p.z <= top) { stomp(e, top); return true; }
  }
  return false;
}

function stomp(e, top) {
  const p = player, s = p.st;
  const slam = p.slamming;
  hurtEnemy(e, (slam ? 60 : 30) * s.landMult, p.vx * 0.3, p.vy * 0.3);
  if (slam) { p.slamming = false; shockwave(e.x, e.y, 120 * s.slamRadius, 22 * s.landMult); }
  p.z = top; p.slideAir = false;
  p.vz = s.jumpVel * (input.jumpHeld ? 1.05 : 0.82);
  p.air = 0; p.coyote = 0; p.airJumpsLeft = s.airJumps;
  p.chain++;
  p.best.chain = Math.max(p.best.chain, p.chain);
  const sp = Math.hypot(p.vx, p.vy);
  if (sp > 60 && sp < s.hopCap) setSpeed(p, Math.min(s.hopCap, sp * (1 + s.hopBoost)));
  floatText(`STOMP ×${p.chain}`, '#ff8a3d');
  addShake(4);
}

// ---------------------------------------------------------------------------
// Enemies, damage, pickups
// ---------------------------------------------------------------------------
function spawnEnemy(type, x, y) {
  const T = ETYPES[type], m = 1 + game.t / 100;
  enemies.push({
    type, x, y, kx: 0, ky: 0, r: T.r, h: T.h, speed: T.speed * (0.92 + Math.random() * 0.16),
    hp: T.hp * m, maxHp: T.hp * m, dmg: T.dmg, xp: T.xp, flash: 0, hitCd: 0, dead: false, cell: 0,
  });
}

const viewRadius = () => Math.hypot(W, H) / 2 / cam.zoom;
const SP = { x: 0, y: 0 };
function spawnPoint() {
  const p = player, R = viewRadius() + 70, sp = Math.hypot(p.vx, p.vy);
  // Fast players mostly meet enemies ahead of them instead of outrunning everything.
  const a = sp > 200 && Math.random() < 0.55 ? Math.atan2(p.vy, p.vx) + (Math.random() - 0.5) * 2 : Math.random() * TAU;
  SP.x = clamp(p.x + Math.cos(a) * R, 60, WORLD - 60);
  SP.y = clamp(p.y + Math.sin(a) * R, 60, WORLD - 60);
}

function pickType() {
  const t = game.t, r = Math.random();
  if (t > 70 && r < 0.06 + Math.min(0.08, (t - 70) / 3000)) return 2;
  if (t > 35 && r < 0.3) return 1;
  return 0;
}

function updateSpawns(dt) {
  const p = player;
  game.spawnAcc += (0.9 + game.t * 0.055) * dt;
  while (game.spawnAcc >= 1) {
    game.spawnAcc -= 1;
    if (enemies.length < MAX_ENEMIES) { spawnPoint(); spawnEnemy(pickType(), SP.x, SP.y); }
  }
  if (game.t >= game.nextRing) {
    game.ring++;
    game.nextRing += 40;
    const n = Math.min(26 + game.ring * 8, 90), R = Math.min(viewRadius() * 0.8, 560);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * TAU;
      spawnEnemy(game.t > 90 && i % 3 === 0 ? 1 : 0, clamp(p.x + Math.cos(a) * R, 60, WORLD - 60), clamp(p.y + Math.sin(a) * R, 60, WORLD - 60));
    }
    banner('Ring closing in. Jump it.');
  }
}

function updateEnemies(dt) {
  const p = player, far = viewRadius() * 1.9, kd = Math.exp(-5 * dt);
  for (let i = 0; i < enemies.length; i++) {
    const e = enemies[i];
    if (e.dead) continue;
    const dx = p.x - e.x, dy = p.y - e.y, d = Math.hypot(dx, dy) || 1;
    if (d > far) { spawnPoint(); e.x = SP.x; e.y = SP.y; continue; }   // left behind: re-enter ahead of the player
    e.x += ((dx / d) * e.speed + e.kx) * dt;
    e.y += ((dy / d) * e.speed + e.ky) * dt;
    e.kx *= kd; e.ky *= kd;
    e.flash -= dt; e.hitCd -= dt;
  }
  rebuildHash();

  // Separation: push overlapping enemies apart (lighter ones move more).
  for (let i = 0; i < enemies.length; i++) {
    const a = enemies[i];
    if (a.dead) continue;
    const cx = clamp((a.x / HC) | 0, 0, HN - 1), cy = clamp((a.y / HC) | 0, 0, HN - 1);
    for (let yy = Math.max(0, cy - 1); yy <= Math.min(HN - 1, cy + 1); yy++) {
      for (let xx = Math.max(0, cx - 1); xx <= Math.min(HN - 1, cx + 1); xx++) {
        const c = yy * HN + xx, s1 = cellStart[c] + cellCount[c];
        for (let k = cellStart[c]; k < s1; k++) {
          const j = sorted[k];
          if (j <= i) continue;
          const b = enemies[j];
          if (b.dead) continue;
          const dx = b.x - a.x, dy = b.y - a.y, rr = a.r + b.r, d2 = dx * dx + dy * dy;
          if (d2 >= rr * rr || d2 < 1e-6) continue;
          const d = Math.sqrt(d2), push = ((rr - d) * 0.6) / d / rr;
          a.x -= dx * push * b.r; a.y -= dy * push * b.r;
          b.x += dx * push * a.r; b.y += dy * push * a.r;
        }
      }
    }
  }

  // Contact with the player: slide tackles bonk, otherwise you get hurt unless you're above them.
  const s = p.st, hA = p.z - ground(p.x, p.y), sp = Math.hypot(p.vx, p.vy);
  const bonking = (p.sliding || p.slideAir) && sp >= 330;
  const n = queryNear(p.x, p.y, 50);
  for (let i = 0; i < n; i++) {
    const e = enemies[near[i]];
    if (e.dead) continue;
    const dx = e.x - p.x, dy = e.y - p.y, rr = e.r + PR, d2 = dx * dx + dy * dy;
    if (d2 > rr * rr || hA > e.h * 0.85) continue;
    if (bonking) {
      if (e.hitCd > 0) continue;
      e.hitCd = 0.3;
      const d = Math.sqrt(d2) || 1;
      hurtEnemy(e, 16 * (sp / 300) * s.bonkMult, (dx / d) * 420 + p.vx * 0.5, (dy / d) * 420 + p.vy * 0.5);
      burst(e.x, e.y, '#fff4d6', 5);
      addShake(2);
    } else if (p.iframes <= 0) {
      damagePlayer(e.dmg);
    }
  }
}

function hurtEnemy(e, dmg, kx, ky) {
  if (e.dead) return;
  e.hp -= dmg;
  e.flash = 0.09;
  const w = 12 / e.r;
  e.kx += kx * w; e.ky += ky * w;
  if (e.hp <= 0) {
    e.dead = true;
    game.kills++;
    dropGem(e.x, e.y, e.xp);
    if (Math.random() < 0.012) gems.push({ x: e.x, y: e.y, v: 20, heart: true, mag: false });
    burst(e.x, e.y, ETYPES[e.type].color, e.type === 2 ? 14 : 7);
  }
}

function shockwave(x, y, radius, dmg) {
  const n = queryNear(x, y, radius + 30);
  for (let i = 0; i < n; i++) {
    const e = enemies[near[i]];
    if (e.dead) continue;
    const dx = e.x - x, dy = e.y - y, d = Math.hypot(dx, dy) || 1;
    if (d > radius + e.r) continue;
    const f = 1 - (0.5 * Math.min(d, radius)) / radius;
    hurtEnemy(e, dmg * f, (dx / d) * 650 * f, (dy / d) * 650 * f);
  }
  waves.push({ x, y, r: radius, life: 0.35 });
  for (let k = 0; k < 24; k++) { const a = (k / 24) * TAU; emit(x, y, 3, Math.cos(a) * radius * 3, Math.sin(a) * radius * 3, 80, 0.3, 5, '#fff4d6'); }
}

function damagePlayer(d) {
  const p = player;
  p.hp -= d;
  p.iframes = 0.5;
  p.hurt = 0.3;
  addShake(6);
  if (p.hp <= 0) { p.hp = 0; die(); }
}

function dropGem(x, y, v) {
  if (gems.length > 380) { gems[(Math.random() * gems.length) | 0].v += v; return; }
  gems.push({ x, y, v, heart: false, mag: false });
}

function updateGems(dt) {
  const p = player, R = p.st.magnet, sp = Math.hypot(p.vx, p.vy);
  for (let i = gems.length - 1; i >= 0; i--) {
    const g = gems[i], dx = p.x - g.x, dy = p.y - g.y, d2 = dx * dx + dy * dy;
    if (!g.mag && d2 < R * R) g.mag = true;
    if (!g.mag) continue;
    const d = Math.sqrt(d2) || 1;
    if (d < 22) {
      gems[i] = gems[gems.length - 1]; gems.pop();
      if (g.heart) { p.hp = Math.min(p.maxHp, p.hp + g.v); floatText(`+${g.v}`, '#ff4d6d'); }
      else gainXp(g.v);
      continue;
    }
    const step = Math.min(d, (420 + sp * 1.1 + Math.max(0, R - d) * 3) * dt);   // always faster than you
    g.x += (dx / d) * step; g.y += (dy / d) * step;
  }
}

function gainXp(v) {
  const p = player;
  p.xp += v;
  while (p.xp >= p.need) { p.xp -= p.need; p.level++; p.need = xpNeed(p.level); p.pending++; }
  if (p.pending > 0 && game.state === 'play') openLevelUp();
}

// ---------------------------------------------------------------------------
// Weapons
// ---------------------------------------------------------------------------
const momentumMult = () => 1 + player.st.momentum * Math.max(0, Math.hypot(player.vx, player.vy) - CFG.runSpeed) / CFG.runSpeed;

function updateWeapons(dt) {
  const p = player, s = p.st;
  p.boltT -= dt;
  if (p.boltT <= 0) {
    let best = null, bd = 560 * 560;
    for (let i = 0; i < enemies.length; i++) {
      const e = enemies[i];
      if (e.dead) continue;
      const d2 = (e.x - p.x) ** 2 + (e.y - p.y) ** 2;
      if (d2 < bd) { bd = d2; best = e; }
    }
    if (best) {
      const mult = momentumMult(), base = Math.atan2(best.y - p.y, best.x - p.x);
      const hA = Math.max(0, p.z - ground(p.x, p.y));
      for (let k = 0; k < s.bolts; k++) {
        const a = base + (k - (s.bolts - 1) / 2) * 0.13, c = Math.cos(a), sn = Math.sin(a);
        const v = 900 + Math.max(0, p.vx * c + p.vy * sn);
        bolts.push({ x: p.x, y: p.y, vx: c * v, vy: sn * v, life: 0.75, max: 0.75, h: hA, dmg: 12 * mult, pierce: s.pierce, hits: [] });
      }
      p.boltT = 1 / s.fireRate;
    } else p.boltT = 0.1;
  }

  for (let i = bolts.length - 1; i >= 0; i--) {
    const b = bolts[i];
    b.life -= dt; b.x += b.vx * dt; b.y += b.vy * dt;
    if (b.life > 0) {
      const n = queryNear(b.x, b.y, 30);
      for (let k = 0; k < n; k++) {
        const e = enemies[near[k]];
        if (e.dead || b.hits.includes(e)) continue;
        const rr = e.r + 5;
        if ((e.x - b.x) ** 2 + (e.y - b.y) ** 2 > rr * rr) continue;
        hurtEnemy(e, b.dmg, b.vx * 0.25, b.vy * 0.25);
        b.hits.push(e);
        if (b.pierce-- <= 0) { b.life = 0; break; }
      }
    }
    if (b.life <= 0) { bolts[i] = bolts[bolts.length - 1]; bolts.pop(); }
  }

  // Afterburner: a burning trail while you're fast and low.
  if (s.burn > 0) {
    const sp = Math.hypot(p.vx, p.vy);
    if (sp > 533 && p.z - ground(p.x, p.y) < 30) {
      p.burnDist += sp * dt;
      while (p.burnDist > 34) { p.burnDist -= 34; flames.push({ x: p.x, y: p.y, life: 1.3 }); }
    }
    game.burnTick -= dt;
    if (game.burnTick <= 0) {
      game.burnTick = 0.15;
      const dmg = (12 + 10 * (s.burn - 1)) * 0.15;
      for (const f of flames) {
        const n = queryNear(f.x, f.y, 40);
        for (let k = 0; k < n; k++) {
          const e = enemies[near[k]];
          if (!e.dead && (e.x - f.x) ** 2 + (e.y - f.y) ** 2 < (22 + e.r) ** 2) hurtEnemy(e, dmg, 0, 0);
        }
      }
    }
  }
  for (let i = flames.length - 1; i >= 0; i--) {
    flames[i].life -= dt;
    if (flames[i].life <= 0) { flames[i] = flames[flames.length - 1]; flames.pop(); }
  }
}

// ---------------------------------------------------------------------------
// Effects
// ---------------------------------------------------------------------------
const PART_MAX = 500;
function emit(x, y, z, vx, vy, vz, life, size, color) {
  let o;
  if (parts.length < PART_MAX) { o = {}; parts.push(o); } else { o = parts[partI]; partI = (partI + 1) % PART_MAX; }
  o.x = x; o.y = y; o.z = z; o.vx = vx; o.vy = vy; o.vz = vz; o.life = life; o.max = life; o.size = size; o.color = color;
}
function dust(x, y, n) {
  for (let k = 0; k < n; k++) {
    const a = Math.random() * TAU, v = 40 + Math.random() * 120;
    emit(x, y, 2, Math.cos(a) * v, Math.sin(a) * v, 60 + Math.random() * 90, 0.4 + Math.random() * 0.25, 4, 'rgba(232,238,226,0.7)');
  }
}
function burst(x, y, color, n) {
  for (let k = 0; k < n; k++) {
    const a = Math.random() * TAU, v = 80 + Math.random() * 220;
    emit(x, y, 10, Math.cos(a) * v, Math.sin(a) * v, 100 + Math.random() * 200, 0.35 + Math.random() * 0.3, 4, color);
  }
}
function updateParticles(dt) {
  const damp = Math.exp(-3 * dt);
  for (const o of parts) {
    if (o.life <= 0) continue;
    o.life -= dt;
    o.x += o.vx * dt; o.y += o.vy * dt; o.z += o.vz * dt;
    o.vz -= 900 * dt; o.vx *= damp; o.vy *= damp;
    if (o.z < 0) { o.z = 0; o.vz *= -0.3; }
  }
  for (let i = waves.length - 1; i >= 0; i--) { waves[i].life -= dt; if (waves[i].life <= 0) waves.splice(i, 1); }
  for (let i = texts.length - 1; i >= 0; i--) { texts[i].life -= dt; if (texts[i].life <= 0) texts.splice(i, 1); }
  for (const pad of pads) pad.flash = Math.max(0, pad.flash - dt);
  if (game.banner) { game.banner.life -= dt; if (game.banner.life <= 0) game.banner = null; }
}
function floatText(str, color) {
  const p = player;
  texts.push({ str, color, x: p.x, y: p.y, h: Math.max(0, p.z - ground(p.x, p.y)) + 44, life: 0.9, max: 0.9 });
  if (texts.length > 12) texts.shift();
}
function banner(str) { game.banner = { str, life: 2.6 }; }
function addShake(a) { if (!reduceMotion) cam.shake = Math.min(18, cam.shake + a); }

function updateTrail(dt) {
  const p = player, sp = Math.hypot(p.vx, p.vy);
  p.trailT -= dt;
  if (p.trailT > 0) return;
  p.trailT = 0.03;
  if (sp > 520) {
    p.trail.push({ x: p.x, y: p.y, h: Math.max(0, p.z - ground(p.x, p.y)) });
    if (p.trail.length > 9) p.trail.shift();
  } else if (p.trail.length) p.trail.shift();
}

function updateCamera(dt) {
  const p = player, sp = Math.hypot(p.vx, p.vy), hA = Math.max(0, p.z - ground(p.x, p.y));
  const k = 1 - Math.exp(-7 * dt);
  cam.x += (p.x + p.vx * 0.16 - cam.x) * k;
  cam.y += (p.y + p.vy * 0.16 - hA * 0.5 - cam.y) * k;
  const zt = baseZoom * lerp(1, 0.7, clamp((sp - 320) / 1100, 0, 1));
  cam.zoom += (zt - cam.zoom) * (1 - Math.exp(-2.5 * dt));
  cam.shake = Math.max(0, cam.shake - dt * 30);
  // Keep the view inside the map.
  const hw = W / 2 / cam.zoom, hh = H / 2 / cam.zoom;
  cam.x = hw * 2 < WORLD ? clamp(cam.x, hw, WORLD - hw) : CENTER;
  cam.y = hh * 2 < WORLD ? clamp(cam.y, hh, WORLD - hh) : CENTER;
}

// ---------------------------------------------------------------------------
// Simulation step
// ---------------------------------------------------------------------------
function tick(dt) {
  const steps = Math.max(1, Math.ceil(dt * 120)), h = dt / steps;   // player physics at >= 120 Hz
  for (let i = 0; i < steps; i++) { game.t += h; updatePlayer(h); }
  updateEnemies(dt);
  updateWeapons(dt);
  updateGems(dt);
  updateSpawns(dt);
  updateParticles(dt);
  updateTrail(dt);
  updateCamera(dt);
  let w = 0;
  for (let i = 0; i < enemies.length; i++) if (!enemies[i].dead) enemies[w++] = enemies[i];
  enemies.length = w;
  rebuildHash();
  player.best.speed = Math.max(player.best.speed, Math.hypot(player.vx, player.vy));
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------
const canvas = document.getElementById('view');
const ctx = canvas.getContext('2d', { alpha: false });
let W = 1, H = 1, dpr = 1, baseZoom = 1, terrain = null, realT = 0;
const visE = [];

function resize() {
  dpr = Math.min(window.devicePixelRatio || 1, 1.5);
  W = window.innerWidth; H = window.innerHeight;
  canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
  baseZoom = clamp(Math.sqrt(W * H) / 1150, 0.5, 1.5);
}

const inView = (x, y, m) => x > view.x0 - m && x < view.x1 + m && y > view.y0 - m && y < view.y1 + m;

function render() {
  const z = cam.zoom, k = z * dpr;
  let shx = 0, shy = 0;
  if (cam.shake > 0) { shx = (Math.random() - 0.5) * cam.shake; shy = (Math.random() - 0.5) * cam.shake; }
  const vw = W / z, vh = H / z;
  view.x0 = cam.x - vw / 2 + shx / z; view.y0 = cam.y - vh / 2 + shy / z;
  view.x1 = view.x0 + vw; view.y1 = view.y0 + vh;

  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = '#081011';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.setTransform(k, 0, 0, k, -view.x0 * k, -view.y0 * k);

  const sx0 = Math.max(0, view.x0), sy0 = Math.max(0, view.y0), sx1 = Math.min(WORLD, view.x1), sy1 = Math.min(WORLD, view.y1);
  if (terrain && sx1 > sx0 && sy1 > sy0) {
    ctx.drawImage(terrain, sx0 / TEX, sy0 / TEX, (sx1 - sx0) / TEX, (sy1 - sy0) / TEX, sx0, sy0, sx1 - sx0, sy1 - sy0);
  }
  drawMapText(z);
  drawRamps();
  drawPads();
  drawFlames();
  drawGems();
  drawEnemies();
  drawBolts();
  drawWaves();
  drawPlayer();
  drawParticles();

  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  drawTexts(z);
  if (game.state !== 'title') { drawSpeedLines(); drawBanner(); drawHurt(); }
}

function drawMapText(z) {
  const size = 12 / Math.min(1, z);
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(232, 238, 226, 0.62)';
  ctx.font = `500 ${size}px 'IBM Plex Mono', ui-monospace, monospace`;
  for (const l of LABELS) {
    if (!inView(l.x, l.y, 200)) continue;
    ctx.fillText(l.text, l.x, l.y);
  }
  ctx.font = `italic 400 ${size * 0.9}px 'IBM Plex Mono', ui-monospace, monospace`;
  ctx.fillStyle = 'rgba(232, 238, 226, 0.45)';
  for (const l of LABELS) if (inView(l.x, l.y, 200)) ctx.fillText(l.sub, l.x, l.y + size * 1.3);
  ctx.font = `500 ${size * 0.9}px 'IBM Plex Mono', ui-monospace, monospace`;
  for (const s of spots) if (inView(s.x, s.y, 100)) ctx.fillText(s.text, s.x, s.y);
}

function drawRamps() {
  for (const r of ramps) {
    if (!inView(r.cx, r.cy, 180)) continue;
    const nx = -r.dy * r.hw, ny = r.dx * r.hw, lx = r.x + r.dx * r.L, ly = r.y + r.dy * r.L;
    ctx.fillStyle = 'rgba(0, 10, 8, 0.38)';
    ctx.beginPath();
    ctx.moveTo(lx + nx, ly + ny); ctx.lineTo(lx - nx, ly - ny);
    ctx.lineTo(lx - nx + r.dx * 30, ly - ny + r.dy * 30); ctx.lineTo(lx + nx + r.dx * 30, ly + ny + r.dy * 30);
    ctx.fill();
    const grad = ctx.createLinearGradient(r.x, r.y, lx, ly);
    grad.addColorStop(0, 'rgba(214, 198, 160, 0.3)');
    grad.addColorStop(1, 'rgba(240, 230, 204, 0.95)');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(r.x + nx, r.y + ny); ctx.lineTo(r.x - nx, r.y - ny); ctx.lineTo(lx - nx, ly - ny); ctx.lineTo(lx + nx, ly + ny);
    ctx.fill();
    ctx.strokeStyle = '#ff8a3d';
    ctx.lineWidth = 4;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    for (let q = 1; q <= 3; q++) {
      const cx = r.x + r.dx * (r.L * q / 4 + 8), cy = r.y + r.dy * (r.L * q / 4 + 8);
      ctx.moveTo(cx + nx * 0.45 - r.dx * 16, cy + ny * 0.45 - r.dy * 16);
      ctx.lineTo(cx, cy);
      ctx.lineTo(cx - nx * 0.45 - r.dx * 16, cy - ny * 0.45 - r.dy * 16);
    }
    ctx.stroke();
    ctx.strokeStyle = '#fff4d6';
    ctx.beginPath(); ctx.moveTo(lx + nx, ly + ny); ctx.lineTo(lx - nx, ly - ny); ctx.stroke();
  }
}

function drawPads() {
  for (const pad of pads) {
    if (!inView(pad.x, pad.y, 40)) continue;
    const pulse = 0.5 + 0.5 * Math.sin(realT * 4 + pad.x);
    ctx.fillStyle = `rgba(255, 210, 63, ${0.14 + pad.flash + pulse * 0.08})`;
    ctx.beginPath(); ctx.arc(pad.x, pad.y, pad.r, 0, TAU); ctx.fill();
    ctx.strokeStyle = '#ffd23f';
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.beginPath(); ctx.arc(pad.x, pad.y, pad.r * (0.4 + 0.2 * pulse), 0, TAU); ctx.stroke();
  }
}

function drawFlames() {
  if (!flames.length) return;
  ctx.globalCompositeOperation = 'lighter';
  for (const f of flames) {
    if (!inView(f.x, f.y, 30)) continue;
    const t = f.life / 1.3;
    ctx.fillStyle = `rgba(255, ${(90 + 100 * t) | 0}, 40, ${0.45 * t})`;
    ctx.beginPath(); ctx.arc(f.x, f.y - 4, 12 + 12 * (1 - t), 0, TAU); ctx.fill();
  }
  ctx.globalCompositeOperation = 'source-over';
}

function drawGems() {
  const groups = [['#6ee7f0', (g) => !g.heart && g.v < 5, 5], ['#b69cff', (g) => !g.heart && g.v >= 5, 8]];
  for (const [color, test, s] of groups) {
    ctx.fillStyle = color;
    ctx.beginPath();
    for (const g of gems) {
      if (!test(g) || !inView(g.x, g.y, 10)) continue;
      ctx.moveTo(g.x, g.y - s); ctx.lineTo(g.x + s * 0.75, g.y); ctx.lineTo(g.x, g.y + s); ctx.lineTo(g.x - s * 0.75, g.y); ctx.closePath();
    }
    ctx.fill();
  }
  ctx.fillStyle = '#ff4d6d';
  for (const g of gems) {
    if (!g.heart || !inView(g.x, g.y, 12)) continue;
    ctx.fillRect(g.x - 9, g.y - 3, 18, 6); ctx.fillRect(g.x - 3, g.y - 9, 6, 18);
  }
}

// Enemies are pre-rendered sprites (normal + hit flash): one drawImage each is far cheaper than vector circles.
const SPRITE_SCALE = 2.5;
function makeEnemySprites() {
  for (const T of ETYPES) {
    T.sprites = [T.color, '#ffffff'].map((color) => {
      const r = T.r, w = 2 * r + 4, top = 1.7 * r + 2, h = top + 0.5 * r + 3;
      const cv = document.createElement('canvas');
      cv.width = Math.ceil(w * SPRITE_SCALE); cv.height = Math.ceil(h * SPRITE_SCALE);
      const c = cv.getContext('2d');
      c.scale(SPRITE_SCALE, SPRITE_SCALE);
      c.translate(w / 2, top);
      c.fillStyle = 'rgba(0, 12, 10, 0.3)';
      c.beginPath(); c.ellipse(0, 1, r, r * 0.5, 0, 0, TAU); c.fill();
      c.fillStyle = color;
      c.beginPath(); c.arc(0, -r * 0.7, r, 0, TAU); c.fill();
      c.lineWidth = 1.5; c.strokeStyle = 'rgba(28, 6, 14, 0.6)'; c.stroke();
      c.fillStyle = 'rgba(255, 255, 255, 0.3)';
      c.beginPath(); c.arc(-r * 0.35, -r * 1.05, r * 0.3, 0, TAU); c.fill();
      return { cv, w, h, top };
    });
  }
}

const byY = (a, b) => a.y - b.y;
function drawEnemies() {
  visE.length = 0;
  for (const e of enemies) if (!e.dead && inView(e.x, e.y, 50)) visE.push(e);
  visE.sort(byY);   // nearer the bottom of the screen draws on top
  for (const e of visE) {
    const s = ETYPES[e.type].sprites[e.flash > 0 ? 1 : 0];
    ctx.drawImage(s.cv, e.x - s.w / 2, e.y - s.top, s.w, s.h);
  }
  for (const e of visE) {
    if (e.type !== 2 || e.hp >= e.maxHp) continue;
    ctx.fillStyle = 'rgba(8, 16, 17, 0.8)'; ctx.fillRect(e.x - 18, e.y - e.r * 1.7 - 8, 36, 5);
    ctx.fillStyle = '#ff4d6d'; ctx.fillRect(e.x - 18, e.y - e.r * 1.7 - 8, 36 * Math.max(0, e.hp / e.maxHp), 5);
  }
}

function drawBolts() {
  if (!bolts.length) return;
  ctx.strokeStyle = '#ffe3b0';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.beginPath();
  for (const b of bolts) {
    const off = 14 + b.h * (b.life / b.max);
    ctx.moveTo(b.x, b.y - off); ctx.lineTo(b.x - b.vx * 0.02, b.y - off - b.vy * 0.02);
  }
  ctx.stroke();
}

function drawWaves() {
  for (const w of waves) {
    const t = 1 - w.life / 0.35;
    ctx.strokeStyle = `rgba(255, 244, 214, ${0.8 * (1 - t)})`;
    ctx.lineWidth = 5 * (1 - t) + 1;
    ctx.beginPath(); ctx.ellipse(w.x, w.y, w.r * (0.3 + 0.7 * t), w.r * (0.3 + 0.7 * t) * 0.8, 0, 0, TAU); ctx.stroke();
  }
}

function drawPlayer() {
  const p = player, hA = Math.max(0, p.z - ground(p.x, p.y)), sp = Math.hypot(p.vx, p.vy);
  ctx.fillStyle = '#ff8a3d';
  for (let i = 0; i < p.trail.length; i++) {
    const t = p.trail[i];
    ctx.globalAlpha = ((i + 1) / p.trail.length) * 0.26;
    ctx.beginPath(); ctx.arc(t.x, t.y - t.h - PR * 0.85, PR * 0.9, 0, TAU); ctx.fill();
  }
  ctx.globalAlpha = 1;

  const sc = 1 / (1 + hA / 160);
  ctx.fillStyle = `rgba(0, 10, 8, ${0.1 + 0.32 * sc})`;
  ctx.beginPath(); ctx.ellipse(p.x, p.y + 1, PR * (0.6 + 0.5 * sc), PR * 0.5 * (0.6 + 0.5 * sc), 0, 0, TAU); ctx.fill();
  if (hA > 30) {
    ctx.strokeStyle = 'rgba(232, 238, 226, 0.35)';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 5]);
    ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x, p.y - hA); ctx.stroke();
    ctx.setLineDash([]);
  }

  const slidePose = p.sliding || p.slideAir;
  const by = p.y - hA - (slidePose ? PR * 0.45 : PR * 0.85);
  ctx.save();
  ctx.translate(p.x, by);
  if (p.iframes > 0 && ((p.iframes * 20) | 0) % 2) ctx.globalAlpha = 0.45;
  if (slidePose && sp > 5) { ctx.rotate(Math.atan2(p.vy, p.vx)); ctx.scale(1.35, 0.72); }
  else if (p.slamming) ctx.scale(0.75, 1.35);
  else if (p.squash > 0) ctx.scale(1 + 0.35 * p.squash, 1 - 0.3 * p.squash);
  else if (!p.grounded) { const st = clamp(p.vz / 2400, -0.18, 0.18); ctx.scale(1 - Math.abs(st) * 0.5, 1 + Math.abs(st)); }
  ctx.beginPath(); ctx.arc(0, 0, PR, 0, TAU);
  ctx.fillStyle = '#fff4d6'; ctx.fill();
  ctx.lineWidth = 3.2; ctx.strokeStyle = '#ff8a3d'; ctx.stroke();
  ctx.restore();
  ctx.fillStyle = '#ff8a3d';
  ctx.beginPath(); ctx.arc(p.x + p.fx * PR * 0.95, by + p.fy * PR * 0.75, 4.5, 0, TAU); ctx.fill();
}

function drawParticles() {
  for (const o of parts) {
    if (o.life <= 0 || !inView(o.x, o.y, 20)) continue;
    ctx.globalAlpha = o.life / o.max;
    ctx.fillStyle = o.color;
    ctx.fillRect(o.x - o.size / 2, o.y - o.z - o.size / 2, o.size, o.size);
  }
  ctx.globalAlpha = 1;
}

const FONT_POP = "900 22px 'Big Shoulders Display', 'Arial Narrow', sans-serif";
function drawTexts(z) {
  ctx.textAlign = 'center';
  ctx.font = FONT_POP;
  ctx.lineWidth = 4;
  ctx.strokeStyle = 'rgba(8, 16, 17, 0.85)';
  ctx.lineJoin = 'round';
  for (const t of texts) {
    const f = 1 - t.life / t.max;
    const sx = (t.x - view.x0) * z, sy = (t.y - t.h - view.y0) * z - f * 34;
    ctx.globalAlpha = Math.min(1, t.life * 3);
    ctx.strokeText(t.str, sx, sy);
    ctx.fillStyle = t.color;
    ctx.fillText(t.str, sx, sy);
  }
  ctx.globalAlpha = 1;
}

function drawSpeedLines() {
  const p = player, sp = Math.hypot(p.vx, p.vy);
  if (reduceMotion || sp < 620) return;
  const inten = clamp((sp - 620) / 900, 0, 1), n = (10 + 30 * inten) | 0;
  const dx = p.vx / sp, dy = p.vy / sp, rMin = Math.min(W, H) * 0.3;
  ctx.strokeStyle = `rgba(232, 238, 226, ${0.1 + 0.22 * inten})`;
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  for (let i = 0; i < n; i++) {
    const x = Math.random() * W, y = Math.random() * H;
    if (Math.hypot(x - W / 2, y - H / 2) < rMin) continue;
    const len = 40 + 140 * inten * Math.random();
    ctx.moveTo(x, y); ctx.lineTo(x - dx * len, y - dy * len);
  }
  ctx.stroke();
}

function drawBanner() {
  const b = game.banner;
  if (!b) return;
  const str = b.str.toUpperCase();
  ctx.globalAlpha = Math.min(1, b.life * 2);
  ctx.textAlign = 'center';
  ctx.font = "900 30px 'Big Shoulders Display', 'Arial Narrow', sans-serif";
  const wText = ctx.measureText(str).width;
  if (wText > W - 32) ctx.font = `900 ${Math.floor((30 * (W - 32)) / wText)}px 'Big Shoulders Display', 'Arial Narrow', sans-serif`;
  ctx.lineWidth = 5;
  ctx.strokeStyle = 'rgba(8, 16, 17, 0.9)';
  const y = touchMode ? H * 0.34 : 96;
  ctx.strokeText(str, W / 2, y);
  ctx.fillStyle = '#e8eee2';
  ctx.fillText(str, W / 2, y);
  ctx.globalAlpha = 1;
}

function drawHurt() {
  const p = player;
  const low = p.hp / p.maxHp < 0.3 ? 0.25 + 0.1 * Math.sin(realT * 6) : 0;
  const a = Math.max(p.hurt * 1.6, low);
  if (a <= 0.01) return;
  const g = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.35, W / 2, H / 2, Math.hypot(W, H) * 0.6);
  g.addColorStop(0, 'rgba(255, 77, 109, 0)');
  g.addColorStop(1, `rgba(255, 77, 109, ${Math.min(0.55, a)})`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
}

// ---------------------------------------------------------------------------
// HUD and menus
// ---------------------------------------------------------------------------
const $ = (id) => document.getElementById(id);
const el = {
  hud: $('hud'), overlay: $('overlay'), touch: $('touch'), legend: document.querySelector('.legend'),
  xpFill: $('xpFill'), lvl: $('lvl'), hpFill: $('hpFill'), hpText: $('hpText'), time: $('time'), kills: $('kills'),
  speedo: $('speedo'), spd: $('spd'), spdFill: $('spdFill'), tickRun: $('tickRun'), tickCap: $('tickCap'),
  chipMom: $('chipMom'), chipHop: $('chipHop'), chipAir: $('chipAir'), perf: $('perf'),
  panels: { title: $('panelTitle'), levelup: $('panelLevel'), paused: $('panelPause'), dead: $('panelDead') },
  levelTitle: $('levelTitle'), levelSheet: $('levelSheet'), cards: $('cards'), stats: $('stats'),
  stick: $('stick'), knob: $('knob'), zone: $('touchZone'), tJump: $('tJump'), tSlide: $('tSlide'),
};
let touchMode = matchMedia('(pointer: coarse)').matches;
let showPerf = true;
let fps = 60;

function setText(node, s) { if (node._t !== s) { node._t = s; node.textContent = s; } }
function setStyle(node, prop, v) { const key = '_' + prop; if (node[key] !== v) { node[key] = v; node.style[prop] = v; } }
function setClass(node, cls, on) { const key = '_c' + cls; if (node[key] !== on) { node[key] = on; node.classList.toggle(cls, on); } }
const fmtTime = (t) => `${Math.floor(t / 60)}:${String(Math.floor(t % 60)).padStart(2, '0')}`;

function hud() {
  if (game.state === 'title') return;
  const p = player, s = p.st, sp = Math.hypot(p.vx, p.vy), BAR = 1650;
  setText(el.spd, String(Math.round(sp * KMH)));
  setStyle(el.spdFill, 'width', `${(Math.min(1, sp / BAR) * 100).toFixed(1)}%`);
  setStyle(el.tickRun, 'left', `${((s.runSpeed / BAR) * 100).toFixed(1)}%`);
  setStyle(el.tickCap, 'left', `${((Math.min(s.hopCap, BAR) / BAR) * 100).toFixed(1)}%`);
  setClass(el.speedo, 'hot', sp > s.hopCap * 0.98);
  const m = momentumMult();
  setText(el.chipMom, `DMG ×${m.toFixed(1)}`);
  setClass(el.chipMom, 'on', m >= 1.3);
  setText(el.chipHop, `HOP ×${p.chain}`);
  setClass(el.chipHop, 'on', p.chain > 0);
  const airborne = !p.grounded && p.air > 0.25;
  setText(el.chipAir, `AIR ${(airborne ? p.air : p.lastAir).toFixed(1)}s`);
  setClass(el.chipAir, 'on', airborne);
  setStyle(el.hpFill, 'width', `${((p.hp / p.maxHp) * 100).toFixed(1)}%`);
  setText(el.hpText, `${Math.ceil(p.hp)}/${p.maxHp}`);
  setStyle(el.xpFill, 'width', `${((p.xp / p.need) * 100).toFixed(1)}%`);
  setText(el.lvl, String(p.level));
  setText(el.time, fmtTime(game.t));
  setText(el.kills, String(game.kills));
  setText(el.perf, showPerf ? `${Math.round(fps)} FPS · ${enemies.length} enemies` : '');
}

function setState(s) {
  game.state = s;
  for (const k in el.panels) el.panels[k].hidden = k !== s;
  el.overlay.hidden = s === 'play';
  el.hud.hidden = s === 'title';
  el.touch.hidden = !(touchMode && s === 'play');
  if (s !== 'play') releaseTouch();
}

function startRun() {
  enemies.length = 0; bolts.length = 0; gems.length = 0; flames.length = 0; waves.length = 0; texts.length = 0;
  parts.length = 0; partI = 0;
  Object.assign(game, { t: 0, kills: 0, spawnAcc: 0, nextRing: 25, ring: 0, banner: null, burnTick: 0 });
  resetPlayer();
  cam.x = player.x; cam.y = player.y; cam.shake = 0;
  rebuildHash();
  setState('play');
  banner('Hop, slide, slam. Speed is damage.');
}

function die() {
  const p = player;
  const rows = [
    ['Survived', fmtTime(game.t)], ['KOs', game.kills], ['Level', p.level],
    ['Top speed', `${Math.round(p.best.speed * KMH)} km/h`], ['Best hop chain', `×${p.best.chain}`], ['Longest air', `${p.best.air.toFixed(1)} s`],
  ];
  el.stats.innerHTML = rows.map(([l, v]) => `<div><span class="lab">${l}</span><b>${v}</b></div>`).join('');
  setState('dead');
}

const UPGRADES = [
  { id: 'stride', tag: 'Movement', name: 'Long Stride', desc: '+12% run speed.', max: 5, apply: (s) => { s.runSpeed *= 1.12; } },
  { id: 'spring', tag: 'Movement', name: 'Spring Heels', desc: '+10% jump height.', max: 4, apply: (s) => { s.jumpVel *= 1.05; } },
  { id: 'double', tag: 'Movement', name: 'Double Jump', desc: 'Jump again in midair. The second jump also swings you toward where you steer.', max: 2, apply: (s) => { s.airJumps += 1; } },
  { id: 'hop', tag: 'Movement', name: 'Hop Engine', desc: 'Perfect hops add 4% more speed, and the hop speed cap rises by 21 km/h.', max: 4, apply: (s) => { s.hopBoost += 0.04; s.hopCap += 140; } },
  { id: 'grease', tag: 'Movement', name: 'Greased Slide', desc: 'Slides lose 35% less speed and start with a bigger kick.', max: 3, apply: (s) => { s.slideFriction *= 0.65; s.slideBoost += 45; } },
  { id: 'air', tag: 'Movement', name: 'Air Control', desc: 'Turn 40% faster in the air.', max: 3, apply: (s) => { s.airTurn *= 1.4; s.airAccel *= 1.3; } },
  { id: 'momentum', tag: 'Speed into damage', name: 'Momentum Core', desc: 'Bolts gain more damage from your speed.', max: 4, apply: (s) => { s.momentum += 0.35; } },
  { id: 'bonk', tag: 'Speed into damage', name: 'Bonk Pads', desc: '+60% slide tackle damage.', max: 4, apply: (s) => { s.bonkMult += 0.6; } },
  { id: 'heavy', tag: 'Speed into damage', name: 'Heavy Landing', desc: '+50% stomp and slam damage, +20% slam radius.', max: 4, apply: (s) => { s.landMult += 0.5; s.slamRadius += 0.2; } },
  { id: 'burn', tag: 'Speed into damage', name: 'Afterburner', desc: 'Above 80 km/h you leave a burning trail. Each level burns hotter.', max: 4, apply: (s) => { s.burn += 1; } },
  { id: 'rate', tag: 'Bolts', name: 'Quick Bolts', desc: '+20% fire rate.', max: 5, apply: (s) => { s.fireRate *= 1.2; } },
  { id: 'split', tag: 'Bolts', name: 'Split Bolt', desc: '+1 bolt per shot.', max: 4, apply: (s) => { s.bolts += 1; } },
  { id: 'pierce', tag: 'Bolts', name: 'Piercing Bolts', desc: 'Bolts pass through one more enemy.', max: 3, apply: (s) => { s.pierce += 1; } },
  { id: 'magnet', tag: 'Utility', name: 'Magnet', desc: '+40% pickup range.', max: 4, apply: (s) => { s.magnet *= 1.4; } },
  { id: 'tough', tag: 'Utility', name: 'Tough', desc: '+25 max health and heal 25.', max: 5, apply: (s, p) => { p.maxHp += 25; p.hp = Math.min(p.maxHp, p.hp + 25); } },
];
const PATCH = { id: 'patch', tag: 'Utility', name: 'Patch Up', desc: 'Heal 40.', max: 0, apply: (s, p) => { p.hp = Math.min(p.maxHp, p.hp + 40); } };

function openLevelUp() {
  const p = player;
  const pool = UPGRADES.filter((u) => (p.lv[u.id] || 0) < u.max);
  for (let i = pool.length - 1; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [pool[i], pool[j]] = [pool[j], pool[i]]; }
  const choices = pool.slice(0, 3);
  while (choices.length < 3) choices.push(PATCH);
  game.choices = choices;
  setText(el.levelTitle, `Level ${p.level - p.pending + 1}`);
  setText(el.levelSheet, p.pending > 1 ? `Level up · ${p.pending} to pick` : 'Level up');
  el.cards.innerHTML = choices.map((u, i) => {
    const lv = p.lv[u.id] || 0;
    const pips = Array.from({ length: u.max }, (_, k) => `<i class="${k < lv ? 'on' : ''}"></i>`).join('');
    return `<button class="card" type="button" data-i="${i}"><span class="k">[${i + 1}] <span class="tag">${u.tag}</span></span>`
      + `<span class="name">${u.name}</span><span class="desc">${u.desc}</span><span class="pips">${pips}</span></button>`;
  }).join('');
  game.levelOpenAt = performance.now();
  setState('levelup');
}

function chooseCard(i) {
  // Ignore picks in the first moments so a mashed key doesn't choose for you.
  if (game.state !== 'levelup' || performance.now() - game.levelOpenAt < 350) return;
  const u = game.choices[i];
  if (!u) return;
  const p = player;
  p.lv[u.id] = (p.lv[u.id] || 0) + 1;
  u.apply(p.st, p);
  p.pending--;
  if (p.pending > 0) openLevelUp(); else setState('play');
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------
function syncHeld() {
  const j = JUMP_KEYS.some((k) => keys.has(k)) || input.tJump;
  const s = SLIDE_KEYS.some((k) => keys.has(k)) || input.tSlide;
  if (j && !input.jumpHeld) input.jumpSeq++;
  if (s && !input.slideHeld) input.slideSeq++;
  input.jumpHeld = j;
  input.slideHeld = s;
}

addEventListener('keydown', (e) => {
  const c = e.code;
  if (GAME_KEYS.has(c)) e.preventDefault();
  if (e.repeat) return;
  keys.add(c);
  syncHeld();
  if (game.state === 'title' && (c === 'Space' || c === 'Enter')) startRun();
  else if (game.state === 'play' && (c === 'Escape' || c === 'KeyP')) setState('paused');
  else if (game.state === 'paused' && (c === 'Escape' || c === 'KeyP')) setState('play');
  else if (game.state === 'levelup' && /^Digit[1-3]$/.test(c)) chooseCard(+c.slice(5) - 1);
  else if (game.state === 'dead' && (c === 'KeyR' || c === 'Enter')) startRun();
  if (c === 'KeyH') el.legend.hidden = !el.legend.hidden;
  if (c === 'KeyF') showPerf = !showPerf;
});
addEventListener('keyup', (e) => { keys.delete(e.code); syncHeld(); });
addEventListener('blur', () => { keys.clear(); syncHeld(); if (game.state === 'play') setState('paused'); });
document.addEventListener('visibilitychange', () => { if (document.hidden && game.state === 'play') setState('paused'); });

$('startBtn').addEventListener('click', startRun);
$('resumeBtn').addEventListener('click', () => setState('play'));
$('againBtn').addEventListener('click', startRun);
el.cards.addEventListener('click', (e) => { const b = e.target.closest('.card'); if (b) chooseCard(+b.dataset.i); });

// Touch: a floating stick on the left, jump and slide buttons on the right.
const stick = { id: -1, ox: 0, oy: 0 };
addEventListener('pointerdown', (e) => {
  if (e.pointerType === 'touch' && !touchMode) { touchMode = true; setState(game.state); }
}, true);
el.zone.addEventListener('pointerdown', (e) => {
  if (stick.id !== -1) return;
  e.preventDefault();
  stick.id = e.pointerId; stick.ox = e.clientX; stick.oy = e.clientY;
  el.zone.setPointerCapture(e.pointerId);
  el.stick.hidden = false;
  el.stick.style.left = `${e.clientX}px`; el.stick.style.top = `${e.clientY}px`;
  el.knob.style.transform = '';
});
el.zone.addEventListener('pointermove', (e) => {
  if (e.pointerId !== stick.id) return;
  let dx = e.clientX - stick.ox, dy = e.clientY - stick.oy;
  const l = Math.hypot(dx, dy), m = 44;
  if (l > m) { dx *= m / l; dy *= m / l; }
  el.knob.style.transform = `translate(${dx}px, ${dy}px)`;
  input.mx = dx / m; input.my = dy / m;
});
const endStick = (e) => { if (e.pointerId !== stick.id) return; stick.id = -1; input.mx = 0; input.my = 0; el.stick.hidden = true; };
el.zone.addEventListener('pointerup', endStick);
el.zone.addEventListener('pointercancel', endStick);

function holdButton(node, key) {
  node.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    node.setPointerCapture(e.pointerId);
    input[key] = true; node.classList.add('down'); syncHeld();
  });
  const up = () => { input[key] = false; node.classList.remove('down'); syncHeld(); };
  node.addEventListener('pointerup', up);
  node.addEventListener('pointercancel', up);
  node.addEventListener('lostpointercapture', up);
}
holdButton(el.tJump, 'tJump');
holdButton(el.tSlide, 'tSlide');
function releaseTouch() {
  stick.id = -1; input.mx = 0; input.my = 0; el.stick.hidden = true;
  input.tJump = false; input.tSlide = false;
  el.tJump.classList.remove('down'); el.tSlide.classList.remove('down');
  syncHeld();
}

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------
let last = 0, fpsAcc = 0, fpsN = 0;
function frame(now) {
  const dt = last ? Math.min((now - last) / 1000, 1 / 20) : 1 / 60;
  last = now;
  realT += dt;
  fpsAcc += dt; fpsN++;
  if (fpsAcc >= 0.5) { fps = fpsN / fpsAcc; fpsAcc = 0; fpsN = 0; }
  if (game.state === 'play') tick(dt);
  else updateCamera(dt);
  render();
  hud();
  requestAnimationFrame(frame);
}

function boot() {
  resize();
  addEventListener('resize', resize);
  buildWorld();
  makeEnemySprites();
  resetPlayer();
  rebuildHash();
  cam.x = player.x; cam.y = player.y; cam.zoom = baseZoom;
  setState('title');
  requestAnimationFrame(frame);
  // Paint the map after the first frame so the title shows up right away.
  setTimeout(() => { terrain = paintTerrain(); }, 30);
}

// Debug handle for tuning from the console.
window.__lab = { CFG, game, player, enemies, ground, spawnEnemy };

const hot = window.claude && window.claude.hot;
if (hot && hot.ready) hot.ready(boot); else boot();
})();
