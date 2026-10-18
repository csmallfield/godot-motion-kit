# SPDX-License-Identifier: Apache-2.0
## The simplest cue listener: plays a sound for each cue a composition fires.
## A stand-in until a real audio system subscribes to the same cues.
##
##   var p := MotionCuePlayer.new()
##   p.composition = self                      # or leave empty: every composition
##   p.sounds = {&"hit": preload("res://sfx/hit.wav"), &"count.*": preload("res://sfx/blip.wav")}
##   add_child(p)
##
## A cue's `intensity` sets the volume (linear, 1 = full) and `data` can carry
## `volume_db` and `pitch`. Names match exactly, then by the longest `prefix*`
## pattern, then `*`. Sounds stop when the composition seeks or stops.
@icon("res://addons/motion_kit/icons/composition.svg")
class_name MotionCuePlayer
extends Node

## Listen to this composition only; empty listens to every composition
## (through `MotionCue.bus`). Set it before the player enters the tree.
@export var composition: MotionComposition
## Cue name (or `prefix*`, or `*`) -> AudioStream.
@export var sounds: Dictionary = {}
@export var volume_db := 0.0
@export var bus: StringName = &"Master"
## How many sounds can overlap.
@export_range(1, 32) var voices := 8
## Also play cues crossed while playing backwards.
@export var play_reversed := false
## Stop sounding voices when the composition seeks, stops or finishes.
@export var stop_on_sync := true

## A sound started for `cue` on `player`.
signal played(cue: MotionCue, player: AudioStreamPlayer)

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in voices:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)


func _enter_tree() -> void:
	if composition:
		composition.cue_fired.connect(_on_cue)
		composition.cue_sync.connect(_on_comp_sync)
	else:
		MotionCue.bus.fired.connect(_on_cue)
		MotionCue.bus.sync.connect(_on_bus_sync)


func _exit_tree() -> void:
	if composition:
		if composition.cue_fired.is_connected(_on_cue):
			composition.cue_fired.disconnect(_on_cue)
			composition.cue_sync.disconnect(_on_comp_sync)
	elif MotionCue.bus.fired.is_connected(_on_cue):
		MotionCue.bus.fired.disconnect(_on_cue)
		MotionCue.bus.sync.disconnect(_on_bus_sync)


## The stream for a cue name: exact, then the longest matching `prefix*`, then `*`.
func stream_for(cue_name: StringName) -> AudioStream:
	if sounds.has(cue_name):
		return sounds[cue_name]
	var n := String(cue_name)
	var best: AudioStream = null
	var best_len := -1
	for k in sounds:
		var key := String(k)
		if key.ends_with("*") and n.begins_with(key.left(-1)) and key.length() > best_len:
			best = sounds[k]
			best_len = key.length()
	return best


func _on_cue(c: MotionCue) -> void:
	if c.reversed and not play_reversed:
		return
	var stream := stream_for(c.name)
	if not stream:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db + linear_to_db(clampf(c.intensity, 0.0001, 4.0)) + float(c.data.get("volume_db", 0.0))
	p.pitch_scale = float(c.data.get("pitch", 1.0))
	p.play()
	played.emit(c, p)


func _on_comp_sync(_frame: float, state: StringName) -> void:
	_on_sync(state)


func _on_bus_sync(_comp: MotionComposition, _frame: float, state: StringName) -> void:
	_on_sync(state)


func _on_sync(state: StringName) -> void:
	# A start carries on from where the picture is; a seek or a stop strands
	# whatever is sounding.
	if not stop_on_sync or state == &"start":
		return
	for p in _players:
		p.stop()
