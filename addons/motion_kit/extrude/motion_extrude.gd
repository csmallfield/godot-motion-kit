# SPDX-License-Identifier: Apache-2.0
## 2.5D extrusion: MotionSolids drawn as shaded prisms through an orthographic
## MotionExtrudeCamera, into a MotionCanvas, with painter's ordering.
##
## Every frame: set the camera and the solids from f, call `prepare()` once
## (it sorts), then `draw(canvas)` from the canvas's draw_fn. Hundreds of
## solids draw in one canvas; split them across several canvases with a filter
## when something else (a MotionSvg on a face, a mask) must sit between them:
##
##   scene.prepare()
##   back.draw_fn  = func(c, f): scene.draw(c, func(s): return s.layer == 0)
##   front.draw_fn = func(c, f): scene.draw(c, func(s): return s.layer == 1)
##
## Ordering: solids sort by their ground key along the camera's horizontal view
## direction (far first), then by `stack`; inside a solid the visible sides draw
## far to near and the visible cap last. That is exact for solids on a grid that
## don't overlap in plan, seen from above the horizon. Big solids spanning many
## cells (a sign, a wall) belong in their own layer.
##
## Faces can be cut at a height (`MotionSolid.clip_z`) so solids rise out of the
## ground; decals draw in a face's own plane, so text and markings follow the
## camera; `cap_transform()` and `cap_polygon()` put a MotionSvg (with a mask) on
## a cap, for logos that must keep their exact artwork.
##
## Frame-pure: nothing is cached between frames except the sort of the current one.
@tool
class_name MotionExtrude
extends RefCounted

## Decal units per world unit (a decal drawn 24 units tall on a face is 0.24 world units).
const DECAL_PX := 100.0

var camera := MotionExtrudeCamera.new()
var solids: Array[MotionSolid] = []
## Horizontal direction the light comes from (sides facing it use `lit`).
var light := Vector3(-0.35, -1.0, 0.0)
## Faces whose normal points this much up use the `top` colour.
var top_threshold := 0.6
## Skip faces smaller than this many square pixels (also avoids triangulating slivers).
var min_area := 0.5
## Solids whose bounds fall outside this screen rect are skipped (empty = no culling).
var cull_rect := Rect2(0, 0, 1920, 1080)
## Decals on faces smaller than this many square pixels on screen are skipped.
var min_decal_area := 600.0
## Decal text smaller than this many pixels is skipped (unreadable, and costly).
static var min_text_px := 5

var _sorted: Array[MotionSolid] = []


func add(s: MotionSolid) -> MotionSolid:
	solids.append(s)
	return s


## Update the camera basis and sort the solids. Call once per frame, before drawing.
func prepare() -> void:
	camera.update()
	_sorted.clear()
	var keyed: Array = []
	for s in solids:
		if not s.visible or s.outline.size() < 3:
			continue
		if cull_rect.has_area():
			var r := s.bound_radius() * camera.scale
			if not cull_rect.grow(r).has_point(camera.project(s.centre())):
				continue
		var k := s.sort_key
		if is_nan(k):
			k = camera.ground_key(s.centre() if s.sort_at == Vector3.INF else s.sort_at)
		keyed.append([k, s.stack, s.origin.z, s])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(a[0], b[0]):
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	for e in keyed:
		_sorted.append(e[3])


## Draw every prepared solid (or those `filter(solid)` accepts) into `c`.
func draw(c: MotionCanvas, filter := Callable()) -> void:
	for s in _sorted:
		if filter.is_valid() and not filter.call(s):
			continue
		draw_solid(c, s)


## The colour of a face with outward normal `n` on solid `s`.
func shade(s: MotionSolid, n: Vector3, is_cap: bool) -> Color:
	if is_cap and s.cap.a > 0.0:
		return s.cap
	if n.z > top_threshold:
		return s.top
	var l := Vector3(light.x, light.y, 0.0).normalized()
	var h := Vector3(n.x, n.y, 0.0)
	if h.length_squared() < 1e-6:
		return s.dark
	var k := h.normalized().dot(l)
	if s.smooth:
		return s.dark.lerp(s.lit, smoothstep(-0.9, 0.9, k))
	return s.lit if k >= 0.0 else s.dark


