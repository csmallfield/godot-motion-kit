# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take: GREEBLES. Bold shapes, intricate tertiary greebles.
#
# Brief: concept-art hard surface in the sky (Brian Sum's "Sky City"): huge pale
# stone forms against blue sky, chunky overhangs with cool shadowed undersides,
# dark recesses full of tiny machinery. Every shape is greebled by MotionGreebler
# in three tiers (bold shape, secondary panels, tertiary vents / bolts / pipes /
# lamps / stencils), and detail resolves by its size ON SCREEN: push in and the
# machinery appears, pull out and the bold shapes read clean.
#   I   MINIMAL HUMANS. We open pressed against the monogram's stone face, deep
#       in its machinery, and pull back three beats until the whole lockup hangs
#       in the sky as a monument; its red and amber layers slide home on beats 2
#       and 3. On bar 2 a hatch in the plinth opens: PRESENTS, lit amber.
#   II  On beat 7 the camera dives into the open hatch; detail cascades past
#       until the recess swallows the frame. Blast doors light up in the dark.
#   III DROP (bar 3): the doors split along their seam and the FTF hull plate is
#       already there, full frame, set in a sky-city superstructure (overhang,
#       pylons, deck). Panel seams and greebles cascade out from the plate. The
#       hold stays busy: lamps blink on the beat, fans turn, drones cross at
#       three depths, the camera drifts with parallax, clouds pass; on bar 4
#       the clamps slam onto the plate with steam and a glint sweeps across it.
#   IV  Pull out into the sky: the plate becomes one piece of a city of floating
#       structures, the sky goes to dusk and haze, the lamps glow, then cut on
#       the last downbeat and everything hazes to black.
#
# Tempo: 75 bpm, 4/4 (half-time), 24 frames a beat, 96 a bar, first downbeat at
# frame 0. Bars land on frames 0, 96, 192, 288, 384. Replace the music with any
# 75 (or 150 half-time) bpm track whose first downbeat is at 0.0 s.
#
# Beats (30 fps, 420 frames):
#   0       fade in on the monogram's face, s = 12; pull back to 72
#   24/48   red, then amber layer slide home (clank)
#   72      lockup settles (boom)
#   96      bar 2: plinth hatch opens; 104 PRESENTS lights
#   144     dive into the hatch (riser to the drop); 182-191 blast doors light
#           in the dark and creep closer
#   192     DROP: doors split, hull plate full frame, shake; cascade to 240
#   240     HUD types in; drones 248 / 276 / 300
#   288     bar 4: clamps slam, steam, glint sweep
#   336     HUD out, pull out to the sky city; dusk
#   384     bar 5: lamps cut; haze to black by 402; black to 420
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0
const SC := Vector2(960, 540)
const BEAT := 24.0
const BAR := 96.0

# ---- beats
const PULL_END := 72.0
const LAYER_AT := [24.0, 48.0]
const SETTLE := 72.0
const HATCH := 96.0
const PRESENTS_AT := 104.0
const DIVE := 144.0
const DOORS_ON := 182.0
const DROP := 192.0
const CASCADE_END := 240.0
const HUD_AT := 240.0
const DRONES := [248.0, 276.0, 300.0]
const MH_DRONES := [110.0, 124.0]
const CLAMP := 288.0
const OUT := 336.0
const CUT := 384.0
const BLACK := 402.0
const END := 420

# ---- camera / depth
const F_LEN := 1000.0
const D_MAIN := 1000.0
const D_FAR := 2600.0
const D_CLOUD := 1700.0
const D_FG := 650.0
const S0 := 12.0
const S1 := 0.92

# ---- palette (Sky City)
const STONE := Color("#ebe6da")
const STONE_FG := Color("#d8d1c2")
const SHADOW := Color("#9fb1c1")
const SKY_TOP := Color("#5b9bd8")
const SKY_MID := Color("#a6cdea")
const SKY_LOW := Color("#e7eef0")
const DUSK_TOP := Color("#121c34")
const DUSK_MID := Color("#3f4774")
const DUSK_LOW := Color("#e2946a")
const HAZE_DAY := Color("#c9dcea")
const HAZE_DUSK := Color("#4c4a6c")

# ---- world layout
const MH_W := 1300.0
const MH_TL := Vector2(-650, -200)
const C1 := Vector2(0, 30)
const HATCH_R := Rect2(-330, 232, 660, 70)
const T_DIVE := Vector2(250, 267)
const X0 := 20000.0
const LOGO_W := 1500.0
const C2 := Vector2(X0, 40)

var _built := false
var _mh: MotionSvgData
var _ftf: MotionSvgData
var _k_mh := 1.0
var _k_ftf := 1.0
var _ftf_tl := Vector2.ZERO
var _p0 := Vector2.ZERO
var _plate_outline := PackedVector2Array()

var _g_far: MotionGreebler
var _g_back: MotionGreebler
var _g_mid: MotionGreebler
var _g_front: MotionGreebler
var _g_fg: MotionGreebler
var _g_doors: MotionGreebler
var _ftf_ids: Array = []
var _mh_list: Array = []
var _red_sides := -1
var _clamp_l := -1
var _clamp_r := -1
var _door_l: Array[int] = []
var _door_r: Array[int] = []

