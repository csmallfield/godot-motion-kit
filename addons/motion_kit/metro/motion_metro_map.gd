# SPDX-License-Identifier: Apache-2.0
## A transit diagram you can animate: octilinear lines (0, 45 and 90 degrees only)
## routed through grid nodes, bundled side by side where they share a corridor,
## rounded at every bend (concentric bends across a bundle), drawn on by arc
## length, with stations, interchanges, terminus bars, trains and labels.
##
## It holds the geometry only; draw it into a MotionCanvas from the piece's
## draw_fn, choosing per line how much is drawn each frame:
##
##   var m := MotionMetroMap.new()
##   m.cell = 24.0
##   var red := m.add_line(&"red", Color("#e2231a"), [Vector2i(0, 0), Vector2i(12, 6), Vector2i(30, 6)])
##   m.add_line(&"blue", Color("#0a6cb4"), [Vector2i(0, 3), Vector2i(12, 6), Vector2i(30, 6)])
##   m.build()
##   canvas.draw_fn = func(c: MotionCanvas, f: float) -> void:
##       m.draw_line(c, red, 0.0, MK.map(f, [0, 24], [0, 1]))
##       m.draw_train(c, red, fmod(f * 9.0, m.length(red)), 18.0, Color.WHITE)
##
## Coordinates: node (x, y) sits at `origin + Vector2(x, y) * cell` pixels.
## Everything is computed once in build(); drawing reads cached arrays, so the
## picture is whatever fractions the piece passes for its frame (frame-pure).
@tool
class_name MotionMetroMap
extends RefCounted

## Pixels per grid unit.
var cell := 24.0
## Pixel position of node (0, 0).
var origin := Vector2.ZERO
## Distance between the centres of parallel lines in a shared corridor.
var spacing := 7.0
## Default line width in pixels.
var width := 5.0
## Bend radius of a corridor's centreline, in cells. Lines on the inside of a
## bend get a smaller radius and lines on the outside a larger one, so a
## bundle bends concentrically.
var radius := 1.0
## Smallest bend radius in pixels (inside lines of wide bundles).
var min_radius := 3.0
## Radius of the 45-degree jogs a line makes when its slot in a corridor changes.
var jog_radius := 6.0
## Casing drawn under each line, in pixels either side; 0 = none.
var casing := 1.0
var casing_color := Color(0, 0, 0)

## Lines, as added. Read-only after build() apart from `color`, `width` and `meta`.
var lines: Array[Dictionary] = []

var _corr := {}      # edge key -> Array[int] of bundled line indices
var _at_node := {}   # node key -> Array[Vector2] of line positions at that node
var _built := false


# ------------------------------------------------------------------ input

## Add a line through grid `waypoints` (Array of Vector2i). Between waypoints
## the route is octilinear: `mode` "diag" goes diagonal first, "straight"
## goes straight first, "mid" puts the diagonal in the middle. Options:
##   width (px), order (bundle order; default = insertion order), bundle
##   (false: never offset into corridors), shift (Vector2 px added to the whole
##   line), closed (the route returns to its start), radius (cells, overrides
##   the map's), stations (every n nodes; 0 = waypoints only), meta (anything).
## Returns the line index.
func add_line(id: StringName, color: Color, waypoints: Array, opts := {}) -> int:
	var d := {
		id = id, color = color, waypoints = waypoints, kind = &"route",
		mode = StringName(opts.get("mode", "diag")), width = float(opts.get("width", -1.0)),
		order = int(opts.get("order", lines.size())), bundle = bool(opts.get("bundle", true)),
		shift = opts.get("shift", Vector2.ZERO), closed = bool(opts.get("closed", false)),
		radius = float(opts.get("radius", -1.0)), station_every = int(opts.get("stations", 0)),
		meta = opts.get("meta", null),
	}
	lines.append(d)
	_built = false
	return lines.size() - 1


