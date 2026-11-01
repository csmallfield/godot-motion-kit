# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take "INSANE SUBWAY MAP".
#
# Brief: a night transit diagram that draws itself and gets absurdly dense.
# Octilinear lines (0/45/90 degrees) with rounded, concentric bends run in
# bundles, with interchanges, station ticks, invented station names (F-9000
# world, katakana), trains and a legend. MINIMAL HUMANS is written by a route:
# every stroke is three parallel lines stacked like the M monogram's layers
# (red, amber, cream). From its PRESENTS station the pink Flux Line departs and
# the camera rides its head through the network as it explodes in density, into
# an inset box where the FTF logo is formed by lines: concentric contour lines
# fill every letter, a bundle of four lines rings the plate. It lands complete
# and big on the drop. The hold keeps running: trains circle the letters, a
# light chases round every contour on each beat, expresses race the rim, and
# new lines keep drawing at the edges. Out: the doors close, every line
# retracts, the map zooms out to one station dot, which blips out. Black.
#
# Tempo: 150 bpm = 12 frames a beat, 48 a bar, first downbeat at frame 0
# (drop on bar 4, frame 192 = 6.4 s). Replacement music: 150 bpm from 0.0 s.
#
# Beats (30 fps, 420 frames):
#   0/12/24/36   first lines draw on along two corridors (camera close)
#   48-94        MINIMAL HUMANS drawn as triple routes, left to right
#   96           word complete: station chime; trains start on the letters
#   108          PRESENTS station; 114/126/138 more lines draw at the edges
#   144          the network explodes: lines on every eighth to 186
#   146-180      the pink Flux Line draws; the camera rides its head
#   166          the inset box opens; 170-191 the logo's lines draw on
#   192          DROP: the logo is complete and big, network dims, shake
#   192-336      hold: beat chases, trains, expresses at 240 and 288,
#                station label at 216, edge lines keep drawing
#   324/327/330  doors-closing beeps
#   336-366      every line retracts; 340-372 zoom out to one dot
#   384          the dot blips out; black to 420
@tool
extends MotionComposition

const BPM := 150.0
const BEAT := 12.0
const BAR := 48.0

const WAVE_A := [0.0, 12.0, 24.0, 36.0]
const MH_AT := 48.0
const MH_DONE := 96.0
const PRESENTS := 108.0
const WAVE_B := [114.0, 120.0, 126.0, 138.0]
const EXPLODE := 144.0
const PINK_ON := 146.0
const PINK_DONE := 180.0
const BOX_AT := 166.0
const LOGO_ON := 170.0
const DROP := 192.0
const LABEL_AT := 216.0
const EXPRESS := [240.0, 288.0]
const DOORS := [324.0, 327.0, 330.0]
const OUT := 336.0
const ZOOM_OUT := 340.0
const DOT := 372.0
const BLIP := 384.0
const END := 420

const W := 1920.0
const H := 1080.0
const CELL := 24.0
const M_C := Vector2(-1500, -800)      # centre of the MINIMAL HUMANS word (map px)
const L_C := Vector2(1104, 648)        # centre of the FTF logo (map px) = node (46, 27)
const LOGO_W := 1500.0
const P0 := Vector2i(-30, -17)         # PRESENTS station, where the pink line departs

const BG := Color("#0a0f1d")
const GRIDC := Color("#121a2e")
const RIVER := Color("#10203a")
const PANEL := Color("#0f182c")
const INK := Color("#05070d")
const LINE_COLS := [
	Color("#e2231a"), Color("#0a72c4"), Color("#00a650"), Color("#ffd200"), Color("#f58220"),
	Color("#9b4fb0"), Color("#b0703c"), Color("#00b1a9"), Color("#62c5f0"), Color("#8cc63f"),
	Color("#a7b0bd"),
]
const HUB_NAMES := [
	["MOABIT", "モアビット"], ["SPREE", "シュプレー"], ["FLUX CENTRAL", "フラックス"], ["THROTTLE", "スロットル"],
	["KESTREL YARD", "ケストレル"], ["SPARROW HTS", "スパロー"], ["STARLING", "スターリング"], ["UTOPIA", "ユートピア"],
	["CHEVRON", "シェブロン"], ["CHECKER SQ", "チェッカー"], ["HANGAR 9", "ハンガー"], ["MAGRAIL", "マグレール"],
	["NEON QUAY", "ネオンキー"], ["GRAVITY WELL", "グラビティ"], ["PYLON", "パイロン"], ["TURBINE", "タービン"],
	["APEX", "エイペックス"], ["VECTOR", "ベクター"], ["DELTA", "デルタ"], ["ORBIT", "オービット"],
	["PIT LANE", "ピットレーン"], ["BOOST PAD", "ブースト"], ["AIRBRAKE", "エアブレーキ"], ["SLIPSTREAM", "スリップ"],
	["PHOTON", "フォトン"], ["CIRCUIT", "サーキット"], ["TERMINAL", "ターミナル"], ["GRID", "グリッド"],
	["SKYPORT", "スカイポート"], ["DOCKS", "ドック"], ["MAGLEV", "マグレブ"], ["RAMP", "ランプ"],
	["SECTOR 7", "セクター"], ["PADDOCK", "パドック"], ["NOVA", "ノヴァ"], ["ZENITH", "ゼニス"],
	["HELIX", "ヘリックス"], ["CARGO", "カーゴ"], ["SIGNAL", "シグナル"], ["BEACON", "ビーコン"],
	["QUANTUM", "クオンタム"], ["ION", "イオン"], ["RADAR", "レーダー"], ["SPIRE", "スパイア"],
	["HARBOUR", "ハーバー"], ["NORTH GATE", "ノースゲート"], ["SOUTH GATE", "サウスゲート"], ["MONO", "モノ"],
	["ARC", "アーク"], ["CORE", "コア"], ["STATIC", "スタティック"], ["VOLT", "ボルト"],
	["LUMEN", "ルーメン"], ["AXIS", "アクシス"], ["FERRY", "フェリー"], ["MARKET", "マーケット"],
	["FOUNDRY", "ファウンドリー"], ["TOWER", "タワー"], ["PLAZA", "プラザ"], ["CANAL", "カナル"],
]
const ST_A := ["NORTH", "SOUTH", "EAST", "WEST", "UPPER", "LOWER", "OLD", "NEW", "GRAND", "LITTLE"]
const ST_B := ["MOABIT", "SPREE", "FLUX", "THROTTLE", "KESTREL", "SPARROW", "STARLING", "UTOPIA", "CHEVRON", "HANGAR",
	"MAGRAIL", "NEON", "PYLON", "TURBINE", "APEX", "VECTOR", "ORBIT", "BOOST", "PHOTON", "HELIX"]
