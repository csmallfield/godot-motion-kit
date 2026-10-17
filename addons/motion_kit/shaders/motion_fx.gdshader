// SPDX-License-Identifier: Apache-2.0
// MotionFX post stack, applied to the group's rendered content:
//   slice glitch: horizontal bands shifted by per-band offsets (set from MK.rand on the CPU)
//   RGB split: red and cyan ghosts, screen-blended under the content
//   pixelate, brightness (CSS brightness()), goo (alpha threshold after blur)
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 frame_size = vec2(1920.0, 1080.0);  // content size in pixels (authoring space)
uniform int slice_count = 0;                        // 0 = no slicing
uniform float slice_offsets[64];                    // pixels, one per band
uniform float split = 0.0;                          // RGB split distance in pixels
uniform float brightness = 1.0;
uniform float pixel_size = 0.0;                     // 0 = off
uniform float goo_blur = 0.0;                       // pixels; 0 = off
uniform float goo_sharp = 22.0;
uniform vec4 ghost_a : source_color = vec4(1.0, 0.41, 0.54, 1.0);   // red ghost tint (Remotion's feColorMatrix, in sRGB)
uniform vec4 ghost_b : source_color = vec4(0.38, 1.0, 1.0, 1.0);    // cyan ghost tint

vec4 sample_px(sampler2D tex, vec2 px) {
	vec2 uv = px / frame_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
	return texture(tex, uv);
}

vec4 goo(sampler2D tex, vec2 px) {
	// 9-tap box blur of alpha, then a steep threshold; colour from the unblurred content.
	float a = 0.0;
	for (int y = -1; y <= 1; y++)
		for (int x = -1; x <= 1; x++)
			a += sample_px(tex, px + vec2(float(x), float(y)) * goo_blur).a;
	a /= 9.0;
	float t = clamp(a * goo_sharp - goo_sharp * 0.45, 0.0, 1.0);
	vec4 c = sample_px(tex, px);
	vec3 rgb = c.a > 0.001 ? c.rgb : vec3(0.0);
	return vec4(rgb, t);
}

vec4 fetch(sampler2D tex, vec2 px) {
	if (pixel_size > 0.5) px = (floor(px / pixel_size) + 0.5) * pixel_size;
	return goo_blur > 0.0 ? goo(tex, px) : sample_px(tex, px);
}

void fragment() {
	vec2 px = UV * frame_size;
	float off = 0.0;
	if (slice_count > 0) {
		int band = clamp(int(floor(UV.y * float(slice_count))), 0, slice_count - 1);
		off = slice_offsets[band];
	}
	vec4 m = fetch(TEXTURE, px - vec2(off, 0.0));
	vec3 rgb = m.rgb * m.a;
	float a = m.a;
	if (split > 0.5) {
		vec4 r = fetch(TEXTURE, px - vec2(off - split, 0.0));
		vec4 c = fetch(TEXTURE, px - vec2(off + split, 0.0));
		vec3 gr = vec3(r.r, ghost_a.g, ghost_a.b) * r.a;
		vec3 gc = vec3(ghost_b.r, c.g, c.b) * c.a;
		vec3 ghosts = 1.0 - (1.0 - gr) * (1.0 - gc);     // screen
		float ga = 1.0 - (1.0 - r.a) * (1.0 - c.a);
		rgb = rgb + ghosts * (1.0 - a);
		a = a + ga * (1.0 - a);
	}
	COLOR = vec4(rgb * brightness, a);
}
