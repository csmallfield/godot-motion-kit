// SPDX-License-Identifier: Apache-2.0
// MotionTiling: a full-frame op-art tiling (houndstooth, checker, pinwheel, dots,
// chevrons, stripes) whose cells rotate, scale, invert, recolour, switch motif and
// open up, each driven by four fields: a MASK (anything drawn into the tiling's
// mask viewport), a HALO around the mask, a RING (band or disc) and a SWEEP front.
// A Vasarely bulge and a radial ripple warp the whole fabric. Every value is a
// uniform, so the tiling is a pure function of what the script sets per frame.
shader_type canvas_item;
render_mode blend_mix;

uniform vec2 field_size = vec2(1920.0, 1080.0);
uniform float cell = 48.0;                // tile period in px
uniform float angle = 0.0;                // global rotation (radians)
uniform vec2 origin = vec2(960.0, 540.0); // rotation centre and tile origin (px)
uniform vec2 scroll = vec2(0.0);          // px, in the tiling's rotated frame
uniform int motif = 0;
uniform int motif_b = 1;
uniform float seed = 1.0;

// colourways
uniform vec4 ink_a : source_color = vec4(0.04, 0.04, 0.05, 1.0);   // motif
uniform vec4 ink_b : source_color = vec4(0.95, 0.93, 0.9, 1.0);    // ground
uniform vec4 alt_a : source_color = vec4(0.91, 0.13, 0.4, 1.0);
uniform vec4 alt_b : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform vec4 gap_color : source_color = vec4(0.04, 0.04, 0.05, 1.0); // shown where cells shrink
uniform float mask_color = 0.0;           // 0..1: the motif takes the mask's colour inside the mask
uniform float mask_ground = 0.0;          // 0..1: the ground takes the mask's colour x mask_ground_shade inside the mask
uniform float mask_ground_shade = 0.55;

// warp
uniform vec2 bulge_c = vec2(960.0, 540.0);
uniform float bulge_r = 600.0;
uniform float bulge = 0.0;                // -0.9..0.9: >0 magnifies (a Vasarely sphere), <0 pinches
uniform vec2 ripple_c = vec2(960.0, 540.0);
uniform float ripple_r = -1.0;            // < 0 = off
uniform float ripple_w = 120.0;
uniform float ripple_amp = 0.0;           // px of radial displacement

// drivers
uniform sampler2D mask : filter_linear, repeat_disable;
uniform bool has_mask = false;
uniform bool mask_pixel = true;           // true: the mask edge is per pixel (crisp shapes made of cells); false: per cell
uniform bool mask_warp = false;           // sample the mask in the warped fabric (the shape bends with it)
uniform float halo_r = 60.0;              // px: how far around the mask the halo reaches
uniform vec2 ring_c = vec2(960.0, 540.0);
uniform float ring_r = -1.0;              // < 0 = off
uniform float ring_w = 120.0;
uniform int ring_mode = 0;                // 0 band, 1 disc (inside = 1), 2 outside
uniform float sweep = -100000.0;          // front position (px along sweep_angle from the field centre)
uniform float sweep_angle = 0.0;          // degrees: 0 = left to right
uniform float sweep_w = 40.0;
uniform float jitter = 0.0;               // 0..1: per-cell stagger for ring and sweep fronts

// channels: value = base + dot(by, vec4(mask, halo, ring, sweep))
//                       + dot(and, vec4(ring*mask, sweep*mask, ring*halo, sweep*halo))
uniform float rot_base = 0.0;
uniform vec4 rot_and = vec4(0.0);
uniform vec4 rot_by = vec4(0.0);          // radians per driver
uniform float scale_base = 1.0;
uniform vec4 scale_and = vec4(0.0);
uniform vec4 scale_by = vec4(0.0);
uniform float inv_base = 0.0;
uniform vec4 inv_and = vec4(0.0);
uniform vec4 inv_by = vec4(0.0);
uniform bool alt_hard = true;            // each cell switches colourway at once (no blended colours at a front)
uniform float alt_base = 0.0;
uniform vec4 alt_and = vec4(0.0);
uniform vec4 alt_by = vec4(0.0);
uniform float clear_base = 0.0;           // gap transparency: lets what's under the tiling show through shrunk cells
uniform vec4 clear_and = vec4(0.0);
uniform vec4 clear_by = vec4(0.0);
uniform float motif_base = 0.0;           // > 0.5: the cell shows motif_b
uniform vec4 motif_and = vec4(0.0);
uniform vec4 motif_by = vec4(0.0);