const ST_C := ["YARD", "QUAY", "GATE", "PARK", "CROSS", "LOOP", "JCT", "HEIGHTS", "DOCKS", "MARKET", "ROAD", "SQ"]

const F_INTER9 := "res://demo/assets/fonts/inter-latin-900-normal.woff2"
const F_INTER7 := "res://demo/assets/fonts/inter-latin-700-normal.woff2"
const F_MONO := "res://demo/assets/fonts/space-mono-latin-700-normal.woff2"
const F_JP := "res://demo/ftf/ftf_subway/assets/noto-jp-subway-700.woff2"

var _built := false
var _stage: Node2D
var _cam: Node2D
var _map: MotionCanvas
var _logo_svg: MotionSvg
var _top: MotionCanvas
var _hud: MotionCanvas
var _mh_icon: MotionSvg
var _zoom := 1.0
var _view := Rect2()

var _f9: Font
var _f7: Font
var _fm: Font
var _fj: Font

var _net := MotionMetroMap.new()
var _mh := MotionMetroMap.new()
var _logo := MotionMetroMap.new()
var _river := MotionMetroMap.new()

var _net_on: Array[Vector2] = []        # per net line: (start frame, duration)
var _net_off: Array[float] = []         # per net line: retract start
var _net_wave: Array[int] = []          # 0 early, 1 explosion, 2 hold edges
var _pink := -1
var _hubs: Array[Dictionary] = []       # {node, name, jp, t}
var _stations: Array[Dictionary] = []   # {line, s, side, name, t}
var _trains: Array[Dictionary] = []     # {line, phase, speed, t}

var _mh_strokes: Array[Dictionary] = [] # {lines: [r, a, c], start}
var _word_rect := Rect2()

