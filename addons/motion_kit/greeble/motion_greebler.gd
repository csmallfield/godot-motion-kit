# SPDX-License-Identifier: Apache-2.0
## Procedural hard-surface detail ("greebles") with a level-of-detail reveal.
##
## Give it shapes (polygons, rectangles, or a logo's contours from MotionSvgData)
## and it subdivides them, seeded, into panels (raised or recessed, with bevels
## and seams) down to `max_level`, and fills leaf panels with greebles from a
## small library: vents, grilles, bolts, pipes, lamps, fans, hazard stripes,
## stencil numbers, boxes, slots and chevrons. Everything is built once.
##
## Drawing is immediate-mode into any CanvasItem (a MotionCanvas draw_fn), in
## screen space through a scale + origin camera, so stencil text stays sharp at
## any zoom. Each item fades in by its size ON SCREEN: push the camera in and
## the secondary panels, then the tertiary greebles, resolve out of the bold
## shapes; pull out and the shapes read clean again. `reveal` (per level) and
## `reveal_front` (a growing radius) add time-based reveals on top.
##
## Frame-pure: the structure is static; draw() reads only its arguments, the
## public controls and the frame (for lamps and fans), so seeking works.
@tool
class_name MotionGreebler
extends RefCounted

enum Kind { BLOCK, SIDES, PANEL, VENT, GRILLE, BOLTS, PIPE, LIGHT, FAN, HAZARD, STENCIL, BOXES, SLOT, CHEVRON }

# ---------------------------------------------------------------- generation
## Deepest panel level (level 0 is the base shape).
var max_level := 4
## No panel is split below twice this (world units).
var min_size := 3.0
## Chance a panel at each level is split again.
var split_chance: PackedFloat32Array = PackedFloat32Array([1.0, 0.95, 0.85, 0.7, 0.55, 0.4, 0.3])
## Chance a split is an inset frame instead of a cut.
var inset_chance := 0.25
## Chance a panel is raised (else recessed).
var raise_chance := 0.6
## Chance a leaf panel gets a greeble.
var greeble_chance := 0.85
## Chance a panel at levels 1..rest_levels stays a plain plate (no split, no
## greeble): areas of rest between the busy parts, so bold shapes read.
var rest_chance := 0.3
var rest_levels := 2
## Texts for STENCIL greebles.
var stencils: PackedStringArray = PackedStringArray(["07", "A-12", "FX9", "03", "R-4", "9000", "B2", "7G", "11", "S-07", "K45", "T23"])

# ---------------------------------------------------------------- look
var face := Color("#ebe7dc")
var tone_jitter := 0.05
var bevel_light := Color("#fdfcf7")
var bevel_shade := Color("#a3b1bc")
var recess := Color("#8a7b68")
var recess_deep := Color("#2a231c")
var seam := Color("#6f6a62")
var side_lit := Color("#b4c0c9")
var side_dark := Color("#66778a")
var pipe := Color("#c9ccc9")
var accent := Color("#ff6a13")
var accent2 := Color("#e92067")
var ink := Color("#2b2723")
var lamp := Color("#fff0c4")
var lamp_alt := Color("#7fe3ff")
var lamp_off := Color("#4a4038")
## Direction the extruded sides are seen in (light comes from the opposite side).
var extrude_dir := Vector2(0.42, 1.0).normalized()
## Font for stencils (sharp at any zoom: drawn at its on-screen size).
var font: Font

# ---------------------------------------------------------------- draw controls
## On-screen size (px) at which an item starts to appear...
var lod_px := 4.0
## ...and the multiple of it at which it is fully in.
var lod_band := 2.5
var haze_color := Color.WHITE
var haze := 0.0
## Per-level reveal multiplier (index = level).
var reveal: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1, 1, 1, 1])
## A radius (world units) growing from `reveal_origin`: detail inside it shows.
var reveal_origin := Vector2.ZERO
var reveal_front := INF
var reveal_soft := 300.0
## Lamp brightness (0 cuts every lamp) and blink period in frames.
var lamp_level := 1.0
var lamp_period := 24.0
## Items drawn by the last draw() (for profiling).
var stats_drawn := 0

var _structures: Array[Dictionary] = []


# ================================================================ building

## A new empty structure; returns its id. `opts` may override colours for it:
## face, side_lit, side_dark, haze (added to the global haze), and `lod` (a
## multiplier on lod_px: above 1 keeps this structure clean until closer).
func new_structure(opts := {}) -> int:
	_structures.append({items = [], bbox = Rect2(), offset = Vector2.ZERO, visible = true, alpha = 1.0,
		opts = opts, cum = PackedFloat32Array(), dirty = true})
	return _structures.size() - 1