## Draw one solid: visible sides far to near, then the visible cap, each with its decals.
func draw_solid(c: MotionCanvas, s: MotionSolid) -> void:
	var n := s.normal()
	var cnt := s.outline.size()
	var back := PackedVector3Array()
	var front := PackedVector3Array()
	back.resize(cnt)
	front.resize(cnt)
	var dn := n * s.depth
	for i in cnt:
		var p := s.origin + s.u * s.outline[i].x + s.v * s.outline[i].y
		back[i] = p
		front[i] = p + dn
	# Sides: outward normal of a CCW edge (da, db) is (db, -da) in the plane.
	var sides: Array = []
	if s.depth > 1e-5:
		for i in cnt:
			var j := (i + 1) % cnt
			var e := s.outline[j] - s.outline[i]
			if e.length_squared() < 1e-12:
				continue
			var on := (s.u * e.y - s.v * e.x).normalized()
			if not camera.facing(on):
				continue
			var quad := PackedVector3Array([back[i], back[j], front[j], front[i]])
			sides.append([camera.depth((back[i] + front[j]) * 0.5), quad, on, i])
		sides.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for sd in sides:
		var quad: PackedVector3Array = sd[1]
		var on: Vector3 = sd[2]
		if _face(c, s, quad, shade(s, on, false)) == 1:
			_side_decals(c, s, sd[3], on)
	# The cap facing the camera, last.
	var front_vis := camera.facing(n)
	if front_vis and s.draw_front_cap:
		if _face(c, s, front, shade(s, n, true)) == 1:
			_cap_decals(c, s, "front")
	elif not front_vis and s.draw_back_cap and s.depth > 1e-5:
		var rb := back.duplicate()
		rb.reverse()
		if _face(c, s, rb, shade(s, -n, true)) == 1:
			_cap_decals(c, s, "back")


## Clip a world polygon to z >= clip_z, project and fill it. Returns 0 when
## nothing drew, 1 when the whole face drew, 2 when the cut removed part of it
## (decals skip cut faces, so markings appear once a face is fully out).
func _face(c: MotionCanvas, s: MotionSolid, pts: PackedVector3Array, col: Color) -> int:
	var poly := pts
	var cut := false
	if s.clip_z > -INF:
		poly = clip_above(pts, s.clip_z)
		if poly.size() < 3:
			return 0
		for p in pts:
			if p.z < s.clip_z - 1e-5:
				cut = true
				break
	var sp := PackedVector2Array()
	sp.resize(poly.size())
	for i in poly.size():
		sp[i] = camera.project(poly[i])
	if absf(MotionPoly.area2(sp)) * 0.5 < min_area:
		return 0
	var fill := Color(col, col.a * s.opacity)
	if sp.size() == 4 or Geometry2D.triangulate_polygon(sp).size() > 0:
		c.draw_colored_polygon(sp, fill)
	if s.outline_width > 0.0 and s.outline_color.a > 0.0:
		c.polyline(sp, s.outline_color, s.outline_width, s.opacity, true)
	return 2 if cut else 1


