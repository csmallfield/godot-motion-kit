// SPDX-License-Identifier: Apache-2.0
// Shared by motion_gradient (plain) and motion_gradient_blend.
//   kind 0 linear (CSS angle: 0deg points up, 90deg right)
//   kind 1 radial (ellipse, farthest-corner, at `center`)
//   kind 2 conic  (from 12 o'clock, clockwise, at `center`)
//   kind 3 repeating linear: stop positions in pixels (stripes)
uniform int kind = 0;
uniform vec2 rect_size = vec2(100.0);
uniform float angle_deg = 180.0;
uniform vec2 center = vec2(0.5);          // fraction of the rect (radial, conic)
uniform vec2 shift = vec2(0.0);           // CSS background-position, pixels
uniform int stop_count = 2;
uniform vec4 stop_colors[8] : source_color;
uniform float stop_pos[8];                // 0..1 for kinds 0-2; pixels for kind 3
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

// The gradient's colour (straight alpha) at this fragment, with `opacity`.
vec4 gradient_colour() {
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
			// CSS repeating gradients repeat every (last - first) stop, anchored at the first.
			float first = stop_pos[0];
			float period = max(stop_pos[stop_count - 1] - first, 1e-3);
			t = first + mod(d - first, period);
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
	return g;
}
