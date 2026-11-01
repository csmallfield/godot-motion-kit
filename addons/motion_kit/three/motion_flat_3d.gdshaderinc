// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D flat look: the parts every MotionFlat3D material shares, so
// faces, edges and decals of one object move and fog identically.
//
// Group motion. Every vertex carries its object's ground anchor in UV2 (world
// x, z). Two frame-pure motions displace whole objects vertically by their
// distance from an origin, so a merged city mesh can still sink in rings or
// pulse on the beat without per-object nodes:
//   sink   rings leave from sink_origin: ring k starts at sink_t = k * sink_step
//          (k = floor(d / sink_width); 0 width = continuous) and drops
//          sink_depth over sink_dur frames, easing in. sink_t < 0: untouched.
//   pulse  a bob of pulse_amp travels out at pulse_speed units a frame and
//          decays by pulse_decay per frame, fading out by pulse_reach.
//          pulse_t is frames since the beat.
// MotionFlat3D.offset() mirrors this in GDScript for nodes moved on the CPU.
//
// Fog. Linear by view depth (-VERTEX.z) from fog_begin to fog_end, towards
// fog_color, amount fog_amount. Depth fog works the same in perspective and
// orthographic views; MotionFlat3D sets begin/end relative to the lens
// distance so a dolly zoom keeps the same fog around its target.

uniform float groups_on = 1.0;
uniform vec2 sink_origin = vec2(0.0);
uniform float sink_t = -1e4;
uniform float sink_step = 1.5;
uniform float sink_width = 1.8;
uniform float sink_dur = 8.0;
uniform float sink_depth = 8.0;
uniform vec2 pulse_origin = vec2(0.0);
uniform float pulse_t = 1e4;
uniform float pulse_speed = 2.0;
uniform float pulse_amp = 0.0;
uniform float pulse_decay = 0.35;
uniform float pulse_reach = 14.0;

uniform vec4 fog_color : source_color = vec4(1.0);
uniform float fog_begin = 1e5;
uniform float fog_end = 2e5;
uniform float fog_amount = 0.0;
uniform float energy = 1.0;

float mk_group_offset(vec2 key) {
	if (groups_on < 0.5) {
		return 0.0;
	}
	float off = 0.0;
	float d = distance(key, sink_origin);
	if (sink_t >= 0.0) {
		float k = sink_width > 0.0 ? floor(d / sink_width) : d;
		float p = clamp((sink_t - k * sink_step) / max(sink_dur, 1e-3), 0.0, 1.0);
		off -= p * p * sink_depth;
	}
	if (pulse_amp != 0.0) {
		float dp = distance(key, pulse_origin);
		float age = pulse_t - dp / max(pulse_speed, 1e-3);
		if (age >= 0.0) {
			off -= pulse_amp * exp(-age * pulse_decay) * (1.0 - smoothstep(pulse_reach * 0.6, pulse_reach, dp));
		}
	}
	return off;
}

vec3 mk_fog(vec3 col, float view_depth) {
	float t = clamp((view_depth - fog_begin) / max(fog_end - fog_begin, 1e-3), 0.0, 1.0);
	return mix(col, fog_color.rgb, t * fog_amount);
}
