# SPDX-License-Identifier: Apache-2.0
# MotionPoly, MotionMarks (geometry only; drawing is covered by the renders)
# and MotionTape's pose.
extends RefCounted

const OUTER := [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]
const HOLE_REV := [Vector2(25, 25), Vector2(25, 75), Vector2(75, 75), Vector2(75, 25)]
const HOLE_SAME := [Vector2(25, 25), Vector2(75, 25), Vector2(75, 75), Vector2(25, 75)]


func _pv(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)


func test_area_and_bounds() -> String:
	var o := _pv(OUTER)
	if MotionPoly.area2(o) != 20000.0 or MotionPoly.signed_area(o) != 10000.0 or MotionPoly.signed_area(_pv(HOLE_REV)) != -2500.0:
		return "areas"
	if MotionPoly.bounds(_pv([Vector2(5, 7), Vector2(-3, 9), Vector2(2, -1)])) != Rect2(-3, -1, 8, 10):
		return "bounds"
	if MotionPoly.bounds(PackedVector2Array()) != Rect2() or MotionPoly.bounds_all([]) != Rect2():
		return "empty bounds"
	if MotionPoly.bounds_all([o, _pv([Vector2(150, -20)])]) != Rect2(0, -20, 150, 120):
		return "bounds_all"
	return ""


func test_fill_rules() -> String:
	var opp := [_pv(OUTER), _pv(HOLE_REV)]
	var same := [_pv(OUTER), _pv(HOLE_SAME)]
	var mid := Vector2(50, 50)
	if MotionPoly.contains(opp, mid) or MotionPoly.contains(opp, mid, true):
		return "opposite winding is a hole under both rules"
	if not MotionPoly.contains(same, mid) or MotionPoly.contains(same, mid, true):
		return "same winding: nonzero fills, even-odd doesn't"
	if MotionPoly.count_containing(same, mid) != 2 or MotionPoly.count_containing(same, mid, 0) != 1:
		return "count_containing"
	var prep := MotionPoly.prepare(same + [_pv([Vector2(1, 1), Vector2(2, 2)])])
	if prep.size() != 2 or MotionPoly.contains_prepared(prep, mid) or not MotionPoly.contains_prepared(prep, Vector2(10, 10)):
		return "prepared"
	return ""


func test_nesting() -> String:
	var cs := [_pv(OUTER), _pv(HOLE_REV), _pv([Vector2(40, 40), Vector2(60, 40), Vector2(60, 60), Vector2(40, 60)])]
	if MotionPoly.hole_flags(cs) != [false, true, false] or MotionPoly.hole_flags(cs, false) != [false, true, false]:
		return "hole flags %s %s" % [MotionPoly.hole_flags(cs), MotionPoly.hole_flags(cs, false)]
	if not MotionPoly.contour_inside(_pv(HOLE_REV), _pv(OUTER)) or MotionPoly.contour_inside(_pv(OUTER), _pv(HOLE_REV)):
		return "contour_inside"
	return ""


func test_rect_builders() -> String:
	var r := Rect2(10, 20, 100, 40)
	if MotionPoly.rect(r) != _pv([Vector2(10, 20), Vector2(110, 20), Vector2(110, 60), Vector2(10, 60)]):
		return "rect"
	if MotionMarks.rect_pts(r) != MotionPoly.rect(r) or FTFKit.rect_pts(r) != MotionPoly.rect(r):
		return "rect aliases"
	var c := MotionPoly.chamfered_rect(r, 5.0)
	if c.size() != 8 or c[0] != Vector2(15, 20) or MotionGreebler.chamfered(r, 5.0) != c:
		return "chamfered %s" % c
	return ""


func test_marks_geometry() -> String:
	var t := MotionMarks.triangle(Vector2(0, 0), 100.0)
	if not t[0].is_equal_approx(Vector2(0, -62)) or absf(t[1].distance_to(t[2]) - 115.47) > 0.01:
		return "triangle %s" % t
	var th := MotionMarks.thin(Color(1, 1, 1, 0.8), 0.5)
	if th[1] != 1.0 or not is_equal_approx((th[0] as Color).a, 0.4) or MotionMarks.thin(Color.WHITE, 3.0)[1] != 3.0:
		return "thin %s" % [th]
	if MotionMarks.fade(Color(1, 0, 0, 0.5), 0.5) != Color(1, 0, 0, 0.25):
		return "fade"
	return ""


func test_tape_pose() -> String:
	var spec := {a = Vector2(0, 500), b = Vector2(1000, 500), at = 10.0, dur = 10.0, out = "tear", out_at = 40.0, out_dur = 8.0, tear = 0.4}
	if not MotionTape.pose(spec, 5.0).pieces.is_empty():
		return "before `at` there is no tape"
	var mid: Dictionary = MotionTape.pose(spec, 15.0)
	var pc: Dictionary = mid.pieces[0]
	if mid.pieces.size() != 1 or pc.from != 0.0 or pc.to <= 0.0 or pc.to >= 1000.0:
		return "thrown %s" % [mid.pieces]
	if not (mid.path is MotionPath) or mid.total != 1000.0 or (mid.pts as PackedVector2Array).size() != 42:
		return "pose path %s %s" % [mid.total, (mid.pts as PackedVector2Array).size()]
	var torn: Dictionary = MotionTape.pose(spec, 44.0)
	if torn.pieces.size() != 2 or not torn.pieces[0].torn_end or not torn.pieces[1].torn_start:
		return "tear %s" % [torn.pieces]
	if not MotionTape.edge(mid, 500.0, 20.0).is_equal_approx(Vector2(500, 520)):
		return "edge %s" % MotionTape.edge(mid, 500.0, 20.0)
	var follow := {a = Vector2(0, 0), b = Vector2(100, 0), out = "follow", out_at = 0.0, out_dur = 10.0}
	if MotionTape.pieces(follow, 100.0, 5.0)[0].from <= 0.0:
		return "follow exit moves the tail"
	return ""
