# SPDX-License-Identifier: Apache-2.0
## Time displacement and slit-scan: the content is cut into bands (rows,
## columns, nested boxes or colour channels) and each band shows the content
## at a different moment, f - delay(band). Moving content shears, ripples and
## smears; with `slit` every band shows the same thin slice of the content
## instead of its own, stretched to the band, which is the slit-scan photograph:
## anything crossing the slit becomes streaks of light (the 2001 stargate, a
## photo-finish camera). Animate `delay` and `slit` to 0 and the picture snaps
## back to the plain, sharp content.
##
## The content is a MotionComposition, instanced once per band (from `scene`
## or `builder`). Each instance draws on the parent's timeline: a band with
## delay d is a nested composition with `start = d`, so it sees f - d. Nothing
## accumulates between frames, so scrubbing, seeking and reversing work, and
## content must accept negative frames.
##
## Each band renders into its own SubViewport the size of the band, so a
## full set of rows or columns costs one frame of fill in total, plus the
## content's script cost once per band. BOXES draws nested boxes outside in,
## each a full box: fill is the sum of their areas (about bands / (2p+1)
## frames for `box_power` p), so keep box counts to a dozen or two.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionTimeSlices
extends Node2D

enum Layout {
	ROWS,      ## horizontal strips, top to bottom
	COLUMNS,   ## vertical strips, left to right
	BOXES,     ## nested boxes about the centre, outermost first (a square tunnel)
	CHANNELS,  ## three full-frame copies tinted red, green and blue, added together
}
enum Profile {
	LINEAR,    ## u: the last band lags most
	REVERSE,   ## 1 - u: the first band lags most
	CENTRE,    ## the middle band lags most
	EDGES,     ## the outer bands lag most
	SINE,      ## a wave across the bands (`waves`, `phase`)
	RANDOM,    ## seeded per band (`seed_value`)
	CUSTOM,    ## `profile_fn(u) -> 0..1`
}

## The content: a scene whose root is a MotionComposition. Or set `builder`.
@export var scene: PackedScene:
	set(v):
		scene = v
		_queue_rebuild()
## Reference size of the content and of the area the bands cover.
@export var size := Vector2(1920, 1080):
	set(v):
		size = v
		_queue_rebuild()
@export var layout := Layout.COLUMNS:
	set(v):
		layout = v
		_queue_rebuild()
@export_range(1, 256) var bands := 48:
	set(v):
		bands = v
		_queue_rebuild()

@export_group("Time")
## Frames the most delayed band lags behind. 0 = every band shows the present.
@export var delay := 0.0
@export var profile := Profile.LINEAR
## SINE: number of cycles across the bands, and their offset in turns.
@export var waves := 1.0
@export var phase := 0.0
## RANDOM: seed.
@export var seed_value := 1.0
## Quantise each band's delay to whole steps of this many frames (0 = smooth).
@export var step := 0.0

@export_group("Slit")
## 0 = each band shows its own place (time displacement); 1 = every band shows
## the slit (slit-scan). In between, the bands unfold from the slit.
@export_range(0.0, 1.0) var slit := 0.0
## Where the slit sits across the bands, 0..1 (COLUMNS: x, ROWS: y, BOXES: unused).
@export_range(0.0, 1.0) var slit_pos := 0.5
## Size of the slice each band shows at slit = 1, in pixels across the band
## (COLUMNS: width, ROWS: height, BOXES: width of the centre box). Smaller than
## the band, it is stretched to fit: streaks.
@export var slit_width := 2.0

@export_group("Layout")
## BOXES: box k has scale (1 - k / bands) ^ box_power. Higher packs boxes toward
## the centre, like depth in a tunnel.
@export var box_power := 1.6
## Show only the bands within `reveal` (0..1 of the bands) of `reveal_from`.
## Hidden bands cost nothing.
@export_range(0.0, 1.0) var reveal := 1.0
@export_range(0.0, 1.0) var reveal_from := 0.5

## Builds one content instance (a MotionComposition). Used when `scene` is empty.
var builder: Callable
## CUSTOM profile: u (0..1 across the bands) -> 0..1 of `delay`.
var profile_fn: Callable

var _bands: Array[Dictionary] = []   # {vp, holder, inst, spr, dst: Rect2, u: float}
var _dirty := true
var _add_mat: CanvasItemMaterial


func _ready() -> void:
	if _dirty:
		rebuild()


func _queue_rebuild() -> void:
	_dirty = true
	if is_inside_tree():
		rebuild.call_deferred()


## Number of bands actually built (CHANNELS is always 3).
func band_count() -> int:
	return 3 if layout == Layout.CHANNELS else bands


## The band rectangles on screen, in this node's space.
func band_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := band_count()
	for k in n:
		match layout:
			Layout.ROWS:
				var y0 := roundf(size.y * k / n)
				var y1 := roundf(size.y * (k + 1) / n)
				out.append(Rect2(0, y0, size.x, y1 - y0))
			Layout.COLUMNS:
				var x0 := roundf(size.x * k / n)
				var x1 := roundf(size.x * (k + 1) / n)
				out.append(Rect2(x0, 0, x1 - x0, size.y))
			Layout.BOXES:
				var s := pow(1.0 - float(k) / n, box_power)
				var bs := (size * s).round().max(Vector2(2, 2))
				out.append(Rect2(((size - bs) * 0.5).round(), bs))
			Layout.CHANNELS:
				out.append(Rect2(Vector2.ZERO, size))
	return out


