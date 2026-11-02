# SPDX-License-Identifier: Apache-2.0
# LIVE EXAMPLE: the kit's live-game layer in one small scene, no game code
# needed. A cutout walker (one SVG rig, mirrored) circles a post on an
# outlined tile of grass. Every few seconds it bonks the post: an authored
# arm swing (MotionPoseCurve), hit-stop on both (MotionClock.freeze), trauma
# shake with a kick (MotionTrauma), the post wobbling on a spring
# (MotionSpring2D), a squash (MotionSquash), a ring through the grass
# (MotionRipples + MotionGrass3D). Its feet plant (MotionGait), its scarf
# trails (MotionChain + MotionRibbon3D), its head turns to the post
# (MotionAimSpring), and an overlay shows each system's script cost
# (MotionPerfProbe). Cutout Isle (csmallfield/cutout-isle) is the full game.
extends Node3D

const PITCH := 50.0
const WALKER := "res://demo/live/walker.svg"

var world := MotionClock.new()
var flat := MotionFlat3D.new()
var ripples := MotionRipples.new()
var trauma := MotionTrauma.new(3.0)
var lens: MotionLens3D
var camera: Camera3D
var grass: MultiMeshInstance3D

var walker: CharacterBody3D
var w_clock: MotionClock
var cut: MotionCutout
var gait: MotionGait
var squash := MotionSquash.new()
var head := MotionAimSpring.new(0.0, 11.0, 150.0)
var scarf := MotionChain.new(8, 0.04)
var ribbon := MotionRibbon3D.new()
var bonk: MotionPoseCurve

var post: Node3D
var p_clock: MotionClock
var wobble := MotionSpring2D.new(Vector2.ZERO, 3.0, 80.0)
var label: Label
var _angle := 0.0


func _ready() -> void:
	flat.light = Vector3(-0.55, 0.0, 0.83)
	var cutout := flat.cutout()
	var ink := flat.edges(Color("#1b1622"), 2.6, 0.001)
	var ink_world := flat.edges(Color("#1b1622"), 2.2, 0.03)

	# ground: an outlined tile, and grass that reacts
	var st := MotionFlat3D.begin()
	var edges := MotionEdges3D.new()
	MotionFlat3D.box(st, Vector3(-5, -1, -5), Vector3(10, 1, 10), Vector2.ZERO, Color.WHITE, edges)
	add_child(MotionFlat3D.instance(st.commit(), flat.material(Color("#8fcf6a"), Color("#b98a5a"), Color("#8a603d"), Color(0, 0, 0, 0), 0.0, false)))
	add_child(MotionFlat3D.instance(edges.commit(), ink_world))
	grass = MotionGrass3D.field(Rect2(-4.8, -4.8, 9.6, 9.6), 4.0, Color("#6cb853"), 3,
		func(p: Vector2) -> bool: return p.length() > 0.5)
	add_child(grass)
	ripples.register(grass.material_override as ShaderMaterial)
	flat.register(grass.material_override as ShaderMaterial, false)

	# the post: a faceted cylinder that wobbles on a spring
	p_clock = MotionClock.new(world)
	post = Node3D.new()
	add_child(post)
	var ps := MotionFlat3D.begin()
	var pe := MotionEdges3D.new()
	MotionFlat3D.cylinder(ps, Vector3.ZERO, 0.12, 1.1, Vector2.ZERO, Color("#c58b52"), pe, 8)
	MotionFlat3D.cylinder(ps, Vector3(0, 0.6, 0), 0.26, 0.45, Vector2.ZERO, Color("#e2c27a"), pe, 10)
	var white := flat.material(Color.WHITE, Color(0.86, 0.86, 0.86), Color(0.66, 0.66, 0.68), Color(0, 0, 0, 0), 0.0, false, false, true)
	post.add_child(MotionFlat3D.instance(ps.commit(), white))
	post.add_child(MotionFlat3D.instance(pe.commit(), ink_world))

	# the walker: one side-view rig, mirrored for the other side
	w_clock = MotionClock.new(world)
	walker = CharacterBody3D.new()
	add_child(walker)
	cut = MotionCutout.new()
	walker.add_child(cut)
	# a character gets its own actor material (flash and tint as plain uniforms)
	cut.add_view(&"side", MotionCutoutRig.build(MotionSvgData.load_any(WALKER), 0.6, flat.actor(), ink, {origin = Vector2(80, 230)}))
	cut.lean(PITCH, 20.0)
	gait = MotionGait.new()
	gait.settings.hip_width = 0.05
	gait.planted.connect(func(_i: int, p: Vector3) -> void: ripples.add(p, 0.25))
	ribbon.material_override = cutout
	ribbon.color = Color("#d8433b")
	ribbon.width_from = 0.045
	ribbon.width_to = 0.025
	ribbon.position.z = -0.004
	cut.flip.add_child(ribbon)
	scarf.drag = 3.0
	scarf.gravity = Vector3(0, -4.5, 0)
	cut.view_changed.connect(func(_v: StringName, _m: bool) -> void: scarf.mirror_x())

	# the bonk: an arm angle around the shoulder, authored as keys
	bonk = MotionPoseCurve.new()
	bonk.length = 16.0
	bonk.channels = {
		"arc": {keys = [0.0, 4.0, 7.0, 16.0], values = [-80.0, 120.0, -30.0, -80.0], ease = "ease_out"},
		"weight": {keys = [0.0, 2.0, 12.0, 16.0], values = [0.0, 1.0, 1.0, 0.0], ease = "ease_in_out"},
		"squash": {keys = [0.0, 3.0, 6.0, 12.0], values = [0.0, -0.08, 0.1, 0.0], ease = "ease_out"},
	}
	bonk.markers = {"hit": 6.0}

	camera = Camera3D.new()
	add_child(camera)
	lens = MotionLens3D.extrude(0.0, PITCH, 1080.0 / 3.4, Vector3(0, 0.45, 0))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#3a8fae")
	add_child(env)
	label = Label.new()
	label.position = Vector2(16, 12)
	var hud := CanvasLayer.new()
	hud.add_child(label)
	add_child(hud)
	scarf.teleport(_neck())


