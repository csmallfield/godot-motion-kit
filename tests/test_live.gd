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
