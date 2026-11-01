# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take: CHECKERBOARD CITY.
#
# Brief: an OutRun / demoscene flight over an endless checkerboard toward a
# banded sun, between checker-tiled skyscrapers, under a checker sky. The
# ground bends, ripples and folds into op-art. Minimal Humans rises over the
# horizon as a giant checker monument at sunrise; the ground then curls into a
# tube and the camera barrel-rolls through it; the FTF logo rises out of the
# floor right in front of the camera on the drop, its plate checkered, and the
# board keeps racing under it; finally the ground folds up into a wall and
# closes to black.
#
# Tempo: 112.5 bpm = 16 frames a beat, 64 a bar, first downbeat at frame 0.
# Any music at 112.5 bpm starting on its downbeat lines up: the drop is bar 3
# (frame 192, 6.4 s).
#
# Beats (30 fps, 420 frames):
#   0-32     dive: looking straight down at the board, the camera pitches up to the horizon
#   16-40    the city sprouts out of the ground, far to near
#   40-64    Minimal Humans monument rises over the horizon; lands on bar 1 (64)
#   80       PRESENTS; the board pulses on every beat
#   112-124  the monument sinks; the ground's sides curl up
#   128      bar 2: TUBE. Barrel roll through a checker tube, colours flip on every beat
#   160-176  the tube unrolls back into a plane
#   176-192  the FTF logo rises out of the floor in front of the camera
#   192      bar 3: DROP. Logo up, shockwave through the board, sun pulse
#   192-320  hold: the board races, buildings stream past, the road sways, rings on
#            every bar, sun on every beat, lanes recolour per bar, the board halves at 256
#   320-334  the logo sinks back into the floor
#   330-384  the ground folds up into a wall ahead and closes; black from 384
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0
const BPM := 112.5
const BEAT := 1800.0 / BPM          # frames per beat at 30 fps
const BAR := 4.0 * BEAT

const DIVE := 0.0
const HORIZON := 32.0
const SPROUT := 16.0
const MH_RISE := 40.0
const MH_LAND := 64.0
const PRESENTS := 80.0
const MH_SINK := 112.0
const TUBE := 128.0
const UNTUBE := 160.0
const RISE := 176.0
const DROP := 192.0
const RINGS := [192.0, 256.0, 288.0, 320.0]
const HALVE := 256.0
const SINK := 320.0
const FOLD := 326.0
const CLOSE := 384.0
const END := 420

# world
const CAM_H := 2.2
const LOGO_D := 13.0            # FTF logo distance ahead (travels with the camera)
const LOGO_W := 25.0            # FTF logo width in world units
const LOGO_PX := 1400.0         # FTF logo authoring width
const MH_W := 374.0             # monument panel width (world units)
const MH_H := 116.5             # panel height
const MH_UP := 113.0            # panel centre above the ground
const MH_PILLAR := 520.0        # pillar length below the panel (authoring px)
const MH_PX := 1300.0           # monument authoring width
const LOT := 12.0               # building lot spacing along z
const BCELL := 2.0              # building checker size

# palette
const INK := Color("#08080c")
const PAPER := Color("#f4f1ea")
const PINK := Color("#e92067")
const LIME := Color("#d7ff1f")
const CYAN := Color("#19c3e6")
const LILAC := Color("#a98bff")
const MH_CREAM := Color("#ece5da")
const MH_AMBER := Color("#f4af3f")
const MH_RED := Color("#ef393b")

var _built := false
var _tr: MotionTravel   # travel distance per frame (tabled once)

var _back: MotionPatternPlane
var _front: MotionPatternPlane
var _far_city: MotionCanvas
var _near_city: MotionCanvas
var _mh: Node2D
var _mh_svg: MotionSvg
var _mh_presents: MotionText
var _mh_jp: MotionText
var _mh_slab: MotionCanvas
var _logo: Node2D
var _logo_svg: MotionSvg
var _plate_checks: MotionCanvas
var _hud: Node2D
var _hud_l: MotionText
var _hud_r: MotionText
var _hud_spd: MotionText
var _hud_jp: MotionText
var _stage: Node2D
var _lots: Array = []   # cached per lot index: Dictionary


