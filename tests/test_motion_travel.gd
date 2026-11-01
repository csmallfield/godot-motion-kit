# SPDX-License-Identifier: Apache-2.0
# MotionTravel: distance tables from a speed function, keys and anchors;
# lookups, clamping, extrapolation and precision. The reference loops are the
# hand-written tables the FTF pieces used before MotionTravel.
extends RefCounted

const KEYS := [[0.0, 0.0], [40.0, 0.12], [60.0, 1.7], [120.0, 0.9], [420.0, 0.15]]


static func _speed(f: float) -> float:
	return MotionTravel.keyed_speed(KEYS, f)


func test_from_speed_matches_eighths_integration() -> String:
	var t := MotionTravel.from_speed(_speed, 484, 8, true)
	var ref := PackedFloat64Array()
	ref.resize(484)
	var s := 0.0
	for i in range(1, ref.size()):
		for k in 8:
			s += _speed(i - 1 + (k + 0.5) / 8.0) / 8.0
		ref[i] = s
	if t.size() != 484 or not t.precise:
		return "size/precision"
	for f in [0.0, 0.25, 59.5, 60.0, 133.7, 419.0, 482.5]:
		var fc := clampf(f, 0.0, ref.size() - 1.001)
		var i := int(fc)
		var want := lerpf(ref[i], ref[i + 1], fc - i)
		if t.at(f) != want:
			return "at(%s) %s != %s" % [f, t.at(f), want]
	if t.at(-5.0) != 0.0 or t.at(10000.0) != ref[483]:
		return "clamp ends %s %s" % [t.at(-5.0), t.at(10000.0)]
	if t.speed(61.0) != _speed(61.0):
		return "speed"
	return ""


func test_keys_float32_and_frame_speed() -> String:
	var keys := [0, 32, 56, 128, 384]
	var vals := [1.1, 0.9, 0.5, 2.4, 4.0]
	var t := MotionTravel.from_keys(keys, vals, 422, MK.ease_in_out)
	var ref := PackedFloat32Array()
	ref.resize(422)
	var acc := 0.0
	for i in 422:
		ref[i] = acc
		for k in 8:
			acc += MK.interp(i + (k + 0.5) / 8.0, keys, vals, MK.ease_in_out) / 8.0
	for f in [0.0, 12.5, 100.0, 333.3, 420.0]:
		var i := clampi(int(floorf(f)), 0, 420)
		if t.at(f) != lerpf(ref[i], ref[i + 1], clampf(f - i, 0.0, 1.0)):
			return "at(%s)" % f
	var sp := PackedFloat32Array([MK.interp(200.0, keys, vals, MK.ease_in_out)])
	if t.frame_speed(200.7) != sp[0]:
		return "frame_speed %s %s" % [t.frame_speed(200.7), sp[0]]
	return ""


func test_extrapolate() -> String:
	var t := MotionTravel.from_speed(func(_f: float) -> float: return 2.0, 12)
	t.extrapolate = true
	t.end = 10
	if not is_equal_approx(t.at(5.0), 10.0) or not is_equal_approx(t.at(-3.0), -6.0):
		return "inside/before %s %s" % [t.at(5.0), t.at(-3.0)]
	if not is_equal_approx(t.at(25.0), 50.0):
		return "after %s" % t.at(25.0)
	t.extrapolate = false
	if not is_equal_approx(t.at(25.0), 22.0) or t.at(-3.0) != 0.0:
		return "clamped %s" % t.at(25.0)
	return ""


func test_euler_sum() -> String:
	# one sample per frame at the frame itself (a spin table)
	var t := MotionTravel.from_speed(func(f: float) -> float: return f, 6, 1, false, false)
	for i in 6:
		if t.entry(i) != float(i * (i - 1) / 2):
			return "entry %d = %s" % [i, t.entry(i)]
	return ""


func test_anchors_pass_and_stay_monotone() -> String:
	var xs := [0.0, 40.0, 108.0, 200.0, 300.0]
	var ys := [0.0, 30.0, 32.0, 140.0, 400.0]
	var t := MotionTravel.from_anchors(xs, ys, 422)
	for i in xs.size():
		if absf(t.at(xs[i]) - ys[i]) > 1e-9:
			return "anchor %d: %s" % [i, t.at(xs[i])]
	var prev := -INF
	for f in 301:
		var v := t.at(float(f))
		if v < prev - 1e-9:
			return "not monotone at %d" % f
		prev = v
	# past the last anchor: on along the last tangent
	if not t.at(350.0) > t.at(300.0):
		return "runs on"
	if absf(t.speed(150.0) - (t.at(150.5) - t.at(149.5))) > 1e-12:
		return "anchor speed"
	return ""


func test_keyed_speed() -> String:
	if MotionTravel.keyed_speed(KEYS, 40.0) != 0.12 or MotionTravel.keyed_speed(KEYS, 500.0) != 0.15:
		return "keys"
	if not is_equal_approx(MotionTravel.keyed_speed(KEYS, 50.0), lerpf(0.12, 1.7, 0.5)):
		return "smoothstep midpoint"
	return ""
