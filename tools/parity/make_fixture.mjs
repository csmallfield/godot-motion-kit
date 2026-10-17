// Writes tests/fixtures/remotion_parity.json: reference values computed by
// Remotion itself, which tests/test_parity.gd compares against MK.
//   cd tools/parity && npm install && npm run fixture
import { spring, interpolate, Easing } from "remotion";
import fs from "node:fs";

const out = { generator: "remotion@4.0.534", spring: [], bezier: [], interpolate: [], rand: [], shake: [], typed: [] };

// Spring configs used across the SCF pieces, plus edge cases: critical (zeta = 1),
// overdamped, heavy mass, and a 60 fps run.
const configs = [
  [10, 100, 1], [9, 120, 1], [8, 110, 1], [7, 160, 1], [6, 200, 1], [11, 110, 1], [12, 90, 1],
  [8, 180, 1], [9, 180, 1], [8, 200, 1], [9, 150, 1], [10, 140, 1], [20, 100, 1], [40, 100, 1], [5, 100, 2.5],
];
const frames = [];
for (let f = -3; f <= 90; f += 1) frames.push(f);
for (let f = 0.25; f <= 30; f += 0.5) frames.push(f);
for (const fps of [30, 60]) {
  for (const [damping, stiffness, mass] of configs) {
    const values = frames.map((frame) => spring({ frame, fps, config: { damping, stiffness, mass } }));
    out.spring.push({ fps, damping, stiffness, mass, frames, values });
  }
}

const curves = {
  ease: [0.22, 1, 0.36, 1], ease_in_out: [0.65, 0, 0.35, 1],
  ease_in_back: [0.6, -0.28, 0.735, 0.045], ease_out_back: [0.175, 0.885, 0.32, 1.275],
  odd: [0.9, 0.1, 0.1, 0.9], steep: [0.0, 0.0, 0.0, 1.0],
};
const xs = Array.from({ length: 201 }, (_, i) => i / 200);
for (const [name, c] of Object.entries(curves)) {
  const e = Easing.bezier(...c);
  out.bezier.push({ name, c, xs, values: xs.map((x) => e(x)) });
}

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" };
const icases = [
  { inputs: [0, 30], outputs: [0, 1], easing: "linear" },
  { inputs: [10, 40], outputs: [200, -50], easing: "ease" },
  { inputs: [0, 12, 30, 44], outputs: [0, 1, 1, 0], easing: "ease_in_out" },
  { inputs: [5, 17], outputs: [1, 0.004], easing: "quad" },
  { inputs: [100, 120], outputs: [0, 1], easing: "ease_in_back" },
];
const ef = { linear: (t) => t, ease: Easing.bezier(0.22, 1, 0.36, 1), ease_in_out: Easing.bezier(0.65, 0, 0.35, 1), ease_in_back: Easing.bezier(0.6, -0.28, 0.735, 0.045), quad: (t) => t * t };
const ix = Array.from({ length: 161 }, (_, i) => -10 + i);
for (const c of icases) out.interpolate.push({ ...c, xs: ix, values: ix.map((x) => interpolate(x, c.inputs, c.outputs, { ...clamp, easing: ef[c.easing] })) });
// Extrapolation: Remotion applies the easing outside the range too.
out.interpolate_extend = [
  { inputs: [0, 10], outputs: [0, 1], easing: "quad" },
  { inputs: [0, 10, 20], outputs: [0, 5, 3], easing: "linear" },
].map((c) => ({ ...c, xs: ix, values: ix.map((x) => interpolate(x, c.inputs, c.outputs, { extrapolateLeft: "extend", extrapolateRight: "extend", easing: ef[c.easing] })) }));

// The SCF project's own helpers (src/lib/anim.ts), reproduced verbatim.
const rand = (seed) => { const x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x); };
const shake = (f, at, amp = 18, dur = 10) => { const t = f - at; if (t < 0 || t > dur) return { x: 0, y: 0 }; const k = 1 - t / dur; return { x: (rand(at * 7 + t) - 0.5) * 2 * amp * k, y: (rand(at * 13 + t) - 0.5) * 2 * amp * k }; };
const typed = (text, f, start, cps = 38, fps = 30) => text.slice(0, Math.max(0, Math.floor(((f - start) * cps) / fps)));
// Seeds are exact binary fractions: Godot's JSON parser rounds 17-digit decimals.
for (let i = 0; i < 400; i++) { const s = i * 1.625 + (i % 7) * 0.03125; out.rand.push([s, rand(s)]); }
for (let f = 80; f < 100; f++) { const v = shake(f, 86, 120, 10); out.shake.push([f, v.x, v.y]); }
for (let f = 140; f < 170; f++) out.typed.push([f, typed("> verify ............ ok", f, 150, 120)]);

fs.writeFileSync(new URL("../../tests/fixtures/remotion_parity.json", import.meta.url), JSON.stringify(out));
console.log("spring", out.spring.length, "bezier", out.bezier.length, "interpolate", out.interpolate.length);
