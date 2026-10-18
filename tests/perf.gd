# SPDX-License-Identifier: Apache-2.0
# CPU cost per frame of the two intros: steps every frame and reads Godot's
# process-time monitor (script + _draw command building; GPU time excluded).
#   godot --path . res://tests/perf.tscn   (headless works too)
extends Node

const SCENES := ["res://demo/scf/e1_supergraphic.tscn", "res://demo/scf/d1_signal.tscn", "res://demo/scf/a_pit_lane.tscn", "res://demo/scf/c_vector_track.tscn", "res://demo/scf/b_print.tscn", "res://demo/scf/b1_print.tscn", "res://demo/scf/b2_specimen.tscn", "res://demo/scf/b3_index.tscn",
	"res://demo/scf/f1_strobe.tscn", "res://demo/scf/f2_moire.tscn", "res://demo/scf/f3_goo.tscn", "res://demo/scf/f4_hyperspeed.tscn", "res://demo/scf/f5_automaton.tscn",
	"res://demo/scf/g1_lava.tscn", "res://demo/scf/g2_splash.tscn", "res://demo/scf/g3_cells.tscn", "res://demo/scf/g4_ferro.tscn", "res://demo/scf/g5_goo_type.tscn"]
var _i := -1
var _comp: MotionComposition
var _f := 0
var _times := PackedFloat64Array()


func _ready() -> void:
	_next()


func _next() -> void:
	if _comp:
		_report()
		_comp.queue_free()
	_i += 1
	if _i >= SCENES.size():
		get_tree().quit()
		return
	_comp = (load(SCENES[_i]) as PackedScene).instantiate()
	_comp.autoplay = false
	_comp.clock = MotionComposition.Clock.MANUAL
	add_child(_comp)
	_f = 0
	_times.clear()


func _process(_d: float) -> void:
	if not _comp:
		return
	var t0 := Time.get_ticks_usec()
	_comp.render(_f)
	_times.append(Time.get_ticks_usec() - t0)
	_f += 1
	if _f >= int(_comp.duration):
		_next()


func _report() -> void:
	var s := Array(_times)
	s.sort()
	var total := 0.0
	for t in s:
		total += t
	print("%s: %d frames, render() mean %.3f ms, median %.3f ms, p95 %.3f ms, max %.3f ms" % [
		SCENES[_i].get_file(), s.size(), total / s.size() / 1000.0, s[s.size() / 2] / 1000.0,
		s[int(s.size() * 0.95)] / 1000.0, s[s.size() - 1] / 1000.0])
