# SPDX-License-Identifier: Apache-2.0
## Draws a MotionSvgData with per-part animation, the Godot counterpart of the
## SCF Remotion `<Logo>` component.
##
## The node's local space is output pixels: the logo's viewBox is scaled to
## `width` and its top-left corner sits at the node's origin, like an
## absolutely positioned <svg>.
##
## Per-part overrides are Dictionaries with any of these keys (Remotion `Part`):
##   tx, ty      translate, logo units
##   s, sx, sy   scale about the pivot
##   rot         rotation in degrees about the pivot
##   pivot       Vector2 in logo units (default: the part's bbox centre)
##   o           opacity 0..1
##   fill        Color, replaces a single-colour part's colour (parts with both
##               fill and stroke, or a gradient, are tinted by it instead)
##   stroke      Color of the outline (drawn over the fill)
##   stroke_width  outline width in screen pixels (non-scaling)
##   draw        0..1 of the outline drawn, as a self-drawing line
##   draw_width  width of that line in screen pixels (default 3)
##   fill_o      fill opacity while drawing (default 0)
##   hide        true to skip the part
##   blur        Vector2 Gaussian blur in logo units (SVG feGaussianBlur
##               stdDeviation "x y"), e.g. Vector2(26, 0) for a motion smear
##   blur_region Rect2 filter region as fractions of the part's bounds
##               (SVG filter x/y/width/height, e.g. Rect2(-0.5, -0.1, 2, 1.2));
##               the blur is cut off outside it. Keep it wider than the part:
##               ThorVG doesn't blur at all when the region is the bare bounds,
##               where a browser still would
@tool
@icon("res://addons/motion_kit/icons/svg.svg")
class_name MotionSvg
extends Node2D

@export var data: MotionSvgData:
	set(v):
		data = v
		_overrides.clear()
		queue_redraw()
## Rendered width in pixels; 0 means the viewBox width.
@export var width := 0.0:
	set(v):
		width = v
		queue_redraw()
## Render only these part indices (empty = all).
@export var only := PackedInt32Array():
	set(v):
		only = v
		queue_redraw()
## The region of the logo, in logo units, that maps to `width` (zero size =
## whole viewBox). Like an SVG viewBox with overflow visible: parts outside it
## still draw, so combine it with `only` or a clipping parent.
@export var crop := Rect2():
	set(v):
		crop = v
		queue_redraw()
## Stretch to exactly this height in pixels, ignoring aspect (0 = keep aspect).
@export var stretch_h := 0.0:
	set(v):
		stretch_h = v
		queue_redraw()
## Raster density multiplier. Raise it for parts that will be scaled up a lot.
@export_range(0.5, 4.0, 0.25) var oversample := 1.0
## Reproduce Chromium's self-drawing stroke exactly, for ports of Remotion pieces.
## In Chromium a dash over pathLength 1 with non-scaling-stroke is measured in
## screen pixels while the path is measured in logo units, so `draw` = 1 shows
## only 1 / (pixels per logo unit) of the outline. Off: `draw` is the true fraction.
@export var chromium_draw := false

## Called from _frame as part_fn.call(i, f) -> Dictionary (or null) for each part.
var part_fn: Callable

var _overrides := {}
var _blur_region := Rect2()   # fractions of the part bbox; zero size = unlimited

# Raster cache shared by every MotionSvg: "rid:part:bucket" -> ImageTexture
static var _cache := {}
static var _cache_bytes := {}
static var _cache_total := 0
## Raster cache budget in bytes, shared by every MotionSvg; least recently used
## rasters are dropped beyond it (they are rebuilt if needed again).
static var cache_budget := 256 * 1024 * 1024
# Outline cache: "rid:part:bucket" -> Array[PackedVector2Array]
static var _outlines := {}
static var _outline_lengths := {}

const MAX_TEX := 4096


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _frame(f: float) -> void:
	if part_fn.is_valid():
		apply(func(i: int) -> Variant: return part_fn.call(i, f))