func _init() -> void:
	duration = END
	bpm = BPM
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": 224.0, "out": SINK}
	_table()
	cue(DIVE, &"dive", 0.8)
	cue(SPROUT, &"sprout", 0.6)
	cue(MH_RISE, &"mh.rise", 0.8)
	cue(MH_LAND, &"mh.land", 1.0)
	cue(PRESENTS, &"presents", 0.8)
	for b in [96.0, 104.0]:
		cue(b, &"pulse", 0.5, {pitch = 1.0 if b == 96.0 else 1.19})
	cue(MH_SINK, &"mh.sink", 0.7)
	cue(TUBE - 12.0, &"tube.in", 0.9)
	for i in 2:   # the third beat of the tube is the unroll
		cue(TUBE + i * BEAT, &"flip", 0.6 + 0.1 * i, {pitch = [1.0, 1.19][i]})
	cue(UNTUBE, &"tube.out", 0.8)
	cue(RISE, &"rise", 1.0)
	cue(DROP, &"drop", 1.0)
	for i in RINGS.size():
		if i > 0 and RINGS[i] < SINK and RINGS[i] != HALVE:
			cue(RINGS[i], &"ring", 0.8 - 0.1 * i)
	cue(HALVE, &"halve", 0.7)
	for b in [224.0, 304.0]:
		cue(b, &"swerve", 0.6)
	cue(SINK, &"sink", 0.8)
	cue(FOLD, &"fold", 1.0)
	cue(CLOSE, &"close", 1.0)


# ------------------------------------------------------------------ timing

const SPEED_FRAMES := [0, 32, 56, 72, 112, 124, 128, 168, 184, 192, 320, 340, 384]
## World units per frame at SPEED_FRAMES.
const SPEED := [1.1, 0.9, 0.5, 0.32, 0.32, 1.2, 2.4, 2.4, 1.6, 2.4, 2.4, 3.2, 4.0]


func _table() -> void:
	# Integrate the speed profile once (on eighths of a frame): travel(f) is a
	# lookup, so every frame stays a pure function of f.
	_tr = MotionTravel.from_keys(SPEED_FRAMES, SPEED, END + 2, MK.ease_in_out)


func travel(f: float) -> float:
	return _tr.at(f)


## Where the MH monument stands (absolute travel position).
func _mh_z() -> float:
	return travel(MH_LAND) + 262.0


# ------------------------------------------------------------------ build

func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = INK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_back = MotionPatternPlane.new()
	_stage.add_child(_back)
	_far_city = MotionCanvas.new()
	_far_city.draw_fn = func(c: MotionCanvas, f: float) -> void: _draw_city(c, f, false)
	_stage.add_child(_far_city)
	_build_mh()
	_build_logo()
	_front = MotionPatternPlane.new()
	_front.draw_sky = false
	_stage.add_child(_front)
	_near_city = MotionCanvas.new()
	_near_city.draw_fn = func(c: MotionCanvas, f: float) -> void: _draw_city(c, f, true)
	_stage.add_child(_near_city)
	_build_hud()
	_add_sound()


