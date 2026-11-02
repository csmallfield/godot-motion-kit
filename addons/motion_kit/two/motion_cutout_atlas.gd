# SPDX-License-Identifier: Apache-2.0
## Cutout characters for 2D, baked: every rig part of one or more SVG views
## rasterized once, with its outline baked into the texture, and packed into
## one texture. MotionCutoutRig2D draws a character as one Sprite2D per
## layer, all from this texture with one shared material, so a crowd of
## characters baked into the same atlas can batch into a few draw calls.
##
## Same authoring convention as MotionCutoutRig (3D): a rig part is a
## `<g id="name">` holding a pivot marker (an element whose id starts with
## "pivot"), parts nest as their groups nest, document order is draw order,
## class "flat" gets no outline.
##
##   var atlas := MotionCutoutAtlas.new()
##   var s := 34.0 / 330.0 * 2.0                    # 34 px tall on screen, baked at 2x
##   atlas.add_view(&"hero/front", front, s, {origin = Vector2(110, 318)})
##   atlas.add_view(&"hero/side_left", side.mirrored(110), s, {origin = Vector2(110, 318)})
##   var map := MotionCutoutAtlas.hue_map(front, Color("#4fa86c"), Color(0.35, 0.8, 0.3))
##   atlas.add_view(&"goblin/front", front, s, {origin = Vector2(110, 318), recolor = map, hide = ["scarf"]})
##   atlas.add_card(&"sword", sword, s, Vector2(20, 136))
##   atlas.bake()
##
## Recolouring happens at bake time (`recolor`: fill hex -> Color), so a
## colour-shifted variant costs nothing at runtime and keeps its outlines and
## whites, which a modulate tint would darken. hue_map() builds such a map.
##
## A part whose own shapes are split by a child part in document order (a
## head with eyes in the middle of it) bakes as several layers on the same
## pivot, so the draw order matches the drawing.
##
## Bake scale: rig-local pixels are baked pixels. Draw the rig at
## 1 / `bake_scale` (MotionCutoutRig2D.display_scale) when baking above
## screen size (2x for a 960x540 game shown at 1080p with canvas_items stretch).
@tool
class_name MotionCutoutAtlas
extends RefCounted

const SHADER := preload("res://addons/motion_kit/two/motion_cutout_2d.gdshader")

## The packed texture (after bake()).
var texture: ImageTexture
## Key -> view:
##   names: Array[StringName]      rig parts, parents first (&"" is the root)
##   parent: {name: parent name}
##   pivot: {name: Vector2}       rest pivot, rig-local px (origin at `origin`, y down)
##   layers: Array of {part: StringName, region: Rect2, offset: Vector2}, in draw order;
##           offset = the raster's top-left relative to the part's pivot, px
##   scale: float                 baked px per SVG unit
var views := {}
## Seconds the last bake() took.
var bake_seconds := 0.0

var _pending := []          # [{key, runs: [{part, svg, offset}]}]
var _packed := {}           # layers baked earlier, kept for re-packing
static var _material: ShaderMaterial


## The material every rig drawn from any atlas shares: per-character tint and
## hit flash come through the CanvasItem's modulate (see MotionCutoutRig2D.set_look).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## Add a rigged view at `scale` px per SVG unit. Options:
##   origin       SVG point at the rig's origin (default: bottom centre of the viewBox)
##   outline      outline width in baked px (1.6)
##   ink          outline colour (#1b1622)
##   recolor      {fill hex (lowercase, no #) or Color: Color}
##   hide         element ids, classes or group ids left out (["scarf"])
##   pad          px of transparent border per layer (2)
##   pivot_prefix ("pivot"), flat_class ("flat"), overrides ({part: {pivot, parent}})
func add_view(key: StringName, data: MotionSvgData, scale: float, opts := {}) -> void:
	var vb := data.view_box
	var origin: Vector2 = opts.get("origin", Vector2(vb.position.x + vb.size.x * 0.5, vb.end.y))
	var prefix: String = opts.get("pivot_prefix", "pivot")
	var flat_class: String = opts.get("flat_class", "flat")
	var overrides: Dictionary = opts.get("overrides", {})
	var hide := PackedStringArray(opts.get("hide", []))

	# rig parts and their pivots
	var is_part := {}
	var pivot_svg := {&"": origin}
	for i in data.parts.size():
		var p: Dictionary = data.parts[i]
		var gs: PackedStringArray = p.groups
		if String(p.id).begins_with(prefix) and not gs.is_empty():
			var n := gs[gs.size() - 1]
			is_part[n] = true
			pivot_svg[StringName(n)] = data.centre(i)
	for n in overrides:
		is_part[String(n)] = true
		if (overrides[n] as Dictionary).has("pivot"):
			pivot_svg[StringName(n)] = overrides[n].pivot

	# hierarchy and element ownership, as runs of consecutive elements per part
	var parent := {}
	var runs := []          # [{part, idx: []}]
	for i in data.parts.size():
		var p: Dictionary = data.parts[i]
		var chain: Array[StringName] = []
		for g in (p.groups as PackedStringArray):
			if is_part.has(g):
				chain.append(StringName(g))
		for c in chain.size():
			if not parent.has(chain[c]):
				parent[chain[c]] = chain[c - 1] if c > 0 else &""
		if String(p.id).begins_with(prefix) or (p.fill as Color).a <= 0.0 or _hidden(p, hide):
			continue
		var owner: StringName = chain[chain.size() - 1] if not chain.is_empty() else &""
		if runs.is_empty() or runs[runs.size() - 1].part != owner:
			runs.append({part = owner, idx = []})
		(runs[runs.size() - 1].idx as Array).append(i)
	for n in overrides:
		var o: Dictionary = overrides[n]
		if o.has("parent"):
			parent[StringName(n)] = StringName(o.parent)
		elif not parent.has(StringName(n)):
			parent[StringName(n)] = &""

	var view := {names = _ordered(parent), parent = parent, pivot = {}, layers = [], scale = scale}
	for n: StringName in pivot_svg:
		view.pivot[n] = (pivot_svg[n] - origin) * scale
	var baked := []
	for r in runs:
		baked.append(_raster_job(data, r.idx, scale, pivot_svg.get(r.part, origin), opts, flat_class))
		baked[baked.size() - 1]["part"] = r.part
	views[key] = view
	_pending.append({key = key, runs = baked})


