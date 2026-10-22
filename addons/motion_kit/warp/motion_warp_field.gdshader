// SPDX-License-Identifier: Apache-2.0
// MotionWarpField: a procedural colour field (rings, rays, stripes, a striped
// sun) and/or an offscreen content layer, both pushed through an analytic,
// seeded domain warp, palette-cycled, kaleidoscoped and mirrored in a rippling
// horizon. Every input is a uniform set from the frame: no state.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 size = vec2(1920.0, 1080.0);
uniform float time = 0.0;            // frames; drives warp motion and ripples
uniform float seed = 1.0;

// ---- field
uniform bool draw_field = true;
uniform vec2 centre = vec2(960.0, 700.0);
uniform float rings = 1.0;           // weight of concentric rings
uniform float rays = 0.0;            // weight of radial rays
uniform float stripes = 0.0;         // weight of horizontal stripes
uniform float freq = 9.0;            // bands per 1000 px (rings, stripes); rays: rays per turn
uniform float phase = 0.0;           // scrolls bands outward / down (in bands)
uniform float twist = 0.0;           // rays twist with radius (turns per 1000 px)
uniform float steps = 0.0;           // posterize the band value into hard stripes (0 = smooth)
uniform float field_level = 1.0;     // 0 = black
uniform float ring_r = -1.0;         // a bright ring around centre (px; < 0 off): a shockwave
uniform float ring_w = 40.0;
uniform float ring_gain = 1.0;
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float iris = 1e6;            // field shown only inside this radius around centre (px)
uniform float iris_soft = 120.0;

// ---- sun
uniform float sun_r = 0.0;           // px, 0 = no sun
uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 sun_color_b : source_color = vec4(1.0, 0.25, 0.55, 1.0);  // bottom of the sun's gradient
uniform float sun_slits = 0.0;       // 70s cut lines across the sun's lower half
uniform float sun_slit_scroll = 0.0;
uniform float sun_glow = 0.0;

// ---- palette: cosine palette a + b cos(2pi (c t + d)), or a gradient LUT
uniform vec3 pal_a = vec3(0.5, 0.5, 0.5);
uniform vec3 pal_b = vec3(0.5, 0.5, 0.5);
uniform vec3 pal_c = vec3(1.0, 1.0, 1.0);
uniform vec3 pal_d = vec3(0.0, 0.33, 0.67);
uniform float pal_shift = 0.0;       // cycles the palette (animate for colour cycling)
uniform float pal_spread = 1.0;      // palette cycles per band
uniform sampler2D lut : source_color, filter_linear, repeat_enable;
uniform float lut_mix = 0.0;         // 0 cosine palette, 1 gradient LUT

// ---- content (offscreen subtree)
uniform bool draw_content = false;
uniform sampler2D content_tex : filter_linear, repeat_disable;
uniform float content_warp = 0.0;    // px of liquid displacement on the content
uniform float content_melt = 0.0;    // px of downward drip on the content
uniform float content_chroma = 0.0;  // px of RGB split on the content
uniform float content_level = 1.0;

// ---- warp
uniform float warp = 0.0;            // px of domain warp on the field
uniform float warp_scale = 420.0;    // px per noise cell
uniform float warp_speed = 0.01;     // noise drift per frame
uniform float kaleido = 0.0;         // 0..1 blend into a kaleidoscope
uniform float segments = 6.0;
uniform float kaleido_spin = 0.0;    // turns

// ---- horizon
uniform float horizon = 1e6;         // px; below it the scene mirrors (water)
uniform float ripple = 6.0;          // px
uniform float reflect_dim = 0.55;
uniform float horizon_glow = 0.0;
uniform vec4 horizon_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);

uniform float level = 1.0;           // overall opacity



float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13) + seed * 0.0137);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// Two-level domain warp (q, then r from q): a liquid displacement vector in [-1, 1].
vec2 warp_vec(vec2 px, float salt) {
	vec3 p = vec3(px / warp_scale, time * warp_speed + salt);
	vec2 q = vec2(fbm(p), fbm(p + vec3(5.2, 1.3, 0.0)));
	vec2 r = vec2(fbm(p + vec3(4.0 * q, 0.0) + vec3(1.7, 9.2, 0.0)),
				  fbm(p + vec3(4.0 * q, 0.0) + vec3(8.3, 2.8, 0.0)));
	return (r - 0.5) * 2.0;
}

vec3 palette(float t) {
	vec3 cos_p = pal_a + pal_b * cos(TAU * (pal_c * t + pal_d));
	vec3 lut_p = texture(lut, vec2(fract(t), 0.5)).rgb;
	return mix(cos_p, lut_p, lut_mix);
}

vec2 kaleido_p(vec2 p) {
	vec2 d = p - centre;
	float r = length(d);
	float a = atan(d.y, d.x) + kaleido_spin * TAU;
	float seg = TAU / max(segments, 1.0);
	a = mod(a, seg);
	a = abs(a - seg * 0.5);
	return centre + r * vec2(cos(a), sin(a));
}

