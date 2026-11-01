# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take: NIGHT CIRCUIT (Gantry x Checkerboard City).
#
# Brief: the Gantry camera flight, but the neon circuit is an elevated skyway
# over an endless checkerboard world at dusk. Real 3D in a MotionStage3D: the
# board is a pattern material on a ground plane inside the stage (so depth,
# occlusion and fog match the track), the sky a dome with a banded OutRun sun
# sitting on the horizon dead ahead. Checker skyscrapers line the circuit,
# the gantries are checkered, the track's edge strips are FTF pink / cyan with
# a lime centre line.
#   I   Black. The circuit powers up one beat at a time: the barrier strips
#       chase out toward the sun while the dusk comes up. The camera creeps
#       off the start line toward the first gantry, which carries the MINIMAL
#       HUMANS lockup framed against the sun: it strikes on at 30 and stays
#       readable for ~2.5 s while PRESENTS types across the beam and two
#       rival ships streak past underneath. Launch on bar 2, duck under it.
#   II  Full speed through a banked S-bend between checker towers, a checkered
#       sponsor gantry overhead on every beat; out of it onto the long
#       straight, the sun dead ahead...
#   III ...and on the drop the FULL THROTTLE FLUX sign, a huge extruded logo
#       on checkered pillars, punches up out of the board straddling the
#       skyway and slams to its full height already filling the frame, a
#       shockwave racing out through the checks. It travels with us for the
#       hold: the board races under, towers stream past, the strips pulse on
#       every beat, ships streak under the sign. Then the lights cut from the
#       far end toward us, the sign drifts off toward the sun and cuts, the
#       sun sinks under the horizon: black.
#
# Tempo: 150 bpm = 12 frames a beat, 48 a bar; first downbeat on frame 0.
# Beats (30 fps, 420 frames):
#   0/12/24/36  power-up: strip chase steps out; dusk fades up; HUD types from 14
#   30      MH lockup strikes on (readable ~30-106)
#   48      PRESENTS types along the beam (bar 1)
#   60/78   two rival ships overtake under the MH gantry
#   84      engine spool; 96 LAUNCH (bar 2, FOV kick)
#   110     under the MH gantry
#   120/132/144/156  checkered sponsor gantries overhead (S-bend)
#   176     the board ahead cracks: the FTF sign starts to rise
#   192     DROP (bar 4): sign up, slam, shockwave, strips flare, zoom punch
#   192-336 hold: sign rides ahead; strips/pads pulse every beat; rings 240/288;
#           callouts pin at 216/222; ships under the sign at 240/276/312
#   336/348/360  lights cut far to near (bar 7); the sun sinks 336-390
#   372     sign cuts; the dusk and the sun are gone by ~386 (black); 420 end
#
# Sound: cue sheet in _init (the engine is one cue whose pitch and level
# curves come from the same speed profile as the camera);
# demo/ftf/ftf_nightcircuit/audio/make.py writes the recipes and a 150 bpm
# song, tools/bake_audio.gd bakes them.
@tool
extends MotionComposition

const NB := preload("res://demo/ftf/ftf_nightcircuit/nightcircuit_build.gd")

const BPM := 150.0
const BEAT := 1800.0 / BPM          # frames per beat at 30 fps
const BAR := 4.0 * BEAT
const POWER := [0.0, 12.0, 24.0, 36.0]
const HUD_IN := 14.0
const MH_ON := 30.0
const PRESENTS := 48.0
const OVERTAKE := [60.0, 78.0]
const SPOOL := 84.0
const LAUNCH := 96.0
const MH_PASS := 110.0
const GATES := [120.0, 132.0, 144.0, 156.0]
const RISE := 176.0
const DROP := 192.0
const RINGS := [192.0, 240.0, 288.0]
const CALLOUTS := [216.0, 222.0]
const SHIPS := [240.0, 276.0, 312.0]
const CUTS := [336.0, 348.0, 360.0]
const SINK := 336.0
const SIGN_CUT := 372.0
const END := 420

const EYE := 2.0             # camera height above the deck
const MH_W := 18.0
const MH_Y := 12.2           # MH lockup centre above the deck
const LOGO_W := 38.0
const LOGO_H := 38.0 * 339.95 / 1427.88
const PLATE_Y := 10.8        # FTF plate centre above the board
const PILLAR_X := 13.0
const SIGN_D := 32.0         # sign distance ahead at the drop

const SKY_TOP := Color("#0a0a26")
const SKY_HZ := Color("#d8406f")
const BOARD_A := Color("#6a54b4")
const BOARD_B := Color("#120e26")
const SUN_EL := 2.0

var _built := false
var _stage: MotionStage3D
var _sky: MotionSkyDome3D
var _curve: Curve3D
var _travel: MotionTravel   # camera distance along the circuit per frame
var _len := 0.0
var _s_mh := 0.0
var _s_gates: Array[float] = []
var _mh_fr: Transform3D

var _ground: MeshInstance3D
var _m_board: ShaderMaterial
var _m_deck: ShaderMaterial
var _m_checks: ShaderMaterial
var _m_gchecks: ShaderMaterial
var _m_solid: ShaderMaterial
var _m_lights: ShaderMaterial
var _m_city_lights: ShaderMaterial
var _m_pads: ShaderMaterial
var _m_mh: ShaderMaterial
var _m_mh_frame: ShaderMaterial
var _m_ftf: ShaderMaterial
var _m_plate: ShaderMaterial
var _m_pillar: ShaderMaterial
var _m_sign_lights: ShaderMaterial
var _m_trails: Array[ShaderMaterial] = []
var _sign: Node3D
var _presents: MotionPanel3D
var _presents_text: MotionText
var _presents_jp: MotionText
var _boards: Array[MotionPanel3D] = []
var _billboards: Array[MotionPanel3D] = []
var _pillar_panels: Array[MotionPanel3D] = []

var _streaks: MotionCanvas
var _hud: Node2D
var _hud_l1: MotionText
var _hud_l2: MotionText
var _speed_txt: MotionText
var _speed_unit: MotionText
var _lap: MotionText
var _hud_canvas: MotionCanvas
var _call: MotionCanvas
var _call_a: MotionText
var _call_b: MotionText
var _fade: ColorRect


