// SPDX-License-Identifier: Apache-2.0
// MotionPlaneScan: MotionPatternPlane with time displacement and slit-scan done
// per pixel. Each pixel picks a SOURCE pixel (its own place, or the slit,
// optionally through a perspective wall) and a TIME (frames back), and the
// plane is evaluated there and then from a history texture of the plane's
// time-varying state (travel, cell, motion blur, colours, sun, level).
// One quad, no instancing: a whole stargate costs one plane render (three
// pattern evaluations with the RGB time split on).
//
// The plane part (camera, bends, patterns, sky, sun, ring) is shared with
// motion_pattern_plane.gdshader through plane/motion_pattern.gdshaderinc.
shader_type canvas_item;

uniform vec2 size = vec2(1920.0, 1080.0);
uniform vec2 centre = vec2(960.0, 540.0);
uniform float focal = 771.0;
uniform vec3 cam_rot = vec3(0.0);
uniform float height = 2.0;
uniform vec2 ground_offset = vec2(0.0);
uniform float curve = 0.0;
uniform float channel = 0.0;
uniform float hill = 0.0;
uniform vec3 wave = vec3(0.0, 0.2, 0.0);

uniform int pattern = 0;
uniform vec2 cell = vec2(2.0);
uniform vec2 cell_scroll = vec2(2.0);
uniform vec2 pattern_shift = vec2(0.0);
uniform vec2 motion_blur = vec2(0.0);
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_width = 0.08;
uniform sampler2D pattern_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 accent_color : source_color = vec4(0.0);
uniform float accent_every = 0.0;
uniform float accent_width = 1.0;

uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 fog_range = vec2(40.0, 300.0);

uniform bool ceiling = false;
uniform float ceiling_height = 12.0;
uniform vec4 ceiling_a : source_color = vec4(1.0);
uniform vec4 ceiling_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float ceiling_alpha = 1.0;

uniform bool draw_sky = true;
uniform vec4 sky_top : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.2, 0.0, 0.2, 1.0);
uniform float sky_spread = 0.5;
uniform vec3 sun_dir = vec3(0.0, 0.1, 1.0);
uniform float sun_size = 0.0;
uniform vec4 sun_top : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 sun_bottom : source_color = vec4(1.0, 0.1, 0.5, 1.0);
uniform vec3 sun_bands = vec3(7.0, 0.0, 0.25);
uniform float sun_glow = 0.3;

uniform vec2 clip = vec2(-1e9, 1e9);

uniform vec4 ring = vec4(0.0, 0.0, -1.0, 2.0);
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float ring_push = 0.0;

uniform float level = 1.0;
uniform float opacity = 1.0;

// ---- time: the state history (column i = i frames back)
// rows: 0 (offset.x, offset.y, cell.x, cell.y), 1 (blur.x, blur.y, sun scale, level),
//       2 color_a, 3 color_b, 4 accent_color
uniform sampler2D history : filter_nearest, repeat_disable;
uniform int history_len = 0;                    // 0 = no history: every time shows the present

// ---- scan
uniform float scan = 0.0;                       // 0 own place .. 1 the slit
uniform int scan_axis = 0;                      // 0 vertical slit (walls left and right), 1 horizontal (above and below), 2 both (a tunnel)
uniform vec2 slit_at = vec2(960.0, 540.0);      // the slit lines cross here (pixels): the vanishing point of the walls
uniform float walls = 0.0;                      // 0 flat streaks, 1 perspective walls
uniform vec2 wall_ref = vec2(960.0, 540.0);     // distance from the slit where a wall shows the slit 1:1 (vertical, horizontal)
uniform float wall_near = 24.0;                 // walls: pixels from the slit where the delay starts (it is full at wall_ref)
uniform vec2 delay_span = vec2(960.0, 540.0);   // flat: distance from the slit where the delay is full
uniform float delay = 0.0;                      // frames, at full share
uniform float delay_curve = 1.0;                // share = u ^ curve (u = 0 at the slit .. 1 at the span / near the camera)
uniform float delay_step = 0.0;                 // quantise the delay to steps of this many frames
uniform vec3 ripple = vec3(0.0, 1.0, 0.0);      // + amplitude * sin(2 pi (waves * u - phase)), in shares of delay
uniform float split = 0.0;                      // RGB time split: green lags this many frames more than red, blue twice
uniform float gap = 1.0;                        // walls: mix toward gap_color where the source leaves the frame
uniform vec4 gap_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

#define MK_PLANE
#include "res://addons/motion_kit/plane/motion_pattern.gdshaderinc"

// The state `t` frames back: rows of the history, linearly interpolated.
vec4 hist(int row, float t, vec4 now) {
	if (history_len <= 0)
		return now;
	float tt = clamp(t, 0.0, float(history_len - 1));
	int i0 = int(floor(tt));
	int i1 = min(i0 + 1, history_len - 1);
	return mix(texelFetch(history, ivec2(i0, row), 0), texelFetch(history, ivec2(i1, row), 0), tt - float(i0));
}

vec4 sky_colour(vec3 r, float sun_k, float px) {
	return plane_sky(r, sun_size * sun_k, px, true);
}