## Add a line along a ready-made pixel path (a logo contour, a hand-drawn route).
## Options: width, closed, shift, meta. It is not bundled or rounded.
func add_path(id: StringName, color: Color, points: PackedVector2Array, opts := {}) -> int:
	var d := {
		id = id, color = color, points = points, kind = &"path",
		width = float(opts.get("width", -1.0)), order = int(opts.get("order", lines.size())),
		bundle = false, shift = opts.get("shift", Vector2.ZERO), closed = bool(opts.get("closed", false)),
		meta = opts.get("meta", null),
	}
	lines.append(d)
	_built = false
	return lines.size() - 1


## Octilinear route from a to b (both included), one node per grid step.
static func route(a: Vector2i, b: Vector2i, mode: StringName = &"diag") -> Array[Vector2i]:
	var out: Array[Vector2i] = [a]
	var d := b - a
	var sx := signi(d.x)
	var sy := signi(d.y)
	var n_diag := mini(absi(d.x), absi(d.y))
	var n_str := maxi(absi(d.x), absi(d.y)) - n_diag
	var diag := Vector2i(sx, sy)
	var straight := Vector2i(sx, 0) if absi(d.x) > absi(d.y) else Vector2i(0, sy)
	var steps: Array[Vector2i] = []
	match mode:
		&"straight":
			for i in n_str: steps.append(straight)
			for i in n_diag: steps.append(diag)
		&"mid":
			var h := n_str / 2
			for i in h: steps.append(straight)
			for i in n_diag: steps.append(diag)
			for i in n_str - h: steps.append(straight)
		_:
			for i in n_diag: steps.append(diag)
			for i in n_str: steps.append(straight)
	var p := a
	for s in steps:
		p += s
		out.append(p)
	return out


## route() that takes the same nodes whichever way it is travelled, so lines
## running a pair of waypoints in opposite directions share the corridor.
static func canonical_route(a: Vector2i, b: Vector2i, mode: StringName = &"diag") -> Array[Vector2i]:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return route(a, b, mode)
	var r := route(b, a, mode)
	r.reverse()
	return r


# ------------------------------------------------------------------ build

## Route, bundle, offset and round every line. Call once after adding lines.
func build() -> void:
	_corr.clear()
	_at_node.clear()
	# 1. nodes
	for li in lines.size():
		var L := lines[li]
		if L.kind != &"route":
			continue
		var wp: Array = L.waypoints
		var nodes: Array[Vector2i] = []
		for k in range(1, wp.size()):
			var seg := canonical_route(wp[k - 1], wp[k], L.mode)
			if not nodes.is_empty():
				seg.remove_at(0)
			nodes.append_array(seg)
		if L.closed and wp.size() > 2:
			var seg2 := canonical_route(wp[wp.size() - 1], wp[0], L.mode)
			seg2.remove_at(0)
			nodes.append_array(seg2)
		L.nodes = nodes
	# 2. corridors, sorted by bundle order
	for li in lines.size():
		var L := lines[li]
		if L.kind != &"route" or not L.bundle:
			continue
		var nodes: Array[Vector2i] = L.nodes
		for k in range(1, nodes.size()):
			var key := _ekey(nodes[k - 1], nodes[k])
			if not _corr.has(key):
				_corr[key] = []
			var arr: Array = _corr[key]
			if not arr.has(li):
				arr.append(li)
	for key in _corr:
		var arr: Array = _corr[key]
		arr.sort_custom(func(x: int, y: int) -> bool: return lines[x].order < lines[y].order)
	# 3. geometry
	for li in lines.size():
		var L := lines[li]
		if L.kind == &"route":
			_build_route(li)
		else:
			var pts: PackedVector2Array = (L.points as PackedVector2Array).duplicate()
			var sh: Vector2 = L.shift
			for i in pts.size():
				pts[i] += sh
			if L.closed and pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) > 0.01:
				pts.append(pts[0])
			L.path = pts
			L.node_pts = PackedVector2Array()
		_measure(L)
	_built = true