## Set every part's override from fn(i) -> Dictionary (null or {} for none).
func apply(fn: Callable) -> void:
	_overrides.clear()
	if data:
		for i in data.parts.size():
			var d: Variant = fn.call(i)
			if d != null and not (d as Dictionary).is_empty():
				_overrides[i] = d
	queue_redraw()


func set_part(i: int, d: Dictionary) -> void:
	_overrides[i] = d
	queue_redraw()


func clear_parts() -> void:
	_overrides.clear()
	queue_redraw()


## Displayed size in pixels.
func get_size() -> Vector2:
	if not data:
		return Vector2.ZERO
	var vb := _vb()
	var kx := _kx()
	return Vector2(vb.size.x * kx, vb.size.y * (stretch_h / vb.size.y if stretch_h > 0.0 else kx))


## Logo units → this node's local pixels (ignores part overrides).
func logo_to_local(p: Vector2) -> Vector2:
	var vb := _vb()
	var kx := _kx()
	var ky := stretch_h / vb.size.y if stretch_h > 0.0 else kx
	return Vector2((p.x - vb.position.x) * kx, (p.y - vb.position.y) * ky)


## Pixels per logo unit along x.
func get_logo_scale() -> float:
	return _kx()


## Rasterize every part now at the current on-screen size, so playback never stalls.
func prewarm() -> void:
	if not data:
		return
	var dens := _screen_scale_xy() * _kx() * oversample
	for i in data.parts.size():
		_texture(i, Vector2i(_bucket(dens.x), _bucket(dens.y)))


static func clear_cache() -> void:
	_cache.clear()
	_cache_bytes.clear()
	_cache_total = 0
	_outlines.clear()
	_outline_lengths.clear()


# ------------------------------------------------------------------ drawing

func _vb() -> Rect2:
	return crop if crop.size.x > 0.0 else data.view_box


func _kx() -> float:
	var vb := _vb()
	return (width if width > 0.0 else vb.size.x) / vb.size.x


## Screen pixels per local unit, including the window's stretch (a 1080p-authored
## project shown at 4K rasterizes at 4K density).
func _screen_scale() -> float:
	var k := _screen_scale_xy()
	return maxf(k.x, k.y)


## The same per local axis: a node stretched 5x vertically needs 5x the
## raster density down, not across.
func _screen_scale_xy() -> Vector2:
	var s := get_global_transform_with_canvas().get_scale().abs()
	if is_inside_tree():
		var vs := get_viewport().get_final_transform().get_scale().abs()
		s *= maxf(vs.x, vs.y)
	return s


# Rasters are made for the on-screen scale at the last draw. Moving or scaling
# the node (or a parent) doesn't redraw it, so watch the global transform and
# redraw when the scale crosses into another density step.
var _drawn_bucket := Vector2i(-999, -999)


func _enter_tree() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and data:
		var k := _screen_scale_xy() * _kx()
		if Vector2i(_bucket(k.x), _bucket(k.y)) != _drawn_bucket:
			queue_redraw()


