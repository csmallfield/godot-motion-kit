// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: decals from a MotionDecalAtlas (white artwork, alpha) on
// quads laid just off a face. Vertex colour tints the artwork (one atlas cell
// serves red, cream and ink markings). Alpha-blended for clean small type;
// moves and fogs with its object (motion_flat_3d.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

#include "res://addons/motion_kit/three/motion_flat_3d.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float opacity = 1.0;

void vertex() {
	VERTEX.y += mk_group_offset(UV2);
}

void fragment() {
	vec4 t = texture(atlas, UV);
	ALBEDO = mk_fog(COLOR.rgb * energy, -VERTEX.z);
	ALPHA = t.a * COLOR.a * opacity;
}
