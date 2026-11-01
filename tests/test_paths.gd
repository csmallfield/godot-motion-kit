# SPDX-License-Identifier: Apache-2.0
# Characterisation tests for the kit's path code (MotionFlow, MotionCable,
# MotionMetroMap, MotionTextPath, MotionFaceLights, FTFKit's path helpers).
# Values were recorded from the implementations before they were consolidated
# into MotionPath, so these pin the old public behaviour, quirks included.
extends RefCounted

const L_PTS := [Vector2(0, 800), Vector2(900, 800), Vector2(900, 400)]
const SQUARE_RUN := [Vector2(0, 0), Vector2(100, 0), Vector2(200, 0), Vector2(200, 100), Vector2(100, 100)]


func _pv(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)


func _near(a: Variant, b: Variant, eps := 1e-3) -> bool:
	if a is Vector2:
		return (a as Vector2).distance_to(b) <= eps
	return absf(float(a) - float(b)) <= eps


func _same(got: PackedVector2Array, want: Array, eps := 1e-3) -> String:
	if got.size() != want.size():
		return "size %d, want %d (%s)" % [got.size(), want.size(), got]
	for i in want.size():
		if not _near(got[i], want[i], eps):
			return "point %d is %s, want %s" % [i, got[i], want[i]]
	return ""


# ------------------------------------------------------------ MotionFlow

func test_flow_rounded_merges_straight_corners() -> String:
	var r := MotionFlow.rounded(_pv(L_PTS), 60.0)
	if r.size() != 13 or r[0] != Vector2(0, 800) or r[12] != Vector2(900, 400):
		return "L rounded %s" % r
	if not _near(r[1], Vector2(840, 800)) or not _near(r[2], Vector2(851.4, 799.4)):
		return "corner starts %s %s" % [r[1], r[2]]
	# collinear corner kept as one point; radius 0 returns the input
	var s := MotionFlow.rounded(_pv(SQUARE_RUN), 12.0)
	if s.size() != 25 or s[1] != Vector2(100, 0):
		return "collinear corner: %d points, [1] = %s" % [s.size(), s[1]]
	if MotionFlow.rounded(_pv(SQUARE_RUN), 0.0) != _pv(SQUARE_RUN):
		return "radius 0 should return the points"
	return ""


func test_flow_pipe_point_tangent_length() -> String:
	var fl := MotionFlow.new()
	var i := fl.add_pipe(_pv(L_PTS), {radius = 0.0})
	var j := fl.add_pipe(_pv(L_PTS), {radius = 60.0})
	var err := ""
	if fl.length(i) != 1300.0:
		err = "length %s" % fl.length(i)
	elif fl.point_at(i, 450.0) != Vector2(450, 800) or fl.point_at(i, 1000.0) != Vector2(900, 700):
		err = "point_at %s %s" % [fl.point_at(i, 450.0), fl.point_at(i, 1000.0)]
	elif fl.point_at(i, -5.0) != Vector2(0, 800) or fl.point_at(i, 5000.0) != Vector2(900, 400):
		err = "point_at clamps %s %s" % [fl.point_at(i, -5.0), fl.point_at(i, 5000.0)]
	elif not _near(fl.tangent_at(i, 450.0), Vector2(1, 0)) or not _near(fl.tangent_at(i, 1100.0), Vector2(0, -1)):
		err = "tangent %s %s" % [fl.tangent_at(i, 450.0), fl.tangent_at(i, 1100.0)]
	elif not _near(fl.length(j), 1277.2935) or fl.points(j).size() != 13:
		err = "rounded pipe %s %d" % [fl.length(j), fl.points(j).size()]
	elif not _near(fl.point_at(j, 1000.0), Vector2(900, 677.2934)):
		err = "rounded point %s" % fl.point_at(j, 1000.0)
	fl.free()
	return err


func test_flow_sub_path_vertex_convention() -> String:
	# MotionFlow's sub-path takes the segment *ending* at an exact vertex hit:
	# a span ending on a corner stops there, one starting on it repeats it.
	var fl := MotionFlow.new()
	var i := fl.add_pipe(_pv(L_PTS), {radius = 0.0})
	var rc: Dictionary = fl._pipes[i]
	var err := _same(MotionFlow.sub_path(rc, 100.0, 900.0), [Vector2(100, 800), Vector2(900, 800)])
	if err == "":
		err = _same(MotionFlow.sub_path(rc, 900.0, 1100.0), [Vector2(900, 800), Vector2(900, 800), Vector2(900, 600)])
	if err == "":
		err = _same(MotionFlow.sub_path(rc, -40.0, 4000.0), L_PTS)
	if err == "" and not MotionFlow.sub_path(rc, 500.0, 500.0).is_empty():
		err = "empty span should give no points"
	fl.free()
	return err


