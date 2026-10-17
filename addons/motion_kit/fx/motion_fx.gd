# SPDX-License-Identifier: Apache-2.0
## A group whose content is rendered offscreen and drawn back through an
## effect stack: slice glitch, RGB split, pixelate, brightness and goo.
## Put nodes under `content` (children placed under a MotionFX in a scene are
## moved there when it enters the tree).
##
## Slice offsets follow the SCF Remotion `Sliced` component exactly: band i of
## n moves by (r - 0.5) * 2 * amount * big, with r = MK.rand(seed*97 + i*13 +
## floor(f/2)*7) and big = 1, 0.35 or 0.05 for r above 0.8, 0.55 or below.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionFX
extends Node2D

const SHADER := preload("res://addons/motion_kit/shaders/motion_fx.gdshader")
const MAX_SLICES := 64

## Size of the content area in pixels (the composition size, usually).
@export var size := Vector2(1920, 1080):
	set(v): size = v; _resize()
@export_group("Slice glitch")
## Largest band displacement in pixels (0 = off).
@export var slice_amount := 0.0
@export var slice_split := 0.0
@export_range(1, 64) var slice_count := 18
@export var slice_seed := 1.0
@export_group("Other")
@export var brightness := 1.0
@export var pixel_size := 0.0
@export var goo_blur := 0.0
@export var goo_sharp := 22.0
## Render the content at this multiple of `size` (raise for 4K output).
@export_range(0.25, 4.0, 0.25) var render_scale := 1.0:
	set(v): render_scale = v; _resize()

## Where to add the nodes the effects apply to.
var content: Node2D

var _vp: SubViewport
var _view: Sprite2D
var _mat: ShaderMaterial
var _frame_f := 0.0


func _init() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	content = Node2D.new()
	content.name = "Content"
	_vp.add_child(content)
	add_child(_vp, false, Node.INTERNAL_MODE_FRONT)
	_view = Sprite2D.new()
	_view.centered = false
	_view.texture = _vp.get_texture()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_view.material = _mat
	add_child(_view, false, Node.INTERNAL_MODE_FRONT)
	_resize()


func _ready() -> void:
	# Adopt children authored under this node in a scene.
	for c in get_children():
		if c != _vp and c != _view:
			c.reparent(content, false)
	_resize()
	_apply()


func _resize() -> void:
	if not _vp:
		return
	var px := (size * render_scale).round()
	_vp.size = Vector2i(maxi(1, int(px.x)), maxi(1, int(px.y)))
	# A viewport's canvas transform can only be set once it is in the tree.
	if _vp.is_inside_tree():
		_vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(render_scale, render_scale))
	_view.scale = Vector2.ONE / render_scale


func _frame(f: float) -> void:
	_frame_f = f
	_apply()


## Remotion `Sliced` parameters in one call: amount and split in pixels.
func set_slices(amount: float, split: float, count := 18, seed := 1.0) -> void:
	slice_amount = amount
	slice_split = split
	slice_count = count
	slice_seed = seed
	_apply()


func _process(_d: float) -> void:
	_apply()


func _apply() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("frame_size", size)
	var quiet := slice_amount < 0.5 and slice_split < 0.5
	var n := clampi(slice_count, 1, MAX_SLICES)
	var offs := PackedFloat32Array()
	offs.resize(MAX_SLICES)
	if not quiet:
		for i in n:
			var r := MK.rand(slice_seed * 97.0 + i * 13.0 + floorf(_frame_f / 2.0) * 7.0)
			var big := 1.0 if r > 0.8 else (0.35 if r > 0.55 else 0.05)
			offs[i] = (r - 0.5) * 2.0 * slice_amount * big
	_mat.set_shader_parameter("slice_count", 0 if quiet else n)
	_mat.set_shader_parameter("slice_offsets", offs)
	_mat.set_shader_parameter("split", 0.0 if quiet else slice_split)
	_mat.set_shader_parameter("brightness", brightness)
	_mat.set_shader_parameter("pixel_size", pixel_size)
	_mat.set_shader_parameter("goo_blur", goo_blur)
	_mat.set_shader_parameter("goo_sharp", goo_sharp)