func _cap_decals(c: MotionCanvas, s: MotionSolid, which: String) -> void:
	if s.decals.is_empty():
		return
	for d in s.decals:
		if typeof(d.face) == TYPE_STRING and d.face == which:
			var bb := MotionPoly.bounds(s.outline)
			var t := s.depth if which == "front" else 0.0
			# Decal space: x along u, y down (against v), origin at the outline's top-left.
			var o := s.point(bb.position.x, bb.end.y, t)
			var xf := camera.plane_transform(o, s.u / DECAL_PX, -s.v / DECAL_PX)
			if absf(xf.determinant()) * bb.size.x * bb.size.y * DECAL_PX * DECAL_PX < min_decal_area:
				continue
			c.draw_set_transform_matrix(xf)
			(d.fn as Callable).call(c, bb.size * DECAL_PX, s, xf)
			c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _side_decals(c: MotionCanvas, s: MotionSolid, i: int, on: Vector3) -> void:
	if s.decals.is_empty():
		return
	for d in s.decals:
		if typeof(d.face) != TYPE_VECTOR3 or (d.face as Vector3).normalized().dot(on) < 0.95:
			continue
		var j := (i + 1) % s.outline.size()
		var a := s.outline[i]
		var b := s.outline[j]
		var along := (s.u * (b.x - a.x) + s.v * (b.y - a.y))
		var length := along.length()
		var n := s.normal()
		# Seen from outside, the CCW edge runs left to right; decal y runs from the
		# front cap edge towards the back (down a building's wall).
		var o := s.point(a.x, a.y, s.depth)
		var xf := camera.plane_transform(o, along / length / DECAL_PX, -n / DECAL_PX)
		if absf(xf.determinant()) * length * s.depth * DECAL_PX * DECAL_PX < min_decal_area:
			continue
		c.draw_set_transform_matrix(xf)
		(d.fn as Callable).call(c, Vector2(length, s.depth) * DECAL_PX, s, xf)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- caps with artwork

## The screen transform that puts SVG artwork on a solid's front cap, for a
## solid made with MotionSolid.from_svg (SVG units, its MotionSvg's width set to
## the viewBox width so one SVG unit is one local pixel).
func cap_transform(s: MotionSolid, front := true) -> Transform2D:
	var k: float = s.data.get("svg_k", 1.0)
	var t := s.depth if front else 0.0
	return camera.plane_transform(s.origin + s.normal() * t, s.u * k, -s.v * k)


## The front cap's outline on screen, cut at the solid's clip height: draw it
## into a clip_children MotionCanvas holding the MotionSvg so artwork rises
## out of the ground with its solid. Empty when nothing is above the cut.
func cap_polygon(s: MotionSolid, front := true) -> PackedVector2Array:
	var t := s.depth if front else 0.0
	var pts := PackedVector3Array()
	for p in s.outline:
		pts.append(s.point(p.x, p.y, t))
	if s.clip_z > -INF:
		pts = clip_above(pts, s.clip_z)
	var out := PackedVector2Array()
	for p in pts:
		out.append(camera.project(p))
	return out


## True when the solid's cap is fully above its clip height (no mask needed).
func cap_unclipped(s: MotionSolid) -> bool:
	if s.clip_z == -INF:
		return true
	for p in s.outline:
		if s.point(p.x, p.y, s.depth).z < s.clip_z:
			return false
	return true


# ---------------------------------------------------------------- text on faces

## Draw text in a face plane (inside a decal: pass the decal's `xf`), rasterized
## at the size it appears on screen rather than scaled from a small raster, so it
## stays sharp under any camera zoom without MSDF's corner artefacts. `pos` is
## the baseline start in decal units. Leaves `xf` set when it returns.
static func draw_text(c: CanvasItem, xf: Transform2D, font: Font, pos: Vector2, text: String, size: float,
		col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	# a ladder of sizes about 6% apart, so a moving camera reuses glyph rasters
	MotionFonts.draw_screen_text(c, xf, font, pos, text, size, col, align, 1.06, min_text_px, width)


# ---------------------------------------------------------------- geometry

## Sutherland–Hodgman: the part of a planar world polygon with z >= h.
static func clip_above(pts: PackedVector3Array, h: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var ain := a.z >= h
		var bin := b.z >= h
		if ain:
			out.append(a)
		if ain != bin:
			var t := (h - a.z) / (b.z - a.z)
			out.append(a.lerp(b, t))
	return out


## Deprecated: use MotionPoly.area2.
static func _area2(p: PackedVector2Array) -> float:
	return MotionPoly.area2(p)


## Deprecated: use MotionPoly.bounds.
static func _bounds(p: PackedVector2Array) -> Rect2:
	return MotionPoly.bounds(p)
