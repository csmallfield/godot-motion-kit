# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take 3: RISO.
#
# Brief: 14 s at 100 bpm (18 frames a beat, 72 a bar, first downbeat at frame
# 0). Swissted / Designers Republic print on a risograph press. Nothing springs
# in: everything arrives by being printed. Each colour is its own plate
# (MotionPlate), rolled onto cream paper (MotionPaper) one beat at a time,
# overprinting the plates under it (pink over blue goes purple, anything under
# black stays black), halftoned where it is a tint, ragged and speckled, and
# off register until the press clamps every plate home on the beat.
#   I   SHEET A, MINIMAL HUMANS. The sheet feeds in. Blue keyline (rules, crop
#       marks, a quarter circle) and a huge halftone "01"; the M's red and amber
#       layers, each knocked out by the cream front layer; the black plate (a
#       panel with the M knocked out of it, the wordmark, the Swiss columns);
#       a lime band; then PRESENTS in pink, and on that beat every plate snaps
#       into register. The printed sheet is pulled out of the press.
#   II  SHEET B, FULL THROTTLE FLUX. A new sheet feeds in. Blue: rules, a
#       halftone drop shadow of the logo and a huge "9000"; the pink plate (the
#       logo, its white parts knocked out) slams in far off register; lime band
#       behind the logo; black type; and on the bar every plate snaps home. In
#       the hold the blue screen slowly turns (the dots shimmer), the lime plate
#       takes a second, slurred impression, and a red 認可 approval stamp hits.
#   III FLOOD. A black roller floods the sheet right to left on the last two
#       beats; the final hit lands on black and the sheet leaves only black.
#
# Beats (30 fps, 420 frames; beat = 18, bar = 72):
#   0       sheet A feeds in (lands 14)
#   18/36/54  blue, red, amber plates roll on (10 frames each)
#   72      black plate (bar 1)
#   90      lime band
#   108     pink PRESENTS + REGISTER: every plate snaps home
#   126     sheet A pulled out, sheet B feeds in (lands 144)
#   144/162/180/198  blue, pink (far off register), lime, black
#   216     REGISTER (bar 3): the logo locks
#   216-324 hold: blue screen turns; 252 lime slur; 270 approval stamp
#   324-360 black flood, right to left
#   360     final hit on black (bar 5); 366 sheet gone; black to 420
#
# Music: 100 bpm, 4/4, first downbeat at 0.0 s; a replacement track at that
# tempo lands every print on its beat. The drop into the FTF sheet is bar 2
# (frame 144, 4.8 s); the register snap is bar 3 (frame 216, 7.2 s).
@tool
extends MotionComposition

const BEAT := 18.0
const BAR := 72.0
# ---- Sheet A
const FEED_A := 0.0
const A_BLUE := 18.0
const A_RED := 36.0
const A_AMBER := 54.0
const A_BLACK := 72.0
const A_LIME := 90.0
const A_PINK := 108.0
const A_SNAP := 108.0
const SHEET_CHANGE := 126.0
# ---- Sheet B
const B_BLUE := 144.0
const B_PINK := 162.0
const B_LIME := 180.0
const B_BLACK := 198.0
const B_SNAP := 216.0
const SLUR := 252.0
const STAMP := 270.0
const FLOOD := 324.0
const END_HIT := 360.0
const CLEAR := 366.0
const END := 420
const ROLL := 10.0

# ---- inks (riso-like)
const PAPER := Color("#f2eee6")
const BLUE := Color("#2448c8")
const PINK := Color("#ff2f7d")
const LIME := Color("#d4f21a")
const RED := Color("#ef393b")
const AMBER := Color("#f6ad32")
const BLACK := Color("#141416")
const BED := Color(0.074, 0.073, 0.078)   # = paper x black ink: the flood blends into it

const PAPER_RECT := Rect2(60, 40, 1800, 1000)
const MH_SVG := "res://demo/assets/logos/mh_logoFull_standard.svg"
const INTER9 := "res://demo/assets/fonts/inter-latin-900-normal.woff2"
const INTER7 := "res://demo/assets/fonts/inter-latin-700-normal.woff2"