func _draw() -> void:
	if not data:
		return
	var vb := _vb()
	var kx := _kx()
	var ky := stretch_h / vb.size.y if stretch_h > 0.0 else kx
	var base := Transform2D(Vector2(kx, 0), Vector2(0, ky), Vector2(-vb.position.x * kx, -vb.position.y * ky))
	var screen_xy := _screen_scale_xy()
	var screen := maxf(screen_xy.x, screen_xy.y)
	_drawn_bucket = Vector2i(_bucket(screen_xy.x * kx), _bucket(screen_xy.y * kx))
	var px_per_unit := screen * maxf(kx, ky)
	var use_only := only.size() > 0

	for i in data.parts.size():
		if use_only and not only.has(i):
			continue
		var p: Dictionary = data.parts[i]
		var o: Dictionary = _overrides.get(i, {})
		if o.get("hide", false):
			continue
		var alpha := float(o.get("o", 1.0))
		if alpha <= 0.0:
			continue
		var bbox: Rect2 = p.bbox
		var pivot: Vector2 = o.get("pivot", bbox.get_center())
		var s := float(o.get("s", 1.0))
		var sx := float(o.get("sx", 1.0)) * s
		var sy := float(o.get("sy", 1.0)) * s
		if absf(sx) < 1e-6 or absf(sy) < 1e-6:
			continue
		var xf := base * Transform2D(0.0, Vector2(float(o.get("tx", 0.0)), float(o.get("ty", 0.0))) + pivot) \
			* Transform2D(deg_to_rad(float(o.get("rot", 0.0))), Vector2.ZERO) \
			* Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO) \
			* Transform2D(0.0, -pivot)
		draw_set_transform_matrix(xf)

		var part_scale := maxf(absf(sx), absf(sy))
		# Raster density per axis of the part (a rotated part takes the larger for both).
		var dens := Vector2(screen_xy.x * kx * maxf(1.0, absf(sx)), screen_xy.y * ky * maxf(1.0, absf(sy))) * oversample
		if o.has("rot") and fmod(absf(float(o.rot)), 180.0) > 0.01:
			dens = Vector2.ONE * maxf(dens.x, dens.y)
		var pblur: Vector2 = o.get("blur", Vector2.ZERO)
		# Never ask for a raster wider than the texture limit: clamp density, not size
		# (the padding for a blur's three sigma either side counts too).
		dens.x = minf(dens.x, (MAX_TEX - 8) / maxf(1e-3, bbox.size.x + 6.0 * pblur.x + p.stroke_width))
		dens.y = minf(dens.y, (MAX_TEX - 8) / maxf(1e-3, bbox.size.y + 6.0 * pblur.y + p.stroke_width))
		var bucket := Vector2i(_bucket(dens.x), _bucket(dens.y))
		pblur = _snap_blur(pblur, Vector2(_bucket_density(bucket.x), _bucket_density(bucket.y)))
		var obucket := maxi(bucket.x, bucket.y)   # outlines: one tolerance for both axes
		var drawing := o.has("draw")
		var own_colour := _own_colour(p)

		# Fill
		var fill_alpha := alpha * (float(o.get("fill_o", 0.0)) if drawing else 1.0)
		if fill_alpha > 0.0:
			var col: Color = Color.WHITE if own_colour else o.get("fill", _base_colour(p))
			if own_colour and o.has("fill"):
				col = o.fill
			col.a *= fill_alpha
			_blur_region = o.get("blur_region", Rect2())
			var tex := _texture(i, bucket, pblur)
			if tex:
				draw_texture_rect(tex, _raster_rect(p, bucket, pblur), false, col)

		# Outline: self-drawing line, or a full stroke override
		var unit_px := px_per_unit * part_scale   # screen pixels per logo unit for this part
		if drawing or o.has("stroke"):
			var amount := maxf(0.0, float(o.get("draw", 1.0)))
			var w_px := float(o.get("draw_width", 3.0)) if drawing else float(o.get("stroke_width", 1.0))
			var scol: Color = o.get("stroke", o.get("fill", _base_colour(p)))
			scol.a *= alpha
			if amount > 0.0:
				if chromium_draw:
					# Dash `draw`, gap 2, both scaled into screen pixels: see chromium_draw.
					_draw_outline(i, obucket, amount / unit_px, 2.0 / unit_px, w_px / unit_px, scol)
				else:
					_draw_outline(i, obucket, amount, INF, w_px / unit_px, scol)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _base_colour(p: Dictionary) -> Color:
	var f: Color = p.fill
	return f if f.a > 0.0 else p.stroke


func _own_colour(p: Dictionary) -> bool:
	var f: Color = p.fill
	var s: Color = p.stroke
	return p.gradient or (f.a > 0.0 and s.a > 0.0)