var _rings: Array[Dictionary] = []      # {line, s0, start, dur, col, depth, part}
var _rim: Array[int] = []
var _plate := PackedVector2Array()
var _small_band := Rect2()
var _checks: Array[Rect2] = []
var _ring_trains: Array[Dictionary] = []


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": DROP + BAR, "out": OUT}
	for i in WAVE_A.size():
		cue(WAVE_A[i], &"line", 0.5 + 0.1 * i, {pitch = [1.0, 1.12, 1.26, 1.5][i]})
	cue(MH_AT, &"mh.draw", 0.8)
	cue(MH_DONE, &"chime", 0.9)
	cue(PRESENTS, &"presents", 0.8)
	for i in WAVE_B.size():
		cue(WAVE_B[i], &"line", 0.45, {pitch = [1.68, 1.5, 1.26, 2.0][i]})
	cue(EXPLODE, &"explode", 1.0)
	for k in 7:
		cue(EXPLODE + 6.0 * (k + 1), &"burst", 0.5 + 0.06 * k, {pitch = [1.0, 1.12, 1.26, 1.5, 1.68, 2.0, 2.24][k]})
	cue(PINK_ON, &"pink", 0.9)
	cue(BOX_AT, &"box", 0.6)
	cue(DROP, &"riser", 1.0)           # its recipe swells in ahead and peaks here
	cue(DROP, &"drop", 1.0)
	cue(LABEL_AT, &"label", 0.6)
	for i in EXPRESS.size():
		cue(EXPRESS[i], &"express", 0.9 - 0.1 * i, {pitch = [1.0, 1.12][i]})
	for i in DOORS.size():
		cue(DOORS[i], &"door", 0.7)
	cue(OUT, &"retract", 0.9)
	cue(ZOOM_OUT + 4.0, &"zoomout", 0.8)
	cue(BLIP, &"blip", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _font(path: String) -> Font:
	var f := MotionFonts.font(path)
	if path != F_JP:
		var jp := MotionFonts.font(F_JP)
		if not f.fallbacks.has(jp):
			f.fallbacks = [jp]
	return f


func _build() -> void:
	_built = true
	_f9 = _font(F_INTER9)
	_f7 = _font(F_INTER7)
	_fm = _font(F_MONO)
	_fj = _font(F_JP)
	var bg := ColorRect.new()
	bg.color = INK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_cam = Node2D.new()
	_stage.add_child(_cam)
	_map = MotionCanvas.new()
	_map.draw_fn = _draw_map
	_cam.add_child(_map)
	_build_river()
	_build_mh()
	_build_network()
	_build_logo()
	_logo_svg = MotionSvg.new()
	_logo_svg.data = _svg(FTFKit.LOGO)
	_logo_svg.width = LOGO_W
	_logo_svg.only = PackedInt32Array(FTFKit.SMALL + FTFKit.CHECKS)
	_logo_svg.position = L_C - _logo_svg.data.view_box.size * (LOGO_W / _logo_svg.data.view_box.size.x) * 0.5
	_top = MotionCanvas.new()
	_top.draw_fn = _draw_top
	_cam.add_child(_top)
	_cam.add_child(_logo_svg)
	_hud = MotionCanvas.new()
	_hud.draw_fn = _draw_hud
	add_child(_hud)
	_mh_icon = MotionSvg.new()
	_mh_icon.data = _svg("res://demo/assets/logos/mh_icon.svg")
	_mh_icon.width = 54.0
	_mh_icon.position = Vector2(84, 846)
	add_child(_mh_icon)
	_add_sound()


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_subway/audio/subway_map.tres"
	const SONG := "res://demo/ftf/ftf_subway/audio/music/subway_song.tres"
	const TRACK := "res://demo/ftf/ftf_subway/audio/ftf_subway_track.res"
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


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _build_river() -> void:
	_river.cell = CELL
	_river.radius = 4.0
	_river.casing = 0.0
	_river.add_line(&"river", RIVER, [Vector2i(-130, 8), Vector2i(-82, 8), Vector2i(-68, 22), Vector2i(-32, 22),
		Vector2i(-18, 8), Vector2i(4, 8), Vector2i(16, -4), Vector2i(66, -4), Vector2i(80, 10), Vector2i(132, 10)],
		{width = 84.0, bundle = false, mode = "diag"})
	_river.build()


## MINIMAL HUMANS in an octilinear stroke alphabet, every stroke three stacked lines.
func _build_mh() -> void:
	_mh.cell = 30.0
	_mh.width = 13.0
	_mh.radius = 0.9
	_mh.casing = 3.0
	_mh.casing_color = BG
	var glyphs := {
		"M": [[Vector2i(0, 6), Vector2i(0, 0), Vector2i(3, 3), Vector2i(6, 0), Vector2i(6, 6)]],
		"I": [[Vector2i(0, 0), Vector2i(0, 6)]],
		"N": [[Vector2i(0, 6), Vector2i(0, 0), Vector2i(6, 6), Vector2i(6, 0)]],
		"A": [[Vector2i(0, 4), Vector2i(6, 4)], [Vector2i(0, 6), Vector2i(0, 2), Vector2i(2, 0), Vector2i(4, 0), Vector2i(6, 2), Vector2i(6, 6)]],
		"L": [[Vector2i(0, 0), Vector2i(0, 6), Vector2i(4, 6)]],
		"H": [[Vector2i(0, 3), Vector2i(5, 3)], [Vector2i(0, 0), Vector2i(0, 6)], [Vector2i(5, 0), Vector2i(5, 6)]],
		"U": [[Vector2i(0, 0), Vector2i(0, 6), Vector2i(5, 6), Vector2i(5, 0)]],
		"S": [[Vector2i(5, 1), Vector2i(4, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3),
			Vector2i(4, 3), Vector2i(5, 4), Vector2i(5, 5), Vector2i(4, 6), Vector2i(1, 6), Vector2i(0, 5)]],
	}
	var rows := [["MINIMAL", [0, 8, 10, 18, 20, 28, 36], 1.5], ["HUMANS", [0, 7, 14, 22, 30, 38], 0.0]]
	var word_w := 43.0 * _mh.cell
	var word_h := 16.0 * _mh.cell
	_mh.origin = M_C - Vector2(word_w, word_h) * 0.5
	_word_rect = Rect2(_mh.origin, Vector2(word_w, word_h))
	var cols := [FTFKit.MH_RED, FTFKit.MH_AMBER, FTFKit.MH_CREAM]
	var shifts := [Vector2(9, 9), Vector2(4.5, 4.5), Vector2.ZERO]
	var strokes: Array = []
	for r in rows.size():
		var text: String = rows[r][0]
		var xs: Array = rows[r][1]
		var row_dx: float = rows[r][2]
		for ci in text.length():
			for st in glyphs[text[ci]]:
				var nodes: Array = []
				for p in st:
					nodes.append(Vector2i(p) + Vector2i(xs[ci], r * 10))
				var radius := 2.2 if text[ci] == "U" else 0.9
				var x_frac := (float(xs[ci]) + 3.0) / 43.0
				strokes.append({nodes = nodes, dx = row_dx * _mh.cell, radius = radius, start = MH_AT + x_frac * 24.0 + r * 4.0})
	# all red strokes first, then amber, then cream: the layers stack like the M monogram
	for layer in 3:
		for k in strokes.size():
			var s: Dictionary = strokes[k]
			var li := _mh.add_line(StringName("mh%d_%d" % [layer, k]), cols[layer], s.nodes,
				{bundle = false, shift = shifts[layer] + Vector2(s.dx, 0), radius = s.radius})
			if layer == 0:
				_mh_strokes.append({lines = [li], start = s.start})
			else:
				(_mh_strokes[k].lines as Array).append(li)
	_mh.build()


func _build_network() -> void:
	_net.cell = CELL
	_net.spacing = 8.5
	_net.width = 6.0
	_net.radius = 1.4
	_net.casing = 1.5
	_net.casing_color = BG
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000
	# hand-placed early lines along the corridors above and below the word
	var early := [
		[[Vector2i(-124, -49), Vector2i(-40, -49), Vector2i(-30, -59), Vector2i(20, -59)], WAVE_A[0], 34.0, 0],
		[[Vector2i(-124, -60), Vector2i(-113, -49), Vector2i(-56, -49), Vector2i(-46, -59), Vector2i(-20, -59)], WAVE_A[1], 30.0, 1],
		[[Vector2i(-124, -17), Vector2i(-30, -17), Vector2i(-20, -7), Vector2i(24, -7)], WAVE_A[3] + 6.0, 34.0, 9],
		[[Vector2i(-112, -64), Vector2i(-97, -49), Vector2i(-46, -49), Vector2i(-36, -59), Vector2i(-10, -59)], WAVE_A[2], 30.0, 2],
		[[Vector2i(-112, -4), Vector2i(-99, -17), Vector2i(-36, -17), Vector2i(-26, -27), Vector2i(-6, -27)], WAVE_A[3], 30.0, 3],
		[[Vector2i(-95, -80), Vector2i(-95, -49), Vector2i(-95, -17), Vector2i(-95, 14)], WAVE_B[0], 30.0, 4],
		[[Vector2i(-124, -49), Vector2i(-60, -49), Vector2i(-50, -39)], WAVE_B[1], 22.0, 5],
		[[Vector2i(-26, -80), Vector2i(-26, -40), Vector2i(-26, -17), Vector2i(-16, -7), Vector2i(-16, 6)], WAVE_B[2], 26.0, 7],
		[[Vector2i(-124, -17), Vector2i(-60, -17), Vector2i(-50, -7), Vector2i(-50, 4)], WAVE_B[3], 24.0, 8],
	]
	for e in early:
		_net.add_line(StringName("e%d" % _net.lines.size()), LINE_COLS[e[3]], e[0], {mode = "diag"})
		_net_on.append(Vector2(e[1], e[2]))
		_net_wave.append(0)
	# hubs on a jittered grid, clear of the word and the logo box
	var hub_at := {}
	var word_box := Rect2i(-93, -47, 62, 28)
	var logo_box := Rect2i(8, 14, 78, 27)
	for gx in range(-6, 7):
		for gy in range(-3, 4):
			var n := Vector2i(gx * 20 + rng.randi_range(-3, 3), gy * 17 + rng.randi_range(-3, 3))
			if word_box.has_point(n) or logo_box.has_point(n):
				continue
			hub_at[Vector2i(gx, gy)] = n
	var keys: Array = hub_at.keys()
	var used := {}
	# random walks on the hub grid: the network proper
	var n_lines := 132
	for k in n_lines:
		var g: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var walk: Array[Vector2i] = [g]
		var dir := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var hops := rng.randi_range(4, 9)
		for h in hops:
			var options: Array[Vector2i] = []
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var nb := walk[walk.size() - 1] + Vector2i(dx, dy)
					if (dx == 0 and dy == 0) or not hub_at.has(nb) or walk.has(nb):
						continue
					if dir != Vector2i.ZERO and Vector2(dx, dy).dot(Vector2(dir)) < 0.0:
						continue
					options.append(nb)
			if options.is_empty():
				break
			options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var last := walk[walk.size() - 1]
				return Vector2(a - last).dot(Vector2(dir)) > Vector2(b - last).dot(Vector2(dir)))
			var pick := options[0] if rng.randf() < 0.6 else options[rng.randi_range(0, options.size() - 1)]
			dir = pick - walk[walk.size() - 1]
			walk.append(pick)
		if walk.size() < 3:
			continue
		var nodes: Array = []
		for w in walk.size() - 1:
			var a: Vector2i = hub_at[walk[w]]
			var b: Vector2i = hub_at[walk[w + 1]]
			var modes := [&"diag", &"straight", &"mid"]
			var m: StringName = modes[int(MK.rand(float(a.x * 31 + a.y * 7 + b.x * 13 + b.y * 3)) * 3.0) % 3]
			var seg := MotionMetroMap.canonical_route(a, b, m)
			if not nodes.is_empty():
				seg.remove_at(0)
			nodes.append_array(seg)
		for w in walk:
			used[w] = true
		var col: Color = LINE_COLS[k % LINE_COLS.size()]
		_net.add_line(StringName("n%d" % k), col, nodes, {mode = "diag", meta = walk})
		var slot := k % 8
		var wave := 1 if k < 110 else 2
		var start := EXPLODE + slot * 6.0 + float(k % 3) * 2.0 if wave == 1 else DROP + 24.0 + float(k - 110) * 5.0
		_net_on.append(Vector2(start, 0.0))
		_net_wave.append(wave)
	# the pink Flux Line, from PRESENTS to the logo box
	_pink = _net.add_line(&"flux", FTFKit.PINK, [P0, Vector2i(-14, -17), Vector2i(-6, -25), Vector2i(6, -25),
		Vector2i(14, -17), Vector2i(14, -5), Vector2i(2, 7), Vector2i(2, 17), Vector2i(12, 27), Vector2i(13, 27)],
		{mode = "diag", width = 7.0, order = 999})
	_net_on.append(Vector2(PINK_ON, PINK_DONE - PINK_ON))
	_net_wave.append(1)
	_net.build()
	# durations by length; retract times
	for i in _net.lines.size():
		var on := _net_on[i]
		if on.y <= 0.0:
			on.y = clampf(_net.length(i) / 160.0, 8.0, 26.0)
			_net_on[i] = on
		_net_off.append(OUT + 2.0 + MK.rand(i * 3.7 + 5.0) * 22.0)
	# hubs: name, and when the first line reaches them
	var hi := 0
	for g in keys:
		if not used.has(g):
			continue
		var n: Vector2i = hub_at[g]
		var t := INF
		for li in _net.lines.size():
			var meta: Variant = _net.lines[li].meta
			if meta is Array and (meta as Array).has(g):
				var frac := _net.s_near(li, _net.px(n)) / maxf(1.0, _net.length(li))
				t = minf(t, _net_on[li].x + _net_on[li].y * frac)
		var nm: Array = HUB_NAMES[hi % HUB_NAMES.size()]
		_hubs.append({node = n, name = nm[0], jp = nm[1], t = t})
		hi += 1
	# intermediate stations with ticks; one in three named
	var sk := 0
	for li in _net.lines.size():
		if li == _pink:
			continue
		var L: float = _net.length(li)
		var s := 150.0 + MK.rand(li * 1.3) * 80.0
		while s < L - 100.0:
			var nm := ""
			if sk % 3 == 0:
				var r1 := MK.rand(sk * 2.1 + 1.0)
				var r2 := MK.rand(sk * 3.7 + 2.0)
				var r3 := MK.rand(sk * 5.3 + 3.0)
				nm = (ST_A[int(r1 * ST_A.size())] + " " if r1 > 0.45 else "") + ST_B[int(r2 * ST_B.size())] + " " + ST_C[int(r3 * ST_C.size())]
			_stations.append({line = li, s = s, side = 1.0 if sk % 2 == 0 else -1.0, name = nm,
				t = _net_on[li].x + _net_on[li].y * s / L})
			sk += 1
			s += 170.0 + MK.rand(sk * 0.7) * 120.0
	# trains: two per line, running once the line is drawn
	for li in _net.lines.size():
		for k in 2:
			_trains.append({line = li, phase = MK.rand(li * 7.7 + k * 3.1) * 4000.0,
				speed = (2.4 + MK.rand(li * 1.9 + k) * 3.0) * (1.0 if k == 0 else -1.0)})


