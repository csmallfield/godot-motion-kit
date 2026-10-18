// SPDX-License-Identifier: Apache-2.0
// MotionCells: a grid of palette-indexed cells drawn from a state texture in
// one quad. Coverage is analytic per pixel (box filter over the pixel's
// footprint), so cells inset by fractional amounts get the same half-covered
// edge pixels an SVG <rect> at x = 1.5 gets in a browser.
shader_type canvas_item;

uniform sampler2D state : filter_nearest;   // R8: palette index / 255
uniform vec4 palette[16];
uniform vec2 cell = vec2(24.0);
uniform float inset = 1.5;
uniform vec4 grid_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float grid_width = 1.0;
uniform ivec2 dims = ivec2(1, 1);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// Fraction of the span [p - w/2, p + w/2] inside [a, b].
float cover(float p, float w, float a, float b) {
	return clamp((min(p + 0.5 * w, b) - max(p - 0.5 * w, a)) / w, 0.0, 1.0);
}

// Coverage of grid lines [k * c, k * c + lw] for the nearest k, k in 0..n.
float line_cover(float p, float w, float c, float lw, int n) {
	float k = floor(p / c);
	float a = 0.0;
	for (float j = k - 1.0; j <= k + 1.0; j += 1.0) {
		if (j >= 0.0 && j <= float(n)) {
			a += cover(p, w, j * c, j * c + lw);
		}
	}
	return min(a, 1.0);
}

void fragment() {
	vec2 fw = max(fwidth(local), vec2(1e-4));
	// Grid: vertical lines, then horizontal ones over them (each with its alpha).
	float gv = line_cover(local.x, fw.x, cell.x, grid_width, dims.x) * grid_color.a;
	float gh = line_cover(local.y, fw.y, cell.y, grid_width, dims.y) * grid_color.a;
	float ga = 1.0 - (1.0 - gv) * (1.0 - gh);
	vec3 pm = grid_color.rgb * ga;     // premultiplied
	float pa = ga;
	// Cells cover the pixel's footprint between them (they never overlap), so
	// their coverages add: sum the cells around the pixel, then lay that over the grid.
	vec3 cp = vec3(0.0);
	float ca = 0.0;
	ivec2 c0 = ivec2(floor(local / cell));
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 ci = c0 + ivec2(dx, dy);
			if (ci.x < 0 || ci.y < 0 || ci.x >= dims.x || ci.y >= dims.y) continue;
			int s = int(round(texelFetch(state, ci, 0).r * 255.0));
			if (s <= 0) continue;
			vec2 lo = vec2(ci) * cell;
			float c = cover(local.x, fw.x, lo.x + inset, lo.x + cell.x - inset)
				* cover(local.y, fw.y, lo.y + inset, lo.y + cell.y - inset);
			vec4 col = palette[min(s, 15)];
			cp += col.rgb * col.a * c;
			ca += col.a * c;
		}
	}
	ca = min(ca, 1.0);
	pm = cp + pm * (1.0 - ca);
	pa = ca + pa * (1.0 - ca);
	COLOR = pa > 0.0 ? vec4(pm / pa, pa) * COLOR : vec4(0.0);
}
