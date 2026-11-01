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

#define MK_PLANE
#include "res://addons/motion_kit/plane/motion_pattern.gdshaderinc"

vec4 sky_colour(vec3 r) {
	return plane_sky(r, sun_size, 1.5 / focal, false);
}

void fragment() {
	vec2 px = local;
	vec3 d = normalize(vec3(px.x - centre.x, centre.y - px.y, focal));
	vec3 r = cam_to_world(d);

	bool hit_c;
	float t = plane_hit(r, hit_c);

	vec4 col = vec4(0.0);
	bool surface = t > 0.0;
	vec3 P = r * t;
	if (surface && (P.z < clip.x || P.z >= clip.y))
		surface = false;

	if (surface) {
		vec2 g = ground_coord(P);
		if (ring.z > 0.0)
			g = ring_displace(g, cell.x);
		vec2 p = g / cell + ground_offset / cell_scroll + pattern_shift;
		vec2 w = max(abs(dFdx(p)), abs(dFdy(p))) + 1e-4;
		w = min(w + motion_blur, vec2(4.0));
		vec4 ca = hit_c ? ceiling_a : color_a;
		vec4 cb = hit_c ? ceiling_b : color_b;
		col = pattern_colour(p, w, ca, cb);
		if (!hit_c && accent_every > 0.0 && accent_color.a > 0.0)
			col.rgb = accent_lanes(col.rgb, p, w, accent_color);
		if (!hit_c && ring.z > 0.0 && ring_color.a > 0.0)
			col.rgb = mix(col.rgb, ring_color.rgb, ring_k(g) * ring_color.a);
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
