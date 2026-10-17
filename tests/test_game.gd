# SPDX-License-Identifier: Apache-2.0
extends RefCounted

func test_motion_spring_matches_mk_spring() -> String:
	# Stepping the reactive spring frame by frame must land exactly on the
	# frame-pure spring, for under-, critically and over-damped settings.
	for cfg in [[9.0, 180.0, 1.0], [12.0, 90.0, 1.0], [20.0, 100.0, 1.0], [40.0, 100.0, 1.0], [5.0, 100.0, 2.5]]:
		var s := MotionSpring.new(0.0, cfg[0], cfg[1], cfg[2])
		s.target = 1.0
		for f in range(1, 91):
			var got := s.step(1.0 / 30.0)
			var want := MK.spring(f, 0.0, cfg[0], cfg[1], cfg[2])
			if absf(got - want) > 1e-9:
				return "cfg %s frame %d: %s vs %s" % [cfg, f, got, want]
	return ""

func test_motion_spring_retargets_smoothly() -> String:
	var s := MotionSpring.new(0.0, 9, 180)
	s.target = 1.0
	for i in 5:
		s.step(1.0 / 60.0)
	var v_before := s.velocity
	s.target = 0.0
	s.step(0.0)
	return "" if is_equal_approx(s.velocity, v_before) else "velocity jumped on retarget"