func _build_route(li: int) -> void:
	var L := lines[li]
	var nodes: Array[Vector2i] = L.nodes
	var sh: Vector2 = L.shift
	var n_edges := nodes.size() - 1
	if n_edges < 1:
		L.path = PackedVector2Array([px(nodes[0]) + sh]) if nodes.size() > 0 else PackedVector2Array()
		L.node_pts = L.path
		return
	var offs: Array[Vector2] = []
	var dirs: Array[Vector2] = []
	for k in n_edges:
		var a := nodes[k]
		var b := nodes[k + 1]
		dirs.append(Vector2(b - a).normalized())
		var v := Vector2.ZERO
		if L.bundle:
			var key := _ekey(a, b)
			var arr: Array = _corr[key]
			var slot := arr.find(li)
			var o := (slot - (arr.size() - 1) * 0.5) * spacing
			v = _canon_normal(a, b) * o
		offs.append(v + sh)
	var lr: float = L.radius
	var base_r: float = (lr if lr > 0.0 else radius) * cell
	var pts := PackedVector2Array()
	var radii := PackedFloat32Array()
	var node_pts := PackedVector2Array()
	pts.append(px(nodes[0]) + offs[0])
	radii.append(0.0)
	node_pts.append(pts[0])
	for k in range(1, n_edges):
		var n := px(nodes[k])
		var d1 := dirs[k - 1]
		var d2 := dirs[k]
		var v1 := offs[k - 1]
		var v2 := offs[k]
		node_pts.append(n + (v1 + v2) * 0.5)
		if d1.dot(d2) > 0.999:
			if v1.distance_to(v2) < 0.01:
				continue
			# slot change in a straight corridor: a 45-degree jog
			var delta := v1.distance_to(v2)
			var h := minf(delta * 0.5, cell * 0.45)
			pts.append(n + v1 - d1 * h)
			radii.append(jog_radius)
			pts.append(n + v2 + d1 * h)
			radii.append(jog_radius)
			continue
		var hit: Variant = Geometry2D.line_intersects_line(n + v1, d1, n + v2, d2)
		var p: Vector2 = hit if hit != null else n + (v1 + v2) * 0.5
		var turn := d1.angle_to(d2)
		var u_in := d1.rotated(signf(turn) * PI * 0.5)
		var r := maxf(min_radius, base_r - ((v1 + v2) * 0.5 - sh).dot(u_in))
		pts.append(p)
		radii.append(r)
	var last := px(nodes[n_edges]) + offs[n_edges - 1]
	pts.append(last)
	radii.append(0.0)
	node_pts.append(last)
	L.path = _round(pts, radii)
	L.node_pts = node_pts


## Round each corner with a circular arc of its radius (clamped to fit).
func _round(pts: PackedVector2Array, radii: PackedFloat32Array) -> PackedVector2Array:
	return MotionPath.arc_corners(pts, radii)


func _measure(L: Dictionary) -> void:
	var mp := MotionPath.new(L.path)
	mp.wrap = L.closed
	mp.length = MotionPath.polyline_length(L.path)   # the double-precision sum
	L.measured = mp
	L.cum = mp.lengths
	L.length = mp.length


