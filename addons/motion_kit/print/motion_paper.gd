# SPDX-License-Identifier: Apache-2.0
## A sheet of uncoated paper for MotionPlates to print on: a `size` rectangle
## (origin top-left) with seeded mottling, tooth and fibres, slightly darker
## toward its edges. Static and frame-pure; move or rotate the node to feed
## sheets through a press. `shadow` draws a soft drop shadow under it.
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionPaper
extends Node2D

const SHADER := preload("res://addons/motion_kit/print/motion_paper.gdshader")

@export var size := Vector2(1800, 1000):
	set(v): size = v; _sync()
@export var color := Color("#f2eee6"):
	set(v): color = v; _sync()
@export_range(0.0, 1.0) var grain := 0.06:
	set(v): grain = v; _sync()
@export_range(0.0, 1.0) var mottle := 0.05:
	set(v): mottle = v; _sync()
@export_range(0.0, 1.0) var fibres := 0.04:
	set(v): fibres = v; _sync()
@export_range(0.0, 1.0) var edge_shade := 0.06:
	set(v): edge_shade = v; _sync()
@export var seed := 1.0:
	set(v): seed = v; _sync()
## Drop shadow under the sheet (alpha 0 = none).
@export var shadow := Color(0, 0, 0, 0.45):
	set(v): shadow = v; _sync()
@export var shadow_blur := 24.0:
	set(v): shadow_blur = v; _sync()

var _sheet: Node2D
var _shadow: MotionShape
var _mat: ShaderMaterial


func _init() -> void:
	_shadow = MotionShape.new()
	_shadow.kind = MotionShape.Kind.RECT
	_shadow.anchor = Vector2.ZERO
	add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)
	_sheet = Node2D.new()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_sheet.material = _mat
	_sheet.draw.connect(func() -> void: _sheet.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE))
	add_child(_sheet, false, Node.INTERNAL_MODE_FRONT)
	_sync()


func _sync() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("paper", color)
	_mat.set_shader_parameter("grain", grain)
	_mat.set_shader_parameter("mottle", mottle)
	_mat.set_shader_parameter("fibres", fibres)
	_mat.set_shader_parameter("edge_shade", edge_shade)
	_mat.set_shader_parameter("seed", seed)
	_mat.set_shader_parameter("sheet_size", size)
	_shadow.visible = shadow.a > 0.0
	_shadow.size = size
	_shadow.position = Vector2(0, shadow_blur * 0.4)
	_shadow.color = shadow
	_shadow.blur = shadow_blur
	_sheet.queue_redraw()
