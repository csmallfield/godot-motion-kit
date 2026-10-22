// SPDX-License-Identifier: Apache-2.0
// MotionPatternPlane: an infinite patterned ground (and optional ceiling) seen
// through a pinhole camera, ray-cast per pixel, with a sky and a sun above it.
//
// Camera space: x right, y up, z forward; the camera sits at the origin,
// `height` above the ground. The ground is y = -height + channel * x^2 + hill * z^2
// (channel curls the sides up into a half-pipe or tube, hill folds the ground
// ahead up into a wall); every ray is intersected analytically. The pattern is
// evaluated in ground coordinates with a road curve (x - curve * z^2), a
// sideways wave and a ring displacement, and box-filtered with screen-space
// derivatives, so it stays free of moire down to the horizon.
shader_type canvas_item;

uniform vec2 size = vec2(1920.0, 1080.0);
uniform vec2 centre = vec2(960.0, 540.0);      // principal point (pixels)
uniform float focal = 771.0;                   // pixels
uniform vec3 cam_rot = vec3(0.0);              // pitch, yaw, roll (radians)
uniform float height = 2.0;
uniform vec2 ground_offset = vec2(0.0);        // lateral offset, travel (world units)
uniform float curve = 0.0;
uniform float channel = 0.0;
uniform float hill = 0.0;
uniform vec3 wave = vec3(0.0, 0.2, 0.0);       // amplitude, frequency (per unit z), phase

uniform int pattern = 0;                        // 0 checker, 1 stripes, 2 grid, 3 dots, 4 texture
uniform vec2 cell = vec2(2.0);
uniform vec2 cell_scroll = vec2(2.0);           // cell size the offsets scroll at
uniform vec2 pattern_shift = vec2(0.0);         // in cells
uniform vec2 motion_blur = vec2(0.0);           // shutter movement, in cells
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_width = 0.08;                // grid / dots, fraction of a cell
uniform sampler2D pattern_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 accent_color : source_color = vec4(0.0);
uniform float accent_every = 0.0;               // a lane every n cells (0 = off)
uniform float accent_width = 1.0;               // cells

uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 fog_range = vec2(40.0, 300.0);     // distance where fog starts, where it is total

uniform bool ceiling = false;
uniform float ceiling_height = 12.0;
uniform vec4 ceiling_a : source_color = vec4(1.0);
uniform vec4 ceiling_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float ceiling_alpha = 1.0;

uniform bool draw_sky = true;
uniform vec4 sky_top : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.2, 0.0, 0.2, 1.0);
uniform float sky_spread = 0.5;                 // elevation (sine) where the sky reaches sky_top
uniform vec3 sun_dir = vec3(0.0, 0.1, 1.0);
uniform float sun_size = 0.0;                   // angular radius (radians); 0 = no sun
uniform vec4 sun_top : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 sun_bottom : source_color = vec4(1.0, 0.1, 0.5, 1.0);
uniform vec3 sun_bands = vec3(7.0, 0.0, 0.25);  // count, scroll, top of the banded area (-1..1)
uniform float sun_glow = 0.3;

uniform vec2 clip = vec2(-1e9, 1e9);            // draw surfaces whose forward distance is in [x, y)

uniform vec4 ring = vec4(0.0, 0.0, -1.0, 2.0);  // centre x, centre z (camera-relative), radius, width
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float ring_push = 0.0;                  // pattern displacement at the ring (cells)

uniform float level = 1.0;                      // multiplies the colour (fade to black)
uniform float opacity = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

vec3 cam_to_world(vec3 d) {
	float cr = cos(cam_rot.z), sr = sin(cam_rot.z);
	d = vec3(d.x * cr - d.y * sr, d.x * sr + d.y * cr, d.z);
	float cp = cos(cam_rot.x), sp = sin(cam_rot.x);
	d = vec3(d.x, d.y * cp + d.z * sp, -d.y * sp + d.z * cp);
	float cy = cos(cam_rot.y), sy = sin(cam_rot.y);
	return vec3(d.x * cy + d.z * sy, d.y, -d.x * sy + d.z * cy);
}

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

