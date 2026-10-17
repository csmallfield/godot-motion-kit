# SPDX-License-Identifier: Apache-2.0
@tool
extends EditorPlugin

const AUTOLOAD := "MotionTransition"
var _svg_importer: EditorImportPlugin


func _enter_tree() -> void:
	_svg_importer = preload("res://addons/motion_kit/svg/motion_svg_importer.gd").new()
	add_import_plugin(_svg_importer)


func _exit_tree() -> void:
	remove_import_plugin(_svg_importer)
	_svg_importer = null


func _enable_plugin() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD):
		add_autoload_singleton(AUTOLOAD, "res://addons/motion_kit/game/motion_transition.gd")


func _disable_plugin() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD):
		remove_autoload_singleton(AUTOLOAD)
