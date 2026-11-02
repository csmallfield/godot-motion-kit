# SPDX-License-Identifier: Apache-2.0
# The live layer: MotionClock, MotionTrauma, vector springs, instanced and
# cutout materials, flat SVG meshes.
extends RefCounted

const DT := 1.0 / 60.0


# ------------------------------------------------------------------ MotionClock

func test_clock_since_and_frames() -> String:
	var c := MotionClock.new()
	if not is_inf(c.since(&"hit")):
		return "since() before any event should be INF"
	if c.frames_since(&"hit") < 1e5:
		return "frames_since() before any event should be large"
	for i in 30:
		c.advance(DT)
	c.mark(&"hit", {power = 2})
	for i in 15:
		c.advance(DT)
	if not is_equal_approx(c.since(&"hit"), 0.25):
		return "since: %s" % c.since(&"hit")
	if not is_equal_approx(c.frames_since(&"hit"), 7.5):
		return "frames_since: %s" % c.frames_since(&"hit")
	if c.last_data(&"hit").get("power", 0) != 2:
		return "last_data lost"
	return ""


func test_clock_drives_mk_unchanged() -> String:
	# A reaction from the clock equals the frame-pure curve at the same frame.
	var c := MotionClock.new()
	for i in 10:
		c.advance(DT)
	c.mark(&"hit")
	for i in 9:
		c.advance(DT)
	var want := MK.spring(4.5, 0.0, 9, 220)
	var got := MK.spring(c.frames_since(&"hit"), 0.0, 9, 220)
	if absf(want - got) > 1e-9:
		return "spring %s vs %s" % [got, want]
	var a := MK.shakes(c.frame(), c.frames(&"hit"), 6, 8)
	var b := MK.shakes(19.0 * 0.5, [5.0], 6, 8)
	return "" if a.is_equal_approx(b) else "shakes %s vs %s" % [a, b]


func test_clock_within_and_history() -> String:
	var c := MotionClock.new()
	c.history = 4
	for i in 6:
		c.mark(&"step")
		c.advance(0.1)
	if c.frames(&"step").size() != 4:
		return "history not capped: %d" % c.frames(&"step").size()
	var ages := c.within(&"step", 0.25)
	if ages.size() != 2 or not is_equal_approx(ages[0], 0.1):
		return "within: %s" % ages
	return "" if c.count(&"step", 1.0) == 4 else "count"


func test_clock_freeze_holds_then_eases() -> String:
	var c := MotionClock.new()
	c.freeze(0.1, 0.1)
	var t0 := c.time
	for i in 6:        # 0.1 s at 60 Hz: frozen
		c.advance(DT)
	if c.time - t0 > 1e-9:
		return "time moved during the hold: %s" % (c.time - t0)
	if c.rate() >= 1.0:
		return "rate should be below 1 while easing"
	for i in 6:        # easing back
		c.advance(DT)
	var eased := c.time - t0
	if eased <= 0.0 or eased >= 0.1:
		return "ease step total %s should be between 0 and 0.1" % eased
	for i in 3:
		c.advance(DT)
	if not is_equal_approx(c.rate(), 1.0) or c.is_scaled():
		return "envelope did not end"
	return ""


func test_clock_parent_chain_and_scale() -> String:
	var world := MotionClock.new()
	var hero := MotionClock.new(world)
	var ui := MotionClock.new(world)
	ui.ignore_time_scale = true
	hero.scale = 0.5
	world.freeze(1.0)
	world.advance(DT)
	hero.advance(DT)
	ui.advance(DT)
	if hero.dt != 0.0:
		return "child of a frozen clock moved"
	if not is_equal_approx(ui.dt, DT):
		return "ignore_time_scale clock should not follow its parent"
	world.release()
	hero.advance(DT)
	return "" if is_equal_approx(hero.dt, DT * 0.5) else "scale: %s" % hero.dt


