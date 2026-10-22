// SPDX-License-Identifier: Apache-2.0
// MotionPaper: an uncoated sheet. Low-frequency mottling, fine tooth (grain)
// and a few long fibres, all seeded and static, so plates multiplied over it
// pick up the paper's texture the way ink does.
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.949, 0.933, 0.902, 1.0);
uniform float grain = 0.06;
uniform float mottle = 0.05;
uniform float fibres = 0.06;
uniform float seed = 1.0;
uniform float edge_shade = 0.06;   // darkening toward the sheet's edges
uniform vec2 sheet_size = vec2(1800.0, 1000.0);

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.1234);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float m = vnoise(pos / 160.0) * 0.6 + vnoise(pos / 41.0) * 0.4;
	float g = hash(floor(pos));
	// fibres: noise stretched along two directions, thresholded to thin hairs
	float f1 = smoothstep(0.86, 0.97, vnoise(vec2(pos.x / 2.2, pos.y / 70.0) + 5.0));
	float f2 = smoothstep(0.88, 0.98, vnoise(vec2((pos.x + pos.y) / 90.0, (pos.x - pos.y) / 2.6) + 17.0));
	vec2 e = min(pos, sheet_size - pos) / 60.0;
	float edge = 1.0 - edge_shade * (1.0 - clamp(min(e.x, e.y), 0.0, 1.0));
	vec3 c = paper.rgb * (1.0 - mottle * (m - 0.5) * 2.0) * (1.0 - grain * (g - 0.5)) * (1.0 - fibres * max(f1, f2)) * edge;
	COLOR = vec4(c, paper.a);
}
