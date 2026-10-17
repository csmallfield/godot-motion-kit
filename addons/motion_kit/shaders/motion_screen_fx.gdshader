// SPDX-License-Identifier: Apache-2.0
// Screen-space transition effects over whatever is already drawn:
//   mode 0 glitch: slice displacement + RGB split, fading to a solid colour
//   mode 1 crt:    the picture squashes to a line, then a dot, on black
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform int mode = 0;
uniform float t = 0.0;                 // 0 = untouched, 1 = fully covered
uniform vec4 cover_color : source_color = vec4(0.07, 0.07, 0.07, 1.0);
uniform float slice_offsets[32];       // in UV units, set from MK.rand on the CPU
uniform int slice_count = 18;
uniform float split = 0.0;             // UV units
uniform vec2 squash = vec2(1.0);       // crt: x and y scale of the picture
uniform float bright = 0.0;            // crt: flash

void fragment() {
	vec2 uv = SCREEN_UV;
	if (mode == 0) {
		int band = clamp(int(floor(uv.y * float(slice_count))), 0, slice_count - 1);
		float off = slice_offsets[band];
		vec3 m = texture(screen, uv - vec2(off, 0.0)).rgb;
		float r = texture(screen, uv - vec2(off - split, 0.0)).r;
		float b = texture(screen, uv - vec2(off + split, 0.0)).b;
		vec3 c = vec3(r, m.g, b);
		float k = smoothstep(0.55, 1.0, t);
		COLOR = vec4(mix(c, cover_color.rgb, k), 1.0);
	} else {
		vec2 p = (uv - 0.5) / max(squash, vec2(1e-4)) + 0.5;
		bool inside = p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0;
		// Only the shrinking picture flashes; everything around it is the dark tube.
		vec3 c = inside ? min(texture(screen, p).rgb * (1.0 + bright * 4.0) + bright, vec3(1.0)) : vec3(0.0);
		COLOR = vec4(c, 1.0);
	}
}
