# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — HOUNDSTOOTH: op-art textile intro.
#
# Brief: the whole frame is one woven houndstooth (real 2/2 twill, 4 dark / 4 light
# threads). The logos are first formed by the fabric itself: inside their shapes the
# tiles invert, turn 45° and take the logo's colours, and the tiles around them turn
# and shrink to a black margin, so each logo reads as a region of the pattern before
# it exists as a vector. Then the fabric parts and the vector logo is underneath.
# Colourways (black/cream, pink, lime) change as diagonal sweeps on the beat, a
# Vasarely bulge rolls through the cloth, ripples run out from the logo, and care
# labels and a size tag hang around it. Outro: the tiles shrink to nothing toward
# the centre and the last ones blip out on black.
#
# Tempo: 120 bpm = 15 frames a beat, 60 a bar, first downbeat at frame 0.
# Any 120 bpm track with its first downbeat at 0.0 s lines up; the drop is bar 5
# (frame 240, 8.0 s).
#
# Beats (30 fps, 420 frames):
#   0-14    the cloth opens from the centre (tiles grow out of black)
#   15      MINIMAL HUMANS weaves in: a sweep inverts the tiles inside the lockup
#   30      tiles inside turn 45°, tiles around shrink to a black margin
#   45      the lockup's own colours run into the weave (amber, red, cream)
#   60      the cloth parts from the M outwards: the vector lockup is underneath
#   75      PRESENTS woven label slides up
#   90      a Vasarely bulge rolls across the top of the cloth
#   105     tiles around the lockup twist; the label drops away
#   108     the cloth closes back over the lockup
#   114     the cloth is pulled up and away (scroll), MH leaves
#   120/135 colourway sweeps: pink, then lime
#   150     FULL THROTTLE FLUX weaves in from its centre (pink and white weave, 45°)
#   165     colourway sweep back to black and cream: the logo region stands out
#   180     tiles inside tighten (black between them), tiles around twist
#   195/210 the cloth bulges over the logo on the beat
#   225     the cloth is sucked into the centre (pinch), tiles get finer: riser
#   234-239 the cloth parts from the centre, fast
#   240     DROP: the vector logo, full size, on a black margin in lime-on-black
#           cloth; a ripple runs out; shake
#   252/264/276  care label, size tag, care symbols
#   255/285/330  ripples run out from the logo
#   270/300 colourway sweeps (pink, black-and-cream)
#   300-324 the logo weaves back into cloth from the outside in, holds, parts again
#   336     labels leave; 340 the logo weaves back into the cloth
#   348-372 the tiles shrink to nothing toward the centre, leaving a last swatch
#   384     the last swatch blips out; black to the end
@tool
extends MotionComposition

const BEAT := 15.0
const BAR := 60.0
# ---- Act I
const OPEN := 0.0
const MH_WEAVE := 15.0
const MH_TURN := 30.0
const MH_COLOUR := 45.0
const MH_PART := 60.0
const LABEL := 75.0
const MH_BULGE := 90.0
const MH_TWIST := 105.0
const MH_CLOSE := 108.0
const MH_PULL := 114.0
# ---- Act II
const ACT2 := 120.0
const FTF_WEAVE := 150.0
const TIGHTEN := 180.0
const PULSES := [195.0, 210.0]
const PINCH := 225.0
const PART := 234.0
# ---- Act III
const DROP := 240.0
const TAGS := [252.0, 264.0, 276.0]
const RIPPLES := [255.0, 285.0, 330.0]
const REWEAVE := 300.0
const REPART := 316.0
const OUT := 336.0
const CLOSE := 340.0
const COLLAPSE := 348.0
const BLIP := 384.0
const END := 420

# colourway sweeps: [frame, angle (deg), colourway index, motif]
const SWEEPS := [[120.0, 30.0, 1, 0], [135.0, 210.0, 2, 1], [165.0, 90.0, 0, 0], [270.0, 150.0, 1, 0], [300.0, -30.0, 0, 0]]
const SWEEP_DUR := 12.0

# layout
const MH_W := 1300.0
const MH_POS := Vector2(310, 285)
const FTF_W := 1560.0
const FTF_POS := Vector2(180, 315)
const CELL := 44.0

