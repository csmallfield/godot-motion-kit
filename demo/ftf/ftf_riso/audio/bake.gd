# SPDX-License-Identifier: Apache-2.0
# Bake FTF take 3 (RISO)'s soundtrack with the Audio Kit into the project and
# write its cue sheet. Needs tools/link_audio_kit.sh first:
#   godot --headless --path . -s res://demo/ftf/ftf_riso/audio/bake.gd
extends SceneTree

const SCENE := "res://demo/ftf/ftf_riso/ftf_riso.tscn"
const MAP := "res://demo/ftf/ftf_riso/audio/riso_map.tres"
const SONG := "res://demo/ftf/ftf_riso/audio/music/riso_song.tres"
const TRACK := "res://demo/ftf/ftf_riso/audio/riso_track.res"
const CUES := "res://demo/ftf/ftf_riso/audio/riso_cues.json"
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
	print("baked %s in %d ms (%.2f s), save: %s" % [TRACK, Time.get_ticks_msec() - t0, track.get_length(), error_string(err)])
	bridge.free()
	comp.free()
	quit()