func test_clock_overlapping_envelopes_take_slowest() -> String:
	var c := MotionClock.new()
	c.slow(0.5, 1.0, 0.0)
	c.freeze(0.05)
	c.advance(DT)
	if c.dt != 0.0:
		return "freeze inside a slow-mo should win"
	for i in 10:
		c.advance(DT)
	return "" if is_equal_approx(c.dt, DT * 0.5) else "slow-mo after freeze: %s" % c.dt


func test_clock_tick_once_per_frame() -> String:
	var c := MotionClock.new()
	c.tick(DT)
	c.tick(DT)
	return "" if is_equal_approx(c.time, DT) else "tick ran twice in one frame"


func test_clock_marked_signal() -> String:
	var c := MotionClock.new()
	var got := []
	c.marked.connect(func(e: StringName, d: Dictionary) -> void: got.append([e, d]))
	c.mark(&"land", {h = 1})
	return "" if got.size() == 1 and got[0][0] == &"land" else "signal not emitted"


# ------------------------------------------------------------------ MotionTrauma

func test_trauma_decays_and_squares() -> String:
	var t := MotionTrauma.new(3.0)
	t.add(0.5)
	if not is_equal_approx(t.amount(), 0.25):
		return "amount should be trauma^2"
	t.add(2.0)
	if t.trauma != 1.0:
		return "trauma not clamped"
	for i in 120:
		t.step(DT)
	if t.trauma != 0.0 or t.offset() != Vector2.ZERO or t.roll() != 0.0:
		return "trauma did not decay to still"
	return "" if t.is_still() else "is_still"


func test_trauma_deterministic_and_bounded() -> String:
	var a := MotionTrauma.new(7.0)
	var b := MotionTrauma.new(7.0)
	a.add(1.0)
	b.add(1.0)
	var peak := 0.0
	for i in 30:
		a.step(DT)
		b.step(DT)
		if not a.offset().is_equal_approx(b.offset()):
			return "same seed and steps diverged"
		peak = maxf(peak, absf(a.offset().x))
	if peak > a.max_offset.x + 1e-4:
		return "offset over max: %s" % peak
	var c := MotionTrauma.new(8.0)
	c.add(1.0)
	c.step(DT * 7.0)
	a = MotionTrauma.new(7.0)
	a.add(1.0)
	a.step(DT * 7.0)
	return "" if not c.offset().is_equal_approx(a.offset()) else "seed has no effect"


func test_trauma_kick_direction() -> String:
	var t := MotionTrauma.new()
	t.kick(Vector2(3, 0), 10.0)
	var o := t.offset()
	if o.x < 9.9 or absf(o.y) > 1e-5:
		return "kick should start along +x at full amount: %s" % o
	for i in 60:
		t.step(DT)
	return "" if t.is_still() else "kick did not die out"


# ------------------------------------------------------------------ springs

func test_vector_springs_match_scalar() -> String:
	var s := MotionSpring.new(0.0, 9, 180)
	var s2 := MotionSpring2D.new(Vector2.ZERO, 9, 180)
	var s3 := MotionSpring3D.new(Vector3.ZERO, 9, 180)
	s.target = 1.0
	s2.target = Vector2(1.0, -2.0)
	s3.target = Vector3(1.0, 0.0, 3.0)
	for i in 40:
		var v := s.step(DT)
		var v2 := s2.step(DT)
		var v3 := s3.step(DT)
		if absf(v2.x - v) > 1e-5 or absf(v2.y + 2.0 * v) > 1e-5:
			return "2D off at step %d" % i
		if absf(v3.z - 3.0 * v) > 1e-5 or absf(v3.y) > 1e-9:
			return "3D off at step %d" % i
	return ""


func test_spring_impulse_and_settle() -> String:
	var s := MotionSpring2D.new(Vector2.ZERO, 8, 200)
	s.impulse(Vector2(5, 0))
	var peak := 0.0
	for i in 240:
		peak = maxf(peak, s.step(DT).x)
	if peak <= 0.0:
		return "impulse did not move it"
	return "" if s.is_settled() else "did not settle back"