static func _ekey(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return Vector4i(a.x, a.y, b.x, b.y)
	return Vector4i(b.x, b.y, a.x, a.y)


## Normal of an edge in its canonical direction (from the smaller node), so lines
## travelling either way agree on which side is which.
static func _canon_normal(a: Vector2i, b: Vector2i) -> Vector2:
	var k := _ekey(a, b)
	var d := Vector2(k.z - k.x, k.w - k.y).normalized()
	return Vector2(-d.y, d.x)


# ------------------------------------------------------------------ queries

## Pixel position of a grid node.
func px(n: Vector2i) -> Vector2:
	return origin + Vector2(n) * cell


func length(i: int) -> float:
	return float(lines[i].get("length", 0.0))


func path(i: int) -> PackedVector2Array:
	return lines[i].path


## Lines that share the corridor between two neighbouring nodes.
func corridor(a: Vector2i, b: Vector2i) -> Array:
	return _corr.get(_ekey(a, b), [])


## Where line i passes grid node k (its index along the line), offset into its slot.
func node_point(i: int, k: int) -> Vector2:
	var np: PackedVector2Array = lines[i].node_pts
	return np[clampi(k, 0, np.size() - 1)]


## Every line's position at a node (for interchanges). Built on first use.
func points_at(n: Vector2i) -> PackedVector2Array:
	if _at_node.is_empty():
		for li in lines.size():
			var L := lines[li]
			if L.kind != &"route":
				continue
			var nodes: Array[Vector2i] = L.nodes
			for k in nodes.size():
				var key := nodes[k]
				if not _at_node.has(key):
					_at_node[key] = PackedVector2Array()
				var arr: PackedVector2Array = _at_node[key]
				arr.append(node_point(li, k))
				_at_node[key] = arr
	return _at_node.get(n, PackedVector2Array())


## Line i's path as a measured MotionPath (built by build()).
func measured(i: int) -> MotionPath:
	return lines[i].measured


## Point at arc length s (pixels) along line i (clamped; wraps on closed lines).
func point_at(i: int, s: float) -> Vector2:
	return (lines[i].measured as MotionPath).point_at(s)


## Unit direction of travel at arc length s.
func dir_at(i: int, s: float) -> Vector2:
	return (lines[i].measured as MotionPath).direction_at(s)


## Arc length of the path point nearest to p (for stations on a line).
func s_near(i: int, p: Vector2) -> float:
	return (lines[i].measured as MotionPath).nearest(p)


## The part of line i between arc lengths a and b (pixels).
func sub_path(i: int, a: float, b: float) -> PackedVector2Array:
	return (lines[i].measured as MotionPath).sub(a, b)


# ------------------------------------------------------------------ drawing

## Draw line i from fraction a to b of its length (0..1), with its casing.
## `col` overrides the colour when its alpha > 0; `w_scale` scales the width.
func draw_line(c: CanvasItem, i: int, a := 0.0, b := 1.0, opacity := 1.0, w_scale := 1.0, col := Color(0, 0, 0, 0), with_casing := true) -> void:
	if b <= a or opacity <= 0.0:
		return
	var L := lines[i]
	var pts: PackedVector2Array
	if a <= 0.0 and b >= 1.0:
		pts = L.path
	else:
		pts = sub_path(i, a * L.length, b * L.length)
	if pts.size() < 2:
		return
	var lw0: float = L.width
	var w: float = (lw0 if lw0 > 0.0 else width) * w_scale
	var cc: Color = col if col.a > 0.0 else L.color
	if with_casing and casing > 0.0:
		c.draw_polyline(pts, Color(casing_color, casing_color.a * opacity), w + casing * 2.0, true)
	c.draw_polyline(pts, Color(cc, cc.a * opacity), w, true)


## Draw the stretch of line i between arc lengths sa and sb (pixels), no casing:
## light chases, highlights, pulses.
func draw_span(c: CanvasItem, i: int, sa: float, sb: float, col: Color, w: float) -> void:
	var L := lines[i]
	if L.closed and L.length > 0.0:
		var total: float = L.length
		var a0 := fposmod(sa, total)
		var b0 := a0 + (sb - sa)
		if b0 > total:
			_poly(c, sub_path(i, a0, total), col, w)
			_poly(c, sub_path(i, 0.0, b0 - total), col, w)
			return
		_poly(c, sub_path(i, a0, b0), col, w)
		return
	_poly(c, sub_path(i, sa, sb), col, w)


func _poly(c: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	if pts.size() >= 2:
		c.draw_polyline(pts, col, w, true)


## A train: a capsule `len` pixels long centred at arc length s, in `col`
## with a dark outline, following the line's direction there.
func draw_train(c: CanvasItem, i: int, s: float, len: float, col: Color, w := -1.0, outline := Color(0, 0, 0, 0)) -> void:
	var L := lines[i]
	var lw0: float = L.width
	var lw: float = lw0 if lw0 > 0.0 else width
	var tw: float = w if w > 0.0 else lw + 3.0
	var pts: PackedVector2Array
	if L.closed:
		var total: float = L.length
		var a0 := fposmod(s - len * 0.5, total)
		pts = sub_path(i, a0, minf(total, a0 + len))
	else:
		pts = sub_path(i, s - len * 0.5, s + len * 0.5)
	if pts.size() < 2:
		return
	var oc := outline if outline.a > 0.0 else casing_color
	c.draw_polyline(pts, oc, tw + 3.0, true)
	c.draw_circle(pts[0], (tw + 3.0) * 0.5, oc, true, -1.0, true)
	c.draw_circle(pts[pts.size() - 1], (tw + 3.0) * 0.5, oc, true, -1.0, true)
	c.draw_polyline(pts, col, tw, true)
	c.draw_circle(pts[0], tw * 0.5, col, true, -1.0, true)
	c.draw_circle(pts[pts.size() - 1], tw * 0.5, col, true, -1.0, true)


## A terminus bar across the end of line i (`at_end`: the far end).
func draw_terminus(c: CanvasItem, i: int, at_end := true, len := 18.0, col := Color(0, 0, 0, 0), opacity := 1.0) -> void:
	var L := lines[i]
	var s: float = L.length if at_end else 0.0
	var p := point_at(i, s)
	var d := dir_at(i, s)
	var nrm := Vector2(-d.y, d.x)
	var lw0: float = L.width
	var w: float = lw0 if lw0 > 0.0 else width
	var cc: Color = col if col.a > 0.0 else L.color
	c.draw_line(p - nrm * len * 0.5, p + nrm * len * 0.5, Color(cc, cc.a * opacity), w, true)


## A station tick on one side of line i at arc length s (side +1 or -1).
func draw_tick(c: CanvasItem, i: int, s: float, side := 1.0, len := 8.0, opacity := 1.0) -> void:
	var L := lines[i]
	var p := point_at(i, s)
	var d := dir_at(i, s)
	var nrm := Vector2(-d.y, d.x) * side
	var lw0: float = L.width
	var w: float = lw0 if lw0 > 0.0 else width
	var cc: Color = L.color
	c.draw_line(p, p + nrm * (w * 0.5 + len), Color(cc, cc.a * opacity), w * 0.8, true)


## An interchange: a white capsule with a dark outline joining every line's
## position at node n (or the given points), scaled by `s` (0 hides it).
func draw_interchange(c: CanvasItem, n: Vector2i, s := 1.0, r := -1.0, fill := Color.WHITE, outline := Color(0, 0, 0), pts := PackedVector2Array()) -> void:
	if s <= 0.0:
		return
	var p := pts if pts.size() > 0 else points_at(n)
	if p.is_empty():
		return
	var rr := (r if r > 0.0 else width * 0.9 + 2.0) * s
	var a := p[0]
	var b := p[0]
	var best := -1.0
	for x in p:
		for y in p:
			var d := x.distance_squared_to(y)
			if d > best:
				best = d
				a = x
				b = y
	var ow := maxf(1.5, rr * 0.35)
	c.draw_line(a, b, outline, (rr + ow) * 2.0, true)
	c.draw_circle(a, rr + ow, outline, true, -1.0, true)
	c.draw_circle(b, rr + ow, outline, true, -1.0, true)
	c.draw_line(a, b, fill, rr * 2.0, true)
	c.draw_circle(a, rr, fill, true, -1.0, true)
	c.draw_circle(b, rr, fill, true, -1.0, true)


## Text drawn at its on-screen size, so labels stay sharp while the map zooms:
## `zoom` is the canvas' on-screen scale, `size` the label size in map pixels.
## `align` 0 left, 0.5 centre, 1 right; `pos` is the baseline start. Labels
## smaller than `min_px` on screen are skipped (dense maps stay cheap).
static func label(c: CanvasItem, font: Font, pos: Vector2, text: String, size: float, zoom: float, col: Color, align := 0.0, min_px := 4.0) -> void:
	if size * zoom < min_px or col.a <= 0.0:
		return
	# raster sizes snap to a ladder 8% apart so a zooming camera reuses glyphs
	MotionFonts.draw_screen_text(c, Transform2D.IDENTITY, font, pos, text, size, col,
		HORIZONTAL_ALIGNMENT_LEFT, 1.08, min_px, -1.0, align, zoom)
