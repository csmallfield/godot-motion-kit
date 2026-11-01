// SPDX-License-Identifier: Apache-2.0
// Motion Kit shared hash / value noise / fbm. Every function takes its seed
// offset (or constants) as arguments, so each shader keeps its own exact
// numbers: e.g. `float hash(vec2 p) { return mk_hash21(p, seed * 0.618); }`.
// Include with
//   #include "res://addons/motion_kit/shaders/motion_noise.gdshaderinc"

// 2D cell hash in [0, 1). `s` is added before the first fract (the seed term).
float mk_hash21(vec2 p, float s) {
	p = fract(p * vec2(123.34, 456.21) + s);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 2D value noise in [0, 1): smoothstep-interpolated mk_hash21 lattice.
float mk_vnoise2(vec2 p, float s) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mk_hash21(i, s), b = mk_hash21(i + vec2(1, 0), s), c = mk_hash21(i + vec2(0, 1), s), d = mk_hash21(i + vec2(1, 1), s);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 3D cell hash in [0, 1). `s` is added before the first fract (the seed term).
float mk_hash31(vec3 p, float s) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13) + s);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// 3D value noise in [0, 1): smoothstep-interpolated mk_hash31 lattice.
float mk_vnoise3(vec3 x, float s) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(mk_hash31(i, s), mk_hash31(i + vec3(1, 0, 0), s), f.x),
				   mix(mk_hash31(i + vec3(0, 1, 0), s), mk_hash31(i + vec3(1, 1, 0), s), f.x), f.y),
			   mix(mix(mk_hash31(i + vec3(0, 0, 1), s), mk_hash31(i + vec3(1, 0, 1), s), f.x),
				   mix(mk_hash31(i + vec3(0, 1, 1), s), mk_hash31(i + vec3(1, 1, 1), s), f.x), f.y), f.z);
}

// 3D fbm of mk_vnoise3: `octaves` octaves, each scaled by `lacunarity` and
// shifted by `shift`, amplitudes 0.5, 0.25, ...
float mk_fbm3(vec3 p, float s, int octaves, float lacunarity, vec3 shift) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * mk_vnoise3(p, s);
		p = p * lacunarity + shift;
		a *= 0.5;
	}
	return v;
}
