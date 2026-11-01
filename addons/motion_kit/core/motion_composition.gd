# SPDX-License-Identifier: Apache-2.0
## A piece of motion graphics whose picture is a pure function of one number,
## the frame. Override `_frame(f)` and set properties from `f`; descendants
## that define `_frame(f)` are called too, after this node.
##
## The frame comes from one of three clocks: process time (the default),
## an AudioStreamPlayer's playback position (picture locked to sound), or
## manual (`render(f)` / the editor's Preview Frame slider).
##
## Nested compositions are driven by their parent and receive `f - start`.
##
## Cues: declare the moments sound should land on with `cue(frame, name,
## intensity)` (it returns the frame, so one constant drives both picture and
## sound). Playback fires each cue it crosses on `cue_fired` and on the global
## `MotionCue.bus`, whether or not anything listens; seeking fires none but
## emits `cue_sync` (start, seek, stop) so listeners can follow. Nested compositions' cues fire from
## the root, offset by their `start`. The whole sheet can be read ahead
## (`cues_between`) for scheduling, or exported as JSON for sound design.
@tool
@icon("res://addons/motion_kit/icons/composition.svg")
class_name MotionComposition
extends Node2D

signal finished
signal segment_finished(name: StringName)
## Playback crossed a cue (see `cue()`); also relayed on `MotionCue.bus.fired`.
signal cue_fired(cue: MotionCue)
## Playback changed at `frame`: `state` is &"start" (play from here), &"seek"
## (a jump: drop sounding cues, reschedule) or &"stop" (stopped or finished).
## Also relayed on `MotionCue.bus.sync`.
signal cue_sync(frame: float, state: StringName)

enum Clock { PROCESS, AUDIO, MANUAL }

@export_group("Timing")
@export var fps := 30.0
## Length in frames. A non-looping composition stops on its last frame.
@export var duration := 300.0
@export var clock := Clock.PROCESS
## Used by Clock.AUDIO: the frame follows this player's playback position.
@export var audio: AudioStreamPlayer
@export var autoplay := true
@export var loop := false
@export var speed := 1.0
## Ignore Engine.time_scale, so slow motion and hit-stop do not slow the UI.
@export var ignore_time_scale := true
## Named frames: in, hold, out. Used by play_segment().
@export var markers: Dictionary = {}
## Offset when nested inside another composition: this one sees parent f - start.
@export var start := 0.0
## When nested: hide outside [0, duration) of its own time, like a Remotion
## <Sequence>; `loop` then repeats it within the parent's time.
@export var hide_outside := true
## Tempo in beats per minute (0: none). Read by beat_frames(), bar_frames()
## and beat_at(); pieces derive their beat timing from it.
@export var bpm := 0.0

@export_group("Layout")
## Reference size the composition is authored in (1920x1080 for the SCF pieces).
@export var size := Vector2(1920, 1080)
## Scale and centre the reference size to fit the viewport (letterboxed).
@export var fit_to_viewport := false

@export_group("Preview")
## Scrub in the editor. Not used at runtime.
@export var preview_frame := 0.0:
	set(v):
		preview_frame = v
		if Engine.is_editor_hint() and is_inside_tree():
			render(v)

var frame := 0.0
var playing := false

var _time := 0.0
var _dir := 1.0
var _stop_at := -1.0
var _segment := &""
var _hold_first := false
var _movie := Engine.get_write_movie_path() != ""
var _cues: Array[MotionCue] = []
var _sheet: Array[MotionCue] = []    # own cues and nested ones, in this timeline, sorted
var _sheet_dirty := true
var _fired_to := 0.0                 # cues up to here (in play direction) have fired
var _fire_inclusive := true          # the next range includes _fired_to itself