## The FTF logo as lines: concentric contours filling every part, a bundle round the plate.
func _build_logo() -> void:
	_logo.cell = 1.0
	_logo.width = 4.2
	_logo.casing = 0.0
	var data := _svg(FTFKit.LOGO)
	var k := LOGO_W / data.view_box.size.x
	var tl := L_C - data.view_box.size * k * 0.5
	# plate: its outer contour, filled as the inset box; four lines round it
	var plate_c := _contours(data, FTFKit.PLATE, k, tl)
	_plate = plate_c[0]
	var rim_cols := [FTFKit.PINK, FTFKit.CREAM, FTFKit.LILAC, FTFKit.LIME]
	for j in rim_cols.size():
		var off: Array[PackedVector2Array] = Geometry2D.offset_polygon(_plate, -2.0 + j * 10.0, Geometry2D.JOIN_ROUND)
		for poly in off:
			if Geometry2D.is_polygon_clockwise(poly) and off.size() > 1:
				continue
			var li := _logo.add_path(StringName("rim%d" % j), rim_cols[j], poly, {closed = true, width = 6.5 if j == 0 else 5.0})
			_rim.append(li)
			_rings.append({line = li, start = BOX_AT + 2.0 + j * 2.0, dur = 16.0, col = rim_cols[j], depth = -1, part = -1})
	# filled parts as concentric contour lines
	var pink_parts: Array = FTFKit.WORD + FTFKit.FLUX_TOP + [FTFKit.FLUX_BOWL, FTFKit.TAB]
	var white_parts: Array = FTFKit.FLUX_BOT
	var spacing := 7.2
	for part in pink_parts + white_parts:
		var col: Color = FTFKit.PINK if pink_parts.has(part) else FTFKit.WHITE
		var conts := _contours(data, part, k, tl)
		var outers: Array[PackedVector2Array] = []
		var holes: Array[PackedVector2Array] = []
		var is_hole := MotionPoly.hole_flags(conts, false)
		for ci in conts.size():
			if is_hole[ci]:
				holes.append(conts[ci])
			else:
				outers.append(conts[ci])
		var bb: Rect2 = data.parts[part].bbox
		var x_frac := ((bb.get_center().x * k + tl.x) - (L_C.x - LOGO_W * 0.5)) / LOGO_W
		for depth in 12:
			var d := 2.6 + depth * spacing
			var shapes: Array[PackedVector2Array] = []
			for o in outers:
				shapes.append_array(Geometry2D.offset_polygon(o, -d, Geometry2D.JOIN_ROUND))
			for h in holes:
				var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(h, d, Geometry2D.JOIN_ROUND)
				var next: Array[PackedVector2Array] = []
				for s in shapes:
					var cur: Array[PackedVector2Array] = [s]
					for g in grown:
						var acc: Array[PackedVector2Array] = []
						for c in cur:
							acc.append_array(Geometry2D.clip_polygons(c, g))
						cur = acc
					next.append_array(cur)
				shapes = next
			if shapes.is_empty():
				break
			for s in shapes:
				if s.size() < 3 or absf(MotionPoly.signed_area(s)) < 30.0:
					continue
				var li := _logo.add_path(StringName("r%d_%d" % [part, depth]), col, s, {closed = true})
				var start := minf(LOGO_ON + x_frac * 9.0 + depth * 0.9, DROP - 9.0)
				_rings.append({line = li, start = start, dur = minf(9.0, DROP - 1.0 - start), col = col, depth = depth, part = part})
	_logo.build()
	for r in _rings:
		var li: int = r.line
		var pts := _logo.path(li)
		var best := 0
		for i in pts.size():
			if pts[i].x < pts[best].x:
				best = i
		r.s0 = _logo.s_near(li, pts[best])
		r.len = _logo.length(li)
	# the small type and the checks: a dark strip and casings under the white SVG
	var sb := Rect2()
	for p in FTFKit.SMALL:
		var bb: Rect2 = data.parts[p].bbox
		var r := Rect2(tl + bb.position * k, bb.size * k)
		sb = r if sb.size == Vector2.ZERO else sb.merge(r)
	_small_band = sb.grow(5.0)
	for p in FTFKit.CHECKS:
		var bb: Rect2 = data.parts[p].bbox
		_checks.append(Rect2(tl + bb.position * k, bb.size * k).grow(3.0))
	# trains on the outermost contour of each letter and on the rim lines
	var n := 0
	for r in _rings:
		if r.depth == 0 and FTFKit.WORD.has(r.part) or r.depth == -1:
			_ring_trains.append({line = r.line, phase = MK.rand(n * 4.1) * 900.0, speed = (2.5 + MK.rand(n * 2.3) * 2.5) * (1.0 if n % 2 == 0 else -1.0)})
			n += 1


