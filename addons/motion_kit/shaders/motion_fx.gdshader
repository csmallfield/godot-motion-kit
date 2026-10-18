// SPDX-License-Identifier: Apache-2.0
// MotionFX post stack, applied to the group's rendered content. The viewport
// texture holds premultiplied colour, so samples are used as they come.
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
uniform float invert = 0.0;                         // CSS invert(), applied before brightness
uniform vec2 alpha_matrix = vec2(1.0, 0.0);         // feColorMatrix alpha row: a * x + y
uniform vec4 flood_color : source_color = vec4(0.0); // feFlood + feComposite in (a > 0 to use)
uniform float pixel_size = 0.0;                     // 0 = off
uniform float goo_blur = 0.0;                       // pixels; 0 = off
uniform float goo_sharp = 22.0;
uniform sampler2D blur_tex : filter_linear;          // horizontally blurred content (first pass)
uniform float blur_sigma = 0.0;                     // sigma of that pass, pixels; 0 = no blurred texture
uniform bool source_atop = false;                  // feComposite in=SourceGraphic in2=goo operator=atop
uniform bool blur_main = false;                     // CSS filter: blur() on the content itself
uniform float glow = 0.0;                           // > 0: blurred copy drawn under the content
uniform float glow_strength = 1.0;
uniform float shadow_blur = 0.0;                    // CSS text/box-shadow under the content
uniform vec4 shadow_color : source_color = vec4(0.0);
uniform vec2 shadow_offset = vec2(0.0);
uniform vec4 ghost_a : source_color = vec4(1.0, 0.41, 0.54, 1.0);   // red ghost tint (Remotion's feColorMatrix, in sRGB)
uniform vec4 ghost_b : source_color = vec4(0.38, 1.0, 1.0, 1.0);    // cyan ghost tint

varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;   // modulate x self_modulate, applied at the end (premultiplied)
}

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
	vec3 straight = c.a > 0.001 ? c.rgb / c.a : vec3(0.0);
	return vec4(straight * t, t);   // premultiplied, like every other sample
}

// Outside the frame the content is transparent (not the clamped edge pixel).
vec4 blur_tap(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
	return texture(blur_tex, uv);
}

// Second (vertical) pass of the separable Gaussian, on the horizontally
// blurred texture, using pairs of taps merged into bilinear fetches.
// blur_sigma is in texels of that texture (it includes render_scale).
vec4 vblur(vec2 px) {
	vec2 uv = px / frame_size;
	if (blur_sigma <= 0.01) return vec4(0.0);
	float texel = 1.0 / float(textureSize(blur_tex, 0).y);
	float s = blur_sigma;
	int n = int(ceil(s * 3.0));
	vec4 acc = blur_tap(uv);
	float wsum = 1.0;
	for (int i = 1; i <= n; i += 2) {
		float o1 = float(i);
		float o2 = float(i + 1);
		float w1 = exp(-o1 * o1 / (2.0 * s * s));
		float w2 = exp(-o2 * o2 / (2.0 * s * s));
		float w = w1 + w2;
		float o = (o1 * w1 + o2 * w2) / max(w, 1e-6);
		acc += (blur_tap(uv + vec2(0.0, o * texel)) + blur_tap(uv - vec2(0.0, o * texel))) * w;
		wsum += 2.0 * w;
	}
	return acc / wsum;
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
	vec4 m = blur_main ? vblur(px - vec2(off, 0.0)) : fetch(TEXTURE, px - vec2(off, 0.0));   // premultiplied
	if (alpha_matrix != vec2(1.0, 0.0) || flood_color.a > 0.0) {
		float am = clamp(m.a * alpha_matrix.x + alpha_matrix.y, 0.0, 1.0);
		vec3 straight = m.a > 0.0001 ? m.rgb / m.a : vec3(0.0);
		if (flood_color.a > 0.0) {
			am *= flood_color.a;
			straight = flood_color.rgb;
		}
		m = vec4(straight * am, am);
	}
	if (source_atop) {
		vec4 src = sample_px(TEXTURE, px - vec2(off, 0.0));
		m = src * m.a + m * (1.0 - src.a);
	}
	vec3 rgb = m.rgb;
	float a = m.a;
	if (split > 0.5) {
		vec4 r = fetch(TEXTURE, px - vec2(off - split, 0.0));
		vec4 c = fetch(TEXTURE, px - vec2(off + split, 0.0));
		// Tinted ghosts, premultiplied: the kept channel is already scaled by alpha.
		vec3 gr = vec3(r.r, ghost_a.g * r.a, ghost_a.b * r.a);
		vec3 gc = vec3(ghost_b.r * c.a, c.g, c.b);
		vec3 ghosts = 1.0 - (1.0 - gr) * (1.0 - gc);     // screen
		float ga = 1.0 - (1.0 - r.a) * (1.0 - c.a);
		rgb = rgb + ghosts * (1.0 - a);
		a = a + ga * (1.0 - a);
	}
	// Glow and shadow sit under the content (premultiplied "over").
	if (glow > 0.01) {
		vec4 g = vblur(px) * glow_strength;
		rgb = rgb + g.rgb * (1.0 - a);
		a = a + min(g.a, 1.0) * (1.0 - a);
	}
	if (shadow_blur > 0.0 || shadow_color.a > 0.0) {
		float sa = (blur_sigma > 0.01 ? vblur(px - shadow_offset).a : sample_px(TEXTURE, px - shadow_offset).a) * shadow_color.a;
		rgb = rgb + shadow_color.rgb * sa * (1.0 - a);
		a = a + sa * (1.0 - a);
	}
	rgb = mix(rgb, vec3(a) - rgb, invert);            // premultiplied 1 - c
	COLOR = vec4(rgb * brightness * v_mod.rgb * v_mod.a, a * v_mod.a);
}