func test_spring_coefficients_identity_at_zero() -> String:
	var c := MotionSpring.coefficients(0.0, 10, 140)
	return "" if is_equal_approx(c[0], 1.0) and is_zero_approx(c[1]) and is_zero_approx(c[2]) and is_equal_approx(c[3], 1.0) else "%s" % c


# ------------------------------------------------------------------ materials and meshes

func test_instanced_and_cutout_materials() -> String:
	var flat := MotionFlat3D.new()
	var m := flat.material(Color.WHITE, Color.GRAY, Color.DIM_GRAY, Color(0, 0, 0, 0), 0.0, true, false, true)
	var cut := flat.cutout()
	for mat: ShaderMaterial in [m, cut]:
		if mat.shader == null or mat.shader.get_code().is_empty():
			return "shader missing"
	if not flat.fixed.has(cut):
		return "cutout should be out of group motion"
	var names := []
	for u in RenderingServer.get_shader_parameter_list(cut.shader.get_rid()):
		names.append(u.name)
	# instance uniforms are not material parameters
	if names.has("flash") or names.has("tint"):
		return "flash/tint should be instance uniforms on the cutout shader"
	var plain := flat.material(Color.WHITE, Color.GRAY, Color.DIM_GRAY)
	var pnames := []
	for u in RenderingServer.get_shader_parameter_list(plain.shader.get_rid()):
		pnames.append(u.name)
	if not pnames.has("flash"):
		return "the plain material should keep its per-material flash"
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = cut
	MotionFlat3D.set_flash(mi, Color.WHITE, 0.6)
	var got: Variant = mi.get_instance_shader_parameter(&"flash")
	mi.free()
	return "" if got is Color and is_equal_approx((got as Color).a, 0.6) else "set_flash: %s" % got


func test_svg_mesh_flat_cards() -> String:
	var svg := '<svg viewBox="0 0 100 100"><rect id="a" x="0" y="0" width="100" height="100" fill="#ff0000"/><circle id="b" cx="50" cy="50" r="20" fill="#0000ff"/></svg>'
	var data := MotionSvgData.from_string(svg)
	var flat := MotionSvgMesh.build(data, 1.0, {flat = true, depth = 0.0, layer = 0.01})
	var solid := MotionSvgMesh.build(data, 1.0, {depth = 0.1})
	var fv: PackedVector3Array = flat.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sv: PackedVector3Array = solid.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if fv.size() * 2 >= sv.size():
		return "flat mesh should have caps only (%d vs %d)" % [fv.size(), sv.size()]
	var zs := {}
	for v in fv:
		zs[snappedf(v.z, 1e-4)] = true
	if zs.size() != 2 or not zs.has(0.0) or not zs.has(0.01):
		return "parts should sit at i * layer: %s" % zs.keys()
	var edges := MotionEdges3D.from_mesh(flat)
	return "" if edges.get_surface_count() > 0 else "no outline edges for flat cards"


# ------------------------------------------------------------------ IK

func test_ik_2d_reaches_and_keeps_lengths() -> String:
	for tgt in [Vector2(1.2, 0.3), Vector2(-0.4, -0.9), Vector2(0.1, 1.5)]:
		var s := MotionIK.two_bone_2d(Vector2.ZERO, tgt, 1.0, 0.8, 1.0)
		var mid: Vector2 = s.mid
		var end: Vector2 = s.end
		if not s.reached or end.distance_to(tgt) > 1e-4:
			return "did not reach %s" % tgt
		if absf(mid.length() - 1.0) > 1e-4 or absf(mid.distance_to(end) - 0.8) > 1e-4:
			return "bone lengths changed for %s" % tgt
		var cross: float = tgt.x * mid.y - tgt.y * mid.x
		if cross <= 0.0:
			return "bend +1 should put the joint counter-clockwise of the line"
	var far := MotionIK.two_bone_2d(Vector2.ZERO, Vector2(5, 0), 1.0, 0.8)
	if far.reached or ((far.end as Vector2) - Vector2(1.8, 0)).length() > 1e-3:
		return "out of reach should straighten toward the target"
	return ""