## Add a prop drawn in one piece (a sword, a club, a shadow): a view with a
## single root part pivoting at `anchor` (SVG units). Same options as add_view.
func add_card(key: StringName, data: MotionSvgData, scale: float, anchor: Vector2, opts := {}) -> void:
	var idx := []
	var hide := PackedStringArray(opts.get("hide", []))
	for i in data.parts.size():
		var p: Dictionary = data.parts[i]
		if (p.fill as Color).a > 0.0 and not _hidden(p, hide):
			idx.append(i)
	var job := _raster_job(data, idx, scale, anchor, opts, String(opts.get("flat_class", "flat")))
	job["part"] = &""
	views[key] = {names = [&""], parent = {}, pivot = {&"": Vector2.ZERO}, layers = [], scale = scale}
	_pending.append({key = key, runs = [job]})


## Rasterize everything added since the last bake and pack it into `texture`
## (a fresh texture holding every view; re-baking re-rasterizes nothing old,
## but call it once after adding everything: each bake re-packs).
func bake(max_width := 2048) -> ImageTexture:
	var t0 := Time.get_ticks_usec()
	var items := []        # [{key, layer index, image}]
	for job in _pending:
		var view: Dictionary = views[job.key]
		for r in job.runs:
			var img := Image.new()
			if img.load_svg_from_string(r.svg, 1.0) != OK or img.is_empty():
				push_warning("MotionCutoutAtlas: could not rasterize a layer of %s" % job.key)
				continue
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			# ThorVG leaves transparent texels black: bleed edge colours outward
			# so linear filtering doesn't fringe the outline.
			img.fix_alpha_edges()
			view.layers.append({part = r.part, region = Rect2(), offset = r.offset})
			items.append({key = job.key, i = view.layers.size() - 1, img = img})
	_pending.clear()
	for k in _packed:
		items.append(_packed[k])
	# shelf pack, tallest first
	items.sort_custom(func(a, b) -> bool: return a.img.get_height() > b.img.get_height())
	var area := 0
	var widest := 1
	for it in items:
		area += (it.img.get_width() + 2) * (it.img.get_height() + 2)
		widest = maxi(widest, it.img.get_width() + 2)
	var w := clampi(nearest_po2(int(sqrt(float(area)) * 1.15)), nearest_po2(widest), max_width)
	var x := 0
	var y := 0
	var shelf := 0
	for it in items:
		var iw: int = it.img.get_width()
		var ih: int = it.img.get_height()
		if x + iw + 2 > w:
			x = 0
			y += shelf
			shelf = 0
		it["at"] = Vector2i(x + 1, y + 1)
		x += iw + 2
		shelf = maxi(shelf, ih + 2)
	var h := maxi(nearest_po2(y + shelf), 4)
	var atlas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for it in items:
		var img: Image = it.img
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), it.at)
		(views[it.key].layers[it.i] as Dictionary).region = Rect2(it.at, img.get_size())
		_packed["%s#%d" % [it.key, it.i]] = it
	texture = ImageTexture.create_from_image(atlas)
	bake_seconds = (Time.get_ticks_usec() - t0) / 1e6
	return texture



func has_view(key: StringName) -> bool:
	return views.has(key)


func layer_count(key: StringName) -> int:
	return (views[key].layers as Array).size()


