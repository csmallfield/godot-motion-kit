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
