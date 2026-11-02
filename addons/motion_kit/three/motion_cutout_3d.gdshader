// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: flat cutout parts (MotionSvgMesh with `flat`, a card per SVG
// part). Unlit vertex colour, so a part keeps the colour it was drawn in
// whatever way it turns (face tones by normal would flip a card between lit
// and dark as a character turns). Two-sided. Per-instance `flash` (hit tint,
// rgb toward flash.rgb by flash.a), `tint` (multiplies) and `opacity`, so
// props sharing one material react one at a time. Every mesh using it holds
// a block of the global shader buffer (a few hundred fit under the
// Compatibility renderer): for characters with many parts and views use the
// actor variant (motion_cutout_3d_actor.gdshader, MotionFlat3D.actor), one
// material per character. Fogs with the look (motion_flat_3d.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

instance uniform vec4 flash : source_color = vec4(0.0);
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float opacity = 1.0;

#include "res://addons/motion_kit/three/motion_cutout_3d.gdshaderinc"