func _init() -> void:
	duration = END
	bpm = BPM
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": 216.0, "out": SINK}
	cue(0.0, &"engine", 0.8, _engine_curves())
	for i in POWER.size():
		cue(POWER[i], &"power", 0.55 + 0.15 * i, {pitch = [1.0, 1.12, 1.26, 1.5][i]})
	cue(HUD_IN, &"hud.type", 0.5)
	cue(MH_ON, &"neon", 0.9)
	cue(PRESENTS, &"presents", 0.8)
	for i in OVERTAKE.size():
		cue(OVERTAKE[i] - 6.0, &"overtake", 0.7 + 0.1 * i, {pitch = [1.0, 1.12][i]})
	cue(SPOOL, &"spool", 0.9)
	cue(LAUNCH, &"launch", 1.0)
	cue(MH_PASS - 6.0, &"pass", 0.8)
	for i in GATES.size():
		cue(GATES[i] - 4.0, &"gate", 0.7 + 0.08 * i, {pitch = [1.0, 0.94, 1.06, 0.89][i]})
	cue(RISE, &"rise", 1.0)
	cue(DROP, &"drop", 1.0)
	for i in range(1, RINGS.size()):
		cue(RINGS[i], &"ring", 0.6 + 0.1 * i)
	for i in CALLOUTS.size():
		cue(CALLOUTS[i], &"callout", 0.6, {pitch = [1.0, 1.19][i]})
	for i in SHIPS.size():
		cue(SHIPS[i] - 12.0, &"ship", 0.75 + 0.1 * i, {pitch = [1.0, 0.9, 1.1][i]})
	cue(SINK + 2.0, &"sink", 0.8)
	for i in CUTS.size():
		cue(CUTS[i], &"cut", 0.6 + 0.12 * i, {pitch = [1.0, 0.84, 0.71][i]})
	cue(SIGN_CUT, &"sign.cut", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== timing

## Camera speed in metres per frame at key frames; smoothstep between keys.
const SPEED_KEYS := [[0.0, 0.0], [6.0, 0.0], [30.0, 0.32], [84.0, 0.3], [96.0, 0.42], [112.0, 3.3],
	[150.0, 4.1], [176.0, 4.5], [192.0, 3.6], [220.0, 2.7], [336.0, 2.7], [372.0, 1.8], [420.0, 1.2]]


static func _speed(f: float) -> float:
	return MotionTravel.keyed_speed(SPEED_KEYS, f)


func _make_table() -> void:
	# integrated on eighths of a frame, Float64 (a long circuit)
	_travel = MotionTravel.from_speed(_speed, END + 64, 8, true)


## Camera distance along the circuit at frame f (pure: a table lookup).
func s_at(f: float) -> float:
	return _travel.at(f)


## The engine: one cue whose pitch and level follow the camera's speed.
static func _engine_curves() -> Dictionary:
	var pitch := []
	var level := []
	var f := 0.0
	while f <= END:
		var spool := MK.map(f, [SPOOL, LAUNCH], [0, 1], MK.ease_in_quad) * (1.0 - MK.map(f, [LAUNCH, LAUNCH + 10.0], [0, 1]))
		var hz := 31.0 + 17.0 * _speed(f) + 26.0 * spool
		pitch.append([snappedf(f / 30.0, 0.001), snappedf(hz, 0.01)])
		var lv := MK.map(f, [2, 30], [0.0, 0.55]) + 0.45 * MK.map(f, [SPOOL, LAUNCH + 4.0], [0, 1])
		lv *= 1.0 - 0.35 * MK.map(f, [DROP, DROP + 24.0], [0, 1])
		lv *= 1.0 - MK.map(f, [SINK, SIGN_CUT + 12.0], [0, 1], MK.ease_in_out)
		level.append([snappedf(f / 30.0, 0.001), snappedf(lv, 0.001)])
		f += 6.0
	return {pitch = pitch, level = level}


# ================================================================== build

func _build() -> void:
	_built = true
	_make_table()
	_s_mh = s_at(MH_PASS)
	for g in GATES:
		_s_gates.append(s_at(g))
	_curve = NB.circuit()
	_len = _curve.get_baked_length()

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = size
	add_child(bg)
	_stage = MotionStage3D.new()
	_stage.size = size
	add_child(_stage)
	_stage.night(SKY_TOP, SKY_HZ, 0.0024, 0.8)

	_sky = MotionSkyDome3D.new()
	_sky.sky_top = SKY_TOP
	_sky.sky_horizon = SKY_HZ
	_sky.sky_spread = 0.42
	_sky.sky_curve = 0.75
	_sky.sun_elevation = SUN_EL
	_sky.sun_size = 11.0
	_sky.sun_top = Color("#ffe27a")
	_sky.sun_bottom = Color("#ff3f86")
	_sky.sun_bands = Vector3(9.0, 0.0, 0.3)
	_sky.sun_glow = 0.28
	_stage.world.add_child(_sky)

	_m_board = MotionPattern3D.material(BOARD_A, BOARD_B, 8.0)
	_m_board.set_shader_parameter("sheen_color", Color(1.0, 0.45, 0.4, 0.8))
	_m_board.set_shader_parameter("sheen_dir", _sky.sun_direction())
	_m_board.set_shader_parameter("sheen_power", 26.0)
	_ground = MotionPattern3D.ground(_stage.world, _m_board)
	_m_checks = MotionPattern3D.material(Color(1, 1, 1), Color("#0c0a18"), 4.0, MotionPattern3D.Space.UV)
	_m_checks.set_shader_parameter("face_shade", Vector3(0.55, 0.7, 0.85))
	_m_gchecks = MotionPattern3D.material(Color(1, 1, 1), Color("#0c0a18"), 0.8, MotionPattern3D.Space.UV)
	_m_solid = MotionStage3D.unlit(Color.WHITE, 1.0)
	_m_lights = MotionStage3D.unlit(Color.WHITE, 2.6, 0.03)
	_m_lights.set_shader_parameter("lit_soft", 6.0)
	_m_city_lights = MotionPattern3D.material(Color.WHITE, Color.BLACK, 1.0, MotionPattern3D.Space.UV, MotionPattern3D.Pattern.SOLID)
	_m_city_lights.set_shader_parameter("face_shade", Vector3.ONE)
	_m_city_lights.set_shader_parameter("lit_soft", 20.0)
	_m_pads = MotionStage3D.unlit(Color.WHITE, 2.0, 0.08)
	_m_mh = MotionStage3D.unlit(Color.WHITE, 1.0)
	_m_mh_frame = MotionStage3D.unlit(Color.WHITE, 1.0)
	_m_ftf = MotionStage3D.unlit(Color.WHITE, 1.0)

	var checks := SurfaceTool.new()
	checks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gchecks := SurfaceTool.new()
	gchecks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lights := SurfaceTool.new()
	lights.begin(Mesh.PRIMITIVE_TRIANGLES)
	var city_lights := SurfaceTool.new()
	city_lights.begin(Mesh.PRIMITIVE_TRIANGLES)

	_mh_fr = NB.gantry(gchecks, lights, _curve, _s_mh, 9.6, 7.0, 1.8, Color(0.95, 0.93, 1.0), FTFKit.WHITE)
	var gate_cols := [FTFKit.LIME, FTFKit.CYAN, FTFKit.ORANGE, FTFKit.PINK]
	for i in _s_gates.size():
		NB.gantry(gchecks, lights, _curve, _s_gates[i], 9.4, 6.4, 2.0, gate_cols[i].lerp(Color.WHITE, 0.25), gate_cols[i])
	var clear := func(s: float) -> float: return 16.0 if s < 280.0 else 26.0
	var placed := []
	NB.skyline(checks, city_lights, _curve, _len, clear, placed, 9.0, 20.0, 30.0, 22.0)   # a near row first
	NB.skyline(checks, city_lights, _curve, _len, clear, placed)

	_add_mesh(NB.track_solid(_curve, _len), _m_solid)
	_m_deck = MotionPattern3D.material(Color("#2a2252"), Color("#120f26"), 4.0)
	_m_deck.set_shader_parameter("sheen_color", Color(1.0, 0.4, 0.5, 0.35))
	_m_deck.set_shader_parameter("sheen_power", 18.0)
	_add_mesh(NB.track_deck(_curve, _len), _m_deck)
	_add_mesh(NB.track_lights(_curve, _len, FTFKit.PINK, FTFKit.CYAN, FTFKit.LIME), _m_lights)
	_add_mesh(checks.commit(), _m_checks)
	_add_mesh(gchecks.commit(), _m_gchecks)
	_add_mesh(lights.commit(), _m_lights)
	_add_mesh(city_lights.commit(), _m_city_lights)
	var pad_at := []
	var ps := 70.0
	while ps < _len:
		pad_at.append(ps)
		ps += 40.0
	_add_mesh(NB.pads(_curve, pad_at, FTFKit.LIME), _m_pads)

	# light trails: two overtaking ships at the start, three under the sign in the hold
	var trail_cols := [FTFKit.PINK, FTFKit.LIME, FTFKit.CYAN, FTFKit.PINK, FTFKit.LIME]
	var trail_x := [-3.2, 3.0, -2.6, 3.2, -0.6]
	for i in trail_cols.size():
		var m := MotionStage3D.unlit(Color.WHITE, 3.0, 0.0)
		m.set_shader_parameter("lit_soft", 18.0)
		m.set_shader_parameter("lit_to", -1000.0)
		m.set_shader_parameter("lit_from", -1000.0)
		_m_trails.append(m)
		_add_mesh(MotionTrack3D.trail_lane(_curve, _len, trail_x[i], 0.7, trail_cols[i]), m)

	_build_mh()
	_build_boards()
	_build_sign()
	_build_overlay()
	_add_sound()


func _add_mesh(mesh: Mesh, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	(parent if parent else _stage.world).add_child(mi)
	return mi


func _build_mh() -> void:
	# Minimal Humans: extruded lockup on a dark backing board above the beam
	var b := MotionTrack3D.level_frame(_curve, _s_mh).basis
	var at := Transform3D(b, _mh_fr * Vector3(0, MH_Y, 0))
	var back := SurfaceTool.new()
	back.begin(Mesh.PRIMITIVE_TRIANGLES)
	MotionPattern3D.box(back, at, Vector3(MH_W + 2.6, 6.4, 0.5), Color("#0b0a16"))
	_add_mesh(back.commit(), _m_solid)
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in [-3.2, 3.2]:
		MotionPattern3D.box(frame, at * Transform3D(Basis(), Vector3(0, y, 0.28)), Vector3(MH_W + 2.6, 0.16, 0.08), FTFKit.MH_AMBER)
	for x in [-(MH_W + 2.6) * 0.5, (MH_W + 2.6) * 0.5]:
		MotionPattern3D.box(frame, at * Transform3D(Basis(), Vector3(x, 0, 0.28)), Vector3(0.16, 6.4, 0.08), FTFKit.MH_AMBER)
	_add_mesh(frame.commit(), _m_mh_frame)
	var mh: MotionSvgData = load("res://demo/assets/logos/mh_logoFull_standard.svg")
	var mh_mesh := MotionSvgMesh.build(mh, MH_W, {depth = 0.4, side_shade = 0.55})
	var mi := _add_mesh(mh_mesh, _m_mh)
	mi.transform = at * Transform3D(Basis(), Vector3(0, 0, 0.3))
	# PRESENTS on the beam's face
	_presents = MotionPanel3D.new()
	_presents.pixel_size = Vector2i(1536, 144)
	_presents.world_size = Vector2(18.4, 1.72)
	_presents.background = Color("#0b0a16")
	_presents.transform = Transform3D(b, _mh_fr * Vector3(0, 7.9, 0.64))
	_stage.world.add_child(_presents)
	_presents_text = FTFKit.text(_presents.canvas, "ext", 74, FTFKit.MH_CREAM, "PRESENTS", 0.62)
	_presents_text.position = Vector2(768 - _presents_text.get_text_size().x * 0.5 + 24, 26)
	_presents_jp = FTFKit.text(_presents.canvas, "jp", 44, FTFKit.MH_AMBER, "提供")
	_presents_jp.position = Vector2(1400, 40)
	var mk := FTFKit.text(_presents.canvas, "mono", 26, FTFKit.STONE, "MH//01", 0.1)
	mk.position = Vector2(48, 54)


func _build_boards() -> void:
	# checkered sponsor boards on the gates
	var boards := [
		["SPARROW", "S07", "スパロー", FTFKit.LIME, FTFKit.INK],
		["STARLING", "T23", "スターリング", FTFKit.CYAN, FTFKit.INK],
		["KESTREL", "K45", "ケストレル", FTFKit.ORANGE, FTFKit.INK],
		["F-9000", "A.G.", "反重力レース", FTFKit.PINK, FTFKit.WHITE],
	]
	for i in boards.size():
		var bd: Array = boards[i]
		var p := MotionPanel3D.new()
		p.pixel_size = Vector2i(1536, 168)
		p.world_size = Vector2(18.8, 2.06)
		p.background = bd[3]
		p.animated = false
		var fr := MotionTrack3D.frame(_curve, _s_gates[i])
		p.transform = Transform3D(MotionTrack3D.level_frame(_curve, _s_gates[i]).basis, fr * Vector3(0, 6.4 + 1.0, 0.64))
		_stage.world.add_child(p)
		var fg: Color = bd[4]
		var c := MotionCanvas.new()
		c.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
			# checker end caps
			for k in 2:
				var x0 := 0.0 if k == 0 else 1536.0 - 168.0
				for j in 4:
					for q in 4:
						if (j + q) % 2 == 0:
							cv.rect(Rect2(x0 + q * 42.0, j * 42.0, 42.0, 42.0), fg)
		p.canvas.add_child(c)
		var name := FTFKit.text(p.canvas, "wide", 92, fg, bd[0], 0.02)
		name.position = Vector2(210, 16)
		var code := FTFKit.text(p.canvas, "mono", 40, fg, bd[1], 0.1)
		code.position = Vector2(1536 - 210 - code.get_text_size().x, 22)
		var jp := FTFKit.text(p.canvas, "jp", 34, fg, bd[2])
		jp.position = Vector2(1536 - 210 - jp.get_text_size().x, 96)
		_boards.append(p)

	# DR billboards on stilts along the S-bend
	var bills := [
		[0.3, -1.0, "反重力", FTFKit.PINK, FTFKit.INK, "jp"],
		[0.5, 1.0, "S07", FTFKit.LIME, FTFKit.INK, "wide"],
		[0.7, -1.0, "加速", FTFKit.CYAN, FTFKit.INK, "jp"],
		[0.92, 1.0, "FTF", FTFKit.INK, FTFKit.PINK, "wide"],
	]
	var a := NB.S1
	var bb := NB.S1 + NB.R * PI * 0.5
	for i in bills.size():
		var bl: Array = bills[i]
		var bs := lerpf(a, bb, bl[0])
		var lv := MotionTrack3D.level_frame(_curve, bs)
		var side: float = bl[1]
		var bp := MotionPanel3D.new()
		bp.pixel_size = Vector2i(512, 768)
		bp.world_size = Vector2(14, 21)
		bp.background = bl[3]
		bp.animated = false
		var pos := lv * Vector3(side * 21.0, 0, -24.0)
		pos.y = 16.0
		bp.transform = Transform3D(lv.basis * Basis(Vector3.UP, -side * 0.5), pos)
		_stage.world.add_child(bp)
		var big := FTFKit.text(bp.canvas, bl[5], 240 if bl[5] == "jp" else 200, bl[4], bl[2])
		if bl[5] == "jp":
			big.vertical = true
			big.box_width = 760
			big.position = Vector2(256 - big.get_text_size().x * 0.5, 24)
		else:
			big.position = Vector2(256 - big.get_text_size().x * 0.5, 280)
		var bc := MotionCanvas.new()
		var fgc: Color = bl[4]
		bc.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
			MotionMarks.checker(cv, Vector2(24, 664), 10, 2, 46.0, fgc, 1.0, 3.0 + i, 1.0)
			MotionMarks.xbox(cv, Vector2(460, 52), 56, fgc, 4.0)
		bp.canvas.add_child(bc)
		_billboards.append(bp)


func _build_sign() -> void:
	# FULL THROTTLE FLUX: an extruded logo on two checkered pillars, a node that
	# rides ahead of the camera and rises out of the board.
	_sign = Node3D.new()
	_stage.world.add_child(_sign)
	var logo: MotionSvgData = load(FTFKit.LOGO)
	var proud := FTFKit.WORD + FTFKit.FLUX_TOP + FTFKit.FLUX_BOT + [FTFKit.FLUX_BOWL, FTFKit.TAB] + FTFKit.SMALL + FTFKit.CHECKS
	var ftf_mesh := MotionSvgMesh.build(logo, LOGO_W, {depth = 1.0, side_shade = 0.6,
		part_fn = func(i: int) -> Dictionary:
			if i == FTFKit.PLATE:
				return {hide = true}
			if i == FTFKit.RIM:
				return {depth = 1.3, z = -0.1}
			if proud.has(i):
				return {depth = 0.5, z = 1.0 + i * 0.012}
			return {}})
	var lm := _add_mesh(ftf_mesh, _m_ftf, _sign)
	lm.position = Vector3(0, PLATE_Y, 0)
	# the plate: pale checks scrolling across it (pattern in the logo's UV space)
	_m_plate = MotionPattern3D.material(Color(1, 1, 1), Color("#ffc4da"), 1.7, MotionPattern3D.Space.UV)
	_m_plate.set_shader_parameter("uv_scale", Vector2(LOGO_W, LOGO_W * logo.view_box.size.y / logo.view_box.size.x))
	_m_plate.set_shader_parameter("face_shade", Vector3(1, 1, 1))
	var plate := MotionSvgMesh.build(logo, LOGO_W, {depth = 1.0, side_shade = 0.6, only = PackedInt32Array([FTFKit.PLATE])})
	var pm := _add_mesh(plate, _m_plate, _sign)
	pm.position = Vector3(0, PLATE_Y, 0)
	# pillars: pink / ink checks from deep under the board up to the plate
	_m_pillar = MotionPattern3D.material(FTFKit.PINK, FTFKit.INK, 1.2, MotionPattern3D.Space.UV)
	_m_pillar.set_shader_parameter("face_shade", Vector3(0.7, 1.0, 1.0))
	_m_sign_lights = MotionStage3D.unlit(Color.WHITE, 2.4)
	var pst := SurfaceTool.new()
	pst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lst := SurfaceTool.new()
	lst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom := -30.0
	var top := PLATE_Y - LOGO_H * 0.5 + 1.0
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * PILLAR_X
		MotionPattern3D.box(pst, Transform3D(Basis(), Vector3(x, (bottom + top) * 0.5, -0.6)), Vector3(2.4, top - bottom, 2.4), Color.WHITE, 0.0)
		for e in [-1.0, 1.0]:
			MotionPattern3D.box(lst, Transform3D(Basis(), Vector3(x + e * 1.26, (bottom + top) * 0.5, 0.66)), Vector3(0.12, top - bottom, 0.12), FTFKit.CYAN if sgn < 0 else FTFKit.LIME)
		# vertical katakana boards on the pillars' fronts
		var pp := MotionPanel3D.new()
		var ph := top - 1.6
		pp.pixel_size = Vector2i(128, int(ph / 1.8 * 128.0))
		pp.world_size = Vector2(1.8, ph)
		pp.background = FTFKit.INK
		pp.animated = false
		pp.position = Vector3(x, ph * 0.5, 0.62)
		_sign.add_child(pp)
		var jt := FTFKit.text(pp.canvas, "jp", 52, FTFKit.WHITE, "フルスロットル" if sgn < 0 else "フラックス")
		jt.vertical = true
		jt.box_width = pp.pixel_size.y - 20
		jt.position = Vector2(64 - jt.get_text_size().x * 0.5, 10)
		_pillar_panels.append(pp)
	_add_mesh(pst.commit(), _m_pillar, _sign)
	_add_mesh(lst.commit(), _m_sign_lights, _sign)


func _build_overlay() -> void:
	_streaks = MotionCanvas.new()
	_streaks.draw_fn = _draw_streaks
	add_child(_streaks)
	var vig := MotionGradient.radial(size, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7)], [0.0, 0.55, 1.0], Vector2(0.5, 0.5))
	add_child(vig)

	_hud = Node2D.new()
	add_child(_hud)
	_hud_canvas = MotionCanvas.new()
	_hud_canvas.draw_fn = _draw_hud
	_hud.add_child(_hud_canvas)
	_hud_l1 = FTFKit.text(_hud, "mono", 22, FTFKit.WHITE, "F-9000 // ANTI-GRAVITY LEAGUE", 0.14)
	_hud_l1.position = Vector2(96, 70)
	_hud_l2 = FTFKit.text(_hud, "mono", 22, FTFKit.LIME, "NIGHT CIRCUIT // CHECKER DISTRICT // DUSK", 0.14)
	_hud_l2.position = Vector2(96, 102)
	_speed_txt = FTFKit.text(_hud, "tall", 120, FTFKit.WHITE, "000", 0.02)
	_speed_unit = FTFKit.text(_hud, "mono", 22, FTFKit.PINK, "KM/H", 0.2)
	_lap = FTFKit.text(_hud, "mono", 30, FTFKit.WHITE, "00:00.00", 0.08)
	_lap.position = Vector2(96, 960)

	_call = MotionCanvas.new()
	_call.draw_fn = _draw_callouts
	add_child(_call)
	_call_a = FTFKit.text(self, "mono", 22, FTFKit.WHITE, "SIGNAL 01 // 40.0 M SPAN // RISEN", 0.12)
	_call_b = FTFKit.text(self, "mono", 22, FTFKit.LIME, "フルスロットル・フラックス // S.01", 0.06)

	_fade = ColorRect.new()
	_fade.size = size
	_fade.color = Color(0, 0, 0, 0)
	add_child(_fade)


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_nightcircuit/audio/nc_map.tres"
	const SONG := "res://demo/ftf/ftf_nightcircuit/audio/music/nc_song.tres"
	const TRACK := "res://demo/ftf/ftf_nightcircuit/audio/ftf_nightcircuit_track.res"
	if ResourceLoader.exists(BRIDGE) and ResourceLoader.exists(MAP):
		var bridge: Node = (load(BRIDGE) as GDScript).new()
		bridge.set("cue_map", load(MAP))
		if ResourceLoader.exists(SONG):
			bridge.set("song", load(SONG))
		if ResourceLoader.exists(TRACK):
			bridge.set("track", load(TRACK))
		bridge.set("track_path", TRACK)
		add_child(bridge)
	elif ResourceLoader.exists(TRACK):
		var p := AudioStreamPlayer.new()
		p.stream = load(TRACK)
		add_child(p)
		audio = p
		clock = Clock.AUDIO


