# SPDX-License-Identifier: Apache-2.0
## Polygon utilities shared by the kit: signed area, bounds, point-in-polygon
## under the nonzero and even-odd rules, contour nesting (which contours of a
## glyph or logo are holes) and simple polygon builders. All static.
##
##   if MotionPoly.signed_area(pts) < 0.0:
##       pts.reverse()                                   # make it counter-clockwise (y up)
##   var filled := MotionPoly.contains(svg.outline(part), p, evenodd)
##   var holes := MotionPoly.hole_flags(contours)
##
## Contours are PackedVector2Arrays without a closing duplicate point.
@tool
class_name MotionPoly
extends RefCounted


## Twice the signed area (shoelace sum). Positive when the points turn
## counter-clockwise in a y-up frame (clockwise on screen, y down).
static func area2(p: PackedVector2Array) -> float:
	var a := 0.0
	var n := p.size()
	for i in n:
		var q := p[i]
		var r := p[(i + 1) % n]
		a += q.x * r.y - r.x * q.y
	return a


## The signed area (see area2 for the sign).
static func signed_area(p: PackedVector2Array) -> float:
	return area2(p) * 0.5


## Bounding rectangle of a polygon (Rect2() when empty).
static func bounds(p: PackedVector2Array) -> Rect2:
	if p.is_empty():
		return Rect2()
	var r := Rect2(p[0], Vector2.ZERO)
	for q in p:
		r = r.expand(q)
	return r


## Bounding rectangle of several contours (Rect2() when there are no points).
static func bounds_all(contours: Array) -> Rect2:
	var have := false
	var b := Rect2()
	for c in contours:
		for p in (c as PackedVector2Array):
			if not have:
				b = Rect2(p, Vector2.ZERO)
				have = true
			else:
				b = b.expand(p)
	return b


## Point in a multi-contour shape: nonzero winding (SVG's default fill rule),
## or even-odd. Edge crossings are counted directly, so it needs no
## triangulation and accepts any winding.
static func contains(contours: Array, pt: Vector2, evenodd := false) -> bool:
	var wn := 0
	var crossings := 0
	for cv in contours:
		var poly: PackedVector2Array = cv
		var n := poly.size()
		if n < 3:
			continue
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			if a.y <= pt.y:
				if b.y > pt.y and (b - a).cross(pt - a) > 0.0:
					wn += 1
					crossings += 1
			elif b.y <= pt.y and (b - a).cross(pt - a) < 0.0:
				wn -= 1
				crossings += 1
	return (crossings % 2) == 1 if evenodd else wn != 0


## How many of `contours` contain pt (Geometry2D.is_point_in_polygon); odd
## means inside under the even-odd rule. Skips index `skip` (a contour testing
## its own point).
static func count_containing(contours: Array, pt: Vector2, skip := -1) -> int:
	var n := 0
	for i in contours.size():
		if i != skip and Geometry2D.is_point_in_polygon(pt, contours[i]):
			n += 1
	return n


## Contours with cached bounds for repeated even-odd tests: [{pts, bb}]
## (contours under three points are dropped).
static func prepare(contours: Array) -> Array:
	var out := []
	for c in contours:
		var pts: PackedVector2Array = c
		if pts.size() < 3:
			continue
		out.append({pts = pts, bb = bounds_all([pts])})
	return out


## Even-odd point test against prepare()d contours. A contour only counts
## when pt is inside its bounds (Rect2.has_point: the far edges are outside).
static func contains_prepared(prepared: Array, pt: Vector2) -> bool:
	var n := 0
	for c in prepared:
		if (c.bb as Rect2).has_point(pt) and Geometry2D.is_point_in_polygon(pt, c.pts):
			n += 1
	return n % 2 == 1


## Contour a lies inside contour b: most of a's vertices are inside b (a few
## can sit on b's edge where the shapes touch). A single probe point like the
## centroid would fail for a ring, whose centroid lies in its own hole.
static func contour_inside(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var n := 0
	for v in a:
		if Geometry2D.is_point_in_polygon(v, b):
			n += 1
	return n * 2 > a.size()


## Which contours are holes: those inside an odd number of the others.
## `majority` tests most of a contour's vertices (contour_inside, robust where
## outlines touch); false tests only its first vertex (cheaper).
static func hole_flags(contours: Array, majority := true) -> Array[bool]:
	var out: Array[bool] = []
	for i in contours.size():
		var n := 0
		for j in contours.size():
			if i == j:
				continue
			var a: PackedVector2Array = contours[i]
			var b: PackedVector2Array = contours[j]
			if contour_inside(a, b) if majority else Geometry2D.is_point_in_polygon(a[0], b):
				n += 1
		out.append(n % 2 == 1)
	return out


## The four corners of a rectangle, clockwise on screen from the top-left.
static func rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A rectangle with its four corners cut at 45 degrees by `c` px (clamped to
## 45% of the shorter side); c <= 0 gives the plain rectangle.
static func chamfered_rect(r: Rect2, c: float) -> PackedVector2Array:
	if c <= 0.0:
		return rect(r)
	c = minf(c, minf(r.size.x, r.size.y) * 0.45)
	var a := r.position
	var b := r.end
	return PackedVector2Array([Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c)])