func _ready() -> void:
	if Engine.is_editor_hint():
		render(preview_frame)
		return
	if _is_nested():
		return
	# Pause-safe by default, unless the user chose a process mode.
	if process_mode == Node.PROCESS_MODE_INHERIT:
		process_mode = Node.PROCESS_MODE_ALWAYS
	if fit_to_viewport:
		get_viewport().size_changed.connect(_fit)
		_fit()
	if _movie:
		# Godot's physics jitter fix nudges each frame's process delta to line up
		# physics ticks, so under Movie Maker the first deltas run 0.75, 1, 1.25,
		# 0.875... of a frame and frames 2-4 land between frames. An offline render
		# has nothing to smooth: switch it off so every image is exactly one step.
		Engine.physics_jitter_fix = 0.0
	render(0.0)
	# `-- --mk-start=N` on the command line starts the top-level composition at
	# frame N: resume or split a long Movie Maker render (its files still count
	# from 0, so frame N is written as file 0).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mk-start="):
			seek(arg.get_slice("=", 1).to_float())
	if autoplay:
		play()


## Start playing from the current frame (or from `from` when given).
func play(from := -1.0) -> void:
	if from >= 0.0:
		seek(from)
	_start(1.0, -1.0, &"")


## Play backwards to frame 0 (or to `to`): a mirrored outro for free.
func play_backwards(to := 0.0) -> void:
	_start(-1.0, maxf(0.0, to), &"")


## Play from marker `a` to marker `b` (or frame numbers), forwards or backwards.
func play_segment(a: Variant, b: Variant) -> void:
	var fa := _marker(a)
	var fb := _marker(b)
	seek(fa)
	_start(1.0 if fb >= fa else -1.0, fb, StringName(str(b)))


func _start(dir: float, stop_at: float, segment: StringName) -> void:
	_fired_to = frame
	_fire_inclusive = true   # a cue on the starting frame fires with it
	_sync(&"start")
	_dir = dir
	_stop_at = stop_at
	_segment = segment
	_time = frame / fps
	playing = true
	# The first drawn frame shows the current frame rather than one step past it,
	# so a Movie Maker render's first image is frame 0, as in Remotion.
	_hold_first = true
	if audio:
		if dir > 0.0:
			audio.play(frame / fps)
		else:
			audio.stop()   # sound does not run backwards


func stop() -> void:
	playing = false
	if audio:
		audio.stop()
	_sync(&"stop")


func seek(f: float) -> void:
	_time = f / fps
	render(f)
	if audio and audio.playing:
		audio.seek(f / fps)
	# A jump fires nothing: cues between the old and new frame were skipped.
	_fired_to = f
	_fire_inclusive = true
	_sync(&"seek")


## Draw frame `f` now. Safe to call at any time, in any order.
func render(f: float) -> void:
	frame = f
	if has_method(&"_frame"):
		call(&"_frame", f)
	for c in get_children(true):
		_dispatch(c, f)


func _dispatch(node: Node, f: float) -> void:
	if node is MotionComposition:
		node._render_nested(f - node.start)
		return
	if node.has_method(&"_frame"):
		node.call(&"_frame", f)
	# Internal children too: MotionFX keeps its content inside an internal SubViewport.
	for c in node.get_children(true):
		_dispatch(c, f)


func _render_nested(local: float) -> void:
	if loop and duration > 0.0:
		local = fposmod(local, duration)
	if hide_outside:
		visible = local >= 0.0 and local < duration
		if not visible:
			return
	render(local)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not playing or clock == Clock.MANUAL:
		return
	if _hold_first:
		_hold_first = false
		render(frame)
		_fire_to(frame)
		return
	var f: float
	# Movie Maker steps time exactly, so a movie render always uses process time.
	if clock == Clock.AUDIO and audio and audio.playing and not _movie:
		var t := audio.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		f = maxf(0.0, t) * fps
		_time = f / fps   # so time carries on smoothly if the sound stops
	else:
		var d := delta
		if ignore_time_scale and Engine.time_scale > 0.0:
			d /= Engine.time_scale
		_time += d * speed * _dir
		# Snap away float drift so movie renders land on exact frames.
		f = snappedf(_time * fps, 1e-6)
	var forward := _dir * signf(speed) >= 0.0
	if _stop_at >= 0.0 and ((forward and f >= _stop_at) or (not forward and f <= _stop_at)):
		_fire_to(_stop_at)
		_finish_at(_stop_at)
		var seg := _segment
		_segment = &""
		_stop_at = -1.0
		segment_finished.emit(seg)
		return
	if f >= duration or f < 0.0:
		if loop and duration > 0.0:
			# Fire to the end (or start) of the loop, then on from the other side.
			_fire_to(duration if forward else 0.0)
			f = fposmod(f, duration)
			_time = f / fps
			_fired_to = 0.0 if forward else duration
			_fire_inclusive = true
			if audio and forward:
				audio.play(f / fps)
		else:
			_fire_to(clampf(f, 0.0, duration))
			_finish_at(clampf(f, 0.0, duration))
			finished.emit()
			return
	render(f)
	_fire_to(f)