# ================================================================== the sign

## Distance of the sign ahead of the camera.
func _sign_d(f: float) -> float:
	var d := lerpf(SIGN_D, SIGN_D - 2.0, MK.map(f, [DROP, SINK], [0, 1], MK.ease_in_out))
	return d + 60.0 * MK.map(f, [SINK, SIGN_CUT + 8.0], [0, 1], MK.ease_in_quad)


## How far the sign has risen: -1 under the board .. 0 up, with a slam.
func _sign_rise(f: float) -> float:
	var r := MK.map(f, [RISE, DROP], [0, 1], MK.ease_in_quad)
	var y := -(PLATE_Y + LOGO_H * 0.5 + 1.5) * (1.0 - r)
	if f >= DROP:
		y += sin((f - DROP) * 0.7) * exp(-(f - DROP) * 0.28) * 0.9
		# a little dip on every beat during the hold
		var t := fposmod(f - DROP, BEAT)
		y -= 0.16 * exp(-t * 0.35) * MK.map(f, [DROP + BEAT, DROP + BEAT + 1.0], [0, 1]) * (1.0 - MK.map(f, [SINK, SINK + 12.0], [0, 1]))
	return y


func _sign_xf(f: float) -> Transform3D:
	var lv := MotionTrack3D.level_frame(_curve, s_at(f) + _sign_d(f))
	var o := lv.origin
	o.y = _sign_rise(f)
	return Transform3D(lv.basis, o)


