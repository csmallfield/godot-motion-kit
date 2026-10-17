// SPDX-License-Identifier: Apache-2.0
// Signed-distance shapes for MotionShape. One quad per shape; the edge is
// anti-aliased by screen-space derivatives, so it is sharp at any scale.
shader_type canvas_item;
render_mode blend_mix;

uniform int kind = 0;            // 0 circle/ellipse, 1 rounded rect (pill when radius = h/2), 2 ring, 3 arc
uniform vec2 half_size = vec2(50.0);
uniform float radius = 0.0;      // corner radius for rects
uniform float thickness = 4.0;   // ring and arc width (pixels in shape space)
uniform float sweep_from = 0.0;  // arc / ring visible range, 0..1 of a turn, starting at 12 o'clock
uniform float sweep_to = 1.0;
uniform float dash_count = 0.0;  // > 0 splits rings and arcs into dashes
uniform float dash_fill = 0.9;   // fraction of each dash period that is drawn
uniform float rotation_turns = 0.0;
uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec2 center = vec2(0.0); // shape centre in the node's local space

varying vec2 local;

void vertex() {
	// The quad is drawn around `center` in the node's local space.
	local = VERTEX - center;
}

float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_ellipse_approx(vec2 p, vec2 ab) {
	// Good to well under a pixel for the aspect ratios used here.
	float k0 = length(p / ab);
	float k1 = length(p / (ab * ab));
	return k0 < 1e-5 ? -min(ab.x, ab.y) : k0 * (k0 - 1.0) / k1;
}

void fragment() {
	vec2 p = local;
	float d;
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.75;
	if (kind == 0) {
		d = sd_ellipse_approx(p, half_size);
	} else if (kind == 1) {
		d = sd_rounded_box(p, half_size, min(radius, min(half_size.x, half_size.y)));
	} else {
		float r = half_size.x - thickness * 0.5;
		d = abs(length(p) - r) - thickness * 0.5;
		// angle from 12 o'clock, clockwise, in turns
		float a = fract(atan(p.x, -p.y) / 6.28318530718 - rotation_turns + 1.0);
		float lo = sweep_from;
		float hi = sweep_to;
		bool inside = hi - lo >= 1.0 || (a >= lo && a <= hi) || (hi > 1.0 && a <= hi - 1.0);
		if (!inside) d = max(d, aa * 4.0);
		if (dash_count > 0.0) {
			float period = fract(a * dash_count);
			if (period > dash_fill) d = max(d, aa * 4.0);
		}
	}
	float cover = clamp(0.5 - d / max(aa, 1e-4), 0.0, 1.0);
	COLOR = vec4(fill_color.rgb, fill_color.a * cover) * COLOR;
}
