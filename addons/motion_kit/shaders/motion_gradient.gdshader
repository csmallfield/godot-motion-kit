// SPDX-License-Identifier: Apache-2.0
// CSS-style gradients over a rectangle, with optional blend modes against what
// is already drawn (CSS mix-blend-mode).
//   kind 0 linear (CSS angle: 0deg points up, 90deg right)
//   kind 1 radial (ellipse, farthest-corner, at `center`)
//   kind 2 conic  (from 12 o'clock, clockwise, at `center`)
//   kind 3 repeating linear: stop positions in pixels, repeated (stripes)
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform int kind = 0;
uniform vec2 rect_size = vec2(100.0);
uniform float angle_deg = 180.0;
uniform vec2 center = vec2(0.5);          // fraction of the rect (radial, conic)
uniform vec2 shift = vec2(0.0);           // CSS background-position, pixels
uniform int stop_count = 2;
uniform vec4 stop_colors[8] : source_color;
uniform float stop_pos[8];                // 0..1 for kinds 0-2; pixels for kind 3
uniform int blend = 0;                    // 0 normal, 1 add, 2 multiply, 3 screen, 4 overlay
uniform float opacity = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

vec4 ramp(float t) {
	if (t <= stop_pos[0]) return stop_colors[0];
	for (int i = 1; i < 8; i++) {
		if (i >= stop_count) break;
		if (t <= stop_pos[i]) {
			float a = stop_pos[i - 1];
			float b = stop_pos[i];
			float k = b > a ? (t - a) / (b - a) : 1.0;
			// CSS interpolates in premultiplied space
			vec4 c0 = vec4(stop_colors[i - 1].rgb * stop_colors[i - 1].a, stop_colors[i - 1].a);
			vec4 c1 = vec4(stop_colors[i].rgb * stop_colors[i].a, stop_colors[i].a);
			vec4 c = mix(c0, c1, k);
			return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
		}
	}
	return stop_colors[stop_count - 1];
}

float overlay_ch(float b, float s) {
	return b <= 0.5 ? 2.0 * b * s : 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
}

void fragment() {
	// background-position moves the gradient image, which tiles (CSS
	// background-repeat), seams included, exactly as a browser draws it.
	vec2 sz = rect_size;
	vec2 p = mod(local - shift, sz);
	float t = 0.0;
	if (kind == 0 || kind == 3) {
		float a = radians(angle_deg);
		vec2 dir = vec2(sin(a), -cos(a));
		// CSS gradient line length: |w sin a| + |h cos a|, centred on the box
		float len = abs(sz.x * sin(a)) + abs(sz.y * cos(a));
		float d = dot(p - sz * 0.5, dir) + len * 0.5;
		if (kind == 0) {
			t = d / len;
		} else {
			float period = stop_pos[stop_count - 1];
			t = mod(d, max(period, 1e-3));
		}
	} else if (kind == 1) {
		vec2 c = center * sz;
		vec2 far = max(c, sz - c);
		vec2 r = far * sqrt(2.0);   // ellipse through the farthest corner
		t = length((p - c) / r);
	} else {
		vec2 c = center * sz;
		vec2 v = p - c;
		t = fract(atan(v.x, -v.y) / 6.28318530718 + 1.0);
	}
	vec4 g = ramp(t);
	g.a *= opacity;
	if (blend == 0) {
		COLOR = g;
	} else {
		// CSS compositing: Cs' = (1 - ab) Cs + ab B(Cb, Cs), then source-over.
		// Where the backdrop is transparent (an isolated group, e.g. inside a
		// MotionFX), the gradient simply draws; over opaque pixels it blends.
		vec4 bd = texture(screen, SCREEN_UV);           // premultiplied
		float ab = bd.a;
		vec3 b = ab > 0.0 ? bd.rgb / ab : vec3(0.0);
		vec3 s = g.rgb;
		vec3 r;
		if (blend == 1) r = b + s;
		else if (blend == 2) r = b * s;
		else if (blend == 3) r = 1.0 - (1.0 - b) * (1.0 - s);
		else r = vec3(overlay_ch(b.r, s.r), overlay_ch(b.g, s.g), overlay_ch(b.b, s.b));
		COLOR = vec4(mix(s, clamp(r, 0.0, 1.0), ab), g.a);
	}
}
