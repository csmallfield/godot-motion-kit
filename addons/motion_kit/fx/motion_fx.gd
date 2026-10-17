# SPDX-License-Identifier: Apache-2.0
## A group whose content is rendered offscreen and drawn back through an
## effect stack: slice glitch, RGB split, pixelate, brightness and goo.
## Put nodes under `content` (children placed under a MotionFX in a scene are
## moved there when the game runs; in the editor they draw without effects).
## Slices animate with the frame when the FX is inside a MotionComposition;
## elsewhere call `_frame(f)` yourself.
##
## Slice offsets follow the SCF Remotion `Sliced` component exactly: band i of
## n moves by (r - 0.5) * 2 * amount * big, with r = MK.rand(seed*97 + i*13 +
## floor(f/2)*7) and big = 1, 0.35 or 0.05 for r above 0.8, 0.55 or below.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionFX
extends Node2D

const SHADER := preload("res://addons/motion_kit/shaders/motion_fx.gdshader")
const BLUR_H := preload("res://addons/motion_kit/shaders/motion_blur_h.gdshader")
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
@export_group("Blur, glow, shadow")
## CSS filter: blur(), standard deviation in pixels.
@export var blur := 0.0
## A blurred copy of the content in its own colours under it (SVG feMerge glow);
## the value is its standard deviation in pixels.
@export var glow := 0.0
@export var glow_strength := 1.0
## A blurred, tinted copy under the content (CSS text-shadow / box-shadow).
## shadow_blur is the CSS blur radius (standard deviation = radius / 2).
@export var shadow_color := Color(0, 0, 0, 0)
@export var shadow_blur := 0.0
@export var shadow_offset := Vector2.ZERO
## One separable Gaussian pass is shared by blur, glow and shadow, so they use
## a single radius: blur if set, else glow, else shadow_blur. With blur set,
## pixel_size and goo are not applied (the blurred content replaces them).
@export_group("Other")
@export var brightness := 1.0
## CSS filter: invert(), 0..1.
@export_range(0.0, 1.0) var invert := 0.0
@export var pixel_size := 0.0
@export var goo_blur := 0.0
@export var goo_sharp := 22.0
## Render the content at this multiple of `size` (raise for 4K output).
@export_range(0.25, 4.0, 0.25) var render_scale := 1.0:
	set(v): render_scale = v; _resize()

## Where to add the nodes the effects apply to.
var content: Node2D

var _vp: SubViewport
var _vp_h: SubViewport      # horizontal blur pass
var _blur_on := false       # the blur pass has been sized for use
var _h_sprite: Sprite2D
var _h_mat: ShaderMaterial
var _view: Sprite2D
var _mat: ShaderMaterial
var _frame_f := 0.0
var _offs := PackedFloat32Array()


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
	_make_blur_pass()
	_view = Sprite2D.new()
	_view.centered = false
	_view.texture = _vp.get_texture()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("blur_tex", _vp_h.get_texture())
	_view.material = _mat
	add_child(_view, false, Node.INTERNAL_MODE_FRONT)
	_resize()


# The horizontal blur pass has its own render target. It is created with the
# content viewport (created later, it rendered a frame behind the content),
# but kept at 1x1 until a blur, glow or shadow needs it.
func _make_blur_pass() -> void:
	_vp_h = SubViewport.new()
	_vp_h.transparent_bg = true
	_vp_h.disable_3d = true
	_vp_h.size = Vector2i(1, 1)
	_vp_h.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_h_sprite = Sprite2D.new()
	_h_sprite.centered = false
	_h_sprite.texture = _vp.get_texture()
	_h_mat = ShaderMaterial.new()
	_h_mat.shader = BLUR_H
	_h_sprite.material = _h_mat
	_vp_h.add_child(_h_sprite)
	add_child(_vp_h, false, Node.INTERNAL_MODE_FRONT)


func _blur_size() -> Vector2i:
	return _vp.size if _blur_on else Vector2i(1, 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply()


func _ready() -> void:
	# Adopt children authored under this node in a scene. Not in the editor:
	# nodes moved into an internal viewport would not be saved with the scene.
	# There they draw normally, without the effects.
	if not Engine.is_editor_hint():
		for c in get_children():
			c.reparent(content, false)
	_resize()
	_apply()


func _resize() -> void:
	if not _vp:
		return
	var px := (size * render_scale).round()
	_vp.size = Vector2i(maxi(1, int(px.x)), maxi(1, int(px.y)))
	_vp_h.size = _blur_size()
	# A viewport's canvas transform can only be set once it is in the tree.
	if _vp.is_inside_tree():
		_vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(render_scale, render_scale))
	_view.scale = Vector2.ONE / render_scale


func _frame(f: float) -> void:
	_frame_f = f
	_apply()


## Remotion `Sliced` parameters in one call: amount and split in pixels.
func set_slices(amount: float, split: float, count := 18, seed_value := 1.0) -> void:
	slice_amount = amount
	slice_split = split
	slice_count = count
	slice_seed = seed_value
	_apply()


func _process(_d: float) -> void:
	_apply()


func _apply() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("frame_size", size)
	var quiet := slice_amount < 0.5 and slice_split < 0.5
	var n := clampi(slice_count, 1, MAX_SLICES)
	if _offs.size() != MAX_SLICES:
		_offs.resize(MAX_SLICES)
	if not quiet:
		for i in n:
			var r := MK.rand(slice_seed * 97.0 + i * 13.0 + floorf(_frame_f / 2.0) * 7.0)
			var big := 1.0 if r > 0.8 else (0.35 if r > 0.55 else 0.05)
			_offs[i] = (r - 0.5) * 2.0 * slice_amount * big
	_mat.set_shader_parameter("slice_count", 0 if quiet else n)
	_mat.set_shader_parameter("slice_offsets", _offs)
	_mat.set_shader_parameter("split", 0.0 if quiet else slice_split)
	_mat.set_shader_parameter("brightness", brightness)
	_mat.set_shader_parameter("invert", invert)
	_mat.set_shader_parameter("pixel_size", pixel_size)
	_mat.set_shader_parameter("goo_blur", goo_blur)
	_mat.set_shader_parameter("goo_sharp", goo_sharp)
	var sigma := blur if blur > 0.01 else (glow if glow > 0.01 else shadow_blur * 0.5)
	var need := sigma > 0.01
	# Hidden groups stop rendering offscreen (both passes).
	# Viewports render in the order they became active, and the blur pass must
	# render after the content it blurs, or it shows the previous frame. So
	# whenever the content viewport (re)starts, the blur pass restarts after it.
	var live := is_visible_in_tree() or not is_inside_tree()
	var mode := SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	var restarted := mode != _vp.render_target_update_mode and live
	_vp.render_target_update_mode = mode
	if need and not _blur_on:
		_blur_on = true
		_vp_h.size = _blur_size()
	var hmode := SubViewport.UPDATE_ALWAYS if (need and live) else SubViewport.UPDATE_DISABLED
	if restarted:
		_vp_h.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp_h.render_target_update_mode = hmode
	_h_mat.set_shader_parameter("sigma", sigma * render_scale)
	_mat.set_shader_parameter("blur_sigma", sigma * render_scale if need else 0.0)
	_mat.set_shader_parameter("blur_main", blur > 0.01)
	_mat.set_shader_parameter("glow", glow)
	_mat.set_shader_parameter("glow_strength", glow_strength)
	_mat.set_shader_parameter("shadow_color", shadow_color)
	_mat.set_shader_parameter("shadow_blur", shadow_blur)
	_mat.set_shader_parameter("shadow_offset", shadow_offset)
