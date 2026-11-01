# SPDX-License-Identifier: Apache-2.0
## One extruded solid for a MotionExtrude scene: a 2D outline in a plane
## (`origin` + a * `u` + b * `v`), pushed out along n = u × v by `depth`.
## The cap at `depth` is the "front" (a roof for a floor solid, the face of a
## wall); the cap at 0 is the back.
##
## Floor solids (u = x, v = y) are buildings, tanks and plinths; wall solids
## (u = x, v = z, so n points south at the camera) are signs and slabs; a
## u = y, v = z plane makes pipes running east. Set properties every frame
## from f (height, position, colours); the scene draws whatever they are.
##
##   var b := MotionSolid.box(Vector3(2, 3, 0), Vector3(0.8, 0.8, 2.4))
##   b.paint(CREAM_TOP, CREAM_LIT, CREAM_DARK)
##   var logo := MotionSolid.from_svg(svg_data, [1], 0.005, Vector3(4, 2, 1.9), Vector3.RIGHT, Vector3.BACK, 0.4)
@tool
class_name MotionSolid
extends RefCounted

## Outer contour in plane units, counter-clockwise (set_outline() fixes the winding).
var outline := PackedVector2Array()
var origin := Vector3.ZERO
var u := Vector3(1, 0, 0)
var v := Vector3(0, 1, 0)
## Extrusion length along n = u × v (keep it >= 0).
var depth := 1.0

## Face colours: caps facing up use `top`, faces lit by the scene's light use
## `lit`, the others `dark`. `cap` (alpha > 0) overrides both caps' colour.
var top := Color(0.95, 0.94, 0.9)
var lit := Color(0.85, 0.83, 0.78)
var dark := Color(0.6, 0.58, 0.55)
var cap := Color(0, 0, 0, 0)
## Shade side faces continuously between dark and lit (cylinders, pipes).
var smooth := false
var outline_color := Color(0, 0, 0, 0)
var outline_width := 0.0
## Opacity of every face.
var opacity := 1.0

var draw_front_cap := true
var draw_back_cap := true
var visible := true
## Everything below this height is cut away (a solid rising out of, or sinking
## into, the ground). -INF = no cut.
var clip_z := -INF

## Painter's key override (bigger = drawn earlier). NAN = the ground key of the
## solid's centre.
var sort_key := NAN
## Ground point the painter's key is measured at (INF = the solid's centre).
## Give everything standing on one footprint (a block and its roof tanks) the
## same point, so `stack` orders them.
var sort_at := Vector3.INF
## Tie-break for solids sharing a key (stacked on the same footprint): lower first.
var stack := 0
## Free tag for filters (MotionExtrude.draw's filter callable).
var layer := 0

## Decals drawn on faces right after them, in the face's own plane, in decal
## pixels (MotionExtrude.DECAL_PX per world unit), y down from the face's top
## edge: Array of {face = "front" | "back" | Vector3 outward normal,
## fn = func(c: MotionCanvas, size: Vector2, s: MotionSolid, xf: Transform2D)}.
## `xf` is the face's transform (already set), to compose rotated text with.
var decals: Array[Dictionary] = []
var data := {}

var _centroid := Vector2.ZERO
var _radius := 0.0


## Set the outline, making it counter-clockwise.
func set_outline(pts: PackedVector2Array) -> MotionSolid:
	var a := 0.0
	var n := pts.size()
	var p := pts
	if n > 1 and p[0].distance_to(p[n - 1]) < 1e-6:
		p = p.slice(0, n - 1)
		n -= 1
	a = MotionPoly.area2(p)
	if a < 0.0:
		p.reverse()
	outline = p
	_centroid = Vector2.ZERO
	for q in p:
		_centroid += q
	if n > 0:
		_centroid /= n
	_radius = 0.0
	for q in p:
		_radius = maxf(_radius, q.distance_to(_centroid))
	return self


func normal() -> Vector3:
	return u.cross(v).normalized()


func paint(top_col: Color, lit_col: Color, dark_col: Color) -> MotionSolid:
	top = top_col
	lit = lit_col
	dark = dark_col
	return self


