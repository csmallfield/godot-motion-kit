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

#include "res://addons/motion_kit/shaders/motion_noise.gdshaderinc"

float hash(vec2 p) {
	return mk_hash21(p, seed * 0.618);
}

float vnoise(vec2 p) {
	return mk_vnoise2(p, seed * 0.618);
}

void fragment() {
	vec2 px = FRAGCOORD.xy;
	float n = vnoise(px * frequency) * 0.66 + vnoise(px * frequency * 2.0 + 17.0) * 0.34;
	float n2 = vnoise(px * frequency + 91.0) * 0.66 + vnoise(px * frequency * 2.0 + 53.0) * 0.34;
	float g = clamp(contrast * (centre + (n - 0.5) * amplitude) + lift, 0.0, 1.0);
	float a = clamp(contrast * (centre + (n2 - 0.5) * amplitude) + lift, 0.0, 1.0);
	COLOR = vec4(vec3(g), a * opacity);
}
