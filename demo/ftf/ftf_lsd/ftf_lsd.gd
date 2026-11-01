# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — LSD SUNRISE.
#
# Brief: 14 s at 100 bpm (18 frames a beat, 72 a bar, first downbeat at frame
# 0). A psychedelic sunrise over a mirror sea: a striped 70s sun climbs through
# concentric bands of acid colour that melt and flow like liquid. Nothing is
# placed; everything surfaces out of the warp and sets solid.
#   I   Dawn. A thin horizon glows, the sun peeks over it and its rings bloom
#       outwards. The Minimal Humans lockup rises out of the sea as liquid, in
#       the studio's own cream / amber / red, and sets solid on bar 1. PRESENTS
#       wipes in under it. Then the lockup melts back down into the water.
#   II  The trip: the field folds into a kaleidoscope mandala, spirals, palette
#       cycling, segments stepping up on the beats. The rings peel into
#       horizontal stripes and the palette turns FTF (pink, white, lime,
#       lilac); the FTF logo pours in out of the liquid.
#   III On the drop the logo sets solid, big and sharp, over the sun, with a
#       shockwave ring through the sky and the sea. The hold keeps breathing:
#       rings pulse out on every beat, the palette cycles, the logo ripples on
#       bar downbeats, a kaleidoscope bloom passes behind it. Then the logo
#       melts into the sea, the sun sinks, and the light drains to black.
#
# Beats (30 fps, 420 frames; beat = 18 frames, bar = 72):
#   0       horizon line glows in
#   18      sun peeks; its rings bloom out (iris opens 18-72)
#   30-72   MH rises out of the sea as liquid, sets solid on 72 (bar 1)
#   90      PRESENTS wipes in; 99 katakana
#   126     MH melts down into the sea (126-150)
#   144     bar 2: kaleidoscope mandala; segments step 162, 180
#   180-210 rings peel into stripes, FTF palette, kaleidoscope folds away
#   198-216 FTF logo pours in (liquid -> solid)
#   216     DROP (bar 3): logo solid, shockwave ring, soft flash
#   234     katakana under the logo
#   252-288 kaleidoscope bloom behind the logo
#   288     bar 4: logo ripple; 324 ripple
#   336     logo melts into the sea (336-360); HUD out
#   360     bar 5: the sun sinks, the light drains (360-396)
#   396     last hit; black 400-420
#
# Sound: cues in _init; the Godot Audio Kit scores them from audio/ (recipes,
# cue map and a 100 bpm balearic acid song); the baked track is committed.
# Music can be replaced by any 100 bpm track with its first downbeat at 0.0 s;
# the drop is bar 3 (frame 216, 7.2 s).
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0
const BPM := 100.0
const BEAT := 1800.0 / BPM          # frames per beat at 30 fps
const BAR := 4.0 * BEAT

const HORIZON := 720.0
const PEEK := 18.0
const RISE := 30.0
const SET := 72.0
const PRESENTS := 90.0
const MELT := 126.0
const TRIP := 144.0
const SEG_STEPS := [162.0, 180.0]
const PEEL := 180.0
const POUR := 198.0
const DROP := 216.0
const KANA := 234.0
const BLOOM := 252.0
const RIPPLES := [288.0, 324.0]
const MELT_OUT := 336.0
const SINK := 360.0
const LAST := 396.0
const END := 420

const MH_W := 1200.0
const MH_TOP := 214.0
const LOGO_W := 1500.0
const LOGO_C := Vector2(960, 405)

# palettes (hard bands, outward from the sun)
const SUNRISE := ["#ffe27a", "#ffc23d", "#ff8a1f", "#ff4f5e", "#e0267d", "#9b2bb5", "#5b2bb0", "#2a1a6e", "#5b2bb0", "#9b2bb5", "#e0267d", "#ff4f5e", "#ff8a1f", "#ffc23d"]
const ACID := ["#ffd400", "#ff7a00", "#ff2e88", "#c03bff", "#5a3bff", "#00b3c7", "#18e0a0", "#00b3c7", "#5a3bff", "#c03bff", "#ff2e88", "#ff7a00"]
const FTF_BANDS := ["#e92067", "#ffffff", "#e92067", "#0a0a0d", "#d7ff1f", "#0a0a0d", "#a98bff", "#ffffff"]

