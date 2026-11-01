# SPDX-License-Identifier: Apache-2.0
## Slit-scan and channel splits that render each moment once. The cheap
## sibling of MotionTimeSlices for the two cases where every band shows the
## same part of the content and only the moment differs:
##
## - ROWS / COLUMNS: a slit-scan photograph. Every band shows the slit (a
##   `slit_width`-pixel line of the content at `slit_pos`), stretched across
##   the band, at f - delay(band): anything crossing the slit becomes streaks.
## - CHANNELS: three full-frame copies tinted red, green and blue and added,
##   each at its own moment: a time-split colour fringe.
##
## MotionTimeSlices renders one content instance per band. Here the bands'
## delays are quantised (`step`) and every distinct delay is rendered once,
## into a slot the size of the slit (or the frame), and shared by all the
## bands that want it. A symmetric profile (EDGES, CENTRE) over 96 columns with
## a 1-frame step and an 18-frame delay is 19 renders of a 3-pixel line; a
## red/cyan split (`channel_shares`) is two renders of the frame instead of
## three. When there are more distinct delays than `slots`, they are merged to
## `slots` evenly spaced levels.
##
## Frame-pure: the slot assignment is recomputed from f every frame (distinct
## delays sorted, slot i takes the i-th), each slot is a nested composition
## with `start` = its delay, nothing is kept between frames. Content must
## accept negative frames. Heavy content should cull itself to what its slot
## shows (MotionViewRect.of(self)): a slit slot is a few pixels wide.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionTimeCache
extends Node2D

enum Layout {
	ROWS,      ## horizontal bands; the slit is a row at slit_pos (0..1 down)
	COLUMNS,   ## vertical bands; the slit is a column at slit_pos (0..1 across)
	CHANNELS,  ## three full-frame copies tinted R, G, B and added
}

## The content: a scene whose root is a MotionComposition. Or set `builder`.
@export var scene: PackedScene:
	set(v):
		scene = v
		_queue_rebuild()
@export var size := Vector2(1920, 1080):
	set(v):
		size = v
		_queue_rebuild()
@export var layout := Layout.COLUMNS:
	set(v):
		layout = v
		_queue_rebuild()
@export_range(1, 512) var bands := 96:
	set(v):
		bands = v
		_queue_rebuild()
## Most distinct moments rendered per frame (one content instance each).
@export_range(1, 64) var slots := 20:
	set(v):
		slots = v
		_queue_rebuild()

@export_group("Time")
@export var delay := 0.0
## Same profiles as MotionTimeSlices (u = 0..1 across the bands; CHANNELS: R 0, G 0.5, B 1).
@export var profile := MotionTimeSlices.Profile.LINEAR
@export var waves := 1.0
@export var phase := 0.0
@export var seed_value := 1.0
## Quantise delays to steps of this many frames: equal delays share a render.
@export var step := 1.0

@export_group("Slit")
@export_range(0.0, 1.0) var slit_pos := 0.5
@export var slit_width := 3.0
## Show only the bands within `reveal` (0..1 of the bands) of `reveal_from`.
@export_range(0.0, 1.0) var reveal := 1.0
@export_range(0.0, 1.0) var reveal_from := 0.5

## CUSTOM profile: u -> 0..1 of `delay`.
var profile_fn: Callable
## CHANNELS: which delay share each channel uses, e.g. [1.0, 0.0, 0.0] = red
## lags, green and blue together (a red/cyan split in two renders).
var channel_shares := [0.0, 0.5, 1.0]
var builder: Callable

var _slots: Array[Dictionary] = []   # {vp, holder, inst}
var _bands: Array[Dictionary] = []   # {spr, dst, u}
var _dirty := true
var _add_mat: CanvasItemMaterial


func _ready() -> void:
	if _dirty:
		rebuild()


func _queue_rebuild() -> void:
	_dirty = true
	if is_inside_tree():
		rebuild.call_deferred()


func band_count() -> int:
	return 3 if layout == Layout.CHANNELS else bands


## The content rectangle every slot renders: the slit, or the frame.
func region() -> Rect2:
	match layout:
		Layout.COLUMNS:
			var w := maxf(1.0, ceilf(slit_width))
			return Rect2(roundf(slit_pos * size.x - w * 0.5), 0, w, size.y)
		Layout.ROWS:
			var h := maxf(1.0, ceilf(slit_width))
			return Rect2(0, roundf(slit_pos * size.y - h * 0.5), size.x, h)
	return Rect2(Vector2.ZERO, size)


