# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — boot intro: "Minimal Humans presents", then the FTF logo.
#
# Brief: 14 s at 150 bpm (12 frames a beat, 48 a bar), Wipeout / Designers
# Republic / neo-futurist. Three acts on the bar grid:
#   I   MINIMAL HUMANS, in the studio's own cream / amber / red. A boot rule draws,
#       the M monogram's three layers drop and stack, the wordmark pops up letter by
#       letter, supergraphic discs land, PRESENTS settles. Then it starts to break:
#       glitch hits on the off-beats recolour it in FTF acid (pink, lime, lilac),
#       harder each time, until it tears apart on the downbeat of bar 2.
#   II  LIVERY. A five-colour stripe bundle sweeps across; three full-frame team
#       liveries cut on the beat (SPARROW S07 lime, STARLING T23 lilac, KESTREL K45
#       black/orange); the last shrinks into a 3x2 team-registry wall that pops
#       in on sixteenths. A pink iris swallows the wall; half a beat of black.
#   III LOGO. On the drop the plate slams in with a flash; "Full Throttle" drops
#       letter by letter; the pink tab slides under and FLUX's halves smash
#       together on beat 3; the checker flag pops on sixteenths. An acid HUD builds
#       around it on eighths (rounded ribbons, pills, X boxes, crosshairs,
#       chevrons, barcode, katakana). It holds with everything crawling, glitching
#       on two accents, then the HUD pops away, the logo flattens into a pink
#       line, shrinks to a dot, and the dot blips out on the final hit. Black to
#       the end so the game can cut straight to the menu.
#
# Beats (30 fps, 420 frames; b = beat, 12 frames):
#   0       boot rule + microtype
#   6-18    M layers fall in, landing on 12/15/18 (red, amber, cream)
#   24-43   wordmark letters pop
#   36/39/42  discs land
#   48      PRESENTS rule; tracking settles
#   78/84/90/93  glitch hits, growing
#   96      tear: full glitch; stripe bundle sweeps (96-106)
#   108/120/132  liveries S07, T23, K45 cut in
#   144     K45 shrinks into the wall; 148-160 tiles pop on sixteenths
#   180     pink iris; 186 black; 186 riser peak
#   192     DROP: plate slams, flash, shake
#   194-211 "Full Throttle" letters drop
#   216     FLUX halves smash; tab lands
#   222-231 checker squares pop on sixteenths
#   240-264 small type, HUD pops on eighths
#   264-336 hold (crawl); glitch accents 288, 324
#   336-350 HUD out; 348 logo flattens; 360 line shrinks; 372/378 dot pulses;
#           384 dot blips out
#   390-420 black
#
# Sound: the cue sheet in _init. With the Godot Audio Kit linked
# (tools/link_audio_kit.sh) an AKCueBridge scores it from demo/ftf/audio/
# (recipes, cue map and a 150 bpm breakbeat song); without it the committed
# baked track plays. Music can be replaced by any track at 150 bpm with its
# first downbeat at 0.0 s: bars land on frames 0, 48, 96 ... 384.
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0

# ---- Act I
const BOOT := 0.0
const LAYERS := [12.0, 15.0, 18.0]
const LETTERS_AT := 24.0
const DISCS := [36.0, 39.0, 42.0]
const PRESENTS := 48.0
const GLITCH_HITS := [78.0, 84.0, 90.0, 93.0]
const TEAR := 96.0
# ---- Act II
const SWEEP := 96.0
const PANELS := [108.0, 120.0, 132.0]
const WALL := 144.0
const TILES := [148.0, 151.0, 154.0, 157.0, 160.0]
const IRIS := 180.0
const GAP := 186.0
# ---- Act III
const DROP := 192.0
const WORD_AT := 194.0
const TAB_AT := 210.0
const FLUX_AT := 216.0
const CHECK_AT := [222.0, 225.0, 228.0, 231.0]
const SMALL_AT := 240.0
const HUD_AT := [240.0, 246.0, 252.0, 258.0, 264.0]
const HOLD := 264.0
const ACCENTS := [288.0, 324.0]
const OUT := 336.0
const COLLAPSE := 348.0
const SHRINK := 360.0
const BLIP := 384.0
const END := 420

# ---- layout
const MH_W := 1200.0
const MH_POS := Vector2(360, 300)
const LOGO_W := 1400.0
const LOGO_C := Vector2(960, 520)
const TILE_S := 0.275                     # card scale on the wall (528 x 297)
const WALL_ORIGIN := Vector2(132, 225)
const WALL_STEP := Vector2(564, 333)

