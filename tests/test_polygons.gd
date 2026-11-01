# SPDX-License-Identifier: Apache-2.0
# Characterisation tests for the polygon helpers spread over the kit (signed
# area, point-in-polygon, bounds) before they were consolidated into MotionPoly,
# plus the outputs that depend on them (MotionSolid, MotionSvgMesh, MotionVoxelize).
extends RefCounted

const SQ := [Vector2(0, 0), Vector2(0, 10), Vector2(10, 10), Vector2(10, 0)]
const OUTER := [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]
const HOLE_REV := [Vector2(25, 25), Vector2(25, 75), Vector2(75, 75), Vector2(75, 25)]
const HOLE_SAME := [Vector2(25, 25), Vector2(75, 25), Vector2(75, 75), Vector2(25, 75)]
const ISLAND := [Vector2(40, 40), Vector2(60, 40), Vector2(60, 60), Vector2(40, 60)]


func _pv(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)


func test_signed_area_variants_agree() -> String:
	var sq := _pv(SQ)
	if MotionSolid._area(sq) != -100.0 or MotionSvgMesh._area(sq) != -100.0 or MotionExtrude._area2(sq) != -200.0:
		return "areas %s %s %s" % [MotionSolid._area(sq), MotionSvgMesh._area(sq), MotionExtrude._area2(sq)]
	var o := _pv(OUTER)
	if MotionSolid._area(o) != 10000.0:
		return "outer area %s" % MotionSolid._area(o)
	return ""


func test_bounds() -> String:
	var g := MotionGreebler.new()
	var b: Rect2 = g._bounds([_pv(OUTER), _pv([Vector2(-5, 50), Vector2(10, 120)])])
	if b != Rect2(-5, 0, 105, 120):
		return "greebler bounds %s" % b
	if g._bounds([]) != Rect2():
		return "empty bounds %s" % g._bounds([])
	if MotionExtrude._bounds(_pv(ISLAND)) != Rect2(40, 40, 20, 20):
		return "extrude bounds %s" % MotionExtrude._bounds(_pv(ISLAND))
	return ""


func test_point_in_polygon_rules() -> String:
	var opposite := [_pv(OUTER), _pv(HOLE_REV)]
	var same := [_pv(OUTER), _pv(HOLE_SAME)]
	# a hole wound the other way is a hole under both rules
	if MotionVoxelize.inside(opposite, Vector2(50, 50)) or MotionVoxelize.inside(opposite, Vector2(50, 50), true):
		return "opposite-wound hole should be empty"
	# a hole wound the same way is filled under nonzero, empty under even-odd
	if not MotionVoxelize.inside(same, Vector2(50, 50)) or MotionVoxelize.inside(same, Vector2(50, 50), true):
		return "same-wound hole: nonzero fills, even-odd empties"
	if not MotionVoxelize.inside(same, Vector2(10, 10)) or MotionVoxelize.inside(same, Vector2(-1, 10)):
		return "ring body / outside"
	# MotionGreebler counts containing contours (even-odd), with bbox pre-checks
	var g := MotionGreebler.new()
	var prepped: Array = g._prep_contours([_pv(OUTER), _pv(HOLE_REV), _pv(ISLAND)])
	if not MotionGreebler._inside(Vector2(50, 50), prepped) or MotionGreebler._inside(Vector2(30, 50), prepped) or not MotionGreebler._inside(Vector2(10, 10), prepped):
		return "greebler inside"
	return ""


func test_svg_mesh_contour_nesting() -> String:
	if not MotionSvgMesh._inside(_pv(HOLE_REV), _pv(OUTER)) or MotionSvgMesh._inside(_pv(OUTER), _pv(HOLE_REV)):
		return "contour inside"
	var cs: Array[PackedVector2Array] = [_pv(OUTER), _pv(HOLE_REV), _pv(ISLAND)]
	var flags := MotionSvgMesh._hole_flags(cs)
	return "" if flags == [false, true, false] else "hole flags %s" % [flags]


func test_solid_outline_winding() -> String:
	var s := MotionSolid.new()
	s.set_outline(_pv(SQ + [Vector2(0, 0)]))
	# closing duplicate dropped, clockwise input reversed to counter-clockwise
	if s.outline != _pv([Vector2(10, 0), Vector2(10, 10), Vector2(0, 10), Vector2(0, 0)]):
		return "outline %s" % s.outline
	return ""


func test_greebler_chamfered() -> String:
	var c := MotionGreebler.chamfered(Rect2(0, 0, 100, 40), 4.0)
	if c.size() != 8 or c[0] != Vector2(4, 0) or c[7] != Vector2(0, 4):
		return "chamfered %s" % c
	if MotionGreebler.chamfered(Rect2(0, 0, 3, 3), 30.0)[0] != Vector2(1.35, 0):
		return "clamped chamfer %s" % MotionGreebler.chamfered(Rect2(0, 0, 3, 3), 30.0)[0]
	return "" if MotionGreebler.chamfered(Rect2(1, 2, 3, 4), 0.0).size() == 4 else "zero chamfer"


func test_svg_mesh_and_voxelize_logo() -> String:
	var svg := MotionSvgData.from_file("res://demo/ftf/assets/ftf_logo.svg")
	var mesh := MotionSvgMesh.build(svg, 10.0)
	var n := (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if mesh.get_surface_count() != 1 or n != 8322:
		return "logo mesh: %d surfaces, %d vertices" % [mesh.get_surface_count(), n]
	var v := MotionVoxelize.from_svg(svg, 40, 20)
	var lit := 0
	for k in v.cover.size():
		if v.cover[k] >= v.threshold:
			lit += 1
	return "" if lit == 791 else "voxelized logo: %d filled cells" % lit