## An extruded polygon (bold shape) with panels and greebles inside it.
## `opts`: seed, max_level, min_size, greeble_chance, first_level (1), avoid
## (Array of contours kept clear), plus the colour overrides of new_structure.
func add_block(poly: PackedVector2Array, depth: float, opts := {}) -> int:
	var id := new_structure(opts)
	var contours: Array = [poly]
	_add_item(id, {k = Kind.BLOCK, l = 0, r = _bounds(contours), sz = 1e9, d = depth,
		poly = poly, edges = _edges(contours), sd = float(opts.get("seed", 1.0))})
	if int(opts.get("max_level", max_level)) > 0:
		_detail(id, contours, opts)
	return id


## A rectangle block (add_block with optional chamfered corners, in world units).
func add_rect(r: Rect2, depth: float, chamfer := 0.0, opts := {}) -> int:
	return add_block(chamfered(r, chamfer), depth, opts)


## Only the extruded sides of a shape (its face is drawn by something else, e.g.
## a MotionSvg). Contours may include holes (even-odd). Add `detail = true` to
## also subdivide its face.
func add_sides(contours: Array, depth: float, opts := {}) -> int:
	var id := new_structure(opts)
	_add_item(id, {k = Kind.SIDES, l = 0, r = _bounds(contours), sz = 1e9, d = depth,
		edges = _edges(contours), sd = float(opts.get("seed", 1.0))})
	if opts.get("detail", false):
		_detail(id, contours, opts)
	return id


## Panels and greebles inside a shape (even-odd contours), without a base.
func add_detail(contours: Array, opts := {}) -> int:
	var id := new_structure(opts)
	_detail(id, contours, opts)
	return id


## One hand-placed item (kind, world rect, level) in an existing structure.
func add_item(id: int, kind: int, r: Rect2, level := 1, extra := {}) -> void:
	var it := {k = kind, l = level, r = r, sz = minf(r.size.x, r.size.y) * _lod_k(kind),
		d = 2.0, t = 0.0, sd = float(extra.get("seed", r.position.x * 0.013 + r.position.y * 0.007))}
	it.merge(extra, true)
	_prep_greeble(it)
	_add_item(id, it)


func set_offset(id: int, off: Vector2) -> void:
	_structures[id].offset = off


func set_visible(id: int, on: bool) -> void:
	_structures[id].visible = on


func set_alpha(id: int, a: float) -> void:
	_structures[id].alpha = a


func structure_count() -> int:
	return _structures.size()


func item_count() -> int:
	var n := 0
	for st in _structures:
		n += (st.items as Array).size()
	return n


## A rectangle with its four corners cut at 45 degrees.
## Deprecated: use MotionPoly.chamfered_rect.
static func chamfered(r: Rect2, c: float) -> PackedVector2Array:
	return MotionPoly.chamfered_rect(r, c)


func _add_item(id: int, it: Dictionary) -> void:
	var st: Dictionary = _structures[id]
	(st.items as Array).append(it)
	var r: Rect2 = it.r
	st.bbox = r if (st.items as Array).size() == 1 else (st.bbox as Rect2).merge(r)
	st.dirty = true


func _finish(st: Dictionary) -> void:
	var items: Array = st.items
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.l) < int(b.l))
	var top := 0
	for it in items:
		top = maxi(top, int(it.l))
	var mx := PackedFloat32Array()
	mx.resize(top + 1)
	for it in items:
		var l: int = it.l
		mx[l] = maxf(mx[l], float(it.sz))
	var cum := PackedFloat32Array()
	cum.resize(top + 1)
	var run := 0.0
	for l in range(top, -1, -1):
		run = maxf(run, mx[l])
		cum[l] = run
	st.cum = cum
	st.dirty = false


# ---------------------------------------------------------------- subdivision

func _detail(id: int, contours: Array, opts: Dictionary) -> void:
	var g := {
		contours = _prep_contours(contours),
		avoid = _prep_contours(opts.get("avoid", [])),
		margin = float(opts.get("margin", 0.0)),
		max_level = int(opts.get("max_level", max_level)),
		min_size = float(opts.get("min_size", min_size)),
		greeble = float(opts.get("greeble_chance", greeble_chance)),
		raise = float(opts.get("raise_chance", raise_chance)),
		depth_k = float(opts.get("depth_k", 1.0)),
		rest = float(opts.get("rest_chance", rest_chance)),
		first = int(opts.get("first_level", 1)),
		id = id,
	}
	var b := _bounds(contours)
	_sub(g, b, int(g.first), float(opts.get("seed", 1.0)) * 7.31 + 0.5, false, 0)