func _build_mh() -> void:
	_mh = Node2D.new()
	_stage.add_child(_mh)
	_mh_slab = MotionCanvas.new()
	_mh_slab.draw_fn = _draw_slab
	_mh.add_child(_mh_slab)
	_mh_svg = MotionSvg.new()
	_mh_svg.data = MotionSvgData.load_any("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh_svg.width = 980.0
	var mh_h := 980.0 * _mh_svg.data.view_box.size.y / _mh_svg.data.view_box.size.x
	_mh_svg.position = Vector2(-490.0, -MH_PX * MH_H / MH_W * 0.5 + 70.0)
	_mh.add_child(_mh_svg)
	_mh_presents = FTFKit.text(_mh, "heavy", 64, MH_CREAM, "PRESENTS", 0.5)
	_mh_presents.position = Vector2(-490.0 + 980.0 * 145.0 / 485.7, _mh_svg.position.y + mh_h + 46.0)
	_mh_jp = FTFKit.text(_mh, "jp", 40, MH_AMBER, "ミニマル・ヒューマンズ　提供")
	_mh_jp.position = Vector2(490.0 - _mh_jp.get_text_size().x, _mh_presents.position.y + 14.0)


func _build_logo() -> void:
	_logo = Node2D.new()
	_stage.add_child(_logo)
	var data := MotionSvgData.load_any(FTFKit.LOGO)
	var k := LOGO_PX / data.view_box.size.x
	var origin := -data.view_box.size * k * 0.5
	# the plate, filled with checks: a polygon mask that clips a checker canvas
	var plate := MotionCanvas.new()
	var outline: Array[PackedVector2Array] = data.outline(FTFKit.PLATE, 0.2)
	var poly := PackedVector2Array()
	for p in outline[0]:
		poly.append(origin + p * k)
	plate.draw_fn = func(c: MotionCanvas, _f: float) -> void: c.draw_colored_polygon(poly, Color.WHITE)
	plate.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_logo.add_child(plate)
	_plate_checks = MotionCanvas.new()
	_plate_checks.draw_fn = func(c: MotionCanvas, f: float) -> void: _draw_plate_checks(c, f, origin, data.view_box.size * k)
	plate.add_child(_plate_checks)
	_logo_svg = MotionSvg.new()
	_logo_svg.data = data
	_logo_svg.width = LOGO_PX
	_logo_svg.position = origin
	var rest := PackedInt32Array()
	for i in data.parts.size():
		if i != FTFKit.PLATE:
			rest.append(i)
	_logo_svg.only = rest
	_logo.add_child(_logo_svg)


func _build_hud() -> void:
	_hud = Node2D.new()
	add_child(_hud)
	_hud_l = FTFKit.text(_hud, "mono", 22, PAPER, "F-9000 // CHECKERBOARD CITY", 0.14)
	_hud_l.position = Vector2(72, 56)
	_hud_r = FTFKit.text(_hud, "mono", 22, PAPER, "112.5 BPM // 16 F", 0.14)
	_hud_r.position = Vector2(W - 72 - _hud_r.get_text_size().x, 56)
	_hud_spd = FTFKit.text(_hud, "mono", 22, LIME, "SPD 000 KM/H", 0.14)
	_hud_spd.position = Vector2(72, H - 82)
	_hud_jp = FTFKit.text(_hud, "jp", 30, PAPER, "フルスロットル・フラックス")
	_hud_jp.position = Vector2(W - 72 - _hud_jp.get_text_size().x, H - 90)


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_checkercity/audio/cc_map.tres"
	const SONG := "res://demo/ftf/ftf_checkercity/audio/music/cc_song.tres"
	const TRACK := "res://demo/ftf/ftf_checkercity/audio/cc_track.res"
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


# ------------------------------------------------------------------ helpers

## Section mixes, each 0..1.
func _tube(f: float) -> float:
	return MK.interp(f, [116, 128, UNTUBE, RISE], [0, 1, 1, 0], MK.ease_in_out)


func _hold_mix(f: float) -> float:
	return MK.map(f, [UNTUBE, RISE], [0, 1], MK.ease_in_out)


func _cycle(i: int) -> Color:
	return [PINK, LIME, CYAN, PAPER][posmod(i, 4)]


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var tube := _tube(f)
	var hold := _hold_mix(f)
	var p := _back

	# -- camera
	var dive := MK.map(f, [DIVE, HORIZON], [0, 1], MK.ease_in_out)
	p.height = lerpf(9.0, CAM_H, dive)
	var sway := sin(TAU * (f - DROP) / (BAR * 2.0)) * MK.map(f, [DROP, DROP + 24], [0, 1]) * (1.0 - MK.map(f, [SINK, SINK + 16], [0, 1]))
	var pitch_mh := MK.interp(f, [HORIZON, 48, 120, 128], [-3.0, 5.0, 5.0, 0.0], MK.ease_in_out)
	p.pitch = lerpf(-82.0, pitch_mh, dive)
	if f >= 128.0:
		p.pitch = lerpf(0.0, -1.5, hold) + MK.map(f, [SINK, CLOSE], [0, 14], MK.ease_in_out)
	p.roll = 360.0 * MK.map(f, [TUBE - 4.0, RISE - 6.0], [0, 1], MK.ease_in_out) + sway * 6.0
	p.yaw = sway * 4.0
	p.fov = 70.0 + 10.0 * tube + 6.0 * exp(-maxf(f - DROP, 0.0) * 0.25) * float(f >= DROP)
	var tr := travel(f)
	p.ground_offset = Vector2(0.0, tr)

	# -- bends
	p.curve = 0.0012 * sway
	p.channel = 0.09 * tube
	p.hill = 0.0 if f < FOLD else 0.25 * pow(MK.map(f, [FOLD, CLOSE], [0, 1], MK.linear), 2.6)
	var waveamp := 1.6 * tube + 0.9 * _env(f, [240.0, 304.0], 30.0)
	p.wave = Vector3(waveamp, 0.12, -f * 0.25)

	# -- pattern
	var base_cell := lerpf(2.0, 4.0, MK.map(f, [112, 128], [0, 1], MK.ease_in_out))
	var cell_y := base_cell * lerpf(1.0, 1.5, maxf(tube, hold))
	if f >= HALVE:
		var hv := MK.map(f, [HALVE, HALVE + 6], [0, 1], MK.ease_out)
		base_cell = lerpf(base_cell, base_cell * 0.5, hv)
		cell_y = lerpf(cell_y, cell_y * 0.5, hv)
	var pulse := MK.beat_pulse(f, BEAT, 80.0, 112.0, 0.18) + MK.beat_pulse(f, BEAT, TUBE, UNTUBE, 0.18) + 0.5 * MK.beat_pulse(f, BEAT, DROP, SINK, 0.18)
	p.cell = Vector2(base_cell, cell_y) * (1.0 + 0.35 * pulse)
	p.cell_scroll = Vector2(base_cell, cell_y)
	p.motion_blur = p.motion_blur_for(Vector2(0, _tr.frame_speed(f)), 0.5)
	# colours: MH sunrise (cream/ink, amber lanes) -> tube flips -> FTF (white/ink, cycling lanes)
	var mh_a := MH_CREAM
	var a := mh_a.lerp(PAPER, hold)
	if tube > 0.5:
		a = _cycle(int(floorf((f - TUBE) / BEAT)) if f >= TUBE else 3)
	p.color_a = a
	p.color_b = INK
	var bar_i := int(floorf((f - DROP) / BAR))
	var lane := MH_AMBER.lerp(_cycle(bar_i if f >= DROP else 2), hold)
	p.accent_color = Color(lane, 0.85 * (1.0 - tube))
	p.accent_every = 8.0
	p.accent_width = 0.5
	p.pattern_shift = Vector2(0.5, 0.0)

	# -- sky, sun, fog
	var mh_sky := Color("#120814")
	var ftf_sky := Color("#06060e")
	var mh_hz := Color("#f08a3a")
	var ftf_hz := Color("#ff4f9a")
	var hz := mh_hz.lerp(Color("#1a0a24"), tube).lerp(ftf_hz, hold)
	p.sky_top = mh_sky.lerp(ftf_sky, maxf(tube, hold))
	p.sky_horizon = hz
	p.sky_spread = 0.42
	p.fog_color = hz.lerp(INK, MK.map(f, [FOLD + 16.0, CLOSE], [0, 1]))
	var fogfar := lerpf(240.0, 160.0, tube)
	p.fog_range = Vector2(lerpf(30.0, 12.0, tube), fogfar)
	var rise_sun := MK.map(f, [0, MH_LAND], [-6.0, 7.0], MK.ease_out)
	p.sun_elevation = lerpf(rise_sun, 5.5, hold)
	var spulse := MK.beat_pulse(f, BEAT, DROP, SINK, 0.22) + MK.beat_pulse(f, BEAT, 64.0, 112.0, 0.22) * 0.6
	p.sun_size = lerpf(11.0, 13.0, hold) * (1.0 + 0.05 * spulse + 0.12 * _env(f, [DROP], 14.0)) * (1.0 - tube)
	p.sun_top = Color("#ffe9a6").lerp(LIME, hold)
	p.sun_bottom = MH_RED.lerp(PINK, hold)
	p.sun_bands = Vector3(9.0, f * 0.015, 0.3)
	p.sun_glow = 0.25 + 0.25 * spulse
	# checker sky: a ceiling far overhead, fading in for the hold
	p.ceiling = true
	p.ceiling_height = 36.0
	p.ceiling_a = Color("#1b1b2a").lerp(Color("#2a1630"), hold)
	p.ceiling_b = Color("#0a0a12")
	p.ceiling_alpha = 0.85 * (1.0 - tube) * MK.map(f, [HORIZON, 64], [0, 1])

	# -- ring: shockwave from the logo's foot on the drop and on accents
	var ring := Vector4(0, 0, -1, 2)
	var rcol := Color(1, 1, 1, 0)
	var push := 0.0
	for at: float in RINGS:
		if f >= at and f < at + 36.0:
			var t := (f - at) / 36.0
			ring = Vector4(0.0, LOGO_D, lerpf(1.0, 150.0, MK.ease_out.call(t)), lerpf(2.0, 9.0, t))
			rcol = Color(LIME.lerp(PAPER, 0.4), 0.75 * (1.0 - t))
			push = 0.9 * (1.0 - t)
	p.ring = ring
	p.ring_color = rcol
	p.ring_push = push
	p.level = MK.map(f, [0, 8], [0, 1]) * (1.0 - MK.map(f, [CLOSE - 10.0, CLOSE], [0, 1], MK.ease_in_quad))

	# -- front layer mirrors the back one, clipped in front of the sandwich
	_front.copy_from(p)
	_front.draw_sky = false
	var sandwich := LOGO_D
	if f < TUBE:
		sandwich = p.rel_z(_mh_z())
	_front.ceiling = false
	_front.clip = Vector2(-1e9, sandwich)
	_back.sync_now()
	_front.sync_now()

	# -- MH monument and FTF logo
	_frame_mh(f)
	_frame_logo(f)
	_stage.position = MK.shakes(f, [MH_LAND], 10, 8) + MK.shakes(f, [DROP], 26, 12) + MK.shakes(f, [CLOSE], 14, 8)

	# -- HUD
	var hud_on := MK.map(f, [HORIZON, HORIZON + 12], [0, 1]) * (1.0 - MK.map(f, [FOLD, FOLD + 20], [0, 1]))
	_hud.modulate.a = hud_on
	_hud.visible = hud_on > 0.0
	_hud_spd.text = "SPD %03d KM/H" % int(_tr.frame_speed(f) * 30.0 * 3.6 * 1.6)
	_hud_jp.visible_chars = int(MK.map(f, [DROP + 8, DROP + 24], [0, 14], MK.linear))


func _env(f: float, ats: Array, dur: float) -> float:
	var v := 0.0
	for a in ats:
		var at: float = a
		if f >= at:
			v = maxf(v, sin(PI * clampf((f - at) / dur, 0.0, 1.0)))
	return v


func _frame_mh(f: float) -> void:
	var on := f >= MH_RISE and f < MH_SINK + 14.0
	_mh.visible = on
	if not on:
		return
	var up := MK.map(f, [MH_RISE, MH_LAND], [0, 1], MK.bezier(0.2, 0.0, 0.1, 1.0))
	up -= MK.map(f, [MH_SINK, MH_SINK + 12.0], [0, 1], MK.ease_in_quad)
	var settle := 0.0
	if f >= MH_LAND:
		settle = sin((f - MH_LAND) * 0.55) * exp(-(f - MH_LAND) * 0.22) * 4.0
	var z := _back.rel_z(_mh_z())
	var y := -(MH_UP + MH_H * 0.5) * 1.04 * (1.0 - up) + MH_UP - settle
	var q := _back.project(_back.ground_point(-_back.curve * z * z, z, y))
	var s := _back.scale_at(q.z) * MH_W / MH_PX
	_mh.position = Vector2(q.x, q.y)
	_mh.scale = Vector2.ONE * s
	_mh.rotation = -deg_to_rad(wrapf(_back.roll, -180.0, 180.0))
	var pr := MK.prog(f, PRESENTS, 18)
	_mh_presents.visible = f >= PRESENTS
	_mh_presents.tracking = lerpf(1.1, 0.5, pr)
	_mh_presents.modulate.a = minf(1.0, pr * 3.0)
	_mh_jp.visible_chars = int(MK.map(f, [PRESENTS + 6, PRESENTS + 18], [0, 14], MK.linear))


func _draw_slab(c: MotionCanvas, f: float) -> void:
	# the monument: a dark checker slab with a cream frame and an amber base band
	var w := MH_PX
	var h := MH_PX * MH_H / MH_W
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	var pil := Rect2(-170.0, h * 0.5, 340.0, MH_PILLAR)
	c.rect(pil, Color("#0c0c10"))
	for j in int(MH_PILLAR / 34.0):
		for i in 10:
			if (i + j) % 2 == 0:
				c.rect(Rect2(pil.position + Vector2(i * 34.0, j * 34.0), Vector2(34, 34)), MH_AMBER.darkened(0.35))
	c.rect(r, Color("#0c0c10"))
	var cs := 54.0
	var nx := int(ceilf(w / cs))
	var ny := int(ceilf(h / cs))
	for j in ny:
		for i in nx:
			if (i + j) % 2 == 0:
				var cr := Rect2(r.position + Vector2(i, j) * cs, Vector2(cs, cs)).intersection(r)
				c.rect(cr, Color("#1d1c24"))
	c.rect(r, MH_CREAM, 1.0, 8.0)
	# checker band along the top and the bottom (studio colours)
	var band := 24.0
	for i in int(w / band):
		var col := MH_AMBER if i % 2 == 0 else Color("#0c0c10")
		c.rect(Rect2(r.position.x + i * band, r.position.y + 14.0, band, band * 0.5), col)
		c.rect(Rect2(r.position.x + i * band, r.end.y - 14.0 - band * 0.5, band, band * 0.5), MH_RED if i % 2 == 0 else Color("#0c0c10"))
	# PRESENTS rule
	var rw := MK.map(f, [PRESENTS - 4.0, PRESENTS + 8.0], [0, 980], MK.ease_in_out)
	if rw > 0.0:
		c.rect(Rect2(-490.0 + 980.0 * 145.0 / 485.7, _mh_presents.position.y - 18.0, rw * (1.0 - 145.0 / 485.7), 6.0), MH_AMBER)


func _frame_logo(f: float) -> void:
	var on := f >= RISE - 2.0 and f < SINK + 16.0
	_logo.visible = on
	if not on:
		return
	var lh := LOGO_W * 339.95 / 1427.88
	var rise := MK.map(f, [RISE, DROP], [0, 1], MK.ease_in_quad)
	rise -= MK.map(f, [SINK, SINK + 14.0], [0, 1], MK.ease_in_quad)
	var bounce := 0.0
	if f >= DROP:
		bounce = sin((f - DROP) * 0.6) * exp(-(f - DROP) * 0.2) * 0.45
	# a little dip on every kick during the hold
	var kick := 0.12 * MK.beat_pulse(f, BEAT, DROP + BEAT, SINK, 0.35)
	var y := -lh * 1.08 * (1.0 - rise) + lh * 0.5 + bounce - kick
	var gx := -_back.curve * LOGO_D * LOGO_D + LOGO_D * tan(deg_to_rad(_back.yaw)) * 0.7
	var q := _back.project(_back.ground_point(gx, LOGO_D, y))
	var s := _back.scale_at(q.z) * LOGO_W / LOGO_PX
	# Fully risen, nothing has to hide its foot: it draws over the near city.
	_logo.z_index = 1 if (f >= DROP + 2.0 and f < SINK) else 0
	# the logo travels with us: it sways only a quarter as much as the world
	_logo.position = Vector2(lerpf(W * 0.5, q.x, 0.25), q.y)
	_logo.scale = Vector2.ONE * s
	_logo.rotation = -deg_to_rad(wrapf(_back.roll, -180.0, 180.0)) * 0.6


func _draw_plate_checks(c: MotionCanvas, f: float, origin: Vector2, sz: Vector2) -> void:
	# pale checks scrolling across the white plate with the travel
	var cs := 44.0
	var shift := fmod(travel(f) * 9.0, cs * 2.0)
	var col := Color("#ffd5e4").lerp(Color("#d9f6ff"), MK.map(f, [HALVE, HALVE + 8], [0, 1]))
	var x0 := origin.x - cs * 2.0 + shift
	var nx := int(sz.x / cs) + 4
	var ny := int(sz.y / cs) + 2
	for j in ny:
		for i in nx:
			if (i + j) % 2 == 0:
				c.rect(Rect2(x0 + i * cs, origin.y + j * cs, cs, cs), col)


# ------------------------------------------------------------------ the city

## Deterministic lot description for lot index k on side `side` (-1 / 1).
func _lot(k: int, side: int) -> Dictionary:
	var key := k * 2 + (1 if side > 0 else 0)
	var r0 := MK.rand(key * 1.37 + 11.0)
	if r0 < 0.12:
		return {}
	var r1 := MK.rand(key * 2.71 + 3.0)
	var r2 := MK.rand(key * 3.93 + 7.0)
	var r3 := MK.rand(key * 5.17 + 1.0)
	var w := 4.0 + 2.0 * floorf(r1 * 3.0)
	var d := 4.0 + 2.0 * floorf(r2 * 3.0)
	var h := 10.0 + 2.0 * floorf(r3 * 11.0)
	var x := side * (13.0 + floorf(MK.rand(key * 7.7) * 6.0) * 2.0)
	var accent := MK.rand(key * 9.1 + 5.0) < 0.3
	return {w = w, d = d, h = h, x = x, z = k * LOT, accent = accent, idx = key, seed = r0}


func _city_h(f: float, lot: Dictionary, rel: float) -> float:
	# sprout far to near at the start, sink for the tube, sprout again, sink for the fold
	var stagger: float = float(lot.seed) * 8.0
	var a := MK.map(f, [SPROUT + stagger, SPROUT + 14.0 + stagger], [0, 1], MK.ease_out)
	a *= 1.0 - MK.map(f, [MH_SINK + stagger * 0.5, 128.0], [0, 1], MK.ease_in_quad)
	a = maxf(a, MK.map(f, [RISE - 6.0 + stagger * 0.5, DROP + 4.0 + stagger * 0.5], [0, 1], MK.ease_out))
	a *= 1.0 - MK.map(f, [SINK + stagger * 0.5, SINK + 16.0 + stagger * 0.5], [0, 1], MK.ease_in_quad)
	return a


func _draw_city(c: MotionCanvas, f: float, near: bool) -> void:
	if _tube(f) > 0.98:
		return
	var p := _back
	var tr := travel(f)
	var sandwich := LOGO_D if f >= TUBE else p.rel_z(_mh_z())
	var k0 := int(floorf((tr + 0.5) / LOT))
	var k1 := int(floorf((tr + 230.0) / LOT))
	var items := []
	for k in range(k0, k1 + 1):
		for side in [-1, 1]:
			var lot := _lot(k, side)
			if lot.is_empty():
				continue
			var zn: float = float(lot.z) - float(lot.d) * 0.5 - tr
			var zf: float = zn + float(lot.d)
			if zf < 0.8:
				continue
			var is_near := zn < sandwich
			if is_near != near:
				continue
			items.append([zn, lot])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var tube := _tube(f)
	for it in items:
		var lot: Dictionary = it[1]
		var hh: float = float(lot.h) * _city_h(f, lot, float(it[0])) * (1.0 - tube)
		# while the monument stands, the city stays low and steps aside for it
		var mh := 1.0 - MK.map(f, [MH_SINK, TUBE], [0, 1]) if f < TUBE else 0.0
		hh = lerpf(hh, minf(hh, 8.0), mh)
		if hh < 0.3:
			continue
		_draw_building(c, f, lot, tr, hh, 6.0 * mh)


func _draw_building(c: MotionCanvas, f: float, lot: Dictionary, tr: float, hh: float, push := 0.0) -> void:
	var p := _back
	var w: float = lot.w
	var d: float = lot.d
	var x0: float = float(lot.x) - w * 0.5 + signf(float(lot.x)) * push
	var x1: float = x0 + w
	var zn: float = float(lot.z) - d * 0.5 - tr
	var zf: float = zn + d
	var side := 1 if float(lot.x) > 0.0 else -1
	var hold := _hold_mix(f)
	var bar_i := int(floorf((f - DROP) / BAR))
	var a := MH_CREAM.lerp(PAPER, hold)
	var b := INK
	if lot.accent:
		a = MH_AMBER.lerp(_cycle(int(lot.idx) + maxi(bar_i, 0)), hold)
	# inner side face (facing the road), darker; the front face
	p.draw_checker_box(c, x0, x1, zn, zf, hh, BCELL, a, b, side, Color(0.62, 0.62, 0.68), 0.6)
