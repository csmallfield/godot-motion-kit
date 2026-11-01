# SPDX-License-Identifier: Apache-2.0
## Loop-built graphic marks for HUDs, liveries, signage and decals: chevrons,
## arrows, checker fields, hatching, X boxes, crosshairs, registration plus
## marks, barcodes, ribbons and stripe bundles along paths, warning triangles,
## hazard clamps and barrier arms. All static; each draws immediately into any
## CanvasItem (call from a MotionCanvas draw_fn, a node's _draw, or a
## MotionExtrude / MotionGreebler decal callback), with an `opacity` argument.
##
##   canvas.draw_fn = func(c: MotionCanvas, f: float) -> void:
##       MotionMarks.chevrons(c, Vector2(120, 540), 6, 40.0, LIME, f / 12.0)
##       MotionMarks.hatch(c, MotionPoly.rect(Rect2(0, 0, 300, 80)), 14.0, 5.0, PINK)
##
## The primitives at the top (line, polyline, polygon, rect, circle, ring) are
## MotionCanvas's drawing helpers as statics: lines under a pixel draw at 1 px
## with their coverage as alpha, and polygons Godot can't triangulate are skipped.
@tool
class_name MotionMarks
extends RefCounted

const _NONE := Color(0, 0, 0, 0)


# ---------------------------------------------------------------- primitives

## `col` with its alpha scaled by `opacity`.
static func fade(col: Color, opacity: float) -> Color:
	return Color(col, col.a * opacity)


## Colour and width for a stroke: under a pixel it draws 1 px wide with its
## coverage as alpha, as a browser rasterizes it. Returns [Color, width].
static func thin(col: Color, w: float) -> Array:
	if w < 1.0:
		return [Color(col, col.a * maxf(w, 0.0)), 1.0]
	return [col, w]


## A straight antialiased line `w` px wide.
static func line(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 1.0, opacity := 1.0) -> void:
	var t := thin(fade(col, opacity), w)
	c.draw_line(a, b, t[0], t[1], true)


## An antialiased polyline (`closed` joins the last point to the first).
static func polyline(c: CanvasItem, pts: PackedVector2Array, col: Color, w := 1.0, opacity := 1.0, closed := false) -> void:
	if pts.size() < 2:
		return
	var p := pts
	if closed:
		p = pts.duplicate()
		p.append(pts[0])
	var t := thin(fade(col, opacity), w)
	c.draw_polyline(p, t[0], t[1], true)


## A filled and/or stroked polygon (fill alpha 0 skips the fill).
static func polygon(c: CanvasItem, pts: PackedVector2Array, fill: Color, stroke := _NONE, w := 1.0, opacity := 1.0) -> void:
	if pts.size() < 3:
		return
	if fill.a > 0.0:
		# Skip polygons Godot can't triangulate (self-intersecting), which would error.
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			c.draw_colored_polygon(pts, fade(fill, opacity))
	if stroke.a > 0.0 and w > 0.0:
		polyline(c, pts, stroke, w, opacity, true)


## A filled rectangle, or an outline when `w` > 0 (inside the rect, like a CSS border).
static func rect(c: CanvasItem, r: Rect2, col: Color, opacity := 1.0, w := 0.0) -> void:
	if w <= 0.0:
		c.draw_rect(r, fade(col, opacity))
	else:
		var k := fade(col, opacity)
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), k)
		c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), k)
		c.draw_rect(Rect2(r.position + Vector2(0, w), Vector2(w, r.size.y - 2 * w)), k)
		c.draw_rect(Rect2(r.position + Vector2(r.size.x - w, w), Vector2(w, r.size.y - 2 * w)), k)


## A filled antialiased disc.
static func circle(c: CanvasItem, centre: Vector2, r: float, fill: Color, opacity := 1.0) -> void:
	if r > 0.0:
		c.draw_circle(centre, r, fade(fill, opacity), true, -1.0, true)


## A circle outline, `w` px wide.
static func ring(c: CanvasItem, centre: Vector2, r: float, col: Color, w := 1.0, opacity := 1.0) -> void:
	if r > 0.0:
		var t := thin(fade(col, opacity), w)
		c.draw_arc(centre, r, 0.0, TAU, maxi(24, int(r * 0.6)), t[0], t[1], true)


## The four corners of a rectangle (MotionPoly.rect).
static func rect_pts(r: Rect2) -> PackedVector2Array:
	return MotionPoly.rect(r)


# ---------------------------------------------------------------- chevrons and arrows