func _sub(g: Dictionary, r: Rect2, level: int, sd: float, known_in: bool, partial: int) -> void:
	var ms: float = g.min_size
	var mn := minf(r.size.x, r.size.y)
	if mn <= 0.0:
		return
	if not known_in:
		var cls := _classify(r, g)
		if cls == 0:
			return
		if cls == 1:
			if mn < ms * 2.0 or partial > 12:
				return
			var horiz := r.size.x >= r.size.y
			var cut := 0.35 + 0.3 * MK.rand(sd + 0.9)
			var a: Rect2
			var b: Rect2
			if horiz:
				a = Rect2(r.position, Vector2(r.size.x * cut, r.size.y))
				b = Rect2(r.position.x + r.size.x * cut, r.position.y, r.size.x * (1.0 - cut), r.size.y)
			else:
				a = Rect2(r.position, Vector2(r.size.x, r.size.y * cut))
				b = Rect2(r.position.x, r.position.y + r.size.y * cut, r.size.x, r.size.y * (1.0 - cut))
			_sub(g, a, level, sd * 1.13 + 3.7, false, partial + 1)
			_sub(g, b, level, sd * 1.29 + 9.1, false, partial + 1)
			return
	# fully inside: a panel, then split, inset or leaf
	var raised := MK.rand(sd + 0.17) < float(g.raise)
	var d := clampf(mn * 0.045, 0.35, 7.0) * float(g.depth_k) * (1.0 if raised else -1.0)
	_add_item(int(g.id), {k = Kind.PANEL, l = level, r = r, sz = mn, d = d, t = MK.rand(sd + 0.53) * 2.0 - 1.0, sd = sd})
	if level <= rest_levels and MK.rand(sd + 0.43) < float(g.rest):
		return
	var sc := split_chance[mini(level, split_chance.size() - 1)]
	if level >= int(g.max_level) or mn < ms * 2.2 or MK.rand(sd + 0.31) > sc:
		_leaf(g, r, level, sd)
		return
	if MK.rand(sd + 0.77) < inset_chance and mn > ms * 5.0:
		var m := clampf(mn * 0.12, ms * 0.5, 40.0)
		_sub(g, r.grow(-m), level + 1, sd * 1.41 + 2.2, true, 0)
		if MK.rand(sd + 0.11) < 0.5:
			add_item(int(g.id), Kind.BOLTS, r.grow(-m * 0.3), level + 1, {seed = sd + 4.4})
		return
	var horiz2 := r.size.x >= r.size.y
	var n := 2 if MK.rand(sd + 0.61) < 0.65 else 3
	var gap := clampf(mn * 0.03, 0.25, 3.0)
	var length := r.size.x if horiz2 else r.size.y
	var cuts := PackedFloat32Array([0.0])
	for i in range(1, n):
		cuts.append(float(i) / n + (MK.rand(sd + i * 1.7) - 0.5) * 0.3 / n)
	cuts.append(1.0)
	for i in n:
		var p0 := cuts[i] * length + (gap * 0.5 if i > 0 else 0.0)
		var p1 := cuts[i + 1] * length - (gap * 0.5 if i < n - 1 else 0.0)
		var cr: Rect2
		if horiz2:
			cr = Rect2(r.position.x + p0, r.position.y, p1 - p0, r.size.y)
		else:
			cr = Rect2(r.position.x, r.position.y + p0, r.size.x, p1 - p0)
		_sub(g, cr, level + 1, sd * 1.7 + i * 5.3 + 1.1, true, 0)


func _leaf(g: Dictionary, r: Rect2, level: int, sd: float) -> void:
	if MK.rand(sd + 0.93) > float(g.greeble):
		return
	var mn := minf(r.size.x, r.size.y)
	var rr := r.grow(-clampf(mn * 0.12, 0.2, 8.0))
	if rr.size.x <= 0.0 or rr.size.y <= 0.0:
		return
	add_item(int(g.id), _pick_kind(rr, sd, float(g.min_size)), rr, level + 1, {seed = sd + 7.7})