func _sign_centre(f: float) -> Vector3:
	return _sign_xf(f) * Vector3(0, PLATE_Y, 0)


# ================================================================== camera

func _camera(f: float) -> Array:
	var s := s_at(f)
	var spd := _speed(f)
	var hold := MK.map(f, [DROP, DROP + 30.0], [0, 1], MK.ease_in_out)
	var out := MK.map(f, [SINK, SIGN_CUT + 20.0], [0, 1], MK.ease_in_out)
	var sway := sin(TAU * (f - DROP) / (BAR * 2.0)) * hold
	var ride := MotionStage3D.ride(_curve, s, EYE + 5.0 * out, 26.0, 1.2, 1.4 * sway)
	# attention: up at the MH lockup on the approach, then at the FTF sign
	var mh_c := _mh_fr * Vector3(0, MH_Y - 0.6, 0)
	var w_mh := MK.map(f, [6, 40], [0.25, 0.62], MK.ease_in_out) * (1.0 - MK.map(f, [100, 109], [0, 1], MK.ease_in_out))
	var w_ftf := MK.map(f, [172, 190], [0, 0.42], MK.ease_in_out) * (1.0 - 0.6 * out)
	var ahead := ride.origin - ride.basis.z * 26.0 + ride.basis.y * (-0.4)
	var target := ahead.lerp(mh_c, w_mh).lerp(_sign_centre(f) - Vector3(0, 2.0, 0), w_ftf)
	var roll := deg_to_rad(1.6) * sway
	var xf := MotionStage3D.look(ride.origin, target, ride.basis.y, roll)
	# rumble with speed, jolts on the launch and the drop
	var rum := 0.016 * spd
	var shake := Vector3(sin(f * 2.3) * 0.6 + sin(f * 5.1) * 0.4, sin(f * 3.7) * 0.5 + sin(f * 7.3) * 0.5, 0) * rum
	var jolt := MK.shakes(f, [LAUNCH, DROP], 1.0, 10)
	xf.origin += xf.basis * (shake + Vector3(jolt.x, jolt.y, 0) * 0.07)
	var fov := lerpf(50.0, 62.0 + spd * 2.4, MK.map(f, [LAUNCH - 4.0, LAUNCH + 16.0], [0, 1], MK.ease_in_out))
	fov += 10.0 * maxf(0.0, 1.0 - MK.map(f, [LAUNCH, LAUNCH + 14], [0, 1])) * float(f >= LAUNCH)
	# into the drop: narrow down so the sign is big; a zoom punch on impact
	fov = lerpf(fov, 58.0, MK.map(f, [RISE - 6.0, DROP], [0, 1], MK.ease_in_out))
	fov -= 7.0 * exp(-maxf(0.0, f - DROP) / 7.0) * float(f >= DROP)
	fov += 6.0 * out
	return [xf, fov]


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	var cam: Array = _camera(f)
	_stage.set_camera(cam[0], cam[1])
	var cpos: Vector3 = (cam[0] as Transform3D).origin
	_sky.follow(_stage.camera)
	MotionPattern3D.follow(_ground, cpos)

	# ---- dusk level: up with the power, down as the sun sinks
	var up := MK.map(f, [0, 40], [0, 1], MK.ease_out)
	var dusk := up * (1.0 - MK.map(f, [CUTS[1], SIGN_CUT + 22.0], [0, 1], MK.ease_in_out))
	var sun_sink := MK.map(f, [SINK, SIGN_CUT + 18.0], [0, 1], MK.ease_in_quad)
	var spulse := MK.beat_pulse(f, BEAT, DROP, SINK, 0.25)
	_sky.level = dusk
	_sky.sun_elevation = lerpf(SUN_EL, -12.0, sun_sink) - 6.0 * (1.0 - up)
	_sky.sun_size = 11.0 * (1.0 + 0.04 * spulse + 0.1 * exp(-maxf(0.0, f - DROP) / 6.0) * float(f >= DROP))
	_sky.sun_bands = Vector3(9.0, f * 0.012, 0.3)
	_sky.sun_glow = 0.24 + 0.14 * spulse
	var env := _stage.environment
	env.fog_light_color = SKY_HZ * dusk
	env.background_color = SKY_TOP * dusk

	# ---- board: motion blur along the travel, dusk, sheen, rings
	var p0 := MotionStage3D.path_frame(_curve, s_at(f - 0.5)).origin
	var p1 := MotionStage3D.path_frame(_curve, s_at(f + 0.5)).origin
	_m_board.set_shader_parameter("motion", MotionPattern3D.motion_for(p0, p1, 0.5))
	_m_deck.set_shader_parameter("motion", MotionPattern3D.motion_for(p0, p1, 0.5))
	_m_deck.set_shader_parameter("energy", up * (1.0 - MK.map(f, [CUTS[2], SIGN_CUT + 10.0], [0, 1])))
	_m_deck.set_shader_parameter("sheen_dir", _sky.sun_direction())
	_m_board.set_shader_parameter("energy", dusk * (1.0 + 0.1 * spulse))
	_m_board.set_shader_parameter("sheen_dir", _sky.sun_direction())
	_m_board.set_shader_parameter("sheen_color", Color(1.0, 0.45, 0.4, 0.8 * (1.0 - sun_sink)))
	var ring_on := false
	for at: float in RINGS:
		if f >= at and f < at + 40.0:
			var t := (f - at) / 40.0
			var c := _sign_xf(at).origin
			var strength := 1.0 if at == DROP else 0.55
			var rr := lerpf(4.0, 220.0, MK.ease_out.call(t))
			var rc := Color(FTFKit.LIME.lerp(FTFKit.WHITE, 0.3), strength * (1.0 - t))
			MotionPattern3D.ring(_m_board, c, rr, lerpf(3.0, 14.0, t), rc, 0.8 * strength * (1.0 - t))
			# the deck carries it too: the wave sweeps back under the camera
			MotionPattern3D.ring(_m_deck, c, rr, lerpf(2.0, 8.0, t), rc, 0.6 * strength * (1.0 - t))
			ring_on = true
	if not ring_on:
		MotionPattern3D.ring(_m_board, Vector3.ZERO, -1.0)
		MotionPattern3D.ring(_m_deck, Vector3.ZERO, -1.0)

	# ---- power: the strip chase steps out toward the sun on the first four beats
	var reach := 0.0
	var steps := [30.0, 90.0, 300.0, _len + 50.0]
	for i in POWER.size():
		if f >= POWER[i]:
			reach = lerpf(reach if i == 0 else steps[i - 1], steps[i], MK.map(f, [POWER[i], POWER[i] + 9.0], [0, 1], MK.ease_out))
	# outro: the far end cuts first, toward us
	var cut_to := _len + 50.0
	var cut_steps := [s_at(CUTS[0]) + 420.0, s_at(CUTS[1]) + 140.0, s_at(CUTS[2]) + 12.0]
	for i in CUTS.size():
		if f >= CUTS[i]:
			cut_to = cut_steps[i]
	if f >= SIGN_CUT:
		cut_to = -100.0
	var lit := minf(reach, cut_to)
	var pulse := 1.0 + 0.55 * MK.beat_pulse(f, BEAT, LAUNCH, SINK, 0.32)
	var flare := 1.0 + 1.6 * exp(-maxf(0.0, f - DROP) / 6.0) * float(f >= DROP)
	_m_lights.set_shader_parameter("lit_to", lit)
	_m_lights.set_shader_parameter("energy", 2.4 * pulse * flare)
	_m_pads.set_shader_parameter("lit_to", lit)
	_m_pads.set_shader_parameter("energy", 1.2 * (1.0 + 0.8 * MK.beat_pulse(f, BEAT, LAUNCH, SINK, 0.3)))
	_m_city_lights.set_shader_parameter("lit_to", minf(reach * 2.0 + MK.map(f, [36, 60], [0, 2000]), cut_to + 60.0))
	_m_city_lights.set_shader_parameter("energy", 1.7 * up * (1.0 + 0.35 * flare - 0.35) * (1.0 + 0.25 * MK.beat_pulse(f, BEAT, DROP, SINK, 0.2)))
	var solid := up * (1.0 - MK.map(f, [CUTS[2], SIGN_CUT + 10.0], [0, 1]))
	_m_solid.set_shader_parameter("energy", solid)
	_m_checks.set_shader_parameter("energy", dusk * 0.92)
	# the city sprouts from the board as we approach (keeps the sun in view)
	MotionPattern3D.grow(_m_checks, s_at(f), 100.0, 165.0)
	MotionPattern3D.grow(_m_city_lights, s_at(f), 100.0, 165.0)
	_m_gchecks.set_shader_parameter("energy", dusk)

	# ---- MH lockup
	var mh_e := MK.flicker(f, MH_ON, 7.0)
	var mh_off := 1.0 - MK.map(f, [CUTS[0], CUTS[0] + 2.0], [0, 1], MK.linear)
	_m_mh.set_shader_parameter("energy", lerpf(0.05, 1.12, mh_e) * mh_off)
	_m_mh_frame.set_shader_parameter("energy", lerpf(0.0, 2.2, MK.flicker(f, MH_ON + 3.0, 4.0)) * mh_off * (1.0 + 0.3 * MK.beat_pulse(f, BEAT, PRESENTS, LAUNCH, 0.3)))
	_presents.energy = (0.08 + 1.25 * MK.flicker(f, PRESENTS, 11.0)) * mh_off
	_presents_text.visible_chars = int(MK.map(f, [PRESENTS, PRESENTS + 10.0], [0, 8], MK.linear))
	_presents_jp.visible = f >= PRESENTS + 10.0
	var boards_on := MK.map(f, [LAUNCH - 12.0, LAUNCH], [0, 1], MK.linear) * mh_off
	for i in _boards.size():
		var hit := exp(-maxf(0.0, f - GATES[i]) * 0.3) * float(f >= GATES[i] - 2.0)
		_boards[i].energy = boards_on * (1.0 + 0.7 * hit)
	for bp in _billboards:
		bp.energy = 1.05 * dusk

	# ---- the FTF sign
	var sxf := _sign_xf(f)
	_sign.transform = sxf
	_sign.visible = f >= RISE - 2.0 and f < SIGN_CUT + 4.0
	var sign_cut := 1.0 - MK.map(f, [SIGN_CUT, SIGN_CUT + 3.0], [0, 1], MK.linear)
	var sign_e := 1.0 + 0.25 * exp(-maxf(0.0, f - DROP) / 5.0) * float(f >= DROP)
	_m_ftf.set_shader_parameter("energy", 1.05 * sign_e * sign_cut)
	_m_plate.set_shader_parameter("energy", 1.0 * sign_cut)
	_m_plate.set_shader_parameter("offset", Vector2(s_at(f) * 0.08, 0.0))
	_m_pillar.set_shader_parameter("energy", 1.0 * sign_cut)
	_m_pillar.set_shader_parameter("offset", Vector2(0.0, -s_at(f) * 0.05))
	_m_sign_lights.set_shader_parameter("energy", 2.4 * pulse * sign_cut)
	for pp in _pillar_panels:
		pp.energy = 1.1 * sign_cut

	# ---- light trails: rivals overtaking at the start, ships under the sign in the hold
	for i in OVERTAKE.size():
		_trail(i, f, OVERTAKE[i] - 10.0, 3.0, 40.0)
	for i in SHIPS.size():
		_trail(i + 2, f, SHIPS[i] - 15.0, 4.2, 60.0)

	_frame_overlay(f)


