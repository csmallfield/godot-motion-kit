# SPDX-License-Identifier: Apache-2.0
# The round-three kit classes, pinned to their current behaviour: block plans,
# cables, voxels, solids, extrusion clipping, view rects, time slices and
# caches, SVG meshes, lens / extrude / pattern-plane projection parity, the
# offscreen helper, and the normalised names (seed, fill_level, set_opacity,
# reveal_from) with their deprecated aliases.
extends RefCounted

## Set by run_tests.gd: the running SceneTree, for tests that need nodes in a tree.
var tree: SceneTree


static func _near(a: float, b: float, eps := 1e-4) -> bool:
	return absf(a - b) <= eps


static func _near2(a: Vector2, b: Vector2, eps := 1e-3) -> bool:
	return a.distance_to(b) <= eps


static func _near4(a: Vector4, b: Vector4, eps := 1e-4) -> bool:
	return (a - b).length() <= eps


# ------------------------------------------------------------ MotionBlockPlan

static func _plan() -> MotionBlockPlan:
	var p := MotionBlockPlan.new(3)
	p.start = 10.0
	p.set_move(0, Vector3(0, 0, 2), Vector3(0, 0, 1), 0.0)      # stays, crouches
	p.set_move(1, Vector3(0, 0, 1), Vector3(2, 0, 1), 0.5)      # short: slides
	p.set_move(2, Vector3(0, 0, 1), Vector3(10, 5, 3), 0.99)    # long: flies
	return p


func test_block_plan_styles_waves_progress() -> String:
	var p := _plan()
	if p.style(0) != MotionBlockPlan.STAY or p.style(1) != MotionBlockPlan.SLIDE or p.style(2) != MotionBlockPlan.FLY:
		return "styles %d %d %d" % [p.style(0), p.style(1), p.style(2)]
	# key 0.5 of 4 waves = wave 2; key 0.99 = wave 3 + 0.96 of the jitter
	if p.starts(0) != 10.0 or p.starts(1) != 46.0 or not _near(p.starts(2), 66.88) or p.lands(1) != 64.0:
		return "starts %s %s %s lands %s" % [p.starts(0), p.starts(1), p.starts(2), p.lands(1)]
	if p.wave_frames() != PackedFloat32Array([10, 28, 46, 64]):
		return "wave frames %s" % p.wave_frames()
	if p.progress(1, 40.0) != 0.0 or p.progress(1, 55.0) != 0.5 or p.progress(1, 99.0) != 1.0:
		return "progress"
	return ""


func test_block_plan_pose() -> String:
	var p := _plan()
	for i in 3:
		var a := p.origin(i)
		var b := p.target(i)
		if p.pose(i, p.starts(i) - 1.0) != Vector4(a.x, a.y, 0, a.z) or p.pose(i, p.lands(i) + 1.0) != Vector4(b.x, b.y, 0, b.z):
			return "ends of move %d" % i
	var want := {
		0: [Vector4(0, 0, 0, 1.865049), Vector4(0, 0, 0, 1.275208), Vector4(0, 0, 0, 0.95)],
		1: [Vector4(0.269903, 0, 0, 1), Vector4(1.449585, 0, 0, 1), Vector4(2, 0, 0, 1)],
		2: [Vector4(0, 0.009304, 1.803434, 1.028886), Vector4(3.771383, 5, 1.803434, 2.306761), Vector4(10, 5, 1.062378, 3)],
	}
	for i in 3:
		var at := [p.starts(i) + 4.0, p.starts(i) + 9.0, p.starts(i) + 15.0]
		for k in 3:
			var got := p.pose(i, at[k])
			if not _near4(got, want[i][k], 1e-4) or got != p.pose(i, at[k]):
				return "pose %d at %s: %s" % [i, at[k], got]
	return ""


func test_block_plan_assign_nearest_and_seed_alias() -> String:
	var blocks := PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(10, 0), Vector2(4, 4)])
	var targets := PackedVector2Array([Vector2(9, 0), Vector2(0, 1), Vector2(4, 0)])
	if MotionBlockPlan.assign_nearest(blocks, targets) != PackedInt32Array([2, 0, 1]):
		return "assign %s" % MotionBlockPlan.assign_nearest(blocks, targets)
	if MotionBlockPlan.assign_nearest(blocks, targets, PackedInt32Array(), {2: true}) != PackedInt32Array([1, 0, 3]):
		return "exclude"
	if MotionBlockPlan.assign_nearest(PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2(9, 0), Vector2(1, 1)])) != PackedInt32Array([-1, 0]):
		return "ran out"
	var p := MotionBlockPlan.new()
	p.seed_v = 3.0
	return "" if p.seed == 3.0 and p.seed_v == 3.0 else "seed alias"