func _pick_kind(r: Rect2, sd: float, ms: float) -> int:
	var lo := maxf(r.size.x, r.size.y)
	var sh := minf(r.size.x, r.size.y)
	var asp := lo / maxf(sh, 0.001)
	var u := MK.rand(sd + 5.5)
	if asp > 4.0:
		if u < 0.36: return Kind.PIPE
		if u < 0.68: return Kind.VENT
		if u < 0.82: return Kind.SLOT
		if u < 0.92: return Kind.CHEVRON
		return Kind.HAZARD
	if sh < ms * 2.5:
		return Kind.LIGHT if u < 0.55 else Kind.BOLTS
	var table := [[Kind.VENT, 0.17], [Kind.GRILLE, 0.11], [Kind.BOLTS, 0.12], [Kind.FAN, 0.1], [Kind.STENCIL, 0.13],
		[Kind.BOXES, 0.15], [Kind.LIGHT, 0.08], [Kind.HAZARD, 0.06], [Kind.SLOT, 0.08]]
	var acc := 0.0
	for e in table:
		acc += float(e[1])
		if u < acc:
			return int(e[0])
	return Kind.VENT


static func _lod_k(kind: int) -> float:
	match kind:
		Kind.VENT: return 0.55
		Kind.GRILLE: return 0.45
		Kind.BOLTS: return 0.35
		Kind.PIPE: return 0.8
		Kind.LIGHT: return 1.2
		Kind.FAN: return 0.6
		Kind.HAZARD: return 0.7
		Kind.STENCIL: return 0.8
		Kind.BOXES: return 0.6
		Kind.SLOT: return 0.6
		Kind.CHEVRON: return 0.6
	return 1.0


## Per-kind constants decided at build time, so counts don't pop while zooming.
func _prep_greeble(it: Dictionary) -> void:
	var r: Rect2 = it.r
	var sd: float = it.sd
	var sh := minf(r.size.x, r.size.y)
	var lo := maxf(r.size.x, r.size.y)
	match int(it.k):
		Kind.VENT:
			it.n = clampi(int(sh / maxf(min_size * 0.9, 0.5)), 2, 9)
		Kind.GRILLE:
			var cell := sh / (3.0 + floorf(MK.rand(sd + 1.1) * 4.0))
			it.nx = clampi(int(r.size.x / cell), 2, 14)
			it.ny = clampi(int(r.size.y / cell), 2, 14)
		Kind.PIPE:
			it.n = clampi(int(lo / sh * 0.6), 1, 8)
			it.c = pipe if MK.rand(sd + 0.4) < 0.7 else accent
		Kind.LIGHT:
			var u := MK.rand(sd + 2.3)
			it.c = lamp if u < 0.6 else (lamp_alt if u < 0.85 else accent2)
			it.per = [1.0, 2.0, 0.5, 4.0][int(MK.rand(sd + 3.1) * 4.0)]
			it.steady = MK.rand(sd + 3.9) < 0.3
		Kind.FAN:
			it.spin = (0.08 + 0.2 * MK.rand(sd + 1.9)) * (1.0 if MK.rand(sd + 2.9) < 0.5 else -1.0)
			it.blades = 3 + int(MK.rand(sd + 4.1) * 4.0)
		Kind.STENCIL:
			if not it.has("txt"):
				it.txt = stencils[int(MK.rand(sd + 0.7) * stencils.size()) % stencils.size()]
			if not it.has("c"):
				it.c = ink if MK.rand(sd + 1.3) < 0.7 else accent
		Kind.BOXES:
			var boxes := []
			var n := 2 + int(MK.rand(sd + 0.5) * 2.0)
			for i in n:
				var w := r.size.x * (0.3 + 0.4 * MK.rand(sd + i * 2.1))
				var h := r.size.y * (0.3 + 0.4 * MK.rand(sd + i * 3.7))
				var x := r.position.x + (r.size.x - w) * MK.rand(sd + i * 5.3)
				var y := r.position.y + (r.size.y - h) * MK.rand(sd + i * 7.9)
				boxes.append(Rect2(x, y, w, h))
			it.boxes = boxes
		Kind.SLOT:
			it.n = clampi(int(lo / sh * 0.5), 1, 4)
		Kind.CHEVRON:
			it.n = clampi(int(lo / sh * 1.3), 1, 10)
		Kind.HAZARD:
			it.n = clampi(int(lo / sh * 2.2), 1, 16)


func _prep_contours(contours: Array) -> Array:
	return MotionPoly.prepare(contours)


func _bounds(contours: Array) -> Rect2:
	return MotionPoly.bounds_all(contours)


static func _inside(p: Vector2, cs: Array) -> bool:
	return MotionPoly.contains_prepared(cs, p)


