// SPDX-License-Identifier: Apache-2.0
// CRT overlay: scanlines, a slow rolling bright band and a tube vignette.
// Matches the SCF Remotion CRT component (4 px scanline period, 0.38 dark,
// 220 px roll band, elliptical vignette from 55% to 100%).
shader_type canvas_item;

uniform vec2 frame_size = vec2(1920.0, 1080.0);
uniform float line_dark = 0.38;
uniform float line_period = 4.0;
uniform float roll_y = -1000.0;     // top of the roll band, pixels
uniform float roll_height = 220.0;
uniform float roll_strength = 0.05;
uniform float vignette = 0.7;
uniform float vignette_start = 0.55;

void fragment() {
	vec2 px = UV * frame_size;
	// scanlines counted from the bottom edge (CSS repeating-linear-gradient at 0deg)
	float from_bottom = frame_size.y - px.y;
	float dark = mod(from_bottom, line_period) >= line_period * 0.5 ? line_dark : 0.0;
	// vignette: ellipse through the corners
	vec2 d = (px - frame_size * 0.5) / (frame_size * 0.5 * sqrt(2.0));
	float v = clamp((length(d) - vignette_start) / (1.0 - vignette_start), 0.0, 1.0) * vignette;
	// roll band: transparent → white → transparent
	float t = (px.y - roll_y) / roll_height;
	float roll = (t >= 0.0 && t <= 1.0) ? (1.0 - abs(t * 2.0 - 1.0)) * roll_strength : 0.0;
	// composite, premultiplied: band (white) under scanlines (black) under vignette (black)
	vec4 c = vec4(vec3(roll), roll);
	c = vec4(0.0, 0.0, 0.0, dark) + c * (1.0 - dark);
	c = vec4(0.0, 0.0, 0.0, v) + c * (1.0 - v);
	COLOR = vec4(c.rgb / max(c.a, 1e-4), c.a);
}