func _contours(data: MotionSvgData, part: int, k: float, tl: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for c in data.outline(part, 0.25):
		var pts := PackedVector2Array()
		for p in c:
			pts.append(tl + p * k)
		if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
			pts.remove_at(pts.size() - 1)
		if pts.size() > 2:
			out.append(pts)
	return out


## Deprecated: use MotionPoly.signed_area.
static func _area(p: PackedVector2Array) -> float:
	return MotionPoly.signed_area(p)


# ================================================================== camera

func _log_interp(f: float, keys: Array, zs: Array) -> float:
	var ls: Array = []
	for z in zs:
		ls.append(log(float(z)))
	return exp(MK.interp(f, keys, ls, MK.ease_in_out))


func _camera(f: float) -> Array:
	var keys := [0.0, 24.0, 48.0, 60.0, 96.0, 144.0]
	var cx := [-2150.0, -1950.0, -2000.0, -1950.0, -1430.0, -1410.0]
	var cy := [-1150.0, -1110.0, -900.0, -850.0, -730.0, -722.0]
	var zs := [2.3, 2.0, 1.8, 1.7, 1.15, 1.12]
	if f <= EXPLODE:
		var c := Vector2(MK.interp(f, keys, cx, MK.ease_in_out), MK.interp(f, keys, cy, MK.ease_in_out))
		return [c, _log_interp(f, keys, zs)]
	if f < DROP:
		var head := _net.point_at(_pink, _net.length(_pink) * _pink_prog(f))
		var c0 := Vector2(cx[cx.size() - 1], cy[cy.size() - 1])
		var c := c0.lerp(head, MK.map(f, [EXPLODE, PINK_ON + 10.0], [0, 1], MK.ease_in_out))
		c = c.lerp(L_C, MK.map(f, [PINK_DONE - 6.0, DROP], [0, 1], MK.ease_in_out))
		var z := _log_interp(f, [EXPLODE, 154.0, 170.0, 182.0, DROP], [1.12, 0.66, 0.56, 0.72, 1.12])
		return [c, z]
	if f < ZOOM_OUT:
		var settle := MK.map(f, [DROP, DROP + 8.0], [0, 1], MK.ease_out)
		var drift := MK.map(f, [DROP + 8.0, ZOOM_OUT], [0, 1], MK.linear)
		var z := lerpf(1.12, 1.0, settle) * lerpf(1.0, 1.06, drift)
		return [L_C + Vector2(24.0, 10.0) * drift, z]
	var t := MK.map(f, [ZOOM_OUT, DOT], [0, 1], MK.ease_in_quad)
	return [L_C + Vector2(24.0, 10.0), exp(lerpf(log(1.06), log(0.012), t))]


func _pink_prog(f: float) -> float:
	return MK.map(f, [PINK_ON, PINK_DONE], [0, 1], MK.ease_in_out)


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	var cam := _camera(f)
	var c: Vector2 = cam[0]
	_zoom = cam[1]
	_cam.scale = Vector2.ONE * _zoom
	_cam.position = Vector2(W, H) * 0.5 - c * _zoom
	_view = Rect2(c - Vector2(W, H) * 0.5 / _zoom, Vector2(W, H) / _zoom).grow(120.0 / _zoom)
	_stage.position = MK.shakes(f, [DROP], 20, 9) + MK.shakes(f, [EXPLODE], 8, 6)
	_map.visible = f < DOT
	_top.visible = f < DOT
	# the small type and checks: on with the impact, off with the outro
	var svg_on := f >= DROP and f < OUT + 4.0
	_logo_svg.visible = svg_on
	if svg_on:
		_logo_svg.apply(func(_i: int) -> Variant: return {fill = FTFKit.WHITE})
	_mh_icon.modulate.a = MK.prog(f, 20, 8) * (1.0 - MK.prog(f, OUT, 8))
	_mh_icon.visible = _mh_icon.modulate.a > 0.0


func _net_dim(f: float) -> float:
	# the network steps back behind the logo after the drop, and on the way out
	var d := lerpf(1.0, 0.32, MK.map(f, [DROP - 2.0, DROP + 6.0], [0, 1], MK.ease_out))
	return d


func _draw_map(c: MotionCanvas, f: float) -> void:
	var dim := _net_dim(f)
	# grid and river
	# the grid fades out as the map zooms far out (it would fill the screen)
	var g0 := MK.prog(f, 0, 8) * clampf((_zoom - 0.2) / 0.25, 0.0, 1.0)
	if g0 > 0.0:
		var step := CELL * 4.0
		var x0 := floorf(_view.position.x / step) * step
		var y0 := floorf(_view.position.y / step) * step
		var gw := maxf(1.0 / _zoom, 1.0)
		var x := x0
		while x < _view.end.x:
			c.draw_line(Vector2(x, _view.position.y), Vector2(x, _view.end.y), Color(GRIDC, g0), gw)
			x += step
		var y := y0
		while y < _view.end.y:
			c.draw_line(Vector2(_view.position.x, y), Vector2(_view.end.x, y), Color(GRIDC, g0), gw)
			y += step
	_river.draw_line(c, 0, 0.0, MK.map(f, [0, 30], [0, 1], MK.ease_out), 1.0, 1.0, Color(0, 0, 0, 0), false)
	# network lines: drawn on, retracting at the end
	for i in _net.lines.size():
		var on := _net_on[i]
		var b := MK.map(f, [on.x, on.x + on.y], [0, 1], MK.ease_out if i != _pink else MK.ease_in_out)
		if i == _pink:
			b = _pink_prog(f)
		var a := MK.map(f, [_net_off[i], _net_off[i] + 14.0], [0, 1], MK.ease_in_quad)
		if b <= a:
			continue
		var op := dim if i != _pink else lerpf(1.0, 0.7, MK.map(f, [DROP, DROP + 8.0], [0, 1]))
		_net.draw_line(c, i, a, b, op)
	# interchanges and hub names
	var lz := _zoom
	for hb in _hubs:
		var t: float = hb.t
		if f < t:
			continue
		var n: Vector2i = hb.node
		var p := _net.px(n)
		if not _view.has_point(p):
			continue
		var s := MK.map(f, [t, t + 4.0], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [OUT + 6.0, OUT + 18.0], [0, 1]))
		if s <= 0.0:
			continue
		var col := Color(1, 1, 1, dim)
		_net.draw_interchange(c, n, s, 6.0, Color(col, 1.0).darkened(1.0 - dim), Color(INK, 1.0))
		MotionMetroMap.label(c, _f7, p + Vector2(16, -12), hb.name, 15.0, lz, Color(1, 1, 1, 0.92 * dim * s))
		MotionMetroMap.label(c, _fj, p + Vector2(16, 6), hb.jp, 11.0, lz, Color(0.75, 0.8, 0.9, 0.8 * dim * s))
	# station ticks and names
	for st in _stations:
		var t: float = st.t
		if f < t:
			continue
		var li: int = st.line
		var a2 := MK.map(f, [_net_off[li], _net_off[li] + 14.0], [0, 1], MK.ease_in_quad)
		if (st.s as float) < a2 * _net.length(li):
			continue
		var p := _net.point_at(li, st.s)
		if not _view.has_point(p):
			continue
		var o := MK.map(f, [t, t + 3.0], [0, 1]) * dim
		_net.draw_tick(c, li, st.s, st.side, 7.0, o)
		if st.name != "":
			var d := _net.dir_at(li, st.s)
			var nrm := Vector2(-d.y, d.x) * float(st.side)
			var lp := p + nrm * 18.0
			var al := 0.0 if nrm.x > 0.35 else (1.0 if nrm.x < -0.35 else 0.5)
			if nrm.y > 0.35:
				lp.y += 9.0
			MotionMetroMap.label(c, _f7, lp + Vector2(0, 4), st.name, 10.0, lz, Color(0.86, 0.89, 0.95, 0.85 * o), al)
	# trains on the network
	for tr in _trains:
		var li: int = tr.line
		var on := _net_on[li]
		var ready := on.x + on.y
		if f < ready + 2.0:
			continue
		var a3 := MK.map(f, [_net_off[li], _net_off[li] + 14.0], [0, 1], MK.ease_in_quad)
		if a3 > 0.0:
			continue
		var L := _net.length(li)
		var x: float = tr.phase + (f - ready) * float(tr.speed)
		var s := fposmod(x, 2.0 * L)
		if s > L:
			s = 2.0 * L - s
		if not _view.has_point(_net.point_at(li, s)):
			continue
		var tc := Color(1, 1, 1, MK.map(f, [ready + 2.0, ready + 6.0], [0, 1]) * dim)
		_net.draw_train(c, li, s, 16.0, tc, 6.0, Color(_net.lines[li].color, tc.a))
	# PRESENTS station and its pink terminus
	var pp := _net.px(P0)
	var ps := MK.map(f, [PRESENTS, PRESENTS + 4.0], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [OUT, OUT + 10.0], [0, 1]))
	if ps > 0.0:
		_net.draw_interchange(c, P0, ps, 9.0, Color.WHITE, INK)
		var n_ch := int(MK.map(f, [PRESENTS, PRESENTS + 10.0], [0, 8], MK.linear))
		MotionMetroMap.label(c, _f9, pp + Vector2(-34, -38), "PRESENTS".left(n_ch), 52.0, lz, FTFKit.MH_CREAM, 1.0)
		var jp_o := MK.map(f, [PRESENTS + 8.0, PRESENTS + 12.0], [0, 1])
		MotionMetroMap.label(c, _fj, pp + Vector2(-34, 4), "提供 · ミニマル・ヒューマンズ", 20.0, lz, Color(FTFKit.MH_AMBER, jp_o), 1.0)
	# MINIMAL HUMANS: triple routes, red then amber then cream
	if f < DROP + 12.0:
		_draw_mh(c, f)


