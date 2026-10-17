# SPDX-License-Identifier: Apache-2.0
# Plays one intro full-screen, then returns to the menu with a transition.
# Any key, click or gamepad button skips.
class_name IntroPlayer
extends Node2D

static var next_scene := "res://demo/scf/e1_supergraphic.tscn"
static var style := "circle"

var _intro: MotionComposition
var _leaving := false


func _ready() -> void:
	_intro = (load(next_scene) as PackedScene).instantiate()
	_intro.fit_to_viewport = true
	add_child(_intro)
	_intro.finished.connect(_back)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and (e is InputEventKey or e is InputEventMouseButton or e is InputEventJoypadButton):
		_back()


func _back() -> void:
	if _leaving:
		return
	_leaving = true
	MotionTransition.change_scene("res://demo/demo_menu.tscn", style)
