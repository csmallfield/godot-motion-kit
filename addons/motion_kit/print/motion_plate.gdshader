// SPDX-License-Identifier: Apache-2.0
// MotionPlate: one colour plate of a print. The plate's content (rendered
// offscreen, premultiplied) says where ink goes: ink = alpha - luma, so black
// prints solid, greys print a tint, white knocks out. The ink is then screened
// (AM halftone: round, line, square or diamond dots on a rotated grid that
// moves with the plate), roughened, speckled, rolled on by a press roller and
// multiplied onto whatever is under it (paper, earlier plates): overprint.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec4 ink : source_color = vec4(0.914, 0.125, 0.404, 1.0);
uniform float density = 1.0;           // 0 = no ink, 1 = full ink
uniform vec2 plate_size = vec2(1920.0, 1080.0);
uniform float tone_scale = 1.0;        // multiplies the content's ink amount
uniform float cell = 0.0;              // halftone cell in pixels; 0 = solid ink
uniform float angle = 0.2618;          // screen angle, radians
uniform int dot_shape = 0;             // 0 round, 1 line, 2 square, 3 diamond
uniform float roughness = 0.0;         // edge wobble in pixels
uniform float grain = 0.0;             // 0..1 speckles where ink missed the paper
uniform float mottle = 0.0;            // 0..1 uneven ink laydown
uniform float seed = 1.0;
uniform float roll = 1.0;              // 0..1 how far the roller has printed
uniform vec2 roll_dir = vec2(1.0, 0.0);
uniform float roll_soft = 36.0;        // ragged width of the roller's edge, pixels
uniform float roll_shadow = 0.0;       // 0..1 the roller's shadow while it passes
uniform vec2 slur = vec2(0.0);         // a doubled ghost image (press slur), pixels
uniform float slur_amount = 0.0;

#include "res://addons/motion_kit/shaders/motion_noise.gdshaderinc"

float hash(vec2 p) {
	return mk_hash21(p, seed * 0.1234);
}

float vnoise(vec2 p) {
	return mk_vnoise2(p, seed * 0.1234);
}

float ink_at(sampler2D tex, vec2 px) {
	vec2 uv = px / plate_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
	vec4 t = texture(tex, uv);
	float v = clamp(t.a - dot(t.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	if (slur_amount > 0.0) {
		vec2 su = (px - slur) / plate_size;
		vec4 s = texture(tex, su);
		v = max(v, clamp(s.a - dot(s.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0) * slur_amount);
	}
	return clamp(v * tone_scale, 0.0, 1.0);
}

void fragment() {
	vec2 px = UV * plate_size;
	vec2 q = px;
	if (roughness > 0.0) {
		vec2 w = vec2(vnoise(px / 6.0), vnoise(px / 6.0 + 31.7)) - 0.5;
		vec2 w2 = vec2(vnoise(px / 41.0 + 7.1), vnoise(px / 41.0 + 93.3)) - 0.5;
		q += (w * 1.4 + w2 * 0.8) * roughness;
	}
	float a;
	if (cell > 0.5) {
		float c = cos(angle);
		float s = sin(angle);
		vec2 rp = vec2(c * q.x + s * q.y, -s * q.x + c * q.y);
		vec2 idx = floor(rp / cell);
		vec2 local = rp / cell - idx - 0.5;
		vec2 cr = (idx + 0.5) * cell;
		vec2 cc = vec2(c * cr.x - s * cr.y, s * cr.x + c * cr.y);
		float tone = ink_at(TEXTURE, cc);
		float aa = 0.85 / cell;
		if (tone < 0.003) {
			a = 0.0;
		} else if (dot_shape == 1) {
			a = 1.0 - smoothstep(tone * 0.5 - aa, tone * 0.5 + aa, abs(local.y));
		} else if (dot_shape == 2) {
			float h = sqrt(tone) * 0.5;
			a = 1.0 - smoothstep(h - aa, h + aa, max(abs(local.x), abs(local.y)));
		} else if (dot_shape == 3) {
			float h = sqrt(tone * 0.5);
			a = 1.0 - smoothstep(h - aa, h + aa, abs(local.x) + abs(local.y));
		} else {
			float r = mix(sqrt(tone / 3.14159), 0.7072, smoothstep(0.72, 1.0, tone));
			a = 1.0 - smoothstep(r - aa, r + aa, length(local));
		}
		// clip to the artwork's own edge, so solids and tints keep crisp outlines
		a *= clamp(ink_at(TEXTURE, q) / max(tone, 0.05), 0.0, 1.0);
	} else {
		a = ink_at(TEXTURE, q);
	}
	// ink texture: speckles where the ink missed, and uneven laydown
	if (grain > 0.0) {
		float g = hash(floor(px / 1.5));
		a *= 1.0 - step(1.0 - grain * 0.06, g);
		a *= 1.0 - grain * 0.3 * smoothstep(0.55, 0.9, vnoise(px / 2.5));
	}
	if (mottle > 0.0) {
		a *= 1.0 - mottle * vnoise(px / 70.0 + 3.0) * vnoise(px / 17.0);
	}
	// the press roller: ink only where it has passed, with a ragged edge
	vec2 d = normalize(roll_dir);
	float ext = abs(d.x) * plate_size.x + abs(d.y) * plate_size.y;
	float soft = roll_soft / ext;
	float pos = dot(px - plate_size * 0.5, d) / ext + 0.5;
	float front = roll * (1.0 + 2.0 * soft) - soft;
	float edge = (vnoise(px / 19.0 + 11.0) - 0.5) * soft * 1.6;
	a *= 1.0 - smoothstep(front - soft, front, pos + edge);
	float shade = 1.0;
	if (roll_shadow > 0.0 && roll > 0.0 && roll < 1.0) {
		float dist = (pos - front) * ext;
		shade = 1.0 - roll_shadow * exp(-dist * dist / 1800.0) * 0.6 - roll_shadow * 0.4 * exp(-max(dist, 0.0) / 90.0) * step(0.0, dist);
	}
	vec3 col = mix(vec3(1.0), ink.rgb, clamp(a * density * ink.a, 0.0, 1.0));
	COLOR = vec4(col * shade, 1.0);
}
