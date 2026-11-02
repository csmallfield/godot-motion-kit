# SPDX-License-Identifier: Apache-2.0
## Game time for the kit's frame-pure curves: a clock that records events and
## answers "how long since". MK.spring, MK.shakes, MK.decay_kick and MK.accent
## then run on game events unchanged, because "frames since the hit" is just
## another frame number.
##
##   var clock := MotionClock.new(world_clock)     # one per entity
##   clock.tick(delta)                             # once per _process
##   clock.mark(&"hit", {dir = d})                 # on the event
##   var s := MK.spring(clock.frames_since(&"hit"), 0, 9, 220)
##   offset = MK.shakes(clock.frame(), clock.frames(&"hit"), 6, 8)
##
## Time scale. A clock's local time runs at `scale` times its envelopes times
## its parent's rate, so a hit-stop on one entity (`freeze`) stops only its
## reactions, a freeze on the world clock stops every child, and a clock with
## `ignore_time_scale` (UI, camera trauma during a global slow-mo) runs on real
## time. Envelopes run on the clock's input time, so a freeze always ends.
## Root clocks follow Engine.time_scale through `_process`'s delta.
##
## Fixed-step code (verlet, foot planting) steps with `delta * clock.rate()`
## from `_physics_process`, so it freezes and slows with the clock too.
class_name MotionClock
extends RefCounted

## Emitted by mark(): the event name and its data.
signal marked(event: StringName, data: Dictionary)

## Rates multiply down the chain: a child of a frozen clock is frozen.
var parent: MotionClock
## Your own slow motion on this clock (1 = normal).
var scale := 1.0
## Run on real time: ignores Engine.time_scale and the parent chain.
var ignore_time_scale := false
## Local time in seconds, and the last tick's local step.
var time := 0.0
var dt := 0.0
## How many events of each name are kept for frames() and within().
var history := 16

var _outer := 0.0                  # input time, for envelopes
var _envs: Array[Dictionary] = []  # {at, hold, ease, low}
var _events := {}                  # StringName -> Array of [t, data], oldest first
var _ticked := -1
var _last_usec := -1


func _init(parent_clock: MotionClock = null) -> void:
	parent = parent_clock


## Advance once per rendered frame (call it from _process; a second call in
## the same frame is ignored, so several systems can share a clock safely).
func tick(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _ticked:
		return
	_ticked = frame
	if ignore_time_scale:
		var now := Time.get_ticks_usec()
		delta = 0.0 if _last_usec < 0 else minf(float(now - _last_usec) * 1e-6, 0.1)
		_last_usec = now
	advance(delta)


## Advance by `delta` seconds of input time (no once-per-frame guard: tests,
## replays, manual stepping).
func advance(delta: float) -> void:
	if delta <= 0.0:
		dt = 0.0
		return
	# the envelope at the middle of the step: one step of error at most
	var mid := _env_scale(_outer + delta * 0.5)
	_outer += delta
	_prune()
	var up := 1.0 if ignore_time_scale or parent == null else parent.rate()
	dt = delta * scale * mid * up
	time += dt


## This clock's current rate relative to its input time (0 while frozen).
func rate() -> float:
	var up := 1.0 if ignore_time_scale or parent == null else parent.rate()
	return scale * _env_scale(_outer) * up


## Local time in frames (MK's 30 fps unless given).
func frame(fps := 30.0) -> float:
	return time * fps


# ------------------------------------------------------------------ events

## Record an event now.
func mark(event: StringName, data := {}) -> void:
	var list: Array = _events.get(event, [])
	list.append([time, data])
	while list.size() > maxi(history, 1):
		list.pop_front()
	_events[event] = list
	marked.emit(event, data)


## Seconds since the latest `event` (INF if it never happened).
func since(event: StringName) -> float:
	var list: Array = _events.get(event, [])
	return INF if list.is_empty() else time - float(list[-1][0])


## Frames since the latest `event`: feed it straight to MK.spring(f, 0, ...).
## A large number (1e6) when it never happened, so springs read as settled.
func frames_since(event: StringName, fps := 30.0) -> float:
	var s := since(event)
	return 1e6 if is_inf(s) else s * fps


## The latest event's data ({} if none).
func last_data(event: StringName) -> Dictionary:
	var list: Array = _events.get(event, [])
	return {} if list.is_empty() else list[-1][1]


## How many times `event` happened in the last `window` seconds.
func count(event: StringName, window: float) -> int:
	return within(event, window).size()


## Ages in seconds of every `event` in the last `window` seconds, newest first.
func within(event: StringName, window: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var list: Array = _events.get(event, [])
	for i in range(list.size() - 1, -1, -1):
		var age := time - float(list[i][0])
		if age > window:
			break
		out.append(age)
	return out


## Every kept `event` as a frame on this clock's frame axis, oldest first:
## the `ats` of MK.shakes, MK.decay_kick and MK.accent.
func frames(event: StringName, fps := 30.0) -> Array:
	var out := []
	for e in _events.get(event, []):
		out.append(float(e[0]) * fps)
	return out


## Forget one event name, or all of them.
func clear(event: StringName = &"") -> void:
	if event == &"":
		_events.clear()
	else:
		_events.erase(event)


# ------------------------------------------------------------------ time scale

## Hit-stop: hold this clock at `low` (0 = frozen) for `hold` seconds of input
## time, then ease back to full speed over `ease` seconds. Overlapping
## envelopes take the slowest.
func freeze(hold: float, ease := 0.0, low := 0.0) -> void:
	_envs.append({at = _outer, hold = maxf(hold, 0.0), ease = maxf(ease, 0.0), low = clampf(low, 0.0, 1.0)})


## Slow motion: `low` speed for `hold` seconds, easing back over `ease`.
func slow(low: float, hold: float, ease := 0.2) -> void:
	freeze(hold, ease, low)


## True while an envelope is holding or easing.
func is_scaled() -> bool:
	return _env_scale(_outer) < 1.0


## Drop every envelope (full speed now).
func release() -> void:
	_envs.clear()


func _env_scale(t: float) -> float:
	var s := 1.0
	for e in _envs:
		var age: float = t - float(e.at)
		var hold: float = e.hold
		var ease: float = e.ease
		var low: float = e.low
		var v := 1.0
		if age < 0.0:
			v = 1.0
		elif age < hold:
			v = low
		elif ease > 0.0 and age < hold + ease:
			var u := (age - hold) / ease
			v = lerpf(low, 1.0, u * u * (3.0 - 2.0 * u))
		s = minf(s, v)
	return s


func _prune() -> void:
	for i in range(_envs.size() - 1, -1, -1):
		var e: Dictionary = _envs[i]
		if _outer - float(e.at) >= float(e.hold) + float(e.ease):
			_envs.remove_at(i)
