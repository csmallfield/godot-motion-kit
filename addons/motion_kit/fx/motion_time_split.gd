# SPDX-License-Identifier: Apache-2.0
## RGB time split for content on ANY background: the content (a
## MotionComposition) is rendered three times, at f - delay * (0, 1, 2) for
## red, green and blue, and composited as three black silhouettes (normal
## blend) with the three channels added on top. Where the copies coincide the
## result is exactly the content; where it moves, it fringes red, green and
## blue (cyan, magenta and yellow where two overlap) over whatever is behind.
## MotionTimeSlices CHANNELS does the same by pure addition, which needs an
## opaque dark background; this works over a racing checkerboard.
##
## With `delay` 0 the three viewports stop and one plain copy draws instead,
## so it only costs while it splits. `region` limits the viewports to the part
## of the frame the content uses (a logo's box plus its motion), which is
## where the cost is: three region-sized renders and six sprites.
##
##   var split := MotionTimeSplit.new()
##   split.builder = func() -> Node: return LogoSource.new()
##   split.region = Rect2(160, 200, 1600, 560)
##   func _frame(f): split.delay = 4.0 * exp(-(f - 240.0) * 0.3)
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionTimeSplit
extends Node2D

## The content: a scene whose root is a MotionComposition. Or set `builder`.
@export var scene: PackedScene:
	set(v):
		scene = v
		_queue_rebuild()
## The part of the content's frame that is rendered (content coordinates).
@export var region := Rect2(0, 0, 1920, 1080):
	set(v):
		region = v
		_queue_rebuild()
## Frames green lags red (blue lags twice as much). 0 = the plain content.
@export var delay := 0.0
## Order of the channels in time (red, green, blue shares of `delay`).
@export var shares := Vector3(0.0, 1.0, 2.0)
## Tints for the three copies (they should sum to white).
@export var tints: Array[Color] = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]

## Builds one content instance. Used when `scene` is empty.
var builder: Callable

var _copies: Array[Dictionary] = []   # {vp, holder, inst, mask, add}
var _plain: Node
var _dirty := true
var _add_mat: CanvasItemMaterial


func _ready() -> void:
	if _dirty:
		rebuild()


func _queue_rebuild() -> void:
	_dirty = true
	if is_inside_tree():
		rebuild.call_deferred()


func _make() -> Node:
	var inst: Node = scene.instantiate() if scene else builder.call()
	inst.set("hide_outside", false)
	inst.set("autoplay", false)
	return inst


func rebuild() -> void:
	_dirty = false
	for c in _copies:
		(c.vp as Node).queue_free()
		(c.mask as Node).queue_free()
		(c.add as Node).queue_free()
	_copies.clear()
	if _plain:
		_plain.queue_free()
		_plain = null
	if scene == null and not builder.is_valid():
		return
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var masks: Array[Sprite2D] = []
	var adds: Array[Sprite2D] = []
	for k in 3:
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.size = Vector2i(maxi(1, int(region.size.x)), maxi(1, int(region.size.y)))
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		var holder := Node2D.new()
		holder.position = -region.position
		vp.add_child(holder)
		var inst := _make()
		holder.add_child(inst)
		add_child(vp, false, Node.INTERNAL_MODE_FRONT)
		var mask := Sprite2D.new()
		mask.centered = false
		mask.texture = vp.get_texture()
		mask.position = region.position
		mask.modulate = Color(0, 0, 0, 1)
		masks.append(mask)
		var add := Sprite2D.new()
		add.centered = false
		add.texture = vp.get_texture()
		add.position = region.position
		add.modulate = tints[k]
		add.material = _add_mat
		adds.append(add)
		_copies.append({vp = vp, holder = holder, inst = inst, mask = mask, add = add})
	# draw order: the three silhouettes, then the three channels
	for m in masks:
		add_child(m, false, Node.INTERNAL_MODE_BACK)
	for a in adds:
		add_child(a, false, Node.INTERNAL_MODE_BACK)
	_plain = _make()
	add_child(_plain, false, Node.INTERNAL_MODE_BACK)


func _frame(f: float) -> void:
	if _dirty and is_inside_tree():
		rebuild()
	var live := is_visible_in_tree()
	var on := live and delay > 0.0
	for k in _copies.size():
		var c: Dictionary = _copies[k]
		var inst: Node = c.inst
		(c.mask as CanvasItem).visible = on
		(c.add as CanvasItem).visible = on
		(c.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		inst.set("hide_outside", not on)
		inst.set("start", delay * shares[k] if on else 1e9)
		if on:
			(inst as CanvasItem).visible = true   # hide_outside may have hidden it while off
	if _plain:
		_plain.set("hide_outside", on)
		_plain.set("start", 1e9 if on else 0.0)
		(_plain as CanvasItem).visible = live and not on
