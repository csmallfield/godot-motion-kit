# SPDX-License-Identifier: Apache-2.0
## Imports an .svg as MotionSvgData instead of a texture. Godot keeps its own
## texture importer as the default; choose "Motion SVG" for a file in the
## Import dock (Import As), then Reimport.
@tool
extends EditorImportPlugin


func _get_importer_name() -> String:
	return "motion_kit.svg"


func _get_visible_name() -> String:
	return "Motion SVG"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["svg"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	# Below Godot's texture importer (1.0), so plain SVG icons stay textures.
	return 0.5


func _get_import_order() -> int:
	return 0


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_i: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option: StringName, _options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, _options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var text := FileAccess.get_file_as_string(source_file)
	if text.is_empty():
		return ERR_FILE_CANT_READ
	var data := MotionSvgParser.parse(text, source_file)
	for w in data.warnings:
		push_warning("%s: %s" % [source_file, w])
	return ResourceSaver.save(data, "%s.%s" % [save_path, _get_save_extension()])