## 0 outside, 1 partial, 2 inside (and clear of `avoid`).
func _classify(r: Rect2, g: Dictionary) -> int:
	var cs: Array = g.contours
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center()]
	var ins := 0
	for p in pts:
		if _inside(p, cs):
			ins += 1
	var crossing := false
	for c in cs:
		if (c.bb as Rect2).intersects(r):
			for p in (c.pts as PackedVector2Array):
				if r.has_point(p):
					crossing = true
					break
		if crossing:
			break
	if ins == 0 and not crossing:
		return 0
	if ins < 5 or crossing:
		return 1
	var av: Array = g.avoid
	if not av.is_empty():
		var rg := r.grow(float(g.margin))
		var gp := [rg.position, Vector2(rg.end.x, rg.position.y), rg.end, Vector2(rg.position.x, rg.end.y), rg.get_center()]
		var hits := 0
		for p in gp:
			if _inside(p, av):
				hits += 1
		if hits == 5:
			return 0
		if hits > 0:
			return 1
		for c in av:
			if (c.bb as Rect2).intersects(rg):
				for p in (c.pts as PackedVector2Array):
					if rg.has_point(p):
						return 1
	return 2


## Edges with outward normals (even-odd), ordered far to near along extrude_dir.
func _edges(contours: Array) -> Array:
	var cs := _prep_contours(contours)
	var out := []
	for c in contours:
		var pts: PackedVector2Array = c
		var n := pts.size()
		if n < 3:
			continue
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if a.distance_squared_to(b) < 1e-8:
				continue
			var nn := (b - a).orthogonal().normalized()
			var m := (a + b) * 0.5
			var eps := clampf(a.distance_to(b) * 0.05, 0.02, 0.5)
			if _inside(m + nn * eps, cs):
				nn = -nn
			out.append([a, b, nn, m.dot(extrude_dir)])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[3]) < float(y[3]))
	return out


# ================================================================ drawing

## Draw every structure into `c` (screen = world * s + origin).
func draw(c: CanvasItem, s: float, origin: Vector2, f: float, view := Rect2(0, 0, 1920, 1080)) -> void:
	stats_drawn = 0
	var vr := view.grow(8.0)
	for st in _structures:
		if not st.visible or float(st.alpha) <= 0.0:
			continue
		if st.dirty:
			_finish(st)
		var off: Vector2 = st.offset
		var bb: Rect2 = st.bbox
		if not Rect2((bb.position + off) * s + origin, bb.size * s).grow(absf(s) * 80.0).intersects(vr):
			continue
		var o: Dictionary = st.opts
		var face_c: Color = o.get("face", face)
		var sl: Color = o.get("side_lit", side_lit)
		var sdk: Color = o.get("side_dark", side_dark)
		var hz := clampf(haze + float(o.get("haze", 0.0)), -1.0, 1.0)
		var lp := lod_px * float(o.get("lod", 1.0))
		var sa: float = st.alpha
		var cum: PackedFloat32Array = st.cum
		var lvl := -1
		for it in (st.items as Array):
			var l: int = it.l
			if l != lvl:
				lvl = l
				if l < cum.size() and cum[l] * s < lp:
					break
			var k: int = it.k
			var a := sa
			if l > 0:
				a *= clampf((float(it.sz) * s - lp) / (lp * (lod_band - 1.0)), 0.0, 1.0)
				if l < reveal.size():
					a *= reveal[l]
				if reveal_front < INF:
					var dd := ((it.r as Rect2).get_center() + off).distance_to(reveal_origin)
					a *= clampf((reveal_front - dd) / reveal_soft, 0.0, 1.0)
				if a <= 0.01:
					continue
			if k == Kind.BLOCK or k == Kind.SIDES:
				_draw_solid(c, it, s, origin + off * s, a, face_c, sl, sdk, hz, k == Kind.BLOCK)
				stats_drawn += 1
				continue
			var r: Rect2 = it.r
			var sr := Rect2((r.position + off) * s + origin, r.size * s)
			if not sr.intersects(vr) or sr.size.x < 0.7 or sr.size.y < 0.7:
				continue
			stats_drawn += 1
			match k:
				Kind.PANEL: _panel(c, sr, float(it.d) * s, float(it.t), a, face_c, hz)
				Kind.VENT: _vent(c, sr, it, a, hz)
				Kind.GRILLE: _grille(c, sr, it, a, hz)
				Kind.BOLTS: _bolts(c, sr, a, hz)
				Kind.PIPE: _pipe(c, sr, it, a, hz)
				Kind.LIGHT: _light(c, sr, it, a, f, hz)
				Kind.FAN: _fan(c, sr, it, a, f, hz)
				Kind.HAZARD: _hazard(c, sr, it, a, hz)
				Kind.STENCIL: _stencil(c, sr, it, a, hz)
				Kind.BOXES: _boxes(c, it, s, origin + off * s, a, face_c, hz)
				Kind.SLOT: _slot(c, sr, it, a, f, hz)
				Kind.CHEVRON: _chevron(c, sr, it, a, hz)