func test_ik_3d_bends_toward_pole() -> String:
	var s := MotionIK.two_bone_3d(Vector3.ZERO, Vector3(0, -1.2, 0), Vector3(0, -0.6, 2.0), 0.7, 0.7)
	var mid: Vector3 = s.mid
	if mid.z <= 0.1:
		return "knee should point at the pole: %s" % mid
	if absf(mid.length() - 0.7) > 1e-4 or ((s.end as Vector3) - Vector3(0, -1.2, 0)).length() > 1e-4:
		return "solve off: %s" % s
	return ""


func test_aim_spring_short_way_and_limits() -> String:
	var a := MotionAimSpring.new(deg_to_rad(170.0), 14, 200)
	a.target = deg_to_rad(-170.0)
	for i in 120:
		a.step(DT)
	if absf(wrapf(a.value - deg_to_rad(-170.0), -PI, PI)) > 1e-3 or a.value < PI * 0.9:
		return "should turn the short way across +-180: %s" % rad_to_deg(a.value)
	var h := MotionAimSpring.new(0.0, 12, 160)
	h.limit_min = -0.25
	h.limit_max = 0.25
	h.target = 1.5
	for i in 120:
		h.step(DT)
	return "" if is_equal_approx(h.value, 0.25) else "limit not held: %s" % h.value


# ------------------------------------------------------------------ cutout rig

const RIG_SVG := """<svg viewBox="0 0 100 200">
<g id="hips"><circle id="pivot-hips" cx="50" cy="120" r="1" fill="none"/>
  <g id="thigh"><circle id="pivot-thigh" cx="50" cy="120" r="1" fill="none"/>
    <rect x="45" y="120" width="10" height="30" fill="#334455"/>
    <g id="shin"><circle id="pivot-shin" cx="50" cy="150" r="1" fill="none"/>
      <rect x="46" y="150" width="8" height="30" fill="#334455"/>
      <g id="foot"><circle id="pivot-foot" cx="50" cy="180" r="1" fill="none"/>
        <rect x="44" y="180" width="16" height="8" fill="#553322"/></g></g></g>
  <rect id="torso" x="30" y="60" width="40" height="60" fill="#44aa66"/>
  <circle id="eye" class="flat" cx="50" cy="80" r="3" fill="#000000"/>
</g>
<rect id="loose" x="0" y="190" width="5" height="5" fill="#ffffff"/>
</svg>"""


func _rig() -> MotionCutoutRig:
	var flat := MotionFlat3D.new()
	return MotionCutoutRig.build(MotionSvgData.from_string(RIG_SVG), 1.0, flat.cutout(), flat.edges(), {origin = Vector2(50, 188)})


func test_rig_hierarchy_and_pivots() -> String:
	var rig := _rig()
	var ok := ""
	if rig.parent_of.get(&"shin") != &"thigh" or rig.parent_of.get(&"thigh") != &"hips" or rig.parent_of.get(&"hips") != &"":
		ok = "hierarchy: %s" % rig.parent_of
	elif rig.part(&"foot").get_parent() != rig.part(&"shin"):
		ok = "nodes not nested"
	elif not rig.rest_pivot(&"shin").is_equal_approx(Vector3(0, 0.38, 0)):
		ok = "shin pivot %s" % rig.rest_pivot(&"shin")
	elif not rig.meshes.has(&"") or not rig.meshes.has(&"hips"):
		ok = "root and hips should own shapes"
	elif rig.meshes.has(&"pivot-hips"):
		ok = "markers must not draw"
	rig.free()
	return ok


func test_rig_mesh_sits_on_pivot() -> String:
	var rig := _rig()
	var m: ArrayMesh = (rig.meshes[&"foot"] as MeshInstance3D).mesh
	var aabb := m.get_aabb()
	# foot rect spans x 44..60, y 180..188 around pivot (50, 180): x -0.06..0.10, y -0.08..0
	var ok := aabb.position.is_equal_approx(Vector3(-0.06, -0.08, aabb.position.z)) and is_equal_approx(aabb.size.x, 0.16)
	var flat_out := not rig.outlines.has(&"") or true
	rig.free()
	return "" if ok and flat_out else "foot mesh not around its pivot: %s" % aabb


