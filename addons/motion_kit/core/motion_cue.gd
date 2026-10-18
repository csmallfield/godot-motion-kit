# SPDX-License-Identifier: Apache-2.0
## A moment in a composition's timeline that something may want to hear: a
## hit, a beat, a whoosh's start. Compositions declare cues with `cue()` and
## fire them as playback crosses them, whether or not anything is listening.
##
## A fired cue is a copy whose `frame` is in the timeline of the composition
## that fired it (the root, for cues declared in nested compositions), with
## `reversed` set when playback crossed it going backwards.
##
## Listen to one composition's `cue_fired` signal, or to every composition at
## once through the global relay:
##
##   MotionCue.bus.fired.connect(func(c: MotionCue): print(c.name, " at ", c.time))
##   MotionCue.bus.sync.connect(func(comp, frame, state): ...)   # &"start", &"seek", &"stop"
@icon("res://addons/motion_kit/icons/composition.svg")
class_name MotionCue
extends RefCounted

## Relay for every composition's cues: an audio system subscribes here once.
class Bus:
	extends RefCounted
	## A cue was crossed during playback.
	signal fired(cue: MotionCue)
	## Playback changed: `state` is &"start", &"seek" (a jump: drop sounding
	## cues and reschedule from `frame`) or &"stop" (stopped or finished).
	signal sync(composition: MotionComposition, frame: float, state: StringName)

static var bus := Bus.new()

## Short identifier, dot-separated by convention ("hit", "count.3", "whoosh.out").
var name: StringName
## Frame in the timeline of the composition that fires it.
var frame := 0.0
## 0..1 by convention: how hard the moment lands (louder, brighter, longer).
var intensity := 1.0
## Free-form extras for the listener: pan, pitch, volume_db, a sound id, a note.
var data := {}
## Frames per second of the firing composition (for `time`).
var fps := 30.0
## True when playback crossed the cue going backwards.
var reversed := false
## The composition that declared the cue (a nested one, possibly).
var composition: MotionComposition
## Frame in the declaring composition's own timeline.
var local_frame := 0.0


func _init(p_name: StringName = &"", p_frame := 0.0, p_intensity := 1.0, p_data := {}) -> void:
	name = p_name
	frame = p_frame
	local_frame = p_frame
	intensity = p_intensity
	data = p_data


## Seconds from the start of the firing composition's timeline.
var time: float:
	get: return frame / fps


func copy() -> MotionCue:
	var c := MotionCue.new(name, frame, intensity, data)
	c.fps = fps
	c.reversed = reversed
	c.composition = composition
	c.local_frame = local_frame
	return c


func to_dict() -> Dictionary:
	return {frame = frame, time = time, name = String(name), intensity = intensity, data = data}


func _to_string() -> String:
	return "MotionCue(%s @ %.2f, %.2f%s)" % [name, frame, intensity, ", reversed" if reversed else ""]