## Throw away the bands and build them again (after changing scene, layout,
## bands or size; setters do this for you).
func rebuild() -> void:
	_dirty = false
	for b in _bands:
		(b.vp as Node).queue_free()
		(b.spr as Node).queue_free()
	_bands.clear()
	if scene == null and not builder.is_valid():
		return
	var rects := band_rects()
	var n := rects.size()
	if layout == Layout.CHANNELS and _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for k in n:
		var dst: Rect2 = rects[k]
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.size = Vector2i(maxi(1, int(dst.size.x)), maxi(1, int(dst.size.y)))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		var holder := Node2D.new()
		vp.add_child(holder)
		var inst: Node = scene.instantiate() if scene else builder.call()
		inst.set("hide_outside", false)
		inst.set("autoplay", false)
		holder.add_child(inst)
		add_child(vp, false, Node.INTERNAL_MODE_FRONT)
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = vp.get_texture()
		spr.region_enabled = true
		if layout == Layout.CHANNELS:
			spr.modulate = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)][k]
			spr.material = _add_mat
		add_child(spr, false, Node.INTERNAL_MODE_BACK)
		var u := (k + 0.5) / n
		if layout == Layout.BOXES:
			u = float(k) / maxf(1.0, n - 1.0)
		elif layout == Layout.CHANNELS:
			u = k * 0.5
		_bands.append({vp = vp, holder = holder, inst = inst, spr = spr, dst = dst, u = u})


## 0..1 share of `delay` for a band at u (0..1 across the bands).
func profile_at(u: float, k: int) -> float:
	return profile_value(profile, u, k, waves, phase, seed_value, profile_fn)


## A profile's 0..1 share of `delay` for band k at u (0..1 across the bands):
## the shared shape table of MotionTimeSlices and MotionTimeCache. `waves` and
## `phase` shape SINE, `seed_v` RANDOM, `fn(u)` CUSTOM.
static func profile_value(shape: Profile, u: float, k: int, waves_v := 1.0, phase_v := 0.0,
		seed_v := 1.0, fn := Callable()) -> float:
	match shape:
		Profile.LINEAR:
			return u
		Profile.REVERSE:
			return 1.0 - u
		Profile.CENTRE:
			return 1.0 - absf(2.0 * u - 1.0)
		Profile.EDGES:
			return absf(2.0 * u - 1.0)
		Profile.SINE:
			return 0.5 + 0.5 * sin(TAU * (waves_v * u + phase_v))
		Profile.RANDOM:
			return MK.rand(k * 7.13 + seed_v * 31.7)
		Profile.CUSTOM:
			return float(fn.call(u)) if fn.is_valid() else 0.0
	return 0.0


## The content rectangle band k shows (its own place lerped toward the slit).
func source_rect(k: int) -> Rect2:
	var b: Dictionary = _bands[k]
	var dst: Rect2 = b.dst
	if slit <= 0.0 or layout == Layout.CHANNELS:
		return dst
	var s: Rect2
	match layout:
		Layout.COLUMNS:
			s = Rect2(slit_pos * size.x - slit_width * 0.5, 0, slit_width, size.y)
		Layout.ROWS:
			s = Rect2(0, slit_pos * size.y - slit_width * 0.5, size.x, slit_width)
		Layout.BOXES:
			var bs := Vector2(slit_width, slit_width * size.y / size.x)
			s = Rect2((size - bs) * 0.5, bs)
	var pos := dst.position.lerp(s.position, slit)
	var sz := dst.size.lerp(s.size, slit).min(dst.size).max(Vector2(0.5, 0.5))
	return Rect2(pos, sz)


func _frame(f: float) -> void:
	if _dirty and is_inside_tree():
		rebuild()
	var live := is_visible_in_tree()
	var n := _bands.size()
	for k in n:
		var b: Dictionary = _bands[k]
		var vp: SubViewport = b.vp
		var inst: Node = b.inst
		var spr: Sprite2D = b.spr
		var u: float = b.u
		var on := live and absf(u - reveal_from) <= reveal * 0.5 + 0.5 / n
		spr.visible = on
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		if not on:
			# The parent still walks into the band: make it return at once.
			inst.set("hide_outside", true)
			inst.set("start", 1e9)
			continue
		var d := delay * profile_at(u, k)
		if step > 0.0:
			d = floorf(d / step + 0.5) * step
		inst.set("hide_outside", false)
		inst.set("start", d)      # the parent's walk renders it at f - d next
		(inst as CanvasItem).visible = true
		var dst: Rect2 = b.dst
		var src := source_rect(k)
		(b.holder as Node2D).position = -src.position
		spr.region_rect = Rect2(Vector2.ZERO, src.size)
		spr.position = dst.position
		spr.scale = dst.size / src.size
