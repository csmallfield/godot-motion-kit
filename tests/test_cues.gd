# SPDX-License-Identifier: Apache-2.0
# Cue sheets and cue firing, stepped by hand (no scene tree, no audio).
extends RefCounted

class Probe:
	extends MotionComposition
	var fired: Array = []      # [name, frame, reversed]
	var syncs: Array[StringName] = []
	func _init() -> void:
		autoplay = false
		fps = 30.0
		duration = 30.0
		cue_fired.connect(func(c: MotionCue): fired.append([c.name, c.frame, c.reversed]))
		cue_sync.connect(func(_f: float, s: StringName): syncs.append(s))

const DT := 1.0 / 30.0

func _steps(c: MotionComposition, n: int) -> void:
	for i in n:
		c._process(DT)

func _names(c: Probe) -> Array:
	return c.fired.map(func(e): return e[0])


func test_cue_returns_its_frame_and_sheet_sorts() -> String:
	var c := Probe.new()
	var at := c.cue(20, &"b")
	c.cue(5, &"a", 0.5)
	c.cue(20, &"b", 0.8)          # same name and frame: an update, not a second cue
	var sheet := c.get_cue_sheet()
	var r := ""
	if at != 20.0: r = "cue() returned %s" % at
	elif sheet.size() != 2: r = "%d cues, want 2" % sheet.size()
	elif sheet[0].name != &"a" or sheet[1].name != &"b": r = "order %s, %s" % [sheet[0].name, sheet[1].name]
	elif not is_equal_approx(sheet[1].intensity, 0.8): r = "update lost (intensity %s)" % sheet[1].intensity
	c.free()
	return r


func test_playback_fires_each_cue_once_in_order() -> String:
	var c := Probe.new()
	c.cue(0, &"start"); c.cue(10, &"mid"); c.cue(29.5, &"late")
	c.play()
	_steps(c, 40)                  # past the end
	var r := ""
	if _names(c) != [&"start", &"mid", &"late"]: r = "fired %s" % [_names(c)]
	elif c.syncs != [&"start", &"stop"]: r = "syncs %s" % [c.syncs]
	c.free()
	return r


func test_seek_skips_cues_and_syncs() -> String:
	var c := Probe.new()
	c.cue(10, &"skipped"); c.cue(20, &"after")
	c.play()
	_steps(c, 5)
	c.seek(15)
	_steps(c, 10)
	var r := ""
	if _names(c) != [&"after"]: r = "fired %s" % [_names(c)]
	elif not c.syncs.has(&"seek"): r = "no seek sync: %s" % [c.syncs]
	c.free()
	return r


func test_backwards_fires_reversed_in_reverse_order() -> String:
	var c := Probe.new()
	c.cue(5, &"a"); c.cue(15, &"b")
	c.seek(25)
	c.play_backwards(0)
	_steps(c, 40)
	var r := ""
	if _names(c) != [&"b", &"a"]: r = "fired %s" % [_names(c)]
	elif not (c.fired[0][2] and c.fired[1][2]): r = "not flagged reversed"
	c.free()
	return r


func test_loop_fires_every_pass() -> String:
	var c := Probe.new()
	c.loop = true
	c.cue(5, &"tick")
	c.play()
	_steps(c, 70)                   # frames 0..69: passes at 5, 35, 65
	var n := c.fired.size()
	c.free()
	return "" if n == 3 else "fired %d times, want 3" % n


func test_nested_cues_fire_from_the_root_with_offset() -> String:
	var root := Probe.new()
	root.duration = 200
	var child := MotionComposition.new()
	child.autoplay = false
	child.start = 100
	child.duration = 50
	child.cue(10, &"inside")
	child.cue(60, &"outside")        # past the child's duration: it never shows, so never fires
	root.add_child(child)
	var sheet := root.get_cue_sheet()
	var r := ""
	if sheet.size() != 1: r = "%d cues in the root's sheet, want 1" % sheet.size()
	elif not is_equal_approx(sheet[0].frame, 110.0): r = "at %s, want 110" % sheet[0].frame
	elif sheet[0].composition != child: r = "lost its declaring composition"
	elif not is_equal_approx(sheet[0].local_frame, 10.0): r = "local frame %s" % sheet[0].local_frame
	root.free()
	return r


func test_looping_nested_cues_repeat_within_the_parent() -> String:
	var root := Probe.new()
	root.duration = 100
	var child := MotionComposition.new()
	child.autoplay = false
	child.loop = true
	child.start = 10
	child.duration = 30
	child.cue(5, &"pulse")
	root.add_child(child)
	var frames := root.get_cue_sheet().map(func(c): return c.frame)
	root.free()
	return "" if frames == [15.0, 45.0, 75.0] else "frames %s, want [15, 45, 75]" % [frames]


func test_beats_on_the_grid_with_accents() -> String:
	var c := Probe.new()
	var at := c.beats(120, 0, 60)    # 30 fps at 120 bpm = every 15 frames
	var sheet := c.get_cue_sheet()
	var r := ""
	if Array(at) != [0.0, 15.0, 30.0, 45.0, 60.0]: r = "frames %s" % [at]
	elif not is_equal_approx(sheet[0].intensity, 1.0) or not is_equal_approx(sheet[1].intensity, 0.6): r = "accents %s, %s" % [sheet[0].intensity, sheet[1].intensity]
	elif sheet[4].data.get("beat") != 4: r = "beat index %s" % [sheet[4].data]
	c.free()
	return r


func test_cues_between_and_export() -> String:
	var c := Probe.new()
	c.cue(10, &"a", 0.5, {pan = -0.3}); c.cue(20, &"b")
	var mid := c.cues_between(10, 20)
	var json: Dictionary = JSON.parse_string(c.export_cue_sheet())
	var r := ""
	if mid.size() != 1 or mid[0].name != &"b": r = "cues_between(10, 20] gave %s" % [mid]
	elif c.cues_between(10, 20, true).size() != 2: r = "inclusive range missed the first"
	elif json.cues.size() != 2 or not is_equal_approx(json.cues[0].time, 10.0 / 30.0): r = "export %s" % [json]
	elif not is_equal_approx(json.cues[0].data.pan, -0.3): r = "data lost in export"
	c.free()
	return r


func test_fired_cues_are_copies() -> String:
	var c := Probe.new()
	c.cue(3, &"x")
	var got: Array[MotionCue] = []
	c.cue_fired.connect(func(e: MotionCue): got.append(e))
	c.play()
	_steps(c, 6)
	got[0].intensity = 0.0          # a listener scribbling on its copy
	var kept := c.get_cue_sheet()[0].intensity
	c.free()
	return "" if is_equal_approx(kept, 1.0) else "the sheet changed to %s" % kept


func test_cue_player_matches_exact_then_longest_prefix() -> String:
	var p := MotionCuePlayer.new()
	var a := AudioStreamWAV.new(); var b := AudioStreamWAV.new(); var c := AudioStreamWAV.new(); var d := AudioStreamWAV.new()
	p.sounds = {&"hit": a, &"whoosh.*": b, &"whoosh.out*": c, &"*": d}
	var got := [p.stream_for(&"hit"), p.stream_for(&"whoosh.in"), p.stream_for(&"whoosh.out"), p.stream_for(&"other")]
	p.free()
	return "" if got == [a, b, c, d] else "matched %s" % [got]