var _built := false
var _stage: Node2D
# Act I
var _a1: MotionFX
var _a1_bg: ColorRect
var _a1_canvas: MotionCanvas
var _mh: MotionSvg
var _mh_k := 1.0
var _boot_l: MotionText
var _boot_r: MotionText
var _presents: MotionText
var _presents_jp: MotionText
# Act II
var _a2: Node2D
var _wall_bg: ColorRect
var _wall_text: Array[MotionText] = []
var _wall_canvas: MotionCanvas
var _cards: Array[Node2D] = []
var _card_texts: Array = []           # per card: {code, name, jp, micro}
var _sweep: MotionCanvas
var _iris: MotionShape
# Act III
var _a3: MotionFX
var _a3_back: MotionCanvas
var _logo_pivot: Node2D
var _logo: MotionSvg
var _logo_k := 1.0
var _hud: MotionCanvas
var _hud_texts: Array[Node2D] = []    # pivots, popped in order
var _hud_at: Array[float] = []
var _dot: MotionCanvas
var _flash: ColorRect


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": HOLD, "out": OUT}
	# The cue sheet: one number per moment, shared with the picture below.
	cue(BOOT, &"boot.rule", 0.5)
	for i in LAYERS.size():
		cue(LAYERS[i], &"mh.layer", 0.6 + 0.15 * i, {pitch = [0.84, 1.0, 1.19][i]})
	cue(LETTERS_AT, &"mh.letters", 0.6)
	for i in DISCS.size():
		cue(DISCS[i], &"mh.disc", 0.55 + 0.1 * i, {pitch = [1.0, 1.12, 1.26][i]})
	cue(PRESENTS, &"mh.presents", 0.8)
	for i in 3:   # the fourth hit sits under the sweep's attack: picture only
		cue(GLITCH_HITS[i], &"glitch", 0.45 + 0.15 * i, {pitch = [1.0, 0.9, 1.1][i]})
	cue(TEAR, &"glitch.tear", 1.0)
	cue(SWEEP - 2.0, &"sweep", 0.9)
	for i in PANELS.size():
		cue(PANELS[i], &"panel", 0.85 + 0.075 * i, {pitch = [1.0, 1.12, 1.26][i]})
	cue(WALL, &"wall", 0.7)
	for i in TILES.size():
		cue(TILES[i], &"tile", 0.6, {pitch = [1.0, 1.12, 1.26, 1.5, 1.68][i]})
	cue(IRIS, &"iris", 0.8)
	cue(GAP, &"riser", 1.0)          # its recipe swells in ahead and peaks here
	cue(DROP, &"drop", 1.0)
	cue(WORD_AT, &"letters", 0.8)
	cue(TAB_AT, &"tab", 0.7)
	cue(FLUX_AT, &"flux", 1.0)
	for i in CHECK_AT.size():
		cue(CHECK_AT[i], &"check", 0.6 + 0.1 * i, {pitch = [1.0, 1.19, 1.5, 2.0][i]})
	cue(SMALL_AT + 3.0, &"type", 0.5)   # just after the first HUD blip
	for i in HUD_AT.size():
		cue(HUD_AT[i], &"hud", 0.5 + 0.08 * i, {pitch = [1.0, 1.12, 1.26, 1.5, 1.68][i]})
	for i in ACCENTS.size():
		cue(ACCENTS[i], &"glitch", 0.8 - 0.2 * i, {pitch = [1.2, 0.85][i]})
	cue(OUT, &"hud.out", 0.7)
	cue(COLLAPSE, &"collapse", 0.9)
	cue(SHRINK, &"zip", 0.8)
	cue(BLIP, &"blip", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = FTFKit.INK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_build_act1()
	_build_act2()
	_build_act3()
	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = FTFKit.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_add_sound()


func _build_act1() -> void:
	_a1 = MotionFX.new()
	_a1.size = size
	_stage.add_child(_a1)
	_a1_bg = ColorRect.new()
	_a1_bg.size = size
	_a1_bg.color = FTFKit.MH_INK
	_a1.content.add_child(_a1_bg)
	_a1_canvas = MotionCanvas.new()
	_a1_canvas.draw_fn = _draw_act1
	_a1.content.add_child(_a1_canvas)
	_mh = MotionSvg.new()
	_mh.data = _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh.width = MH_W
	_mh.position = MH_POS
	_a1.content.add_child(_mh)
	_mh_k = MH_W / _mh.data.view_box.size.x
	_boot_l = FTFKit.text(_a1.content, "mono", 22, FTFKit.MH_CREAM, "MINIMAL HUMANS // FOSS STUDIO // BERLIN 52.52N 13.34E", 0.12)
	_boot_l.position = Vector2(120, 868)
	_boot_r = FTFKit.text(_a1.content, "mono", 22, FTFKit.MH_AMBER, "BOOT SEQ 01 // OK", 0.12)
	_boot_r.position = Vector2(1560 - _boot_r.get_text_size().x, 868)
	_presents = FTFKit.text(_a1.content, "heavy", 54, FTFKit.MH_CREAM, "PRESENTS", 0.42)
	_presents.position = Vector2(MH_POS.x + 145.0 * _mh_k, MH_POS.y + 128.9 * _mh_k + 58.0)
	_presents_jp = FTFKit.text(_a1.content, "jp", 30, FTFKit.MH_AMBER, "ミニマル・ヒューマンズ　提供")
	_presents_jp.position = Vector2(MH_POS.x + 145.0 * _mh_k + 1060.0 - _presents_jp.get_text_size().x, _presents.position.y + 16.0)


func _build_act2() -> void:
	_a2 = Node2D.new()
	_stage.add_child(_a2)
	_wall_bg = ColorRect.new()
	_wall_bg.size = size
	_wall_bg.color = FTFKit.CREAM
	_a2.add_child(_wall_bg)
	_wall_canvas = MotionCanvas.new()
	_wall_canvas.draw_fn = _draw_wall
	_a2.add_child(_wall_canvas)
	var h1 := FTFKit.text(_a2, "mono", 26, FTFKit.INK, "F-9000 // TEAM REGISTRY // ANTI-GRAVITY LEAGUE", 0.14)
	h1.position = Vector2(WALL_ORIGIN.x, 150)
	var h2 := FTFKit.text(_a2, "jp", 30, FTFKit.PINK, "反重力レース　第一")
	h2.position = Vector2(W - WALL_ORIGIN.x - h2.get_text_size().x, 144)
	var f1 := FTFKit.text(_a2, "mono", 22, FTFKit.INK, "SEASON 01 // 06 TEAMS // CLASSES: SPARROW · STARLING · KESTREL", 0.12)
	f1.position = Vector2(WALL_ORIGIN.x, 908)
	_wall_text = [h1, h2, f1]
	var specs := [
		{bg = FTFKit.LIME, fg = FTFKit.INK, code = "S07", name = "SPARROW", jp = "スパロー", micro = "CLASS 01 / ALL-ROUNDER\nAG MASS 0.82 T\nSPD 7 ACC 7 HDL 7"},
		{bg = FTFKit.LILAC, fg = FTFKit.CREAM, code = "T23", name = "STARLING", jp = "スターリング", micro = "CLASS 02 / ACCELERATION\nAG MASS 0.74 T\nSPD 8 ACC 9 HDL 6"},
		{bg = FTFKit.INK, fg = FTFKit.ORANGE, code = "K45", name = "KESTREL", jp = "ケストレル", micro = "CLASS 03 / TOP SPEED\nAG MASS 0.91 T\nSPD 10 ACC 6 HDL 5"},
		{bg = FTFKit.PINK, fg = FTFKit.WHITE, code = "F01", name = "FLUX WORKS", jp = "フラックス", micro = "WORKS TEAM\nMINIMAL HUMANS\nBERLIN"},
		{bg = FTFKit.WHITE, fg = FTFKit.INK, code = "A04", name = "ARCLIGHT", jp = "全開", micro = "PRIVATEER\nAG MASS 0.79 T"},
		{bg = FTFKit.ORANGE, fg = FTFKit.INK, code = "B79", name = "BOREAL", jp = "反重力", micro = "PRIVATEER\nAG MASS 0.88 T"},
	]
	for i in specs.size():
		_cards.append(_make_card(i, specs[i]))
	_sweep = MotionCanvas.new()
	_sweep.draw_fn = _draw_sweep
	_stage.add_child(_sweep)
	_iris = MotionShape.circle(10, FTFKit.PINK)
	_stage.add_child(_iris)


## A full-frame livery (1920 x 1080, origin at its centre). Scaled to TILE_S it
## becomes a tile on the wall, so the zoom out is a literal scale.
func _make_card(i: int, spec: Dictionary) -> Node2D:
	var card := Node2D.new()
	card.position = Vector2(W, H) * 0.5
	_a2.add_child(card)
	var bg := ColorRect.new()
	bg.color = spec.bg
	bg.position = Vector2(-W, -H) * 0.5
	bg.size = Vector2(W, H)
	bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW   # tiles keep their graphics inside
	card.add_child(bg)
	var inner := Node2D.new()
	inner.position = Vector2(W, H) * 0.5
	bg.add_child(inner)
	var c := MotionCanvas.new()
	c.draw_fn = func(cv: MotionCanvas, f: float) -> void: _draw_card(cv, f, i, spec)
	inner.add_child(c)
	var fg: Color = spec.fg
	var code := FTFKit.text(inner, "wide", 430, fg, spec.code, -0.02)
	code.position = Vector2(-890, 520 - code.get_text_size().y)
	var name := FTFKit.text(inner, "ext", 58, fg, spec.name, 0.28)
	name.position = Vector2(-880, -250)
	var jp := FTFKit.text(inner, "jp", 92, fg, spec.jp)
	jp.position = Vector2(-884, -385)
	var micro := FTFKit.text(inner, "mono", 30, fg, spec.micro, 0.08)
	micro.line_height = 1.35
	micro.position = Vector2(440, 300)
	_card_texts.append({code = code, name = name, jp = jp, micro = micro})
	return card


func _build_act3() -> void:
	_a3 = MotionFX.new()
	_a3.size = size
	_stage.add_child(_a3)
	_a3_back = MotionCanvas.new()
	_a3_back.draw_fn = _draw_act3_back
	_a3.content.add_child(_a3_back)
	_logo_pivot = Node2D.new()
	_logo_pivot.position = LOGO_C
	_a3.content.add_child(_logo_pivot)
	_logo = MotionSvg.new()
	_logo.data = _svg(FTFKit.LOGO)
	_logo.width = LOGO_W
	_logo_k = LOGO_W / _logo.data.view_box.size.x
	_logo.position = -_logo.data.view_box.size * _logo_k * 0.5
	_logo_pivot.add_child(_logo)
	_hud = MotionCanvas.new()
	_hud.draw_fn = _draw_hud
	_a3.content.add_child(_hud)
	# HUD type, each in a pivot so it pops in place: [node, at, centre]
	var p1 := FTFKit.pill(_a3.content, "F-9000 // ANTI-GRAVITY LEAGUE", FTFKit.LIME, FTFKit.INK, 24)
	_hud_item(p1, HUD_AT[1], Vector2(330, 120), Vector2.ZERO)
	var micro := FTFKit.text(_a3.content, "mono4", 20, FTFKit.STONE, "REV 03.10 // BUILD 0.9.150\nTRACK: UTOPIA // LAP 0/3\nGRAV 0.00 G // AG FIELD OK", 0.1)
	micro.line_height = 1.4
	_hud_item(micro, HUD_AT[2], Vector2(88 + micro.get_text_size().x * 0.5, 230), micro.get_text_size() * 0.5)
	var p2 := FTFKit.pill(_a3.content, "CLASS: SPARROW", FTFKit.PINK, FTFKit.WHITE, 24)
	_hud_item(p2, HUD_AT[1], Vector2(1450, 790), Vector2.ZERO)
	var p3 := FTFKit.pill(_a3.content, "SEASON 01", FTFKit.CYAN, FTFKit.INK, 24)
	_hud_item(p3, HUD_AT[2], Vector2(1700, 790), Vector2.ZERO)
	var jp := FTFKit.text(_a3.content, "jp", 54, FTFKit.WHITE, "フルスロットル・フラックス")
	_hud_item(jp, HUD_AT[3], Vector2(132 + jp.get_text_size().x * 0.5, 930), jp.get_text_size() * 0.5)
	var jpv := FTFKit.text(_a3.content, "jp", 40, FTFKit.LIME, "反重力レース")
	jpv.vertical = true
	jpv.box_width = 600
	_hud_item(jpv, HUD_AT[3], Vector2(1838, 420), jpv.get_text_size() * 0.5)
	var hex := FTFKit.text(_a3.content, "mono", 22, FTFKit.PINK, "#E92067 // #D7FF1F // #A98BFF", 0.1)
	_hud_item(hex, HUD_AT[4], Vector2(1260 - hex.get_text_size().x * 0.5, 1030), hex.get_text_size() * 0.5)
	var bpm := FTFKit.text(_a3.content, "mono", 22, FTFKit.STONE, "150 BPM // 4/4", 0.1)
	_hud_item(bpm, HUD_AT[4], Vector2(132 + bpm.get_text_size().x * 0.5, 1030), bpm.get_text_size() * 0.5)
	_dot = MotionCanvas.new()
	_dot.draw_fn = _draw_dot
	_stage.add_child(_dot)


func _hud_item(n: Node2D, at: float, centre: Vector2, half: Vector2) -> void:
	var p := FTFKit.centred(_a3.content, n, centre, half)
	_hud_texts.append(p)
	_hud_at.append(at)


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/audio/ftf_map.tres"
	const SONG := "res://demo/ftf/audio/music/ftf_song.tres"
	const TRACK := "res://demo/ftf/audio/ftf_intro_track.res"
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

## 0..1 glitch strength for act I (the off-beat hits, then the tear).
func _glitch1(f: float) -> float:
	for i in GLITCH_HITS.size():
		var at: float = GLITCH_HITS[i]
		var len := [2.0, 3.0, 2.0, 3.0][i] as float
		if f >= at and f < at + len:
			return 0.45 + 0.15 * i
	if f >= TEAR and f < TEAR + 10.0:
		return 1.0
	return 0.0


## Act III glitch accents (two frames each).
func _glitch3(f: float) -> float:
	for i in ACCENTS.size():
		var at: float = ACCENTS[i]
		if f >= at and f < at + 3.0:
			return 1.0 - 0.3 * i
	return 0.0


func _pop(f: float, at: float, damping := 11.0, stiffness := 220.0) -> float:
	return maxf(0.0, MK.spring(f, at, damping, stiffness))


## Which acid colour a glitched frame swaps a brand colour to.
func _acid(f: float, idx: int) -> Color:
	var sets := [[FTFKit.LIME, FTFKit.PINK, FTFKit.LILAC], [FTFKit.PINK, FTFKit.LIME, FTFKit.INK], [FTFKit.LILAC, FTFKit.INK, FTFKit.LIME], [FTFKit.INK, FTFKit.LILAC, FTFKit.PINK]]
	var s: Array = sets[int(MK.rand(floorf(f) * 1.7 + 3.0) * 4.0) % 4]
	return s[idx % 3]


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	_stage.position = MK.shakes(f, [DROP, FLUX_AT], 22, 9) + MK.shakes(f, PANELS + [TEAR], 9, 6)
	_frame_act1(f)
	_frame_act2(f)
	_frame_act3(f)
	# white flash on the drop and on FLUX
	var fl := maxf(1.0 - MK.map(f, [DROP, DROP + 5], [0, 1], MK.linear), 0.0) if f >= DROP else 0.0
	fl = maxf(fl, (0.55 - MK.map(f, [FLUX_AT, FLUX_AT + 4], [0, 0.55], MK.linear)) if f >= FLUX_AT else 0.0)
	_flash.visible = fl > 0.01
	_flash.color.a = fl * 0.9


func _frame_act1(f: float) -> void:
	_a1.visible = f < SWEEP + 12.0
	if not _a1.visible:
		return
	var g := _glitch1(f)
	var tear := MK.map(f, [TEAR, TEAR + 10], [0, 1], MK.linear) if f >= TEAR else 0.0
	_a1.set_slices(g * 140.0 + tear * 260.0, g * 24.0 + tear * 30.0, 22, floorf(f))
	_a1.invert = 1.0 if (g > 0.6 and int(f) % 2 == 0) else 0.0
	_a1_bg.color = _acid(f, 1) if g > 0.0 else FTFKit.MH_INK
	_a1.modulate.a = 1.0 - MK.map(f, [TEAR + 6, TEAR + 12], [0, 1], MK.linear)

	# M layers drop in one after another and stack; letters pop up from the baseline.
	_mh.apply(func(i: int) -> Variant:
		if i <= 2:
			var at: float = LAYERS[i]          # red (0) is the back layer: first in, cream lands last on top
			if f < at - 6.0:
				return {hide = true}
			# falls in over six frames and lands on its cue, then a small rebound
			var t := MK.map(f, [at - 6.0, at], [0, 1], MK.ease_in_quad)
			var rebound := 16.0 * exp(-(f - at) * 0.4) * absf(sin((f - at) * 0.8)) if f >= at else 0.0
			var fan := (1.0 - MK.spring(f, LAYERS[2] + 2.0, 9, 140)) * (2 - i) * 9.0
			var d := {ty = (1.0 - t) * -420.0 - rebound - fan, tx = -fan}
			if g > 0.0:
				d.fill = _acid(f, i)
			return d
		var k := i - 3
		var at2 := LETTERS_AT + k * 1.5
		if f < at2:
			return {hide = true}
		var p: Dictionary = _mh.data.parts[i]
		var bb: Rect2 = p.bbox
		var s2 := MK.spring(f, at2, 9, 240)
		var d2 := {sy = s2, sx = lerpf(0.6, 1.0, minf(1.0, s2)), pivot = Vector2(bb.get_center().x, bb.end.y)}
		if g > 0.0:
			d2.fill = _acid(f, 0)
		return d2)

	_boot_l.visible_chars = int(MK.map(f, [BOOT + 2, BOOT + 26], [0, 54], MK.linear))
	_boot_r.modulate.a = MK.prog(f, BOOT + 20, 6)
	_boot_l.color = _acid(f, 2) if g > 0.0 else FTFKit.MH_CREAM
	var pr := MK.prog(f, PRESENTS + 4, 22)
	_presents.visible = f >= PRESENTS + 4
	_presents.tracking = lerpf(0.9, 0.42, pr)
	_presents.modulate.a = minf(1.0, pr * 3.0)
	_presents.color = _acid(f, 0) if g > 0.0 else FTFKit.MH_CREAM
	_presents_jp.visible = f >= PRESENTS + 10
	_presents_jp.visible_chars = int(MK.map(f, [PRESENTS + 10, PRESENTS + 20], [0, 14], MK.linear))


func _draw_act1(c: MotionCanvas, f: float) -> void:
	var g := _glitch1(f)
	var cream := _acid(f, 0) if g > 0.0 else FTFKit.MH_CREAM
	var amber := _acid(f, 1) if g > 0.0 else FTFKit.MH_AMBER
	var red := _acid(f, 2) if g > 0.0 else FTFKit.MH_RED
	var blue := _acid(f, 0) if g > 0.0 else FTFKit.MH_BLUE
	# boot rule: draws out from the centre with ticks
	var rw := MK.map(f, [BOOT, BOOT + 10], [0, 840], MK.ease_out)
	c.line(Vector2(960 - rw, 850), Vector2(960 + rw, 850), cream, 2.0, 0.8)
	for i in 29:
		var x := 960.0 + (i - 14) * 60.0
		if absf(x - 960.0) <= rw:
			c.line(Vector2(x, 850), Vector2(x, 842 if i % 7 else 830), cream, 2.0, 0.8)
	MotionMarks.plus(c, Vector2(120, 960), 14, cream, 2.0, MK.prog(f, BOOT + 4, 6))
	MotionMarks.plus(c, Vector2(1800, 120), 14, cream, 2.0, MK.prog(f, BOOT + 6, 6))
	# supergraphic discs (studio colours), springing in on the beat
	var s0 := _pop(f, DISCS[0], 10, 170)
	var s1 := _pop(f, DISCS[1], 10, 170)
	var s2 := _pop(f, DISCS[2], 10, 170)
	var drift := sin(f / 14.0) * 6.0
	if s0 > 0.0:
		c.circle(Vector2(150, 40 + drift), 210.0 * s0, amber)
	if s1 > 0.0:
		var pc := Vector2(1500, 150 - drift)
		var hw := 134.0 * s1
		var hh := 46.0 * s1
		c.rect(Rect2(pc - Vector2(hw, hh), Vector2(hw, hh) * 2.0), blue)
		c.circle(pc - Vector2(hw, 0), hh, blue)
		c.circle(pc + Vector2(hw, 0), hh, blue)
	if s2 > 0.0:
		for k in 4:
			c.ring(Vector2(1770, 1000), (40.0 + k * 34.0) * s2, red, 12.0)
	# PRESENTS rule
	var pw := MK.map(f, [PRESENTS, PRESENTS + 12], [0, 1060], MK.ease_in_out)
	if pw > 0.0:
		c.rect(Rect2(MH_POS.x + 145.0 * _mh_k, MH_POS.y + 128.9 * _mh_k + 34.0, pw, 6), amber)
	# glitch: acid blocks punched across the frame
	if g > 0.0:
		for k in int(4 + g * 10):
			var rr := MK.rand(floorf(f) * 9.1 + k * 4.7)
			var rect := Rect2(rr * 1800.0, MK.rand(rr * 77.0 + k) * 1000.0, 80.0 + MK.rand(k * 3.1 + f) * 520.0, 8.0 + MK.rand(k + f * 2.0) * 60.0)
			c.rect(rect, _acid(f + k, k), 0.9)
		MotionMarks.checker(c, Vector2(MK.rand(f * 3.3) * 1500.0, MK.rand(f * 5.1) * 900.0), 10, 3, 22, _acid(f, 1), 1.0, f)


# ---------------------------------------------------------------- act II

## Path of the livery stripe bundle: up from bottom-left at 45 degrees, then right.
func _sweep_path() -> PackedVector2Array:
	return MotionPath.rounded(PackedVector2Array([Vector2(-500, 1500), Vector2(560, 440), Vector2(2600, 440)]), 260.0, 14)


func _draw_sweep(c: MotionCanvas, f: float) -> void:
	if f < SWEEP or f > PANELS[0] + 14.0:
		return
	var head := MK.map(f, [SWEEP, SWEEP + 11], [0, 1], MK.ease_in_out)
	var tail := MK.map(f, [SWEEP + 9, PANELS[0] + 5], [0, 1], MK.ease_in_quad)
	MotionMarks.stripe_bundle(c, _sweep_path(), [170, 170, 170, 170, 170], [FTFKit.CREAM, FTFKit.CYAN, FTFKit.LILAC, FTFKit.LIME, FTFKit.PINK], 0.0, tail, head)


func _frame_act2(f: float) -> void:
	_a2.visible = f >= PANELS[0] and f < GAP
	_iris.visible = false
	if not _a2.visible:
		for card in _cards:
			card.visible = false
		return
	var wall_on := f >= WALL
	_wall_bg.visible = wall_on
	_wall_canvas.visible = wall_on
	for t in _wall_text:
		t.visible = wall_on
		t.modulate.a = MK.prog(f, WALL + 4, 8)
	# tile order on the wall: K45 (index 2) lands first, the rest pop on eighths
	var order := [0, 1, 3, 4, 5]
	for i in _cards.size():
		var card := _cards[i]
		var slot := WALL_ORIGIN + Vector2(i % 3, floori(i / 3.0)) * WALL_STEP + Vector2(1920, 1080) * TILE_S * 0.5
		if not wall_on:
			card.visible = i < 3 and f >= PANELS[i] and (i == 2 or f < PANELS[i + 1])
			card.position = Vector2(W, H) * 0.5
			card.scale = Vector2.ONE
			# each panel kicks in from a little zoom
			var k := MK.map(f, [PANELS[mini(i, 2)], PANELS[mini(i, 2)] + 6.0], [0, 1], MK.ease_out)
			card.scale = Vector2.ONE * lerpf(1.08, 1.0, k)     # never below 1: no edge shows
			continue
		var s := 0.0
		if i == 2:
			var z := MK.spring(f, WALL, 13, 170)
			card.position = (Vector2(W, H) * 0.5).lerp(slot, z)
			s = lerpf(1.0, TILE_S, z)
		else:
			var at: float = TILES[order.find(i)]
			s = _pop(f, at, 15, 260) * TILE_S
			card.position = slot
		# tiles drop out on sixteenths before the iris
		var out := MK.map(f, [IRIS - 8.0 + i * 1.5, IRIS - 2.0 + i * 1.5], [0, 1], MK.ease_in_back)
		s *= 1.0 - out
		card.scale = Vector2.ONE * maxf(0.0, s)
		card.visible = s > 0.001
	# the pink iris that swallows the wall
	var t := MK.map(f, [IRIS, GAP - 1], [0, 1], MK.ease_in_quad)
	_iris.visible = t > 0.0
	_iris.position = Vector2(960, 540)
	_iris.size = Vector2.ONE * 2300.0 * t


func _draw_wall(c: MotionCanvas, f: float) -> void:
	var a := MK.prog(f, WALL + 2, 8)
	c.line(Vector2(WALL_ORIGIN.x, 196), Vector2(W - WALL_ORIGIN.x, 196), FTFKit.INK, 3.0, a)
	c.line(Vector2(WALL_ORIGIN.x, 884), Vector2(W - WALL_ORIGIN.x, 884), FTFKit.INK, 3.0, a)
	MotionMarks.barcode(c, Rect2(1430, 900, 358, 40), FTFKit.INK, 7.0, MK.prog(f, WALL + 6, 14))
	MotionMarks.chevrons(c, Vector2(WALL_ORIGIN.x, 990), 18, 34, FTFKit.PINK, fmod(f / 6.0, 1.0), 1.0, MK.prog(f, WALL + 4, 10))
	for p in [Vector2(70, 70), Vector2(1850, 70), Vector2(70, 1010), Vector2(1850, 1010)]:
		MotionMarks.plus(c, p, 16, FTFKit.INK, 2.0, a)


## A livery's graphics in card space (centre origin, 1920 x 1080).
func _draw_card(c: MotionCanvas, f: float, i: int, spec: Dictionary) -> void:
	var fg: Color = spec.fg
	var t0: float = PANELS[i] if i < 3 else TILES[[0, 1, 3, 4, 5].find(i)]
	var lf := f - t0            # local time since the card appeared
	var draw_in := MK.map(lf, [0, 8], [0, 1], MK.ease_out)
	# a corner X box and registration marks on every card
	MotionMarks.xbox(c, Vector2(860, -460), 70, fg, 3.0, 1.0, draw_in)
	MotionMarks.plus(c, Vector2(-890, 470), 18, fg, 3.0)
	match i:
		0:   # SPARROW: marching chevrons, pink/ink bent stripes
			MotionMarks.chevrons(c, Vector2(-880, -450), 14, 90, FTFKit.INK, fmod(f / 4.0, 1.0), 1.0, draw_in)
			var p := MotionPath.rounded(PackedVector2Array([Vector2(420, -560), Vector2(420, -10), Vector2(980, -10)]), 160.0, 12)
			MotionMarks.stripe_bundle(c, p, [90, 90], [FTFKit.PINK, FTFKit.INK], 22.0, 0.0, draw_in)
		1:   # STARLING: ring stack, crosshair, checker strip, hatched block
			var cen := Vector2(500, -90)
			for k in 7:
				c.ring(cen, (70.0 + k * 52.0) * draw_in, FTFKit.CREAM, 16.0)
			MotionMarks.crosshair(c, cen, 34, FTFKit.INK, 4.0, 1.0, draw_in)
			MotionMarks.checker(c, Vector2(380, 420), 14, 2, 40, FTFKit.INK, draw_in, 3.0)
			MotionMarks.hatch(c, MotionPoly.rect(Rect2(-880, -470, 420, 80)), 22, 9, FTFKit.INK, -45.0, f * 2.0)
		2:   # KESTREL: a field of diagonal arrows climbing up-right
			c.draw_set_transform(Vector2(560, -170), deg_to_rad(-45.0), Vector2.ONE)
			for r in 4:
				var col := FTFKit.ORANGE if r % 2 == 0 else FTFKit.PINK
				MotionMarks.chevrons(c, Vector2(-520, -200 + r * 132), 10, 96, col, fmod(f / 3.0 + r * 0.3, 1.0), 1.0, draw_in, 0.9 if r % 2 == 0 else 0.75)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			MotionMarks.hatch(c, MotionPoly.rect(Rect2(-880, -470, 420, 80)), 22, 9, FTFKit.ORANGE, 45.0, -f * 2.0)
		3:   # FLUX WORKS: big white checker flag
			for y in 4:
				for x in 6:
					if (x + y) % 2 == 0:
						c.rect(Rect2(320 + x * 90, -380 + y * 90, 90, 90), FTFKit.WHITE, draw_in)
			MotionMarks.chevrons(c, Vector2(-880, -470), 10, 70, FTFKit.WHITE, fmod(f / 4.0, 1.0), 1.0, draw_in)
		4:   # ARCLIGHT: cyan/pink stripes bending down
			var p2 := MotionPath.rounded(PackedVector2Array([Vector2(-980, -200), Vector2(300, -200), Vector2(300, 560)]), 220.0, 12)
			MotionMarks.stripe_bundle(c, p2, [80, 80, 80], [FTFKit.CYAN, FTFKit.WHITE, FTFKit.PINK], 0.0, 0.0, draw_in)
		5:   # BOREAL: triangle grid
			for y in 4:
				for x in 5:
					var o := Vector2(260 + x * 120, -400 + y * 120)
					if MK.rand(x * 3.0 + y * 7.0 + 1.0) > 0.35:
						c.polygon(PackedVector2Array([o, o + Vector2(110, 0), o + Vector2(0, 110)]), FTFKit.INK, Color(0, 0, 0, 0), 0.0, draw_in)
	# the code slides up into place on the card's beat
	var tx: Dictionary = _card_texts[i]
	var code: MotionText = tx.code
	var up := MK.spring(lf, 0.0, 12, 200)
	code.position.y = 520.0 - code.get_text_size().y + (1.0 - up) * 160.0
	(tx.jp as MotionText).visible_chars = int(MK.map(lf, [1, 6], [0, 8], MK.linear))
	(tx.micro as MotionText).modulate.a = MK.prog(lf, 3, 5)


# ---------------------------------------------------------------- act III

func _frame_act3(f: float) -> void:
	_a3.visible = f >= DROP and f < SHRINK + 2.0
	_dot.visible = f >= SHRINK and f < BLIP + 12.0
	if not _a3.visible:
		return
	var g := _glitch3(f)
	_a3.set_slices(g * 120.0, g * 18.0, 18, floorf(f) + 11.0)
	_a3.invert = 1.0 if (g > 0.0 and int(f) % 3 == 0) else 0.0

	# Logo group: slams in on the drop, flattens into a line on the way out.
	var slam := MK.spring(f, DROP, 12, 260)
	var flat := MK.map(f, [COLLAPSE, COLLAPSE + 10], [0, 1], MK.ease_in_quad)
	var sy := lerpf(1.0, 0.012, flat)
	var sx := lerpf(1.18, 1.0, slam) * lerpf(1.0, 1.1, flat)
	_logo_pivot.scale = Vector2(sx, lerpf(0.82, 1.0, slam) * sy)
	_logo_pivot.position = LOGO_C + Vector2((1.0 - slam) * -60.0, 0)
	var white_out := flat > 0.45
	var recol := g > 0.0
	var acc := int(MK.rand(floorf(f) * 2.3) * 3.0)
	_logo.apply(func(i: int) -> Variant:
		var d := {}
		if i == FTFKit.PLATE or i == FTFKit.RIM:
			pass
		elif FTFKit.WORD.has(i):
			var k := FTFKit.WORD.find(i)
			var at := WORD_AT + k * 1.5
			if f < at:
				return {hide = true}
			var s := MK.spring(f, at, 10, 230)
			d = {ty = (1.0 - s) * -360.0, rot = (1.0 - s) * (0.3 if k % 2 == 0 else -0.3), pivot = (_logo.data.parts[i].bbox as Rect2).get_center()}
		elif i == FTFKit.TAB:
			var t := MK.map(f, [TAB_AT, FLUX_AT], [0, 1], MK.ease_in_quad)
			if f < TAB_AT:
				return {hide = true}
			d = {tx = (1.0 - t) * 1500.0}
		elif FTFKit.FLUX_TOP.has(i) or FTFKit.FLUX_BOT.has(i) or i == FTFKit.FLUX_BOWL:
			var t2 := MK.map(f, [FLUX_AT - 7.0, FLUX_AT], [0, 1], MK.ease_in_quad)
			if f < FLUX_AT - 7.0:
				return {hide = true}
			var top := FTFKit.FLUX_TOP.has(i)
			var bounce := (1.0 - MK.spring(f, FLUX_AT, 8, 300)) * (6.0 if top else -6.0) if f >= FLUX_AT else 0.0
			d = {ty = (1.0 - t2) * (-420.0 if top else 420.0) + bounce}
		elif FTFKit.CHECKS.has(i):
			var at2: float = CHECK_AT[FTFKit.CHECKS.find(i)]
			if f < at2:
				return {hide = true}
			var s2 := MK.spring(f, at2, 9, 260)
			d = {s = s2, pivot = (_logo.data.parts[i].bbox as Rect2).get_center()}
		elif FTFKit.SMALL.has(i):
			var at3 := SMALL_AT + FTFKit.SMALL.find(i) * 1.0
			if f < at3:
				return {hide = true}
			d = {o = MK.prog(f, at3, 3), ty = (1.0 - MK.prog(f, at3, 5)) * 20.0}
		# recolours: glitch accents swap the palette; the collapse burns to white
		if white_out:
			d.fill = FTFKit.PINK
		elif recol:
			var pinkish := (_logo.data.parts[i].fill as Color).r < 0.95 or (_logo.data.parts[i].fill as Color).g < 0.95
			var swaps := [[FTFKit.INK, FTFKit.LIME], [FTFKit.LIME, FTFKit.INK], [FTFKit.WHITE, FTFKit.LILAC]]
			d.fill = swaps[acc][0] if pinkish else swaps[acc][1]
		return d)

	# HUD type pops in on eighths, out on sixteenths
	for k in _hud_texts.size():
		var p := _hud_texts[k]
		var s3 := _pop(f, _hud_at[k], 10, 240)
		var out := MK.map(f, [OUT + k * 1.2, OUT + 6.0 + k * 1.2], [0, 1], MK.ease_in_back)
		s3 *= 1.0 - out
		p.scale = Vector2.ONE * maxf(0.0, s3)
		p.visible = s3 > 0.001


func _lime_band() -> PackedVector2Array:
	# a diagonal band behind the logo, bottom-left to top-right (Moon Jumper style)
	return PackedVector2Array([Vector2(-200, 1180), Vector2(240, 1180), Vector2(1700, -100), Vector2(1260, -100)])


func _draw_act3_back(c: MotionCanvas, f: float) -> void:
	var g := _glitch3(f)
	var on := MK.map(f, [DROP, DROP + 8], [0, 1], MK.ease_out)
	var off := MK.map(f, [COLLAPSE - 6.0, COLLAPSE + 4.0], [0, 1], MK.ease_in_quad)
	var band := _lime_band()
	# grow along the diagonal, retract the same way
	var poly := PackedVector2Array([
		band[0].lerp(band[3], off), band[1].lerp(band[2], off),
		band[1].lerp(band[2], on), band[0].lerp(band[3], on)])
	if on > off:
		c.polygon(poly, FTFKit.LILAC if g > 0.0 else FTFKit.LIME, Color(0, 0, 0, 0))
		MotionMarks.hatch(c, poly, 34, 10, FTFKit.INK, -55.0, f * 1.5, 0.22)
	# a thin pink line riding parallel
	var shift := Vector2(300, 0)
	var line_a := (band[1] + shift).lerp(band[2] + shift, off)
	var line_b := (band[1] + shift).lerp(band[2] + shift, on)
	if on > off:
		c.line(line_a, line_b, FTFKit.PINK, 14.0)
	MotionMarks.chevrons(c, Vector2(70, 60), 12, 30, FTFKit.PINK, fmod(f / 6.0, 1.0), 1.0, on * (1.0 - off), 0.8)


func _hud_route_a() -> PackedVector2Array:
	return MotionPath.rounded(PackedVector2Array([Vector2(-40, 330), Vector2(110, 330), Vector2(110, 740), Vector2(230, 860), Vector2(1180, 860), Vector2(1300, 980), Vector2(1980, 980)]), 60.0, 10)


func _hud_route_b() -> PackedVector2Array:
	return MotionPath.rounded(PackedVector2Array([Vector2(1980, 190), Vector2(1560, 190), Vector2(1440, 300), Vector2(980, 300)]), 60.0, 10)


func _draw_hud(c: MotionCanvas, f: float) -> void:
	if f < HUD_AT[0]:
		return
	var out := MK.map(f, [OUT, OUT + 12], [0, 1], MK.ease_in_quad)
	# ribbons draw in along their routes, retract on the way out
	# a label plate under the bottom-left type, cutting the lime band
	var sp := _pop(f, HUD_AT[3], 12, 240) * (1.0 - out)
	if sp > 0.0:
		c.rect(Rect2(96, 884, 660 * sp, 176), FTFKit.INK)
		c.rect(Rect2(96, 884, 8, 176 * sp), FTFKit.PINK)
	var ra := _hud_route_a()
	var rb := _hud_route_b()
	var draw_a := MK.map(f, [HUD_AT[0], HUD_AT[0] + 16], [0, 1], MK.ease_in_out)
	var draw_b := MK.map(f, [HUD_AT[0] + 4, HUD_AT[0] + 18], [0, 1], MK.ease_in_out)
	MotionMarks.ribbon(c, ra, 24, FTFKit.LILAC, out, draw_a, true)
	MotionMarks.ribbon(c, rb, 24, FTFKit.LILAC, out, draw_b, true)
	if draw_a > 0.2:
		c.dashed_polyline(MotionPath.slice_fraction(ra, out, draw_a), FTFKit.INK, 4.0, 18.0, 14.0, -f * 2.0)
	# the hold is alive: chevrons march, X boxes and crosshairs, barcode, checkers
	var vis := 1.0 - out
	var s2 := _pop(f, HUD_AT[2], 10, 240) * vis
	var s3 := _pop(f, HUD_AT[3], 10, 240) * vis
	var s4 := _pop(f, HUD_AT[4], 10, 240) * vis
	MotionMarks.chevrons(c, Vector2(1480, 120), 10, 44, FTFKit.LIME, fmod(f / 6.0, 1.0), 1.0, s2)
	MotionMarks.xbox(c, Vector2(1640, 290), 64, FTFKit.WHITE, 3.0, 1.0, s3)
	MotionMarks.crosshair(c, Vector2(1760, 290), 26, FTFKit.PINK, 3.0, 1.0, s3)
	MotionMarks.xbox(c, Vector2(300, 760), 44, FTFKit.LIME, 3.0, 1.0, s2)
	MotionMarks.barcode(c, Rect2(1440, 1012, 300, 36), FTFKit.WHITE, 3.0, s4)
	MotionMarks.checker(c, Vector2(1580, 850), 10, 2, 20, FTFKit.WHITE, s4, 5.0)
	if s3 > 0.0:
		MotionMarks.hatch(c, MotionPoly.rect(Rect2(1300, 850, 240 * s3, 40)), 16, 6, FTFKit.LIME, 45.0, f * 2.0)
	for p in [Vector2(1850, 1040), Vector2(1850, 70)]:
		MotionMarks.plus(c, p, 14, FTFKit.STONE, 2.0, s2)


func _draw_dot(c: MotionCanvas, f: float) -> void:
	# the flattened logo line shrinks to a dot, which blips out on the final hit
	var t := MK.map(f, [SHRINK, SHRINK + 12], [0, 1], MK.ease_in_out)
	var half := lerpf(LOGO_W * 1.1 * 0.5, 0.0, t)
	var thick := lerpf(4.0, 9.0, t)
	if f < BLIP:
		if half > thick:
			c.rect(Rect2(LOGO_C.x - half, LOGO_C.y - thick, half * 2.0, thick * 2.0), FTFKit.PINK)
		# the dot pulses on the outro's last kick and the off-beat before the blip
		var pulse := 0.0
		for at in [SHRINK + 12.0, SHRINK + 18.0]:
			if f >= at:
				pulse = maxf(pulse, exp(-(f - at) * 0.45))
		c.circle(LOGO_C, thick * 1.2 * (1.0 + 0.6 * pulse), FTFKit.PINK)
		if pulse > 0.05:
			c.ring(LOGO_C, thick * (3.0 + 4.0 * (1.0 - pulse)), FTFKit.PINK, 2.0, pulse)
		return
	var b := MK.map(f, [BLIP, BLIP + 10], [0, 1], MK.ease_out)
	c.circle(LOGO_C, lerpf(16.0, 0.0, b), FTFKit.WHITE)
	c.ring(LOGO_C, lerpf(16.0, 160.0, b), FTFKit.PINK, lerpf(8.0, 1.0, b), 1.0 - b)
