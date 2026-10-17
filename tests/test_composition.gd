# SPDX-License-Identifier: Apache-2.0
# MotionComposition playback, stepped by hand (no scene tree, no audio).
extends RefCounted

class Probe:
	extends MotionComposition
	var seen: Array[float] = []
	var finishes := 0
	var segments: Array[StringName] = []
	func _init() -> void:
		autoplay = false
		fps = 30.0
		duration = 10.0
		finished.connect(func(): finishes += 1)
		segment_finished.connect(func(n): segments.append(n))
	func _frame(f: float) -> void:
		seen.append(f)

const DT := 1.0 / 30.0

func _steps(c: MotionComposition, n: int, dt := DT) -> void:
	for i in n:
		c._process(dt)

func test_loop_wraps_values() -> String:
	var c := Probe.new(); c.loop = true
	c.play(); c.seen.clear()
	_steps(c, 26)
	var got := c.seen.duplicate()
	c.free()
	for i in got.size():
		if not is_equal_approx(got[i], float(i % 10)):
			return "step %d drew %s" % [i, got[i]]
	return ""

func test_finishes_once_at_the_end() -> String:
	var c := Probe.new()
	c.play()
	_steps(c, 20)
	var r := ""
	if c.finishes != 1: r = "finished %d times" % c.finishes
	elif c.playing: r = "still playing"
	elif not is_equal_approx(c.frame, 10.0): r = "ended on %s" % c.frame
	c.free()
	return r

func test_hitch_at_end_then_backwards() -> String:
	var c := Probe.new()
	c.play()
	_steps(c, 5)
	c._process(0.5)        # a long frame past the end
	c.play_backwards()
	_steps(c, 20)
	var r := ""
	if c.finishes != 1: r = "finished %d times" % c.finishes
	elif not is_equal_approx(c.frame, 0.0): r = "reverse ended on %s" % c.frame
	elif c.segments != [&""]: r = "segments %s" % [c.segments]
	c.free()
	return r

func test_segment_stops_on_marker() -> String:
	var c := Probe.new()
	c.markers = {"a": 2.0, "b": 6.0}
	c.play_segment("a", "b")
	_steps(c, 20)
	var r := ""
	if not is_equal_approx(c.frame, 6.0): r = "stopped on %s" % c.frame
	elif c.segments != [&"b"]: r = "segments %s" % [c.segments]
	elif c.finishes != 0: r = "finished fired"
	c.free()
	return r

func test_manual_clock_does_not_advance() -> String:
	var c := Probe.new()
	c.clock = MotionComposition.Clock.MANUAL
	c.play()
	_steps(c, 5)
	var r := "" if is_equal_approx(c.frame, 0.0) else "advanced to %s" % c.frame
	c.free()
	return r

func test_nested_hides_outside_its_range() -> String:
	var parent := Probe.new()
	var child := Probe.new()
	child.start = 3.0
	child.duration = 4.0
	parent.add_child(child)
	parent.render(1.0)
	var before := child.visible
	parent.render(5.0)
	var during := child.visible and is_equal_approx(child.frame, 2.0)
	parent.render(8.0)
	var after := child.visible
	parent.free()
	return "" if not before and during and not after else "visible %s %s %s" % [before, during, after]
