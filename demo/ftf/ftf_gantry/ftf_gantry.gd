# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take 4, GANTRY: a night flight along a neon circuit.
#
# Brief: 14 s at 150 bpm (12 frames a beat, 48 a bar; first downbeat on frame
# 0, so any 150 bpm track starting on its downbeat replaces the music). Real 3D
# in a MotionStage3D, flat emissive materials, fog and glow; a thin 2D HUD over
# it. The logos are solid extruded signs (MotionSvgMesh) and arrive by camera,
# not by animating their letters.
#   I   Black. The circuit powers up one beat at a time: the barrier light
#       strips chase out into the dark, the city lights come up. The camera
#       sits low on the start line, then launches on the bar. Ahead, a gantry
#       carries the MINIMAL HUMANS sign: it flickers on, then the PRESENTS strip
#       types across the beam, and the camera ducks under it.
#   II  Full speed into a banked left-hander, a sponsor gantry overhead on
#       every beat (SPARROW, STARLING, KESTREL, F-9000), another ship's trail
#       ahead, speed streaks; a light-ringed tunnel; out of it on the drop...
#   III ...the FULL THROTTLE FLUX sign, huge over the straight. The camera
#       rushes it, brakes, and cranes up to face it head-on for the hold while
#       ships streak underneath and callouts pin themselves to the sign. Then
#       the camera rises and pulls back, the circuit's lights cut from the far
#       end towards us on the beats, the sign cuts last, black.
#
# Beats (30 fps, 420 frames):
#   0/12/24/36  power-up: light chase steps out; HUD types in from 14
#   48      launch (FOV kick)
#   72      MH sign flickers on
#   96      PRESENTS types along the beam strip
#   132     under the MH gantry
#   144/156/168/180  sponsor gantries pass overhead
#   181-192 tunnel
#   192     DROP: out of the tunnel, FTF sign lit ahead (flash, FOV kick)
#   192-216 rush; 216 air-brake; 216-246 crane to face the sign
#   246-336 hold; ships under the sign on 264/288/312; callouts pin at 252/258
#   336     crane up and back
#   348/360/372  lights cut far to near
#   384     sign cuts; black by 396
#
# Sound: cue sheet in _init; demo/ftf/ftf_gantry/audio/make.py writes the
# recipes and a 150 bpm song, bake.gd bakes them (see the FTF README).
@tool
extends MotionComposition

const GB := preload("res://demo/ftf/ftf_gantry/gantry_build.gd")

const POWER := [0.0, 12.0, 24.0, 36.0]
const HUD_IN := 14.0
const LAUNCH := 48.0
const MH_ON := 72.0
const PRESENTS := 96.0
const MH_PASS := 132.0
const GATES := [144.0, 156.0, 168.0, 180.0]
const TUNNEL_IN := 181.0
const DROP := 192.0
const BRAKE := 216.0
const SETTLE := 246.0
const CALLOUTS := [252.0, 258.0]
const SHIPS := [264.0, 288.0, 312.0]
const CRANE := 336.0
const CUTS := [348.0, 360.0, 372.0]
const SIGN_CUT := 384.0
const END := 420

const MH_W := 13.0
const MH_Y := 10.6           # MH logo centre above the deck
const LOGO_W := 38.0
const LOGO_Y := 19.4
const BEAUTY_D := 39.5       # hold: camera distance in front of the FTF sign

var _built := false
var _stage: MotionStage3D
var _curve: Curve3D
var _s := PackedFloat64Array()     # camera distance along the circuit per frame
var _len := 0.0
var _s_mh := 0.0
var _s_gates: Array[float] = []
var _s_tunnel := Vector2.ZERO
var _s_sign := 0.0
var _sign_fr: Transform3D
var _mh_fr: Transform3D