var _built := false
var _stage: Node2D
var _mh_under: MotionSvg
var _ftf_under: MotionSvg
var _ftf_pivot: Node2D
var _tiling: MotionTiling
var _mh_mask: MotionSvg
var _ftf_mask: MotionSvg
var _labels: MotionCanvas
var _presents: Node2D
var _tag_care: Node2D
var _tag_size: Node2D
var _tag_symbols: Node2D
var _mh_k := 1.0
var _ftf_k := 1.0


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": 252.0, "out": OUT}
	cue(OPEN, &"open", 0.8)
	cue(MH_WEAVE, &"weave", 0.6)
	cue(MH_TURN, &"turn", 0.6)
	cue(MH_COLOUR, &"colour", 0.7)
	cue(MH_PART, &"part", 0.9)
	cue(LABEL, &"label", 0.6)
	cue(MH_BULGE, &"bulge", 0.5)
	cue(MH_TWIST, &"turn", 0.5, {pitch = 1.19})
	cue(MH_PULL, &"pull", 0.8)
	var sweep_pitch := [1.0, 1.12, 1.26, 1.0, 0.89]
	for i in SWEEPS.size():
		cue(float(SWEEPS[i][0]), &"sweep", 0.7, {pitch = sweep_pitch[i]})
	cue(FTF_WEAVE, &"weave", 0.9, {pitch = 0.89})
	cue(TIGHTEN, &"tighten", 0.8)
	for p in PULSES:
		cue(float(p), &"bulge", 0.7)
	cue(DROP, &"riser", 1.0)      # its recipe swells in ahead and peaks on the drop
	cue(PART, &"snip", 0.8)
	cue(DROP, &"drop", 1.0)
	for i in TAGS.size():
		cue(float(TAGS[i]), &"tag", 0.6, {pitch = [1.0, 1.19, 1.5][i]})
	for r in RIPPLES:
		cue(float(r), &"ripple", 0.6)
	cue(REWEAVE, &"weave", 0.6, {pitch = 1.12})
	cue(REPART, &"snip", 0.6, {pitch = 1.12})
	cue(OUT, &"zip", 0.7)
	cue(CLOSE, &"weave", 0.5, {pitch = 0.84})
	cue(COLLAPSE, &"collapse", 0.9)
	cue(BLIP, &"blip", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _logo(path: String, w: float, pos: Vector2) -> MotionSvg:
	var s := MotionSvg.new()
	s.data = _svg(path)
	s.width = w
	s.position = pos
	return s


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = FTFKit.INK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	# vector logos under the cloth: they show where the cloth parts
	_mh_under = _logo("res://demo/assets/logos/mh_logoFull_standard.svg", MH_W, MH_POS)
	_stage.add_child(_mh_under)
	_mh_k = MH_W / _mh_under.data.view_box.size.x
	_ftf_pivot = Node2D.new()
	_ftf_pivot.position = FTF_POS + Vector2(FTF_W, FTF_W * 339.95 / 1427.88) * 0.5
	_stage.add_child(_ftf_pivot)
	_ftf_under = _logo(FTFKit.LOGO, FTF_W, Vector2.ZERO)
	_ftf_k = FTF_W / _ftf_under.data.view_box.size.x
	_ftf_under.position = -_ftf_under.data.view_box.size * _ftf_k * 0.5
	_ftf_pivot.add_child(_ftf_under)
	# the cloth
	_tiling = MotionTiling.new()
	_tiling.size = size
	_tiling.cell = CELL
	_tiling.mask_scale = 0.5
	_stage.add_child(_tiling)
	_mh_mask = _logo("res://demo/assets/logos/mh_logoFull_standard.svg", MH_W, MH_POS)
	_tiling.mask_content.add_child(_mh_mask)
	_ftf_mask = _logo(FTFKit.LOGO, FTF_W, FTF_POS)
	_tiling.mask_content.add_child(_ftf_mask)
	# labels
	_presents = _make_presents()
	_tag_care = _make_care_label()
	_tag_size = _make_size_tag()
	_tag_symbols = _make_symbols()
	_add_sound()


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_houndstooth/audio/ht_map.tres"
	const SONG := "res://demo/ftf/ftf_houndstooth/audio/music/ht_song.tres"
	const TRACK := "res://demo/ftf/ftf_houndstooth/audio/ht_track.res"
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


func _text(parent: Node, key: String, sz: float, col: Color, s: String, tracking := 0.0) -> MotionText:
	return FTFKit.text(parent, key, sz, col, s, tracking)


## A woven label: a solid rectangle with a stitched border, origin top-left.
func _woven(parent: Node, w: float, h: float, bg: Color, thread: Color) -> MotionCanvas:
	var c := MotionCanvas.new()
	c.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		cv.rect(Rect2(0, 0, w, h), bg)
		# fold shadow at the top edge, woven ribs
		cv.rect(Rect2(0, 0, w, 6), Color(0, 0, 0, 0.25))
		for x in range(0, int(w), 6):
			cv.line(Vector2(x, 6), Vector2(x, h), Color(1, 1, 1, 0.025), 2.0)
		var r := Rect2(10, 14, w - 20, h - 26)
		cv.dashed_polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), thread, 2.0, 7.0, 5.0, 0.0, 0.8)
	parent.add_child(c)
	return c