## Strokes a part's outline with a dash pattern given as fractions of the whole
## path's length: `dash` drawn, then `gap` skipped, repeating, restarting on
## every subpath (as Chromium does). A gap of INF draws `dash` once from each
## subpath's start, so all contours, a letter's edge and its counters, draw together.
func _draw_outline(i: int, bucket: int, dash: float, gap: float, w: float, col: Color) -> void:
	var lines := _outline(i, bucket)
	var lengths: PackedFloat64Array = _outline_lengths[_key(i, bucket)]
	var total := 0.0
	for l in lengths:
		total += l
	var on := total * dash
	var period := on + total * gap
	if on <= 0.0:
		return
	var r := w * 0.5
	for c in lines.size():
		var line: PackedVector2Array = lines[c]
		var a := 0.0
		while a < lengths[c]:
			var pts := _sub(line, a, minf(a + on, lengths[c]))
			if pts.size() >= 2:
				draw_polyline(pts, col, w, true)
				# Round caps, and round joins where the direction turns sharply.
				draw_circle(pts[0], r, col, true, -1.0, true)
				draw_circle(pts[pts.size() - 1], r, col, true, -1.0, true)
				for k in range(1, pts.size() - 1):
					var u := (pts[k] - pts[k - 1])
					var v := (pts[k + 1] - pts[k])
					if u.length_squared() > 0.0 and v.length_squared() > 0.0 and u.normalized().dot(v.normalized()) < 0.9:
						draw_circle(pts[k], r, col, true, -1.0, true)
			if is_inf(period) or period <= 0.0:
				break
			a += period


