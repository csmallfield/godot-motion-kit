// SPDX-License-Identifier: Apache-2.0
// MotionGradient with a blend mode against what is drawn behind it (CSS
// mix-blend-mode). MotionGradient puts a BackBufferCopy right before it, so
// the screen texture holds the current backdrop.
shader_type canvas_item;

#include "res://addons/motion_kit/shaders/motion_gradient.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform int blend = 1;                    // 1 add (linear dodge), 2 multiply, 3 screen, 4 overlay

float overlay_ch(float b, float s) {
	return b <= 0.5 ? 2.0 * b * s : 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
}

void fragment() {
	vec4 g = gradient_colour() * COLOR;
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
