// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: flat cutout parts (MotionSvgMesh with `flat`, a card per SVG
// part). Unlit vertex colour, so a part keeps the colour it was drawn in
// whatever way it turns (face tones by normal would flip a card between lit
// and dark as a character turns). Two-sided. Per-instance `flash` (hit tint,
// rgb toward flash.rgb by flash.a), `tint` (multiplies) and `opacity`, so
// characters sharing one material react one at a time. Fogs with the look
// (motion_flat_3d.gdshaderinc); no group motion.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://addons/motion_kit/three/motion_flat_3d.gdshaderinc"

instance uniform vec4 flash : source_color = vec4(0.0);
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float opacity = 1.0;

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