func test_rig_solve_limb_reaches() -> String:
	var rig := _rig()
	rig.pose(&"hips", 0.0, Vector2(0, -0.1))           # crouch: the foot target stays
	var target := rig.rest_pivot(&"foot") + Vector3(0.05, 0.02, 0)
	var reached := rig.solve_limb(&"thigh", &"shin", &"foot", target, -1.0)
	var got := rig.rig_transform(&"foot").origin
	var res := ""
	if not reached or Vector2(got.x - target.x, got.y - target.y).length() > 1e-4:
		res = "foot at %s, wanted %s" % [got, target]
	elif rig.rig_transform(&"shin").origin.x >= rig.rig_transform(&"thigh").origin.x:
		res = "bend -1 should push the knee to -x here"
	rig.free()
	return res


func test_cutout_view_choice_and_turn() -> String:
	if MotionCutout.choose(Vector2(1, 0), &"front") != &"side":
		return "sideways should be side"
	if MotionCutout.choose(Vector2(0, 1), &"side") != &"front":
		return "toward the camera should be front"
	if MotionCutout.choose(Vector2(0, -1), &"side") != &"back":
		return "away should be back"
	var diag := Vector2(1, 1.1)      # just past 45 degrees
	if MotionCutout.choose(diag, &"side") != &"side" or MotionCutout.choose(diag, &"front") != &"front":
		return "hysteresis should keep the current view on a diagonal"
	var cut := MotionCutout.new()
	cut.add_view(&"front", _rig())
	cut.add_view(&"side", _rig())
	var swapped := []
	cut.view_changed.connect(func(v: StringName, m: bool) -> void: swapped.append([v, m]))
	cut.face(Vector2(-1, 0))
	var min_w := 1.0
	for i in 60:
		cut.step(DT)
		min_w = minf(min_w, absf(cut.flip.scale.x))
	var res := ""
	if swapped.size() != 1 or swapped[0] != [&"side", true]:
		res = "view changes: %s" % [swapped]
	elif min_w > 0.25:   # crosses zero between steps on a flip
		res = "the card never went edge-on (%s)" % min_w
	elif absf(cut.flip.scale.x + 1.0) > 0.02:
		res = "should settle mirrored: %s" % cut.flip.scale.x
	cut.free()
	return res


# ------------------------------------------------------------------ gait

func test_gait_alternates_and_plants() -> String:
	var g := MotionGait.new()
	var plants := []
	g.planted.connect(func(i: int, p: Vector3) -> void: plants.append([i, p]))
	g.reset(Vector3.ZERO, Vector3(1, 0, 0))
	var at := Vector3.ZERO
	var vel := Vector3(3.0, 0, 0)
	var held := {}
	for f in 180:
		at += vel * DT
		var before := [g.foot(0), g.foot(1)]
		g.step(DT, at, vel, Vector3(1, 0, 0))
		if not g.is_planted(0) and not g.is_planted(1):
			return "both feet in the air at frame %d" % f
		for i in 2:
			if g.is_planted(i) and g.progress(i) < 0.0 and held.get(i, false):
				if g.foot(i).distance_to(before[i]) > 1e-6:
					return "a planted foot slid at frame %d" % f
			held[i] = g.is_planted(i)
	if plants.size() < 6:
		return "too few steps: %d" % plants.size()
	for k in range(1, plants.size()):
		if plants[k][0] == plants[k - 1][0]:
			return "the same foot stepped twice in a row"
	var last: Vector3 = plants[-1][1]
	if absf(last.x - at.x) > 0.4:
		return "feet fell behind the body: foot %s body %s" % [last.x, at.x]
	return ""