func _draw_mh(c: MotionCanvas, f: float) -> void:
	for layer in 3:
		for st in _mh_strokes:
			var li: int = (st.lines as Array)[layer]
			var t0: float = float(st.start) + layer * 2.0
			var b := MK.map(f, [t0, t0 + 14.0], [0, 1], MK.ease_in_out)
			if b <= 0.0:
				continue
			_mh.draw_line(c, li, 0.0, b, 1.0, 1.0, Color(0, 0, 0, 0), layer == 0)
	# trains running the letters once they're complete
	if f >= MH_DONE:
		var o := MK.map(f, [MH_DONE, MH_DONE + 6.0], [0, 1])
		var k := 0
		for st in _mh_strokes:
			var li: int = (st.lines as Array)[2]
			var L := _mh.length(li)
			var s := fposmod(MK.rand(k * 3.3) * L + (f - MH_DONE) * (3.0 + MK.rand(k * 1.7) * 2.0), 2.0 * L)
			if s > L:
				s = 2.0 * L - s
			_mh.draw_train(c, li, s, 22.0, Color(FTFKit.INK, o), 8.0, Color(FTFKit.MH_CREAM, o))
			k += 1


## The logo layer: the inset box, its rim bundle and the contour lines, drawn
## above the network (the small type and checks are an SVG above this).
func _draw_top(c: MotionCanvas, f: float) -> void:
	if f < BOX_AT:
		return
	# the inset box: opens from its centre line
	var box := MK.map(f, [BOX_AT, BOX_AT + 8.0], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [OUT + 10.0, OUT + 22.0], [0, 1], MK.ease_in_quad))
	if box > 0.0:
		var sq := PackedVector2Array()
		for p in _plate:
			sq.append(Vector2(p.x, L_C.y + (p.y - L_C.y) * box))
		c.draw_colored_polygon(sq, PANEL)
	# impact: the logo's lines flash toward white once
	var flash := 1.0 - MK.map(f, [DROP, DROP + 7.0], [0, 1], MK.ease_out) if f >= DROP else 0.0
	var out := MK.map(f, [OUT, OUT + 14.0], [0, 1], MK.ease_in_quad)
	for r in _rings:
		var li: int = r.line
		var p := MK.map(f, [r.start, r.start + r.dur], [0, 1], MK.ease_in_out)
		var depth: int = r.depth
		var shrink := clampf(out * 1.3 - maxf(0, depth) * 0.03, 0.0, 1.0)
		p *= 1.0 - shrink
		if p <= 0.0:
			continue
		var L: float = r.len
		var s0: float = r.s0
		var col: Color = (r.col as Color).lerp(FTFKit.WHITE, flash * 0.75)
		var w := (6.5 if r.part == -1 and depth == -1 and li == _rim[0] else (5.0 if depth == -1 else 4.2))
		if p >= 1.0:
			c.draw_polyline(_logo.path(li), col, w, true)
		else:
			_logo.draw_span(c, li, s0 - L * 0.5 * p, s0 + L * 0.5 * p, col, w)
	# hold: a light chases round every contour on each beat
	if f >= DROP and f < OUT:
		var bt := fposmod(f - DROP, BEAT) / BEAT
		var e := MK.ease_out.call(bt) as float
		for r in _rings:
			var li: int = r.line
			var L: float = r.len
			var s0: float = r.s0
			var head := L * 0.5 * e
			var hl := 70.0 * (1.0 - bt)
			var hc := Color(1, 1, 1, 0.95 * (1.0 - bt * bt))
			_logo.draw_span(c, li, s0 + head - hl, s0 + head, hc, 5.2)
			_logo.draw_span(c, li, s0 - head, s0 - head + hl, hc, 5.2)
		# trains on the letters and the rim
		for tr in _ring_trains:
			var li2: int = tr.line
			var s := float(tr.phase) + (f - DROP) * float(tr.speed)
			_logo.draw_train(c, li2, s, 20.0, FTFKit.WHITE, 5.0, PANEL)
		# expresses round the outer rim
		for ex in EXPRESS:
			var t := f - float(ex)
			if t >= 0.0 and t < 26.0:
				var li3: int = _rim[_rim.size() - 1]
				var L3 := _logo.length(li3)
				var head3 := L3 * MK.map(t, [0, 26], [0, 1], MK.ease_in_out)
				var s03: float = _rings[_rim.size() - 1].s0
				_logo.draw_span(c, li3, s03 + head3 - 220.0, s03 + head3, Color(1, 1, 1, 0.95), 9.0)
				_logo.draw_span(c, li3, s03 - head3, s03 - head3 + 220.0, Color(1, 1, 1, 0.95), 9.0)
	# the small type strip and check casings under the white SVG
	if f >= DROP and f < OUT + 4.0:
		c.draw_rect(_small_band, FTFKit.PINK)
		for r2 in _checks:
			c.draw_rect(r2, PANEL)
	# the logo's station label
	var lt := MK.map(f, [LABEL_AT, LABEL_AT + 14.0], [0, 1]) * (1.0 - MK.map(f, [OUT, OUT + 8.0], [0, 1]))
	if lt > 0.0:
		var base := L_C + Vector2(-LOGO_W * 0.5 + 24.0, 252.0)
		c.draw_line(base + Vector2(0, -34), base + Vector2(LOGO_W - 48.0, -34), Color(FTFKit.PINK, lt), 6.0, true)
		var jp := "フルスロットル・フラックス"
		var n := int(ceil(jp.length() * lt))
		MotionMetroMap.label(c, _fj, base + Vector2(0, 10), jp.left(n), 34.0, _zoom, Color(1, 1, 1, lt))
		MotionMetroMap.label(c, _f7, base + Vector2(LOGO_W - 48.0, 6), "FLUX LINE · TERMINUS · 終点", 18.0, _zoom, Color(FTFKit.LIME, lt), 1.0)