// The plane's colour for the ray `r` (from a source pixel) at `back` frames ago.
// g / t / flags are the ray's hit, shared by every time sample.
vec4 shade(vec3 r, bool surface, bool hit_c, vec2 g, float t, float back, float px) {
	vec4 st0 = hist(0, back, vec4(ground_offset, cell));
	vec4 st1 = hist(1, back, vec4(motion_blur, 1.0, 1.0));
	vec4 col;
	if (surface) {
		vec2 cl = st0.zw;
		vec2 gg = g;
		if (ring.z > 0.0)
			gg = ring_displace(gg, cl.x);
		vec2 p = gg / cl + st0.xy / cell_scroll + pattern_shift;
		vec2 w = max(abs(dFdx(p)), abs(dFdy(p))) + 1e-4;
		w = min(w + st1.xy, vec2(4.0));
		vec4 ca = hit_c ? ceiling_a : hist(2, back, color_a);
		vec4 cb = hit_c ? ceiling_b : hist(3, back, color_b);
		col = pattern_colour(p, w, ca, cb);
		vec4 acc = hist(4, back, accent_color);
		if (!hit_c && accent_every > 0.0 && acc.a > 0.0)
			col.rgb = accent_lanes(col.rgb, p, w, acc);
		if (!hit_c && ring.z > 0.0 && ring_color.a > 0.0)
			col.rgb = mix(col.rgb, ring_color.rgb, ring_k(gg) * ring_color.a);
		float fog = smoothstep(fog_range.x, fog_range.y, t);
		col = mix(col, fog_color, fog);
		if (hit_c)
			col.a *= ceiling_alpha;
		if (hit_c && draw_sky && ceiling_alpha < 1.0)
			col = vec4(mix(sky_colour(r, st1.z, px).rgb, col.rgb, col.a), 1.0);
	} else if (draw_sky) {
		col = r.y > 0.0 ? sky_colour(r, st1.z, px) : sky_horizon;
	} else {
		col = vec4(0.0);
	}
	col.rgb *= st1.w;
	return col;
}

void fragment() {
	vec2 px = local;

	// ---- which slit this pixel reads, where on it, and how long ago
	vec2 s = px - slit_at;
	bool vert = scan_axis == 0;
	if (scan_axis == 2)
		vert = abs(s.x) / max(wall_ref.x, 1.0) > abs(s.y) / max(wall_ref.y, 1.0);
	float across = vert ? s.x : s.y;               // signed distance from the slit line
	float along = vert ? s.y : s.x;                // along the slit, from the crossing point
	float a = max(abs(across), 1e-3);
	float ref = vert ? wall_ref.x : wall_ref.y;
	// a perspective wall: the slit seen ever smaller toward the vanishing point
	float along_src = mix(along, along * ref / a, walls);
	vec2 off = vert ? vec2(mix(across, 0.0, scan), mix(along, along_src, scan))
			: vec2(mix(along, along_src, scan), mix(across, 0.0, scan));
	vec2 src = slit_at + off;
	float u_flat = clamp(a / max(vert ? delay_span.x : delay_span.y, 1.0), 0.0, 1.0);
	// walls: time grows with the log of the distance from the slit (perspective
	// flow, accelerating toward the camera, with the past spread evenly enough to read)
	float u_wall = clamp(log(a / wall_near) / log(max(ref / wall_near, 1.001)), 0.0, 1.0);
	float u = mix(u_flat, u_wall, walls);
	float back = delay * (pow(u, delay_curve) + ripple.x * sin(6.2831853 * (ripple.y * u - ripple.z)));
	if (delay_step > 0.0)
		back = floor(back / delay_step + 0.5) * delay_step;
	back = max(back, 0.0);

	// ---- the plane's ray through the source pixel (shared by every time sample)
	vec3 d = normalize(vec3(src.x - centre.x, centre.y - src.y, focal));
	vec3 r = cam_to_world(d);
	bool hit_c;
	float t = plane_hit(r, hit_c);
	bool surface = t > 0.0;
	vec3 P = r * t;
	if (surface && (P.z < clip.x || P.z >= clip.y))
		surface = false;
	vec2 g = ground_coord(P);
	// the sun's edge: one screen pixel, widened where the walls magnify the source
	float spx = max(1.5 / focal, length(fwidth(src)) / focal);

	vec4 col;
	if (split > 0.0) {
		vec4 cr = shade(r, surface, hit_c, g, t, back, spx);
		vec4 cg = shade(r, surface, hit_c, g, t, back + split, spx);
		vec4 cbb = shade(r, surface, hit_c, g, t, back + 2.0 * split, spx);
		col = vec4(cr.r, cg.g, cbb.b, max(cr.a, max(cg.a, cbb.a)));
	} else {
		col = shade(r, surface, hit_c, g, t, back, spx);
	}
	// walls: where the source leaves the frame (toward the vanishing point), the gap
	if (gap > 0.0 && scan > 0.0 && walls > 0.0) {
		float o = vert ? max(-src.y, src.y - size.y) : max(-src.x, src.x - size.x);
		float fw = max(vert ? fwidth(src.y) : fwidth(src.x), 1e-3);
		float k = clamp(o / fw + 0.5, 0.0, 1.0) * gap;
		col = mix(col, gap_color, k);
	}
	col.rgb *= level;
	col.a *= opacity;
	COLOR = col * COLOR;
}
