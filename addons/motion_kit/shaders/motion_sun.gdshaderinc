// SPDX-License-Identifier: Apache-2.0
// Motion Kit banded OutRun sun, shared by MotionPatternPlane, MotionPlaneScan
// and MotionSkyDome3D. Each caller measures its own sun coordinate and
// antialiasing (screen pixels for the planes, fwidth for the dome), so only
// the band shape lives here.
// Include with
//   #include "res://addons/motion_kit/shaders/motion_sun.gdshaderinc"

// Coverage of the sun's bands at `v` (-1 bottom .. 1 top of the disc).
// bands = (count, scroll, top of the banded area); `aa` = edge softness in
// band phase. Bands get thicker toward the bottom; 1.0 above bands.z.
float sun_band_cut(float v, vec3 bands, float aa) {
	if (v < bands.z) {
		float depth = clamp((bands.z - v) / (bands.z + 1.0), 0.0, 1.0);
		float q = fract(v * bands.x * 0.5 + bands.y);
		float cut = depth * 0.7;
		return smoothstep(cut - aa, cut + aa, q);
	}
	return 1.0;
}

// Sun colour from bottom to top across the disc.
vec4 sun_tint(float v, vec4 bottom, vec4 top) {
	return mix(bottom, top, clamp(v * 0.5 + 0.5, 0.0, 1.0));
}

// Glow falloff outside a sun of angular radius `radius` at angle `ang`.
float sun_glow_k(float ang, float radius) {
	return exp(-max(ang - radius, 0.0) / (radius * 1.5));
}
