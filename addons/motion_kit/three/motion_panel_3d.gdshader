// SPDX-License-Identifier: Apache-2.0
// MotionPanel3D: a 2D viewport shown on a quad, unshaded, with energy for glow.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D panel_tex : source_color, filter_linear;
uniform float energy = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(panel_tex, UV);
	ALBEDO = c.rgb * tint.rgb * energy;
	ALPHA = c.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.02;
}