## A row of chevrons ( >>>> ) of height h centred vertically on `origin`, pointing
## along +x (dir = -1 points left). `phase` 0..1 marches them one slot (it
## wraps); `on` 0..1 grows the row.
static func chevrons(c: CanvasItem, origin: Vector2, n: int, h: float, col: Color, phase := 0.0, dir := 1.0, on := 1.0, opacity := 1.0) -> void:
	var w := h * 0.5
	var gap := h * 0.62
	var th := h * 0.24
	var shown := ceili(n * clampf(on, 0.0, 1.0))
	for i in shown:
		var x := origin.x + dir * (fposmod(float(i) + phase, float(n)) * gap)
		var p := PackedVector2Array([
			Vector2(x, origin.y - h * 0.5), Vector2(x + dir * th, origin.y - h * 0.5),
			Vector2(x + dir * (th + w), origin.y), Vector2(x + dir * th, origin.y + h * 0.5),
			Vector2(x, origin.y + h * 0.5), Vector2(x + dir * w, origin.y)])
		polygon(c, p, col, _NONE, 0.0, opacity)


## A row of n chevrons of height h pointing +x, from the top-left `at`, 0.7 h
## apart (a compact decal row; no triangulation check, so cheap in bulk).
static func chevron_row(c: CanvasItem, at: Vector2, n: int, h: float, col: Color, opacity := 1.0) -> void:
	var k := fade(col, opacity)
	for i in n:
		var x := at.x + i * h * 0.7
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, at.y), Vector2(x + h * 0.25, at.y), Vector2(x + h * 0.75, at.y + h * 0.5),
			Vector2(x + h * 0.25, at.y + h), Vector2(x, at.y + h), Vector2(x + h * 0.5, at.y + h * 0.5)]), k)


## One upward chevron (^) of width w with its apex at `apex`.
static func chevron_up(c: CanvasItem, apex: Vector2, w: float, col: Color, opacity := 1.0) -> void:
	var h := w * 0.45
	var t := w * 0.24
	c.draw_colored_polygon(PackedVector2Array([apex + Vector2(-w * 0.5, h), apex, apex + Vector2(w * 0.5, h),
		apex + Vector2(w * 0.5, h + t), apex + Vector2(0, t), apex + Vector2(-w * 0.5, h + t)]), fade(col, opacity))


## n chevrons filling a rectangle, pointing along its long side (+x or +y).
static func chevron_strip(c: CanvasItem, r: Rect2, n: int, col: Color, opacity := 1.0) -> void:
	var k := fade(col, opacity)
	var horiz := r.size.x >= r.size.y
	var sh := minf(r.size.x, r.size.y)
	for i in n:
		var u := (i + 0.15) / n
		if horiz:
			var x := r.position.x + r.size.x * u
			var w := sh * 0.5
			var th := sh * 0.22
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + th, r.position.y), Vector2(x + th + w, r.get_center().y),
				Vector2(x + th, r.end.y), Vector2(x, r.end.y), Vector2(x + w, r.get_center().y)]), k)
		else:
			var y := r.position.y + r.size.y * u
			var w2 := sh * 0.5
			var th2 := sh * 0.22
			c.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, y), Vector2(r.position.x, y + th2), Vector2(r.get_center().x, y + th2 + w2),
				Vector2(r.end.x, y + th2), Vector2(r.end.x, y), Vector2(r.get_center().x, y + w2)]), k)


## A block arrow of length s pointing +x, its tail centred on `at`.
static func arrow(c: CanvasItem, at: Vector2, s: float, col: Color, opacity := 1.0) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 0.18), at + Vector2(s * 0.55, -s * 0.18), at + Vector2(s * 0.55, -s * 0.45),
		at + Vector2(s, 0), at + Vector2(s * 0.55, s * 0.45), at + Vector2(s * 0.55, s * 0.18), at + Vector2(0, s * 0.18)]), fade(col, opacity))


# ---------------------------------------------------------------- fields and fills

## A checker field: `cols` x `rows` cells of side `cell` at `pos`, colour `col`
## on alternate cells. `on` 0..1 reveals cells in a seeded order.
static func checker(c: CanvasItem, pos: Vector2, cols: int, rows: int, cell: float, col: Color, on := 1.0, seed_value := 1.0, opacity := 1.0) -> void:
	var k := 0
	for y in rows:
		for x in cols:
			if (x + y) % 2 == 0:
				if MK.rand(k * 3.3 + seed_value) < on:
					rect(c, Rect2(pos + Vector2(x, y) * cell, Vector2(cell, cell)), col, opacity)
				k += 1