func stroke(col: Color, w: float) -> MotionSolid:
	outline_color = col
	outline_width = w
	return self


## A plane point (a, b) on the cap at extrusion `t` (0 = back, depth = front).
func point(a: float, b: float, t := 0.0) -> Vector3:
	return origin + u * a + v * b + normal() * t


## The world centre of the solid (outline centroid, half way through the depth).
func centre() -> Vector3:
	return point(_centroid.x, _centroid.y, depth * 0.5)


## Radius of a sphere around centre() that holds the whole solid.
func bound_radius() -> float:
	return sqrt(_radius * _radius + depth * depth * 0.25)


func add_decal(face: Variant, fn: Callable) -> MotionSolid:
	decals.append({face = face, fn = fn})
	return self


# ---------------------------------------------------------------- shapes

static func rect_pts(w: float, h: float, x := 0.0, y := 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func circle_pts(r: float, segments := 16, c := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## A box standing on the ground: `pos` is its min corner (south-west, bottom).
static func box(pos: Vector3, size: Vector3) -> MotionSolid:
	var s := MotionSolid.new()
	s.set_outline(rect_pts(size.x, size.y))
	s.origin = pos
	s.depth = size.z
	return s


## An upright cylinder (or n-sided prism) standing on `base`.
static func cylinder(base: Vector3, r: float, h: float, segments := 16) -> MotionSolid:
	var s := MotionSolid.new()
	s.set_outline(circle_pts(r, segments))
	s.origin = base
	s.depth = h
	s.smooth = true
	return s


## A horizontal pipe from `start` running `length` east (axis = x) or north (axis = y).
static func pipe(start: Vector3, r: float, length: float, axis := Vector3.RIGHT, segments := 14) -> MotionSolid:
	var s := MotionSolid.new()
	s.set_outline(circle_pts(r, segments))
	s.origin = start
	if axis.x != 0.0:
		s.u = Vector3(0, 1, 0)
		s.v = Vector3(0, 0, 1)   # n = y × z = +x
	else:
		s.u = Vector3(0, 0, 1)
		s.v = Vector3(1, 0, 0)   # n = z × x = +y
	s.depth = length
	s.smooth = true
	return s


## A wedge (ramp) on the ground: rises from `h0` at the west end to `h1` at the
## east end, `width` deep (north).
static func wedge(pos: Vector3, length: float, width: float, h0: float, h1: float) -> MotionSolid:
	var s := MotionSolid.new()
	s.set_outline(PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, h1), Vector2(0, h0)]))
	s.origin = pos + Vector3(0, width, 0)
	s.u = Vector3(1, 0, 0)
	s.v = Vector3(0, 0, 1)      # n = x × z = -y: extrudes south by `width`
	s.depth = width
	return s


## A slab whose outline comes from SVG parts (the largest contour of each, so
## counters and holes are ignored for the walls). The SVG's top-left sits at
## `origin`, SVG x runs along `u` and SVG y down runs along -`v`, `k` world
## units per SVG unit. For a south-facing wall use u = x, v = z: n points
## south, the front cap faces the camera. Pass parts one at a time to get one
## solid each, or several to get one solid from their combined bounds hull.
static func from_svg(svg: MotionSvgData, part: int, k: float, at: Vector3, uu: Vector3, vv: Vector3, d: float) -> MotionSolid:
	var s := MotionSolid.new()
	var best := PackedVector2Array()
	var best_a := -1.0
	for c in svg.outline(part, 0.5):
		var a := absf(MotionPoly.signed_area(c))
		if a > best_a:
			best_a = a
			best = c
	var pts := PackedVector2Array()
	for p in best:
		pts.append(Vector2(p.x * k, -p.y * k))
	s.set_outline(pts)
	s.origin = at
	s.u = uu
	s.v = vv
	s.depth = d
	s.data.svg_k = k
	return s


## Deprecated: use MotionPoly.signed_area.
static func _area(c: PackedVector2Array) -> float:
	return MotionPoly.signed_area(c)
