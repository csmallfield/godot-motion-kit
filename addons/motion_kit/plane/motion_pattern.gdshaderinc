// SPDX-License-Identifier: Apache-2.0
// Motion Kit box-filtered patterns (checker, bands, lines, dots), shared by
// motion_pattern_plane.gdshader, motion_plane_scan.gdshader and
// three/motion_pattern_3d.gdshader. `w` is always the filter footprint in
// cells (screen-space derivatives plus shutter movement).
//
// With MK_PLANE defined before the include (the two plane shaders), it also
// holds the plane model: camera rotation, the ground / ceiling ray hit, ground
// coordinates, pattern selection, accent lanes, the ring, and the sky with its
// banded sun. Those parts read the plane uniforms, so declare them first.

// Box-filtered checker (Inigo Quilez): w = filter footprint in cells.
float checker(vec2 p, vec2 w) {
	vec2 i = 2.0 * (abs(fract((p - 0.5 * w) * 0.5) - 0.5) - abs(fract((p + 0.5 * w) * 0.5) - 0.5)) / w;
	return 0.5 - 0.5 * i.x * i.y;
}

// Integral of a periodic box (1 on [0, b) of every unit) for filtering bands.
float box_int(float x, float b) {
	return floor(x) * b + min(fract(x), b);
}

float band(float x, float w, float b) {
	return (box_int(x + 0.5 * w, b) - box_int(x - 0.5 * w, b)) / w;
}

float lines(vec2 p, vec2 w, float lw) {
	vec2 d = abs(fract(p + 0.5) - 0.5);
	vec2 a = 1.0 - smoothstep(vec2(lw * 0.5) - w * 0.5, vec2(lw * 0.5) + w * 0.5, d);
	vec2 avg = vec2(lw);   // fades to the average coverage where cells get tiny
	vec2 k = clamp(w * 1.5 - 0.5, 0.0, 1.0);
	a = mix(a, avg, k);
	return max(a.x, a.y);
}

float dots(vec2 p, vec2 w, float r) {
	vec2 q = fract(p) - 0.5;
	float fw = max(w.x, w.y);
	float a = 1.0 - smoothstep(r - fw * 0.5, r + fw * 0.5, length(q));
	return mix(a, 3.14159 * r * r, clamp(fw * 1.5 - 0.5, 0.0, 1.0));
}

#ifdef MK_PLANE
#include "res://addons/motion_kit/shaders/motion_sun.gdshaderinc"

vec3 cam_to_world(vec3 d) {
	float cr = cos(cam_rot.z), sr = sin(cam_rot.z);
	d = vec3(d.x * cr - d.y * sr, d.x * sr + d.y * cr, d.z);
	float cp = cos(cam_rot.x), sp = sin(cam_rot.x);
	d = vec3(d.x, d.y * cp + d.z * sp, -d.y * sp + d.z * cp);
	float cy = cos(cam_rot.y), sy = sin(cam_rot.y);
	return vec3(d.x * cy + d.z * sy, d.y, -d.x * sy + d.z * cy);
}

// Nearest surface along the world ray `r`: ground
// (channel r.x^2 + hill r.z^2) t^2 - r.y t - height = 0, nearest positive root,
// or the ceiling. Returns t (<= 0: no hit); hit_c is true for the ceiling.
float plane_hit(vec3 r, out bool hit_c) {
	float A = max(channel * r.x * r.x + hill * r.z * r.z, 0.0);
	float S = sqrt(max(r.y * r.y + 4.0 * A * height, 0.0));
	float den = S - r.y;
	float tg = den > 1e-7 ? 2.0 * height / den : -1.0;
	float tc = (ceiling && r.y > 1e-5) ? ceiling_height / r.y : -1.0;
	bool hit_g = tg > 0.0;
	hit_c = tc > 0.0 && (!hit_g || tc < tg);
	return hit_c ? tc : tg;
}

// Ground coordinates of the hit point P: road curve and sideways wave.
vec2 ground_coord(vec3 P) {
	return vec2(P.x - curve * P.z * P.z + wave.x * sin(P.z * wave.y + wave.z), P.z);
}

// The ring's gaussian profile at ground point g.
float ring_k(vec2 g) {
	float dist = length(g - ring.xy);
	return exp(-pow((dist - ring.z) / max(ring.w, 1e-3), 2.0));
}

// g pushed outward by the ring (cell_x = current cell width).
vec2 ring_displace(vec2 g, float cell_x) {
	vec2 rd = g - ring.xy;
	float dist = length(rd);
	float k = exp(-pow((dist - ring.z) / max(ring.w, 1e-3), 2.0));
	return g + (dist > 1e-4 ? rd / dist : vec2(0.0)) * k * ring_push * cell_x;
}

// The selected pattern between cb and ca at pattern coordinates p (cells).
vec4 pattern_colour(vec2 p, vec2 w, vec4 ca, vec4 cb) {
	float m;
	if (pattern == 0) {
		m = checker(p, w);
	} else if (pattern == 1) {
		m = band(p.x, w.x, 0.5);
	} else if (pattern == 2) {
		m = lines(p, w, line_width);
	} else if (pattern == 3) {
		m = dots(p, w, line_width);
	} else {
		m = 0.0;
	}
	if (pattern == 4)
		return textureGrad(pattern_texture, p, dFdx(p), dFdy(p));
	return mix(cb, ca, m);
}

// Accent lanes (every accent_every cells, accent_width wide) mixed into rgb;
// keeps the surface opaque.
vec3 accent_lanes(vec3 rgb, vec2 p, vec2 w, vec4 acc) {
	float q = p.x / accent_every;
	float a = band(q, w.x / accent_every, accent_width / accent_every);
	return mix(rgb, acc.rgb, a * acc.a);
}

// Sky gradient with the banded sun of angular radius ss; px = sun edge
// softness (radians); clamp_aa limits the band softness to half a band.
vec4 plane_sky(vec3 r, float ss, float px, bool clamp_aa) {
	vec4 col = mix(sky_horizon, sky_top, smoothstep(0.0, sky_spread, r.y));
	if (ss > 0.0) {
		vec3 sd = normalize(sun_dir);
		float ang = acos(clamp(dot(r, sd), -1.0, 1.0));
		float disc = 1.0 - smoothstep(ss - px, ss + px, ang);
		float v = (r.y - sd.y) / ss;                // -1 bottom .. 1 top
		float aa = sun_bands.x * 0.5 * px / ss * 2.0;
		if (clamp_aa)
			aa = min(aa, 0.5);
		disc *= sun_band_cut(v, sun_bands, aa);
		vec4 sc = sun_tint(v, sun_bottom, sun_top);
		col = mix(col, sc, disc);
		col.rgb += sun_top.rgb * sun_glow * sun_glow_k(ang, ss);
	}
	return col;
}
#endif
