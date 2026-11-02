// SPDX-License-Identifier: Apache-2.0
// MotionCutoutRig2D: one material for every cutout layer of every rig, so
// layers from one atlas batch. Per-character colour rides on the
// CanvasItem's modulate: rgb tints, alpha up to 1 fades, alpha above 1 is a
// hit flash toward `flash_color` (1.5 = halfway). MotionCutoutRig2D.set_look
// writes it.
shader_type canvas_item;

uniform vec3 flash_color : source_color = vec3(1.0);

varying vec4 mk_mod;

void vertex() {
	mk_mod = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float f = clamp(mk_mod.a - 1.0, 0.0, 1.0);
	COLOR = vec4(mix(t.rgb * mk_mod.rgb, flash_color, f), t.a * min(mk_mod.a, 1.0));
}