func test_gait_settles_and_freezes() -> String:
	var g := MotionGait.new()
	g.reset(Vector3.ZERO, Vector3(1, 0, 0))
	var at := Vector3.ZERO
	for f in 40:
		at += Vector3(3, 0, 0) * DT
		g.step(DT, at, Vector3(3, 0, 0), Vector3(1, 0, 0))
	for f in 90:
		g.step(DT, at, Vector3.ZERO, Vector3(1, 0, 0))
	for i in 2:
		var h := g.home(i, at, Vector3.ZERO, Vector3(1, 0, 0))
		if Vector2(g.foot(i).x - h.x, g.foot(i).z - h.z).length() > g.settings.settle_distance + 1e-4:
			return "foot %d did not settle home" % i
	var snap := [g.foot(0), g.foot(1)]
	g.step(0.0, at + Vector3(1, 0, 0), Vector3(3, 0, 0), Vector3(1, 0, 0))
	if not g.foot(0).is_equal_approx(snap[0]):
		return "a zero step (hit-stop) moved a foot"
	return ""


func test_cutout_ground_to_card() -> String:
	var cut := MotionCutout.new()
	cut.lean(50.0, 20.0)
	var a := cut.ground_to_card(Vector3(0.1, 0, 0))
	var b := cut.ground_to_card(Vector3(0, 0, 1.0))
	var c := cut.ground_to_card(Vector3(0, 1.0, 0))
	cut.free()
	if not a.is_equal_approx(Vector3(0.1, 0, 0)):
		return "x: %s" % a
	if not is_equal_approx(b.y, -sin(deg_to_rad(50.0))):
		return "toward the camera should go down the card: %s" % b
	return "" if is_equal_approx(c.y, cos(deg_to_rad(50.0))) else "height: %s" % c


# ------------------------------------------------------------------ chain, squash, ribbon

func _seg_lengths(c: MotionChain) -> Array:
	var out := []
	for i in range(1, c.points.size()):
		out.append(c.points[i].distance_to(c.points[i - 1]))
	return out


func test_chain_hangs_and_keeps_length() -> String:
	var c := MotionChain.new(8, 0.05, Transform3D.IDENTITY, Vector3(1, 0, 0))
	for i in 240:
		c.step(DT, Transform3D.IDENTITY)
	var tip := c.points[7]
	if tip.y > -0.3 or absf(tip.x) > 0.05:
		return "should hang straight down after settling: %s" % tip
	for l in _seg_lengths(c):
		if absf(l - 0.05) > 0.003:
			return "segment length drifted: %s" % l
	return ""


func test_chain_trails_with_drag_and_freezes() -> String:
	var c := MotionChain.new(8, 0.05)
	c.drag = 4.0
	c.medium_velocity = Vector3(-4.0, 0, 0)       # the body runs +x: air comes from the front
	for i in 120:
		c.step(DT, Transform3D.IDENTITY)
	if c.points[7].x > -0.1:
		return "should trail behind (-x): %s" % c.points[7]
	var snap := c.points.duplicate()
	c.step(0.0, Transform3D(Basis(), Vector3(1, 0, 0)))
	if c.points != snap:
		return "a zero step moved the chain"
	var r := c.render_points(0.5)
	return "" if r[3].is_equal_approx(snap[3]) else "render points off after a frozen step"


func test_chain_shape_memory_follows_root_turn() -> String:
	var c := MotionChain.new(6, 0.05, Transform3D.IDENTITY, Vector3(1, 0, 0))
	c.gravity = Vector3.ZERO
	c.stiffness = 0.8
	var turned := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)   # rest dir now +y
	for i in 120:
		c.step(DT, turned)
	return "" if c.points[5].y > 0.2 else "shape memory should swing the chain round: %s" % c.points[5]


func test_chain_mirror_and_floor() -> String:
	var c := MotionChain.new(5, 0.1, Transform3D.IDENTITY, Vector3(1, -1, 0))
	var x_before := c.points[4].x
	c.mirror_x()
	if not is_equal_approx(c.points[4].x, -x_before) or c.rest_dirs[1].x >= 0.0:
		return "mirror_x"
	c.floor_y = -0.15
	for i in 120:
		c.step(DT, Transform3D.IDENTITY)
	for p in c.points:
		if p.y < -0.15 - 1e-4:
			return "point under the floor: %s" % p
	return ""


