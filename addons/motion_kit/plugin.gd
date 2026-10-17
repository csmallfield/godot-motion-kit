# SPDX-License-Identifier: Apache-2.0
@tool
extends EditorPlugin

var _svg_importer: EditorImportPlugin

func _enter_tree() -> void:
	_svg_importer = preload("res://addons/motion_kit/svg/motion_svg_importer.gd").new()
	add_import_plugin(_svg_importer)
	add_autoload_singleton("MotionTransition", "res://addons/motion_kit/game/motion_transition.gd")

func _exit_tree() -> void:
	remove_import_plugin(_svg_importer)
	_svg_importer = null
	remove_autoload_singleton("MotionTransition")