# ----------------------------------------------------------------- MotionCable

func test_cable_build_sub_tug() -> String:
	var c := MotionCable.new()
	c.points = PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 200)])
	c.tension = 1.0
	c.build(0.0)
	if not _near(c.length(), 510.328186, 1e-3) or c.curve().size() != 35 or not _near2(c.point_at(0.5), Vector2(254.0662, -18.23674)):
		return "taut %s %d %s" % [c.length(), c.curve().size(), c.point_at(0.5)]
	if c.point_at(0.0) != Vector2(0, 0) or not _near2(c.point_at(1.0), Vector2(300, 200)):
		return "pinned ends"
	var s := c.sub(0.25, 0.75)
	if s.size() != 20 or not _near2(s[0], c.point_at(0.25), 0.05) or not _near2(s[s.size() - 1], c.point_at(0.75), 0.05):
		return "sub %d" % s.size()
	c.tension = 0.0
	c.build(0.0)
	if not _near(c.length(), 420.760193, 1e-3) or not _near2(c.point_at(0.5), Vector2(189.4165, 85.17939)):
		return "slack %s %s" % [c.length(), c.point_at(0.5)]
	c.tension = 1.0
	if MotionCable.tug(10.0, 30.0) != {at = 10.0, amp = 30.0, period = 9.0, decay = 14.0}:
		return "tug dict"
	c.tugs = [MotionCable.tug(10.0, 30.0)]
	c.build(5.0)
	if not _near2(c.point_at(0.25), Vector2(126.9543, -11.83124)):
		return "before the tug %s" % c.point_at(0.25)
	c.build(13.0)
	if not _near2(c.point_at(0.25), Vector2(122.6325, 1.12414)):
		return "tugged %s" % c.point_at(0.25)
	c.reveal_from = 0.2
	return "" if c.start == 0.2 and c.pieces().size() == 1 else "reveal_from alias / pieces"


# -------------------------------------------------------------- MotionVoxelize

func test_voxelize_from_fn_ascii_targets() -> String:
	var v := MotionVoxelize.from_fn(func(uv: Vector2) -> int:
		if uv.distance_to(Vector2(0.5, 0.5)) >= 0.4:
			return -1
		return 0 if uv.x < 0.5 else 1, 8, 6)
	var want := "........\n..##AA..\n.###AAA.\n.###AAA.\n..##AA..\n........\n"
	if v.ascii() != want:
		return "ascii\n%s" % v.ascii()
	var t := v.targets()
	if t.size() != 20 or t[0].cell != Vector2i(2, 1) or t[0].part != 0 or v.part_at(5, 2) != 1 or v.part_at(0, 0) != -1:
		return "targets %d %s" % [t.size(), t[0]]
	if v.world(Vector2i(2, 1), Vector2(10, 20)) != Vector2(12, 24):
		return "world %s" % v.world(Vector2i(2, 1), Vector2(10, 20))
	var sq: Array = [PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])]
	return "" if MotionVoxelize.inside(sq, Vector2(2, 2)) and not MotionVoxelize.inside(sq, Vector2(5, 2)) else "inside"


# ------------------------------------------------------- MotionExtrude / Solid

func test_extrude_clip_above() -> String:
	var wall := PackedVector3Array([Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 2), Vector3(0, 0, 2)])
	var cut := MotionExtrude.clip_above(wall, 1.0)
	if cut != PackedVector3Array([Vector3(4, 0, 1), Vector3(4, 0, 2), Vector3(0, 0, 2), Vector3(0, 0, 1)]):
		return "half %s" % cut
	if MotionExtrude.clip_above(wall, -1.0) != wall or not MotionExtrude.clip_above(wall, 3.0).is_empty():
		return "all / none"
	return ""


