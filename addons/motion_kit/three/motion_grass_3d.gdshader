// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: grass tufts (MotionGrass3D, a MultiMesh of flat tuft cards).
// Unlit vertex colour times the instance colour, darker at the root; tips
// sway in the wind and are pushed over and flattened by MotionRipples rings
// (hits, footsteps). Vertex alpha (COLOR.a) is how far up the blade a vertex
// is: 0 at the root, 1 at the tip; the MultiMesh instance colour multiplies
// COLOR (use_colors). Fogs with the MotionFlat3D look.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://addons/motion_kit/three/motion_flat_3d.gdshaderinc"
#include "res://addons/motion_kit/shaders/motion_ripples.gdshaderinc"

uniform vec2 wind_dir = vec2(1.0, 0.3);
uniform float wind_amp = 0.03;
uniform float wind_speed = 1.6;
uniform float time_s = 0.0;
uniform float bend = 0.22;
uniform float flatten = 0.45;
uniform float root_shade = 0.72;

varying float v_tip;
varying vec3 v_col;

void vertex() {
	float tip = COLOR.a;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 r = mk_ripple(root.xz);
	float sway = sin(time_s * wind_speed + root.x * 0.9 + root.z * 0.6) * wind_amp;
	vec2 push = normalize(wind_dir) * sway + r.xy * bend;
	world.xz += push * tip;
	world.y = root.y + (world.y - root.y) * (1.0 - clamp(r.z, 0.0, 1.0) * flatten * tip);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	v_tip = tip;
	v_col = COLOR.rgb;
}

void fragment() {
	vec3 col = v_col * mix(root_shade, 1.0, v_tip);
	ALBEDO = mk_fog(col * energy, -VERTEX.z);
}
