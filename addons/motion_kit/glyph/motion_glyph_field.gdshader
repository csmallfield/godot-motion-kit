// SPDX-License-Identifier: Apache-2.0
// MotionGlyphField: a grid of cycling glyphs drawn in one quad. Each cell picks
// its glyph from a hash of (cell, time step) and its brightness and colour from
// a mask texture (anything drawn into the field's mask viewport). Everything
// is a function of the uniforms, `frame` included, so the field is frame-pure.
shader_type canvas_item;
render_mode blend_mix;

uniform vec2 field_size = vec2(1920.0, 1080.0);
uniform vec2 cell = vec2(18.0, 18.0);
uniform float glyph_scale = 0.9;          // glyph size inside its cell

// atlas: glyphs in a grid, white on transparent
uniform sampler2D atlas : filter_linear, repeat_disable;
uniform int atlas_cols = 16;
uniform vec2 atlas_cell_uv = vec2(0.0625, 0.0625);
uniform int glyph_total = 1;
uniform ivec2 dim_range = ivec2(0, 0);    // start, count (count 0 = all glyphs)
uniform ivec2 lit_range = ivec2(0, 0);

uniform float frame = 0.0;
uniform float cycle_min = 0.03;           // glyph changes per frame, per cell between min and max
uniform float cycle_max = 0.3;
uniform float lit_cycle = 1.0;            // multiplier for lit cells
uniform float seed = 1.0;

// mask
uniform sampler2D mask : filter_linear, repeat_disable;
uniform bool has_mask = false;
uniform float threshold = 0.35;
uniform float softness = 0.15;
uniform float reveal = 1.0;               // 0..1: share of lit cells shown
uniform float reveal_sweep = 0.0;         // 0 random dissolve, 1 a straight sweep along reveal_angle
uniform float reveal_angle = 90.0;        // degrees; 90 = top to bottom
uniform vec4 lit_color : source_color = vec4(1.0);
uniform float tint = 0.0;                 // 0 = the mask's own colour, 1 = lit_color
uniform float lit_level = 1.0;
uniform float lit_fill = 0.0;             // 0..1: lit cells get a filled block behind the glyph
uniform float lit_invert = 0.0;           // 0..1: glyphs on filled cells take ink_color (a stencil)
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// the dim field
uniform vec4 base_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);
uniform vec4 base_color_b : source_color = vec4(1.0, 0.1, 0.4, 1.0);
uniform float base_front = -100000.0;     // x (px) left of which the base turns base_color_b
uniform float base_front_jitter = 160.0;
uniform float base_density = 0.4;         // share of cells showing a dim glyph
uniform float base_level = 0.25;
uniform float base_flicker = 0.0;         // 0..1: dim cells blink on their own steps

// motion
uniform vec2 scroll = vec2(0.0);          // whole grid offset (px); the mask stays put
uniform float rain = 0.0;                 // px per frame, downwards, per column speed varies
uniform float rain_var = 0.6;
uniform float fall_t = -1.0;              // frames since the fall began (< 0 = off)
uniform float fall_g = 0.6;               // px per frame^2
uniform float fall_spread = 30.0;         // frames of per-column delay

// highlights
uniform vec4 hot_color : source_color = vec4(1.0);
uniform float scan_y = -100000.0;
uniform float scan_w = 40.0;
uniform float scan_gain = 1.0;
uniform vec2 ring_c = vec2(960.0, 540.0);
uniform float ring_r = -1.0;
uniform float ring_w = 90.0;
uniform float ring_gain = 1.0;

// glyphs -> solid mask
uniform float solidify = 0.0;
uniform float solidify_noise = 0.5;
uniform float solidify_sweep = 0.0;       // 0 random, 1 radial from ring_c

uniform float level = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.1234);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float h11(float x) {
	return h21(vec2(x, x * 0.37 + 11.0));
}

vec4 mask_at(vec2 px) {
	vec2 uv = px / field_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
	return texture(mask, uv);
}