var _sky: MotionGradient
var _sun: MotionShape
var _far: MotionCanvas
var _stage: Node2D
var _back: MotionCanvas
var _mh_svg: MotionSvg
var _ftf_plate: MotionSvg
var _mid: MotionCanvas
var _ftf_svg: MotionSvg
var _front: MotionCanvas
var _pres_node: Node2D
var _presents: MotionText
var _front2: MotionCanvas
var _fg: MotionCanvas
var _doors: MotionCanvas
var _hud: Array[MotionText] = []
var _hud_bg: Array[ColorRect] = []
var _fade: ColorRect

# per-frame camera, shared by the draw callbacks
var _cam_c := Vector2.ZERO
var _cam_s := 1.0
var _shake := Vector2.ZERO


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": CASCADE_END, "out": OUT}
	cue(0.0, &"air", 0.8)
	for i in LAYER_AT.size():
		cue(LAYER_AT[i], &"clank", 0.7 + 0.15 * i, {pitch = [1.0, 1.19][i]})
	cue(SETTLE, &"settle", 0.9)
	cue(HATCH, &"servo", 0.7)
	cue(PRESENTS_AT, &"lamp", 0.7)
	cue(DROP, &"riser", 1.0)          # swells from the dive, peaks on the drop
	cue(DOORS_ON, &"alarm", 0.6, {pitch = 1.0})
	cue(DOORS_ON + 5.0, &"alarm", 0.6, {pitch = 0.84})
	cue(DROP, &"slam", 1.0)
	cue(DROP + 6.0, &"cascade", 0.7)
	cue(HUD_AT, &"hud", 0.6)
	for i in DRONES.size():
		cue(DRONES[i], &"drone", 0.6 + 0.1 * i, {pitch = [1.0, 0.84, 1.19][i], pan = [-0.6, 0.6, -0.3][i]})
	for i in MH_DRONES.size():
		cue(MH_DRONES[i], &"drone", 0.45, {pitch = [1.12, 0.94][i], pan = [-0.5, 0.5][i]})
	cue(CLAMP, &"clamp", 1.0)
	cue(CLAMP + 2.0, &"steam", 0.7)
	cue(OUT, &"pullout", 0.9)
	cue(CUT, &"cut", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _greebler(face_c: Color, haze_c: Color, hz: float) -> MotionGreebler:
	var g := MotionGreebler.new()
	g.face = face_c
	g.haze_color = haze_c
	g.haze = hz
	g.font = FTFKit.font("mono")
	g.lamp_period = BEAT
	g.lod_px = 6.0
	g.lod_band = 2.2
	g.rest_chance = 0.35
	return g


## A part's contours in world space (svg units * k + tl).
func _contours(data: MotionSvgData, parts: Array, k: float, tl: Vector2) -> Array:
	var out := []
	for i in parts:
		for c in data.outline(int(i), 0.25):
			var pts := PackedVector2Array()
			for p in (c as PackedVector2Array):
				pts.append(tl + p * k)
			out.append(pts)
	return out


func _build() -> void:
	_built = true
	_mh = _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_ftf = _svg(FTFKit.LOGO)
	_k_mh = MH_W / _mh.view_box.size.x
	_k_ftf = LOGO_W / _ftf.view_box.size.x
	_ftf_tl = Vector2(X0, -8.0) - _ftf.view_box.size * _k_ftf * 0.5

	_g_far = _greebler(STONE, HAZE_DAY, 0.5)
	_g_far.max_level = 3
	_g_back = _greebler(STONE, HAZE_DAY, 0.0)
	_g_mid = _greebler(STONE, HAZE_DAY, 0.0)
	_g_front = _greebler(FTFKit.PINK, HAZE_DAY, 0.0)
	_g_fg = _greebler(STONE_FG, Color("#2a3240"), 0.32)
	_g_doors = _greebler(Color("#cdc6b8"), Color("#0b0d12"), 0.0)
	_g_doors.lamp_period = 12.0

	_build_mh_world()
	_build_ftf_world()
	_build_far()
	_build_fg()
	_build_doors()

	# ---- nodes, back to front
	_sky = MotionGradient.linear(size, 180.0, [SKY_TOP, SKY_MID, SKY_LOW], [0.0, 0.55, 1.0])
	add_child(_sky)
	_sun = MotionShape.circle(150, Color("#fff8e6"))
	_sun.blur = 120.0
	add_child(_sun)
	_far = _canvas(self, _draw_far)
	_stage = Node2D.new()
	add_child(_stage)
	_back = _canvas(_stage, func(c: MotionCanvas, f: float) -> void: _layer_draw(_g_back, c, f, D_MAIN))
	_mh_svg = MotionSvg.new()
	_mh_svg.data = _mh
	_mh_svg.width = MH_W
	_stage.add_child(_mh_svg)
	_ftf_plate = MotionSvg.new()
	_ftf_plate.data = _ftf
	_ftf_plate.width = LOGO_W
	_ftf_plate.only = PackedInt32Array([0, 1])
	_stage.add_child(_ftf_plate)
	_mid = _canvas(_stage, func(c: MotionCanvas, f: float) -> void: _layer_draw(_g_mid, c, f, D_MAIN))
	_ftf_svg = MotionSvg.new()
	_ftf_svg.data = _ftf
	_ftf_svg.width = LOGO_W
	var rest := PackedInt32Array()
	for i in range(2, _ftf.parts.size()):
		rest.append(i)
	_ftf_svg.only = rest
	_stage.add_child(_ftf_svg)
	_front = _canvas(_stage, _draw_front)
	_pres_node = Node2D.new()
	_stage.add_child(_pres_node)
	_presents = FTFKit.text(_pres_node, "mono", 44, FTFKit.MH_AMBER, "PRESENTS", 0.34)
	_presents.position = -_presents.get_text_size() * 0.5
	_front2 = _canvas(_stage, _draw_front2)
	_fg = _canvas(_stage, func(c: MotionCanvas, f: float) -> void: _layer_draw(_g_fg, c, f, D_FG))
	_doors = _canvas(self, _draw_doors)
	for i in 2:
		var bgr := ColorRect.new()
		bgr.color = Color("#1d1b19")
		add_child(bgr)
		_hud_bg.append(bgr)
	var h1 := FTFKit.text(self, "mono", 22, FTFKit.CREAM, "SKY CITY 7 // HULL PLATE F-01 // FULL THROTTLE FLUX", 0.12)
	h1.position = Vector2(96, 1004)
	var h2 := FTFKit.text(self, "jp", 26, FTFKit.ORANGE, "フルスロットル・フラックス")
	h2.position = Vector2(96, 962)
	var h3 := FTFKit.text(self, "mono", 22, FTFKit.CREAM, "75 BPM // 4/4 // SECTOR 7", 0.12)
	h3.position = Vector2(1824 - h3.get_text_size().x, 1004)
	_hud = [h1, h2, h3]
	var w1 := maxf(h1.get_text_size().x, h2.get_text_size().x)
	_hud_bg[0].position = Vector2(76, 950)
	_hud_bg[0].size = Vector2(w1 + 40, 92)
	_hud_bg[1].position = Vector2(h3.position.x - 20, 990)
	_hud_bg[1].size = Vector2(h3.get_text_size().x + 40, 52)
	_fade = ColorRect.new()
	_fade.size = size
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_add_sound()


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_greebles/audio/greeble_map.tres"
	const SONG := "res://demo/ftf/ftf_greebles/audio/music/greeble_song.tres"
	const TRACK := "res://demo/ftf/ftf_greebles/audio/ftf_greebles_track.res"
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
		var pl := AudioStreamPlayer.new()
		pl.stream = load(TRACK)
		add_child(pl)
		audio = pl
		clock = Clock.AUDIO


func _canvas(parent: Node, fn: Callable) -> MotionCanvas:
	var c := MotionCanvas.new()
	c.draw_fn = fn
	parent.add_child(c)
	return c


func _track(g: MotionGreebler, id: int, mh: bool) -> int:
	if mh:
		_mh_list.append([g, id])
	else:
		_ftf_ids.append([g, id])
	return id


func _build_mh_world() -> void:
	# The lockup as stone: the red back layer's sides, every letter's sides,
	# then detail on the monogram's front face and on the letters.
	var red := _contours(_mh, [0], _k_mh, MH_TL)
	_red_sides = _track(_g_back, _g_back.add_sides(red, 26.0, {side_lit = FTFKit.MH_RED.darkened(0.2), side_dark = FTFKit.MH_RED.darkened(0.55)}), true)
	var letters := _contours(_mh, range(3, 16), _k_mh, MH_TL)
	_track(_g_back, _g_back.add_sides(letters, 18.0), true)
	var mono := _contours(_mh, [2], _k_mh, MH_TL)
	_track(_g_mid, _g_mid.add_detail(mono, {seed = 3.0, max_level = 6, min_size = 1.6, face = FTFKit.MH_CREAM, lod = 4.0, rest_chance = 0.2}), true)
	for i in range(3, 16):
		_track(_g_mid, _g_mid.add_detail(_contours(_mh, [i], _k_mh, MH_TL), {seed = 10.0 + i, max_level = 4, min_size = 2.0, face = FTFKit.MH_CREAM, greeble_chance = 0.6, lod = 6.5}), true)
	_p0 = _thickest(mono)

	# Plinth with the PRESENTS hatch, hanging tanks, two framing structures.
	_track(_g_back, _g_back.add_rect(Rect2(-700, 205, 1400, 130), 46.0, 34.0, {seed = 21.0, max_level = 4, min_size = 4.0, lod = 1.8, rest_chance = 0.45}), true)
	for x in [-520.0, -180.0, 420.0]:
		_track(_g_back, _g_back.add_rect(Rect2(x, 335, 46, 140 + MK.rand(x) * 120.0), 18.0, 10.0, {seed = x * 0.1, max_level = 3, min_size = 3.0}), true)
	_track(_g_back, _g_back.add_block(PackedVector2Array([Vector2(520, -1100), Vector2(1700, -1100), Vector2(1700, -380), Vector2(1560, -290), Vector2(720, -290), Vector2(520, -470)]), 64.0, {seed = 31.0, max_level = 4, min_size = 5.0}), true)
	_track(_g_back, _g_back.add_rect(Rect2(-1650, 420, 760, 520), 54.0, 60.0, {seed = 41.0, max_level = 4, min_size = 5.0}), true)
	_track(_g_back, _g_back.add_rect(Rect2(-1500, -760, 380, 260), 40.0, 40.0, {seed = 43.0, max_level = 3, min_size = 5.0}), true)


## The point of a shape farthest from its outline (sampled).
func _thickest(contours: Array) -> Vector2:
	var b := MotionPoly.bounds_all(contours)
	var best := b.get_center()
	var best_d := -1.0
	for iy in 24:
		for ix in 24:
			var p := b.position + Vector2((ix + 0.5) / 24.0 * b.size.x, (iy + 0.5) / 24.0 * b.size.y)
			if MotionPoly.count_containing(contours, p) % 2 == 0:
				continue
			var dmin := INF
			for c in contours:
				var pts: PackedVector2Array = c
				for j in pts.size():
					var q := Geometry2D.get_closest_point_to_segment(p, pts[j], pts[(j + 1) % pts.size()])
					dmin = minf(dmin, p.distance_to(q))
			if dmin > best_d:
				best_d = dmin
				best = p
	return best


func _build_ftf_world() -> void:
	var o := Vector2(X0, 0)
	# The hull plate: its pink rim's outer contour extruded deep; raised letters.
	var rim := _contours(_ftf, [1], _k_ftf, _ftf_tl)
	rim.sort_custom(func(x: PackedVector2Array, y: PackedVector2Array) -> bool: return absf(MotionPoly.signed_area(x)) > absf(MotionPoly.signed_area(y)))
	var outer: PackedVector2Array = rim[0]
	var inner: PackedVector2Array = rim[1] if rim.size() > 1 else rim[0]
	_plate_outline = outer
	_track(_g_back, _g_back.add_sides([outer], 44.0, {side_lit = FTFKit.PINK.darkened(0.15), side_dark = FTFKit.PINK.darkened(0.55)}), false)
	var pink_parts := [2, 3, 4, 5, 6, 7, 8] + range(13, 25)
	var white_parts := [9, 10, 11, 12] + range(25, 45)
	_track(_g_mid, _g_mid.add_sides(_contours(_ftf, pink_parts, _k_ftf, _ftf_tl), 7.0, {side_lit = FTFKit.PINK.darkened(0.3), side_dark = FTFKit.PINK.darkened(0.6)}), false)
	_track(_g_mid, _g_mid.add_sides(_contours(_ftf, white_parts, _k_ftf, _ftf_tl), 5.0, {side_lit = Color("#c9b9c0"), side_dark = Color("#8f7a86")}), false)
	# Panels and greebles on the plate's free face, clear of every letter.
	var all_letters := _contours(_ftf, range(2, _ftf.parts.size()), _k_ftf, _ftf_tl)
	_track(_g_mid, _g_mid.add_detail([inner], {seed = 51.0, max_level = 4, min_size = 3.0, avoid = all_letters, margin = 7.0, face = Color("#f6f4ee"), depth_k = 0.7, lod = 4.5, rest_chance = 0.5}), false)
	# Painted seams on the pink tab, clear of its white type.
	_track(_g_front, _g_front.add_detail(_contours(_ftf, [8], _k_ftf, _ftf_tl), {seed = 57.0, max_level = 2, min_size = 5.0, avoid = _contours(_ftf, white_parts, _k_ftf, _ftf_tl), margin = 5.0, greeble_chance = 0.3, depth_k = 0.5, lod = 2.2}), false)

	# Superstructure: overhang, pylons, deck, hanging gear, clamps.
	var ov := PackedVector2Array([Vector2(-1750, -1200), Vector2(1750, -1200), Vector2(1750, -440), Vector2(1470, -300), Vector2(-1470, -300), Vector2(-1750, -440)])
	for i in ov.size():
		ov[i] += o
	_track(_g_back, _g_back.add_block(ov, 72.0, {seed = 61.0, max_level = 5, min_size = 4.0}), false)
	for sx in [-1.0, 1.0]:
		var r := Rect2(o.x + (-1190.0 if sx < 0 else 860.0), -300, 330, 1300)
		_track(_g_back, _g_back.add_rect(r, 52.0, 44.0, {seed = 63.0 + sx, max_level = 5, min_size = 4.0}), false)
	_track(_g_back, _g_back.add_rect(Rect2(o.x - 1350, 330, 2700, 200), 54.0, 60.0, {seed = 67.0, max_level = 5, min_size = 4.0}), false)
	for i in 7:
		var x := -1050.0 + i * 330.0 + (MK.rand(i * 3.1) - 0.5) * 120.0
		var w := 40.0 + MK.rand(i * 5.7) * 90.0
		var hh := 120.0 + MK.rand(i * 7.3) * 260.0
		_track(_g_back, _g_back.add_rect(Rect2(o.x + x, 530, w, hh), 22.0, w * 0.25, {seed = 70.0 + i, max_level = 3, min_size = 3.0}), false)
	_clamp_l = _track(_g_back, _g_back.add_rect(Rect2(o.x - 880, -54, 128, 108), 26.0, 16.0, {seed = 81.0, max_level = 3, min_size = 3.0}), false)
	_clamp_r = _track(_g_back, _g_back.add_rect(Rect2(o.x + 752, -54, 128, 108), 26.0, 16.0, {seed = 83.0, max_level = 3, min_size = 3.0}), false)
	# The sky city around it, seen in the pull-out.
	for i in 34:
		var a := MK.rand(i * 1.37 + 0.2) * TAU
		var rad := 2100.0 + MK.rand(i * 2.91) * 3400.0
		var c := o + Vector2(cos(a) * rad * 1.35, sin(a) * rad * 0.75 - 300.0)
		var w2 := 300.0 + MK.rand(i * 4.7) * 1100.0
		var h2 := 140.0 + MK.rand(i * 6.1) * 900.0
		_track(_g_back, _g_back.add_rect(Rect2(c - Vector2(w2, h2) * 0.5, Vector2(w2, h2)), 30.0 + h2 * 0.05, minf(w2, h2) * 0.18, {seed = 90.0 + i, max_level = 3, min_size = 8.0}), false)


func _build_far() -> void:
	# Distant structures for both regions, behind haze (far layer coordinates).
	for rg in [Vector2(0, 0), Vector2(X0, 0)]:
		var region: Vector2 = rg
		for i in 26:
			var sd := i * 1.91 + region.x * 0.0001
			var x := region.x + (MK.rand(sd) - 0.5) * 9000.0
			var y := (MK.rand(sd + 3.3) - 0.5) * 3600.0 + 300.0
			var w := 300.0 + MK.rand(sd + 5.1) * 1200.0
			var h := 120.0 + MK.rand(sd + 7.7) * 900.0
			_g_far.add_rect(Rect2(x - w * 0.5, y - h * 0.5, w, h), 26.0 + h * 0.04, minf(w, h) * 0.2, {seed = 200.0 + sd, max_level = 3, min_size = 10.0})


func _build_fg() -> void:
	# Big near chunks framing the corners (foreground layer coordinates).
	for rg in [Vector2(0, 0), Vector2(X0, 0)]:
		var region: Vector2 = rg
		_g_fg.add_block(_shift(PackedVector2Array([Vector2(-1150, -1000), Vector2(-420, -1000), Vector2(-420, -360), Vector2(-560, -220), Vector2(-1150, -220)]), region), 60.0, {seed = 301.0 + region.x * 0.001, max_level = 4, min_size = 3.0})
		_g_fg.add_block(_shift(MotionGreebler.chamfered(Rect2(480, 360, 700, 520), 70.0), region), 60.0, {seed = 307.0 + region.x * 0.001, max_level = 4, min_size = 3.0})


func _shift(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in p:
		out.append(q + d)
	return out


func _build_doors() -> void:
	# Blast doors in screen space: two halves split along a diagonal seam.
	var left := PackedVector2Array([Vector2(-40, -40), Vector2(1010, -40), Vector2(905, 1120), Vector2(-40, 1120)])
	var right := PackedVector2Array([Vector2(1010, -40), Vector2(1960, -40), Vector2(1960, 1120), Vector2(905, 1120)])
	_door_l.append(_g_doors.add_block(left, 0.0, {seed = 401.0, max_level = 4, min_size = 7.0}))
	_door_r.append(_g_doors.add_block(right, 0.0, {seed = 409.0, max_level = 4, min_size = 7.0}))
	# a pink band and hazard bands across both, riding with their halves
	var bl := _g_doors.new_structure()
	_g_doors.add_item(bl, MotionGreebler.Kind.HAZARD, Rect2(-40, 470, 990, 56), 0)
	_g_doors.add_item(bl, MotionGreebler.Kind.STENCIL, Rect2(120, 560, 360, 120), 0, {txt = "F-01", c = FTFKit.PINK})
	_door_l.append(bl)
	var br := _g_doors.new_structure()
	_g_doors.add_item(br, MotionGreebler.Kind.HAZARD, Rect2(960, 470, 1000, 56), 0)
	_g_doors.add_item(br, MotionGreebler.Kind.STENCIL, Rect2(1380, 560, 420, 120), 0, {txt = "FTF", c = FTFKit.PINK})
	_door_r.append(br)


# ================================================================== camera

## Main-layer camera: [centre (world), scale].
func _camera(f: float) -> Array:
	if f < DROP:
		var s1b := S1 * 1.07
		if f <= PULL_END:
			var u := MK.map(f, [0, PULL_END], [0, 1], MK.bezier(0.3, 0.0, 0.12, 1.0))
			var s := exp(lerpf(log(S0), log(S1), u))
			var end_scr := (_p0 - C1) * S1 + SC
			var scr := SC.lerp(end_scr, u)
			return [_p0 - (scr - SC) / s, s]
		var drift := Vector2(-24.0 * MK.map(f, [PULL_END, DIVE], [0, 1], MK.ease_in_out), 0)
		var sd := lerpf(S1, s1b, MK.map(f, [PULL_END, DIVE], [0, 1], MK.ease_in_out))
		if f <= DIVE:
			return [C1 + drift, sd]
		var cd := C1 + Vector2(-24, 0)
		var u2 := pow(MK.map(f, [DIVE, DOORS_ON], [0, 1], MK.linear), 1.7)
		var s2 := exp(lerpf(log(s1b), log(90.0), u2))
		var start_scr := (T_DIVE - cd) * s1b + SC
		var scr2 := start_scr.lerp(SC, MK.ease_out.call(minf(1.0, u2 * 1.6)))
		return [T_DIVE - (scr2 - SC) / s2, s2]
	var t := f - DROP
	var drift2 := Vector2(46.0 * sin(t / 52.0), 14.0 * sin(t / 77.0 + 1.0))
	if f < OUT:
		var s3 := lerpf(1.18, 1.0, MK.map(f, [DROP, DROP + 18.0], [0, 1], MK.ease_out))
		s3 *= lerpf(1.0, 1.1, MK.map(f, [HUD_AT, OUT], [0, 1], MK.ease_in_out))
		return [C2 + drift2, s3]
	var u3 := MK.map(f, [OUT, CUT + 4.0], [0, 1], MK.ease_in_out)
	var d_out := Vector2(46.0 * sin((OUT - DROP) / 52.0), 14.0 * sin((OUT - DROP) / 77.0 + 1.0))
	return [(C2 + d_out).lerp(C2 + Vector2(0, -320), u3), exp(lerpf(log(1.1), log(0.16), u3))]


## Scale of a layer at depth `d` for the current camera.
func _layer_s(d: float) -> float:
	var z := D_MAIN - F_LEN / _cam_s
	var dist := d - z
	if dist < 40.0:
		return -1.0
	return F_LEN / dist


func _layer_origin(s: float) -> Vector2:
	return SC - _cam_c * s


func _layer_draw(g: MotionGreebler, c: MotionCanvas, f: float, d: float) -> void:
	var s := _layer_s(d)
	if s <= 0.0:
		return
	g.draw(c, s, _layer_origin(s), f)


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	var cam := _camera(f)
	_cam_c = cam[0]
	_cam_s = cam[1]
	_shake = MK.shakes(f, [DROP], 26, 10) + MK.shakes(f, [CLAMP], 14, 8) + MK.shakes(f, [SETTLE], 5, 8)
	_stage.position = _shake
	# the near layer fades in as it comes out from behind the camera
	_fg.modulate.a = clampf((D_FG - (D_MAIN - F_LEN / _cam_s) - 40.0) / 220.0, 0.0, 1.0)

	var mh_on := f < DROP
	for e in _mh_list:
		(e[0] as MotionGreebler).set_visible(int(e[1]), mh_on)
	for e in _ftf_ids:
		(e[0] as MotionGreebler).set_visible(int(e[1]), not mh_on)

	# ---- sky, haze and light over time
	var dusk := MK.map(f, [OUT, CUT], [0, 1], MK.ease_in_out)
	_sky.colors = PackedColorArray([SKY_TOP.lerp(DUSK_TOP, dusk), SKY_MID.lerp(DUSK_MID, dusk), SKY_LOW.lerp(DUSK_LOW, dusk)])
	var hz_col := HAZE_DAY.lerp(HAZE_DUSK, dusk)
	for g in [_g_far, _g_back, _g_mid, _g_front]:
		(g as MotionGreebler).haze_color = hz_col
	_g_far.haze = 0.5 + 0.2 * dusk
	var main_hz := 0.42 * MK.map(f, [OUT, CUT], [0, 1], MK.ease_in_quad)
	_g_back.haze = main_hz
	_g_mid.haze = main_hz
	_g_front.haze = main_hz
	var lamps := 1.0 - MK.map(f, [CUT, CUT + 6.0], [0, 1], MK.linear)
	for g in [_g_far, _g_back, _g_mid, _g_front, _g_fg]:
		(g as MotionGreebler).lamp_level = lamps
	_sun.position = Vector2(300, 170).lerp(Vector2(380, 900), dusk)
	_sun.modulate.a = 1.0 - 0.3 * dusk
	var tint := Color.WHITE.lerp(Color("#8e86a6"), dusk * 0.6)
	for n in [_mh_svg, _ftf_plate, _ftf_svg]:
		(n as CanvasItem).modulate = tint

	# ---- the cascade of detail after the drop
	if f >= DROP and f < CASCADE_END + 30.0:
		var front := MK.map(f, [DROP, CASCADE_END], [0, 4200], MK.ease_in_quad)
		for g in [_g_back, _g_mid, _g_front]:
			var gg: MotionGreebler = g
			gg.reveal_origin = Vector2(X0, -8)
			gg.reveal_front = front
			gg.reveal_soft = 500.0
	else:
		for g in [_g_back, _g_mid, _g_front]:
			(g as MotionGreebler).reveal_front = INF

	# ---- MH layers slide home; the lockup's svg follows the camera
	var red_off := Vector2(40, 40) * (1.0 - MK.map(f, [LAYER_AT[0] - 16.0, LAYER_AT[0]], [0, 1], MK.ease_in_quad))
	var amb_off := Vector2(30, 30) * (1.0 - MK.map(f, [LAYER_AT[1] - 16.0, LAYER_AT[1]], [0, 1], MK.ease_in_quad))
	_g_back.set_offset(_red_sides, red_off)
	var s := _cam_s
	var org := _layer_origin(s)
	_mh_svg.visible = mh_on
	if mh_on:
		_mh_svg.position = MH_TL * s + org
		_mh_svg.scale = Vector2(s, s)
		var kk := _k_mh
		_mh_svg.apply(func(i: int) -> Variant:
			if i == 0:
				return {tx = red_off.x / kk, ty = red_off.y / kk}
			if i == 1:
				return {tx = amb_off.x / kk, ty = amb_off.y / kk}
			return {})
	_ftf_plate.visible = not mh_on and f < BLACK
	_ftf_svg.visible = _ftf_plate.visible
	if _ftf_plate.visible:
		_ftf_plate.position = _ftf_tl * s + org
		_ftf_plate.scale = Vector2(s, s)
		_ftf_svg.position = _ftf_plate.position
		_ftf_svg.scale = _ftf_plate.scale

	# ---- clamps
	var cl := 1.0 - MK.map(f, [CLAMP - 8.0, CLAMP], [0, 1], MK.ease_in_quad)
	var rebound := 6.0 * exp(-(f - CLAMP) * 0.35) * sin((f - CLAMP) * 0.9) if f >= CLAMP else 0.0
	_g_back.set_offset(_clamp_l, Vector2(-90.0 * cl - rebound, 0))
	_g_back.set_offset(_clamp_r, Vector2(90.0 * cl + rebound, 0))

	# ---- PRESENTS
	var open := MK.map(f, [HATCH, HATCH + 14.0], [0, 1], MK.ease_in_out)
	_pres_node.visible = mh_on and open > 0.2
	_pres_node.position = Vector2(-70, 267) * s + org
	_pres_node.scale = Vector2(s, s)
	var lit := MK.map(f, [PRESENTS_AT, PRESENTS_AT + 4.0], [0, 1], MK.linear)
	_presents.modulate.a = 0.15 + 0.85 * lit
	_presents.tracking = lerpf(0.6, 0.34, MK.prog(f, PRESENTS_AT, 18))

	# ---- doors
	var e := MK.map(f, [DROP, DROP + 9.0], [0, 1], MK.bezier(0.1, 0.8, 0.3, 1.0))
	for id in _door_l:
		_g_doors.set_offset(id, Vector2(-1250.0 * e, -40.0 * e))
	for id in _door_r:
		_g_doors.set_offset(id, Vector2(1250.0 * e, 40.0 * e))
	_doors.visible = f >= DOORS_ON - 1.0 and f < DROP + 10.0
	var dl := MK.map(f, [DOORS_ON - 1.0, DOORS_ON + 6.0], [0, 1], MK.ease_out)
	_doors.modulate = Color(0.35 + 0.65 * dl, 0.35 + 0.65 * dl, 0.38 + 0.62 * dl, dl)
	# the doors creep closer in the dark until they split
	var creep := 1.0 + 0.06 * MK.map(f, [DOORS_ON, DROP], [0, 1], MK.ease_in_quad)
	_doors.scale = Vector2(creep, creep)
	_doors.position = SC * (1.0 - creep)

	# ---- HUD
	var hud_in := MK.prog(f, HUD_AT, 10)
	var hud_out := 1.0 - MK.prog(f, OUT, 10)
	for i in _hud.size():
		var t: MotionText = _hud[i]
		t.visible = f >= HUD_AT and f < OUT + 12.0
		t.modulate.a = hud_in * hud_out
		t.visible_chars = int(MK.map(f, [HUD_AT + i * 4.0, HUD_AT + 20.0 + i * 4.0], [0, 60], MK.linear))
	for i in _hud_bg.size():
		var bgr := _hud_bg[i]
		bgr.visible = f >= HUD_AT and f < OUT + 12.0
		bgr.scale = Vector2(MK.map(f, [HUD_AT - 2.0, HUD_AT + 6.0], [0, 1], MK.ease_out), 1.0)
		bgr.modulate.a = 0.9 * hud_out

	# ---- fades
	var a_in := 1.0 - MK.map(f, [0, 14], [0, 1], MK.ease_out)
	var a_out := MK.map(f, [CUT, BLACK], [0, 1], MK.ease_in_out)
	_fade.color.a = maxf(a_in, a_out)
	_fade.visible = _fade.color.a > 0.002


# ================================================================== drawing

func _draw_far(c: MotionCanvas, f: float) -> void:
	var s := _layer_s(D_FAR)
	if s > 0.0:
		_g_far.draw(c, s, _layer_origin(s), f)
	# clouds between the far city and the main layer
	var sc := _layer_s(D_CLOUD)
	if sc <= 0.0:
		return
	var org := _layer_origin(sc)
	var dusk := MK.map(f, [OUT, CUT], [0, 1], MK.ease_in_out)
	var col := Color("#ffffff").lerp(Color("#b48aa0"), dusk)
	for rg in [0.0, X0]:
		var region: float = rg
		for i in 9:
			var base := Vector2(region + (MK.rand(i * 3.7 + region * 0.001) - 0.5) * 5200.0 + f * (0.6 + MK.rand(i * 1.3) * 0.8), (MK.rand(i * 5.9) - 0.5) * 1900.0 + 200.0)
			var size_k := 160.0 + MK.rand(i * 7.1) * 260.0
			for b in 6:
				var off := Vector2((MK.rand(i * 11.0 + b) - 0.5) * size_k * 2.4, (MK.rand(i * 13.0 + b) - 0.5) * size_k * 0.5)
				var r := size_k * (0.5 + 0.5 * MK.rand(i * 17.0 + b)) * sc
				var p := (base + off) * sc + org
				if p.x < -r * 2.0 or p.x > W + r * 2.0 or p.y < -r * 2.0 or p.y > H + r * 2.0:
					continue
				for ring in 4:
					c.draw_circle(p, r * (1.0 - ring * 0.18), Color(col, 0.07))


func _draw_front(c: MotionCanvas, f: float) -> void:
	var s := _cam_s
	var org := _layer_origin(s)
	_g_front.draw(c, s, org, f)
	if f >= DROP:
		return
	# the hatch recess, its lamp row
	var open := MK.map(f, [HATCH, HATCH + 14.0], [0, 1], MK.ease_in_out)
	if open <= 0.0:
		return
	var hr := Rect2(HATCH_R.position * s + org, HATCH_R.size * s)
	c.draw_rect(hr, Color("#1a1510"))
	c.draw_rect(Rect2(hr.position, Vector2(hr.size.x, hr.size.y * 0.12)), Color("#0c0a07"))
	var lit := MK.map(f, [PRESENTS_AT, PRESENTS_AT + 4.0], [0, 1], MK.linear)
	for i in 15:
		var x := HATCH_R.position.x + 24.0 + i * 43.0
		var p := Vector2(x, HATCH_R.end.y - 7.0) * s + org
		var on := lit * (0.5 + 0.5 * float(fposmod(f / BEAT + i * 0.0667, 1.0) < 0.5))
		c.draw_circle(p, 6.0 * s, Color(FTFKit.MH_AMBER, 0.18 * on))
		c.draw_circle(p, 2.2 * s, Color("#3a2c1a").lerp(Color("#ffd27a"), on))


func _draw_front2(c: MotionCanvas, f: float) -> void:
	var s := _cam_s
	var org := _layer_origin(s)
	_draw_drones(c, f)
	if f < DROP:
		# hatch doors retracting into the plinth
		var open := MK.map(f, [HATCH, HATCH + 14.0], [0, 1], MK.ease_in_out)
		if open < 1.0:
			var hw := HATCH_R.size.x * 0.5 * (1.0 - open)
			for side in [0, 1]:
				var r := Rect2(HATCH_R.position.x if side == 0 else HATCH_R.end.x - hw, HATCH_R.position.y, hw, HATCH_R.size.y)
				var sr := Rect2(r.position * s + org, r.size * s)
				if sr.size.x <= 0.5:
					continue
				c.draw_rect(sr, Color("#d9d2c4"))
				c.draw_rect(Rect2(sr.position, Vector2(sr.size.x, 2.0 * s)), Color("#fbf9f2"))
				c.draw_rect(Rect2(sr.position.x, sr.end.y - 3.0 * s, sr.size.x, 3.0 * s), Color("#9aaab8"))
				var edge := sr.end.x - 10.0 * s if side == 0 else sr.position.x
				c.draw_rect(Rect2(edge, sr.position.y, 10.0 * s, sr.size.y), FTFKit.ORANGE)
		return
	# glint across the plate on bar 4
	var g := MK.map(f, [CLAMP + 2.0, CLAMP + 26.0], [0, 1], MK.ease_in_out)
	if g > 0.0 and g < 1.0:
		var plate := PackedVector2Array()
		for p in _plate_outline:
			plate.append(p * s + org)
		var bx := lerpf(-500.0, 2400.0, g)
		var band := PackedVector2Array([Vector2(bx, -200), Vector2(bx + 240, -200), Vector2(bx - 180, 1300), Vector2(bx - 420, 1300)])
		for poly in Geometry2D.intersect_polygons(band, plate):
			c.draw_colored_polygon(poly, Color(1, 1, 1, 0.5 * sin(g * PI)))
	# steam where the clamps bite
	if f >= CLAMP and f < CLAMP + 30.0:
		var t := (f - CLAMP) / 30.0
		for side in [-1.0, 1.0]:
			for i in 6:
				var p := Vector2(X0 + side * 760.0, -10.0 + (i - 2.5) * 16.0) + Vector2(side * (30.0 + i * 9.0) * t * 2.0, -60.0 * t * (0.5 + MK.rand(i * 2.3)))
				var r := (16.0 + 40.0 * t) * (0.6 + 0.6 * MK.rand(i * 3.1 + side)) * s
				c.draw_circle(p * s + org, r, Color(1, 1, 1, 0.22 * (1.0 - t)))


func _draw_drones(c: MotionCanvas, f: float) -> void:
	var paths := [
		[MH_DRONES[0], 60.0, Vector2(-1400, -300), Vector2(1300, -380), 1300.0],
		[MH_DRONES[1], 40.0, Vector2(1100, 520), Vector2(-900, 420), 860.0],
		[DRONES[0], 64.0, Vector2(X0 - 1300, -230), Vector2(X0 + 1300, -260), D_MAIN],
		[DRONES[1], 70.0, Vector2(X0 + 1500, -620), Vector2(X0 - 1400, -520), 1500.0],
		[DRONES[2], 46.0, Vector2(X0 - 900, 900), Vector2(X0 + 600, 120), 820.0],
	]
	for d in paths:
		var t0: float = d[0]
		var dur: float = d[1]
		var u := (f - t0) / dur
		if u < 0.0 or u > 1.0:
			continue
		var s := _layer_s(float(d[4]))
		if s <= 0.0:
			continue
		var org := _layer_origin(s)
		var a: Vector2 = d[2]
		var b: Vector2 = d[3]
		var dirv := (b - a).normalized()
		for k in 10:
			var uu := u - k * 0.012
			if uu < 0.0:
				break
			c.draw_circle(a.lerp(b, uu) * s + org, (4.0 - k * 0.3) * s, Color(1, 1, 1, 0.2 * (1.0 - k / 10.0)))
		var p := a.lerp(b, u) * s + org
		var side := dirv.orthogonal()
		var len := 58.0 * s
		var wid := 15.0 * s
		var body := PackedVector2Array([p + dirv * len, p + side * wid - dirv * len * 0.8, p - dirv * len * 0.6, p - side * wid - dirv * len * 0.8])
		c.draw_colored_polygon(body, Color("#e9e4d8"))
		c.draw_line(p - dirv * len * 0.6, p + dirv * len, Color("#8fa0b0"), maxf(1.0, wid * 0.35))
		c.draw_circle(p - dirv * len * 0.7, wid * 0.7, Color(FTFKit.CYAN, 0.6))
		var blink := fposmod(f / 12.0, 1.0) < 0.3
		if blink:
			c.draw_circle(p + side * wid, wid * 0.4, Color("#fff4cc"))


func _draw_doors(c: MotionCanvas, f: float) -> void:
	_g_doors.draw(c, 1.0, _shake, f)
	# a light seam where the halves part
	if f < DROP:
		var w := 2.0 + 10.0 * MK.map(f, [DOORS_ON, DROP], [0, 1], MK.ease_in_quad)
		var pulse := 0.6 + 0.4 * absf(sin((f - DOORS_ON) * PI / 6.0))
		c.draw_line(Vector2(1010, -40) + _shake, Vector2(905, 1120) + _shake, Color(1.0, 0.82, 0.55, 0.35 * pulse), w * 3.0)
		c.draw_line(Vector2(1010, -40) + _shake, Vector2(905, 1120) + _shake, Color(1.0, 0.95, 0.85, 0.9 * pulse), w)