func test_solid_factories() -> String:
	var b := MotionSolid.box(Vector3(1, 2, 0), Vector3(4, 6, 8))
	if b.outline != MotionSolid.rect_pts(4, 6) or b.origin != Vector3(1, 2, 0) or b.depth != 8.0:
		return "box %s" % b.outline
	if b.centre() != Vector3(3, 5, 4) or b.normal() != Vector3(0, 0, 1) or not _near(b.bound_radius(), 5.385165):
		return "box centre %s r %s" % [b.centre(), b.bound_radius()]
	var cy := MotionSolid.cylinder(Vector3(0, 0, 1), 2.0, 5.0, 12)
	if cy.outline.size() != 12 or not cy.smooth or cy.depth != 5.0 or not _near2(cy.outline[3], Vector2(0, 2)):
		return "cylinder"
	var px := MotionSolid.pipe(Vector3.ZERO, 1.0, 5.0)
	var py := MotionSolid.pipe(Vector3.ZERO, 1.0, 5.0, Vector3.UP)
	if px.normal() != Vector3(1, 0, 0) or py.normal() != Vector3(0, 1, 0) or not py.smooth or not py.centre().is_equal_approx(Vector3(0, 2.5, 0)):
		return "pipe %s %s %s" % [px.normal(), py.normal(), py.centre()]
	var w := MotionSolid.wedge(Vector3.ZERO, 10, 4, 1, 3)
	if w.normal() != Vector3(0, -1, 0) or w.origin != Vector3(0, 4, 0) or w.centre() != Vector3(5, 2, 1):
		return "wedge %s %s" % [w.normal(), w.centre()]
	return ""


# --------------------------------------------------------------- MotionViewRect

func test_view_rect_box() -> String:
	var cam := MotionExtrudeCamera.new()
	cam.yaw = 0.0
	cam.pitch = 0.0
	cam.update()
	if MotionViewRect.box(cam, Vector3.ZERO, Vector3(1, 2, 3)) != Rect2(860, 240, 200, 600):
		return "front %s" % MotionViewRect.box(cam, Vector3.ZERO, Vector3(1, 2, 3))
	cam.yaw = 37.0
	cam.pitch = 28.0
	cam.roll = 6.0
	cam.target = Vector3(3, -2, 1)
	cam.update()
	var c := Vector3(4, 1, 2)
	var h := Vector3(1.5, 0.5, 2.0)
	var r := MotionViewRect.box(cam, c, h)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in 8:
		var q := cam.project(c + h * Vector3(1 if k & 1 else -1, 1 if k & 2 else -1, 1 if k & 4 else -1))
		lo = lo.min(q)
		hi = hi.max(q)
	return "" if _near2(r.position, lo) and _near2(r.end, hi) else "rotated box %s vs %s..%s" % [r, lo, hi]


# ------------------------------------------------- MotionTimeSlices / TimeCache

func test_time_slices_band_rects() -> String:
	var t := MotionTimeSlices.new()
	t.size = Vector2(100, 50)
	t.bands = 3
	var want := {
		MotionTimeSlices.Layout.ROWS: [Rect2(0, 0, 100, 17), Rect2(0, 17, 100, 16), Rect2(0, 33, 100, 17)],
		MotionTimeSlices.Layout.COLUMNS: [Rect2(0, 0, 33, 50), Rect2(33, 0, 34, 50), Rect2(67, 0, 33, 50)],
		MotionTimeSlices.Layout.BOXES: [Rect2(0, 0, 100, 50), Rect2(24, 12, 52, 26), Rect2(42, 21, 17, 9)],
		MotionTimeSlices.Layout.CHANNELS: [Rect2(0, 0, 100, 50), Rect2(0, 0, 100, 50), Rect2(0, 0, 100, 50)],
	}
	var err := ""
	for l in want:
		t.layout = l
		var got := t.band_rects()
		if got != (want[l] as Array):
			err = "layout %d: %s" % [l, got]
	t.seed_value = 4.0
	if t.seed != 4.0:
		err = "seed alias"
	t.free()
	return err


func test_time_cache_moments() -> String:
	var root := tree.root
	var tc := MotionTimeCache.new()
	tc.size = Vector2(64, 32)
	tc.layout = MotionTimeCache.Layout.ROWS
	tc.bands = 8
	tc.slots = 8
	tc.delay = 12.0
	tc.step = 4.0
	tc.builder = func() -> Node: return MotionComposition.new()
	root.add_child(tc)
	tc.rebuild()
	tc._frame(30.0)
	var m := tc.moments()
	# LINEAR: band k at u = (k + 0.5) / 8 delays 12u, quantised to 4 frames
	var err := "" if m == PackedFloat32Array([0, 4, 8, 12]) else "moments %s" % m
	tc.reveal = 0.0
	tc.reveal_from = 0.0
	tc._frame(30.0)
	if err == "" and tc.moments() != PackedFloat32Array([0]):
		err = "revealed band only %s" % tc.moments()
	tc.seed_value = 2.0
	if err == "" and tc.seed != 2.0:
		err = "seed alias"
	root.remove_child(tc)
	tc.free()
	return err


# ---------------------------------------------------------------- MotionSvgMesh