var _built := false
var _stage: Node2D
var _field: MotionWarpField
var _mh: MotionWarpField
var _mh_logo: MotionSvg
var _presents: MotionText
var _presents_jp: MotionText
var _ftf: MotionWarpField
var _ftf_logo: MotionSvg
var _kana: MotionText
var _hud: Array[MotionText] = []
var _flash: ColorRect
var _grad_sunrise: Gradient
var _grad_acid: Gradient
var _grad_ftf: Gradient


func _init() -> void:
	duration = END
	bpm = BPM
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": DROP + BAR, "out": MELT_OUT}
	cue(0.0, &"dawn", 0.6)
	cue(PEEK, &"sun.peek", 0.8)
	cue(RISE, &"rise", 0.8)
	cue(SET, &"set", 0.9, {pitch = 1.0})
	cue(PRESENTS, &"presents", 0.6)
	cue(MELT, &"melt", 0.8)
	cue(TRIP, &"kaleido", 0.9)
	for i in SEG_STEPS.size():
		cue(SEG_STEPS[i], &"segment", 0.6 + 0.15 * i, {pitch = [1.0, 1.335][i]})
	cue(POUR, &"pour", 0.9)
	cue(DROP, &"drop", 1.0)
	cue(KANA, &"kana", 0.5)
	cue(BLOOM, &"bloom", 0.6)
	for i in RIPPLES.size():
		cue(RIPPLES[i], &"ripple", 0.7, {pitch = [1.0, 0.89][i]})
	cue(MELT_OUT, &"melt.out", 0.9)
	cue(SINK, &"sink", 1.0)
	cue(LAST, &"last", 0.9)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _build() -> void:
	_built = true
	_grad_sunrise = MotionWarpField.bands_gradient(_cols(SUNRISE))
	_grad_acid = MotionWarpField.bands_gradient(_cols(ACID))
	_grad_ftf = MotionWarpField.bands_gradient(_cols(FTF_BANDS))
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)

	_field = MotionWarpField.new()
	_field.size = size
	_field.horizon = HORIZON
	_field.steps = 1.0
	_field.freq = 14.0
	_field.pal_spread = 1.0 / 14.0
	_field.lut_mix = 1.0
	_field.gradient = _grad_sunrise
	_field.sun_slits = 7.0
	_field.seed = 3.0
	_stage.add_child(_field)

	# Minimal Humans: a content-only warp layer (rises out of the sea, melts back)
	_mh = MotionWarpField.new()
	_mh.size = size
	_mh.draw_field = false
	_mh.horizon = HORIZON
	_mh.seed = 7.0
	_stage.add_child(_mh)
	_mh_logo = MotionSvg.new()
	_mh_logo.data = MotionSvgData.load_any("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh_logo.width = MH_W
	_mh.content.add_child(_mh_logo)
	var k := MH_W / _mh_logo.data.view_box.size.x
	_presents = FTFKit.text(_mh.content, "heavy", 60, Color("#1a0b2e"), "PRESENTS", 0.42)
	_presents.position = Vector2(960.0 - MH_W * 0.5 + 145.0 * k, MH_TOP + 128.9 * k + 40.0)
	_presents_jp = FTFKit.text(_mh.content, "jp", 34, Color("#1a0b2e"), "ミニマル・ヒューマンズ 提供")
	_presents_jp.position = Vector2(_presents.position.x, _presents.position.y + 74.0)

	# FTF: poured in liquid, set solid on the drop
	_ftf = MotionWarpField.new()
	_ftf.size = size
	_ftf.draw_field = false
	_ftf.horizon = HORIZON
	_ftf.seed = 11.0
	_stage.add_child(_ftf)
	var pivot := Node2D.new()
	pivot.name = "LogoPivot"
	pivot.position = LOGO_C
	_ftf.content.add_child(pivot)
	_ftf_logo = MotionSvg.new()
	_ftf_logo.data = MotionSvgData.load_any(FTFKit.LOGO)
	_ftf_logo.width = LOGO_W
	_ftf_logo.position = -_ftf_logo.data.view_box.size * (LOGO_W / _ftf_logo.data.view_box.size.x) * 0.5
	pivot.add_child(_ftf_logo)
	_kana = FTFKit.text(_ftf.content, "jp", 46, FTFKit.WHITE, "フルスロットル・フラックス")
	_kana.position = Vector2(960.0 - _kana.get_text_size().x * 0.5, 622)

	# HUD: small, quiet, at the corners
	var specs := [
		["LSD-01 // SUNRISE // 100 BPM", Vector2(80, 60), false],
		["全開 // 05:42 AM", Vector2(1840, 60), true],
		["LAT 52.52N // HORIZON 0.00", Vector2(80, 1000), false],
		["F-9000 // ANTI-GRAVITY LEAGUE", Vector2(1840, 1000), true],
	]
	for s in specs:
		var t := FTFKit.text(_stage, "mono", 20, FTFKit.CREAM, s[0], 0.14)
		t.position = s[1] - Vector2(t.get_text_size().x if s[2] else 0.0, 0.0)
		_hud.append(t)

	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = Color(1, 0.96, 0.85, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_add_sound()


func _cols(hexes: Array) -> Array:
	var out := []
	for h in hexes:
		out.append(Color(h))
	return out


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_lsd/audio/lsd_map.tres"
	const SONG := "res://demo/ftf/ftf_lsd/audio/music/lsd_song.tres"
	const TRACK := "res://demo/ftf/ftf_lsd/audio/lsd_track.res"
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

## Bands kick outward on every beat (a fast ease, then flow), plus a slow drift.
func _beat_phase(f: float, from: float, to: float, kick := 0.5) -> float:
	var p := 0.0
	var b := from
	while b < to and b <= f:
		p += kick * MK.map(f, [b, b + 8.0], [0, 1], MK.ease_out)
		b += BEAT
	return p


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	_stage.position = MK.shake(f, DROP, 14, 9)
	_frame_field(f)
	_frame_mh(f)
	_frame_ftf(f)
	var hud_a := MK.prog(f, 40, 14) * (1.0 - MK.prog(f, MELT_OUT, 12))
	for i in _hud.size():
		_hud[i].modulate.a = hud_a * (0.55 if i < 2 else 0.4)
		_hud[i].visible = hud_a > 0.0
	# one soft flash on the drop (a single warm flash, 6 frames)
	var fl := 0.0
	if f >= DROP and f < DROP + 1.0:
		fl = 0.0
	_flash.color.a = fl
	_flash.visible = fl > 0.0


func _frame_field(f: float) -> void:
	var fd := _field
	# sun path: peeks at 18, climbs through act I, sits behind the logo, sinks at the end
	var sun_y := MK.interp(f, [0, PEEK, SET, TRIP, DROP, MELT_OUT, SINK, LAST],
		[HORIZON + 140.0, HORIZON + 70.0, HORIZON - 10.0, 600.0, LOGO_C.y + 20.0, LOGO_C.y + 40.0, 520.0, HORIZON + 150.0], MK.ease_in_out)
	fd.centre = Vector2(960, sun_y)
	var beat := MK.beat_pulse(f, BEAT, SET, MELT_OUT, 0.0, 3.5)
	fd.sun_r = MK.interp(f, [PEEK, SET, TRIP, DROP, DROP + 8.0, MELT_OUT, LAST], [120.0, 170.0, 150.0, 150.0, 300.0, 300.0, 220.0], MK.ease_out) * (1.0 + (0.1 if f >= DROP else 0.04) * beat)
	fd.sun_glow = 0.6
	fd.sun_slit_scroll = f / 60.0 + (f / 12.0 if f >= POUR and f < DROP else 0.0)
	fd.sun_color = Color("#ffe27a")
	fd.sun_color_b = Color("#ff3d8b")
	fd.horizon_glow = MK.map(f, [0, 16], [0, 0.9]) * (1.0 - MK.map(f, [LAST, LAST + 6], [0, 1]))
	fd.horizon_color = Color("#ffd9a0")

	# bloom: the field opens out from the sun, and closes back into it at the end
	var open := MK.map(f, [PEEK, SET + 18.0], [0, 2600], MK.ease_in_out)
	var close := MK.map(f, [SINK - 12.0, LAST], [0, 1], MK.ease_out)
	fd.iris = lerpf(open, 0.0, close)
	fd.iris_soft = 220.0
	fd.field_level = MK.map(f, [PEEK, PEEK + 6], [0, 1]) * (1.0 - MK.map(f, [SINK + 12.0, LAST + 2], [0, 1], MK.linear))

	# bands: drift + beat kicks; a big jump on the drop
	var phase := f / 55.0 + _beat_phase(f, SET, DROP, 0.45) + _beat_phase(f, TRIP, DROP, 0.35) + _beat_phase(f, DROP + BEAT, MELT_OUT, 0.8)
	phase += maxf(0.0, f - DROP) / 70.0 * (1.0 - MK.map(f, [MELT_OUT, SINK], [0, 1]))
	phase += 3.0 * MK.map(f, [DROP, DROP + 14], [0, 1], MK.ease_out)
	fd.phase = phase

	# warp: liquid all the time, heavier in the trip and the pour
	fd.warp = MK.interp(f, [0, SET, MELT, TRIP, PEEL, POUR, DROP, DROP + 12, MELT_OUT, SINK, LAST],
		[140.0, 60.0, 90.0, 200.0, 180.0, 210.0, 160.0, 55.0, 55.0, 140.0, 220.0])
	fd.warp += 18.0 * sin(f / 23.0)
	fd.warp_scale = 460.0
	fd.warp_speed = 0.012

	# band mix: rings, then the mandala (rings + twisted rays), then stripes for the pour
	var trip := MK.map(f, [TRIP - 6.0, TRIP + 6.0], [0, 1], MK.ease_in_out) * (1.0 - MK.map(f, [PEEL, POUR + 6.0], [0, 1], MK.ease_in_out))
	var peel := MK.map(f, [PEEL, POUR], [0, 1], MK.ease_in_out) * (1.0 - MK.map(f, [DROP, DROP + 6.0], [0, 1]))
	var bloom := MK.map(f, [BLOOM, BLOOM + 12.0], [0, 1], MK.ease_in_out) * (1.0 - MK.map(f, [BLOOM + 26.0, BLOOM + 36.0], [0, 1], MK.ease_in_out))
	fd.rings = 1.0 - peel
	fd.rays = 2.2 * trip + 1.4 * bloom + 0.7 * MK.map(f, [DROP, DROP + 20], [0, 1]) * (1.0 - MK.map(f, [MELT_OUT, SINK], [0, 1]))
	fd.twist = 0.35 * trip + 0.25 * bloom + 0.15
	fd.stripes = 1.6 * peel
	fd.freq = lerpf(14.0, 18.0, trip)
	fd.kaleido = maxf(trip, bloom * 0.85)
	var seg := 6.0
	if f >= SEG_STEPS[0]:
		seg = 8.0
	if f >= SEG_STEPS[1]:
		seg = 12.0
	if f >= DROP:
		seg = 10.0
	fd.segments = seg
	fd.kaleido_spin = f / 900.0

	# palettes: sunrise -> acid cosine (trip) -> FTF bands (peel) -> acid bands (hold)
	if f < TRIP - 6.0:
		fd.gradient = _grad_sunrise
		fd.lut_mix = 1.0
	elif f < PEEL:
		fd.gradient = _grad_acid
		fd.lut_mix = 1.0 - trip   # cosine rainbow in the mandala
		fd.set_palette(Vector3(0.6, 0.45, 0.55), Vector3(0.45, 0.45, 0.45), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.2, 0.45))
	elif f < DROP:
		fd.gradient = _grad_ftf
		fd.lut_mix = MK.map(f, [PEEL, PEEL + 10.0], [0, 1])
	else:
		fd.gradient = _grad_acid
		fd.lut_mix = 1.0 - bloom * 0.7
	fd.pal_spread = 1.0 / 12.0 if f >= DROP else 1.0 / 14.0
	fd.pal_shift = f / 600.0 + (f - TRIP) / 160.0 * trip + maxf(0.0, f - DROP) / 260.0
	fd.steps = 1.0

	# shockwave ring on the drop and small ones on bar downbeats
	var ring := -1.0
	var gain := 0.0
	if f >= DROP and f < DROP + 30.0:
		ring = MK.map(f, [DROP, DROP + 30.0], [120, 2200], MK.ease_out)
		gain = 1.0 - (f - DROP) / 30.0
		fd.ring_w = 70.0 - 30.0 * (f - DROP) / 30.0
	for at in RIPPLES:
		if f >= at and f < at + 24.0:
			ring = MK.map(f, [at, at + 24.0], [200, 1600], MK.ease_out)
			gain = 0.6 * (1.0 - (f - at) / 24.0)
	fd.ring_r = ring
	if f < DROP or f >= DROP + 30.0:
		fd.ring_w = 36.0
	fd.ring_gain = gain
	fd.ring_color = Color("#fff4d6")
	fd.ripple = 7.0 + 4.0 * beat


func _frame_mh(f: float) -> void:
	var on := f >= RISE and f < MELT + 26.0
	_mh.visible = on
	if not on:
		return
	# rises out of the sea as liquid, sets solid on the bar
	var rise := MK.map(f, [RISE, SET], [0, 1], MK.ease_out)
	var settle := MK.map(f, [RISE + 10.0, SET], [1, 0], MK.ease_in_quad)
	var melt := MK.map(f, [MELT, MELT + 22.0], [0, 1], MK.ease_in_quad)
	_mh_logo.position = Vector2(960.0 - MH_W * 0.5, lerpf(HORIZON + 40.0, MH_TOP, rise) + melt * 160.0)
	_mh.content_warp = 150.0 * settle + 160.0 * melt
	_mh.content_melt = 110.0 * settle + 520.0 * melt
	_mh.content_chroma = 16.0 * settle + 22.0 * melt
	_mh.content_level = 1.0 - MK.map(f, [MELT + 10.0, MELT + 24.0], [0, 1])
	_mh.reflect_dim = 0.5
	# PRESENTS wipes in; the katakana follows
	_presents.visible_chars = int(MK.map(f, [PRESENTS, PRESENTS + 8.0], [0, 8], MK.linear))
	_presents.position.y = _mh_logo.position.y + 128.9 * (MH_W / 485.7) + 40.0
	_presents_jp.visible_chars = int(MK.map(f, [PRESENTS + 9.0, PRESENTS + 18.0], [0, 15], MK.linear))
	_presents_jp.position.y = _presents.position.y + 74.0


func _frame_ftf(f: float) -> void:
	var on := f >= POUR and f < MELT_OUT + 26.0
	_ftf.visible = on
	if not on:
		return
	# pour: liquid coalescing into the logo; solid exactly on the drop
	var pour := MK.map(f, [POUR, DROP], [1, 0], MK.ease_in_quad)
	var ripple := 0.0
	for at in RIPPLES:
		if f >= at:
			ripple = maxf(ripple, exp(-(f - at) / 6.0) * absf(sin((f - at) * 0.5)))
	var melt := MK.map(f, [MELT_OUT, MELT_OUT + 24.0], [0, 1], MK.ease_in_quad)
	_ftf.content_warp = 260.0 * pour + 30.0 * ripple + 140.0 * melt + 3.0 * sin(f / 9.0) * (1.0 if f > DROP + 10.0 else 0.0)
	_ftf.content_melt = 160.0 * pour + 560.0 * melt
	_ftf.content_chroma = 26.0 * pour + 10.0 * ripple + 14.0 * melt
	_ftf.content_level = MK.map(f, [POUR, POUR + 8.0], [0, 1]) * (1.0 - MK.map(f, [MELT_OUT + 12.0, MELT_OUT + 26.0], [0, 1]))
	_ftf.reflect_dim = 0.55
	var pivot: Node2D = _ftf_logo.get_parent()
	var punch := 1.0 + 0.05 * (1.0 - MK.map(f, [DROP, DROP + 10.0], [0, 1], MK.ease_out)) if f >= DROP else 1.0
	var bob := sin((f - DROP) / BEAT * PI) * 7.0 if f >= DROP else 0.0
	pivot.position = LOGO_C + Vector2(0, bob + melt * 120.0)
	pivot.scale = Vector2.ONE * punch
	_kana.visible_chars = int(MK.map(f, [KANA, KANA + 10.0], [0, 13], MK.linear))
	_kana.position.y = 622.0 + bob + melt * 120.0