func _finish_at(f: float) -> void:
	_time = f / fps
	playing = false
	render(f)
	_sync(&"stop")


# ------------------------------------------------------------------ cues

## Declare a cue at frame `at` (in this composition's own timeline) and return
## `at`, so the same number drives the animation: `MK.spring(f, cue(66, &"go"), ...)`
## or `var go_at := cue(66, &"go", 1.0)`. Declaring the same name at the same
## frame again updates it. Usually called from `_init` or a build step.
func cue(at: float, name: StringName, intensity := 1.0, data := {}) -> float:
	for c in _cues:
		if c.name == name and is_equal_approx(c.local_frame, at):
			c.intensity = intensity
			c.data = data
			_sheet_dirty = true
			return at
	var c := MotionCue.new(name, at, intensity, data)
	c.composition = self
	_cues.append(c)
	_sheet_dirty = true
	return at


## Declare a cue on every beat at `tempo` bpm from frame `from` to `to` (inclusive):
## `name` with `data.beat` (0, 1, 2...), intensity 1 on every `accent_every`th
## beat and `intensity` otherwise. Returns the frames.
func beats(tempo: float, from: float, to: float, name: StringName = &"beat", intensity := 0.6, accent_every := 4) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var step := fps * 60.0 / tempo
	var i := 0
	var at := from
	while at <= to + 1e-6:
		cue(at, name, 1.0 if accent_every > 0 and i % accent_every == 0 else intensity, {beat = i})
		out.append(at)
		i += 1
		at = from + i * step
	return out


## Frames per beat at `bpm` and `fps` (0 when no bpm is set).
func beat_frames() -> float:
	return MK.beat_frames(bpm, fps) if bpm > 0.0 else 0.0


## Frames per bar of `beats_per_bar` beats.
func bar_frames(beats_per_bar := 4) -> float:
	return beat_frames() * beats_per_bar


## The beat number at frame f, fractional (beat 0 starts at frame `from`):
## floor() it for the beat index, fposmod(.., 1.0) for the phase within it.
func beat_at(f: float, from := 0.0) -> float:
	var b := beat_frames()
	return (f - from) / b if b > 0.0 else 0.0


## Make this composition a source driven by another (a slit-scan or time
## effect samples it at many frames): effectively endless, never playing on
## its own, never hidden by its parent's timeline. Returns itself.
func as_source() -> MotionComposition:
	duration = 100000
	autoplay = false
	hide_outside = false
	return self


## Remove every cue this composition declared (not its children's).
func clear_cues() -> void:
	_cues.clear()
	_sheet_dirty = true


## Every cue that can fire in this timeline, sorted by frame: this composition's
## own and its nested compositions' (offset by their `start`, repeated when they
## loop, dropped outside their duration when they hide outside it).
func get_cue_sheet() -> Array[MotionCue]:
	if _sheet_dirty:
		_rebuild_sheet()
	return _sheet