func _h(col: Color, a: float, hz: float) -> Color:
	var x := col
	if hz > 0.0:
		x = col.lerp(haze_color, hz)
	elif hz < 0.0:
		x = col.lerp(haze_color, -hz)
	x.a = col.a * a
	return x


func _draw_solid(c: CanvasItem, it: Dictionary, s: float, org: Vector2, a: float, face_c: Color, sl: Color, sdk: Color, hz: float, with_face: bool) -> void:
	var o := extrude_dir * float(it.d) * s
	var sides := o.length_squared() > 0.09
	for e in (it.edges as Array):
		if not sides:
			break
		var n: Vector2 = e[2]
		if n.dot(extrude_dir) <= 0.02:
			continue
		var pa: Vector2 = (e[0] as Vector2) * s + org
		var pb: Vector2 = (e[1] as Vector2) * s + org
		if pa.distance_squared_to(pb) < 0.04:
			continue
		var col := sl.lerp(sdk, clampf(n.y * 0.85 + 0.1, 0.0, 1.0))
		c.draw_colored_polygon(PackedVector2Array([pa, pb, pb + o, pa + o]), _h(col, a, hz))
	if not with_face:
		return
	var poly: PackedVector2Array = it.poly
	var sp := PackedVector2Array()
	sp.resize(poly.size())
	for i in poly.size():
		sp[i] = poly[i] * s + org
	c.draw_colored_polygon(sp, _h(face_c, a, hz))
	var w := clampf(float(it.d) * s * 0.06, 0.8, 3.5)
	for e in (it.edges as Array):
		var n2: Vector2 = e[2]
		if n2.dot(extrude_dir) < -0.35:
			c.draw_line((e[0] as Vector2) * s + org, (e[1] as Vector2) * s + org, _h(bevel_light, a, hz), w)


func _panel(c: CanvasItem, sr: Rect2, d: float, tone: float, a: float, face_c: Color, hz: float) -> void:
	var base := face_c.lightened(tone * tone_jitter) if tone > 0.0 else face_c.darkened(-tone * tone_jitter)
	var mn := minf(sr.size.x, sr.size.y)
	var bw := clampf(absf(d), 0.6, mn * 0.2)
	if d >= 0.0:
		c.draw_rect(sr, _h(base, a, hz))
		c.draw_rect(Rect2(sr.position, Vector2(sr.size.x, bw)), _h(bevel_light, a, hz))
		c.draw_rect(Rect2(sr.position, Vector2(bw, sr.size.y)), _h(bevel_light, a * 0.8, hz))
		c.draw_rect(Rect2(sr.position.x, sr.end.y - bw, sr.size.x, bw), _h(bevel_shade, a, hz))
		c.draw_rect(Rect2(sr.end.x - bw, sr.position.y, bw, sr.size.y), _h(bevel_shade, a * 0.85, hz))
	else:
		c.draw_rect(sr, _h(base.lerp(recess, 0.4), a, hz))
		c.draw_rect(Rect2(sr.position, Vector2(sr.size.x, bw)), _h(recess_deep, a * 0.55, hz))
		c.draw_rect(Rect2(sr.position, Vector2(bw, sr.size.y)), _h(recess_deep, a * 0.45, hz))
		c.draw_rect(Rect2(sr.position.x, sr.end.y - bw, sr.size.x, bw), _h(bevel_light, a * 0.7, hz))
	if mn > 5.0:
		c.draw_rect(sr, _h(seam, a * 0.45, hz), false, 1.0)


func _vent(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, hz: float) -> void:
	c.draw_rect(sr, _h(recess, a, hz))
	var n: int = it.n
	var horiz := sr.size.x >= sr.size.y
	var lo := sr.size.y if horiz else sr.size.x
	var th := lo / n * 0.5
	var pad := minf(sr.size.x, sr.size.y) * 0.08
	for i in n:
		var p := (i + 0.5) / n * lo
		if horiz:
			c.draw_rect(Rect2(sr.position.x + pad, sr.position.y + p - th * 0.5, sr.size.x - pad * 2.0, th), _h(recess_deep, a, hz))
			c.draw_rect(Rect2(sr.position.x + pad, sr.position.y + p + th * 0.5, sr.size.x - pad * 2.0, maxf(th * 0.25, 0.5)), _h(bevel_light, a * 0.45, hz))
		else:
			c.draw_rect(Rect2(sr.position.x + p - th * 0.5, sr.position.y + pad, th, sr.size.y - pad * 2.0), _h(recess_deep, a, hz))
			c.draw_rect(Rect2(sr.position.x + p + th * 0.5, sr.position.y + pad, maxf(th * 0.25, 0.5), sr.size.y - pad * 2.0), _h(bevel_light, a * 0.45, hz))