## The piece of a polyline between arc lengths a and b.
static func _sub(line: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pos := 0.0
	for k in range(1, line.size()):
		var p0 := line[k - 1]
		var p1 := line[k]
		var seg := p0.distance_to(p1)
		var end := pos + seg
		if end >= a and pos <= b and seg > 0.0:
			if out.is_empty():
				out.append(p0.lerp(p1, clampf((a - pos) / seg, 0.0, 1.0)))
			if end >= b:
				out.append(p0.lerp(p1, clampf((b - pos) / seg, 0.0, 1.0)))
				return out
			out.append(p1)
		pos = end
		if pos > b:
			break
	return out


# ------------------------------------------------------------------ caches

## Raster densities step by √2, so a part is re-rasterized only when its
## on-screen size changes by more than that.
static func _bucket(dens: float) -> int:
	return int(ceil(log(maxf(dens, 0.01)) / log(sqrt(2.0))))


## An animated blur would re-rasterize the part on every frame. Snap it to
## steps the eye can't tell apart: quarter pixels below 4 px, then 1/16 of an
## octave (4%), so a smear animates through a few dozen cached rasters.
static func _snap_blur(b: Vector2, dens: Vector2) -> Vector2:
	var out := Vector2.ZERO
	for k in 2:
		var px := b[k] * dens[k]
		if px <= 0.0:
			continue
		px = roundf(px * 4.0) / 4.0 if px < 4.0 else pow(2.0, roundf(log(px) / log(2.0) * 16.0) / 16.0)
		out[k] = px / dens[k]
	return out


static func _bucket_density(b: int) -> float:
	return pow(sqrt(2.0), b)


func _key(i: int, bucket: Variant, blur := Vector2.ZERO) -> String:
	if blur == Vector2.ZERO:
		return "%d:%d:%s" % [data.get_instance_id(), i, bucket]
	return "%d:%d:%s:%s:%s:%s" % [data.get_instance_id(), i, bucket, blur.x, blur.y, _blur_region]


func _outline(i: int, bucket: int) -> Array:
	var key := _key(i, bucket)
	if not _outlines.has(key):
		# A quarter of a pixel from the true curve at this density.
		var lines := data.outline(i, 0.25 / _bucket_density(bucket))
		var lens := PackedFloat64Array()
		for l in lines:
			var t := 0.0
			for k in range(1, l.size()):
				t += l[k - 1].distance_to(l[k])
			lens.append(t)
		_outlines[key] = lines
		_outline_lengths[key] = lens
	return _outlines[key]


## The rectangle a part's raster covers, in logo units: its bounds plus two
## pixels of padding, widened to a whole number of texels on each axis.
static func _raster_rect(p: Dictionary, bucket: Vector2i, blur := Vector2.ZERO) -> Rect2:
	var dens := Vector2(_bucket_density(bucket.x), _bucket_density(bucket.y))
	var sw := float(p.stroke_width) * 0.5
	var r: Rect2 = (p.bbox as Rect2).grow_individual(2.0 / dens.x + sw, 2.0 / dens.y + sw, 2.0 / dens.x + sw, 2.0 / dens.y + sw)
	r = r.grow_individual(blur.x * 3.0, blur.y * 3.0, blur.x * 3.0, blur.y * 3.0)   # room for the blur
	var w := minf(ceilf(r.size.x * dens.x), MAX_TEX)
	var h := minf(ceilf(r.size.y * dens.y), MAX_TEX)
	return Rect2(r.position, Vector2(w / dens.x, h / dens.y))


func _texture(i: int, bucket: Vector2i, blur := Vector2.ZERO) -> Texture2D:
	var key := _key(i, bucket, blur)
	if _cache.has(key):
		# Refresh its place in the LRU order (Dictionaries keep insertion order).
		var hit: Texture2D = _cache[key]
		_cache.erase(key)
		_cache[key] = hit
		return hit
	var p: Dictionary = data.parts[i]
	var r := _raster_rect(p, bucket, blur)
	var w := clampi(int(round(r.size.x * _bucket_density(bucket.x))), 1, MAX_TEX)
	var h := clampi(int(round(r.size.y * _bucket_density(bucket.y))), 1, MAX_TEX)
	var body: String = p.svg
	if not _own_colour(p):
		var f: Color = p.fill
		if f.a > 0.0:
			body = body.replace("/>", " fill=\"#ffffff\"/>")
		else:
			body = body.replace("/>", " fill=\"none\" stroke=\"#ffffff\" stroke-width=\"%s\"/>" % str(p.stroke_width))
	else:
		var f: Color = p.fill
		var s: Color = p.stroke
		if not p.gradient:
			body = body.replace("/>", " fill=\"#%s\" fill-opacity=\"%s\" stroke=\"#%s\" stroke-opacity=\"%s\" stroke-width=\"%s\"/>" % [
				f.to_html(false), str(f.a), s.to_html(false), str(s.a), str(p.stroke_width)])
	var defs := data.defs
	if blur != Vector2.ZERO:
		var fr := r
		if _blur_region.size != Vector2.ZERO:
			var bb: Rect2 = p.bbox
			fr = Rect2(bb.position + bb.size * _blur_region.position, bb.size * _blur_region.size).intersection(r)
		defs += "<filter id=\"mkblur\" filterUnits=\"userSpaceOnUse\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\"><feGaussianBlur stdDeviation=\"%s %s\"/></filter>" % [
			str(fr.position.x), str(fr.position.y), str(fr.size.x), str(fr.size.y), str(blur.x), str(blur.y)]
		body = "<g filter=\"url(#mkblur)\">%s</g>" % body
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"%s %s %s %s\" width=\"%d\" height=\"%d\" preserveAspectRatio=\"none\"><defs>%s</defs>%s</svg>" % [
		str(r.position.x), str(r.position.y), str(r.size.x), str(r.size.y), w, h, defs, body]
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK:
		push_warning("MotionSvg: could not rasterize part %d of %s" % [i, data.source])
		_cache[key] = null
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	var bytes := int(w * h * 4 * 1.34)
	_cache_bytes[key] = bytes
	_cache_total += bytes
	while _cache_total > cache_budget and _cache.size() > 1:
		var oldest: String = _cache.keys()[0]
		_cache_total -= int(_cache_bytes.get(oldest, 0))
		_cache.erase(oldest)
		_cache_bytes.erase(oldest)
	return tex