void fragment() {
	vec2 p = local;
	// columns first: rain and fall move whole columns
	float col = floor((p.x + scroll.x) / cell.x);
	float colh = h11(col + 17.0);
	float rain_off = rain * frame * (1.0 + rain_var * (colh * 2.0 - 1.0));
	float fall_off = 0.0;
	if (fall_t >= 0.0) {
		float t = max(0.0, fall_t - colh * fall_spread);
		fall_off = fall_g * t * t;
	}
	vec2 q = p + scroll - vec2(0.0, rain_off + fall_off);
	vec2 ci = floor(q / cell);
	vec2 f_in = fract(q / cell);
	// where this cell is on screen, without the fall (the mask is sampled there)
	vec2 centre_screen = (ci + 0.5) * cell - scroll + vec2(0.0, rain_off);

	float hA = h21(ci);
	float hB = h21(ci + 31.7);
	float hC = h21(ci + 77.1);
	float hD = h21(ci + 5.3);

	// mask coverage: centre + four taps; colour from the centre
	float cover = 0.0;
	vec3 mcol = vec3(0.0);
	if (has_mask) {
		vec4 mc = mask_at(centre_screen);
		vec2 o = cell * 0.3;
		float a = mc.a
			+ mask_at(centre_screen + vec2(-o.x, -o.y)).a
			+ mask_at(centre_screen + vec2(o.x, -o.y)).a
			+ mask_at(centre_screen + vec2(-o.x, o.y)).a
			+ mask_at(centre_screen + vec2(o.x, o.y)).a;
		cover = a / 5.0;
		mcol = mc.a > 0.001 ? mc.rgb / mc.a : vec3(1.0);
	}
	float lit = smoothstep(threshold - softness, threshold + softness, cover);
	// reveal: seeded dissolve blended with a directional sweep
	float ang = radians(reveal_angle);
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 n = centre_screen / field_size - 0.5;
	float sweep_pos = clamp(dot(n, dir) / (abs(dir.x) * 0.5 + abs(dir.y) * 0.5) * 0.5 + 0.5, 0.0, 1.0);
	float r_cell = mix(hB, sweep_pos * 0.9 + hB * 0.1, reveal_sweep);
	lit *= step(r_cell, reveal - 0.0001) * lit_level;

	// glyph choice
	float rate = mix(cycle_min, cycle_max, hA) * mix(1.0, lit_cycle, step(0.01, lit));
	float stp = floor(frame * rate + hC * 13.0);
	float g = h21(ci + vec2(stp * 1.37, stp * 0.71));
	ivec2 rng = lit > 0.01 ? lit_range : dim_range;
	int start = rng.x;
	int count = rng.y > 0 ? rng.y : glyph_total;
	int gi = clamp(start + int(floor(g * float(count))), 0, glyph_total - 1);

	vec2 uv_in = (f_in - 0.5) / glyph_scale + 0.5;
	float ga = 0.0;
	if (uv_in.x >= 0.0 && uv_in.y >= 0.0 && uv_in.x <= 1.0 && uv_in.y <= 1.0) {
		vec2 cxy = vec2(float(gi % atlas_cols), float(gi / atlas_cols));
		ga = texture(atlas, (cxy + uv_in) * atlas_cell_uv).a;
	}

	// dim field
	float show = step(hD, base_density);
	if (base_flicker > 0.0) {
		float fs = floor(frame * mix(0.05, 0.25, hC) + hA * 5.0);
		show *= step(base_flicker, h21(ci + fs * 3.1)) + (1.0 - step(0.001, base_flicker));
		show = min(show, 1.0);
	}
	float side = step(centre_screen.x + (hA - 0.5) * base_front_jitter, base_front);
	vec3 bcol = mix(base_color.rgb, base_color_b.rgb, side);
	float dim_a = show * base_level;

	vec3 lcol = mix(mcol, lit_color.rgb, tint);
	float a_lit = lit;
	// highlights
	float hot = 0.0;
	hot += scan_gain * exp(-pow((centre_screen.y - scan_y) / max(scan_w, 1.0), 2.0));
	if (ring_r >= 0.0) {
		float d = length(centre_screen - ring_c);
		hot += ring_gain * exp(-pow((d - ring_r) / max(ring_w, 1.0), 2.0));
	}
	hot = clamp(hot, 0.0, 1.5);

	float a_glyph = max(dim_a, a_lit);
	vec3 col_glyph = mix(bcol, lcol, clamp(a_lit / max(a_glyph, 1e-4), 0.0, 1.0));
	// hot cells light up and turn white (only where something is drawn or the band passes)
	float hot_a = hot * max(show, step(0.01, a_lit)) * 0.9;
	float hk = clamp(hot, 0.0, 1.0) * 0.85;
	col_glyph = mix(col_glyph, hot_color.rgb, hk);
	a_glyph = max(a_glyph, hot_a);
	// filled lit cells: a block in the lit colour, the glyph inverted on it
	vec2 ins = step(vec2(0.06), f_in) * step(f_in, vec2(0.94));
	float fill_a = a_lit * lit_fill * ins.x * ins.y;
	vec3 fill_col = mix(lcol, hot_color.rgb, hk);
	vec3 g_col = mix(col_glyph, ink_color.rgb, lit_invert * step(0.001, fill_a));
	float g_a = ga * clamp(a_glyph, 0.0, 1.0);
	float o_a = g_a + fill_a * (1.0 - g_a);
	vec3 o_rgb = o_a > 0.0001 ? (g_col * g_a + fill_col * fill_a * (1.0 - g_a)) / o_a : vec3(0.0);
	vec4 glyph_out = vec4(o_rgb, o_a);

	// solidify: cells switch from glyphs to the mask itself
	vec4 outc = glyph_out;
	if (solidify > 0.0 && has_mask) {
		float rr = length(centre_screen - ring_c) / length(field_size * 0.5);
		// key: when this cell turns solid (random, or radial from ring_c)
		float key = mix(hA, clamp(rr, 0.0, 1.0) * (1.0 - solidify_noise) + hA * solidify_noise, solidify_sweep);
		float s = solidify >= 0.999 ? 1.0 : step(key, solidify);
		if (s > 0.5) {
			vec4 m = mask_at(p);
			float sa = m.a;
			vec3 sc = sa > 0.001 ? m.rgb / sa : vec3(0.0);
			// under the solid: dim glyphs carry on, lit glyphs are consumed
			vec4 b = glyph_out * (1.0 - step(0.01, lit));
			float oa = sa + b.a * (1.0 - sa);
			vec3 orgb = oa > 0.0001 ? (sc * sa + b.rgb * b.a * (1.0 - sa)) / oa : vec3(0.0);
			outc = vec4(orgb, oa);
		}
	}
	COLOR = vec4(outc.rgb, outc.a * level);
}