func _grille(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, hz: float) -> void:
	c.draw_rect(sr, _h(recess, a, hz))
	var nx: int = it.nx
	var ny: int = it.ny
	var cw := sr.size.x / nx
	var ch := sr.size.y / ny
	if cw < 1.5 or ch < 1.5:
		c.draw_rect(sr.grow(-minf(cw, ch) * 0.3), _h(recess_deep, a * 0.7, hz))
		return
	var col := _h(recess_deep, a, hz)
	for y in ny:
		for x in nx:
			c.draw_rect(Rect2(sr.position.x + x * cw + cw * 0.18, sr.position.y + y * ch + ch * 0.18, cw * 0.64, ch * 0.64), col)


func _bolts(c: CanvasItem, sr: Rect2, a: float, hz: float) -> void:
	var mn := minf(sr.size.x, sr.size.y)
	var rad := clampf(mn * 0.09, 0.6, 30.0)
	var ins := rad * 1.8
	for p in [sr.position + Vector2(ins, ins), Vector2(sr.end.x - ins, sr.position.y + ins), sr.end - Vector2(ins, ins), Vector2(sr.position.x + ins, sr.end.y - ins)]:
		c.draw_circle(p, rad, _h(bevel_shade, a, hz))
		if rad > 2.0:
			c.draw_circle(p - Vector2(rad, rad) * 0.25, rad * 0.55, _h(bevel_light, a, hz))


func _pipe(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, hz: float) -> void:
	var horiz := sr.size.x >= sr.size.y
	var col: Color = it.c
	var n: int = it.n
	if horiz:
		var h := sr.size.y * 0.7
		var y := sr.position.y + (sr.size.y - h) * 0.5
		c.draw_rect(Rect2(sr.position.x, y + h * 0.15, sr.size.x, h * 0.85), _h(side_dark, a * 0.35, hz))
		c.draw_rect(Rect2(sr.position.x, y, sr.size.x, h), _h(col, a, hz))
		c.draw_rect(Rect2(sr.position.x, y + h * 0.18, sr.size.x, maxf(h * 0.16, 0.5)), _h(bevel_light, a * 0.8, hz))
		c.draw_rect(Rect2(sr.position.x, y + h * 0.72, sr.size.x, h * 0.28), _h(side_dark, a * 0.6, hz))
		for i in n:
			var x := sr.position.x + (i + 0.5) / n * sr.size.x
			c.draw_rect(Rect2(x - h * 0.18, y - h * 0.08, h * 0.36, h * 1.16), _h(col.darkened(0.25), a, hz))
	else:
		var w := sr.size.x * 0.7
		var x2 := sr.position.x + (sr.size.x - w) * 0.5
		c.draw_rect(Rect2(x2, sr.position.y, w, sr.size.y), _h(col, a, hz))
		c.draw_rect(Rect2(x2 + w * 0.18, sr.position.y, maxf(w * 0.16, 0.5), sr.size.y), _h(bevel_light, a * 0.8, hz))
		c.draw_rect(Rect2(x2 + w * 0.72, sr.position.y, w * 0.28, sr.size.y), _h(side_dark, a * 0.6, hz))
		for i in n:
			var y2 := sr.position.y + (i + 0.5) / n * sr.size.y
			c.draw_rect(Rect2(x2 - w * 0.08, y2 - w * 0.18, w * 1.16, w * 0.36), _h(col.darkened(0.25), a, hz))


## Whether a lamp item is lit at frame f (seeded blink, or steady).
func lamp_on(it: Dictionary, f: float) -> bool:
	if it.get("steady", false):
		return true
	var per := lamp_period * float(it.get("per", 1.0))
	return fposmod(f / per + float(it.sd) * 0.37, 1.0) < 0.5


func _light(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, f: float, hz: float) -> void:
	var rad := minf(sr.size.x, sr.size.y) * 0.32
	var p := sr.get_center()
	c.draw_circle(p, rad * 1.25, _h(recess_deep, a, hz))
	var lvl := lamp_level if lamp_on(it, f) else 0.0
	if lvl > 0.0:
		var col: Color = it.c
		c.draw_circle(p, rad * 2.6, _h(Color(col, 0.18 * lvl), a, hz * 0.5))
		c.draw_circle(p, rad, _h(lamp_off.lerp(col, lvl), a, hz * 0.5))
	else:
		c.draw_circle(p, rad, _h(lamp_off, a, hz))


