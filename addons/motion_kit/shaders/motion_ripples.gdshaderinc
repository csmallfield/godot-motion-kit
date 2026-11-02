// SPDX-License-Identifier: Apache-2.0
// Motion Kit: event rings for shaders (MotionRipples). Each ring starts at a
// world point (x, z), runs outward at mk_ripple_speed, is mk_ripple_width
// wide and fades by exp(-age * mk_ripple_decay) times its strength. Rings
// are (x, z, age seconds, strength); age < 0 = unused.
//   vec3 r = mk_ripple(world.xz);   // r.xy: push away from the centres, r.z: total amount
uniform vec4 mk_ripples[16];
uniform int mk_ripple_count = 0;
uniform float mk_ripple_speed = 3.0;
uniform float mk_ripple_width = 0.6;
uniform float mk_ripple_decay = 2.2;

vec3 mk_ripple(vec2 p) {
	vec2 push = vec2(0.0);
	float amount = 0.0;
	for (int i = 0; i < mk_ripple_count; i++) {
		vec4 r = mk_ripples[i];
		if (r.z < 0.0) {
			continue;
		}
		vec2 d = p - r.xy;
		float dist = length(d);
		float k = 1.0 - smoothstep(0.0, mk_ripple_width, abs(dist - r.z * mk_ripple_speed));
		k *= r.w * exp(-r.z * mk_ripple_decay);
		amount += k;
		push += (dist > 1e-4 ? d / dist : vec2(0.0)) * k;
	}
	return vec3(push, amount);
}