vec4 sky_colour(vec3 r) {
	vec4 col = mix(sky_horizon, sky_top, smoothstep(0.0, sky_spread, r.y));
	if (sun_size > 0.0) {
		vec3 sd = normalize(sun_dir);
		float ang = acos(clamp(dot(r, sd), -1.0, 1.0));
		float px = 1.5 / focal;
		float disc = 1.0 - smoothstep(sun_size - px, sun_size + px, ang);
		float v = (r.y - sd.y) / sun_size;                // -1 bottom .. 1 top
		if (v < sun_bands.z) {
			// bands get thicker toward the bottom (OutRun sun)
			float depth = clamp((sun_bands.z - v) / (sun_bands.z + 1.0), 0.0, 1.0);
			float q = fract(v * sun_bands.x * 0.5 + sun_bands.y);
			float cut = depth * 0.7;
			float aa = sun_bands.x * 0.5 * px / sun_size * 2.0;
			disc *= smoothstep(cut - aa, cut + aa, q);
		}
		vec4 sc = mix(sun_bottom, sun_top, clamp(v * 0.5 + 0.5, 0.0, 1.0));
		col = mix(col, sc, disc);
		col.rgb += sun_top.rgb * sun_glow * exp(-max(ang - sun_size, 0.0) / (sun_size * 1.5));
	}
	return col;
}

void fragment() {
	vec2 px = local;
	vec3 d = normalize(vec3(px.x - centre.x, centre.y - px.y, focal));
	vec3 r = cam_to_world(d);

	// ground: (channel r.x^2 + hill r.z^2) t^2 - r.y t - height = 0, nearest positive root
	float A = max(channel * r.x * r.x + hill * r.z * r.z, 0.0);
	float S = sqrt(max(r.y * r.y + 4.0 * A * height, 0.0));
	float den = S - r.y;
	float tg = den > 1e-7 ? 2.0 * height / den : -1.0;
	float tc = (ceiling && r.y > 1e-5) ? ceiling_height / r.y : -1.0;
	bool hit_g = tg > 0.0;
	bool hit_c = tc > 0.0 && (!hit_g || tc < tg);
	float t = hit_c ? tc : tg;

	vec4 col = vec4(0.0);
	bool surface = (hit_g || hit_c);
	vec3 P = r * t;
	if (surface && (P.z < clip.x || P.z >= clip.y))
		surface = false;

	if (surface) {
		vec2 g = vec2(P.x - curve * P.z * P.z + wave.x * sin(P.z * wave.y + wave.z), P.z);
		if (ring.z > 0.0) {
			vec2 rd = g - ring.xy;
			float dist = length(rd);
			float k = exp(-pow((dist - ring.z) / max(ring.w, 1e-3), 2.0));
			g += (dist > 1e-4 ? rd / dist : vec2(0.0)) * k * ring_push * cell.x;
		}
		vec2 p = g / cell + ground_offset / cell_scroll + pattern_shift;
		vec2 w = max(abs(dFdx(p)), abs(dFdy(p))) + 1e-4;
		w = min(w + motion_blur, vec2(4.0));
		vec4 ca = hit_c ? ceiling_a : color_a;
		vec4 cb = hit_c ? ceiling_b : color_b;
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
		if (pattern == 4) {
			col = textureGrad(pattern_texture, p, dFdx(p), dFdy(p));
		} else {
			col = mix(cb, ca, m);
		}
		if (!hit_c && accent_every > 0.0 && accent_color.a > 0.0) {
			float q = p.x / accent_every;
			float a = band(q, w.x / accent_every, accent_width / accent_every);
			col.rgb = mix(col.rgb, accent_color.rgb, a * accent_color.a);   // keep the surface opaque
		}
		if (!hit_c && ring.z > 0.0 && ring_color.a > 0.0) {
			float dist = length(g - ring.xy);
			float k = exp(-pow((dist - ring.z) / max(ring.w, 1e-3), 2.0));
			col.rgb = mix(col.rgb, ring_color.rgb, k * ring_color.a);
		}
		float fog = smoothstep(fog_range.x, fog_range.y, t);
		col = mix(col, fog_color, fog);
		if (hit_c)
			col.a *= ceiling_alpha;
		if (hit_c && draw_sky && ceiling_alpha < 1.0)
			col = vec4(mix(sky_colour(r).rgb, col.rgb, col.a), 1.0);
	} else if (draw_sky) {
		col = r.y > 0.0 ? sky_colour(r) : sky_horizon;
	}
	col.rgb *= level;
	col.a *= opacity;
	COLOR = col * COLOR;
}
