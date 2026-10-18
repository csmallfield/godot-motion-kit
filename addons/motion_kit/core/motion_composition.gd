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
@tool
@icon("res://addons/motion_kit/icons/composition.svg")
class_name MotionComposition
extends Node2D

signal finished
signal segment_finished(name: StringName)

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


func seek(f: float) -> void:
	_time = f / fps
	render(f)
	if audio and audio.playing:
		audio.seek(f / fps)


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
		_finish_at(_stop_at)
		var seg := _segment
		_segment = &""
		_stop_at = -1.0
		segment_finished.emit(seg)
		return
	if f >= duration or f < 0.0:
		if loop and duration > 0.0:
			f = fposmod(f, duration)
			_time = f / fps
			if audio and forward:
				audio.play(f / fps)
		else:
			_finish_at(clampf(f, 0.0, duration))
			finished.emit()
			return
	render(f)


func _finish_at(f: float) -> void:
	_time = f / fps
	playing = false
	render(f)


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
