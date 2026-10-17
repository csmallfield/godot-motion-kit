# SPDX-License-Identifier: Apache-2.0
## A full-frame overlay drawn by a shader: TV static or a CRT tube.
## Static reseeds every frame; the CRT roll band moves with the frame.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionOverlay
extends Node2D

enum Kind { STATIC, CRT }

const SHADERS := {
	Kind.STATIC: preload("res://addons/motion_kit/shaders/motion_static.gdshader"),
	Kind.CRT: preload("res://addons/motion_kit/shaders/motion_crt.gdshader"),
}

@export var kind := Kind.STATIC:
	set(v): kind = v; _setup()
@export var size := Vector2(1920, 1080):
	set(v): size = v; queue_redraw()
## Static opacity.
@export var opacity := 1.0
## CRT: scanline darkness, roll band on/off, vignette strength.
@export var line_dark := 0.38
@export var roll := true
@export var vignette := 0.7

var _mat: ShaderMaterial


# The material is built in code; keep it out of saved scenes and duplicates
# (a copy then gets its own material from _init instead of sharing this one).
func _validate_property(property: Dictionary) -> void:
	if property.name == "material":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _init() -> void:
	_setup()


func _setup() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADERS[kind]
	material = _mat
	queue_redraw()


func _frame(f: float) -> void:
	if kind == Kind.STATIC:
		_mat.set_shader_parameter("seed", fmod(floorf(f), 37.0) + 1.0)
		_mat.set_shader_parameter("opacity", opacity)
	else:
		_mat.set_shader_parameter("frame_size", size)
		_mat.set_shader_parameter("line_dark", line_dark)
		_mat.set_shader_parameter("vignette", vignette)
		_mat.set_shader_parameter("roll_y", fmod(f * 9.0, 1400.0) - 300.0 if roll else -10000.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
