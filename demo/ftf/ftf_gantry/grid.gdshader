// SPDX-License-Identifier: Apache-2.0
// Neon grid on the city floor far below the circuit (world-space lines).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 line_color : source_color = vec4(0.10, 0.55, 0.75, 1.0);
uniform vec4 base_color : source_color = vec4(0.012, 0.016, 0.05, 1.0);
uniform float cell = 24.0;
uniform float width = 0.06;
uniform float energy = 1.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = wpos.xz / cell;
	vec2 fw = fwidth(g);
	vec2 d = abs(fract(g - 0.5) - 0.5) / max(fw, vec2(1e-4));
	float l = 1.0 - clamp(min(d.x, d.y) - width / max(fw.x, 1e-4) * 0.0, 0.0, 1.0);
	float fade = clamp(1.0 - max(fw.x, fw.y) * 2.0, 0.0, 1.0);   // fade where the grid gets too fine
	ALBEDO = mix(base_color.rgb, line_color.rgb * 1.4, l * fade) * energy;
}