func test_svg_mesh_build_counts() -> String:
	var sv := MotionSvgData.from_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50">'
		+ '<rect x="10" y="10" width="80" height="30" fill="#f00"/>'
		+ '<path d="M0 0H20V20H0ZM5 5V15H15V5Z" fill="#00f"/></svg>')
	var m := MotionSvgMesh.build(sv, 10.0)
	var n := (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if m.get_surface_count() != 1 or n != 144:
		return "%d surfaces, %d vertices" % [m.get_surface_count(), n]
	var box := m.get_aabb()
	return "" if box.position.is_equal_approx(Vector3(-5, -1.5, 0)) and box.size.is_equal_approx(Vector3(9, 4, 0.208)) else "aabb %s" % box


# ------------------------------------------------------------- projection parity

func test_extrude_camera_lens_parity() -> String:
	var cases := [[45.0, 35.264, 0.0, 110.0], [20.0, 60.0, 0.0, 40.0], [-70.0, 12.0, 8.0, 75.0], [130.0, 89.0, -15.0, 20.0]]
	var pts := [Vector3(0, 0, 0), Vector3(3, -2, 5), Vector3(-7, 4, 0.5), Vector3(1, 9, -3)]
	for cs in cases:
		var cam := MotionExtrudeCamera.new()
		cam.yaw = cs[0]
		cam.pitch = cs[1]
		cam.roll = cs[2]
		cam.scale = cs[3]
		cam.target = Vector3(2, 1, 0.5)
		cam.centre = Vector2(900, 600)
		cam.update()
		var lens := cam.to_lens()
		if not lens.is_ortho():
			return "lens not orthographic"
		var plain := MotionLens3D.extrude(cam.yaw, cam.pitch, cam.scale, MotionLens3D.from_extrude(cam.target), cam.centre)
		for p in pts:
			var want := cam.project(p)
			var got := lens.project(MotionLens3D.from_extrude(p))
			if not _near2(got, want, 1e-2):
				return "to_lens %s at %s: %s vs %s" % [cs, p, got, want]
			if cam.roll == 0.0 and not _near2(plain.project(MotionLens3D.from_extrude(p)), want, 1e-2):
				return "extrude() %s at %s" % [cs, p]
	return ""


func test_lens_mix_endpoints() -> String:
	var a := MotionLens3D.look(Vector3(0, 4, 20), Vector3(0, 1, 0), 50.0)
	var b := MotionLens3D.extrude(45.0, 35.264, 90.0, Vector3(3, 0, -2))
	b.fov = 50.0
	for t in [0.0, 1.0]:
		var m := a.mix(b, t)
		var e: MotionLens3D = a if t == 0.0 else b
		if not m.target.is_equal_approx(e.target) or not _near(m.frame_h, e.frame_h) or not _near(m.persp, e.persp):
			return "mix %s: target %s frame %s persp %s" % [t, m.target, m.frame_h, m.persp]
		if not m.basis.orthonormalized().is_equal_approx(e.basis.orthonormalized()) or m.offset != e.offset:
			return "mix %s basis / offset" % t
	var half := a.mix(b, 0.5)
	if not (half.persp < a.persp and half.persp > b.persp):
		return "persp between %s" % half.persp
	# t_lens times the flattening separately
	return "" if _near(a.mix(b, 1.0, 0.0).persp, a.persp) else "t_lens"


# The shader's camera rotation (motion_pattern.gdshaderinc: cam_to_world).
static func _cam_to_world(d: Vector3, rot: Vector3) -> Vector3:
	var cr := cos(rot.z)
	var sr := sin(rot.z)
	d = Vector3(d.x * cr - d.y * sr, d.x * sr + d.y * cr, d.z)
	var cp := cos(rot.x)
	var sp := sin(rot.x)
	d = Vector3(d.x, d.y * cp + d.z * sp, -d.y * sp + d.z * cp)
	var cy := cos(rot.y)
	var sy := sin(rot.y)
	return Vector3(d.x * cy + d.z * sy, d.y, -d.x * sy + d.z * cy)


func test_pattern_plane_project_ground_point() -> String:
	var pl := MotionPatternPlane.new()
	pl.fov = 70.0
	var c := pl.centre()
	var err := ""
	var ahead := pl.project(Vector3(0, 0, 10))
	if not _near2(Vector2(ahead.x, ahead.y), c) or ahead.z != 10.0 or pl.project(Vector3(0, 0, -1)).z > 0.0:
		err = "straight ahead %s" % ahead
	pl.pitch = -8.0
	pl.yaw = 12.0
	pl.roll = 5.0
	pl.height = 2.5
	pl.curve = 0.001
	var rot := Vector3(deg_to_rad(pl.pitch), deg_to_rad(pl.yaw), deg_to_rad(pl.roll))
	for q in [Vector2(0, 10), Vector2(-3, 25), Vector2(4, 60)]:
		var g := pl.ground_point(q.x, q.y)
		if err == "" and (not _near(g.x, q.x + 0.001 * q.y * q.y) or g.y != -2.5 or g.z != q.y):
			err = "ground_point %s" % g
		# the shader's ray through the projected pixel lands back on the point
		var s := pl.project(g)
		var d := Vector3(s.x - c.x, c.y - s.y, pl.focal()).normalized()
		var r := _cam_to_world(d, rot)
		var hit := r * (pl.height / -r.y)
		if err == "" and hit.distance_to(g) > 1e-3 * q.y:
			err = "ray %s vs %s" % [hit, g]
	if err == "" and not _near(pl.scale_at(10.0), pl.focal() / 10.0):
		err = "scale_at"
	pl.free()
	return err


# ------------------------------------------------------------- MotionOffscreen

func test_offscreen_helper() -> String:
	if MotionOffscreen.pixels(Vector2(100.6, 50.4), 0.5) != Vector2i(50, 25) or MotionOffscreen.pixels(Vector2(100.6, 50.4), 1.0, false) != Vector2i(100, 50):
		return "pixels"
	if MotionOffscreen.pixels(Vector2.ZERO) != Vector2i(1, 1):
		return "at least 1x1"
	var owner := Node2D.new()
	var content := MotionOffscreen.holder("Content")
	var vp := MotionOffscreen.make(owner, content, SubViewport.UPDATE_DISABLED, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
	var err := ""
	if not vp.transparent_bg or not vp.disable_3d or content.get_parent() != vp or owner.get_child_count() != 0 or owner.get_child_count(true) != 1:
		err = "make"
	elif vp.canvas_item_default_texture_filter != Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR:
		err = "filter"
	MotionOffscreen.fit(vp, Vector2(300, 200), 0.5)
	if err == "" and vp.size != Vector2i(150, 100):
		err = "fit %s" % vp.size
	if err == "" and (not MotionOffscreen.gate(vp, true) or MotionOffscreen.gate(vp, true) or vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS):
		err = "gate"
	owner.free()
	return err


# ------------------------------------------------------------ normalised names

func test_liquid_fill_and_greebler_aliases() -> String:
	var t := MotionLiquidFill.new()
	t.level = 0.4
	t.seed_value = 6.0
	var err := "" if t.fill_level == 0.4 and t.level == 0.4 and t.seed == 6.0 else "liquid fill aliases"
	t.free()
	var g := MotionGreebler.new()
	var id := g.new_structure()
	g.set_alpha(id, 0.25)
	if err == "" and float(g._structures[id].alpha) != 0.25:
		err = "set_alpha"
	g.set_opacity(id, 0.5)
	if err == "" and float(g._structures[id].alpha) != 0.5:
		err = "set_opacity"
	return err


func test_flow_reveal_keys_and_state_fn() -> String:
	var fl := MotionFlow.new()
	fl.add_pipe(PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]), {radius = 0.0})
	fl.set_state(0, {reveal = 0.6, reveal_from = 0.1})
	var err := "" if fl._state[0].draw == 0.6 and fl._state[0].draw_from == 0.1 else "reveal keys"
	fl.state_fn = func(i: int, f: float) -> Dictionary: return {fill = f / 100.0 + i}
	fl._frame(30.0)
	if err == "" and not _near(fl._state[0].fill, 0.3):
		err = "state_fn %s" % fl._state[0].fill
	fl.free()
	return err


func test_plane_scan_captures_in_frame() -> String:
	var ps := MotionPlaneScan.new()
	ps.history = 4
	var calls := [0]
	ps.history_fn = func(t: float) -> Dictionary:
		calls[0] += 1
		return {offset = Vector2(0, t)}
	ps._frame(10.0)
	var err := "" if calls[0] == 4 and ps._hist_len == 4 else "auto capture %d" % calls[0]
	ps.capture(11.0)
	ps._frame(11.0)   # already captured this frame: not sampled again
	if err == "" and calls[0] != 8:
		err = "double capture %d" % calls[0]
	if err == "" and ps._hist_img.get_pixel(1, 0).g != 10.0:
		err = "history %s" % ps._hist_img.get_pixel(1, 0)
	ps.free()
	return err
