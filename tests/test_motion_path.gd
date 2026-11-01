# SPDX-License-Identifier: Apache-2.0
# MotionPath: the measured-path object, its statics and builders, and parity
# with the classes that now delegate to it.
extends RefCounted

const L_PTS := [Vector2(0, 800), Vector2(900, 800), Vector2(900, 400)]


func _pv(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)


func _near(a: Vector2, b: Vector2, eps := 1e-3) -> bool:
	return a.distance_to(b) <= eps


func test_measure_open_and_closed() -> String:
	var p := MotionPath.new(_pv(L_PTS))
	if p.lengths != PackedFloat32Array([0, 900, 1300]) or p.length != 1300.0 or p.segment_count() != 2:
		return "open %s %s" % [p.lengths, p.length]
	var c := MotionPath.new(_pv(L_PTS), true)
	if c.segment_count() != 3 or absf(c.length - 2284.8857) > 1e-3 or not c.wrap:
		return "closed %s %s" % [c.lengths, c.length]
	var e := MotionPath.new()
	if e.length != 0.0 or e.point_at(5.0) != Vector2.ZERO or not e.sub(0.0, 1.0).is_empty():
		return "empty path"
	if MotionPath.new(_pv([Vector2(3, 4)])).point_at(10.0) != Vector2(3, 4):
		return "single point"
	return ""


func test_point_clamp_extend_wrap() -> String:
	var p := MotionPath.new(_pv(L_PTS))
	if p.point_at(450.0) != Vector2(450, 800) or p.point_at(1000.0) != Vector2(900, 700):
		return "inside %s %s" % [p.point_at(450.0), p.point_at(1000.0)]
	if p.point_at(-20.0) != Vector2(0, 800) or p.point_at(1500.0) != Vector2(900, 400):
		return "clamp %s %s" % [p.point_at(-20.0), p.point_at(1500.0)]
	p.extend = true
	if p.point_at(-20.0) != Vector2(-20, 800) or p.point_at(1340.0) != Vector2(900, 360):
		return "extend %s %s" % [p.point_at(-20.0), p.point_at(1340.0)]
	var sq := MotionPath.new(_pv([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]), true)
	if sq.length != 400.0 or sq.point_at(-50.0) != Vector2(0, 50) or sq.point_at(450.0) != Vector2(50, 0):
		return "wrap %s %s" % [sq.point_at(-50.0), sq.point_at(450.0)]
	if p.point_at_fraction(0.5) != Vector2(650, 800):
		return "fraction %s" % p.point_at_fraction(0.5)
	return ""


func test_tangents_and_directions() -> String:
	var p := MotionPath.new(_pv(L_PTS))
	if not _near(p.tangent_at(450.0), Vector2(1, 0)) or not _near(p.tangent_at(1100.0), Vector2(0, -1)):
		return "tangent %s %s" % [p.tangent_at(450.0), p.tangent_at(1100.0)]
	# the chord over a window smooths the corner
	if not _near(p.tangent_at(900.0, 50.0), Vector2(1, -1).normalized()):
		return "corner chord %s" % p.tangent_at(900.0, 50.0)
	if p.direction_at(899.0) != Vector2(1, 0) or p.direction_at(901.0) != Vector2(0, -1):
		return "direction %s %s" % [p.direction_at(899.0), p.direction_at(901.0)]
	# clamped ends have no chord: RIGHT
	if p.tangent_at(-50.0) != Vector2.RIGHT:
		return "degenerate tangent %s" % p.tangent_at(-50.0)
	return ""


func test_sub_conventions() -> String:
	var p := MotionPath.new(_pv(L_PTS))
	if p.sub(100.0, 1000.0) != _pv([Vector2(100, 800), Vector2(900, 800), Vector2(900, 700)]):
		return "sub %s" % p.sub(100.0, 1000.0)
	# an exact corner hit: the default takes the segment starting there...
	if p.sub(100.0, 900.0) != _pv([Vector2(100, 800), Vector2(900, 800), Vector2(900, 800)]):
		return "upper %s" % p.sub(100.0, 900.0)
	# ...`before` the one ending there (MotionFlow)
	if p.sub(100.0, 900.0, true) != _pv([Vector2(100, 800), Vector2(900, 800)]):
		return "before %s" % p.sub(100.0, 900.0, true)
	if not p.sub(500.0, 400.0).is_empty() or p.sub_fraction(0.0, 1.0) != _pv(L_PTS):
		return "empty / full"
	var clean := MotionPath.new(_pv([Vector2(0, 0), Vector2(10, 0), Vector2(10.5, 0), Vector2(11, 0), Vector2(50, 0)])).sub_clean(0.0, 50.0)
	if clean != _pv([Vector2(0, 0), Vector2(10, 0), Vector2(50, 0)]):
		return "sub_clean %s" % clean
	return ""