func _fan(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, f: float, hz: float) -> void:
	var p := sr.get_center()
	var rad := minf(sr.size.x, sr.size.y) * 0.46
	c.draw_circle(p, rad, _h(recess_deep, a, hz))
	var nb: int = it.blades
	var ang := f * float(it.spin) + float(it.sd)
	var col := _h(recess.lightened(0.15), a, hz)
	for i in nb:
		var t := ang + TAU * i / nb
		var dvec := Vector2(cos(t), sin(t))
		var side := dvec.orthogonal() * rad * 0.22
		c.draw_colored_polygon(PackedVector2Array([p + side * 0.4, p + dvec * rad * 0.92 + side, p + dvec * rad * 0.92 - side * 0.3, p - side * 0.4]), col)
	c.draw_circle(p, rad * 0.2, _h(bevel_shade, a, hz))
	if rad > 3.0:
		c.draw_arc(p, rad, 0.0, TAU, 32, _h(bevel_shade, a, hz), maxf(rad * 0.08, 1.0))


func _hazard(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, hz: float) -> void:
	c.draw_rect(sr, _h(accent, a, hz))
	var horiz := sr.size.x >= sr.size.y
	var sh := minf(sr.size.x, sr.size.y)
	var n: int = it.n
	var rect := PackedVector2Array([sr.position, Vector2(sr.end.x, sr.position.y), sr.end, Vector2(sr.position.x, sr.end.y)])
	var step := (sr.size.x if horiz else sr.size.y) / n
	var col := _h(ink, a, hz)
	for i in n + 1:
		var stripe: PackedVector2Array
		if horiz:
			var x := sr.position.x + i * step
			stripe = PackedVector2Array([Vector2(x, sr.position.y), Vector2(x + step * 0.5, sr.position.y), Vector2(x + step * 0.5 - sh, sr.end.y), Vector2(x - sh, sr.end.y)])
		else:
			var y := sr.position.y + i * step
			stripe = PackedVector2Array([Vector2(sr.position.x, y), Vector2(sr.position.x, y + step * 0.5), Vector2(sr.end.x, y + step * 0.5 - sh), Vector2(sr.end.x, y - sh)])
		for poly in Geometry2D.intersect_polygons(stripe, rect):
			c.draw_colored_polygon(poly, col)


func _stencil(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, hz: float) -> void:
	if font == null:
		return
	var fs := sr.size.y * 0.62
	if fs < 7.0:
		return
	fs = pow(1.08, roundf(log(fs) / log(1.08)))
	var txt: String = it.txt
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	if w > sr.size.x:
		fs *= sr.size.x / w
		if fs < 7.0:
			return
		fs = pow(1.08, floorf(log(fs) / log(1.08)))
	c.draw_string(font, Vector2(sr.position.x, sr.position.y + sr.size.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), _h(it.c, a, hz))


func _boxes(c: CanvasItem, it: Dictionary, s: float, org: Vector2, a: float, face_c: Color, hz: float) -> void:
	var i := 0
	for b in (it.boxes as Array):
		var br: Rect2 = b
		var sr := Rect2(br.position * s + org, br.size * s)
		_panel(c, sr, clampf(minf(sr.size.x, sr.size.y) * 0.12, 0.6, 6.0), 0.4 - 0.3 * i, a, face_c, hz)
		i += 1


func _slot(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, f: float, hz: float) -> void:
	c.draw_rect(sr, _h(recess_deep, a, hz))
	c.draw_rect(Rect2(sr.position.x, sr.end.y - maxf(sr.size.y * 0.12, 0.6), sr.size.x, maxf(sr.size.y * 0.12, 0.6)), _h(bevel_light, a * 0.6, hz))
	var n: int = it.n
	var horiz := sr.size.x >= sr.size.y
	var rad := minf(sr.size.x, sr.size.y) * 0.18
	for i in n:
		var u := (i + 0.5) / n
		var p := Vector2(sr.position.x + sr.size.x * u, sr.get_center().y) if horiz else Vector2(sr.get_center().x, sr.position.y + sr.size.y * u)
		var on := fposmod(f / (lamp_period * 2.0) + float(it.sd) * 0.31 + u * 0.5, 1.0) < 0.6
		var lvl := lamp_level if on else 0.15 * lamp_level
		c.draw_circle(p, rad * 2.2, _h(Color(lamp, 0.15 * lvl), a, hz * 0.5))
		c.draw_circle(p, rad, _h(lamp_off.lerp(lamp, lvl), a, hz * 0.5))


func _chevron(c: CanvasItem, sr: Rect2, it: Dictionary, a: float, hz: float) -> void:
	MotionMarks.chevron_strip(c, sr, int(it.n), _h(accent, a, hz))
