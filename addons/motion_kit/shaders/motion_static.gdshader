// SPDX-License-Identifier: Apache-2.0
// Monochrome TV static: two octaves of fine value noise, contrast-stretched,
// with noisy alpha like SVG feTurbulence. A new seed each frame.
shader_type canvas_item;

uniform float seed = 0.0;
uniform float frequency = 0.85;    // cycles per pixel, as feTurbulence baseFrequency
uniform float contrast = 1.6;      // slope
uniform float lift = -0.3;         // intercept
uniform float opacity = 1.0;
uniform float amplitude = 0.62;    // spread of the noise around its centre (feTurbulence is gentle)
uniform float centre = 0.5625;     // feTurbulence fractalNoise sits a little above 0.5

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.618);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 px = FRAGCOORD.xy;
	float n = vnoise(px * frequency) * 0.66 + vnoise(px * frequency * 2.0 + 17.0) * 0.34;
	float n2 = vnoise(px * frequency + 91.0) * 0.66 + vnoise(px * frequency * 2.0 + 53.0) * 0.34;
	float g = clamp(contrast * (centre + (n - 0.5) * amplitude) + lift, 0.0, 1.0);
	float a = clamp(contrast * (centre + (n2 - 0.5) * amplitude) + lift, 0.0, 1.0);
	COLOR = vec4(vec3(g), a * opacity);
}
