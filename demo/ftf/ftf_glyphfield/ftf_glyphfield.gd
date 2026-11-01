# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take 5: GLYPH FIELD.
#
# Brief: 14 s at 90 bpm, half-time and heavy (20 frames a beat, 80 a bar, first
# downbeat at frame 0). The whole piece is one field of ~6,400 cycling glyphs
# (katakana, digits, arrows, blocks) over a deeper field of big dim glyphs. No
# logo is ever "placed": logos are brightness in the field.
#   I   A dim green field drizzles in. A scan band sweeps down and resolves
#       MINIMAL HUMANS behind it as stencilled glyph blocks in the studio's
#       cream / amber / red, the M's three layers fanned into three glyph
#       bands. PRESENTS types into the field on sixteenths. On bar 2 a
#       shockwave condenses the glyphs into the solid vector lockup.
#   II  Data storm: the lockup decays back into glyphs, the field heats up,
#       cycles faster, rains harder, and a pink front sweeps across it until
#       everything is noise; a hard cut to black.
#   III The FTF logo appears as giant glyph letters crawling past, too big for
#       the frame, and the field zooms out one heavy step per beat until the
#       whole logo sits in frame. Half a beat of black around it, then on the
#       drop a shockwave condenses it into the solid logo (pink and white).
#       It holds, glyphs raining around it, katakana typing under it, scans
#       and one data glitch on the beat. Then it decays back into glyphs, the
#       columns fall away under gravity, a block cursor blinks twice and goes
#       out. Black to the end.
#
# Beats (30 fps, 420 frames; beat = 20 frames, bar = 80):
#   0-20     field fades in (dim green, slow rain)
#   20-40    scan band sweeps down, MH resolves behind it
#   60-95    PRESENTS types on sixteenths (5 frames a letter)
#   80       shockwave: MH condenses into the solid lockup (80-92); 100 pulse
#   120      decay + storm: solid -> glyphs, field heats, pink front 120-150
#   156      cut to black (4 frames)
#   160/180/200/220  FTF zoom steps, ring pulse on each
#   236      everything but the logo glyphs goes dark
#   240      DROP: shockwave, logo condenses (240-250), flash
#   260      hold pulse; 262 katakana types under the logo
#   280/300  scans; 300 data glitch
#   320      decay: the logo returns to glyphs
#   336      columns fall away (gravity), field drains to 380
#   380/390  block cursor blinks; 400 out
#   400-420  black
#
# Sound: cues in _init; the Godot Audio Kit scores them from audio/ (recipes,
# cue map and a 90 bpm half-time song); the baked track is committed. Music can
# be replaced by any 90 bpm track with its first downbeat at 0.0 s; the drop is
# bar 4 (frame 240, 8.0 s).
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0
const BPM := 90.0
const BEAT := 1800.0 / BPM          # frames per beat at 30 fps
const BAR := 4.0 * BEAT

const IN := 0.0
const SCAN := 20.0
const SCAN_LEN := 20.0
const PRESENTS := 60.0
const LETTER := 5.0                        # a sixteenth
const MH_SOLID := 80.0
const STORM := 120.0
const CUT := 156.0
const ZOOMS := [160.0, 180.0, 200.0, 220.0]
const ZOOM_SCALES := [3.4, 2.3, 1.6, 1.18, 1.0]
const DARK := 236.0
const DROP := 240.0
const JP_AT := 262.0
const SCANS := [280.0, 300.0]
const PULSES := [260.0, 280.0, 300.0]          # half-time pulses through the hold
const MH_PULSE := 100.0                         # one through the MH hold
const GLITCH := 300.0
const DECAY := 320.0
const FALL := 336.0
const CURSOR := [380.0, 390.0]
const GONE := 400.0
const END := 420

const MH_W := 1300.0
const MH_POS := Vector2(310, 250)
const LOGO_W := 1400.0
const LOGO_C := Vector2(960, 520)
const CELL := Vector2(18, 18)

const GLYPH_FONT := "res://demo/ftf/ftf_glyphfield/assets/noto-jp-glyphs-700.woff2"
# dim set: thin katakana, digits, punctuation; lit set: dense katakana and blocks
const DIM_CHARS := "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワンー0123456789+-=/<>:.#"
const LIT_CHARS := "ヲヌネホムメヰヱ■■■■●●◆◆▲▼█▓▒░▌▐▀▄◢◣◤◥※＃＊％＠反重力流束速度警告信号機体"

const GREEN := Color("#2dff6a")
const LIME := Color("#d7ff1f")
const PINK := Color("#e92067")
const HOTPINK := Color("#ff2d7a")
const WHITE := Color("#ffffff")
const INK := Color("#050806")