func _make_presents() -> Node2D:
	var n := Node2D.new()
	_stage.add_child(n)
	_woven(n, 640, 150, FTFKit.INK, FTFKit.CREAM)
	var t := _text(n, "ext", 50, FTFKit.CREAM, "PRESENTS", 0.36)
	t.position = Vector2(320 - t.get_text_size().x * 0.5 + 9.0, 28)
	var s := _text(n, "mono", 20, FTFKit.MH_AMBER, "提供  //  MINIMAL HUMANS  //  100% FOSS", 0.08)
	s.position = Vector2(320 - s.get_text_size().x * 0.5, 100)
	return n


func _make_care_label() -> Node2D:
	var n := Node2D.new()
	_stage.add_child(n)
	_woven(n, 560, 190, FTFKit.INK, FTFKit.CREAM)
	var a := _text(n, "ext", 28, FTFKit.CREAM, "100% ANTI-GRAVITY", 0.06)
	a.position = Vector2(32, 34)
	var b := _text(n, "mono", 22, FTFKit.CREAM, "WASH AT 9000°\nDO NOT TUMBLE BELOW MACH 1\nMADE IN BERLIN // F-9000", 0.06)
	b.line_height = 1.35
	b.position = Vector2(32, 82)
	var j := _text(n, "jp", 26, FTFKit.PINK, "反重力")
	j.position = Vector2(560 - 30 - j.get_text_size().x, 78)
	return n


func _make_size_tag() -> Node2D:
	# a swing tag hanging from a string; origin at the string's top
	var n := Node2D.new()
	_stage.add_child(n)
	var c := MotionCanvas.new()
	c.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		cv.line(Vector2(0, 0), Vector2(0, 70), FTFKit.CREAM, 2.0)
		var body := PackedVector2Array([Vector2(-100, 96), Vector2(-60, 70), Vector2(60, 70), Vector2(100, 96), Vector2(100, 330), Vector2(-100, 330)])
		cv.polygon(body, FTFKit.PINK, Color(0, 0, 0, 0), 0.0)
		cv.circle(Vector2(0, 92), 9, FTFKit.INK)
		cv.ring(Vector2(0, 92), 13, FTFKit.CREAM, 2.0)
		FTFKit.checker(cv, Vector2(-100, 300), 10, 1, 20, FTFKit.INK)
	n.add_child(c)
	var s := _text(n, "mono", 20, FTFKit.WHITE, "SIZE / CLASS", 0.12)
	s.position = Vector2(-s.get_text_size().x * 0.5, 124)
	var big := _text(n, "wide", 96, FTFKit.WHITE, "S", 0.0)
	big.position = Vector2(-big.get_text_size().x * 0.5, 150)
	var cls := _text(n, "ext", 20, FTFKit.INK, "SPARROW", 0.1)
	cls.position = Vector2(-cls.get_text_size().x * 0.5 + 2.0, 262)
	return n