## Cues with a frame in (a, b] (or [a, b] with `inclusive`), for scheduling
## sounds ahead of the picture.
func cues_between(a: float, b: float, inclusive := false) -> Array[MotionCue]:
	var out: Array[MotionCue] = []
	for c in get_cue_sheet():
		if (c.frame > a or (inclusive and c.frame >= a)) and c.frame <= b:
			out.append(c)
	return out


## The cue sheet as JSON ({fps, duration, cues: [{frame, time, name, intensity,
## data}]}), written to `path` when given: hand it to a sound designer or a
## synthesis script so every hit lands where the picture does.
func export_cue_sheet(path := "") -> String:
	var cues := []
	for c in get_cue_sheet():
		cues.append(c.to_dict())
	var json := JSON.stringify({fps = fps, duration = duration, cues = cues}, "\t")
	if path != "":
		var fa := FileAccess.open(path, FileAccess.WRITE)
		if fa:
			fa.store_string(json)
	return json


func _rebuild_sheet() -> void:
	_sheet.clear()
	_collect(self, 0.0, INF)
	_sheet.sort_custom(func(a: MotionCue, b: MotionCue) -> bool: return a.frame < b.frame)
	_sheet_dirty = false


## Adds `comp`'s cues (and its children's) to the sheet, at `offset`, below `limit`.
func _collect(comp: MotionComposition, offset: float, limit: float) -> void:
	for c in comp._cues:
		var reps := [0.0]
		if comp != self and comp.loop and comp.duration > 0.0:
			reps = []
			var k := 0.0
			while offset + c.local_frame + k * comp.duration < minf(limit, duration):
				reps.append(k * comp.duration)
				k += 1.0
		for r in reps:
			if comp != self and comp.hide_outside and not comp.loop and (c.local_frame < 0.0 or c.local_frame >= comp.duration):
				continue
			var at: float = offset + c.local_frame + r
			if at >= limit:
				continue
			var e := c.copy()
			e.frame = at
			e.fps = fps
			_sheet.append(e)
	for child in comp.find_children("*", "MotionComposition", true, false):
		# Only direct nested compositions: deeper ones are collected through them.
		if _nearest_composition(child) == comp:
			_collect(child, offset + child.start, offset + child.start + (INF if child.loop else child.duration))


static func _nearest_composition(n: Node) -> MotionComposition:
	var p := n.get_parent()
	while p and not p is MotionComposition:
		p = p.get_parent()
	return p


## Fire every cue crossed since the last call, up to `to`, in play order.
func _fire_to(to: float) -> void:
	if _is_nested():
		return
	var forward := _dir * signf(speed) >= 0.0
	var from := _fired_to
	var incl := _fire_inclusive
	var sheet := get_cue_sheet()
	if forward:
		for c in sheet:
			if (c.frame > from or (incl and c.frame >= from)) and c.frame <= to:
				_emit_cue(c, false)
	else:
		for i in range(sheet.size() - 1, -1, -1):
			var c: MotionCue = sheet[i]
			if (c.frame < from or (incl and c.frame <= from)) and c.frame >= to:
				_emit_cue(c, true)
	_fired_to = to
	_fire_inclusive = false


func _emit_cue(c: MotionCue, reversed: bool) -> void:
	var e := c.copy()
	e.reversed = reversed
	cue_fired.emit(e)
	MotionCue.bus.fired.emit(e)


func _sync(state: StringName) -> void:
	if _is_nested() or Engine.is_editor_hint():
		return
	cue_sync.emit(frame, state)
	MotionCue.bus.sync.emit(self, frame, state)


func _marker(m: Variant) -> float:
	if m is String or m is StringName:
		assert(markers.has(m), "MotionComposition: no marker '%s'" % m)
		return float(markers[m])
	return float(m)


func _is_nested() -> bool:
	var p := get_parent()
	while p:
		if p is MotionComposition:
			return true
		p = p.get_parent()
	return false


func _fit() -> void:
	var vp := get_viewport_rect().size
	var k := minf(vp.x / size.x, vp.y / size.y)
	scale = Vector2(k, k)
	position = (vp - size * k) * 0.5