## Parallel hatching clipped to a polygon `area` (convex or concave):
## `spacing` px apart, `width` px wide, at `angle_deg`; `shift` slides the
## stripes across (animate it to scroll).
static func hatch(c: CanvasItem, area: PackedVector2Array, spacing: float, width: float, col: Color, angle_deg := 45.0, shift := 0.0, opacity := 1.0) -> void:
	var bb := MotionPoly.bounds(area)
	var a := deg_to_rad(angle_deg)
	var d := Vector2(cos(a), sin(a))      # stripe direction
	var nrm := Vector2(-d.y, d.x)         # across stripes
	var centre := bb.get_center()
	var reach := bb.size.length()
	var n := ceili(reach / spacing) + 2
	for i in range(-n, n + 1):
		var o := centre + nrm * (i * spacing + fposmod(shift, spacing))
		var stripe := PackedVector2Array([
			o - d * reach - nrm * width * 0.5, o + d * reach - nrm * width * 0.5,
			o + d * reach + nrm * width * 0.5, o - d * reach + nrm * width * 0.5])
		for poly in Geometry2D.intersect_polygons(stripe, area):
			polygon(c, poly, col, _NONE, 0.0, opacity)


## A seeded barcode filling `r`; `on` 0..1 wipes it in from the left (or top
## when `vertical`).
static func barcode(c: CanvasItem, r: Rect2, col: Color, seed_value := 1.0, on := 1.0, opacity := 1.0, vertical := false) -> void:
	var x := 0.0
	var k := 0
	var length := r.size.y if vertical else r.size.x
	while x < length * clampf(on, 0.0, 1.0):
		var w := 2.0 + floorf(MK.rand(k * 1.7 + seed_value) * 4.0) * 2.0
		var gap := 2.0 + floorf(MK.rand(k * 2.9 + seed_value + 5.0) * 3.0) * 2.0
		if vertical:
			rect(c, Rect2(r.position + Vector2(0, x), Vector2(r.size.x, minf(w, length - x))), col, opacity)
		else:
			rect(c, Rect2(r.position + Vector2(x, 0), Vector2(minf(w, length - x), r.size.y)), col, opacity)
		x += w + gap
		k += 1


# ---------------------------------------------------------------- registration marks

## A box with an X through it (the placeholder / "no image" mark), side `size`
## centred on `centre`, scaled by `s` (0 hides it).
static func xbox(c: CanvasItem, centre: Vector2, size: float, col: Color, w := 2.0, opacity := 1.0, s := 1.0) -> void:
	if s <= 0.0:
		return
	var h := size * 0.5 * s
	var r := Rect2(centre - Vector2(h, h), Vector2(h, h) * 2.0)
	polyline(c, MotionPoly.rect(r), col, w, opacity, true)
	line(c, r.position, r.end, col, w, opacity)
	line(c, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), col, w, opacity)


## A ring of radius r with four ticks (a gun-sight crosshair), scaled by `s`.
static func crosshair(c: CanvasItem, centre: Vector2, r: float, col: Color, w := 2.0, opacity := 1.0, s := 1.0) -> void:
	if s <= 0.0:
		return
	r *= s
	ring(c, centre, r, col, w, opacity)
	line(c, centre - Vector2(r * 1.6, 0), centre - Vector2(r * 0.4, 0), col, w, opacity)
	line(c, centre + Vector2(r * 0.4, 0), centre + Vector2(r * 1.6, 0), col, w, opacity)
	line(c, centre - Vector2(0, r * 1.6), centre - Vector2(0, r * 0.4), col, w, opacity)
	line(c, centre + Vector2(0, r * 0.4), centre + Vector2(0, r * 1.6), col, w, opacity)


## A small "+" registration mark of arm length r.
static func plus(c: CanvasItem, centre: Vector2, r: float, col: Color, w := 2.0, opacity := 1.0) -> void:
	line(c, centre - Vector2(r, 0), centre + Vector2(r, 0), col, w, opacity)
	line(c, centre - Vector2(0, r), centre + Vector2(0, r), col, w, opacity)


# ---------------------------------------------------------------- ribbons along paths

## A thick ribbon along `pts` (round it first with MotionPath.rounded) from
## fraction a to b of its length, with round joins and round or square ends.
static func ribbon(c: CanvasItem, pts: PackedVector2Array, width: float, col: Color, a := 0.0, b := 1.0, round_ends := true, opacity := 1.0) -> void:
	var sp := MotionPath.slice_fraction(pts, a, b)
	if sp.size() < 2:
		return
	var end_mode := Geometry2D.END_ROUND if round_ends else Geometry2D.END_BUTT
	for poly in Geometry2D.offset_polyline(sp, width * 0.5, Geometry2D.JOIN_ROUND, end_mode):
		polygon(c, poly, col, _NONE, 0.0, opacity)


