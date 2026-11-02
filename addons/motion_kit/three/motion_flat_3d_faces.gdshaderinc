// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: the face-tone body shared by motion_flat_3d.gdshader
// (back faces culled) and motion_flat_3d_double.gdshader (two-sided, for
// meshes without consistent winding such as MotionSvgMesh logos), and their
// per-instance variants (motion_flat_3d_instanced.gdshader).
#include "res://addons/motion_kit/three/motion_flat_3d.gdshaderinc"

uniform vec4 top : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform vec4 lit : source_color = vec4(0.90, 0.87, 0.82, 1.0);
uniform vec4 dark : source_color = vec4(0.72, 0.68, 0.62, 1.0);
uniform vec4 under : source_color = vec4(0.45, 0.43, 0.40, 1.0);
uniform vec3 light_dir = vec3(-0.33, 0.0, 0.94);
uniform float top_threshold = 0.55;
uniform float soft = 0.0;
// Flash (a hit tint, rgb toward flash.rgb by flash.a): per material, or per
// instance when the including shader defines MK_INSTANCED (GeometryInstance3D
// set_instance_shader_parameter, so one enemy flashes, not every enemy).
#ifdef MK_INSTANCED
instance uniform vec4 flash : source_color = vec4(0.0);
instance uniform vec4 tint : source_color = vec4(1.0);
#else
uniform vec4 flash : source_color = vec4(0.0);
const vec4 tint = vec4(1.0);
#endif

varying vec3 w_normal;

void vertex() {
	VERTEX.y += mk_group_offset(UV2);
	w_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(w_normal);
	vec3 nh = vec3(n.x, 0.0, n.z);
	float h = length(nh);
	float l = dot(nh / max(h, 1e-4), normalize(vec3(light_dir.x, 0.0, light_dir.z)));
	float k = soft > 0.0 ? smoothstep(-soft, soft, l) : step(0.0, l);
	vec3 col = mix(dark.rgb, lit.rgb, k);
	if (n.y > top_threshold) {
		col = top.rgb;
	} else if (n.y < -top_threshold) {
		col = under.rgb;
	}
	col *= COLOR.rgb * tint.rgb;
	col = mix(col, flash.rgb, flash.a);
	ALBEDO = mk_fog(col * energy, -VERTEX.z);
}