var _m_solid: ShaderMaterial
var _m_lights: ShaderMaterial
var _m_pads: ShaderMaterial
var _m_city: ShaderMaterial
var _m_body: ShaderMaterial
var _m_mh: ShaderMaterial
var _m_ftf: ShaderMaterial
var _m_trails: Array[ShaderMaterial] = []
var _grid_mat: ShaderMaterial
var _presents: MotionPanel3D
var _presents_text: MotionText
var _presents_jp: MotionText
var _boards: Array[MotionPanel3D] = []
var _beam_panel: MotionPanel3D
var _billboards: Array[MotionPanel3D] = []

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
var _flash: ColorRect
var _fade: ColorRect


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": SETTLE, "out": CRANE}
	for i in POWER.size():
		cue(POWER[i], &"power", 0.55 + 0.15 * i, {pitch = [1.0, 1.12, 1.26, 1.5][i]})
	cue(HUD_IN, &"hud.type", 0.5)
	cue(LAUNCH - 10.0, &"launch", 1.0)   # the engine swell starts before the bar
	cue(MH_ON, &"neon", 0.9)
	cue(PRESENTS, &"presents", 0.8)
	cue(MH_PASS - 6.0, &"pass", 0.8)      # a pass-by whoosh peaks under the gantry
	for i in GATES.size():
		cue(GATES[i] - 4.0, &"gate", 0.7 + 0.08 * i, {pitch = [1.0, 0.94, 1.06, 0.89][i]})
	cue(TUNNEL_IN - 2.0, &"tunnel", 0.9)
	cue(DROP, &"drop", 1.0)
	cue(BRAKE, &"brake", 0.9)
	cue(SETTLE - 6.0, &"settle", 0.8)
	for i in CALLOUTS.size():
		cue(CALLOUTS[i], &"callout", 0.6, {pitch = [1.0, 1.19][i]})
	for i in SHIPS.size():
		cue(SHIPS[i] - 14.0, &"ship", 0.75 + 0.1 * i, {pitch = [1.0, 0.9, 1.1][i]})
	cue(CRANE, &"crane", 0.7)
	for i in CUTS.size():
		cue(CUTS[i], &"cut", 0.6 + 0.12 * i, {pitch = [1.0, 0.84, 0.71][i]})
	cue(SIGN_CUT, &"sign.cut", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== timing

## Camera speed in metres per frame at key frames; smoothstep between keys.
const SPEED_KEYS := [[0.0, 0.0], [40.0, 0.12], [48.0, 0.25], [60.0, 1.7], [80.0, 1.15], [120.0, 0.9],
	[136.0, 2.4], [150.0, 4.6], [192.0, 4.8], [204.0, 3.0], [224.0, 0.6], [246.0, 0.15], [420.0, 0.15]]


static func _speed(f: float) -> float:
	for k in range(1, SPEED_KEYS.size()):
		var a: Array = SPEED_KEYS[k - 1]
		var b: Array = SPEED_KEYS[k]
		if f <= b[0]:
			var t := clampf((f - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return lerpf(a[1], b[1], t * t * (3.0 - 2.0 * t))
	return SPEED_KEYS[SPEED_KEYS.size() - 1][1]


func _make_table() -> void:
	_s.resize(END + 64)
	var s := 0.0
	_s[0] = 0.0
	for i in range(1, _s.size()):
		for k in 8:   # integrate on eighths of a frame
			s += _speed(i - 1 + (k + 0.5) / 8.0) / 8.0
		_s[i] = s


## Camera distance along the circuit at frame f (pure: a table lookup).
func s_at(f: float) -> float:
	var fc := clampf(f, 0.0, _s.size() - 1.001)
	var i := int(fc)
	return lerpf(_s[i], _s[i + 1], fc - i)


# ================================================================== build

func _build() -> void:
	_built = true
	_make_table()
	_s_mh = s_at(MH_PASS)
	for g in GATES:
		_s_gates.append(s_at(g))
	_s_tunnel = Vector2(s_at(TUNNEL_IN), s_at(DROP))
	_s_sign = s_at(SETTLE) + BEAUTY_D + 2.0   # the ride ends just behind the hold pose
	_curve = GB.circuit(s_at(140.0))
	_len = _curve.get_baked_length()

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = size
	add_child(bg)
	_stage = MotionStage3D.new()
	_stage.size = size
	add_child(_stage)
	_stage.night(Color("#11163c"), Color("#11163c"), 0.0055, 0.85)

	_m_solid = MotionStage3D.unlit(Color.WHITE, 1.0)
	_m_body = MotionStage3D.unlit(Color.WHITE, 1.0)
	_m_lights = MotionStage3D.unlit(Color.WHITE, 2.6, 0.03)
	_m_lights.set_shader_parameter("lit_soft", 6.0)
	_m_pads = MotionStage3D.unlit(Color.WHITE, 2.0, 0.08)
	_m_city = MotionStage3D.unlit(Color.WHITE, 1.25)
	_m_mh = MotionStage3D.unlit(Color.WHITE, 1.0)
	_m_ftf = MotionStage3D.unlit(Color.WHITE, 1.0)

	var solid := SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lights := SurfaceTool.new()
	lights.begin(Mesh.PRIMITIVE_TRIANGLES)
	_mh_fr = GB.gantry(solid, lights, _curve, _s_mh, 9.2, 7.0, 1.6, FTFKit.WHITE)
	var gate_cols := [FTFKit.LIME, FTFKit.LILAC, FTFKit.ORANGE, FTFKit.PINK]
	for i in _s_gates.size():
		GB.gantry(solid, lights, _curve, _s_gates[i], 9.0, 6.4, 1.9, gate_cols[i])
	GB.tunnel(solid, lights, _curve, _s_tunnel.x, _s_tunnel.y + 4.0)
	_sign_fr = GB.gantry(solid, lights, _curve, _s_sign, 22.0, 12.2, 2.2, FTFKit.PINK)

	_add_mesh(GB.track_solid(_curve, _len), _m_solid)
	_add_mesh(GB.track_lights(_curve, _len), _m_lights)
	_add_mesh(solid.commit(), _m_solid)
	_add_mesh(lights.commit(), _m_lights)
	var pad_at := []
	var ps := 60.0
	while ps < _len:
		pad_at.append(ps)
		ps += 46.0
	_add_mesh(GB.pads(_curve, pad_at), _m_pads)
	var city: Array = GB.skyline(_curve, _len)
	_add_mesh(city[0], _m_body)
	_add_mesh(city[1], _m_city)
	_add_grid()

	# light trails: one ahead of us in the corner, three passing under the sign
	var trail_cols := [FTFKit.PINK, FTFKit.LIME, FTFKit.CYAN, FTFKit.WHITE]
	var trail_x := [-2.6, 3.0, -3.2, 2.2]
	for i in trail_cols.size():
		var m := MotionStage3D.unlit(Color.WHITE, 3.0, 0.0)
		m.set_shader_parameter("lit_soft", 18.0)
		m.set_shader_parameter("lit_to", -100.0)
		_m_trails.append(m)
		_add_mesh(GB.trail_lane(_curve, _len, trail_x[i], 0.7, trail_cols[i]), m)

	_build_signs()
	_build_overlay()
	_add_sound()


func _add_mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_stage.world.add_child(mi)
	return mi


func _add_grid() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	_grid_mat = ShaderMaterial.new()
	_grid_mat.shader = load("res://demo/ftf/ftf_gantry/grid.gdshader")
	var mi := _add_mesh(plane, _grid_mat)
	mi.position = Vector3(-300, GB.FLOOR_Y + 0.05, -500)


func _build_signs() -> void:
	# Minimal Humans: extruded lockup on top of the first gantry's beam
	var mh: MotionSvgData = load("res://demo/assets/logos/mh_logoFull_standard.svg")
	var mh_mesh := MotionSvgMesh.build(mh, MH_W, {depth = 0.5, side_shade = 0.55})
	var mi := _add_mesh(mh_mesh, _m_mh)
	mi.transform = _mh_fr * Transform3D(Basis(), Vector3(0, MH_Y, 0.0))
	# PRESENTS on the beam's face
	_presents = MotionPanel3D.new()
	_presents.pixel_size = Vector2i(1536, 144)
	_presents.world_size = Vector2(17.6, 1.65)
	_presents.background = Color("#0b0d22")
	_presents.transform = _mh_fr * Transform3D(Basis(), Vector3(0, 7.8, 0.53))
	_stage.world.add_child(_presents)
	_presents_text = FTFKit.text(_presents.canvas, "ext", 74, FTFKit.WHITE, "PRESENTS", 0.62)
	_presents_text.position = Vector2(768 - _presents_text.get_text_size().x * 0.5 + 24, 26)
	_presents_jp = FTFKit.text(_presents.canvas, "jp", 44, FTFKit.PINK, "提供")
	_presents_jp.position = Vector2(1400, 40)
	var mk := FTFKit.text(_presents.canvas, "mono", 26, FTFKit.STONE, "MH//01", 0.1)
	mk.position = Vector2(48, 54)

	# sponsor boards on the gates
	var boards := [
		["SPARROW", "S07", "スパロー", FTFKit.LIME, FTFKit.INK],
		["STARLING", "T23", "スターリング", FTFKit.LILAC, FTFKit.WHITE],
		["KESTREL", "K45", "ケストレル", FTFKit.ORANGE, FTFKit.INK],
		["F-9000", "A.G.", "反重力レース", FTFKit.PINK, FTFKit.WHITE],
	]
	for i in boards.size():
		var b: Array = boards[i]
		var p := MotionPanel3D.new()
		p.pixel_size = Vector2i(1536, 168)
		p.world_size = Vector2(18.2, 1.99)
		p.background = b[3]
		p.animated = false
		var fr := GB.frame_at(_curve, _s_gates[i])
		p.transform = fr * Transform3D(Basis(), Vector3(0, 6.4 + 0.95, 0.53))
		_stage.world.add_child(p)
		var fg: Color = b[4]
		var name := FTFKit.text(p.canvas, "wide", 96, fg, b[0], 0.02)
		name.position = Vector2(60, 14)
		var code := FTFKit.text(p.canvas, "mono", 40, fg, b[1], 0.1)
		code.position = Vector2(1536 - 60 - code.get_text_size().x, 22)
		var jp := FTFKit.text(p.canvas, "jp", 34, fg, b[2])
		jp.position = Vector2(1536 - 60 - jp.get_text_size().x, 96)
		var c := MotionCanvas.new()
		var px := 60.0 + name.get_text_size().x + 40.0
		c.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
			FTFKit.chevrons(cv, Vector2(px, 84), 9, 70, fg, 0.0, 1.0, 1.0, 0.9)
		p.canvas.add_child(c)
		_boards.append(p)

	# billboards on the towers along the corner: DR-style supergraphics
	var bills := [
		[0.18, -1.0, "反重力", FTFKit.PINK, FTFKit.INK, "jp"],
		[0.42, 1.0, "S07", FTFKit.LIME, FTFKit.INK, "wide"],
		[0.66, -1.0, "加速", FTFKit.CYAN, FTFKit.INK, "jp"],
		[0.86, 1.0, "FTF", FTFKit.INK, FTFKit.PINK, "wide"],
	]
	var corner_a := s_at(140.0)
	var corner_b := _s_tunnel.x
	for i in bills.size():
		var bl: Array = bills[i]
		var bs := lerpf(corner_a, corner_b, bl[0])
		var fr := GB.frame_at(_curve, bs)
		var side: float = bl[1]
		var bp := MotionPanel3D.new()
		bp.pixel_size = Vector2i(512, 768)
		bp.world_size = Vector2(16, 24)
		bp.background = bl[3]
		bp.animated = false
		bp.energy = 1.0
		# stand beside the circuit, turned to face oncoming traffic
		var pos := fr * Vector3(side * 30.0, 18.0, -30.0)
		var face := Basis(Vector3.UP, fr.basis.get_euler().y - side * 0.55)
		bp.transform = Transform3D(face, pos)
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
			FTFKit.chevrons(cv, Vector2(40, 700), 8, 60, fgc, 0.0, 1.0, 1.0, 0.9)
			FTFKit.xbox(cv, Vector2(460, 52), 56, fgc, 4.0)
		bp.canvas.add_child(bc)
		_billboards.append(bp)

	# FULL THROTTLE FLUX: the big sign. Letters and FLUX stand proud of the plate.
	var logo: MotionSvgData = load(FTFKit.LOGO)
	var proud := FTFKit.WORD + FTFKit.FLUX_TOP + FTFKit.FLUX_BOT + [FTFKit.FLUX_BOWL, FTFKit.TAB] + FTFKit.SMALL + FTFKit.CHECKS
	var ftf_mesh := MotionSvgMesh.build(logo, LOGO_W, {depth = 0.9, side_shade = 0.6,
		part_fn = func(i: int) -> Dictionary:
			if i == FTFKit.PLATE:
				return {depth = 0.9, z = 0.0, color = Color(0.92, 0.92, 0.95)}
			if i == FTFKit.RIM:
				return {depth = 1.2, z = -0.1}
			if proud.has(i):
				return {depth = 0.5, z = 0.9 + i * 0.012}   # each part a hair proud of the last
			return {}})
	var lm := _add_mesh(ftf_mesh, _m_ftf)
	lm.transform = _sign_fr * Transform3D(Basis(), Vector3(0, LOGO_Y, 0.0))
	# katakana board on the big gantry's beam
	_beam_panel = MotionPanel3D.new()
	_beam_panel.pixel_size = Vector2i(2048, 112)
	_beam_panel.world_size = Vector2(44.4, 2.24)
	_beam_panel.background = Color("#0b0d22")
	_beam_panel.animated = false
	_beam_panel.transform = _sign_fr * Transform3D(Basis(), Vector3(0, 13.3, 0.53))
	_stage.world.add_child(_beam_panel)
	var kj := FTFKit.text(_beam_panel.canvas, "jp", 58, FTFKit.WHITE, "フルスロットル・フラックス")
	kj.position = Vector2(56, 16)
	var kl := FTFKit.text(_beam_panel.canvas, "mono", 34, FTFKit.LIME, "F-9000 // ANTI-GRAVITY LEAGUE // SEASON 01", 0.1)
	kl.position = Vector2(2048 - 56 - kl.get_text_size().x, 36)


func _build_overlay() -> void:
	_streaks = MotionCanvas.new()
	_streaks.draw_fn = _draw_streaks
	add_child(_streaks)
	var vig := MotionGradient.radial(size, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.75)], [0.0, 0.55, 1.0], Vector2(0.5, 0.5))
	add_child(vig)

	_hud = Node2D.new()
	add_child(_hud)
	_hud_canvas = MotionCanvas.new()
	_hud_canvas.draw_fn = _draw_hud
	_hud.add_child(_hud_canvas)
	_hud_l1 = FTFKit.text(_hud, "mono", 22, FTFKit.WHITE, "F-9000 // ANTI-GRAVITY LEAGUE", 0.14)
	_hud_l1.position = Vector2(96, 70)
	_hud_l2 = FTFKit.text(_hud, "mono", 22, FTFKit.LIME, "NIGHT CIRCUIT // UTOPIA // LAP 1/3", 0.14)
	_hud_l2.position = Vector2(96, 102)
	_speed_txt = FTFKit.text(_hud, "tall", 120, FTFKit.WHITE, "000", 0.02)
	_speed_unit = FTFKit.text(_hud, "mono", 22, FTFKit.PINK, "KM/H", 0.2)
	_lap = FTFKit.text(_hud, "mono", 30, FTFKit.WHITE, "00:00.00", 0.08)
	_lap.position = Vector2(96, 960)

	_call = MotionCanvas.new()
	_call.draw_fn = _draw_callouts
	add_child(_call)
	_call_a = FTFKit.text(self, "mono", 22, FTFKit.WHITE, "SPONSOR GANTRY 09 // 32.0 M SPAN", 0.12)
	_call_b = FTFKit.text(self, "mono", 22, FTFKit.LIME, "フルスロットル・フラックス // S.01", 0.06)

	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_fade = ColorRect.new()
	_fade.size = size
	_fade.color = Color(0, 0, 0, 0)
	add_child(_fade)


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_gantry/audio/gantry_map.tres"
	const SONG := "res://demo/ftf/ftf_gantry/audio/music/gantry_song.tres"
	const TRACK := "res://demo/ftf/ftf_gantry/audio/ftf_gantry_track.res"
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


# ================================================================== camera

func _sign_centre() -> Vector3:
	return _sign_fr * Vector3(0, LOGO_Y, 0)


func _beauty(f: float) -> Transform3D:
	var hold := MK.map(f, [SETTLE - 10.0, CRANE], [0, 1], MK.ease_in_out)
	var d := lerpf(BEAUTY_D, BEAUTY_D - 4.4, hold)
	var orbit := 1.8 * sin((f - SETTLE) / 40.0) * MK.map(f, [SETTLE - 20.0, SETTLE + 20.0], [0, 1])
	var pos := _sign_fr * Vector3(orbit, LOGO_Y - 2.0, d)
	# outro: rise and pull back, looking down the circuit past the sign
	var up := MK.map(f, [CRANE, SIGN_CUT + 6.0], [0, 1], MK.ease_in_out)
	pos += _sign_fr.basis * Vector3(0, 46.0 * up, 40.0 * up)
	var target := _sign_centre() + _sign_fr.basis * Vector3(0, -8.0 * up, -55.0 * up)
	return MotionStage3D.look(pos, target)


func _camera(f: float) -> Array:
	var s := s_at(f)
	var spd := _speed(f)
	var ride := MotionStage3D.ride(_curve, s, 1.55, 26.0, 1.2)
	# attention: look up towards the MH sign on the approach, then the FTF sign
	var mh_c := _mh_fr * Vector3(0, MH_Y - 1.0, 0)
	var w_mh := MK.map(f, [58, 90], [0, 0.55], MK.ease_in_out) * (1.0 - MK.map(f, [118, 131], [0, 1], MK.ease_in_out))
	var w_ftf := MK.map(f, [196, 222], [0, 0.85], MK.ease_in_out)
	var ahead := ride.origin - ride.basis.z * 26.0
	var target := ahead.lerp(mh_c, w_mh).lerp(_sign_centre(), w_ftf)
	var xf := MotionStage3D.look(ride.origin, target, ride.basis.y)
	# rumble with speed, a jolt on the drop
	var rum := 0.018 * spd
	var shake := Vector3(sin(f * 2.3) * 0.6 + sin(f * 5.1) * 0.4, sin(f * 3.7) * 0.5 + sin(f * 7.3) * 0.5, 0) * rum
	var jolt := MK.shakes(f, [LAUNCH, DROP, BRAKE], 1.0, 9)
	xf.origin += xf.basis * (shake + Vector3(jolt.x, jolt.y, 0) * 0.05)
	# crane to the beauty pose
	var crane := MK.map(f, [BRAKE, SETTLE], [0, 1], MK.ease_in_out)
	if crane > 0.0:
		xf = MotionStage3D.blend(xf, _beauty(f), crane)
	var fov := 66.0 + spd * 1.6
	fov += 9.0 * maxf(0.0, 1.0 - MK.map(f, [LAUNCH, LAUNCH + 14], [0, 1])) * float(f >= LAUNCH)
	fov += 14.0 * maxf(0.0, 1.0 - MK.map(f, [DROP, DROP + 18], [0, 1])) * float(f >= DROP)
	fov = lerpf(fov, 50.0, crane)
	return [xf, fov]


# ================================================================== frame

func _flicker(f: float, at: float, seed_v: float) -> float:
	if f < at:
		return 0.0
	var t := f - at
	if t > 8.0:
		return 1.0
	return 1.0 if MK.rand(floorf(t) * 3.1 + seed_v) > 0.45 - t * 0.05 else 0.15


func _frame(f: float) -> void:
	if not _built:
		return
	var cam: Array = _camera(f)
	_stage.set_camera(cam[0], cam[1])

	# ---- power: light chase out along the circuit on the first four beats
	var reach := 0.0
	var steps := [25.0, 80.0, 220.0, _len + 50.0]
	for i in POWER.size():
		if f >= POWER[i]:
			reach = lerpf(reach if i == 0 else steps[i - 1], steps[i], MK.map(f, [POWER[i], POWER[i] + 9.0], [0, 1], MK.ease_out))
	# outro: the far end cuts first, towards us
	var cut_to := _len + 50.0
	var cut_steps := [_s_sign + 220.0, _s_sign + 40.0, _s_sign - 60.0]
	for i in CUTS.size():
		if f >= CUTS[i]:
			cut_to = cut_steps[i]
	if f >= SIGN_CUT:
		cut_to = -100.0
	_m_lights.set_shader_parameter("lit_to", minf(reach, cut_to))
	_m_pads.set_shader_parameter("lit_to", minf(reach, cut_to))
	var pulse := 1.0 + 0.6 * exp(-fposmod(f, 12.0) * 0.35) * float(f >= LAUNCH)
	_m_pads.set_shader_parameter("energy", 1.15 * pulse)
	var city := MK.map(f, [POWER[3], POWER[3] + 20.0], [0, 1]) * (1.0 - MK.map(f, [CUTS[0], CUTS[0] + 4.0], [0, 1], MK.linear))
	_m_city.set_shader_parameter("energy", 1.25 * city)
	var lvl := 0.0
	var lvls := [0.15, 0.35, 0.6, 1.0]
	for i in POWER.size():
		if f >= POWER[i]:
			lvl = lerpf(lvl, lvls[i], MK.map(f, [POWER[i], POWER[i] + 5.0], [0, 1], MK.ease_out))
	_m_body.set_shader_parameter("energy", lvl)
	_m_solid.set_shader_parameter("energy", lvl)
	# the drop: every light on the circuit flares
	var flare := 1.0 + 1.4 * exp(-maxf(0.0, f - DROP) / 5.0) * float(f >= DROP)
	_m_lights.set_shader_parameter("energy", 2.6 * flare)
	var env := _stage.environment
	var sky := MK.map(f, [POWER[1], POWER[3] + 6.0], [0, 1]) * (1.0 - MK.map(f, [CUTS[1], SIGN_CUT + 10.0], [0, 1], MK.linear))
	env.background_color = Color("#11163c") * sky
	env.fog_light_color = Color("#11163c") * sky
	_grid_mat.set_shader_parameter("energy", sky * (1.0 - MK.map(f, [CUTS[0], CUTS[0] + 6.0], [0, 1], MK.linear) * 0.6))

	# ---- signs
	var mh_e := _flicker(f, MH_ON, 7.0)
	var mh_off := 1.0 - MK.map(f, [CUTS[2], CUTS[2] + 2.0], [0, 1], MK.linear)
	_m_mh.set_shader_parameter("energy", lerpf(0.06, 1.15, mh_e) * mh_off)
	_presents.energy = (0.08 + 1.3 * _flicker(f, PRESENTS, 11.0)) * mh_off
	_presents_text.visible_chars = int(MK.map(f, [PRESENTS, PRESENTS + 10.0], [0, 8], MK.linear))
	_presents_jp.visible = f >= PRESENTS + 10.0
	var boards_on := MK.map(f, [LAUNCH, LAUNCH + 6.0], [0, 1], MK.linear) * mh_off
	for i in _boards.size():
		var hit := exp(-maxf(0.0, f - GATES[i]) * 0.3) * float(f >= GATES[i] - 2.0)
		_boards[i].energy = boards_on * (1.05 + 0.8 * hit)
	for bp in _billboards:
		bp.energy = 1.1 * city
	var sign_e := _flicker(f, DROP - 2.0, 3.0)
	var accent := 0.0
	for a in [288.0, 324.0]:
		if f >= a and f < a + 3.0:
			accent = 1.0
	var sign_cut := 1.0 - MK.map(f, [SIGN_CUT, SIGN_CUT + 3.0], [0, 1], MK.linear)
	_m_ftf.set_shader_parameter("energy", lerpf(0.05, 1.12, sign_e) * (1.0 + 0.5 * accent) * sign_cut)
	_beam_panel.energy = lerpf(0.05, 1.2, _flicker(f, DROP + 6.0, 5.0)) * sign_cut

	# ---- light trails: a ship ahead in the corner, ships under the sign in the hold
	_trail(0, f, 146.0, s_at(146.0) + 150.0, 4.45, 45.0)
	for i in SHIPS.size():
		var start: float = SHIPS[i] - 24.0
		_trail(i + 1, f, start, _s_sign - 140.0, 6.4, 70.0)

	_frame_overlay(f)


## Trail i: its head starts at s0 at frame f0 and moves v metres a frame.
func _trail(i: int, f: float, f0: float, s0: float, v: float, length: float) -> void:
	var m := _m_trails[i]
	if f < f0 or f > f0 + 70.0:
		m.set_shader_parameter("lit_to", -1000.0)
		m.set_shader_parameter("lit_from", -1000.0)
		return
	var head := s0 + (f - f0) * v
	m.set_shader_parameter("lit_to", head)
	m.set_shader_parameter("lit_from", head - length)


func _frame_overlay(f: float) -> void:
	var hud_on := MK.map(f, [HUD_IN, HUD_IN + 4.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [BRAKE, BRAKE + 10.0], [0, 1], MK.linear))
	_hud.visible = hud_on > 0.0
	_hud.modulate.a = hud_on
	_hud_l1.visible_chars = int(MK.map(f, [HUD_IN, HUD_IN + 14.0], [0, 29], MK.linear))
	_hud_l2.visible_chars = int(MK.map(f, [HUD_IN + 6.0, HUD_IN + 22.0], [0, 34], MK.linear))
	var kmh := _speed(f) * 30.0 * 3.6
	_speed_txt.text = "%03d" % int(kmh)
	_speed_txt.position = Vector2(1824 - _speed_txt.get_text_size().x, 50)
	_speed_unit.position = Vector2(1824 - _speed_unit.get_text_size().x, 50 + 132)
	var t := f / 30.0
	_lap.text = "%02d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]
	_lap.visible = f >= LAUNCH
	_streaks.visible = f > 136.0 and f < BRAKE + 6.0
	var fl := 0.0
	if f >= DROP:
		fl = maxf(fl, 0.3 * (1.0 - MK.map(f, [DROP, DROP + 4.0], [0, 1], MK.linear)))
	if f >= SIGN_CUT:
		fl = maxf(fl, 0.18 * (1.0 - MK.map(f, [SIGN_CUT, SIGN_CUT + 3.0], [0, 1], MK.linear)))
	_flash.color.a = fl
	_flash.visible = fl > 0.0
	_fade.color.a = MK.map(f, [SIGN_CUT + 2.0, SIGN_CUT + 12.0], [0, 1], MK.linear) + (1.0 - MK.map(f, [0, 6], [0, 1], MK.linear))
	_fade.visible = _fade.color.a > 0.0
	# callouts pinned to the sign's corners
	var ca := MK.map(f, [CALLOUTS[0], CALLOUTS[0] + 14.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [CRANE, CRANE + 8.0], [0, 1], MK.linear))
	var cb := MK.map(f, [CALLOUTS[1], CALLOUTS[1] + 14.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [CRANE, CRANE + 8.0], [0, 1], MK.linear))
	_call.visible = ca > 0.0
	_call_a.visible = ca > 0.0
	_call_b.visible = cb > 0.0
	if ca > 0.0:
		var p := _stage.to_screen(_sign_fr * Vector3(-LOGO_W * 0.5 + 1.4, LOGO_Y + 4.6, 1.6))
		_call_a.position = p + Vector2(-20, -70 - 34)
		_call_a.visible_chars = int(ca * 33.0)
		var q := _stage.to_screen(_sign_fr * Vector3(LOGO_W * 0.5 - 1.4, LOGO_Y + 4.6, 1.6))
		_call_b.position = q + Vector2(-_call_b.get_text_size().x + 20, -140 - 34)
		_call_b.visible_chars = int(cb * 22.0)


func _draw_streaks(c: MotionCanvas, f: float) -> void:
	var spd := _speed(f)
	var fade := MK.map(f, [136, 150], [0, 1]) * (1.0 - MK.map(f, [BRAKE - 8.0, BRAKE + 6.0], [0, 1]))
	if fade <= 0.0:
		return
	var vp := _stage.to_screen(_stage.camera.global_transform * Vector3(0, 0, -400))
	for i in 70:
		var a := MK.rand(i * 7.13 + 1.0) * TAU
		var dir := Vector2(cos(a), sin(a) * 0.62)
		var ph := fposmod(f * (0.05 + 0.04 * MK.rand(i * 3.3)) * spd + MK.rand(i * 1.9), 1.0)
		var r0 := 260.0 + ph * ph * 1100.0
		var len := 40.0 + ph * 240.0
		var col := FTFKit.WHITE if i % 5 else FTFKit.CYAN
		c.line(vp + dir * r0, vp + dir * (r0 + len), col, 1.5 + ph * 2.0, 0.28 * fade * ph)


func _draw_hud(c: MotionCanvas, f: float) -> void:
	# a progress rail along the bottom with a marker for the camera
	var p := clampf(s_at(f) / _s_sign, 0.0, 1.0)
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
		var mx := lerpf(x0, x1, p)
		c.polygon(PackedVector2Array([Vector2(mx, 972), Vector2(mx + 12, 960), Vector2(mx - 12, 960)]), FTFKit.PINK, Color(0, 0, 0, 0))
	FTFKit.chevrons(c, Vector2(1640, 230), 6, 26, FTFKit.LIME, fposmod(f / 4.0, 1.0), 1.0, on, 0.9)


func _draw_callouts(c: MotionCanvas, f: float) -> void:
	var ca := MK.map(f, [CALLOUTS[0], CALLOUTS[0] + 10.0], [0, 1]) * (1.0 - MK.map(f, [CRANE, CRANE + 8.0], [0, 1]))
	var cb := MK.map(f, [CALLOUTS[1], CALLOUTS[1] + 10.0], [0, 1]) * (1.0 - MK.map(f, [CRANE, CRANE + 8.0], [0, 1]))
	var a3 := _sign_fr * Vector3(-LOGO_W * 0.5 + 1.4, LOGO_Y + 4.6, 1.6)
	var b3 := _sign_fr * Vector3(LOGO_W * 0.5 - 1.4, LOGO_Y + 4.6, 1.6)
	if ca > 0.0:
		var a := _stage.to_screen(a3)
		var e := a - Vector2(0, 70) * ca
		c.line(a, e, FTFKit.WHITE, 2.0, ca)
		c.line(e, e + Vector2(-20 + 420.0 * ca, 0), FTFKit.WHITE, 2.0, ca)
		FTFKit.crosshair(c, a, 9, FTFKit.WHITE, 2.0, ca)
	if cb > 0.0:
		var b := _stage.to_screen(b3)
		var e := b - Vector2(0, 140) * cb
		c.line(b, e, FTFKit.LIME, 2.0, cb)
		c.line(e, e + Vector2(20 - 380.0 * cb, 0), FTFKit.LIME, 2.0, cb)
		FTFKit.crosshair(c, b, 9, FTFKit.LIME, 2.0, cb)
