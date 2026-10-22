# SPDX-License-Identifier: Apache-2.0
# Bake the Gantry take's soundtrack with the Audio Kit and save it into the project,
# so the piece plays its sound with or without the audio kit linked. Also writes
# the cue sheet for review. Needs tools/link_audio_kit.sh first:
#   godot --headless --path . -s res://demo/ftf/ftf_gantry/audio/bake.gd
extends SceneTree

const SCENE := "res://demo/ftf/ftf_gantry/ftf_gantry.tscn"
const MAP := "res://demo/ftf/ftf_gantry/audio/gantry_map.tres"
const SONG := "res://demo/ftf/ftf_gantry/audio/music/gantry_song.tres"
const TRACK := "res://demo/ftf/ftf_gantry/audio/ftf_gantry_track.res"
const CUES := "res://demo/ftf/ftf_gantry/audio/ftf_gantry_cues.json"
const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"


func _initialize() -> void:
	if not ResourceLoader.exists(BRIDGE):
		push_error("the audio kit isn't linked: run tools/link_audio_kit.sh")
		quit(1)
		return
	var comp: Node = (load(SCENE) as PackedScene).instantiate()
	comp.call("export_cue_sheet", ProjectSettings.globalize_path(CUES))
	var bridge: Node = (load(BRIDGE) as GDScript).new()
	bridge.set("composition", comp)
	bridge.set("cue_map", load(MAP))
	bridge.set("song", load(SONG))
	var t0 := Time.get_ticks_msec()
	var track: AudioStreamWAV = bridge.call("bake")
	var err := ResourceSaver.save(track, TRACK)
	print("baked %s in %d ms (%.2f s, key %s), save: %s" % [TRACK, Time.get_ticks_msec() - t0,
		track.get_length(), str(track.get_meta("ak_key", "")).left(12), error_string(err)])
	bridge.free()
	comp.free()
	quit()