# Sheet A layout
const PANEL := Rect2(160, 130, 540, 540)
const M_CROP := Rect2(0, 0, 130.3, 129.0)
const M_W := 430.0
const WORD_CROP := Rect2(145.2, 0, 340.6, 129.0)
const WORD_W := 980.0
const WORD_POS := Vector2(800, 150)
# Sheet B layout
const LOGO_W := 1320.0
const LOGO_POS := Vector2(300, 170)

var _built := false
var _stage: Node2D
var _sheet_a: Node2D
var _sheet_b: Node2D
var _a: Dictionary = {}       # plate name -> MotionPlate
var _b: Dictionary = {}
var _stamp_pivot: Node2D
var _mh_svg: MotionSvgData
var _ftf_svg: MotionSvgData


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": B_BLUE, "hold": B_SNAP, "out": FLOOD}
	cue(FEED_A, &"feed", 0.7)
	var a_prints := [A_BLUE, A_RED, A_AMBER, A_BLACK, A_LIME]
	for i in a_prints.size():
		cue(a_prints[i], &"print", 0.6 + 0.06 * i, {pitch = [1.0, 0.89, 1.12, 0.75, 1.26][i]})
	cue(A_SNAP, &"register", 0.8)
	cue(SHEET_CHANGE, &"sheet", 0.9)
	var b_prints := [B_BLUE, B_LIME, B_BLACK]   # the pink plate gets its own slam
	for i in b_prints.size():
		cue(b_prints[i], &"print", 0.7 + 0.08 * i, {pitch = [1.0, 1.12, 0.75][i]})
	cue(B_PINK, &"slam", 1.0)
	cue(B_SNAP, &"register", 1.0, {pitch = 0.84})
	cue(SLUR, &"slur", 0.6)
	cue(STAMP, &"stamp", 1.0)
	cue(FLOOD, &"flood", 1.0)
	cue(END_HIT, &"end", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _font(path: String) -> Font:
	var f := MotionFonts.font(path)
	var jp := MotionFonts.font(FTFKit.JP_FONT)
	if not f.fallbacks.has(jp):
		f.fallbacks = [jp]
	return f


func _text(parent: Node, path: String, sz: float, s: String, pos: Vector2, tracking := 0.0, col := Color.BLACK) -> MotionText:
	var t := MotionText.new()
	t.font = _font(path)
	t.font_size = sz
	t.color = col
	t.tracking = tracking
	t.text = s
	t.position = pos
	parent.add_child(t)
	return t


func _rect(parent: Node, r: Rect2, col := Color.BLACK) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	parent.add_child(c)
	return c


func _svg(parent: Node, data: MotionSvgData, only: Array, w: float, pos: Vector2, crop := Rect2()) -> MotionSvg:
	var s := MotionSvg.new()
	s.data = data
	s.only = PackedInt32Array(only)
	s.width = w
	if crop.size.x > 0.0:
		s.crop = crop
	s.position = pos
	parent.add_child(s)
	return s


func _plate(sheet: Node2D, ink: Color, seed_v: float, cell := 0.0, angle := 15.0) -> MotionPlate:
	var p := MotionPlate.new()
	p.ink = ink
	p.cell = cell
	p.angle_deg = angle
	p.roughness = 1.2
	p.grain = 0.35
	p.mottle = 0.22
	p.seed = seed_v
	p.roll_soft = 30.0
	p.roll_shadow = 0.4
	sheet.add_child(p)
	return p


func _load_svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _build() -> void:
	_built = true
	_mh_svg = _load_svg(MH_SVG)
	_ftf_svg = _load_svg(FTFKit.LOGO)
	var bg := ColorRect.new()
	bg.color = BED
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_sheet_a = _make_sheet(1.0)
	_sheet_b = _make_sheet(2.0)
	_build_a()
	_build_b()
	_add_sound()


func _make_sheet(seed_v: float) -> Node2D:
	var sheet := Node2D.new()
	_stage.add_child(sheet)
	var paper := MotionPaper.new()
	paper.position = PAPER_RECT.position
	paper.size = PAPER_RECT.size
	paper.color = PAPER
	paper.seed = seed_v
	paper.mottle = 0.035
	paper.fibres = 0.018
	sheet.add_child(paper)
	return sheet


## Crop marks just outside the trim box and two registration targets.
func _marks(c: MotionCanvas) -> void:
	var trim := Rect2(110, 80, 1700, 920)
	for corner in [trim.position, Vector2(trim.end.x, trim.position.y), trim.end, Vector2(trim.position.x, trim.end.y)]:
		var sx := -1.0 if corner.x < 960 else 1.0
		var sy := -1.0 if corner.y < 540 else 1.0
		c.line(corner + Vector2(sx * 8, 0), corner + Vector2(sx * 40, 0), Color.BLACK, 2.0)
		c.line(corner + Vector2(0, sy * 8), corner + Vector2(0, sy * 40), Color.BLACK, 2.0)
	for p in [Vector2(85, 540), Vector2(1835, 540)]:
		c.ring(p, 13, Color.BLACK, 2.0)
		c.line(p - Vector2(20, 0), p + Vector2(20, 0), Color.BLACK, 2.0)
		c.line(p - Vector2(0, 20), p + Vector2(0, 20), Color.BLACK, 2.0)


func _build_a() -> void:
	var s := _sheet_a
	# blue keyline: rules, marks, a quarter circle
	var blue := _plate(s, BLUE, 11.0)
	var bc := MotionCanvas.new()
	bc.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		_marks(c)
		c.rect(Rect2(160, 756, 1640, 7), Color.BLACK)
		c.rect(Rect2(745, 130, 5, 626), Color.BLACK)
		c.circle(Vector2(1860, 40), 300, Color.BLACK)
	blue.content.add_child(bc)
	_a.blue = blue
	# blue tint: the huge 01
	var tone := _plate(s, BLUE, 12.0, 11.0, 15.0)
	tone.tone_scale = 0.5
	var n := _text(tone.content, INTER9, 600, "01", Vector2.ZERO, -0.04)
	n.position = Vector2(1830 - n.get_text_size().x, 1000 - n.get_baseline())
	_a.tone = tone
	# red: the M's back layer, knocked out by the amber and cream layers
	var m_pos := PANEL.position + (PANEL.size - Vector2(M_W, M_W * M_CROP.size.y / M_CROP.size.x)) * 0.5
	var red := _plate(s, RED, 13.0)
	var rs := _svg(red.content, _mh_svg, [0, 1, 2], M_W, m_pos, M_CROP)
	rs.apply(func(i: int) -> Variant: return {fill = Color.BLACK if i == 0 else Color.WHITE})
	_a.red = red
	# amber: the middle layer, knocked out by the cream layer
	var amber := _plate(s, AMBER, 14.0)
	var as_ := _svg(amber.content, _mh_svg, [1, 2], M_W, m_pos, M_CROP)
	as_.apply(func(i: int) -> Variant: return {fill = Color.BLACK if i == 1 else Color.WHITE})
	_a.amber = amber
	# black: the panel with the whole M knocked out, the wordmark, the columns
	var black := _plate(s, BLACK, 15.0)
	_rect(black.content, PANEL)
	var ko := _svg(black.content, _mh_svg, [0, 1, 2], M_W, m_pos, M_CROP)
	ko.apply(func(_i: int) -> Variant: return {fill = Color.WHITE})
	var wm := _svg(black.content, _mh_svg, range(3, 16), WORD_W, WORD_POS, WORD_CROP)
	wm.apply(func(_i: int) -> Variant: return {fill = Color.BLACK})
	var cols := [
		[160.0, "MINIMAL HUMANS\nFOSS STUDIO\nBERLIN 52.52N 13.34E"],
		[470.0, "PRINT RUN 01 / 100\nRISO // FIVE INKS\nBLUE RED AMBER BLACK PINK"],
		[870.0, "100 BPM\n4/4 // 72 FRAMES A BAR\nSHEET A"],
	]
	for col in cols:
		var t := _text(black.content, INTER7, 22, col[1], Vector2(col[0], 790), 0.04)
		t.line_height = 1.45
	_text(black.content, INTER7, 30, "ミニマル・ヒューマンズ", Vector2(160, 700))
	_a.black = black
	# lime band (the M panel knocked out of it)
	var lime := _plate(s, LIME, 16.0)
	_rect(lime.content, Rect2(60, 590, 1800, 100))
	_rect(lime.content, PANEL, Color.WHITE)
	_a.lime = lime
	# pink: PRESENTS
	var pink := _plate(s, PINK, 17.0)
	_text(pink.content, INTER9, 64, "PRESENTS", Vector2(800, 600), 0.32)
	_text(pink.content, INTER9, 64, "提供", Vector2(1370, 598))
	_a.pink = pink


func _build_b() -> void:
	var s := _sheet_b
	var blue := _plate(s, BLUE, 21.0)
	var bc := MotionCanvas.new()
	bc.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		_marks(c)
		c.rect(Rect2(160, 636, 1640, 7), Color.BLACK)
		c.rect(Rect2(160, 110, 5, 440), Color.BLACK)
		c.circle(Vector2(60, 1040), 300, Color.BLACK)
	blue.content.add_child(bc)
	_b.blue = blue
	# blue tint: the logo's halftone drop shadow (the logo itself knocked out) and 9000
	var tone := _plate(s, BLUE, 22.0, 11.0, 15.0)
	tone.tone_scale = 0.55
	var sh := _svg(tone.content, _ftf_svg, [0, 1], LOGO_W, LOGO_POS + Vector2(34, 30))
	sh.apply(func(_i: int) -> Variant: return {fill = Color.BLACK})
	var n := _text(tone.content, INTER9, 410, "9000", Vector2.ZERO, -0.05)
	n.position = Vector2(1830 - n.get_text_size().x, 1000 - n.get_baseline())
	var ko := _svg(tone.content, _ftf_svg, [0, 1], LOGO_W, LOGO_POS)
	ko.apply(func(_i: int) -> Variant: return {fill = Color.WHITE})
	_b.tone = tone
	# pink: the logo; its white parts knock out to paper
	var pink := _plate(s, PINK, 23.0)
	var logo := _svg(pink.content, _ftf_svg, [], LOGO_W, LOGO_POS)
	logo.apply(func(i: int) -> Variant:
		var c: Color = logo.data.parts[i].fill
		return {fill = Color.BLACK if c.g < 0.5 else Color.WHITE})
	_b.pink = pink
	# lime band behind the logo
	var lime := _plate(s, LIME, 24.0)
	_rect(lime.content, Rect2(60, 250, 1800, 160))
	var lko := _svg(lime.content, _ftf_svg, [0, 1], LOGO_W, LOGO_POS)
	lko.apply(func(_i: int) -> Variant: return {fill = Color.WHITE})
	_b.lime = lime
	# black: type
	var black := _plate(s, BLACK, 25.0)
	_text(black.content, INTER7, 24, "F-9000 // ANTI-GRAVITY LEAGUE", Vector2(180, 98), 0.08)
	var r := _text(black.content, INTER7, 24, "SEASON 01 // SHEET B", Vector2.ZERO, 0.08)
	r.position = Vector2(1760 - r.get_text_size().x, 98)
	_text(black.content, INTER9, 58, "フルスロットル・フラックス", Vector2(300, 524))
	var cols := [
		[180.0, "FULL THROTTLE FLUX\nANTI-GRAVITY RACING\nGODOT 4.5 // FORWARD+"],
		[520.0, "CLASSES\nSPARROW // STARLING\nKESTREL\n\nPRINT RUN 01 / 100\n100 BPM // 4/4"],
	]
	for col in cols:
		var t := _text(black.content, INTER7, 22, col[1], Vector2(col[0], 676), 0.04)
		t.line_height = 1.45
	_b.black = black
	# the approval stamp: red, rough, pressed by hand
	var stamp := _plate(s, RED, 26.0)
	stamp.roughness = 3.0
	stamp.grain = 0.8
	stamp.mottle = 0.55
	stamp.roll_shadow = 0.0
	_stamp_pivot = Node2D.new()
	_stamp_pivot.position = Vector2(1530, 560)
	_stamp_pivot.rotation = deg_to_rad(-13.0)
	stamp.content.add_child(_stamp_pivot)
	var sc := MotionCanvas.new()
	sc.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		c.ring(Vector2.ZERO, 122, Color.BLACK, 9.0)
		c.ring(Vector2.ZERO, 100, Color.BLACK, 3.0)
	_stamp_pivot.add_child(sc)
	var k := _text(_stamp_pivot, INTER9, 84, "認可", Vector2.ZERO)
	k.position = -k.get_text_size() * 0.5 - Vector2(0, 14)
	var ok := _text(_stamp_pivot, INTER9, 18, "OK TO PRINT", Vector2.ZERO, 0.18)
	ok.position = Vector2(-ok.get_text_size().x * 0.5, 40)
	_b.stamp = stamp
	# the flood: black over the whole sheet
	var flood := _plate(s, BLACK, 27.0)
	flood.grain = 0.0
	flood.mottle = 0.0
	flood.roughness = 0.0
	flood.roll_shadow = 0.8
	flood.roll_soft = 50.0
	flood.roll_dir = Vector2(-1, 0)
	_rect(flood.content, PAPER_RECT.grow(4))
	_b.flood = flood


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_riso/audio/riso_map.tres"
	const SONG := "res://demo/ftf/ftf_riso/audio/music/riso_song.tres"
	const TRACK := "res://demo/ftf/ftf_riso/audio/riso_track.res"
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


# ================================================================== frame

## Press vibration on twos while the plates are off register, so the build lives.
func _shiver(f: float, settle: float, k: float) -> Vector2:
	if f >= settle:
		return Vector2.ZERO
	var t := floorf(f / 2.0)
	return Vector2(MK.rand(t * 3.1 + k) - 0.5, MK.rand(t * 5.7 + k * 2.0) - 0.5) * 3.0


## One plate: printed by the roller from `at`, off register by `err` / `rot`
## until `settle`.
func _print(p: MotionPlate, f: float, at: float, dir: Vector2, err: Vector2, rot: float, settle: float, k: float) -> void:
	p.visible = f >= at
	if not p.visible:
		return
	p.roll = MotionPlate.print_in(f, at, ROLL)
	p.roll_dir = dir
	p.misregister = MotionPlate.register(f, settle, err, 3.0) + _shiver(f, settle, k)
	p.misrotate = rot * MotionPlate.register(f, settle, Vector2(1, 0), 3.0).x


func _frame(f: float) -> void:
	if not _built:
		return
	var hits := [A_BLUE, A_RED, A_AMBER, A_BLACK, A_LIME, A_PINK, B_BLUE, B_PINK, B_LIME, B_BLACK]
	_stage.position = MotionPlate.thunk(f, hits, 3.0, 6.0) + MotionPlate.thunk(f, [A_SNAP, B_SNAP, STAMP], 7.0, 8.0) \
		+ MotionPlate.thunk(f, [END_HIT], 9.0, 10.0)
	_frame_a(f)
	_frame_b(f)


func _frame_a(f: float) -> void:
	# feed in from the right, pulled out to the left
	var feed := MK.map(f, [FEED_A, FEED_A + 14], [0, 1], MK.ease_out)
	var out := MK.map(f, [SHEET_CHANGE, SHEET_CHANGE + 20], [0, 1], MK.ease_in_quad)
	_sheet_a.visible = out < 1.0
	if not _sheet_a.visible:
		return
	_sheet_a.position = Vector2((1.0 - feed) * 1960.0 - out * 2050.0, out * 30.0)
	_sheet_a.rotation = deg_to_rad(-out * 2.5)
	_print(_a.blue, f, A_BLUE, Vector2(1, 0), Vector2.ZERO, 0.0, A_SNAP, 1.0)
	_print(_a.tone, f, A_BLUE, Vector2(1, 0), Vector2.ZERO, 0.0, A_SNAP, 1.0)
	_print(_a.red, f, A_RED, Vector2(0, 1), Vector2(24, -13), 0.6, A_SNAP, 2.0)
	_print(_a.amber, f, A_AMBER, Vector2(-1, 0), Vector2(-17, 19), -0.4, A_SNAP, 3.0)
	_print(_a.black, f, A_BLACK, Vector2(1, 0), Vector2(11, 7), 0.25, A_SNAP, 4.0)
	_print(_a.lime, f, A_LIME, Vector2(0, -1), Vector2(-6, 16), 0.0, A_SNAP, 5.0)
	_print(_a.pink, f, A_PINK, Vector2(1, 0), Vector2.ZERO, 0.0, A_SNAP, 6.0)


func _frame_b(f: float) -> void:
	var feed := MK.map(f, [SHEET_CHANGE, B_BLUE], [0, 1], MK.ease_out)
	_sheet_b.visible = f >= SHEET_CHANGE and f < CLEAR
	if not _sheet_b.visible:
		return
	_sheet_b.position = Vector2((1.0 - feed) * 1960.0, 0)
	_print(_b.blue, f, B_BLUE, Vector2(1, 0), Vector2.ZERO, 0.0, B_SNAP, 11.0)
	_print(_b.tone, f, B_BLUE, Vector2(1, 0), Vector2.ZERO, 0.0, B_SNAP, 11.0)
	_print(_b.pink, f, B_PINK, Vector2(-1, 0), Vector2(-74, -40), -1.7, B_SNAP, 12.0)
	_print(_b.lime, f, B_LIME, Vector2(0, 1), Vector2(8, 28), 0.3, B_SNAP, 13.0)
	_print(_b.black, f, B_BLACK, Vector2(1, 0), Vector2(15, -10), 0.35, B_SNAP, 14.0)
	# the pink plate slams: a doubled ghost as it lands, settling to one image
	var slam := MK.map(f, [B_PINK, B_PINK + 8], [1, 0], MK.ease_out)
	(_b.pink as MotionPlate).slur = Vector2(-18, -9)
	(_b.pink as MotionPlate).slur_amount = 0.55 * slam
	# hold: the blue screen turns slowly, so its dots shimmer against the paper
	var hold := maxf(0.0, f - B_SNAP)
	(_b.tone as MotionPlate).angle_deg = 15.0 + hold * 0.09
	# a second, slurred impression of the lime plate
	var lime := _b.lime as MotionPlate
	lime.slur = Vector2(10, 4)
	lime.slur_amount = MK.map(f, [SLUR, SLUR + 3], [0, 0.85], MK.linear)
	# the approval stamp: pressed down hard, ink laid in two frames
	var stamp := _b.stamp as MotionPlate
	stamp.visible = f >= STAMP
	if stamp.visible:
		stamp.roll = 1.0
		stamp.density = MK.map(f, [STAMP, STAMP + 2], [0.0, 0.92], MK.linear)
		_stamp_pivot.scale = Vector2.ONE * lerpf(1.14, 1.0, MK.map(f, [STAMP, STAMP + 3], [0, 1], MK.ease_out))
	# the flood
	var flood := _b.flood as MotionPlate
	flood.visible = f >= FLOOD
	if flood.visible:
		flood.roll = MK.map(f, [FLOOD, END_HIT], [0, 1], MK.ease_in_out)