func _make_symbols() -> Node2D:
	var n := Node2D.new()
	_stage.add_child(n)
	var c := MotionCanvas.new()
	c.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		var w := 540.0
		cv.rect(Rect2(0, 0, w, 104), FTFKit.CREAM)
		cv.rect(Rect2(0, 0, w, 5), Color(0, 0, 0, 0.2))
		var ink := FTFKit.INK
		var y := 54.0
		# wash tub
		var x := 56.0
		cv.polyline(PackedVector2Array([Vector2(x - 34, y - 22), Vector2(x - 26, y + 24), Vector2(x + 26, y + 24), Vector2(x + 34, y - 22)]), ink, 4.0)
		var wave := PackedVector2Array()
		for k in 9:
			wave.append(Vector2(x - 34 + k * 8.5, y - 22 + (4.0 if k % 2 == 0 else -4.0)))
		cv.polyline(wave, ink, 3.0)
		# triangle, crossed
		x = 158.0
		cv.polygon(PackedVector2Array([Vector2(x, y - 26), Vector2(x + 30, y + 24), Vector2(x - 30, y + 24)]), Color(0, 0, 0, 0), ink, 4.0)
		cv.line(Vector2(x - 30, y - 26), Vector2(x + 30, y + 24), ink, 4.0)
		cv.line(Vector2(x + 30, y - 26), Vector2(x - 30, y + 24), ink, 4.0)
		# tumble dry
		x = 258.0
		cv.rect(Rect2(x - 26, y - 26, 52, 52), ink, 1.0, 4.0)
		cv.ring(Vector2(x, y), 17, ink, 4.0)
		cv.circle(Vector2(x, y), 4, ink)
		# iron, three dots
		x = 362.0
		cv.polygon(PackedVector2Array([Vector2(x - 34, y + 20), Vector2(x + 34, y + 20), Vector2(x + 30, y - 6), Vector2(x - 8, y - 6), Vector2(x - 20, y - 22), Vector2(x - 30, y - 22)]), Color(0, 0, 0, 0), ink, 4.0)
		for k in 3:
			cv.circle(Vector2(x - 6 + k * 12, y + 8), 3.5, ink)
		# dry clean F
		x = 470.0
		cv.ring(Vector2(x, y), 26, ink, 4.0)
	n.add_child(c)
	var f := _text(n, "ext", 26, FTFKit.INK, "F", 0.0)
	f.position = Vector2(470 - f.get_text_size().x * 0.5, 54 - f.get_text_size().y * 0.5)
	var t := _text(n, "mono", 18, FTFKit.INK, "9000", 0.0)
	t.position = Vector2(56 - t.get_text_size().x * 0.5, 50)
	return n


# ================================================================== helpers

func _e(f: float, at: float, dur: float, easing: Callable = MK.ease_out) -> float:
	return MK.map(f, [at, at + dur], [0, 1], easing)


## Colourways: [motif ink, ground].
func _cw(i: int) -> Array:
	match i:
		1: return [FTFKit.PINK, FTFKit.INK]
		2: return [FTFKit.LIME, FTFKit.INK]
		3: return [FTFKit.CREAM, FTFKit.PINK]
		4: return [FTFKit.LIME, FTFKit.INK]
	return [FTFKit.INK, FTFKit.CREAM]


## Set the colourway and the sweep front for frame f.
func _colourway(f: float) -> void:
	var t := _tiling
	var k := -1
	for i in SWEEPS.size():
		if f >= float(SWEEPS[i][0]):
			k = i
	if k < 0:
		var c0 := _cw(0)
		t.ink_a = c0[0]; t.ink_b = c0[1]
		t.alt_a = c0[0]; t.alt_b = c0[1]
		t.sweep = -100000.0
		return
	var prev: int = 0 if k == 0 else int(SWEEPS[k - 1][2])
	var cur: int = int(SWEEPS[k][2])
	var a := _cw(prev)
	var b := _cw(cur)
	t.ink_a = a[0]; t.ink_b = a[1]
	t.alt_a = b[0]; t.alt_b = b[1]
	t.alt_by.w = 1.0
	# the motif changes with the sweep too (houndstooth <-> checker)
	t.motif = int(SWEEPS[k - 1][3]) as MotionTiling.Motif if k > 0 else MotionTiling.Motif.HOUNDSTOOTH
	t.motif_b = int(SWEEPS[k][3]) as MotionTiling.Motif
	t.motif_by.w = 1.0
	t.sweep_angle = float(SWEEPS[k][1])
	t.sweep_w = 70.0
	t.sweep = lerpf(-1400.0, 1400.0, _e(f, float(SWEEPS[k][0]), SWEEP_DUR, MK.ease_in_out))


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	var t := _tiling
	t.reset_channels()
	t.cell = CELL
	t.angle = 0.0
	t.scroll = Vector2.ZERO
	t.bulge = 0.0
	t.ripple_r = -1.0
	t.ring_r = -1.0
	t.ring_mode = MotionTiling.RingMode.DISC
	t.jitter = 0.5
	t.mask_color = 0.0
	t.mask_ground = 0.0
	t.motif = MotionTiling.Motif.HOUNDSTOOTH
	t.motif_b = MotionTiling.Motif.CHECKER
	t.mask_warp = false
	t.gap_color = FTFKit.INK
	t.halo_r = 56.0
	t.level = 1.0
	_stage.position = MK.shakes(f, [MH_PART, DROP], 14, 8)

	if f < ACT2:
		_act1(f)
	elif f < DROP:
		_act2(f)
	else:
		_act3(f)
	_frame_labels(f)
	t._sync()