var _built := false
var _deep: MotionGlyphField
var _field: MotionGlyphField
var _mh: MotionSvg
var _presents: MotionText
var _ftf_pivot: Node2D
var _ftf: MotionSvg
var _jp_mask: MotionText
var _storm: MotionCanvas
var _jp_small: MotionText
var _hud: Array[MotionText] = []
var _cursor: ColorRect
var _flash: ColorRect


func _init() -> void:
	duration = END
	bpm = BPM
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": 250.0, "out": DECAY}
	cue(IN, &"field.in", 0.6)
	cue(SCAN, &"scan", 1.0)
	cue(SCAN + SCAN_LEN, &"resolve", 0.9)
	for i in "PRESENTS".length():
		if PRESENTS + i * LETTER != MH_SOLID:   # the shock covers that letter
			cue(PRESENTS + i * LETTER, &"type", 0.55 + 0.04 * i, {pitch = [1.0, 1.12, 1.26, 1.5, 1.68, 1.5, 1.26, 2.0][i]})
	cue(MH_SOLID, &"shock", 0.9)
	cue(STORM, &"decay", 0.8)
	cue(STORM, &"storm", 1.0)
	cue(CUT, &"cut", 0.8)
	for i in ZOOMS.size():
		cue(ZOOMS[i], &"zoom", 0.7 + 0.1 * i, {pitch = [0.75, 0.84, 0.94, 1.0][i]})
	cue(DROP, &"suck", 1.0)          # a reversed swell that peaks on the drop
	cue(DROP, &"drop", 1.0)
	cue(JP_AT, &"type.run", 0.6)
	for i in SCANS.size():
		cue(SCANS[i], &"scan.small", 0.6)
	cue(MH_PULSE, &"pulse", 0.45)
	cue(PULSES[0], &"pulse", 0.5)      # the other pulses ride with the scans
	cue(GLITCH, &"glitch", 0.9)
	cue(DECAY, &"decay", 0.9)
	cue(FALL, &"fall", 1.0)
	for i in CURSOR.size():
		cue(CURSOR[i], &"cursor", 0.7, {pitch = [1.0, 0.84][i]})
	cue(GONE, &"blip", 1.0)


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
	var font := MotionFonts.font(GLYPH_FONT)

	# a deep layer of big, very dim glyphs drifting slower: parallax depth
	_deep = MotionGlyphField.new()
	_deep.font = font
	_deep.charset = DIM_CHARS
	_deep.cell = Vector2(54, 54)
	_deep.glyph_scale = 0.8
	_deep.seed = 7.0
	_deep.base_density = 0.3
	_deep.base_level = 0.07
	_deep.cycle_min = 0.01
	_deep.cycle_max = 0.06
	add_child(_deep)

	_field = MotionGlyphField.new()
	_field.font = font
	_field.charset = DIM_CHARS + LIT_CHARS
	_field.cell = CELL
	_field.dim_range = Vector2i(0, DIM_CHARS.length())
	_field.lit_range = Vector2i(DIM_CHARS.length(), LIT_CHARS.length())
	_field.ink_color = INK
	_field.seed = 3.0
	add_child(_field)

	# mask: the MH lockup, PRESENTS, the FTF logo and the katakana line
	_mh = MotionSvg.new()
	_mh.data = MotionSvgData.load_any("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh.width = MH_W
	_mh.position = MH_POS
	_field.mask_content.add_child(_mh)
	_presents = FTFKit.text(_field.mask_content, "wide", 104, FTFKit.MH_CREAM, "PRESENTS", 0.28)
	_presents.position = Vector2(MH_POS.x + 145.0 * MH_W / 485.7, MH_POS.y + 128.9 * MH_W / 485.7 + 60.0)
	_ftf_pivot = Node2D.new()
	_ftf_pivot.position = LOGO_C
	_field.mask_content.add_child(_ftf_pivot)
	_ftf = MotionSvg.new()
	_ftf.data = MotionSvgData.load_any(FTFKit.LOGO)
	_ftf.width = LOGO_W
	_ftf.position = -_ftf.data.view_box.size * (LOGO_W / _ftf.data.view_box.size.x) * 0.5
	_ftf_pivot.add_child(_ftf)
	_storm = MotionCanvas.new()
	_storm.draw_fn = _draw_storm
	_field.mask_content.add_child(_storm)
	_jp_mask = FTFKit.text(_field.mask_content, "jp", 72, LIME, "フルスロットル・フラックス")
	_jp_mask.position = Vector2(LOGO_C.x - _jp_mask.get_text_size().x * 0.5, 790)

	# vector type that sits on top of the field (too small to be glyph-built)
	_jp_small = FTFKit.text(self, "jp", 30, LIME, "ミニマル・ヒューマンズ　提供")
	_jp_small.position = Vector2(_presents.position.x + 6.0, _presents.position.y + 150.0)
	var tl := FTFKit.text(self, "mono", 20, GREEN, "SIGNAL 09 // GLYPH FIELD // 6,400 CELLS", 0.12)
	tl.position = Vector2(48, 36)
	var tr := FTFKit.text(self, "mono", 20, GREEN, "00:00:00:00", 0.12)
	tr.position = Vector2(W - 48 - tr.get_text_size().x, 36)
	var bl := FTFKit.text(self, "mono", 20, GREEN, "90 BPM // 4/4 // HALF-TIME", 0.12)
	bl.position = Vector2(48, H - 56)
	var br := FTFKit.text(self, "mono", 20, GREEN, "MH-FTF // 反重力 // 準備完了", 0.12)
	br.position = Vector2(W - 48 - br.get_text_size().x, H - 56)
	_hud = [tl, tr, bl, br]

	_cursor = ColorRect.new()
	_cursor.color = LIME
	_cursor.size = CELL * Vector2(0.8, 1.0)
	_cursor.position = Vector2(960, 540) - _cursor.size * 0.5
	add_child(_cursor)
	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = WHITE
	add_child(_flash)
	_add_sound()


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_glyphfield/audio/gf_map.tres"
	const SONG := "res://demo/ftf/ftf_glyphfield/audio/music/gf_song.tres"
	const TRACK := "res://demo/ftf/ftf_glyphfield/audio/gf_track.res"
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


## Data storm, drawn into the mask: seeded blocks and bars of pink, white and
## green that re-roll on sixteenths and fill the frame as the heat rises.
func _draw_storm(c: MotionCanvas, f: float) -> void:
	if f < STORM or f >= CUT:
		return
	var heat := MK.map(f, [STORM, CUT], [0, 1], MK.ease_in_quad)
	var st := floorf(f / 2.5)                 # re-roll every 32nd note
	var n := int(6 + heat * 70)
	var cols := [HOTPINK, WHITE, GREEN, HOTPINK, PINK]
	for k in n:
		var r := MK.rand(st * 13.1 + k * 7.7)
		var x := MK.rand(r * 91.0 + k) * W
		var y := floorf(MK.rand(r * 37.0 + k * 3.3) * H / CELL.y) * CELL.y
		var w := (2.0 + floorf(MK.rand(k * 5.1 + st) * 30.0)) * CELL.x
		var h := (1.0 + floorf(MK.rand(k * 2.3 + st * 1.7) * 3.0 * (0.3 + heat))) * CELL.y
		c.rect(Rect2(x - w * 0.5, y, w, h), cols[k % cols.size()], 1.0)


## A value that steps on the beat: eased in over `len` frames after each key.
func _stepped(f: float, keys: Array, values: Array, len := 6.0) -> float:
	var v: float = values[0]
	for i in keys.size():
		var k: float = keys[i]
		if f >= k:
			v = lerpf(values[i], values[i + 1], MK.map(f, [k, k + len], [0, 1], MK.bezier(0.2, 0.9, 0.2, 1.0)))
	return v


func _ring(f: float, at: float, len := 18.0, reach := 1500.0) -> float:
	if f < at or f > at + len:
		return -1.0
	return MK.map(f, [at, at + len], [0, reach], MK.ease_out)


func _frame(f: float) -> void:
	if not _built:
		return
	var fld := _field
	# ---------------------------------------------------------------- field state
	var fade_in := MK.map(f, [IN, IN + 20], [0, 1], MK.ease_out)
	var heat := MK.map(f, [STORM, CUT], [0, 1], MK.ease_in_quad) if f < CUT else 0.0
	var drain := MK.map(f, [FALL, 380], [0, 1], MK.ease_in_quad)
	var cut := f >= CUT and f < ZOOMS[0]
	var dark := MK.map(f, [DARK, DARK + 2], [0, 1], MK.linear) if f < DROP + 4 else 0.0
	var phase3 := f >= ZOOMS[0]
	fld.frame = f
	fld.base_color = GREEN if not phase3 else HOTPINK
	fld.base_color_b = HOTPINK if not phase3 else GREEN
	fld.base_front = lerpf(-200.0, W + 300.0, MK.map(f, [STORM, STORM + 30], [0, 1], MK.ease_in_out)) if f >= STORM and not phase3 else -100000.0
	if phase3:
		# after the storm the field is pink with green flecks drifting back in
		fld.base_front = lerpf(-200.0, 700.0, MK.map(f, [DROP, DROP + 60], [0, 1], MK.ease_out)) if f >= DROP else -100000.0
	fld.base_density = lerpf(0.42, 0.95, heat) * fade_in * (1.0 - drain)
	fld.base_level = lerpf(0.3, 0.7, heat) * (1.0 - dark) + (0.1 * MK.map(f, [DROP, DROP + 20], [0, 1], MK.ease_out) if phase3 else 0.0)
	fld.base_flicker = heat * 0.5
	fld.cycle_min = lerpf(0.03, 0.3, heat)
	fld.cycle_max = lerpf(0.25, 1.0, heat)
	fld.lit_cycle = 0.35
	fld.rain = lerpf(0.5, 4.0, heat) if not phase3 else lerpf(0.7, 1.6, MK.map(f, [DROP, DROP + 20], [0, 1], MK.ease_out))
	# the last falling glyphs fade out before the cursor's final blink; nothing after
	fld.level = (0.0 if cut else 1.0) * (1.0 - MK.map(f, [386, 396], [0, 1], MK.linear))
	fld.visible = f < GONE
	_deep.visible = f < GONE
	_deep.frame = f
	_deep.rain = 0.25
	_deep.level = fade_in * (1.0 - drain) * (0.0 if cut else 1.0) * (1.0 - dark)
	_deep.base_color = fld.base_color
	_deep._sync()

	# ---------------------------------------------------------------- act I: MH
	var mh_on := f < CUT
	_mh.visible = mh_on
	_presents.visible = mh_on and f >= PRESENTS
	var fan := (1.0 - MK.map(f, [MH_SOLID - 8, MH_SOLID + 6], [0, 1], MK.ease_in_out)) * 9.0
	_mh.apply(func(i: int) -> Variant:
		if i <= 2:
			return {tx = (2 - i) * fan, ty = (2 - i) * fan}
		return {})
	_presents.visible_chars = int(floorf((f - PRESENTS) / LETTER) + 1.0) if f >= PRESENTS else 0
	var jp_chars := int(MK.map(f, [PRESENTS + 40, PRESENTS + 52], [0, 14], MK.linear))
	_jp_small.visible = f >= PRESENTS + 40 and f < STORM + 10
	_jp_small.visible_chars = jp_chars
	_jp_small.modulate.a = 1.0 - MK.map(f, [STORM, STORM + 10], [0, 1], MK.linear)

	# ---------------------------------------------------------------- act III: FTF
	var ftf_on := phase3 and f < GONE
	_ftf_pivot.visible = ftf_on
	var zs := _stepped(f, [ZOOMS[1], ZOOMS[2], ZOOMS[3], DROP - 4.0], ZOOM_SCALES, 7.0)
	_ftf_pivot.scale = Vector2.ONE * zs
	# while it is huge it crawls left to right, then settles centred
	var crawl := (1.0 - MK.map(f, [ZOOMS[0], DROP - 4.0], [0, 1], MK.ease_in_out)) * 900.0
	_ftf_pivot.position = LOGO_C + Vector2(crawl - 300.0 * (1.0 - MK.map(f, [ZOOMS[0], ZOOMS[1]], [0, 1], MK.linear)), 0)
	# the white plate stays below the light threshold while the logo is glyphs,
	# so the pink letters read; it comes up to full as the logo condenses
	var plate := 0.22 + 0.78 * MK.map(f, [DROP, DROP + 8], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [DECAY + 12, DECAY + 16], [0, 1], MK.linear))
	_ftf.apply(func(i: int) -> Variant:
		return {o = plate} if i == FTFKit.PLATE else {})
	_jp_mask.visible = f >= JP_AT and f < GONE
	_jp_mask.visible_chars = int(MK.map(f, [JP_AT, JP_AT + 26], [0, 13], MK.linear))

	# ---------------------------------------------------------------- reveal / lit
	fld.threshold = 0.4
	fld.softness = 0.12
	fld.lit_fill = 0.88
	fld.lit_invert = 1.0
	fld.tint = 0.0
	if f < STORM:
		# the scan reveals MH top to bottom
		fld.reveal_sweep = 1.0
		fld.reveal_angle = 90.0
		fld.reveal = MK.map(f, [SCAN, SCAN + SCAN_LEN], [0, 1], MK.linear)
	elif f < CUT:
		fld.reveal_sweep = 0.0
		fld.reveal = 1.0 - MK.map(f, [STORM + 4, STORM + 24], [0, 1], MK.ease_in_quad) * 0.0
		_mh.visible = f < STORM + 24
		_presents.visible = f < STORM + 16
	else:
		fld.reveal_sweep = 0.0
		fld.reveal = _stepped(f, ZOOMS, [0.0, 0.45, 0.7, 0.9, 1.0], 5.0)
	fld.lit_level = 1.0

	# ---------------------------------------------------------------- highlights
	fld.scan_y = -100000.0
	fld.scan_w = 34.0
	fld.scan_gain = 1.0
	if f >= SCAN and f <= SCAN + SCAN_LEN + 4:
		fld.scan_y = lerpf(-40.0, H + 40.0, MK.map(f, [SCAN, SCAN + SCAN_LEN], [0, 1], MK.linear))
	for at in SCANS:
		if f >= at and f <= at + 16:
			fld.scan_y = lerpf(-40.0, H + 40.0, MK.map(f, [at, at + 14], [0, 1], MK.ease_in_out))
			fld.scan_gain = 0.8
	fld.ring_r = -1.0
	fld.ring_gain = 1.0
	fld.ring_w = 70.0
	var rings := [[MH_SOLID, Vector2(MH_POS.x + 60.0 * MH_W / 485.7, MH_POS.y + 64.0 * MH_W / 485.7), 1.0],
		[ZOOMS[0], LOGO_C, 0.6], [ZOOMS[1], LOGO_C, 0.6], [ZOOMS[2], LOGO_C, 0.6], [ZOOMS[3], LOGO_C, 0.6], [DROP, LOGO_C, 1.2],
		[PULSES[0], LOGO_C, 0.5], [PULSES[1], LOGO_C, 0.5], [PULSES[2], LOGO_C, 0.5],
		[MH_PULSE, Vector2(960, 470), 0.5]]
	for r in rings:
		var rr := _ring(f, r[0], 20.0, 1700.0)
		if rr >= 0.0:
			fld.ring_r = rr
			fld.ring_c = r[1]
			fld.ring_gain = r[2] * (1.0 - MK.map(f, [r[0], r[0] + 20.0], [0, 1], MK.linear) * 0.6)
	fld.hot_color = WHITE if not phase3 else LIME

	# ---------------------------------------------------------------- solidify
	fld.solidify_sweep = 1.0
	fld.solidify_noise = 0.35
	var solid := 0.0
	if f >= MH_SOLID and f < STORM + 10:
		fld.ring_c = rings[0][1] if f < MH_SOLID + 20 else fld.ring_c
		solid = MK.map(f, [MH_SOLID, MH_SOLID + 12], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [STORM, STORM + 8], [0, 1], MK.ease_in_quad))
		if f >= STORM:
			fld.solidify_sweep = 0.0
	elif f >= DROP and f < DECAY + 14:
		solid = MK.map(f, [DROP, DROP + 10], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [DECAY, DECAY + 12], [0, 1], MK.linear))
		if f >= GLITCH and f < GLITCH + 4:
			solid = 0.55 if int(f) % 2 == 0 else 0.8
		if f >= DECAY or (f >= GLITCH and f < GLITCH + 4):
			fld.solidify_sweep = 0.0
		fld.ring_c = LOGO_C
	fld.solidify = solid

	# ---------------------------------------------------------------- outro: fall
	fld.fall_t = f - FALL if f >= FALL else -1.0
	fld.fall_g = 0.5
	fld.fall_spread = 26.0
	fld.lit_level = 1.0 - MK.map(f, [FALL + 30, GONE - 6], [0, 1], MK.linear)
	fld._sync()

	# ---------------------------------------------------------------- overlays
	for i in _hud.size():
		var t := _hud[i]
		t.visible = f >= 6.0 + i * 2.0 and f < 380.0 and not cut
		t.color = GREEN if not phase3 else (LIME if i % 2 == 0 else HOTPINK)
	_hud[0].visible_chars = int(MK.map(f, [6, 24], [0, 40], MK.linear))
	_hud[1].text = MK.timecode(f)
	_cursor.visible = (f >= CURSOR[0] and f < CURSOR[0] + 6.0) or (f >= CURSOR[1] and f < GONE) \
		or (f >= FALL + 34.0 and f < CURSOR[0] and int(f / 5.0) % 2 == 0)
	var fl := 0.0
	if f >= DROP and f < DROP + 4:
		fl = 0.7 * (1.0 - MK.map(f, [DROP, DROP + 4], [0, 1], MK.ease_out))
	if f >= MH_SOLID and f < MH_SOLID + 5:
		fl = 0.3 * (1.0 - MK.map(f, [MH_SOLID, MH_SOLID + 5], [0, 1], MK.linear))
	_flash.visible = fl > 0.01
	_flash.color.a = fl
