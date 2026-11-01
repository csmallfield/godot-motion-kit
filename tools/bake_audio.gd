# SPDX-License-Identifier: Apache-2.0
# Bake a piece's soundtrack with the Godot Audio Kit and save it into the
# project, so the piece plays its sound with or without the audio kit linked.
# Also writes the piece's cue sheet (JSON) for review. Needs the audio kit
# linked first (tools/link_audio_kit.sh):
#
#   godot --headless --path . -s res://tools/bake_audio.gd -- --piece=res://demo/ftf/ftf_gantry
#   godot --headless --path . -s res://tools/bake_audio.gd -- --piece=res://demo/ftf/ftf_intro.tscn
#
# Convention: a piece is a folder <dir> holding <dir name>.tscn (or a .tscn
# given directly, whose folder is <dir>), with its sound in <dir>/audio/:
#   map    the one *_map.tres         (the AKCueMap: cue name -> sound)
#   song   the one music/*song.tres   (the AKSong: tempo, sections)
#   track  the one *_track.res        (written; <scene>_track.res when new)
#   cues   the one *_cues.json        (written; <scene>_cues.json when new)
# Any of them can be overridden: --scene= --map= --song= --track= --cues=
# (res:// or absolute paths). Bake into a scratch path to compare without
# touching the committed track: --track=/tmp/x.res --cues=/tmp/x.json
extends SceneTree

const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	if not args.has("piece") and not args.has("scene"):
		push_error("usage: -s res://tools/bake_audio.gd -- --piece=res://demo/ftf/ftf_x [--track=...]")
		quit(2)
		return
	if not ResourceLoader.exists(BRIDGE):
		push_error("the audio kit isn't linked: run tools/link_audio_kit.sh")
		quit(1)
		return
	var paths := resolve(str(args.get("piece", "")), args)
	for k in ["scene", "map", "song"]:
		if paths[k] == "" or not ResourceLoader.exists(paths[k]):
			push_error("bake_audio: no %s for %s (found '%s'; pass --%s=)" % [k, args.get("piece", ""), paths[k], k])
			quit(1)
			return
	var comp: Node = (load(paths.scene) as PackedScene).instantiate()
	comp.call("export_cue_sheet", _abs(paths.cues))
	var bridge: Node = (load(BRIDGE) as GDScript).new()
	bridge.set("composition", comp)
	bridge.set("cue_map", load(paths.map))
	bridge.set("song", load(paths.song))
	var t0 := Time.get_ticks_msec()
	var track: AudioStreamWAV = bridge.call("bake")
	var err := ResourceSaver.save(track, paths.track)
	print("baked %s in %d ms (%.2f s, key %s), save: %s" % [paths.track, Time.get_ticks_msec() - t0,
		track.get_length(), str(track.get_meta("ak_key", "")).left(12), error_string(err)])
	bridge.free()
	comp.free()
	quit(0 if err == OK else 1)


## The scene, map, song, track and cues paths for `piece` (a folder or a
## .tscn), by the convention above, with `overrides` (same keys) winning.
static func resolve(piece: String, overrides := {}) -> Dictionary:
	var dir := piece.trim_suffix("/")
	var scene := ""
	if piece.ends_with(".tscn"):
		scene = piece
		dir = piece.get_base_dir()
	elif dir != "":
		scene = "%s/%s.tscn" % [dir, dir.get_file()]
	scene = str(overrides.get("scene", scene))
	if dir == "":
		dir = scene.get_base_dir()
	var stem := scene.get_file().get_basename()
	var audio := dir + "/audio"
	var out := {
		scene = scene,
		map = _one(audio, "_map.tres", ""),
		song = _one(audio + "/music", "song.tres", ""),
		track = _one(audio, "_track.res", "%s/%s_track.res" % [audio, stem]),
		cues = _one(audio, "_cues.json", "%s/%s_cues.json" % [audio, stem]),
	}
	for k in out:
		if overrides.has(k):
			out[k] = str(overrides[k])
	return out


## The single file in `dir` whose name ends with `suffix`, else `fallback`.
static func _one(dir: String, suffix: String, fallback: String) -> String:
	var found := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(suffix):
			found.append(f)
	if found.size() == 1:
		return dir + "/" + found[0]
	if found.size() > 1:
		push_error("bake_audio: several *%s in %s: %s (pass the one to use)" % [suffix, dir, ", ".join(found)])
	return fallback


static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p