func rebuild() -> void:
	_dirty = false
	for s in _slots:
		(s.vp as Node).queue_free()
	for b in _bands:
		(b.spr as Node).queue_free()
	_slots.clear()
	_bands.clear()
	if scene == null and not builder.is_valid():
		return
	var n_slots := mini(slots, 3) if layout == Layout.CHANNELS else slots
	var reg := region()
	for i in n_slots:
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.size = Vector2i(int(reg.size.x), int(reg.size.y))
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		var holder := Node2D.new()
		vp.add_child(holder)
		var inst: Node = scene.instantiate() if scene else builder.call()
		inst.set("hide_outside", true)
		inst.set("autoplay", false)
		inst.set("start", 1e9)
		holder.add_child(inst)
		add_child(vp, false, Node.INTERNAL_MODE_FRONT)
		_slots.append({vp = vp, holder = holder, inst = inst})
	if layout == Layout.CHANNELS and _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var n := band_count()
	for k in n:
		var dst := Rect2(Vector2.ZERO, size)
		match layout:
			Layout.ROWS:
				var y0 := roundf(size.y * k / n)
				dst = Rect2(0, y0, size.x, roundf(size.y * (k + 1) / n) - y0)
			Layout.COLUMNS:
				var x0 := roundf(size.x * k / n)
				dst = Rect2(x0, 0, roundf(size.x * (k + 1) / n) - x0, size.y)
		var spr := Sprite2D.new()
		spr.centered = false
		spr.region_enabled = true
		if layout == Layout.CHANNELS:
			spr.modulate = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)][k]
			spr.material = _add_mat
		add_child(spr, false, Node.INTERNAL_MODE_BACK)
		_bands.append({spr = spr, dst = dst, u = (k + 0.5) / n})


## 0..1 share of `delay` for a band at u.
func profile_at(u: float, k: int) -> float:
	if layout == Layout.CHANNELS:
		return float(channel_shares[k])
	return MotionTimeSlices.profile_value(profile, u, k, waves, phase, seed_value, profile_fn)


## The distinct delays rendered this frame (after quantising and merging).
func moments() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for b in _bands:
		if (b.spr as Sprite2D).visible:
			var d: float = b.get("d", 0.0)
			if not out.has(d):
				out.append(d)
	out.sort()
	return out


func _frame(_f: float) -> void:
	if _dirty and is_inside_tree():
		rebuild()
	var live := is_visible_in_tree()
	var n := _bands.size()
	var reg := region()
	# 1. each band's delay, quantised
	var values: Array[float] = []
	for k in n:
		var b: Dictionary = _bands[k]
		var u: float = b.u
		var on := live and (layout == Layout.CHANNELS or absf(u - reveal_from) <= reveal * 0.5 + 0.5 / n)
		(b.spr as Sprite2D).visible = on
		var d := delay * profile_at(u, k)
		if step > 0.0:
			d = floorf(d / step + 0.5) * step
		d = snappedf(d, 0.001)
		b.d = d
		if on and not values.has(d):
			values.append(d)
	values.sort()
	# 2. too many moments: merge to evenly spaced levels
	if values.size() > _slots.size() and _slots.size() > 0:
		var lo: float = values[0]
		var hi: float = values[values.size() - 1]
		var m := _slots.size()
		var merged: Array[float] = []
		for k in n:
			var b: Dictionary = _bands[k]
			var t := 0.0 if hi <= lo else ((b.d as float) - lo) / (hi - lo)
			b.d = snappedf(lo + roundf(t * (m - 1)) * (hi - lo) / maxf(1.0, m - 1.0), 0.001)
			if (b.spr as Sprite2D).visible and not merged.has(b.d):
				merged.append(b.d)
		merged.sort()
		values = merged
	# 3. slots render the moments; bands sample their slot
	var reg_size := Vector2i(int(reg.size.x), int(reg.size.y))
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var vp: SubViewport = s.vp
		var inst: Node = s.inst
		if i < values.size():
			if vp.size != reg_size:
				vp.size = reg_size
			(s.holder as Node2D).position = -reg.position
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			inst.set("hide_outside", false)
			inst.set("start", values[i])
			(inst as CanvasItem).visible = true
		else:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			inst.set("hide_outside", true)
			inst.set("start", 1e9)
	for k in n:
		var b: Dictionary = _bands[k]
		var spr: Sprite2D = b.spr
		if not spr.visible:
			continue
		var i := values.find(b.d as float)
		var vp: SubViewport = _slots[maxi(0, i)].vp
		spr.texture = vp.get_texture()
		var dst: Rect2 = b.dst
		spr.region_rect = Rect2(Vector2.ZERO, reg.size)
		spr.position = dst.position
		spr.scale = dst.size / reg.size