# ------------------------------------------------------------ FTFKit

func test_ftfkit_rounded_path_keeps_degenerate_corners() -> String:
	var r := FTFKit.rounded_path(_pv(L_PTS), 60.0)
	if r.size() != 11 or not _near(r[2], Vector2(854.0625, 799.0625)):
		return "L rounded %d %s" % [r.size(), r]
	# no straight-through shortcut: the collinear corner gets seg + 1 points
	var s := FTFKit.rounded_path(_pv(SQUARE_RUN), 12.0)
	return "" if s.size() == 29 else "collinear: %d points" % s.size()


func test_ftfkit_path_length_sub_offset() -> String:
	if FTFKit.path_length(_pv(L_PTS)) != 1300.0:
		return "length %s" % FTFKit.path_length(_pv(L_PTS))
	var err := _same(FTFKit.sub_path(_pv(L_PTS), 0.1, 0.6), [Vector2(130, 800), Vector2(780, 800)])
	if err != "":
		return "sub_path " + err
	if not FTFKit.sub_path(_pv(L_PTS), 0.6, 0.1).is_empty():
		return "reversed span should be empty"
	err = _same(FTFKit.sub_path(_pv(L_PTS), -1.0, 2.0), L_PTS)
	if err != "":
		return "clamped sub_path " + err
	err = _same(FTFKit.offset_path(_pv(L_PTS), 13.5), [Vector2(0, 786.5), Vector2(886.5, 786.5), Vector2(886.5, 400)])
	return "" if err == "" else "offset_path " + err


# ------------------------------------------------------------ MotionCable

func test_cable_point_tangent_sub() -> String:
	var c := MotionCable.new()
	c.points = _pv([Vector2(100, 100), Vector2(900, 100)])
	c.tension = 0.3
	c.build(0.0)
	if c.curve().size() != 18 or not _near(c.length(), 853.5663):
		return "curve %d, length %s" % [c.curve().size(), c.length()]
	if c.point_at(0.0) != Vector2(100, 100) or c.point_at(1.0) != Vector2(900, 100):
		return "ends %s %s" % [c.point_at(0.0), c.point_at(1.0)]
	if not _near(c.point_at(0.5), Vector2(500, 230.2145)) or not _near(c.tangent_at(0.25), Vector2(0.955844, 0.293876)):
		return "mid %s, tangent %s" % [c.point_at(0.5), c.tangent_at(0.25)]
	var s := c.sub(0.25, 0.75)
	if s.size() != 10 or not _near(s[0], Vector2(290.5996, 194.7708)):
		return "sub %d %s" % [s.size(), s]
	if not c.sub(0.5, 0.5003).is_empty():
		return "a span under half a pixel should be empty"
	return ""


func test_cable_sub_drops_near_duplicates() -> String:
	var c := MotionCable.new()
	c.points = _pv([Vector2(0, 0), Vector2(10, 0), Vector2(10.5, 0.2), Vector2(400, 300), Vector2(800, 300)])
	c.pinned = true
	c.build(0.0)
	var s := c.sub(0.0, 1.0)
	if c.curve().size() != 69 or s.size() != 40:
		return "curve %d, sub %d" % [c.curve().size(), s.size()]
	for i in range(1, s.size() - 1):
		if s[i].distance_to(s[i - 1]) < 1.5:
			return "points %d and %d are %s apart" % [i - 1, i, s[i].distance_to(s[i - 1])]
	return ""


# ------------------------------------------------------------ MotionMetroMap

func test_metro_routes() -> String:
	var r := MotionMetroMap.route(Vector2i(0, 0), Vector2i(7, 3))
	var want: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3)]
	if r != want:
		return "diag %s" % [r]
	r = MotionMetroMap.route(Vector2i(0, 0), Vector2i(7, 3), &"mid")
	want = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 1), Vector2i(4, 2), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3)]
	if r != want:
		return "mid %s" % [r]
	r = MotionMetroMap.route(Vector2i(0, 0), Vector2i(7, 3), &"straight")
	want = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 1), Vector2i(6, 2), Vector2i(7, 3)]
	if r != want:
		return "straight %s" % [r]
	# canonical: the same nodes whichever way round
	var a := MotionMetroMap.canonical_route(Vector2i(5, 9), Vector2i(-2, 1))
	var b := MotionMetroMap.canonical_route(Vector2i(-2, 1), Vector2i(5, 9))
	b.reverse()
	if a != b or a[0] != Vector2i(5, 9) or a[1] != Vector2i(5, 8):
		return "canonical %s vs %s" % [a, b]
	return ""


