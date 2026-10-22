// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: flat, emissive-style material for MotionStage3D worlds.
// Vertex colour x tint x energy (energy above 1 feeds the environment's glow).
// UV2.x is a "light position" (track distance, logo x...): parts with
// lit_from <= UV2.x <= lit_to are on, the rest sit at `dim`. Animating lit_to
// runs a light chase; moving both runs a window along (a light trail on a
// track ribbon); animating energy flickers or cuts a group. Environment fog
// applies.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform float lit_to = 1e9;
uniform float lit_from = -1e9;
uniform float lit_soft = 0.0;
uniform float dim = 0.0;

void fragment() {
	float d1 = lit_to - UV2.x;
	float d0 = UV2.x - lit_from;
	float on = lit_soft > 0.0
		? clamp(d1 / lit_soft + 1.0, 0.0, 1.0) * clamp(d0 / lit_soft + 1.0, 0.0, 1.0)
		: step(0.0, d1) * step(0.0, d0);
	ALBEDO = COLOR.rgb * tint.rgb * energy * mix(dim, 1.0, on);
}
