# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take: WARNING.
#
# Brief: industrial hazard overload at 200 bpm. Hazard tape is thrown across the
# frame and whips as it lands; multilingual warnings run along it (WARNING /
# ACHTUNG / 警告 / ATTENTION / ВНИМАНИЕ); two rotating beacons sweep the scene.
# The Minimal Humans lockup hangs in on chains as a safety placard (NOTICE),
# PRESENTS is stamped on it, then its chains snap. Four warning signs (anti-
# gravity field, high voltage, extreme speed, magnetic lock) are stamped on the
# beats, a barrier countdown 4-3-2-1 closes two gates, and a wall of tape is
# thrown across the frame. On the drop the wall tears open and the FTF logo is
# there, full size, clamped by four hazard brackets while a tape frame with its
# name runs around it. The hold keeps moving: the frame text crawls, tapes whip
# behind on every bar, the clamps bite, the sign strip chases, the beacons
# sweep (faster after the escalation). Outro: nine tapes snap closed across the
# whole screen, then are yanked away to black.
#
# Photosensitivity: the alarm comes from motion, sweeps and rhythm. The only
# large-area flash is one white hit on the drop; no strobes, no red flashing.
#
# Tempo: 200 bpm, 4/4 = 9 frames a beat, 36 a bar at 30 fps; first downbeat at
# frame 0. Bars land on 0, 36, 72 ... 396; the drop is bar 5 (frame 180, 6.0 s).
#
# Beats (30 fps, 420 frames):
#   0/9/18/27   intro tapes thrown in, beacons on, HUD types
#   30-36       placard falls on its chains, lands on bar 1 (36); sways
#   54          PRESENTS stamped; 63 提供
#   108         chains snap, the placard drops away; intro tapes leave
#   108/117/126/135  warning signs stamped across the frame
#   144/153/162/171  countdown 4-3-2-1; gates close on 144 and 153
#   171-178.5   wall of tape thrown across on eighths
#   180         DROP: the wall tears open on the logo, flash, shake
#   189         clamps hit the corners; the name frame runs round (189-207); HUD tapes
#   216/252/288/324  bar accents: a tape whips behind, the clamps bite
#   216-360     sign strip chases a sign per beat
#   288         escalation: beacons double speed, tapes swap colours
#   360-367     nine tapes snap closed across the screen
#   378         yanked away; beacons off; black from 390
@tool
extends MotionComposition

const Look := preload("res://demo/ftf/ftf_warning/warning_look.gd")
const Signs := preload("res://demo/ftf/ftf_warning/warning_signs.gd")

const W := 1920.0
const H := 1080.0
const BEAT := 9.0
const BAR := 36.0

const INTRO_TAPES := [0.0, 9.0, 18.0, 27.0]
const PLACARD := 36.0
const PRESENTS := 54.0
const PRESENTS_JP := 63.0
const SNAP := 108.0
const SIGNS := [108.0, 117.0, 126.0, 135.0]
const COUNT := [144.0, 153.0, 162.0, 171.0]
const GATES := [144.0, 153.0]
const WALL := [171.0, 172.5, 174.0, 175.5, 177.0, 178.5]
const DROP := 180.0
const CLAMP := 189.0
const HUD_IN := [189.0, 198.0]
const STRIP := 216.0
const BARS := [216.0, 252.0, 288.0, 324.0]
const ESCALATE := 288.0
const CLOSE := 360.0
const YANK := 378.0
const DARK_AT := 390.0
const END := 420

const LOGO_W := 1500.0
const LOGO_C := Vector2(960, 520)
const FRAME_R := Rect2(140, 275, 1640, 490)
const WARN_TEXT := "WARNING ▲ ACHTUNG ▲ 警告 ▲ ATTENTION ▲ ВНИМАНИЕ ▲ 危険 ▲ "
const NOTICE_TEXT := "NOTICE ▲ MINIMAL HUMANS ▲ ミニマル・ヒューマンズ ▲ AUTHORISED PERSONNEL ONLY ▲ "
const NAME_TEXT := "FULL THROTTLE FLUX ▲ フルスロットル・フラックス ▲ ANTI-GRAVITY RACING ▲ 反重力 ▲ "
const HAZ_TEXT := "ANTI-GRAVITY FIELD ▲ 反重力 ▲ HIGH VOLTAGE ▲ 高電圧 ▲ EXTREME SPEED ▲ 速度超過 ▲ MAGNETIC LOCK ▲ 磁場 ▲ "
const SIGN_INFO := [
	[0, "ANTI-GRAVITY FIELD", "反重力"],
	[1, "HIGH VOLTAGE", "高電圧"],
	[2, "EXTREME SPEED", "速度超過"],
	[3, "MAGNETIC LOCK", "磁場"],
]

