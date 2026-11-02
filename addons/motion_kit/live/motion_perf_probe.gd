# SPDX-License-Identifier: Apache-2.0
## Per-system script timing for an in-game overlay: wrap a system's work in
## `var t := MotionPerfProbe.begin()` ... `MotionPerfProbe.end(&"name", t)`,
## call `end_frame()` once at the end of each frame (from a node with a high
## process_priority), and read `stats()` / `report()`. Averages and maxima are
## over the last 120 frames; `worst_frame_ms` tracks the longest frame since
## the last reset_worst(). These are CPU script costs: on a machine without
## the target GPU they say nothing about frame rate.
class_name MotionPerfProbe
extends RefCounted

const WINDOW := 120

static var _acc := {}      # name -> usec this frame
static var _hist := {}     # name -> PackedFloat64Array (ring of frame totals)
static var _i := 0
static var worst_frame_ms := 0.0      # since start (or reset)
static var _last_usec := -1


static func begin() -> int:
	return Time.get_ticks_usec()


static func end(name: StringName, t0: int) -> void:
	_acc[name] = int(_acc.get(name, 0)) + Time.get_ticks_usec() - t0


## Close the frame (the overlay calls this last in the frame).
static func end_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_usec >= 0:
		worst_frame_ms = maxf(worst_frame_ms, (now - _last_usec) * 0.001)
	_last_usec = now
	for name in _acc.keys() + _hist.keys():
		if not _hist.has(name):
			var a := PackedFloat64Array()
			a.resize(WINDOW)
			_hist[name] = a
		var h: PackedFloat64Array = _hist[name]
		h[_i] = float(_acc.get(name, 0))
		_hist[name] = h
	_acc.clear()
	_i = (_i + 1) % WINDOW


static func reset_worst() -> void:
	worst_frame_ms = 0.0


## {name: Vector2(avg_us, max_us)} over the window.
static func stats() -> Dictionary:
	var out := {}
	for name in _hist:
		var h: PackedFloat64Array = _hist[name]
		var s := 0.0
		var m := 0.0
		for v in h:
			s += v
			m = maxf(m, v)
		out[name] = Vector2(s / WINDOW, m)
	return out


## The stats as text lines ("name  avg us  max us"), sorted, with a total.
static func report() -> PackedStringArray:
	var lines := PackedStringArray()
	var st := stats()
	var names := st.keys()
	names.sort()
	var total := 0.0
	for n in names:
		var v: Vector2 = st[n]
		total += v.x
		lines.append("  %-12s %6.0f us avg  %6.0f max" % [n, v.x, v.y])
	lines.append("  %-12s %6.0f us avg" % ["total", total])
	return lines


## Forget everything (a new scene, a new bench).
static func reset() -> void:
	_acc.clear()
	_hist.clear()
	_i = 0
	worst_frame_ms = 0.0
	_last_usec = -1