func test_nearest() -> String:
	var p := MotionPath.new(_pv(L_PTS))
	if p.nearest(Vector2(300, 700)) != 300.0 or p.nearest(Vector2(1000, 600)) != 1100.0:
		return "nearest %s %s" % [p.nearest(Vector2(300, 700)), p.nearest(Vector2(1000, 600))]
	return ""


func test_slice_statics() -> String:
	var pts := _pv(L_PTS)
	if MotionPath.polyline_length(pts) != 1300.0:
		return "length"
	if MotionPath.slice(pts, 850.0, 950.0) != _pv([Vector2(850, 800), Vector2(900, 800), Vector2(900, 750)]):
		return "slice %s" % MotionPath.slice(pts, 850.0, 950.0)
	if MotionPath.slice_fraction(pts, 0.1, 0.6) != _pv([Vector2(130, 800), Vector2(780, 800)]):
		return "slice_fraction %s" % MotionPath.slice_fraction(pts, 0.1, 0.6)
	if not MotionPath.slice_fraction(pts, 0.6, 0.1).is_empty():
		return "reversed fraction"
	var ls := MotionPath.cumulative(pts, true, true)
	if MotionPath.point_on(pts, ls, false, -50.0) != Vector2(-50, 800):
		return "point_on extrapolates"
	return ""


func test_rounded_builders() -> String:
	var pts := _pv(L_PTS)
	var a := MotionPath.rounded(pts, 60.0)
	var b := MotionPath.rounded(pts, 60.0, 10, false)
	if a != b or a.size() != 13:
		return "rounded %d vs %d" % [a.size(), b.size()]
	var run := _pv([Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)])
	if MotionPath.rounded(run, 20.0).size() != 3 or MotionPath.rounded(run, 20.0, 4, false).size() != 7:
		return "straight-through corner"
	# true arcs: every arc point is the radius from the arc's centre
	var arc := MotionPath.arc_corners(pts, PackedFloat32Array([0.0, 100.0, 0.0]))
	var centre := Vector2(800, 700)
	for i in range(1, arc.size() - 1):
		if absf(arc[i].distance_to(centre) - 100.0) > 0.01:
			return "arc point %d at %s" % [i, arc[i].distance_to(centre)]
	var rr := MotionPath.rounded_rect(Rect2(0, 0, 400, 300), 40.0, 8)
	if rr.size() != 37 or not _near(rr[0], rr[rr.size() - 1]):
		return "rounded_rect %d" % rr.size()
	if MotionPath.round_polygon(_pv([Vector2(0, 0), Vector2(100, 0), Vector2(50, 80)]), 10.0).size() != 18:
		return "round_polygon"
	return ""


func test_offset_keeps_band_width() -> String:
	var o := MotionPath.offset(_pv(L_PTS), 13.5)
	if o != _pv([Vector2(0, 786.5), Vector2(886.5, 786.5), Vector2(886.5, 400)]):
		return "offset %s" % o
	return ""


func test_wrappers_match_motion_path() -> String:
	var pts := MotionPath.rounded(_pv(L_PTS), 60.0)
	var mp := MotionPath.new(pts)
	# MotionFlow
	var fl := MotionFlow.new()
	var i := fl.add_pipe(_pv(L_PTS), {radius = 60.0})
	var ok := fl.path(i).points == pts and fl.point_at(i, 950.0) == mp.point_at(950.0) \
		and MotionFlow.sub_path(fl._pipes[i], 300.0, 1000.0) == mp.sub(300.0, 1000.0, true)
	fl.free()
	if not ok:
		return "MotionFlow"
	# MotionMetroMap (an unbundled path line)
	var m := MotionMetroMap.new()
	m.add_path(&"p", Color.WHITE, pts)
	m.build()
	if m.point_at(0, 950.0) != mp.point_at(950.0) or m.sub_path(0, 300.0, 1000.0) != mp.sub(300.0, 1000.0) or m.dir_at(0, 950.0) != mp.direction_at(950.0):
		return "MotionMetroMap"
	# MotionTextPath statics
	var ls := MotionTextPath.path_lengths(pts)
	var tp := MotionPath.new(pts, false, true)
	tp.extend = true
	if ls != tp.lengths or MotionTextPath.path_point(pts, ls, false, 1400.0) != tp.point_at(1400.0):
		return "MotionTextPath"
	# FTFKit
	if FTFKit.sub_path(pts, 0.2, 0.7) != MotionPath.slice_fraction(pts, 0.2, 0.7) or FTFKit.rounded_path(_pv(L_PTS), 50.0) != MotionPath.rounded(_pv(L_PTS), 50.0, 8, false):
		return "FTFKit"
	return ""
