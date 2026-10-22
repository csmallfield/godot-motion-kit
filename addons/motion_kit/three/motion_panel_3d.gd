# SPDX-License-Identifier: Apache-2.0
## A 2D panel in a 3D world: kit 2D nodes (MotionText, MotionShape, MotionPill,
## MotionCanvas...) drawn into a small viewport and shown on a quad, unshaded,
## with `energy` above 1 to glow. Use it for signs, boards and screens in a
## MotionStage3D: anything the 2D kit can draw, with its own frame animation
## (the composition reaches nodes under `canvas` like any other).
##
##   var board := MotionPanel3D.new()
##   board.pixel_size = Vector2i(1024, 128)
##   board.world_size = Vector2(16, 2)
##   board.background = Color("#0a0a12")
##   stage.world.add_child(board)
##   var t := MotionText.new(); t.text = "PRESENTS"; board.canvas.add_child(t)
##
## The quad lies in its local XY plane, centred, facing +Z.
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionPanel3D
extends MeshInstance3D

const SHADER := preload("res://addons/motion_kit/three/motion_panel_3d.gdshader")

## Panel resolution in pixels (what `canvas` draws into).
@export var pixel_size := Vector2i(1024, 256):
	set(v): pixel_size = v; _resize()
## Quad size in world units.
@export var world_size := Vector2(8, 2):
	set(v): world_size = v; _resize()
## Brightness; above 1 feeds the environment's glow.
@export var energy := 1.0:
	set(v): energy = v; if _mat: _mat.set_shader_parameter("energy", v)
@export var tint := Color.WHITE:
	set(v): tint = v; if _mat: _mat.set_shader_parameter("tint", v)
## Fill behind the 2D content; transparent leaves only what is drawn.
@export var background := Color(0, 0, 0, 0):
	set(v): background = v; if _bg: _bg.color = v
## Re-render every frame (animated content) or only when `refresh()` is called.
@export var animated := true:
	set(v): animated = v; if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_ONCE

## Put 2D nodes here; (0, 0) is the panel's top-left pixel.
var canvas: Node2D
var viewport: SubViewport
var _bg: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if animated else SubViewport.UPDATE_ONCE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport, false, Node.INTERNAL_MODE_FRONT)
	_bg = ColorRect.new()
	_bg.color = background
	viewport.add_child(_bg)
	canvas = Node2D.new()
	canvas.name = "Canvas"
	viewport.add_child(canvas)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("energy", energy)
	_mat.set_shader_parameter("tint", tint)
	material_override = _mat
	_resize()


func _ready() -> void:
	_mat.set_shader_parameter("panel_tex", viewport.get_texture())
	_resize()


func _resize() -> void:
	if not viewport:
		return
	viewport.size = pixel_size
	_bg.size = Vector2(pixel_size)
	var q := QuadMesh.new()
	q.size = world_size
	mesh = q


## Draw the panel again (for panels with `animated` off).
func refresh() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