func _act1(f: float) -> void:
	var t := _tiling
	_mh_under.position = MH_POS
	t.scroll = Vector2(f * 0.7, f * 0.35)     # the cloth always drifts
	_mh_mask.visible = true
	_ftf_mask.visible = false
	_mh_under.visible = f >= MH_PART - 1.0 and f < MH_PULL + 6.0
	_ftf_pivot.visible = false
	_colourway(f)
	var mh_c := MH_POS + Vector2(60, 64) * _mh_k
	# open: tiles grow out of black from the centre (ring disc)
	if f < MH_WEAVE:
		t.ring_c = Vector2(960, 540)
		t.ring_w = 90.0
		t.ring_r = lerpf(0.0, 1300.0, _e(f, OPEN, 14.0, MK.ease_in_out))
		t.scale_base = 0.0
		t.scale_by.z = 1.0
		return
	# weave: a sweep inverts the tiles inside the lockup
	t.sweep_angle = 0.0
	t.sweep_w = 60.0
	t.sweep = lerpf(-1100.0, 1100.0, _e(f, MH_WEAVE, 12.0, MK.ease_in_out))
	t.inv_and.y = 1.0
	# turn: tiles inside turn 45°, tiles around shrink to a black margin
	var turn := _e(f, MH_TURN, 8.0)
	t.rot_by.x = PI / 4.0 * turn
	t.scale_by.y = -0.82 * _e(f, MH_TURN + 2.0, 8.0)
	t.rot_by.y = PI / 8.0 * turn + PI / 2.0 * _e(f, MH_TWIST, 8.0)
	# colour: the lockup's own colours run into the weave
	t.mask_color = _e(f, MH_COLOUR, 8.0)
	# part: inside cells vanish from the M outwards (ring x mask), the vector shows through
	if f >= MH_PART:
		t.ring_c = mh_c
		t.ring_w = 60.0
		var open_r := lerpf(0.0, 1500.0, _e(f, MH_PART, 9.0, MK.ease_in_quad))
		var close_r := lerpf(1500.0, 0.0, _e(f, MH_CLOSE, 7.0, MK.ease_in_quad))
		t.ring_r = minf(open_r, close_r) if f >= MH_CLOSE else open_r
		t.scale_and.x = -1.0
		t.clear_and.x = 1.0
	# bulge rolling across the top of the cloth
	if f >= MH_BULGE and f < MH_PULL:
		var b := _e(f, MH_BULGE, 26.0, MK.linear)
		t.bulge_c = Vector2(lerpf(-250.0, 2170.0, b), 150.0)
		t.bulge_r = 420.0
		t.bulge = 0.5 * sin(b * PI)
	# pull: the cloth is dragged up and away; the lockup's weave fades with it
	if f >= MH_PULL:
		var p := _e(f, MH_PULL, 6.0, MK.ease_in_quad)
		t.scroll += Vector2(0, 900.0 * p)
		var fade := 1.0 - p
		t.rot_by.x *= fade
		t.inv_and.y *= fade
		t.mask_color *= fade
		t.scale_by.y *= fade
		t.rot_by.y *= fade
		_mh_under.position = MH_POS - Vector2(0, 900.0 * p)