## Trail i: its head passes the camera at frame f0 + ~8 and gains v m/frame on it.
func _trail(i: int, f: float, f0: float, v: float, length: float) -> void:
	var m := _m_trails[i]
	if f < f0 or f > f0 + 60.0:
		m.set_shader_parameter("lit_to", -1000.0)
		m.set_shader_parameter("lit_from", -1000.0)
		return
	var head := s_at(f) - 30.0 + (f - f0) * v
	m.set_shader_parameter("lit_to", head)
	m.set_shader_parameter("lit_from", head - length)


func _frame_overlay(f: float) -> void:
	var hud_on := MK.map(f, [HUD_IN, HUD_IN + 4.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [SINK, SINK + 12.0], [0, 1], MK.linear))
	_hud.visible = hud_on > 0.0
	_hud.modulate.a = hud_on
	_hud_l1.visible_chars = int(MK.map(f, [HUD_IN, HUD_IN + 14.0], [0, 29], MK.linear))
	_hud_l2.visible_chars = int(MK.map(f, [HUD_IN + 6.0, HUD_IN + 24.0], [0, 41], MK.linear))
	var lines := 1.0 - MK.map(f, [DROP, DROP + 8.0], [0, 1], MK.linear)
	_hud_l1.modulate.a = lines
	_hud_l2.modulate.a = lines
	var kmh := _speed(f) * 30.0 * 3.6
	_speed_txt.text = "%03d" % int(kmh)
	_speed_txt.position = Vector2(1824 - _speed_txt.get_text_size().x, 50)
	_speed_unit.position = Vector2(1824 - _speed_unit.get_text_size().x, 50 + 132)
	var t := f / 30.0
	_lap.text = "%02d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]
	_lap.visible = f >= LAUNCH
	_streaks.visible = f > 108.0 and f < DROP + 30.0
	_fade.color.a = MK.map(f, [SIGN_CUT + 6.0, SIGN_CUT + 24.0], [0, 1], MK.linear) + (1.0 - MK.map(f, [0, 6], [0, 1], MK.linear))
	_fade.visible = _fade.color.a > 0.0
	# callouts pinned to the sign's corners
	var ca := MK.map(f, [CALLOUTS[0], CALLOUTS[0] + 14.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [SINK, SINK + 8.0], [0, 1], MK.linear))
	var cb := MK.map(f, [CALLOUTS[1], CALLOUTS[1] + 14.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [SINK, SINK + 8.0], [0, 1], MK.linear))
	_call.visible = ca > 0.0
	_call_a.visible = ca > 0.0
	_call_b.visible = cb > 0.0
	if ca > 0.0:
		var sx := _sign_xf(f)
		var p := _stage.to_screen(sx * Vector3(-LOGO_W * 0.5 + 1.4, PLATE_Y + LOGO_H * 0.5 - 0.6, 1.6))
		_call_a.position = p + Vector2(-20, -60 - 34)
		_call_a.visible_chars = int(ca * 34.0)
		var q := _stage.to_screen(sx * Vector3(LOGO_W * 0.5 - 1.4, PLATE_Y + LOGO_H * 0.5 - 0.6, 1.6))
		_call_b.position = q + Vector2(-_call_b.get_text_size().x + 20, -110 - 34)
		_call_b.visible_chars = int(cb * 22.0)


