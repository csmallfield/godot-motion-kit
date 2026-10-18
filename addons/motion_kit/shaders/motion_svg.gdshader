// SPDX-License-Identifier: Apache-2.0
// MotionSvg's rasters are stored with premultiplied alpha, so bilinear filtering
// and mipmaps never blend an edge toward the black of empty texels (a dark
// fringe wherever a part lies over its own colour). Filter premultiplied, then
// return the straight colour, tinted by the vertex colour (fill, modulate).
shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = (t.a > 0.0 ? vec4(t.rgb / t.a, t.a) : vec4(0.0)) * tint;
}