func _act2(f: float) -> void:
	var t := _tiling
	_mh_mask.visible = false
	_ftf_mask.visible = true
	_mh_under.visible = false
	_ftf_pivot.visible = f >= PART
	_ftf_pivot.scale = Vector2.ONE
	_colourway(f)
	# the cloth keeps drifting (it arrived pulled from below)
	var settle := _e(f, ACT2, 10.0)
	t.scroll = Vector2(0, -600.0 * (1.0 - settle)) + Vector2(f - ACT2, (f - ACT2) * 0.5)
	t.mask_warp = true
	var lc := FTF_POS + Vector2(FTF_W, FTF_W * 339.95 / 1427.88) * 0.5
	# FTF weaves in from its centre: ring x mask
	var weave_ring := f >= FTF_WEAVE and f < FTF_WEAVE + 15.0
	var woven := _e(f, FTF_WEAVE, 15.0, MK.linear)
	if weave_ring:
		t.ring_c = lc
		t.ring_w = 70.0
		t.ring_r = lerpf(0.0, 1000.0, _e(f, FTF_WEAVE, 12.0, MK.ease_out))
		t.rot_and.x = PI / 4.0
		t.scale_and.x = 0.3
	elif f >= FTF_WEAVE + 15.0:
		t.rot_by.x = PI / 4.0
		t.scale_by.x = 0.3
	t.mask_color = 1.0 if f >= FTF_WEAVE else 0.0
	t.mask_ground = t.mask_color
	# the margin around the logo
	t.scale_by.y = -0.84 * _e(f, FTF_WEAVE + 4.0, 10.0)
	# tighten: tiles inside shrink (black between), tiles around twist
	t.scale_by.x += -0.12 * _e(f, TIGHTEN, 6.0)
	t.rot_by.y = PI / 4.0 * _e(f, TIGHTEN, 8.0) + PI / 4.0 * _e(f, PULSES[0], 6.0) + PI / 4.0 * _e(f, PULSES[1], 6.0)
	# bulges on the beat over the logo
	t.bulge_c = lc
	t.bulge_r = 820.0
	for p in PULSES:
		if f >= float(p):
			t.bulge = 0.42 * exp(-(f - float(p)) * 0.22)
	# pinch: the cloth is sucked into the centre, tiles get finer
	if f >= PINCH:
		var k := _e(f, PINCH, DROP - PINCH, MK.ease_in_quad)
		t.bulge_c = lc
		t.bulge_r = 1100.0
		t.bulge = -0.62 * k
		t.cell = lerpf(CELL, 28.0, k)
		t.angle = 12.0 * k
	# part: cells inside and around the logo vanish from the centre, fast
	if f >= PART:
		t.ring_c = lc
		t.ring_w = 50.0
		t.jitter = 0.35
		t.ring_r = lerpf(0.0, 1250.0, _e(f, PART, DROP - PART - 1.0, MK.ease_in_quad))
		t.scale_and.x = -1.0
		t.clear_and.x = 1.0
		t.scale_and.z = -0.06
		t.mask_warp = false


func _act3(f: float) -> void:
	var t := _tiling
	_mh_mask.visible = false
	_ftf_mask.visible = true
	_mh_under.visible = false
	_colourway_act3(f)
	var lc := FTF_POS + Vector2(FTF_W, FTF_W * 339.95 / 1427.88) * 0.5
	# the logo: full size on the drop, a small settle from 104%
	_ftf_pivot.scale = Vector2.ONE * lerpf(1.04, 1.0, _e(f, DROP, 8.0))
	_ftf_pivot.visible = f < COLLAPSE + 4.0
	t.scroll = Vector2((f - DROP) * 0.8, -(f - DROP) * 0.4)
	# parted state (scalar) and the black margin
	var parted := 1.0 - _e(f, CLOSE, 10.0, MK.ease_in_out)
	t.mask_color = 1.0
	t.mask_ground = 1.0
	t.rot_by.x = PI / 4.0
	t.scale_by.x = 0.18 - 1.18 * parted
	t.clear_by.x = parted
	t.scale_by.y = -0.9 * parted
	# tiles around the logo keep turning
	t.rot_by.y = (f - DROP) * 0.035
	# the re-weave accent: the logo turns back into cloth from the outside in, then parts
	if f >= REWEAVE and f < REPART + 12.0:
		t.ring_mode = MotionTiling.RingMode.DISC
		t.ring_c = lc
		t.ring_w = 60.0
		var r_in := lerpf(1100.0, 0.0, _e(f, REWEAVE, 9.0, MK.ease_in_out))
		var r_out := lerpf(0.0, 1100.0, _e(f, REPART, 9.0, MK.ease_in_out))
		t.ring_r = maxf(0.001, r_out if f >= REPART else r_in)
		t.scale_by.x = 0.18
		t.clear_by.x = 0.0
		t.scale_and.x = -1.18
		t.clear_and.x = 1.0
	# ripples run out from the logo (the drop's is the biggest)
	var rip := [DROP] + RIPPLES
	for i in rip.size():
		var at: float = rip[i]
		if f >= at and f < at + 34.0:
			t.ripple_c = lc
			t.ripple_r = lerpf(200.0, 1500.0, _e(f, at, 34.0, MK.linear))
			t.ripple_w = 110.0
			t.ripple_amp = (34.0 if i == 0 else 18.0) * (1.0 - _e(f, at, 34.0, MK.linear))
	# a slow bulge circling in the corners of the cloth
	var b := (f - DROP) / 96.0
	t.bulge_c = Vector2(960, 540) + Vector2(cos(b * TAU) * 900.0, sin(b * TAU) * 470.0)
	t.bulge_r = 260.0
	t.bulge = 0.38 * _e(f, DROP + 6.0, 20.0) * (1.0 - _e(f, OUT, 12.0))
	# collapse: tiles shrink to nothing toward the centre
	if f >= COLLAPSE:
		t.ring_mode = MotionTiling.RingMode.OUTSIDE
		t.ring_c = Vector2(960, 540)
		t.ring_w = 60.0
		t.jitter = 0.6
		# down to a last swatch at the centre, which blips out on BLIP
		var r_last := lerpf(1250.0, 70.0, _e(f, COLLAPSE, 24.0, MK.ease_in_quad))
		t.ring_r = maxf(0.001, lerpf(r_last, 0.0, _e(f, BLIP, 3.0, MK.ease_in_quad)))
		t.jitter = 0.6 * (1.0 - _e(f, COLLAPSE + 20.0, 4.0))
		t.scale_by.z = -1.6
		t.scale_and = Vector4.ZERO
		t.clear_and = Vector4.ZERO
		t.level = 1.0 - _e(f, BLIP, 3.0, MK.linear)
	t.visible = f < BLIP + 4.0