vec4 field_at(vec2 p) {
	// fold first, then warp: the liquid is mirrored too, so the kaleidoscope
	// turns the warp's structure into a symmetric mandala
	vec2 q = p;
	if (kaleido > 0.0) {
		q = mix(q, kaleido_p(q), kaleido);
	}
	if (warp > 0.0) {
		q += warp_vec(q, 0.0) * warp;
	}
	vec2 d = q - centre;
	float r = length(d);
	float v = 0.0;
	v += rings * (r * freq / 1000.0 - phase);
	float ang = atan(d.y, d.x) / TAU + twist * r / 1000.0;
	v += rays * (ang * freq - phase);
	v += stripes * (q.y * freq / 1000.0 - phase);
	float band = v;
	if (steps > 0.0) {
		// hard 70s bands with an anti-aliased edge
		float w = fwidth(v) * steps;
		float s = v * steps;
		float fl = floor(s);
		float edge = smoothstep(1.0 - w, 1.0, fract(s));
		band = (fl + edge) / steps;
	}
	vec3 col = palette(band * pal_spread + pal_shift);
	float a = field_level;
	if (iris < 1e5) {
		a *= 1.0 - smoothstep(iris - iris_soft, iris, length(p - centre));
	}
	if (ring_r >= 0.0) {
		float rr = length(q - centre);
		float k = exp(-pow((rr - ring_r) / max(ring_w, 1.0), 2.0)) * ring_gain;
		col = mix(col, ring_color.rgb, clamp(k, 0.0, 1.0));
	}
	vec4 out_c = vec4(col * a, a);
	// the sun: a disc over the field, gradient top to bottom, slits across its lower half
	if (sun_r > 0.0) {
		vec2 sd = q - centre;
		float sr = length(sd);
		float aa = fwidth(sr) + 0.5;
		float disc = 1.0 - smoothstep(sun_r - aa, sun_r + aa, sr);
		float y = clamp((sd.y / sun_r) * 0.5 + 0.5, 0.0, 1.0);
		vec3 sc = mix(sun_color.rgb, sun_color_b.rgb, y);
		if (sun_slits > 0.0 && sd.y > -sun_r * 0.1) {
			float yy = (sd.y + sun_r * 0.1) / (sun_r * 1.1);
			float lines = fract(yy * sun_slits - sun_slit_scroll);
			float gap = 0.08 + yy * 0.42;
			float cut = smoothstep(gap - 0.04, gap, lines);
			disc *= cut;
		}
		float glow = sun_glow * exp(-max(sr - sun_r, 0.0) / (sun_r * 0.6)) * (1.0 - disc);
		out_c.rgb = mix(out_c.rgb, sc * field_level, disc) + sc * glow * field_level;
		out_c.a = max(out_c.a, disc * field_level);
	}
	return out_c;
}

vec4 content_at(vec2 p) {
	vec2 q = p;
	if (content_warp > 0.0) {
		q += warp_vec(p, 31.7) * content_warp;
	}
	if (content_melt > 0.0) {
		// drips: columns of varying length pulled down from above
		float col = vnoise(vec3(p.x / 38.0, 3.3, seed));
		float col2 = vnoise(vec3(p.x / 9.0, 7.1, seed));
		q.y -= content_melt * (0.35 + 0.65 * col * col) * (0.8 + 0.4 * col2);
	}
	vec2 uv = q / size;
	vec4 c = texture(content_tex, uv);
	if (content_chroma > 0.0) {
		vec2 o = vec2(content_chroma, 0.0) / size;
		vec4 cr = texture(content_tex, uv + o);
		vec4 cb = texture(content_tex, uv - o);
		c = vec4(cr.r, c.g, cb.b, max(c.a, max(cr.a, cb.a)));
	}
	return c * content_level;   // premultiplied
}

vec4 scene(vec2 p) {
	vec4 c = vec4(0.0);
	if (draw_field) {
		c = field_at(p);
	}
	if (draw_content) {
		vec4 k = content_at(p);
		c = k + c * (1.0 - k.a);
	}
	return c;
}

void fragment() {
	vec2 p = UV * size;
	vec4 c;
	if (p.y > horizon) {
		float depth = (p.y - horizon);
		float rip = sin(depth * 0.18 - time * 0.35) * ripple * (0.3 + depth / 300.0)
			+ (vnoise(vec3(p.x / 60.0, depth / 6.0, time * 0.05)) - 0.5) * ripple * 2.0;
		vec2 m = vec2(p.x + rip, horizon - depth * 0.92 - 1.0);
		c = scene(m);
		c.rgb *= reflect_dim * (1.0 - clamp(depth / (size.y - horizon + 1.0), 0.0, 1.0) * 0.45);
	} else {
		c = scene(p);
	}
	if (horizon_glow > 0.0 && horizon < 1e5) {
		float g = exp(-abs(p.y - horizon) / 6.0) * horizon_glow;
		c.rgb += horizon_color.rgb * g;
		c.a = max(c.a, g);
	}
	vec4 m = COLOR;   // modulate (premultiplied)
	COLOR = c * level * vec4(m.rgb, 1.0) * m.a;
}