func _neck() -> Transform3D:
	var rig := cut.rig
	return Transform3D(Basis(), rig.rig_transform(&"torso") * (rig.svg_to_local(Vector2(70, 100)) - rig.rest_pivot(&"torso")))


func _physics_process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	var dt := delta * w_clock.rate()
	var f := w_clock.frames_since(&"bonk")
	var bonking := f < bonk.length
	# circle the post; every few seconds, stop and bonk it
	if not bonking and w_clock.since(&"bonk") > 2.2 and absf(fmod(_angle, TAU / 3.0)) < 0.05:
		w_clock.mark(&"bonk")
	if not bonking:
		_angle += dt * 0.9
	var goal := Vector3(cos(_angle), 0, sin(_angle)) * 1.0
	var v := (goal - walker.position) * 4.0
	v.y = 0.0
	walker.velocity = v * w_clock.rate()
	walker.move_and_slide()
	walker.velocity = v
	# the hit lands on the bonk's marker frame
	if bonking and f >= bonk.marker(&"hit") and w_clock.last_data(&"bonk").get("landed") == null:
		w_clock.last_data(&"bonk")["landed"] = true
		var dir := (post.position - walker.position).normalized()
		w_clock.freeze(0.07, 0.04)
		p_clock.freeze(0.07, 0.04)
		p_clock.mark(&"hit")
		wobble.impulse(Vector2(dir.x, dir.z) * 5.0)
		trauma.add(0.3)
		trauma.kick(camera.unproject_position(post.position + dir) - camera.unproject_position(post.position), 9.0)
		ripples.add(post.position, 1.2)
		squash.impulse(-2.5)
	var face := (post.position - walker.position) if bonking else Vector3(-sin(_angle), 0, cos(_angle))
	gait.step(dt, walker.position, walker.velocity, face)
	scarf.medium_velocity = -cut.ground_to_card(walker.velocity)
	scarf.step(dt, _neck())
	MotionPerfProbe.end(&"physics", t)


func _process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	world.tick(delta)
	w_clock.tick(delta)
	p_clock.tick(delta)
	var f := w_clock.frames_since(&"bonk")
	var face := (post.position - walker.position) if f < bonk.length else Vector3(-sin(_angle), 0, cos(_angle))
	cut.face(Vector2(face.x, face.z))
	cut.step(w_clock.dt)
	var rig := cut.rig
	rig.reset_pose()
	rig.pose(&"hips", 0.0, Vector2(0, gait.body.y))
	var frac := Engine.get_physics_interpolation_fraction()
	for side in [["l", 0], ["r", 1]]:
		var off := cut.ground_to_card(gait.foot(side[1], frac) - walker.position)
		var rest := rig.rest_pivot(StringName("foot_" + side[0]))
		rig.solve_limb(StringName("leg_%s_upper" % side[0]), StringName("leg_%s_lower" % side[0]), StringName("foot_" + side[0]),
			Vector3(off.x, rest.y + off.y, 0), 1.0)
	var w := float(bonk.sample(&"weight", f))
	var phi := bonk.sample_deg(&"arc", f)
	var sh := rig.rig_transform(&"torso") * (rig.rest[&"arm_upper"] as Transform3D).origin
	var reach := (rig.rest_pivot(&"hand") - rig.rest_pivot(&"arm_upper")).length() * 0.97
	var hand := rig.rest_pivot(&"hand").lerp(sh + Vector3(cos(phi), sin(phi), 0) * reach, w)
	rig.solve_limb(&"arm_upper", &"arm_lower", &"hand", hand, -1.0)
	head.limit_min = -0.2
	head.limit_max = 0.2
	head.target = 0.15 if f < bonk.length else 0.0
	rig.pose(&"head", head.step(w_clock.dt))
	squash.step(w_clock.dt)
	var s := MotionSquash.scale_for(squash.amount() + float(bonk.sample(&"squash", f)))
	cut.scale = Vector3(s.x, s.y, 1)
	ribbon.update(scarf.render_points(frac))
	# the post
	wobble.step(p_clock.dt)
	post.rotation = Vector3(wobble.value.y * 0.25, 0, -wobble.value.x * 0.25)
	MotionFlat3D.set_flash((post.get_child(0) as GeometryInstance3D), Color("#fff4d8"), 0.7 * exp(-p_clock.frames_since(&"hit") / 1.6))
	# camera, ground, look
	trauma.step(delta)
	lens.offset = trauma.offset()
	lens.basis = MotionLens3D.extrude_basis(0.0, PITCH) * Basis(Vector3.BACK, trauma.roll())
	lens.apply(camera)
	ripples.step(delta)
	ripples.apply()
	MotionGrass3D.tick(grass, world.time)
	flat.apply()
	MotionPerfProbe.end(&"render", t)
	MotionPerfProbe.end_frame()
	label.text = "\n".join(MotionPerfProbe.report())