func _colourway_act3(f: float) -> void:
	var t := _tiling
	# the drop changes the cloth to lime-on-black at once; later sweeps continue
	var base := 4
	var pending: int = -1
	var at := 0.0
	var ang := 0.0
	for i in SWEEPS.size():
		var s0: float = float(SWEEPS[i][0])
		if s0 >= DROP and f >= s0:
			base = pending if pending >= 0 else base
			pending = int(SWEEPS[i][2])
			at = s0
			ang = float(SWEEPS[i][1])
	var a := _cw(base)
	t.ink_a = a[0]; t.ink_b = a[1]
	if pending < 0:
		t.alt_a = a[0]; t.alt_b = a[1]
		return
	var b := _cw(pending)
	t.alt_a = b[0]; t.alt_b = b[1]
	t.alt_by.w = 1.0
	t.sweep_angle = ang
	t.sweep_w = 70.0
	t.sweep = lerpf(-1400.0, 1400.0, _e(f, at, SWEEP_DUR, MK.ease_in_out))


func _frame_labels(f: float) -> void:
	# PRESENTS: slides up under the lockup, drops away
	var pin := _e(f, LABEL, 10.0)
	var pout := _e(f, MH_TWIST, 8.0, MK.ease_in_quad)
	_presents.visible = f >= LABEL and pout < 1.0
	_presents.position = Vector2(960 - 320, lerpf(1100.0, 690.0, pin) + 500.0 * pout)
	# care label (bottom left), slides in from the left
	var c_in := _e(f, TAGS[0], 9.0)
	var out := _e(f, OUT, 10.0, MK.ease_in_quad)
	_tag_care.visible = f >= TAGS[0] and out < 1.0
	_tag_care.position = Vector2(lerpf(-520.0, 96.0, c_in) - 620.0 * out, 846)
	# size tag (top right), drops on its string and swings, decaying
	var s_t := f - TAGS[1]
	_tag_size.visible = s_t >= 0.0 and out < 1.0
	var drop := _e(f, TAGS[1], 7.0, MK.ease_in_quad)
	_tag_size.position = Vector2(1690, lerpf(-360.0, -32.0, drop) - 420.0 * out)
	_tag_size.rotation = (0.22 * exp(-maxf(0.0, s_t - 7.0) * 0.045) * sin(maxf(0.0, s_t - 7.0) * 0.21)) if s_t > 7.0 else 0.0
	# care symbols strip (bottom right), wipes in from the right
	var y_in := _e(f, TAGS[2], 9.0)
	_tag_symbols.visible = f >= TAGS[2] and out < 1.0
	_tag_symbols.position = Vector2(lerpf(1960.0, 1290.0, y_in) + 700.0 * out, 916)