## A recolour map for add_view(): every fill of `data` turned in hue by the
## turn that takes `from` to `to`, and its saturation and value scaled the
## same way. Near-greys and near-blacks (whites, eyes, inks) and `keep` (hex strings)
## stay as drawn. `amount` 0..1 blends from the drawing toward the full shift.
static func hue_map(data: MotionSvgData, from: Color, to: Color, keep := PackedStringArray(), amount := 1.0) -> Dictionary:
	var out := {}
	var dh := to.h - from.h
	var ks := to.s / maxf(from.s, 0.001)
	var kv := to.v / maxf(from.v, 0.001)
	for p in data.parts:
		var c: Color = p.fill
		if c.a <= 0.0:
			continue
		var hex := c.to_html(false)
		if out.has(hex) or keep.has(hex) or c.s < 0.12 or c.v < 0.2:
			continue
		var n := Color.from_hsv(fposmod(c.h + dh, 1.0), clampf(c.s * ks, 0.0, 1.0), clampf(c.v * kv, 0.0, 1.0), c.a)
		out[hex] = c.lerp(n, amount)
	return out


# ------------------------------------------------------------------ internals

static func _hidden(p: Dictionary, hide: PackedStringArray) -> bool:
	if hide.is_empty():
		return false
	if hide.has(String(p.id)):
		return true
	for c in (p.classes as PackedStringArray):
		if hide.has(c):
			return true
	for g in (p.groups as PackedStringArray):
		if hide.has(g):
			return true
	return false


## One layer's SVG source, its pixel size and where it sits from its pivot.
static func _raster_job(data: MotionSvgData, idx: Array, scale: float, pivot_svg: Vector2, opts: Dictionary, flat_class: String) -> Dictionary:
	var outline_px: float = opts.get("outline", 1.6)
	var ink: Color = opts.get("ink", Color("#1b1622"))
	var recolor: Dictionary = opts.get("recolor", {})
	var pad_px: float = opts.get("pad", 2.0)
	var ow := outline_px / scale                 # outline width in SVG units
	var rect := Rect2()
	var body := PackedStringArray()
	for n in idx.size():
		var p: Dictionary = data.parts[int(idx[n])]
		var sw := float(p.stroke_width) * 0.5 if (p.stroke as Color).a > 0.0 else 0.0
		var outlined := not (p.classes as PackedStringArray).has(flat_class)
		var b: Rect2 = (p.bbox as Rect2).grow(sw + (ow if outlined else 0.0))
		rect = b if n == 0 else rect.merge(b)
		var rule := ' fill-rule="evenodd"' if p.fill_rule == "evenodd" else ""
		if outlined:
			body.append(_with(p.svg, ' fill="#%s" stroke="#%s" stroke-width="%s" stroke-linejoin="round"%s' % [
				ink.to_html(false), ink.to_html(false), str(ow * 2.0 + sw * 2.0), rule]))
		if p.gradient:
			body.append(p.svg)
		else:
			var f: Color = _recolor(p.fill, recolor)
			var s: Color = _recolor(p.stroke, recolor)
			body.append(_with(p.svg, ' fill="#%s" fill-opacity="%s" stroke="#%s" stroke-opacity="%s" stroke-width="%s"%s' % [
				f.to_html(false), str(f.a), s.to_html(false), str(s.a), str(p.stroke_width), rule]))
	rect = rect.grow(pad_px / scale)
	var w := maxi(int(ceil(rect.size.x * scale)), 1)
	var h := maxi(int(ceil(rect.size.y * scale)), 1)
	rect.size = Vector2(w, h) / scale             # whole pixels
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%d" height="%d" preserveAspectRatio="none"><defs>%s</defs>%s</svg>' % [
		str(rect.position.x), str(rect.position.y), str(rect.size.x), str(rect.size.y), w, h, data.defs, "".join(body)]
	return {svg = svg, offset = (rect.position - pivot_svg) * scale}


static func _with(el: String, attrs: String) -> String:
	var at := el.rfind("/>")
	return el.substr(0, at) + attrs + el.substr(at) if at >= 0 else el


static func _recolor(c: Color, map: Dictionary) -> Color:
	if map.is_empty() or c.a <= 0.0:
		return c
	var hex := c.to_html(false)
	if map.has(hex):
		var n: Color = map[hex]
		return Color(n.r, n.g, n.b, c.a)
	if map.has(c):
		return map[c]
	return c


## Part names, parents before children, root first.
static func _ordered(parent: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = [&""]
	var seen := {&"": true}
	var visit := func(n: StringName, me: Callable) -> void:
		if seen.has(n):
			return
		var p: StringName = parent.get(n, &"")
		me.call(p, me)
		seen[n] = true
		out.append(n)
	for n: StringName in parent:
		visit.call(n, visit)
	return out
