// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: the body of the cutout shaders (motion_cutout_3d.gdshader,
// motion_cutout_3d_actor.gdshader). The including file declares `flash`,
// `tint` and `opacity`, as instance uniforms or plain ones.

#include "res://addons/motion_kit/three/motion_flat_3d.gdshaderinc"

void fragment() {
	vec3 col = COLOR.rgb * tint.rgb;
	col = mix(col, flash.rgb, flash.a);
	ALBEDO = mk_fog(col * energy, -VERTEX.z);
	// dithered opacity keeps cards in the opaque pass (depth-sorted with the world)
	if (opacity < 0.999) {
		float d = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (d > opacity) {
			discard;
		}
	}
}