uniform float level = 1.0;

const float SQRT2 = 1.41421356;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

#include "res://addons/motion_kit/shaders/motion_noise.gdshaderinc"

float hash(vec2 p) {
	return mk_hash21(p, seed * 0.618);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Square wave: 1 for mod(x, p) < p / 2, with a linear ramp aa wide at each edge.
float sqw(float x, float p, float aa) {
	float h = p * 0.5;
	float m = mod(x, p);
	float v = m < h ? 1.0 : 0.0;
	float r = mod(x, h);
	float e = min(r, h - r);
	return mix(0.5, v, clamp(e / max(aa, 1e-4), 0.0, 1.0));
}

// Motif coverage at tile coordinates t (period 1 per cell); aa in tile units.
float motif_at(int m, vec2 t, float aa) {
	if (m == 0) {
		// Houndstooth as a real weave: 4 dark / 4 light threads in warp and weft,
		// 2/2 twill. Warp on top: warp colour, else weft colour.
		vec2 th = t * 8.0;
		float a = aa * 8.0;
		float warp = sqw(th.x, 8.0, a);
		float weft = sqw(th.y, 8.0, a);
		float twill = sqw(th.x + th.y, 4.0, a * SQRT2);
		return mix(weft, warp, twill);
	} else if (m == 1) {
		// checker: 2 x 2 squares per tile
		float a = sqw(t.x * 2.0, 2.0, aa * 2.0);
		float b = sqw(t.y * 2.0, 2.0, aa * 2.0);
		return a + b - 2.0 * a * b;
	} else if (m == 2) {
		// pinwheel: each quadrant split on a diagonal that turns about the centre
		vec2 q = t * 2.0;
		vec2 id = mod(floor(q), 2.0);
		vec2 l = fract(q);
		float sd;
		if (id.x < 0.5 && id.y < 0.5) sd = l.x - l.y;
		else if (id.x > 0.5 && id.y < 0.5) sd = 1.0 - l.x - l.y;
		else if (id.x > 0.5 && id.y > 0.5) sd = l.y - l.x;
		else sd = l.x + l.y - 1.0;
		return smoothstep(-aa * 2.0 * SQRT2, aa * 2.0 * SQRT2, sd);
	} else if (m == 3) {
		// dots
		float d = length(fract(t) - 0.5) - 0.3;
		return smoothstep(aa, -aa, d);
	} else if (m == 4) {
		// chevrons (zigzag)
		float v = t.y * 2.0 + abs(fract(t.x) - 0.5) * 2.0;
		return sqw(v, 2.0, aa * 3.0);
	}
	// diagonal stripes
	return sqw((t.x + t.y) * 2.0, 2.0, aa * 2.0 * SQRT2);
}

vec4 mask_at(vec2 px) {
	if (!has_mask) return vec4(0.0);
	vec2 uv = px / field_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
	return texture(mask, uv);
}

// One cell's colour for given driver values. local: 0..1 in the cell.
vec4 shade(vec2 cid, vec2 local, vec4 d, float aa, vec3 mcol) {
	vec4 e = vec4(d.z * d.x, d.w * d.x, d.z * d.y, d.w * d.y);
	float r = rot_base + dot(rot_by, d) + dot(rot_and, e);
	float s = scale_base + dot(scale_by, d) + dot(scale_and, e);
	float inv = clamp(inv_base + dot(inv_by, d) + dot(inv_and, e), 0.0, 1.0);
	float alt = clamp(alt_base + dot(alt_by, d) + dot(alt_and, e), 0.0, 1.0);
	if (alt_hard) alt = step(0.5, alt);
	float clr = clamp(clear_base + dot(clear_by, d) + dot(clear_and, e), 0.0, 1.0);
	int m = (motif_base + dot(motif_by, d) + dot(motif_and, e)) > 0.5 ? motif_b : motif;

	vec4 ga = mix(gap_color, vec4(gap_color.rgb, 0.0), clr);
	if (s <= 0.001) return ga;
	vec2 q = rot(local - 0.5, -r) / s;
	float aq = aa / s;
	// coverage of the (rotated, scaled) tile inside its cell
	float edge = 0.5 - max(abs(q.x), abs(q.y));
	float inside = smoothstep(-aq, aq, edge);
	float fg = motif_at(m, cid + q + 0.5, aq);
	fg = mix(fg, 1.0 - fg, inv);
	vec4 ca = mix(ink_a, alt_a, alt);
	vec4 cb = mix(ink_b, alt_b, alt);
	ca.rgb = mix(ca.rgb, mcol, mask_color * d.x);
	cb.rgb = mix(cb.rgb, mcol * mask_ground_shade, mask_ground * d.x);
	vec4 tile = mix(cb, ca, fg);
	return mix(ga, tile, inside);
}

void fragment() {
	vec2 px = local_px;

	// warp: Vasarely bulge, then a radial ripple
	vec2 w = px;
	float mag = 1.0;
	vec2 bd = w - bulge_c;
	float br = length(bd) / max(bulge_r, 1.0);
	if (br < 1.0 && bulge != 0.0) {
		float k = 1.0 - br * br;
		float f = 1.0 - bulge * k * k;
		w = bulge_c + bd * f;
		mag = 1.0 / max(f, 0.05);
	}
	if (ripple_r >= 0.0 && ripple_amp != 0.0) {
		vec2 rd = w - ripple_c;
		float dist = length(rd);
		float k = (dist - ripple_r) / max(ripple_w, 1.0);
		float disp = ripple_amp * sin(k * 3.14159) * exp(-k * k);
		w -= (dist > 0.001 ? rd / dist : vec2(0.0)) * disp;
	}

	// into the tiling's frame
	vec2 p = rot(w - origin, -angle) + scroll;
	vec2 u = p / cell;
	vec2 cid = floor(u);
	vec2 local = u - cid;
	float aa = 0.75 / (cell * mag);   // ~0.75 px in tile units

	// the cell centre back in (warped) screen space, for the drivers
	vec2 cc = rot((cid + 0.5) * cell - scroll, angle) + origin;
	float h = hash(cid);

	float m_cell = 0.0;
	float halo = 0.0;
	vec3 mcol = vec3(1.0);
	vec2 mpos_c = mask_warp ? cc : cc;   // cell centre (already in fabric space)
	if (has_mask) {
		vec4 mc = mask_at(mpos_c);
		m_cell = mc.a;
		float o = halo_r * 0.7071;
		float a8 = mask_at(mpos_c + vec2(halo_r, 0.0)).a + mask_at(mpos_c - vec2(halo_r, 0.0)).a
			+ mask_at(mpos_c + vec2(0.0, halo_r)).a + mask_at(mpos_c - vec2(0.0, halo_r)).a
			+ mask_at(mpos_c + vec2(o, o)).a + mask_at(mpos_c + vec2(-o, o)).a
			+ mask_at(mpos_c + vec2(o, -o)).a + mask_at(mpos_c + vec2(-o, -o)).a;
		halo = smoothstep(0.0, 0.5, a8 / 8.0) * (1.0 - m_cell);
	}

	float ring = 0.0;
	if (ring_r >= 0.0) {
		float rd = length(cc - ring_c) - ring_r + (h - 0.5) * jitter * ring_w * 2.0;
		if (ring_mode == 0) ring = exp(-pow(rd / max(ring_w, 1.0), 2.0));
		else if (ring_mode == 1) ring = 1.0 - smoothstep(-ring_w, ring_w, rd);
		else ring = smoothstep(-ring_w, ring_w, rd);
	}
	float sa = radians(sweep_angle);
	float sd = dot(cc - field_size * 0.5, vec2(cos(sa), sin(sa))) - sweep + (h - 0.5) * jitter * sweep_w * 6.0;
	float swp = 1.0 - smoothstep(-sweep_w, sweep_w, sd);

	vec4 col;
	if (has_mask && mask_pixel) {
		vec4 mp = mask_at(mask_warp ? w : px);
		mcol = mp.a > 0.001 ? mp.rgb / mp.a : vec3(1.0);
		vec4 c0 = shade(cid, local, vec4(0.0, halo, ring, swp), aa, mcol);
		vec4 c1 = shade(cid, local, vec4(1.0, 0.0, ring, swp), aa, mcol);
		col = mix(c0, c1, mp.a);
	} else {
		if (has_mask) {
			vec4 mc = mask_at(mpos_c);
			mcol = mc.a > 0.001 ? mc.rgb / mc.a : vec3(1.0);
		}
		col = shade(cid, local, vec4(m_cell, halo, ring, swp), aa, mcol);
	}
	COLOR = vec4(col.rgb, col.a * level);
}