func _draw_streaks(c: MotionCanvas, f: float) -> void:
	var spd := _speed(f)
	var fade := MK.map(f, [108, 124], [0, 1]) * (1.0 - MK.map(f, [DROP + 6.0, DROP + 30.0], [0, 1]))
	if fade <= 0.0:
		return
	var vp := _stage.to_screen(_stage.camera.global_transform * Vector3(0, 0, -400))
	for i in 64:
		var a := MK.rand(i * 7.13 + 1.0) * TAU
		var dir := Vector2(cos(a), sin(a) * 0.62)
		var ph := fposmod(f * (0.05 + 0.04 * MK.rand(i * 3.3)) * spd + MK.rand(i * 1.9), 1.0)
		var r0 := 260.0 + ph * ph * 1100.0
		var len := 40.0 + ph * 240.0
		var col := FTFKit.WHITE if i % 4 else FTFKit.PINK
		c.line(vp + dir * r0, vp + dir * (r0 + len), col, 1.5 + ph * 2.0, 0.26 * fade * ph)


func _draw_hud(c: MotionCanvas, f: float) -> void:
	var on := MK.map(f, [HUD_IN + 10.0, HUD_IN + 24.0], [0, 1])
	var x0 := 330.0
	var x1 := 1824.0
	var xr := lerpf(x0, x1, on)
	c.line(Vector2(x0, 984), Vector2(xr, 984), FTFKit.WHITE, 2.0, 0.5)
	for k in 9:
		var x := lerpf(x0, x1, k / 8.0)
		if x <= xr:
			c.line(Vector2(x, 976), Vector2(x, 992), FTFKit.WHITE, 2.0, 0.5)
	if f >= LAUNCH:
		var p := clampf(s_at(f) / s_at(SIGN_CUT), 0.0, 1.0)
		var mx := lerpf(x0, x1, p)
		c.polygon(PackedVector2Array([Vector2(mx, 972), Vector2(mx + 12, 960), Vector2(mx - 12, 960)]), FTFKit.PINK, Color(0, 0, 0, 0))
	MotionMarks.chevrons(c, Vector2(1640, 230), 6, 26, FTFKit.LIME, fposmod(f / 4.0, 1.0), 1.0, on, 0.9)
	# checker tick under the speed readout, stepping on the beat
	var k0 := int(floorf(f / BEAT))
	for i in 8:
		if (i + k0) % 2 == 0:
			c.rect(Rect2(1824 - 8 * 18 + i * 18, 222, 18, 9), FTFKit.WHITE, 0.8)


