# SPDX-License-Identifier: Apache-2.0
## A measured polyline: points plus cumulative arc lengths, with point,
## tangent and sub-path queries by arc length (pixels) or by fraction (0..1),
## and static builders for paths (rounded corners, true arcs, rounded
## rectangles, offsets). One arc-length model for the kit: MotionFlow,
## MotionCable, MotionMetroMap, MotionTextPath, MotionFaceLights, MotionTape
## and FTFKit's ribbons all measure their paths with it.
##
##   var p := MotionPath.new(MotionPath.rounded(pts, 40.0))
##   var head := p.point_at(f * 12.0)                 # px along the path
##   var drawn := p.sub_fraction(0.0, MK.map(f, [0, 30], [0, 1]))
##   c.draw_polyline(drawn, LIME, 6.0, true)
##
## The object is a snapshot: change `points` and build a new one. Queries are
## pure functions of the arguments, so it is safe to share across frames.
##
## Ends: an open path clamps arc lengths to 0..length, or with `extend` runs
## straight on past its ends (text set along a path keeps its spacing). A
## `closed` path has an implied segment from the last point back to the first
## and its arc lengths wrap; `wrap` alone wraps a path that already returns to
## its start (its last point repeats the first).
@tool
class_name MotionPath
extends RefCounted

## The polyline (read-only: build a new MotionPath to change it).
var points := PackedVector2Array()
## The last point joins back to the first (an implied closing segment).
var closed := false
## Arc lengths wrap (fposmod) instead of clamping. Defaults to `closed`.
var wrap := false
## Open paths run straight on past their ends instead of clamping (ignored when wrapping).
var extend := false
## Cumulative arc length at each point (closed paths add one entry for the closing segment).
var lengths := PackedFloat32Array()
## Total arc length in px: the last cumulative length. Queries clamp and wrap
## by it; a caller with a more precise total may set it (MotionMetroMap keeps
## its double-precision sum).
var length := 0.0


## Measure `pts`. Cumulative lengths are stored in single precision; by
## default they are summed in double precision, `f32_sum` sums them in the
## stored precision (MotionTextPath's original model, kept so text placed
## along a path doesn't move).
func _init(pts := PackedVector2Array(), is_closed := false, f32_sum := false) -> void:
	points = pts
	closed = is_closed
	wrap = is_closed
	lengths = PackedFloat32Array()
	length = 0.0
	var n := pts.size()
	if n == 0:
		return
	lengths.resize(n + (1 if is_closed else 0))
	lengths[0] = 0.0
	if f32_sum:
		for i in range(1, n):
			lengths[i] = lengths[i - 1] + pts[i - 1].distance_to(pts[i])
		if is_closed:
			lengths[n] = lengths[n - 1] + pts[n - 1].distance_to(pts[0])
	else:
		var acc := 0.0
		for i in range(1, n):
			acc += pts[i - 1].distance_to(pts[i])
			lengths[i] = acc
		if is_closed:
			acc += pts[n - 1].distance_to(pts[0])
			lengths[n] = acc
	length = lengths[lengths.size() - 1]


## Number of segments (closed paths count the closing one).
func segment_count() -> int:
	return maxi(0, lengths.size() - 1)


## Index of the segment holding arc length s (the last one starting at or before s), clamped.
func index_at(s: float) -> int:
	return _upper(lengths, s)


## Point at arc length s px (clamped, wrapped or extended, see the class notes).
func point_at(s: float) -> Vector2:
	return _at(points, lengths, length, wrap, extend, s, false)


## Unit tangent at s as the chord over ±window px (smooths polyline corners);
## Vector2.RIGHT where the path has no direction.
func tangent_at(s: float, window := 1.0) -> Vector2:
	var d := point_at(s + window) - point_at(s - window)
	if d.length_squared() < 1e-9:
		return Vector2.RIGHT
	return d.normalized()


