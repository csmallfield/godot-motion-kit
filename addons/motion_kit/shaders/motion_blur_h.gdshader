// SPDX-License-Identifier: Apache-2.0
// First pass of MotionFX's separable Gaussian blur: horizontal, on the
// premultiplied content texture. The vertical pass happens in motion_fx.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float sigma = 1.0;     // pixels (of the texture)

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float s = max(sigma, 0.01);
	int n = int(ceil(s * 3.0));
	vec4 acc = texture(TEXTURE, UV);
	float wsum = 1.0;
	// Pairs of taps merged into one bilinear fetch each.
	for (int i = 1; i <= n; i += 2) {
		float o1 = float(i);
		float o2 = float(i + 1);
		float w1 = exp(-o1 * o1 / (2.0 * s * s));
		float w2 = exp(-o2 * o2 / (2.0 * s * s));
		float w = w1 + w2;
		float o = (o1 * w1 + o2 * w2) / max(w, 1e-6);
		acc += (texture(TEXTURE, UV + vec2(o * texel.x, 0.0)) + texture(TEXTURE, UV - vec2(o * texel.x, 0.0))) * w;
		wsum += 2.0 * w;
	}
	COLOR = acc / wsum;
}