func test_squash_preserves_area_and_settles() -> String:
	var s2 := MotionSquash.scale_for(0.3, 2)
	var s3 := MotionSquash.scale_for(-0.2, 3)
	if absf(s2.x * s2.y - 1.0) > 1e-6 or absf(s3.x * s3.x * s3.y - 1.0) > 1e-6:
		return "area / volume not kept"
	var sq := MotionSquash.new()
	sq.impulse(4.0)
	var peak := 0.0
	for i in 120:
		peak = maxf(peak, sq.step(DT).y)
	if peak <= 1.01:
		return "impulse did not stretch"
	if absf(sq.step(DT).y - 1.0) > 1e-3:
		return "did not settle"
	if absf(MotionSquash.land(0.0, -0.2) + 0.2) > 1e-6 or absf(MotionSquash.land(200.0, -0.2)) > 1e-3:
		return "land curve ends"
	return ""


func test_ribbon_builds_strip_with_outline() -> String:
	var r := MotionRibbon3D.new()
	r.update(PackedVector3Array([Vector3.ZERO, Vector3(0, -0.1, 0), Vector3(0.05, -0.2, 0)]))
	var im := r.mesh as ImmediateMesh
	var verts: int = (im.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	r.free()
	return "" if verts == 2 * 2 * 6 else "expected 24 vertices (outline + strip), got %d" % verts


# ------------------------------------------------------------------ pose curves

func _curve() -> MotionPoseCurve:
	var c := MotionPoseCurve.new()
	c.length = 18.0
	c.channels = {
		"arc": {keys = [0.0, 3.0, 6.0, 18.0], values = [40.0, 135.0, -45.0, -58.0], ease = "ease_out"},
		"arc.front": {keys = [0.0, 6.0], values = [100.0, -80.0], ease = "linear"},
		"lunge": {keys = [0.0, 6.0], values = [Vector2.ZERO, Vector2(0.1, 0.0)], ease = ["ease_in_out"]},
		"twist": {keys = [0.0, 4.0, 8.0], values = [0.0, 10.0, 0.0], ease = ["linear", [0.25, 0.1, 0.25, 1.0]]},
	}
	c.markers = {"active_from": 3, "active_to": 7, "cancel": 9}
	return c


func test_pose_curve_samples_keys_and_eases() -> String:
	var c := _curve()
	if c.sample(&"arc", -5.0) != 40.0 or c.sample(&"arc", 3.0) != 135.0 or c.sample(&"arc", 99.0) != -58.0:
		return "keys / holds wrong"
	var mid: float = c.sample(&"arc", 1.5)
	var want := lerpf(40.0, 135.0, MK.ease_out.call(0.5))
	if absf(mid - want) > 1e-6:
		return "ease_out segment: %s vs %s" % [mid, want]
	if not is_equal_approx(float(c.sample(&"arc", 3.0, &"front")), 100.0 - 180.0 * 0.5):
		return "view override not used"
	if c.sample(&"arc", 3.0, &"side") != 135.0:
		return "a view without an override should use the base channel"
	var l: Vector2 = c.sample(&"lunge", 3.0)
	if not l.is_equal_approx(Vector2(0.05, 0.0)):
		return "vector channel: %s" % l
	var tw: float = c.sample(&"twist", 6.0)
	if absf(tw - lerpf(10.0, 0.0, MK.bezier(0.25, 0.1, 0.25, 1.0).call(0.5))) > 1e-6:
		return "per-segment bezier ease"
	return "" if c.sample(&"missing", 1.0, &"", 7.0) == 7.0 else "fallback"


func test_pose_curve_markers_and_blend() -> String:
	var c := _curve()
	if not c.between(5.0, &"active_from", &"active_to") or c.between(8.0, &"active_from", &"active_to"):
		return "between"
	if c.marker(&"nope", -2.0) != -2.0 or c.marker(&"cancel") != 9.0:
		return "marker"
	var d := _curve()
	d.channels["arc"] = {keys = [0.0], values = [0.0]}
	d.changed_channels()
	var b: float = c.blend(d, 0.25, &"arc", 3.0, 0.0)
	return "" if is_equal_approx(b, 135.0 * 0.75) else "blend: %s" % b


# ------------------------------------------------------------------ ripples and grass

func test_ripples_run_out_and_expire() -> String:
	var r := MotionRipples.new()
	r.add(Vector3(0, 0, 0), 1.0)
	r.step(0.5)                      # the front is now 1.5 m out
	var on := r.offset(Vector2(1.5, 0))
	var off := r.offset(Vector2(0.3, 0))
	if on.z <= 0.1 or off.z > 1e-3:
		return "ring front not where expected: on %s off %s" % [on, off]
	if on.x <= 0.0:
		return "push should point away from the centre"
	var u := r.uniforms()
	if u.size() != MotionRipples.MAX or not is_equal_approx(u[0].z, 0.5) or u[1].z >= 0.0:
		return "uniforms: %s" % [u.slice(0, 2)]
	r.step(5.0)
	return "" if r.count() == 0 else "old rings should be dropped"


func test_ripples_keep_newest_sixteen() -> String:
	var r := MotionRipples.new()
	for i in 20:
		r.add(Vector2(i, 0), 1.0)
		r.step(0.01)
	var u := r.uniforms()
	return "" if r.count() == 16 and is_equal_approx(u[0].x, 4.0) else "kept %d, first %s" % [r.count(), u[0]]


func test_grass_field_scatter_and_mask() -> String:
	var g := MotionGrass3D.field(Rect2(0, 0, 4, 4), 5.0, Color.GREEN, 3, func(p: Vector2) -> bool: return p.x < 2.0)
	var n := g.multimesh.instance_count
	var ok := ""
	if n < 25 or n > 55:
		ok = "about 40 tufts expected on half of 16 m2 at 5/m2, got %d" % n
	else:
		for i in n:
			if g.multimesh.get_instance_transform(i).origin.x >= 2.0:
				ok = "the mask was ignored"
				break
	var params := []
	for u in RenderingServer.get_shader_parameter_list((g.material_override as ShaderMaterial).shader.get_rid()):
		params.append(u.name)
	if ok == "" and not params.has("mk_ripples"):
		ok = "grass shader should read the ripple uniforms"
	g.free()
	return ok


# ------------------------------------------------------------------ consolidation helpers

func test_perf_probe_window() -> String:
	MotionPerfProbe.reset()
	for i in 3:
		var t := MotionPerfProbe.begin()
		var x := 0.0
		for k in 2000:
			x += sqrt(float(k))
		MotionPerfProbe.end(&"work", t)
		MotionPerfProbe.end_frame()
	var st := MotionPerfProbe.stats()
	if not st.has(&"work") or (st[&"work"] as Vector2).y <= 0.0:
		return "no timing recorded: %s" % st
	var rep := MotionPerfProbe.report()
	MotionPerfProbe.reset()
	return "" if rep.size() == 2 and rep[1].contains("total") else "report: %s" % rep


func test_cutout_card_and_warmup_collect() -> String:
	var flat := MotionFlat3D.new()
	var data := MotionSvgData.from_string(RIG_SVG)
	var card := MotionCutoutRig.card(data, 0.5, flat.cutout(), flat.edges())
	var root := Node3D.new()
	root.add_child(card)
	var rig := _rig()
	root.add_child(rig)
	var mats := MotionWarmup.collect(root)
	var res := ""
	if card.get_node_or_null("Outline") == null:
		res = "card has no outline"
	elif mats.size() < 4:      # card cutout + its edges, rig cutout + rig edges
		res = "collect found %d materials" % mats.size()
	root.free()
	return res