## Screen-space map furniture: legend, title block, compass, the final dot.
func _draw_hud(c: MotionCanvas, f: float) -> void:
	var a := MK.prog(f, 18, 10) * (1.0 - MK.prog(f, OUT, 10))
	if a > 0.0:
		# legend box
		var r := Rect2(64, 830, 470, 196)
		c.draw_rect(r, Color(INK, 0.88 * a))
		c.draw_rect(r, Color(1, 1, 1, 0.55 * a), false, 2.0)
		MotionMetroMap.label(c, _f9, Vector2(152, 868), "MINIMAL HUMANS TRANSIT", 22.0, 1.0, Color(1, 1, 1, a))
		MotionMetroMap.label(c, _fj, Vector2(152, 896), "地下鉄路線図 · F-9000 RAPID TRANSIT", 15.0, 1.0, Color(0.7, 0.76, 0.86, a))
		var names := [["SPARROW", 0], ["STARLING", 1], ["KESTREL", 2], ["UTOPIA LOOP", 4], ["FLUX LINE", -1]]
		for i in names.size():
			var col: Color = FTFKit.PINK if names[i][1] == -1 else LINE_COLS[names[i][1]]
			var x := 88.0 + (i % 3) * 150.0
			var y := 940.0 + floorf(i / 3.0) * 40.0
			c.draw_line(Vector2(x, y), Vector2(x + 34, y), col, 7.0, true)
			MotionMetroMap.label(c, _f7, Vector2(x + 44, y + 6), names[i][0], 14.0, 1.0, Color(1, 1, 1, 0.9 * a))
		MotionMetroMap.label(c, _fm, Vector2(88, 1010), "NOT TO SCALE // EDITION 01", 11.0, 1.0, Color(0.6, 0.66, 0.78, a))
		# title block, top left
		MotionMetroMap.label(c, _fm, Vector2(64, 74), "F-9000 NETWORK MAP // NIGHT SERVICE", 15.0, 1.0, Color(1, 1, 1, 0.8 * a))
		MotionMetroMap.label(c, _fm, Vector2(64, 98), "150 BPM · 12 F/BEAT · %03d" % int(f), 13.0, 1.0, Color(FTFKit.LIME, 0.8 * a))
		# compass, top right
		var cp := Vector2(1830, 104)
		c.draw_arc(cp, 30, 0, TAU, 40, Color(1, 1, 1, 0.6 * a), 2.0, true)
		c.draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -26), cp + Vector2(8, 6), cp + Vector2(-8, 6)]), Color(1, 1, 1, 0.9 * a))
		MotionMetroMap.label(c, _f9, cp + Vector2(0, 54), "N", 16.0, 1.0, Color(1, 1, 1, 0.8 * a), 0.5)
		# zoom readout
		MotionMetroMap.label(c, _fm, Vector2(1856, 1010), "ZOOM %.2fx" % _zoom, 13.0, 1.0, Color(1, 1, 1, 0.6 * a), 1.0)
	# doors closing
	var dd := MK.win(f, DOORS[0] - 2.0, OUT + 2.0, 3)
	if dd > 0.0:
		var blink := 1.0 if int((f - DOORS[0]) / 6.0) % 2 == 0 else 0.35
		MotionMetroMap.label(c, _f9, Vector2(960, 1000), "MIND THE GAP  ·  DOORS CLOSING", 26.0, 1.0, Color(FTFKit.LIME, dd * blink), 0.5)
	# the last station dot
	if f >= DOT - 14.0 and f < BLIP + 12.0:
		var ctr := Vector2(960, 540)
		if f < BLIP:
			var g := MK.map(f, [DOT - 14.0, DOT], [0, 1], MK.ease_out)
			# one pulse on the beat before the blip
			var pu := exp(-(f - (DOT + 6.0)) * 0.35) if f >= DOT + 6.0 else 0.0
			c.draw_circle(ctr, (9.0 * g + 2.0) * (1.0 + 0.35 * pu), FTFKit.PINK, true, -1.0, true)
			c.draw_circle(ctr, 4.0 * g, FTFKit.WHITE, true, -1.0, true)
			if pu > 0.03:
				c.draw_arc(ctr, lerpf(14.0, 46.0, 1.0 - pu), 0, TAU, 48, Color(FTFKit.PINK, pu), 2.0, true)
		else:
			var b := MK.map(f, [BLIP, BLIP + 10.0], [0, 1], MK.ease_out)
			c.draw_circle(ctr, 11.0 * (1.0 - b), FTFKit.WHITE, true, -1.0, true)
			c.draw_arc(ctr, lerpf(12.0, 150.0, b), 0, TAU, 64, Color(FTFKit.PINK, 1.0 - b), lerpf(6.0, 1.0, b), true)