var _built := false
var _stage: Node2D
var _field: MotionGradient
var _back: Node2D
var _tapes: Array = []          # {spec, node, canvas, text}
# placard
var _placard: Node2D
var _plac_canvas: MotionCanvas
var _plac_border: Dictionary
var _mh: MotionSvg
var _presents: Node2D
var _presents_jp: MotionText
var _plac_texts: Array[Node2D] = []
# barrage
var _barrage: MotionCanvas
var _sign_labels: Array = []
# countdown
var _count_canvas: MotionCanvas
var _count_pivot: Node2D
var _count_text: MotionText
var _count_label: MotionText
var _plate_border: Dictionary
# logo
var _logo_grp: Node2D
var _logo: MotionSvg
var _clamps: MotionCanvas
var _strip: MotionCanvas
var _strip_labels: Array = []
# lights and overlays
var _beacons: Array[MotionBeacon] = []
var _lamps: MotionCanvas
var _hud: Array[MotionText] = []
var _flash: ColorRect


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": 216.0, "out": CLOSE}
	cue(0.0, &"alarm", 0.8)
	for i in INTRO_TAPES.size():
		cue(INTRO_TAPES[i], &"whip", 0.6 + 0.1 * i, {pitch = [1.0, 0.9, 1.12, 0.84][i]})
	cue(PLACARD - 7.0, &"chain", 0.7)
	cue(PLACARD, &"slam", 1.0)
	cue(PRESENTS, &"stamp", 0.9)
	cue(PRESENTS_JP, &"stamp.small", 0.6)
	cue(SNAP, &"snap", 1.0)
	for i in SIGNS.size():
		cue(SIGNS[i], &"sign", 0.75 + 0.08 * i, {pitch = [1.0, 1.12, 1.26, 1.5][i]})
	for i in COUNT.size():
		cue(COUNT[i], &"count", 0.7 + 0.1 * i, {pitch = [1.0, 1.12, 1.26, 1.5][i]})
	for i in GATES.size():
		cue(GATES[i] + 3.0, &"gate", 0.8)
	cue(WALL[0], &"wall", 0.9)
	cue(DROP, &"drop", 1.0)
	cue(DROP, &"tear", 0.9)
	cue(CLAMP, &"clamp", 1.0)
	cue(HUD_IN[1], &"whip", 0.6, {pitch = 1.2})
	for i in BARS.size():
		cue(BARS[i], &"bite", 0.8)
	cue(ESCALATE - 4.0, &"klaxon", 0.9)
	cue(CLOSE, &"close", 1.0)
	cue(YANK, &"yank", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = Look.BLACK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_field = MotionGradient.stripes(Vector2(2800, 2000), -45.0, [Look.DARK, Look.DARK, Look.BLACK, Look.BLACK], [0.0, 64.0, 64.0, 128.0])
	_field.position = Vector2(-440, -460)
	_stage.add_child(_field)
	_back = Node2D.new()
	_stage.add_child(_back)
	_build_back_tapes()
	_build_placard()
	_build_barrage()
	_build_countdown()
	_build_logo()
	_build_wall()      # in front of the logo: it tears open on it
	_build_close()
	_build_lights()
	_build_hud()
	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = Look.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_add_sound()


func _tape(parent: Node, spec: Dictionary) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	var canvas := MotionCanvas.new()
	node.add_child(canvas)
	var rec := {spec = spec, node = node, canvas = canvas, text = null, pose = {}}
	canvas.draw_fn = func(c: MotionCanvas, f: float) -> void:
		if rec.pose.is_empty():
			return
		MotionTape.draw(c, spec, rec.pose, f)
	if spec.get("style", "") == "text":
		var t := MotionTextPath.new()
		t.font = Look.font(spec.get("font", Look.FONT_WARN))
		t.font_size = spec.get("text_size", 34.0)
		t.color = spec.get("text_color", Look.BLACK)
		t.text = spec.get("text", WARN_TEXT)
		t.repeat = true
		t.gap = 0.0
		t.tracking = spec.get("tracking", 0.04)
		t.edge_fade = 0.0
		node.add_child(t)
		rec.text = t
	_tapes.append(rec)
	return rec


func _build_back_tapes() -> void:
	var y := Look.YELLOW
	var k := Look.BLACK
	var p := Look.PINK
	# intro: thrown in on the first four beats, leave as the placard drops
	_tape(_back, {a = Vector2(-220, 860), b = Vector2(2200, 280), width = 104, style = "text", col_a = y, col_b = k,
		text = WARN_TEXT, text_size = 42, text_scroll = -4.0, at = 0.0, dur = 8.0, wave_amp = 70.0, wave_len = 900.0, wave_decay = 12.0, wave_speed = 110.0,
		out = "follow", out_at = SNAP, out_dur = 10.0, seed = 3.0})
	_tape(_back, {a = Vector2(2200, 930), b = Vector2(-300, 600), width = 86, style = "stripes", col_a = y, col_b = k, period = 72.0, scroll = 3.0,
		at = 9.0, dur = 8.0, wave_amp = 60.0, wave_len = 760.0, wave_decay = 12.0, wave_speed = 120.0, out = "back", out_at = SNAP + 1.0, out_dur = 10.0, seed = 5.0})
	_tape(_back, {a = Vector2(260, -160), b = Vector2(1560, 1260), width = 86, style = "text", col_a = p, col_b = k,
		text = WARN_TEXT, text_size = 36, text_scroll = 5.0, at = 18.0, dur = 8.0, wave_amp = 60.0, wave_len = 700.0, wave_decay = 12.0, wave_speed = 120.0,
		out = "follow", out_at = SNAP + 2.0, out_dur = 10.0, seed = 7.0})
	_tape(_back, {a = Vector2(-260, 170), b = Vector2(2180, 420), width = 70, style = "stripes", col_a = p, col_b = k, period = 60.0, scroll = -3.0,
		at = 27.0, dur = 8.0, wave_amp = 50.0, wave_len = 700.0, wave_decay = 12.0, wave_speed = 120.0, out = "back", out_at = SNAP + 3.0, out_dur = 10.0, seed = 9.0})
	# barrage: two framing tapes
	_tape(_back, {a = Vector2(-120, 150), b = Vector2(2040, 150), width = 64, style = "stripes", col_a = y, col_b = k, period = 64.0, scroll = 4.0,
		at = SIGNS[0], dur = 6.0, wave_amp = 30.0, out = "back", out_at = COUNT[0], out_dur = 8.0, seed = 11.0})
	_tape(_back, {a = Vector2(2040, 930), b = Vector2(-120, 930), width = 64, style = "stripes", col_a = p, col_b = k, period = 64.0, scroll = 4.0,
		at = SIGNS[1], dur = 6.0, wave_amp = 30.0, out = "back", out_at = COUNT[0] + 1.0, out_dur = 8.0, seed = 13.0})
	# hold: one tape whips behind the logo on every bar
	var whips := [
		{a = Vector2(-300, 1180), b = Vector2(2250, -120), style = "stripes", col_a = y},
		{a = Vector2(2250, 1180), b = Vector2(-300, -120), style = "stripes", col_a = p},
		{a = Vector2(-300, 1020), b = Vector2(2250, 60), style = "text", col_a = y},
		{a = Vector2(-300, 60), b = Vector2(2250, 1020), style = "text", col_a = p},
	]
	for i in BARS.size():
		var wspec: Dictionary = whips[i]
		wspec.merge({width = 120, col_b = k, period = 80.0, scroll = 6.0, text = WARN_TEXT, text_size = 46, text_scroll = 6.0,
			at = BARS[i], dur = 6.0, wave_amp = 80.0, wave_len = 900.0, wave_decay = 10.0, wave_speed = 140.0,
			out = "follow", out_at = BARS[i] + 14.0, out_dur = 9.0, seed = 20.0 + i})
		_tape(_back, wspec)


func _sign_rect() -> Rect2:
	return Rect2(-620, 510, 1240, 620)


func _build_placard() -> void:
	_placard = Node2D.new()
	_stage.add_child(_placard)
	_plac_canvas = MotionCanvas.new()
	_plac_canvas.draw_fn = _draw_placard
	_placard.add_child(_plac_canvas)
	var r := _sign_rect()
	var pts := MotionPath.rounded_rect(r.grow(-15.0), 34.0, 6)
	var total := MotionTextPath.path_lengths(pts, true)
	var L: float = total[total.size() - 1]
	_plac_border = {pts = pts, closed = true, width = 30.0, style = "stripes", col_a = Look.YELLOW, col_b = Look.BLACK,
		period = L / roundf(L / 62.0), slant = 15.0, scroll = 0.0}
	_mh = MotionSvg.new()
	_mh.data = _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh.width = 860.0
	var mh_h := 860.0 * _mh.data.view_box.size.y / _mh.data.view_box.size.x
	_mh.position = Vector2(-430, 790 - mh_h * 0.5 - 10.0)
	_placard.add_child(_mh)
	var notice := Look.text(_placard, Look.FONT_WARN, 62, Look.BLACK, "NOTICE")
	notice.position = Vector2(r.position.x + 64, 528)
	var langs := Look.text(_placard, Look.FONT_LABEL, 30, Look.BLACK, "注意 // ACHTUNG // ВНИМАНИЕ")
	langs.position = Vector2(r.end.x - 64 - langs.get_text_size().x, 546)
	var foot := Look.text(_placard, Look.FONT_MONO, 20, Look.STONE, "MH-01 // FOSS STUDIO // BERLIN 52.52N 13.34E // AUTHORISED PERSONNEL ONLY", 0.08)
	foot.position = Vector2(-foot.get_text_size().x * 0.5, 1062)
	var pres := Look.text(_placard, Look.FONT_STENCIL, 96, Look.WHITE, "PRESENTS", 0.3)
	_presents = Node2D.new()
	_presents.position = Vector2(-60, 975)
	_placard.add_child(_presents)
	_placard.remove_child(pres)
	_presents.add_child(pres)
	pres.position = -pres.get_text_size() * 0.5
	_presents_jp = Look.text(_placard, Look.FONT_JP, 54, Look.YELLOW, "提供")
	_presents_jp.position = Vector2(-60 + pres.get_text_size().x * 0.5 + 34, 975 - _presents_jp.get_text_size().y * 0.5)
	_plac_texts = [notice, langs, foot]


func _build_barrage() -> void:
	_barrage = MotionCanvas.new()
	_barrage.draw_fn = _draw_barrage
	_stage.add_child(_barrage)
	for i in 4:
		var info: Array = SIGN_INFO[i]
		var a := Look.text(_stage, Look.FONT_LABEL, 34, Look.WHITE, info[1])
		var b := Look.text(_stage, Look.FONT_JP, 30, Look.YELLOW, info[2])
		_sign_labels.append([a, b])


func _build_countdown() -> void:
	_count_canvas = MotionCanvas.new()
	_count_canvas.draw_fn = _draw_countdown
	_stage.add_child(_count_canvas)
	var plate := Rect2(-215, -215, 430, 430)
	var pts := MotionPath.rounded_rect(plate.grow(-34.0), 20.0, 5)
	var total := MotionTextPath.path_lengths(pts, true)
	var L: float = total[total.size() - 1]
	_plate_border = {pts = pts, closed = true, width = 36.0, style = "stripes", col_a = Look.YELLOW, col_b = Look.BLACK,
		period = L / roundf(L / 56.0), slant = 18.0}
	_count_pivot = Node2D.new()
	_count_pivot.position = Vector2(960, 470)
	_stage.add_child(_count_pivot)
	_count_text = Look.text(_count_pivot, Look.FONT_WARN, 250, Look.BLACK, "4")
	_count_label = Look.text(_stage, Look.FONT_WARN, 34, Look.WHITE, "IMPACT IN ▲ 起動", 0.06)
	_count_label.position = Vector2(960 - _count_label.get_text_size().x * 0.5, 200)


func _build_wall() -> void:
	var y := Look.YELLOW
	var k := Look.BLACK
	var p := Look.PINK
	var lines := [
		[Vector2(-300, 360), Vector2(2220, 540), y],
		[Vector2(2220, 720), Vector2(-300, 560), p],
		[Vector2(-300, 660), Vector2(2220, 260), y],
		[Vector2(2220, 300), Vector2(-300, 780), p],
		[Vector2(-300, 500), Vector2(2220, 470), y],
		[Vector2(2220, 840), Vector2(-300, 200), p],
	]
	for i in lines.size():
		var a: Vector2 = lines[i][0]
		var b: Vector2 = lines[i][1]
		var tear := (960.0 - a.x) / (b.x - a.x)
		_tape(_stage, {a = a, b = b, width = 170.0 if i != 4 else 210.0, style = "stripes", col_a = lines[i][2], col_b = k, period = 96.0, slant = 70.0,
			scroll = 5.0 * (1 if i % 2 == 0 else -1), at = WALL[i], dur = 4.0, wave_amp = 34.0, wave_len = 800.0, wave_decay = 6.0, wave_speed = 160.0,
			out = "tear", tear = tear, out_at = DROP, out_dur = 3.0 + i * 0.4, seed = 40.0 + i})


func _build_logo() -> void:
	_logo_grp = Node2D.new()
	_stage.add_child(_logo_grp)
	var frame_pts := MotionPath.rounded_rect(FRAME_R, 110.0, 10)
	_tape(_logo_grp, {pts = frame_pts, closed = true, width = 46.0, style = "text", col_a = Look.YELLOW, col_b = Look.BLACK,
		text = NAME_TEXT, text_size = 25, text_scroll = 3.0, at = CLAMP, dur = 18.0, seed = 60.0, edge_w = 3.0, edge_inset = 5.0, font = Look.FONT_WARN})
	_logo = MotionSvg.new()
	_logo.data = _svg(FTFKit.LOGO)
	_logo.width = LOGO_W
	var k := LOGO_W / _logo.data.view_box.size.x
	_logo.position = LOGO_C - _logo.data.view_box.size * k * 0.5
	_logo_grp.add_child(_logo)
	_clamps = MotionCanvas.new()
	_clamps.draw_fn = _draw_clamps
	_logo_grp.add_child(_clamps)
	# HUD tapes, top and bottom
	_tape(_stage, {a = Vector2(-80, 70), b = Vector2(2000, 70), width = 58.0, style = "text", col_a = Look.YELLOW, col_b = Look.BLACK,
		text = WARN_TEXT, text_size = 30, text_scroll = -3.0, at = HUD_IN[0], dur = 7.0, wave_amp = 26.0, wave_len = 700.0, wave_decay = 8.0, seed = 70.0, hud = "top", out = "follow", out_at = YANK, out_dur = 9.0})
	_tape(_stage, {a = Vector2(-80, 1010), b = Vector2(2000, 1010), width = 58.0, style = "text", col_a = Look.PINK, col_b = Look.BLACK,
		text = HAZ_TEXT, text_size = 28, text_scroll = 3.0, at = HUD_IN[1], dur = 7.0, wave_amp = 26.0, wave_len = 700.0, wave_decay = 8.0, seed = 72.0, hud = "bottom", out = "follow", out_at = YANK, out_dur = 9.0})
	_strip = MotionCanvas.new()
	_strip.draw_fn = _draw_strip
	_stage.add_child(_strip)
	for i in 4:
		var info: Array = SIGN_INFO[i]
		var a := Look.text(_stage, Look.FONT_LABEL, 24, Look.WHITE, info[1])
		var b := Look.text(_stage, Look.FONT_JP, 22, Look.YELLOW, info[2])
		_strip_labels.append([a, b])


func _build_close() -> void:
	for i in 9:
		var yy := 60.0 + 120.0 * i
		var from_left := i % 2 == 0
		var a := Vector2(-120, yy) if from_left else Vector2(2040, yy)
		var b := Vector2(2040, yy) if from_left else Vector2(-120, yy)
		var spec := {a = a, b = b, width = 132.0, col_b = Look.BLACK, period = 110.0, slant = 60.0, scroll = 7.0 * (1 if from_left else -1),
			at = CLOSE + i * 0.75, dur = 5.0, wave_amp = 22.0, wave_len = 900.0, wave_decay = 6.0, wave_speed = 200.0,
			out = "follow", out_at = YANK + i * 0.4, out_dur = 9.0, seed = 80.0 + i}
		if i % 4 == 0:
			spec.merge({style = "text", col_a = Look.BLACK, col_b = Look.YELLOW, edge = Look.YELLOW, text = WARN_TEXT, text_size = 62,
				text_color = Look.YELLOW, text_scroll = -6.0})
		else:
			spec.merge({style = "stripes", col_a = Look.YELLOW if i % 2 == 1 else Look.PINK})
		_tape(_stage, spec)


func _build_lights() -> void:
	var lamps := [Vector2(120, 168), Vector2(1800, 168)]
	for i in 2:
		var b := MotionBeacon.new()
		b.size = size
		b.centre = lamps[i]
		b.beams = 2
		b.beam_width = 9.0
		b.softness = 0.8
		b.reach = 2500.0
		b.falloff = 1.2
		b.intensity = 0.30
		b.core = 22.0
		b.core_intensity = 1.3
		b.streak = 300.0
		b.streak_intensity = 0.55
		b.color = Look.AMBER if i == 0 else Look.ORANGE
		_stage.add_child(b)
		_beacons.append(b)
	_lamps = MotionCanvas.new()
	_lamps.draw_fn = _draw_lamps
	_stage.add_child(_lamps)


func _build_hud() -> void:
	var l := Look.text(self, Look.FONT_MONO, 20, Look.STONE, "ALERT 05 // ZONE F-9000 // 200 BPM // 9 FRAMES A BEAT", 0.1)
	l.position = Vector2(64, 1032)
	var r := Look.text(self, Look.FONT_MONO, 20, Look.YELLOW, "STATUS: ARMED", 0.1)
	r.position = Vector2(W - 64 - r.get_text_size().x, 1032)
	var t := Look.text(self, Look.FONT_MONO, 20, Look.STONE, "MINIMAL HUMANS // SAFETY NOTICE 01", 0.1)
	t.position = Vector2(64, 28)
	_hud = [l, r, t]


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_warning/audio/warning_map.tres"
	const SONG := "res://demo/ftf/ftf_warning/audio/music/warning_song.tres"
	const TRACK := "res://demo/ftf/ftf_warning/audio/ftf_warning_track.res"
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


# ================================================================== helpers

func _stamp(f: float, at: float, from := 1.25, frames := 4.0) -> float:
	return lerpf(from, 1.0, MK.map(f, [at, at + frames], [0, 1], MK.ease_out))


## The beacons' angles: one turn a bar (two beams: a pass every two beats), twice as fast after the escalation.
func _beacon_angle(f: float, dir: float, phase: float) -> float:
	if f < ESCALATE:
		return MotionBeacon.spin(f, BAR, phase, dir)
	return MotionBeacon.spin(ESCALATE, BAR, phase, dir) + MotionBeacon.spin(f - ESCALATE, BAR * 0.5, 0.0, dir)


func _escalated(f: float) -> bool:
	return f >= ESCALATE and f < CLOSE


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	var shake := MK.shakes(f, [DROP], 26, 9) + MK.shakes(f, [CLAMP, PLACARD, SNAP] + SIGNS + COUNT, 9, 6) \
		+ MK.shakes(f, BARS + [CLOSE], 6, 5)
	_stage.position = shake
	# background stripes: crawl, faster after the escalation, warmer in the barrage
	var crawl := f * 1.6 + maxf(0.0, f - ESCALATE) * 1.6
	_field.shift = Vector2(crawl, 0)
	var warm := MK.win(f, SIGNS[0], COUNT[0] + 6.0, 4)
	_field.modulate = Color(1, 1, 1).lerp(Color(1.9, 1.7, 0.6), warm)
	_field.visible = f < YANK + 8.0
	for rec in _tapes:
		_update_tape(rec, f)
	_frame_placard(f)
	_frame_barrage(f)
	_frame_countdown(f)
	_frame_logo(f)
	_frame_lights(f)
	# HUD lines during the opening only
	var hud_on := f < DROP
	for i in _hud.size():
		_hud[i].visible = hud_on
	_hud[0].visible_chars = int(MK.map(f, [2, 24], [0, 60], MK.linear))
	_hud[1].text = "STATUS: ARMED" if f < COUNT[0] else "STATUS: T-%d" % maxi(1, 4 - int((f - COUNT[0]) / BEAT))
	var fl := 0.0
	if f >= DROP:
		fl = 0.28 * (1.0 - MK.map(f, [DROP, DROP + 3], [0, 1], MK.linear))
	_flash.visible = fl > 0.01
	_flash.color.a = fl


func _update_tape(rec: Dictionary, f: float) -> void:
	var spec: Dictionary = rec.spec
	var node: Node2D = rec.node
	# escalation: the HUD tapes swap colours (once, on the bar)
	if spec.has("hud"):
		var swap := _escalated(f)
		var top: bool = spec.hud == "top"
		spec.col_a = (Look.PINK if top else Look.YELLOW) if swap else (Look.YELLOW if top else Look.PINK)
	if f < float(spec.get("at", 0.0)):
		node.visible = false
		rec.pose = {}
		return
	var pose := MotionTape.pose(spec, f)
	if (pose.pieces as Array).is_empty():
		node.visible = false
		rec.pose = {}
		return
	node.visible = true
	rec.pose = pose
	(rec.canvas as MotionCanvas).queue_redraw()
	var t: MotionTextPath = rec.text
	if t:
		var pc: Dictionary = (pose.pieces as Array)[0]
		t.points = pose.pts
		t.closed = pose.closed
		t.offset = float(spec.get("text_scroll", 0.0)) * f
		if pose.closed and float(pc.to) >= float(pose.total) - 0.5 and float(pc.from) <= 0.5:
			t.show_from = 0.0
			t.show_to = -1.0
		else:
			t.show_from = float(pc.from) + 12.0
			t.show_to = float(pc.to) - 12.0
		if spec.has("hud"):
			t.color = Look.BLACK


# ---------------------------------------------------------------- placard

func _placard_pose(f: float) -> Array:
	# [y offset, rotation]
	var y := 0.0
	var rot := 0.0
	if f < PLACARD:
		y = lerpf(-1150.0, 0.0, MK.map(f, [PLACARD - 6.0, PLACARD], [0, 1], MK.ease_in_quad))
	else:
		var t := f - PLACARD
		y = 16.0 * exp(-t / 3.0) * sin(t * 1.25)
		rot = 0.03 * exp(-t / 34.0) * sin(t * 0.2 + 0.4)
	if f >= SNAP:
		var t2 := f - SNAP
		y += 3.2 * t2 * t2
		rot += 0.0012 * t2 * t2
	return [y, rot]


func _frame_placard(f: float) -> void:
	_placard.visible = f >= PLACARD - 6.0 and f < SNAP + 24.0
	if not _placard.visible:
		return
	var p := _placard_pose(f)
	_placard.position = Vector2(960, -300 + float(p[0]))
	_placard.rotation = float(p[1])
	var s := _stamp(f, PRESENTS, 1.35, 4.0)
	_presents.scale = Vector2.ONE * s
	_presents.visible = f >= PRESENTS
	_presents.modulate.a = MK.map(f, [PRESENTS, PRESENTS + 2], [0, 1], MK.linear)
	_presents_jp.visible = f >= PRESENTS_JP
	_presents_jp.scale = Vector2.ONE * _stamp(f, PRESENTS_JP, 1.4, 3.0)
	_plac_canvas.queue_redraw()


func _draw_placard(c: MotionCanvas, f: float) -> void:
	var r := _sign_rect()
	# chains: from the hooks up out of frame; after the snap only stubs remain
	var top := -80.0 if f < SNAP else 330.0
	for x in [-440.0, 440.0]:
		var yy := r.position.y + 6.0
		var k := 0
		while yy > top:
			if k % 2 == 0:
				c.ellipse(Vector2(x, yy - 14.0), 9.0, 16.0, Look.STONE, 5.0)
			else:
				c.rect(Rect2(x - 2.5, yy - 30.0, 5.0, 32.0), Look.STONE)
			yy -= 26.0
			k += 1
		c.circle(Vector2(x, r.position.y + 10.0), 13.0, Look.STONE)
	# the sign
	c.polygon(MotionPath.rounded_rect(r, 40.0, 6), Look.INK, Color(0, 0, 0, 0))
	c.polygon(MotionPath.rounded_rect(Rect2(r.position + Vector2(30, 30), Vector2(r.size.x - 60, 82)), 10.0, 4), Look.YELLOW, Color(0, 0, 0, 0))
	var pose := MotionTape.pose(_plac_border, f)
	MotionTape.draw(c, _plac_border, pose, f)
	# divider under the logo, and a hazard ticker
	c.rect(Rect2(-540, 920, 1080, 4), Look.STONE, 0.6)


# ---------------------------------------------------------------- barrage

func _sign_pos(i: int) -> Vector2:
	return Vector2(300 + i * 440, 470)


func _sign_out(f: float, i: int) -> Vector2:
	# shoved aside by the countdown: the left pair goes left, the right pair right
	var u := MK.map(f, [COUNT[0] - 2.0, COUNT[0] + 6.0], [0, 1], MK.ease_in_quad)
	return Vector2((-1.0 if i < 2 else 1.0) * u * 1100.0, 0)


func _frame_barrage(f: float) -> void:
	var on := f >= SIGNS[0] and f < COUNT[0] + 8.0
	_barrage.visible = on
	for i in 4:
		var at: float = SIGNS[i]
		var vis := on and f >= at
		var lab: Array = _sign_labels[i]
		var p := _sign_pos(i) + _sign_out(f, i) + MK.shake(f, at, 6, 5)
		var a: MotionText = lab[0]
		var b: MotionText = lab[1]
		a.visible = vis
		b.visible = vis
		a.position = p + Vector2(-a.get_text_size().x * 0.5, 190)
		b.position = p + Vector2(-b.get_text_size().x * 0.5, 240)
		a.modulate.a = MK.map(f, [at + 1.0, at + 3.0], [0, 1], MK.linear)
		b.modulate.a = a.modulate.a
	if on:
		_barrage.queue_redraw()


func _draw_barrage(c: MotionCanvas, f: float) -> void:
	for i in 4:
		var at: float = SIGNS[i]
		if f < at:
			continue
		var p := _sign_pos(i) + _sign_out(f, i) + MK.shake(f, at, 6, 5)
		var s := _stamp(f, at, 1.3, 4.0)
		# the newest sign is pink until the next beat
		var newest := i == 3 or f < float(SIGNS[mini(i + 1, 3)])
		var fill := Look.PINK if (newest and f < at + BEAT) else Look.YELLOW
		Signs.warning_sign(c, p, 300.0, int(SIGN_INFO[i][0]), fill, s, deg_to_rad(-3.0 + 2.0 * i))


# ---------------------------------------------------------------- countdown

func _frame_countdown(f: float) -> void:
	var on := f >= COUNT[0] and f < DROP
	_count_canvas.visible = f >= COUNT[0] - 2.0 and f < DROP
	_count_pivot.visible = on
	_count_label.visible = on
	if not _count_canvas.visible:
		return
	_count_canvas.queue_redraw()
	if not on:
		return
	var n := 0
	for i in COUNT.size():
		if f >= COUNT[i]:
			n = i
	_count_text.text = str(4 - n)
	_count_text.position = -_count_text.get_text_size() * 0.5 + Vector2(6, 4)
	var s := _stamp(f, COUNT[n], 1.18, 4.0)
	_count_pivot.scale = Vector2.ONE * s
	_count_pivot.rotation = deg_to_rad(3.0 if n % 2 == 0 else -3.0)
	_count_label.modulate.a = MK.map(f, [COUNT[0], COUNT[0] + 3], [0, 1], MK.linear)


func _gate_angle(f: float, at: float, closed: float) -> float:
	var t := MK.map(f, [at - 3.0, at + 3.0], [0, 1], MK.ease_in_quad)
	var a := lerpf(-PI * 0.5, closed, t)
	if f >= at + 3.0:
		var u := f - at - 3.0
		a += -signf(closed + PI * 0.5) * 0.08 * exp(-u / 2.5) * absf(sin(u * 1.4))
	return a


func _draw_countdown(c: MotionCanvas, f: float) -> void:
	var n := 0
	for i in COUNT.size():
		if f >= COUNT[i]:
			n = i
	var s := _stamp(f, COUNT[n], 1.18, 4.0)
	var rot := deg_to_rad(3.0 if n % 2 == 0 else -3.0)
	var appear := MK.map(f, [COUNT[0] - 2.0, COUNT[0]], [0, 1], MK.ease_out)
	c.draw_set_transform(Vector2(960, 470), rot, Vector2.ONE * s * appear)
	c.polygon(MotionPath.rounded_rect(Rect2(-215, -215, 430, 430), 30.0, 5), Look.INK, Color(0, 0, 0, 0))
	c.polygon(MotionPath.rounded_rect(Rect2(-200, -200, 400, 400), 22.0, 5), Look.YELLOW, Color(0, 0, 0, 0))
	c.draw_set_transform(Vector2(960, 470), rot, Vector2.ONE * s * appear)
	var pose := MotionTape.pose(_plate_border, f)
	MotionTape.draw(c, _plate_border, pose, f)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# gates
	if f >= GATES[0] - 3.0:
		MotionMarks.barrier(c, Vector2(80, 790), _gate_angle(f, GATES[0], 0.0), 860.0, 46.0, Look.YELLOW, Look.BLACK, Look.INK)
	if f >= GATES[1] - 3.0:
		MotionMarks.barrier(c, Vector2(1840, 790), _gate_angle(f, GATES[1], -PI), 860.0, 46.0, Look.PINK, Look.BLACK, Look.INK)


# ---------------------------------------------------------------- logo

func _frame_logo(f: float) -> void:
	var on := f >= DROP and f < CLOSE + 12.0
	_logo_grp.visible = on
	_strip.visible = f >= STRIP - 4.0 and f < CLOSE + 12.0
	for lab in _strip_labels:
		(lab[0] as MotionText).visible = _strip.visible
		(lab[1] as MotionText).visible = _strip.visible
	if not on:
		return
	var s := lerpf(1.1, 1.0, MK.map(f, [DROP, DROP + 5], [0, 1], MK.ease_out))
	# the clamps bite on every bar: the logo kicks inward a touch
	for b in BARS:
		if f >= b and f < b + 8.0:
			s *= 1.0 - 0.012 * exp(-(f - b) / 2.0)
	_logo_grp.scale = Vector2.ONE * s
	_logo_grp.position = LOGO_C - LOGO_C * s
	_clamps.queue_redraw()
	if _strip.visible:
		_strip.queue_redraw()
		for i in 4:
			var lab: Array = _strip_labels[i]
			var p := _strip_pos(i) + _strip_shake(f, i)
			var a: MotionText = lab[0]
			var b2: MotionText = lab[1]
			a.position = p + Vector2(70, -34)
			b2.position = p + Vector2(70, 2)
			var o := MK.map(f, [STRIP - 4.0, STRIP], [0, 1], MK.linear)
			a.modulate.a = o
			b2.modulate.a = o
			a.color = Look.PINK if _strip_active(f) == i else Look.WHITE


func _clamp_offset(f: float) -> float:
	# slam in from off screen (accelerating into the hit), then bite on the bars
	var d := 700.0 * (1.0 - MK.map(f, [CLAMP - 5.0, CLAMP], [0, 1], MK.ease_in_quad))
	for b in BARS:
		if f >= b and f < b + 10.0:
			d -= 14.0 * exp(-(f - b) / 2.5)
	return d


func _draw_clamps(c: MotionCanvas, f: float) -> void:
	if f < CLAMP - 5.0:
		return
	var d := _clamp_offset(f)
	var g := 23.0 + 12.0
	var corners := [
		[FRAME_R.position + Vector2(-g, -g), 1.0, 1.0],
		[Vector2(FRAME_R.end.x + g, FRAME_R.position.y - g), -1.0, 1.0],
		[FRAME_R.end + Vector2(g, g), -1.0, -1.0],
		[Vector2(FRAME_R.position.x - g, FRAME_R.end.y + g), 1.0, -1.0],
	]
	for k in corners:
		var sx: float = k[1]
		var sy: float = k[2]
		var p: Vector2 = k[0] - Vector2(sx, sy) * d
		MotionMarks.hazard_clamp(c, p, sx, sy, 200.0, 44.0, Look.YELLOW if _escalated(f) == false else Look.PINK, Look.BLACK)


func _strip_pos(i: int) -> Vector2:
	return Vector2(250 + i * 400, 870)


func _strip_active(f: float) -> int:
	if f < STRIP:
		return -1
	return int((f - STRIP) / BEAT) % 4


func _strip_shake(f: float, i: int) -> Vector2:
	if _strip_active(f) != i:
		return Vector2.ZERO
	var t := fmod(f - STRIP, BEAT)
	return MK.shake(t, 0.0, 7, 5)


func _draw_strip(c: MotionCanvas, f: float) -> void:
	var o := MK.map(f, [STRIP - 4.0, STRIP], [0, 1], MK.linear)
	for i in 4:
		var act := _strip_active(f) == i
		var s := _stamp(f, STRIP + floorf((f - STRIP) / BEAT) * BEAT, 1.15, 3.0) if act else 1.0
		Signs.warning_sign(c, _strip_pos(i) + _strip_shake(f, i), 104.0, int(SIGN_INFO[i][0]), Look.PINK if act else Look.YELLOW, s, 0.0, o)


# ---------------------------------------------------------------- lights

func _frame_lights(f: float) -> void:
	var level := MK.map(f, [0, 6], [0, 1], MK.linear) * (1.0 - MK.map(f, [YANK, YANK + 6], [0, 1], MK.linear))
	for i in 2:
		var b := _beacons[i]
		b.level = level
		b.angle = _beacon_angle(f, 1.0 if i == 0 else -1.0, 0.3 if i == 0 else 1.9)
		# right lamp turns FTF pink from the drop
		b.color = Look.AMBER if i == 0 else (Look.ORANGE if f < DROP else Look.PINK)
		b.intensity = 0.30 if f < DROP else 0.26
	_lamps.visible = level > 0.0
	_lamps.queue_redraw()


func _draw_lamps(c: MotionCanvas, f: float) -> void:
	var level := MK.map(f, [0, 6], [0, 1], MK.linear) * (1.0 - MK.map(f, [YANK, YANK + 6], [0, 1], MK.linear))
	for i in 2:
		var b := _beacons[i]
		var p := b.centre
		c.rect(Rect2(p + Vector2(-40, 26), Vector2(80, 22)), Look.INK)
		c.rect(Rect2(p + Vector2(-52, 44), Vector2(104, 10)), Look.STONE)
		var dome := PackedVector2Array()
		for k in 13:
			var a := PI + PI * float(k) / 12.0
			dome.append(p + Vector2(cos(a) * 34.0, sin(a) * 34.0 + 26.0))
		c.polygon(dome, b.color.darkened(0.35), Color(0, 0, 0, 0), 0.0, 0.85)
		c.circle(p + Vector2(0, 8), 10.0, Color(1, 1, 0.9), level)