func _draw_callouts(c: MotionCanvas, f: float) -> void:
	var ca := MK.map(f, [CALLOUTS[0], CALLOUTS[0] + 10.0], [0, 1]) * (1.0 - MK.map(f, [SINK, SINK + 8.0], [0, 1]))
	var cb := MK.map(f, [CALLOUTS[1], CALLOUTS[1] + 10.0], [0, 1]) * (1.0 - MK.map(f, [SINK, SINK + 8.0], [0, 1]))
	var sx := _sign_xf(f)
	var a3 := sx * Vector3(-LOGO_W * 0.5 + 1.4, PLATE_Y + LOGO_H * 0.5 - 0.6, 1.6)
	var b3 := sx * Vector3(LOGO_W * 0.5 - 1.4, PLATE_Y + LOGO_H * 0.5 - 0.6, 1.6)
	if ca > 0.0:
		var a := _stage.to_screen(a3)
		var e := a - Vector2(0, 60) * ca
		c.line(a, e, FTFKit.WHITE, 2.0, ca)
		c.line(e, e + Vector2(-20 + 440.0 * ca, 0), FTFKit.WHITE, 2.0, ca)
		MotionMarks.crosshair(c, a, 9, FTFKit.WHITE, 2.0, ca)
	if cb > 0.0:
		var b := _stage.to_screen(b3)
		var e := b - Vector2(0, 110) * cb
		c.line(b, e, FTFKit.LIME, 2.0, cb)
		c.line(e, e + Vector2(20 - 380.0 * cb, 0), FTFKit.LIME, 2.0, cb)
		MotionMarks.crosshair(c, b, 9, FTFKit.LIME, 2.0, cb)
