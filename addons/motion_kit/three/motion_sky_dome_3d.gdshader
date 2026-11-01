// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: sky dome for MotionStage3D worlds (see motion_sky_dome_3d.gd).
// A gradient sky with a banded OutRun sun fixed in the world, drawn on a big
// sphere that follows the camera. The same sky as MotionPatternPlane's, so a
// 3D take and a pattern-plane take can share a look. Unshaded, no fog (the
// horizon colour is the fog colour, so fogged ground meets it seamlessly).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, shadows_disabled;

uniform vec4 sky_top : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.2, 0.0, 0.2, 1.0);
uniform float sky_spread = 0.5;                 // elevation (sine) where the sky reaches sky_top
uniform float sky_curve = 1.0;                  // gradient exponent (above 1 keeps the glow low)
uniform vec3 sun_dir = vec3(0.0, 0.05, -1.0);
uniform float sun_size = 0.0;                   // angular radius (radians); 0 = no sun
uniform vec4 sun_top : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 sun_bottom : source_color = vec4(1.0, 0.1, 0.5, 1.0);
uniform vec3 sun_bands = vec3(7.0, 0.0, 0.25);  // count, scroll, top of the banded area (-1..1)
uniform float sun_glow = 0.3;
uniform float sun_energy = 1.0;
uniform float horizon_cut = 1.0;                // 1 hides the sun below the horizon
uniform float level = 1.0;

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 r = normalize(dir);
	float t = pow(clamp(r.y / max(sky_spread, 1e-3), 0.0, 1.0), sky_curve);
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, smoothstep(0.0, 1.0, t));
	if (sun_size > 0.0) {
		vec3 sd = normalize(sun_dir);
		float ang = acos(clamp(dot(r, sd), -1.0, 1.0));
		float aa = max(fwidth(ang), 1e-5);
		float disc = 1.0 - smoothstep(sun_size - aa, sun_size + aa, ang);
		float v = (asin(clamp(r.y, -1.0, 1.0)) - asin(clamp(sd.y, -1.0, 1.0))) / sun_size;   // -1 bottom .. 1 top
		if (v < sun_bands.z) {
			// bands get thicker toward the bottom (OutRun sun)
			float depth = clamp((sun_bands.z - v) / (sun_bands.z + 1.0), 0.0, 1.0);
			float q = fract(v * sun_bands.x * 0.5 + sun_bands.y);
			float cut = depth * 0.7;
			float qa = max(fwidth(v) * sun_bands.x * 0.5, 1e-5);
			disc *= smoothstep(cut - qa, cut + qa, q);
		}
		float above = mix(1.0, smoothstep(-aa, aa, r.y), horizon_cut);
		vec3 sc = mix(sun_bottom.rgb, sun_top.rgb, clamp(v * 0.5 + 0.5, 0.0, 1.0)) * sun_energy;
		col = mix(col, sc, disc * above);
		col += sun_top.rgb * sun_glow * exp(-max(ang - sun_size, 0.0) / (sun_size * 1.5)) * mix(1.0, smoothstep(-0.02, 0.02, r.y), horizon_cut);
	}
	ALBEDO = col * level;
}
