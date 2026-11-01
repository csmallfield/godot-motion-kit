// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: patterned, flat emissive material for MotionStage3D worlds
// (see motion_pattern_3d.gd). A box-filtered checker / stripes / grid
// evaluated per pixel in one of three spaces:
//   space 0  world XZ: an endless board on a ground plane (world-locked, so
//            the plane mesh can follow the camera)
//   space 1  UV in metres (uv_scale): building faces, signs, beams; each face
//            carries its own UVs so the cells line up with its edges
//   space 2  world triplanar: picks XZ / ZY / XY by the face normal
// The filter footprint is the pixel's screen-space derivative plus the
// movement while the shutter is open (`motion`, world metres), so fast travel
// smears the board along the motion instead of strobing or running backwards.
// Extras: per-axis face shading (flat boxes read as solids without lights),
// a glossy sheen toward a direction (the sun's reflection on the board), a
// ring shockwave that tints and pushes the pattern, and the kit's light
// window on UV2.x (lit_from / lit_to) for chases and cuts.
// `grow` sprouts geometry by a key: model-space y is scaled by
// 1 - smoothstep(from, to, UV2.x - key), so towers keyed by track distance lie
// flat on the board far ahead and rise as the camera (key) approaches them.
// Unshaded; environment fog applies, so the pattern fogs like the rest of the
// world. Vertex COLOR tints color_a (one material, many building colours).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int pattern = 0;                         // 0 checker, 1 stripes (along u), 2 grid, 3 solid (color_a)
uniform int space = 0;                           // 0 world XZ, 1 UV (metres), 2 triplanar
uniform vec2 cell = vec2(4.0);                   // cell size (metres)
uniform vec2 offset = vec2(0.0);                 // pattern offset in cells (scroll)
uniform vec2 uv_scale = vec2(1.0);               // UV -> metres for space 1
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_width = 0.08;                 // grid line width, fraction of a cell
uniform float energy = 1.0;
uniform float energy_b = 1.0;                    // extra multiplier on color_b cells
uniform vec3 motion = vec3(0.0);                 // world displacement while the shutter is open
uniform vec3 face_shade = vec3(0.62, 1.0, 0.82); // brightness of faces facing x, y, z

uniform vec4 sheen_color : source_color = vec4(0.0);  // alpha = strength
uniform vec3 sheen_dir = vec3(0.0, 0.05, -1.0);
uniform float sheen_power = 24.0;

uniform vec4 ring = vec4(0.0, 0.0, -1.0, 4.0);   // world centre x, z, radius, width (metres)
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float ring_energy = 2.0;
uniform float ring_push = 0.0;                   // pattern displacement at the ring (cells)

uniform vec3 grow = vec3(0.0);                   // key, from, to (UV2.x - key); off while to <= from

uniform float lit_to = 1e9;
uniform float lit_from = -1e9;
uniform float lit_soft = 0.0;
uniform float dim = 0.0;

varying vec3 wpos;

void vertex() {
	if (grow.z > grow.y)
		VERTEX.y *= 1.0 - smoothstep(grow.y, grow.z, UV2.x - grow.x);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

#include "res://addons/motion_kit/plane/motion_pattern.gdshaderinc"

float grid(vec2 p, vec2 w, float lw) {
	vec2 g = vec2(band(p.x + 0.5 * lw, w.x, lw), band(p.y + 0.5 * lw, w.y, lw));
	return max(g.x, g.y);
}

void fragment() {
	vec3 n = normalize(cross(dFdx(wpos), dFdy(wpos)));
	vec3 an = abs(n);
	vec2 q;
	vec2 mv;
	if (space == 1) {
		q = UV * uv_scale;
		mv = vec2(0.0);
	} else if (space == 0 || (an.y >= an.x && an.y >= an.z)) {
		q = wpos.xz;
		mv = motion.xz;
	} else if (an.x >= an.z) {
		q = wpos.zy;
		mv = motion.zy;
	} else {
		q = wpos.xy;
		mv = motion.xy;
	}
	float rk = 0.0;
	if (ring.z > 0.0 && space != 1) {
		vec2 rd = wpos.xz - ring.xy;
		float dist = length(rd);
		rk = exp(-pow((dist - ring.z) / max(ring.w, 1e-3), 2.0));
		if (space == 0)
			q += (dist > 1e-4 ? rd / dist : vec2(0.0)) * rk * ring_push * cell.x;
	}
	vec2 p = q / cell + offset;
	vec2 w = max(abs(dFdx(p)), abs(dFdy(p))) + 1e-4;
	w = min(w + abs(mv) / cell, vec2(4.0));
	float m;
	if (pattern == 0) {
		m = checker(p, w);
	} else if (pattern == 1) {
		m = band(p.x, w.x, 0.5);
	} else if (pattern == 2) {
		m = grid(p, w, line_width);
	} else {
		m = 1.0;
	}
	vec3 col = mix(color_b.rgb * energy_b, color_a.rgb * COLOR.rgb, m);
	col *= dot(an * an, face_shade);
	if (sheen_color.a > 0.0) {
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		vec3 v = normalize(wpos - cam);
		vec3 nn = dot(n, v) > 0.0 ? -n : n;
		float s = pow(max(dot(reflect(v, nn), normalize(sheen_dir)), 0.0), sheen_power);
		col += sheen_color.rgb * sheen_color.a * s;
	}
	if (rk > 0.0 && ring_color.a > 0.0)
		col = mix(col, ring_color.rgb * ring_energy, rk * ring_color.a);
	float d1 = lit_to - UV2.x;
	float d0 = UV2.x - lit_from;
	float on = lit_soft > 0.0
		? clamp(d1 / lit_soft + 1.0, 0.0, 1.0) * clamp(d0 / lit_soft + 1.0, 0.0, 1.0)
		: step(0.0, d1) * step(0.0, d0);
	ALBEDO = col * energy * mix(dim, 1.0, on);
}
