# SPDX-License-Identifier: Apache-2.0
## Builders for racing-track worlds in a MotionStage3D: a smooth banked
## circuit curve through points, ribbons that follow it (deck, barriers, light
## strips, trail lanes) and the frames to place things along it. Geometry goes
## into SurfaceTools merged into a few ArrayMeshes, so a software-GL render
## stays cheap; build once, then only move the camera and set material values.
##
##   var curve := MotionTrack3D.circuit(points, tilts)
##   var st := SurfaceTool.new()
##   st.begin(Mesh.PRIMITIVE_TRIANGLES)
##   MotionTrack3D.strip(st, curve, 0.0, curve.get_baked_length(), -7.0, 0.0, 7.0, 0.0, DECK)
##   var lane := MotionTrack3D.trail_lane(curve, length, 2.2, 0.7, PINK)
##
## Every vertex carries its track distance in UV2.x, so a material's
## lit_to / lit_from (MotionStage3D unlit materials) run light chases and ship
## trails along the circuit. Unlit vertex colours, no UV: for checkered faces
## use MotionPattern3D.box / quad (UVs in metres).
@tool
class_name MotionTrack3D
extends RefCounted


## A Curve3D through `points` with a bank angle (`tilts`, radians) at each,
## smooth handles of `handle` times the neighbour-to-neighbour vector (0.17:
## round, no overshoot on points ~10-20 m apart) and flat ends.
static func circuit(points: Array[Vector3], tilts: Array[float], handle := 0.17, bake_interval := 0.5) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = bake_interval
	for i in points.size():
		var prev := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, points.size() - 1)]
		var h := (next - prev) * handle
		c.add_point(points[i], -h if i > 0 else Vector3.ZERO, h if i < points.size() - 1 else Vector3.ZERO)
		c.set_point_tilt(i, tilts[i] if i < tilts.size() else 0.0)
	return c


## The banked frame at distance `s` along the curve, lifted by `height` and
## moved `side` to the right (MotionStage3D.path_frame): -Z forward, +Y up.
static func frame(curve: Curve3D, s: float, height := 0.0, side := 0.0) -> Transform3D:
	return MotionStage3D.path_frame(curve, s, height, side)


## The frame's heading only, without bank or pitch: for things standing on
## level ground beside the track (signs, buildings, gantry posts).
static func level_frame(curve: Curve3D, s: float, side := 0.0) -> Transform3D:
	var fr := frame(curve, s, 0.0, side)
	var fwd := -fr.basis.z
	fwd.y = 0.0
	var b := Basis.looking_at(fwd.normalized(), Vector3.UP)
	return Transform3D(b, fr.origin)


## Two triangles (a, b, c) (a, c, d) in vertex colour `col`, UV2.x = `uv2x`.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv2x: float) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_uv2(Vector2(uv2x, 0))
		st.add_vertex(v)


## A ribbon following the curve from s0 to s1 (every `step` metres) between
## the frame-local points (x0, y0) and (x1, y1): flat across the track when
## y0 == y1, an upright fin when x0 == x1. UV2.x is the distance along.
static func strip(st: SurfaceTool, curve: Curve3D, s0: float, s1: float, x0: float, y0: float, x1: float, y1: float,
		col: Color, step := 2.0) -> void:
	var s := s0
	var prev_a := Vector3.ZERO
	var prev_b := Vector3.ZERO
	var first := true
	while true:
		var fr := frame(curve, s)
		var a := fr * Vector3(x0, y0, 0)
		var b := fr * Vector3(x1, y1, 0)
		if not first:
			quad(st, prev_a, prev_b, b, a, col, s)
		prev_a = a
		prev_b = b
		first = false
		if s >= s1:
			break
		s = minf(s + step, s1)


## A light-trail lane: a thin cross-shaped ribbon (flat `half_w` and upright
## `half_h`) along the whole curve at lateral offset x, height y, to be lit as
## a moving window (a ship's trail) with lit_from / lit_to.
static func trail_lane(curve: Curve3D, length: float, x: float, y: float, col: Color, half_w := 0.35,
		half_h := 0.25, step := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	strip(st, curve, 0, length, x - half_w, y, x + half_w, y, col, step)
	strip(st, curve, 0, length, x, y - half_h, x, y + half_h, col, step)
	return st.commit()