func test_metro_bundle_measure_query() -> String:
	var m := MotionMetroMap.new()
	m.add_line(&"a", Color.RED, [Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 6)])
	m.add_line(&"b", Color.BLUE, [Vector2i(0, 1), Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 6)])
	m.build()
	if not _near(m.length(0), 379.896687) or not _near(m.length(1), 383.374340) or m.path(0).size() != 12:
		return "lengths %s %s, %d points" % [m.length(0), m.length(1), m.path(0).size()]
	if m.corridor(Vector2i(3, 0), Vector2i(4, 0)) != [0, 1]:
		return "corridor %s" % [m.corridor(Vector2i(3, 0), Vector2i(4, 0))]
	if m.node_point(0, 3) != Vector2(72, -3.5) or m.node_point(1, 4) != Vector2(72, 3.5):
		return "slots %s %s" % [m.node_point(0, 3), m.node_point(1, 4)]
	if m.point_at(0, 100.0) != Vector2(100, -3.5) or m.dir_at(0, 300.0) != Vector2(0, 1):
		return "point/dir %s %s" % [m.point_at(0, 100.0), m.dir_at(0, 300.0)]
	if not _near(m.s_near(0, Vector2(120, -30)), 120.0):
		return "s_near %s" % m.s_near(0, Vector2(120, -30))
	var s := m.sub_path(0, 10.0, 50.0)
	if _same(s, [Vector2(10, -3.5), Vector2(50, -3.5)]) != "":
		return "sub_path %s" % s
	if not m.sub_path(0, 50.0, 10.0).is_empty():
		return "reversed sub_path should be empty"
	return ""


func test_metro_closed_line_wraps() -> String:
	var m := MotionMetroMap.new()
	m.add_path(&"sq", Color.WHITE, _pv([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]), {closed = true})
	m.build()
	if m.length(0) != 400.0 or m.path(0).size() != 5:
		return "closed path %s, %d points" % [m.length(0), m.path(0).size()]
	if m.point_at(0, -50.0) != Vector2(0, 50) or m.point_at(0, 450.0) != Vector2(50, 0):
		return "wrap %s %s" % [m.point_at(0, -50.0), m.point_at(0, 450.0)]
	# the far end wraps to the start
	return "" if m.point_at(0, 400.0) == Vector2(0, 0) else "end %s" % m.point_at(0, 400.0)


# ------------------------------------------------------------ MotionTextPath

func test_text_path_lengths_and_extrapolation() -> String:
	var p := _pv(L_PTS)
	var ls := MotionTextPath.path_lengths(p)
	if ls != PackedFloat32Array([0, 900, 1300]):
		return "lengths %s" % ls
	var lc := MotionTextPath.path_lengths(p, true)
	if lc.size() != 4 or not _near(lc[3], 2284.8857):
		return "closed lengths %s" % lc
	# open paths run straight on past both ends
	if MotionTextPath.path_point(p, ls, false, -50.0) != Vector2(-50, 800) or MotionTextPath.path_point(p, ls, false, 1340.0) != Vector2(900, 360):
		return "extrapolation %s %s" % [MotionTextPath.path_point(p, ls, false, -50.0), MotionTextPath.path_point(p, ls, false, 1340.0)]
	if not _near(MotionTextPath.path_point(p, lc, true, -10.0), Vector2(9.138123, 795.9386)):
		return "closed wrap %s" % MotionTextPath.path_point(p, lc, true, -10.0)
	if not _near(MotionTextPath.path_tangent(p, ls, false, 1340.0), Vector2(0, -1)):
		return "tangent past the end %s" % MotionTextPath.path_tangent(p, ls, false, 1340.0)
	if MotionTextPath.path_tangent(_pv([Vector2(4, 4), Vector2(4, 4)]), PackedFloat32Array([0, 0]), false, 0.0) != Vector2.RIGHT:
		return "degenerate tangent should be RIGHT"
	return ""


# ------------------------------------------------------------ MotionFaceLights

func test_face_lights_piece() -> String:
	var p := _pv(SQUARE_RUN)
	var err := _same(MotionFaceLights._piece(p, -30.0, 50.0), [Vector2(0, 0), Vector2(50, 0)])
	if err == "":
		# no ordering guard: a reversed span gives a backwards stub
		err = _same(MotionFaceLights._piece(p, 60.0, 20.0), [Vector2(60, 0), Vector2(20, 0)])
	if err == "":
		err = _same(MotionFaceLights._piece(p, 150.0, 250.0), [Vector2(150, 0), Vector2(200, 0), Vector2(200, 50)])
	if err == "":
		var w: Array = MotionFaceLights._sub(p, 400.0, -50.0, 30.0)
		if w.size() != 2 or (w[1] as PackedVector2Array).size() != 2:
			err = "wrapping chase %s" % [w]
	return err