## A band of parallel ribbons following one path (livery stripes): `widths`
## and `cols` from the inside of the bends outwards, `gap` px between bands,
## drawn from fraction a to b.
static func stripe_bundle(c: CanvasItem, pts: PackedVector2Array, widths: Array, cols: Array, gap: float, a := 0.0, b := 1.0, opacity := 1.0) -> void:
	var total := 0.0
	for w in widths:
		total += float(w) + gap
	total -= gap
	var off := -total * 0.5
	for i in widths.size():
		var w: float = widths[i]
		ribbon(c, MotionPath.offset(pts, off + w * 0.5), w, cols[i], a, b, false, opacity)
		off += w + gap


# ---------------------------------------------------------------- signage

## The corners of an equilateral warning triangle of height h (apex up),
## `centre` a little below its middle (where an icon sits).
static func triangle(centre: Vector2, h: float) -> PackedVector2Array:
	var w := h * 1.1547   # equilateral
	return PackedVector2Array([centre + Vector2(0, -h * 0.62), centre + Vector2(w * 0.5, h * 0.38), centre + Vector2(-w * 0.5, h * 0.38)])


## An ISO 7010-style warning triangle of height h: a rounded `ink` border and a
## rounded `fill` field. Draw the icon over it, centred near centre + (0, 0.1 h).
static func warning_triangle(c: CanvasItem, centre: Vector2, h: float, fill: Color, ink := Color.BLACK, opacity := 1.0) -> void:
	polygon(c, MotionPath.round_polygon(triangle(centre, h), h * 0.1), ink, _NONE, 0.0, opacity)
	polygon(c, MotionPath.round_polygon(triangle(centre + Vector2(0, h * 0.035), h * 0.74), h * 0.06), fill, _NONE, 0.0, opacity)


## An L-shaped hazard clamp at `corner`, arms `arm` px long and `thick` px wide
## pointing along sx (+1/-1 in x) and sy (+1/-1 in y), `col_a` with `col_b`
## diagonal stripes (34 px period) and a bolt.
static func hazard_clamp(c: CanvasItem, corner: Vector2, sx: float, sy: float, arm: float, thick: float, col_a: Color, col_b: Color, opacity := 1.0) -> void:
	var r1 := Rect2(corner + Vector2(minf(0, sx * arm), minf(0, sy * thick)), Vector2(arm, thick))
	var r2 := Rect2(corner + Vector2(minf(0, sx * thick), minf(0, sy * arm)), Vector2(thick, arm))
	for r in [r1, r2]:
		rect(c, r, col_a, opacity)
	# diagonal stripes clipped to each arm
	for r in [r1, r2]:
		var rr: Rect2 = r
		var k0 := -6
		for k in range(k0, int((rr.size.x + rr.size.y) / 34.0) + 6):
			var x := rr.position.x + k * 34.0
			var band := PackedVector2Array([Vector2(x, rr.position.y), Vector2(x + 17, rr.position.y), Vector2(x + 17 - rr.size.y, rr.end.y), Vector2(x - rr.size.y, rr.end.y)])
			for poly in Geometry2D.intersect_polygons(band, MotionPoly.rect(rr)):
				polygon(c, poly, col_b, _NONE, 1.0, opacity)
	# bolt
	circle(c, corner + Vector2(sx, sy) * thick * 0.5, thick * 0.22, col_b, opacity)
	ring(c, corner + Vector2(sx, sy) * thick * 0.5, thick * 0.3, col_b, 3.0, opacity)


## A level-crossing barrier arm `length` px from `pivot`, `angle` radians
## (0 = along +x), eight blocks alternating col_a / col_b with an `ink` outline
## and hub, on a post running down to y = `ground`. Uses draw_set_transform and
## resets it to identity afterwards.
static func barrier(c: CanvasItem, pivot: Vector2, angle: float, length: float, thick: float, col_a: Color, col_b: Color, ink := Color.BLACK, ground := 1080.0, opacity := 1.0) -> void:
	c.draw_set_transform(pivot, angle, Vector2.ONE)
	var n := 8
	var bl := length / n
	for i in n:
		rect(c, Rect2(i * bl, -thick * 0.5, bl + 0.5, thick), col_a if i % 2 == 0 else col_b, opacity)
	rect(c, Rect2(0, -thick * 0.5, length, thick), ink, opacity, 3.0)
	circle(c, Vector2.ZERO, thick * 0.7, ink, opacity)
	circle(c, Vector2.ZERO, thick * 0.3, col_a, opacity)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# post
	rect(c, Rect2(pivot + Vector2(-thick * 0.45, 0), Vector2(thick * 0.9, ground - pivot.y)), ink, opacity)
	rect(c, Rect2(pivot + Vector2(-thick * 0.45, thick), Vector2(thick * 0.9, 18)), col_a, opacity)