## Unit direction of the segment holding s (no smoothing: it turns at each point).
func direction_at(s: float) -> Vector2:
	var n := points.size()
	if n < 2:
		return Vector2.RIGHT
	s = _range(s, length, wrap, false)
	var k := _upper(lengths, s)
	return (points[(k + 1) % n] - points[k]).normalized()


## Point at fraction u (0..1, clamped) of the length.
func point_at_fraction(u: float) -> Vector2:
	return point_at(clampf(u, 0.0, 1.0) * length)


## Tangent (chord over ±window px) at fraction u of the length.
func tangent_at_fraction(u: float, window := 1.0) -> Vector2:
	return tangent_at(clampf(u, 0.0, 1.0) * length, window)


## The part of the path between arc lengths a and b px (clamped; empty when
## b <= a): the point at a, every point in between, the point at b. `before`
## picks the segment *ending* at an exact point hit instead of the one starting
## there (MotionFlow's convention: a span ending on a corner stops at it).
func sub(a: float, b: float, before := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	a = clampf(a, 0.0, length)
	b = clampf(b, 0.0, length)
	if b <= a or points.size() < 2:
		return out
	var ka := _index(a, before)
	var kb := _index(b, before)
	out.append(_at(points, lengths, length, wrap, extend, a, before))
	for k in range(ka + 1, kb + 1):
		out.append(points[k])
	out.append(_at(points, lengths, length, wrap, extend, b, before))
	return out


## sub() by fractions (0..1) of the length.
func sub_fraction(a: float, b: float) -> PackedVector2Array:
	return sub(clampf(a, 0.0, 1.0) * length, clampf(b, 0.0, 1.0) * length)


## sub() for thick strokes on an open path: points closer than `min_step` px to
## the previous one are skipped (a sub-pixel segment has no reliable direction
## and turns a thick polyline's end into a spike), and spans shorter than
## `min_span` px are empty. MotionCable draws its tube with it.
func sub_clean(a: float, b: float, min_step := 1.5, min_span := 0.5) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2 or b - a < min_span:
		return out
	out.append(point_at(a))
	var i := _upper(lengths, a) + 1
	while i < points.size() and lengths[i] < b:
		if points[i].distance_to(out[out.size() - 1]) >= min_step:
			out.append(points[i])
		i += 1
	var last := point_at(b)
	if out.size() > 1 and last.distance_to(out[out.size() - 1]) < min_step:
		out[out.size() - 1] = last
	else:
		out.append(last)
	return out


## Arc length of the path point nearest to p.
func nearest(p: Vector2) -> float:
	var n := points.size()
	var best := INF
	var best_s := 0.0
	for k in segment_count():
		var a := points[k]
		var q := Geometry2D.get_closest_point_to_segment(p, a, points[(k + 1) % n])
		var d := q.distance_squared_to(p)
		if d < best:
			best = d
			best_s = lengths[k] + a.distance_to(q)
	return best_s


# ------------------------------------------------------------ statics on arrays

## Cumulative arc lengths of a polyline (closed adds the closing segment).
## See _init for `f32_sum`.
static func cumulative(pts: PackedVector2Array, is_closed := false, f32_sum := false) -> PackedFloat32Array:
	return MotionPath.new(pts, is_closed, f32_sum).lengths


## Length of an open polyline in px.
static func polyline_length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


## Point at arc length s on `pts` measured by `lens` (MotionTextPath's model:
## closed paths wrap, open paths run straight on past their ends).
static func point_on(pts: PackedVector2Array, lens: PackedFloat32Array, is_closed: bool, s: float) -> Vector2:
	var total: float = lens[lens.size() - 1] if lens.size() > 0 else 0.0
	return _at(pts, lens, total, is_closed, true, s, false)


## Unit tangent at s on `pts` as the chord over ±window px (see point_on).
static func tangent_on(pts: PackedVector2Array, lens: PackedFloat32Array, is_closed: bool, s: float, window := 8.0) -> Vector2:
	var d := point_on(pts, lens, is_closed, s + window) - point_on(pts, lens, is_closed, s - window)
	if d.length_squared() < 1e-9:
		return Vector2.RIGHT
	return d.normalized()


## The part of an open polyline between arc lengths a and b px, without
## measuring it first (one walk). No clamping or ordering: a reversed span
## gives a short backwards stub.
static func slice(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := 0.0
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var l := p.distance_to(q)
		if l <= 0.0:
			continue
		var s1 := s + l
		if s1 >= a and s <= b:
			var t0 := clampf((a - s) / l, 0.0, 1.0)
			var t1 := clampf((b - s) / l, 0.0, 1.0)
			if out.is_empty():
				out.append(p.lerp(q, t0))
			out.append(p.lerp(q, t1))
		s = s1
	return out


## slice() by fractions (0..1, clamped) of the length; empty when b <= a.
static func slice_fraction(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var total := polyline_length(pts)
	var la := clampf(a, 0.0, 1.0) * total
	var lb := clampf(b, 0.0, 1.0) * total
	if lb <= la:
		return PackedVector2Array()
	return slice(pts, la, lb)


# ------------------------------------------------------------ builders

## A path through `pts` with each corner replaced by a smooth curve of radius
## `r` (clamped to half the shorter neighbouring leg), sampled with `seg` + 1
## points (a quadratic Bézier through the corner, close to a circular arc).
## `merge_straight` keeps straight-through corners as one point and returns
## the input for r <= 0; false samples every corner regardless (FTFKit's
## original rounded_path).
static func rounded(pts: PackedVector2Array, r: float, seg := 10, merge_straight := true) -> PackedVector2Array:
	if pts.size() < 3 or (merge_straight and r <= 0.0):
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var b := pts[i]
		var c := pts[i + 1]
		var d1 := (a - b).normalized()
		var d2 := (c - b).normalized()
		var ang := absf(d1.angle_to(d2))
		if merge_straight and ang > PI - 0.01:   # straight through
			out.append(b)
			continue
		var t := minf(r / tan(ang * 0.5), minf(a.distance_to(b), b.distance_to(c)) * 0.5)
		var p1 := b + d1 * t
		var p2 := b + d2 * t
		for k in seg + 1:
			var u := float(k) / seg
			out.append(p1.lerp(b, u).lerp(b.lerp(p2, u), u))
	out.append(pts[pts.size() - 1])
	return out


## Round each corner of an open path with a true circular arc of its own
## radius (`radii[i]` for corner i; 0 keeps it sharp), shrunk to fit half the
## shorter leg. Duplicate points are dropped first; straight-on corners and
## reversals stay sharp. Arcs get one point per ~5 px (2 to 24).
static func arc_corners(pts: PackedVector2Array, radii: PackedFloat32Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	var r := PackedFloat32Array()
	for i in pts.size():
		if p.size() > 0 and pts[i].distance_to(p[p.size() - 1]) < 0.01:
			continue
		p.append(pts[i])
		r.append(radii[i])
	var out := PackedVector2Array()
	if p.size() < 3:
		return p
	out.append(p[0])
	for i in range(1, p.size() - 1):
		var a := p[i - 1]
		var b := p[i]
		var c := p[i + 1]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var turn := d1.angle_to(d2)
		# straight on, no radius, or a reversal (a spike can't be rounded)
		if absf(turn) < 0.01 or absf(turn) > 3.0 or r[i] <= 0.0:
			out.append(b)
			continue
		var th := absf(turn)
		var t := r[i] * tan(th * 0.5)
		var t_max := minf(a.distance_to(b), b.distance_to(c)) * 0.5
		var rr := r[i]
		if t > t_max:
			t = t_max
			rr = t / tan(th * 0.5)
		var p1 := b - d1 * t
		var u_in := d1.rotated(signf(turn) * PI * 0.5)
		var ctr := p1 + u_in * rr
		var a0 := (p1 - ctr).angle()
		var segs := clampi(int(ceil(th * rr / 5.0)), 2, 24)
		for k in segs + 1:
			out.append(ctr + Vector2.from_angle(a0 + turn * float(k) / segs) * rr)
	out.append(p[p.size() - 1])
	return out


## A closed polygon with every corner cut back `r` px along both edges and
## joined by a `samples`-point curve (no closing duplicate). For small,
## friendly corners on signs and badges; r is not clamped to the edges.
static func round_polygon(poly: PackedVector2Array, r: float, samples := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[(i - 1 + n) % n]
		var b := poly[i]
		var cc := poly[(i + 1) % n]
		var p1 := b + (a - b).normalized() * r
		var p2 := b + (cc - b).normalized() * r
		for k in samples:
			var u := float(k) / float(samples - 1)
			out.append(p1.lerp(b, u).lerp(b.lerp(p2, u), u))
	return out


## A closed rounded rectangle as a polyline, clockwise from the end of the
## top-left corner, `seg` + 1 points per corner (its last point repeats the first).
static func rounded_rect(r: Rect2, radius: float, seg := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI * 0.5],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	out.append(Vector2(r.position.x + radius, r.position.y))
	for cc in cs:
		var cen: Vector2 = cc[0]
		var a0: float = cc[1]
		for i in seg + 1:
			var a := a0 + PI * 0.5 * float(i) / float(seg)
			out.append(cen + Vector2(cos(a), sin(a)) * radius)
	return out


## A copy of an open path shifted sideways by d px (positive = left of travel
## in screen space, y down). Corners are miter-compensated so a band keeps its
## width through bends (the compensation is capped at ~2.9x for sharp turns).
static func offset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var t := Vector2.ZERO
		if i > 0:
			t += (pts[i] - pts[i - 1]).normalized()
		if i < n - 1:
			t += (pts[i + 1] - pts[i]).normalized()
		t = t.normalized()
		var nrm := Vector2(t.y, -t.x)
		var k := 1.0
		if i > 0 and i < n - 1:
			var d1 := (pts[i] - pts[i - 1]).normalized()
			k = 1.0 / maxf(0.35, nrm.dot(Vector2(d1.y, -d1.x)))
		out.append(pts[i] + nrm * d * k)
	return out


# ------------------------------------------------------------ internals

func _index(s: float, before: bool) -> int:
	if before:
		return clampi(lengths.bsearch(s, true) - 1, 0, lengths.size() - 2)
	return _upper(lengths, s)


## The last segment index whose start is at or before s, in 0..segments-1.
static func _upper(lens: PackedFloat32Array, s: float) -> int:
	var lo := 0
	var hi := lens.size() - 2
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if lens[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	return maxi(lo, 0)


static func _range(s: float, total: float, wraps: bool, ext: bool) -> float:
	if wraps and total > 0.0:
		return fposmod(s, total)
	if not ext:
		return clampf(s, 0.0, total)
	return s


static func _at(pts: PackedVector2Array, lens: PackedFloat32Array, total: float, wraps: bool, ext: bool, s: float, before: bool) -> Vector2:
	var n := pts.size()
	if n == 0:
		return Vector2.ZERO
	if n == 1:
		return pts[0]
	s = _range(s, total, wraps, ext)
	var segs := lens.size() - 1
	var lo: int
	if before:
		lo = clampi(lens.bsearch(s, true) - 1, 0, segs - 1)
	elif ext and s <= 0.0:
		lo = 0
	elif ext and s >= total:
		lo = segs - 1
	else:
		lo = _upper(lens, s)
	var a := pts[lo]
	var b := pts[(lo + 1) % n]
	var l0: float = lens[lo]
	var seg: float = lens[lo + 1] - l0
	if seg <= 0.0:
		return a
	if s >= 0.0 and s <= total:
		return a.lerp(b, (s - l0) / seg)
	return a + (b - a).normalized() * (s - l0)
