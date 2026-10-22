# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — "Fuel Lines" boot intro.
#
# Brief: an anti-gravity racer's fuel system as a schematic come alive, on a
# dark engine-bay blueprint. Pumps cycle, valves snap open on the beat, fuel
# surges down the lines in glowing slugs, needles slam over. Minimal Humans is
# the primer tank: its lockup is an empty outline that fills from the bottom
# with fuel (its own colours under a sloshing amber surface), reads full, then
# drains away into the network. The network pressurises line by line, the FTF
# logo's rim traces itself as an empty tank, and four feeds fill it from below
# and above, the level racing up so it is brim-full and sloshing on the drop.
# The hold keeps pumping: pulses lurch down every line on each beat, the
# surface slaps in the tank's top on every beat, pressure rings round the rim,
# a pressure wave sweeps through the letters each bar, needles bounce. Outro:
# valves shut one per eighth, the lines drain, the tank empties, the
# schematic un-draws to black.
#
# Tempo: 180 bpm, 4/4 = 10 frames a beat, 40 a bar, first downbeat at frame 0.
# Any 180 bpm track with its first downbeat at 0.0 s lines up: the drop is
# bar 5 (frame 200, 6.67 s).
#
# Beats (30 fps, 420 frames):
#   0       grid; pump P-01 spins up; primer line draws (4-18)
#   6-26    MH lockup traces itself as an empty outline
#   20      primer valve opens; amber front runs to the tank (20-34)
#   34-80   MH fills from the bottom, sloshing; full on bar 2 (80)
#   80      full; 84 PRESENTS placard; 90/100/110 prime gauges slam
#   124-152 MH drains out through the floor; primer lines un-draw
#   128-146 network draws (pipes traced one after another)
#   130     coolant pump; 140 main valve: the manifold floods left to right
#   150-172 FTF tank: rim traces, letters as empty outlines
#   160     header valve (AG fuel from above)
#   170/175/180  riser valves open; 178-200 the tank fills, accelerating
#   200     DROP: brim-full, big slosh, shake, one soft flash, needles to red
#   200-336 hold: lines lurch every beat, surface slaps every beat,
#           rim pressure ring, pressure wave each bar (240/280/320),
#           purge at 280 (coolant line flushes white)
#   340/345/350/355/360  valves close
#   352-388 tank drains; 372-396 network un-draws; 388-400 rim fades
#   400-420 black
#
# Sound: the cue sheet in _init, scored by demo/ftf/ftf_fuel/audio (recipes,
# cue map and a 180 bpm song: make.py). With the audio kit linked the bridge
# scores it; without, the committed bake plays.
@tool
extends MotionComposition

const BEAT := 10.0
const BAR := 40.0
# ---- Act I: primer
const PRIME_PIPE := 4.0
const MH_TRACE := 6.0
const MH_VALVE := 20.0
const MH_FILL := 34.0
const MH_FULL := 80.0
const MH_GAUGES := [90.0, 100.0, 110.0]
const PRESENTS := 84.0
const MH_DRAIN := 124.0
const MH_EMPTY := 152.0
# ---- Act II: network
const NET_DRAW := 128.0
const COOLANT := 130.0
const MAIN_VALVE := 140.0
const RIM_TRACE := 150.0
const HEADER_VALVE := 160.0
const RISER_VALVES := [170.0, 175.0, 180.0]
const TANK_FILL := 178.0
const DROP := 200.0
# ---- Act III: hold and out
const SWEEPS := [240.0, 280.0, 320.0]
const PURGE := 280.0
const HOLD_END := 336.0
const CLOSES := [340.0, 345.0, 350.0, 355.0, 360.0]   # risers 1-3, header, main
const TANK_DRAIN := 352.0
const TANK_EMPTY := 388.0
const NET_UNDRAW := 372.0
const RIM_OUT := 388.0
const LAST := 400.0
const END := 420

# ---- palette
const BG := Color("#0b111b")
const GRID := Color(0.1, 0.76, 0.9, 0.06)
const STEEL := Color("#5d6b80")
const CORE := Color("#0e1520")
const CHROME := Color("#b9c3d1")
const FACE := Color("#111a26")
const LIME := Color("#d7ff1f")
const PINK := Color("#e92067")
const CYAN := Color("#19c3e6")
const AMBER := Color("#ffb627")
const STONE := Color("#8d98a8")
const WHITE := Color("#ffffff")

# ---- layout
const LOGO_W := 1400.0
const LOGO_POS := Vector2(260, 283.3)
const MH_W := 1100.0
const MH_POS := Vector2(410, 300)
const MANIFOLD_Y := 760.0
const RISER_X := [420.0, 960.0, 1500.0]
const HEADER_X := 700.0
const P1 := Vector2(150, 900)
const P2 := Vector2(1790, 210)

var _built := false
var _bg: ColorRect
var _stage: Node2D
var _grid: MotionCanvas
var _flow: MotionFlow          # network + primer pipes
var _parts: MotionCanvas       # pumps, valves, gauges, sight glasses (over pipes)
var _labels: Node2D
var _flash: ColorRect
# MH
var _mh_ghost: MotionSvg
var _mh_tank: MotionLiquidFill
var _mh_fill: MotionSvg
var _mh_k := 1.0
var _placard: Node2D
var _mh_labels: Array[MotionText] = []
# FTF
var _ftf: Node2D
var _ghost: MotionSvg
var _tank: MotionLiquidFill
var _logo: MotionSvg
var _logo_light: MotionSvg
var _rim: MotionSvg
var _rim_flow: MotionFlow
var _sheen: MotionCanvas
var _sheen_logo: MotionSvg
var _k := 1.0
# text
var _net_labels: Array[MotionText] = []
var _ticker: MotionText
# pipe ids
var _p_prime := -1
var _p_mh_drain := -1
var _p_main := -1
var _p_risers: Array[int] = []
var _p_header := -1
var _p_coolant := -1
var _p_cool_ret := -1
var _p_side := -1
var _spin1 := PackedFloat32Array()
var _spin2 := PackedFloat32Array()


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": DROP + 40.0, "out": HOLD_END}
	cue(0.0, &"pump.start", 0.6)
	cue(PRIME_PIPE, &"trace", 0.4)
	cue(MH_VALVE, &"valve", 0.7, {pitch = 0.9})
	cue(MH_FILL, &"pour", 0.7)
	cue(MH_FULL, &"full", 0.85, {pitch = 0.84})
	for i in MH_GAUGES.size():
		cue(MH_GAUGES[i], &"gauge", 0.5 + 0.1 * i, {pitch = [1.0, 1.12, 1.26][i]})
	cue(PRESENTS, &"placard", 0.7)
	cue(MH_DRAIN, &"drain", 0.8)
	cue(NET_DRAW, &"trace", 0.6)
	cue(COOLANT, &"pump.start", 0.8, {pitch = 1.2})
	cue(MAIN_VALVE, &"valve", 0.9, {pitch = 0.8})
	cue(MAIN_VALVE + 2.0, &"surge", 0.8)
	cue(RIM_TRACE, &"rim", 0.7)
	cue(HEADER_VALVE, &"valve", 0.8, {pitch = 1.0})
	for i in RISER_VALVES.size():
		cue(RISER_VALVES[i], &"valve", 0.8 + 0.05 * i, {pitch = [1.12, 1.26, 1.5][i]})
	cue(DROP, &"riser", 1.0)          # its recipe swells in ahead and peaks here
	cue(DROP, &"drop", 1.0)
	for k in 13:
		var at := DROP + BEAT * (k + 1)
		if at >= HOLD_END:
			break
		if SWEEPS.has(at):
			cue(at, &"sweep", 0.8)
		else:
			cue(at, &"slap", 0.45 + 0.1 * float(k % 2), {pitch = [1.0, 1.12, 0.94, 1.26][k % 4]})
	cue(PURGE + 2.0, &"purge", 0.8)
	for i in CLOSES.size():
		cue(CLOSES[i], &"valve.close", 0.7 + 0.05 * i, {pitch = [1.5, 1.26, 1.12, 1.0, 0.8][i]})
	cue(TANK_DRAIN, &"drain", 1.0, {pitch = 0.8})
	cue(NET_UNDRAW, &"trace.out", 0.6)
	cue(LAST, &"clunk", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================ build

func _build() -> void:
	_built = true
	_bg = ColorRect.new()
	_bg.color = BG
	_bg.size = size
	add_child(_bg)
	_stage = Node2D.new()
	add_child(_stage)
	_grid = MotionCanvas.new()
	_grid.draw_fn = _draw_grid
	_stage.add_child(_grid)
	_build_pipes()
	_build_mh()
	_build_ftf()
	_parts = MotionCanvas.new()
	_parts.draw_fn = _draw_parts
	_stage.add_child(_parts)
	_build_labels()
	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_spin1 = _spin_table(func(f: float) -> float: return _pump_speed(f, 0.0, true))
	_spin2 = _spin_table(func(f: float) -> float: return _pump_speed(f, COOLANT, false))
	_add_sound()


func _pipe_opts(w: float, fluid: Color, extra := {}) -> Dictionary:
	var d := {width = w, wall_width = maxf(3.0, w * 0.16), radius = 46.0, wall = STEEL, core = CORE, fluid = fluid, pulse = WHITE}
	d.merge(extra, true)
	return d


func _build_pipes() -> void:
	_flow = MotionFlow.new()
	_stage.add_child(_flow)
	# primer: pump P-01 up, along, and up into the bottom of the MH lockup
	_p_prime = _flow.add_pipe(PackedVector2Array([P1 + Vector2(0, -50), Vector2(P1.x, 700), Vector2(560, 700), Vector2(560, 588)]),
		_pipe_opts(24.0, AMBER, {arrows = 60.0}))
	# MH drain: out of the floor of the lockup and away
	_p_mh_drain = _flow.add_pipe(PackedVector2Array([Vector2(1300, 586), Vector2(1300, 820), Vector2(1960, 820)]),
		_pipe_opts(24.0, AMBER, {arrows = 60.0}))
	# main manifold: pump P-01 up and along the floor, left to right
	_p_main = _flow.add_pipe(PackedVector2Array([P1 + Vector2(0, -50), Vector2(P1.x, MANIFOLD_Y), Vector2(1860, MANIFOLD_Y), Vector2(1860, 1100)]),
		_pipe_opts(32.0, LIME, {arrows = 70.0}))
	# risers into the floor of the tank
	for x in RISER_X:
		_p_risers.append(_flow.add_pipe(PackedVector2Array([Vector2(x, MANIFOLD_Y), Vector2(x, 612)]),
			_pipe_opts(22.0, LIME, {radius = 0.0, caps = false})))
	# AG-fuel header from the top-left into the tank's filler neck
	_p_header = _flow.add_pipe(PackedVector2Array([Vector2(-30, 200), Vector2(HEADER_X, 200), Vector2(HEADER_X, 290)]),
		_pipe_opts(24.0, PINK, {arrows = 64.0}))
	# coolant loop along the top, via pump P-02, and its return down the right
	_p_coolant = _flow.add_pipe(PackedVector2Array([Vector2(-30, 120), Vector2(P2.x, 120), Vector2(P2.x, P2.y - 48)]),
		_pipe_opts(18.0, CYAN, {arrows = 56.0}))
	_p_cool_ret = _flow.add_pipe(PackedVector2Array([P2 + Vector2(0, 48), Vector2(P2.x, 690), Vector2(1700, 690), Vector2(1700, MANIFOLD_Y - 18)]),
		_pipe_opts(18.0, CYAN, {arrows = 56.0}))
	# a side line out of P-01 to the sight glasses
	_p_side = _flow.add_pipe(PackedVector2Array([P1 + Vector2(52, 0), Vector2(1050, 900), Vector2(1050, 1100)]),
		_pipe_opts(16.0, LIME, {arrows = 50.0}))


func _build_mh() -> void:
	var data := _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh_k = MH_W / data.view_box.size.x
	_mh_ghost = MotionSvg.new()
	_mh_ghost.data = data
	_mh_ghost.width = MH_W
	_mh_ghost.position = MH_POS
	_stage.add_child(_mh_ghost)
	_mh_tank = MotionLiquidFill.new()
	_mh_tank.position = MH_POS
	_mh_tank.size = data.view_box.size * _mh_k
	_mh_tank.wave_amp = 9.0
	_mh_tank.meniscus = 7.0
	_mh_tank.bubbles = 26
	_mh_tank.bubble_color = Color(AMBER, 0.75)
	_mh_tank.bubble_size = 5.0
	_mh_tank.foam = 0.8
	_mh_tank.foam_color = Color(1, 0.95, 0.8, 0.9)
	_mh_tank.seed_value = 3.0
	_mh_tank.kicks = [Vector2(MH_FILL, 0.6), Vector2(50, 0.45), Vector2(62, 0.4), Vector2(72, 0.4), Vector2(MH_FULL, 1.0),
		Vector2(MH_DRAIN, 0.9), Vector2(MH_DRAIN + 12.0, 0.5)]
	_stage.add_child(_mh_tank)
	_mh_fill = MotionSvg.new()
	_mh_fill.data = data
	_mh_fill.width = MH_W
	_mh_tank.fill.add_child(_mh_fill)
	var light := MotionSvg.new()
	light.data = data
	light.width = MH_W
	light.apply(func(_i: int) -> Variant: return {fill = Color(1.0, 0.86, 0.45)})
	_mh_tank.surface.add_child(light)
	# PRESENTS placard: a riveted plate under the wordmark
	_placard = Node2D.new()
	_placard.position = Vector2(MH_POS.x + 145.0 * _mh_k, MH_POS.y + data.view_box.size.y * _mh_k + 34.0)
	_stage.add_child(_placard)
	var plate := MotionCanvas.new()
	plate.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		c.rect(Rect2(0, 0, 760, 64), Color("#1a2533"))
		c.rect(Rect2(0, 0, 760, 64), CHROME, 1.0, 2.0)
		for p in [Vector2(14, 14), Vector2(746, 14), Vector2(14, 50), Vector2(746, 50)]:
			c.circle(p, 4.0, CHROME)
		c.rect(Rect2(0, 0, 10, 64), AMBER)
	_placard.add_child(plate)
	var pres := FTFKit.text(_placard, "heavy", 40, SCFBrand.CREAM, "PRESENTS", 0.42)
	pres.position = Vector2(34, 32 - pres.get_text_size().y * 0.5)
	var jp := FTFKit.text(_placard, "jp", 24, AMBER, "ミニマル・ヒューマンズ　提供")
	jp.position = Vector2(740 - jp.get_text_size().x, 32 - jp.get_text_size().y * 0.5)
	# primer readouts
	var l1 := FTFKit.text(_stage, "mono", 20, AMBER, "P-01 // PRIMER", 0.12)
	l1.position = Vector2(196, 650)
	var l2 := FTFKit.text(_stage, "mono", 20, STONE, "PRIME OK", 0.14)
	l2.position = Vector2(1570 - l2.get_text_size().x * 0.5, 994)
	_mh_labels = [l1, l2]


func _build_ftf() -> void:
	var data := _svg(FTFKit.LOGO)
	_k = LOGO_W / data.view_box.size.x
	_ftf = Node2D.new()
	_ftf.position = LOGO_POS
	_stage.add_child(_ftf)
	_ghost = MotionSvg.new()
	_ghost.data = data
	_ghost.width = LOGO_W
	_ftf.add_child(_ghost)
	_tank = MotionLiquidFill.new()
	_tank.size = data.view_box.size * _k
	_tank.wave_amp = 8.0
	_tank.wave_freq = 0.5
	_tank.damping = 0.09
	_tank.ripple = 1.2
	_tank.meniscus = 8.0
	_tank.bubbles = 40
	_tank.bubble_color = Color(PINK, 0.5)
	_tank.bubble_size = 6.0
	_tank.bubble_speed = 5.0
	_tank.foam = 1.0
	_tank.foam_color = Color(0.95, 1.0, 0.75, 0.95)
	var kicks := [Vector2(TANK_FILL, 0.8), Vector2(186, 0.6), Vector2(192, 0.6), Vector2(DROP, 2.2)]
	for k in 13:
		var at := DROP + BEAT * (k + 1)
		if at >= HOLD_END:
			break
		kicks.append(Vector2(at, 1.1 if fmod(at - DROP, BAR) == 0.0 else 0.45))
	kicks.append_array([Vector2(TANK_DRAIN, 1.2), Vector2(TANK_DRAIN + 10.0, 0.8), Vector2(TANK_DRAIN + 20.0, 0.6)])
	_tank.kicks = kicks
	_ftf.add_child(_tank)
	_logo = MotionSvg.new()
	_logo.data = data
	_logo.width = LOGO_W
	_logo.apply(func(i: int) -> Variant: return {hide = true} if i == FTFKit.RIM else {})
	_tank.fill.add_child(_logo)
	_logo_light = MotionSvg.new()
	_logo_light.data = data
	_logo_light.width = LOGO_W
	_logo_light.apply(func(i: int) -> Variant: return {hide = true} if i == FTFKit.RIM else {fill = LIME})
	_tank.surface.add_child(_logo_light)
	# the pressure wave: a slanted band showing a lime copy of the logo
	_sheen = MotionCanvas.new()
	_sheen.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_sheen.draw_fn = _draw_sheen_mask
	_ftf.add_child(_sheen)
	_sheen_logo = MotionSvg.new()
	_sheen_logo.data = data
	_sheen_logo.width = LOGO_W
	_sheen_logo.apply(func(i: int) -> Variant: return {hide = true} if i == FTFKit.RIM or i == FTFKit.PLATE else {fill = Color(LIME, 0.75)})
	_sheen.add_child(_sheen_logo)
	_rim = MotionSvg.new()
	_rim.data = data
	_rim.width = LOGO_W
	_rim.only = PackedInt32Array([FTFKit.RIM])
	_ftf.add_child(_rim)
	# pressure ring: pulses circulating in the rim
	_rim_flow = MotionFlow.new()
	_ftf.add_child(_rim_flow)
	var outline: Array[PackedVector2Array] = data.outline(FTFKit.PLATE, 0.3)
	var pts := PackedVector2Array()
	for p in outline[0]:
		pts.append(p * _k)
	var grown := Geometry2D.offset_polygon(pts, 2.75 * _k, Geometry2D.JOIN_ROUND)
	var ring: PackedVector2Array = grown[0] if grown.size() > 0 else pts
	ring.append(ring[0])
	_rim_flow.add_pipe(ring, {width = 8.0, wall_width = 0.0, radius = 0.0, caps = false,
		wall = Color(0, 0, 0, 0), core = Color(0, 0, 0, 0), fluid = Color(LIME, 0.0), pulse = LIME})


func _build_labels() -> void:
	_labels = Node2D.new()
	_stage.add_child(_labels)
	var specs := [
		["mono", 20, STONE, "F-9000 // FUEL SYSTEM SCHEMATIC // REV 05", Vector2(60, 40)],
		["kana", 30, LIME, "フューエル・ライン", Vector2(-1, 34)],
		["mono", 18, CYAN, "AG-COOLANT  >>", Vector2(60, 86)],
		["mono", 18, PINK, "AG-FUEL  >>", Vector2(60, 166)],
		["mono", 18, LIME, "MAIN FEED  >>", Vector2(230, 726)],
		["mono", 18, STONE, "P-01", Vector2(124, 968)],
		["mono", 18, STONE, "P-02", Vector2(1768, 270)],
		["mono", 18, STONE, "PSI", Vector2(503, 980)],
		["mono", 18, STONE, "FLOW", Vector2(673, 980)],
		["mono", 18, STONE, "TEMP", Vector2(853, 980)],
		["mono", 18, STONE, "SIGHT", Vector2(1100, 1000)],
		["mono", 18, STONE, "V-01", Vector2(RISER_X[0] + 30, 690)],
		["mono", 18, STONE, "V-02", Vector2(RISER_X[1] + 30, 690)],
		["mono", 18, STONE, "V-03", Vector2(RISER_X[2] + 30, 690)],
		["mono", 18, STONE, "V-04", Vector2(HEADER_X - 270, 214)],
	]
	for s in specs:
		var t: MotionText
		if s[0] == "kana":
			t = MotionText.new()
			t.font = MotionFonts.font("res://demo/ftf/ftf_fuel/assets/noto-jp-kana-700.woff2")
			t.font_size = s[1]
			t.color = s[2]
			t.text = s[3]
			_labels.add_child(t)
		else:
			t = FTFKit.text(_labels, s[0], s[1], s[2], s[3], 0.12)
		var pos: Vector2 = s[4]
		if pos.x < 0.0:
			pos.x = 1860 - t.get_text_size().x
		t.position = pos
		_net_labels.append(t)
	_ticker = FTFKit.text(_labels, "mono", 22, LIME, "", 0.1)
	_ticker.line_height = 1.4
	_ticker.position = Vector2(1300, 880)


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_fuel/audio/fuel_map.tres"
	const SONG := "res://demo/ftf/ftf_fuel/audio/music/fuel_song.tres"
	const TRACK := "res://demo/ftf/ftf_fuel/audio/ftf_fuel_track.res"
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


# ================================================================ time helpers

func _ease3(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


## Beats elapsed since `start` with each beat's step eased: pumped motion
## (lurches forward on every beat, glides between).
func _lurch(f: float, start: float, stop := INF) -> float:
	var t := (clampf(f, start, stop) - start) / BEAT
	var n := floorf(t)
	return n + _ease3((t - n) * 2.2)


## Main pump speed (radians per frame).
func _pump_speed(f: float, start: float, main: bool) -> float:
	if f < start:
		return 0.0
	var base := MK.interp(f, [start, start + 14.0, 120.0, 140.0, DROP - 20.0, DROP, HOLD_END, 384.0, LAST],
		[0.0, 0.18, 0.18, 0.3, 0.45, 0.62, 0.62, 0.2, 0.0])
	if not main:
		base = MK.interp(f, [start, start + 12.0, PURGE, PURGE + 8.0, HOLD_END, 384.0, LAST], [0.0, 0.25, 0.25, 0.7, 0.3, 0.1, 0.0])
	# a kick on every beat while it runs
	var ph := fposmod(f, BEAT)
	return base * (1.0 + 0.9 * exp(-ph * 0.6))


func _spin_table(speed: Callable) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(END + 2)
	var a := 0.0
	for i in END + 2:
		t[i] = a
		a += float(speed.call(float(i)))
	return t


func _spin(table: PackedFloat32Array, f: float) -> float:
	var i := clampi(int(floorf(f)), 0, table.size() - 2)
	return lerpf(table[i], table[i + 1], clampf(f - i, 0.0, 1.0))


## Valve opening 0..1 (spring overshoot on open, a snap on close).
func _valve(f: float, open_at: float, close_at := INF) -> float:
	var o := MK.spring(f, open_at, 10, 260)
	if f >= close_at:
		o = 1.0 - MK.spring(f, close_at, 12, 300)
	return o


func _front(f: float, a: float, b: float) -> float:
	return MK.map(f, [a, b], [0, 1], MK.ease_in_out)


# ================================================================ frame

func _frame(f: float) -> void:
	if not _built:
		return
	_stage.position = MK.shakes(f, [DROP], 22, 9) + MK.shakes(f, [MAIN_VALVE, MH_FULL], 6, 6)
	_frame_pipes(f)
	_frame_mh(f)
	_frame_ftf(f)
	_frame_labels(f)
	# from black and back to black
	var bg_on := MK.prog(f, 0.0, 6) * (1.0 - MK.map(f, [392.0, 404.0], [0, 1], MK.linear))
	_bg.color = Color.BLACK.lerp(BG, bg_on)
	_flash.visible = false


func _frame_pipes(f: float) -> void:
	var net_lurch := _lurch(f, MAIN_VALVE, LAST)
	var hold_gain := MK.map(f, [DROP - 4.0, DROP + 2.0], [0.35, 0.85], MK.linear) * (1.0 - MK.map(f, [CLOSES[0], 372.0], [0, 1], MK.linear))
	var purge := MK.map(f, [PURGE, PURGE + 4.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [PURGE + 18.0, PURGE + 34.0], [0, 1], MK.linear))
	_flow.apply(func(i: int) -> Variant:
		var d := {}
		var net_out := MK.map(f, [NET_UNDRAW + i * 2.0, NET_UNDRAW + 14.0 + i * 2.0], [0, 1], MK.ease_in_out)
		if i == _p_prime:
			d.draw = MK.map(f, [PRIME_PIPE, PRIME_PIPE + 14.0], [0, 1], MK.ease_in_out)
			d.draw_from = MK.map(f, [MH_DRAIN + 16.0, MH_DRAIN + 30.0], [0, 1], MK.ease_in_out)
			d.fill = _front(f, MH_VALVE, MH_FILL)
			d.drain = MK.map(f, [MH_FULL + 20.0, MH_DRAIN + 10.0], [0, 1], MK.ease_in_out)
			d.flow = _lurch(f, MH_VALVE, MH_DRAIN) * 34.0 + f * 1.5
			d.pulse_gain = 0.45
			d.front_glow = 1.0 if f < MH_FILL + 2.0 else 0.0
			d.bubbles = 6
			return d
		if i == _p_mh_drain:
			d.draw = MK.map(f, [MH_DRAIN - 10.0, MH_DRAIN], [0, 1], MK.ease_in_out)
			d.draw_from = MK.map(f, [MH_EMPTY + 4.0, MH_EMPTY + 18.0], [0, 1], MK.ease_in_out)
			d.fill = _front(f, MH_DRAIN + 2.0, MH_DRAIN + 16.0)
			d.drain = MK.map(f, [MH_EMPTY - 4.0, MH_EMPTY + 12.0], [0, 1], MK.ease_in_out)
			d.flow = _lurch(f, MH_DRAIN, MH_EMPTY + 20.0) * 40.0
			d.pulse_gain = 0.5
			d.front_glow = 1.0
			d.bubbles = 5
			return d
		# network pipes: drawn one after another from NET_DRAW
		var order := [_p_main, _p_risers[0], _p_risers[1], _p_risers[2], _p_header, _p_coolant, _p_cool_ret, _p_side].find(i)
		d.draw = MK.map(f, [NET_DRAW + order * 2.5, NET_DRAW + 12.0 + order * 2.5], [0, 1], MK.ease_in_out)
		d.draw_from = net_out
		d.flow = net_lurch * 42.0 + f * 2.0
		d.pulse_gain = hold_gain
		d.pulse_gap = 120.0
		d.pulse_len = 44.0
		d.glow = 0.35 + 0.35 * hold_gain
		d.bubbles = 8
		if i == _p_main:
			d.fill = _front(f, MAIN_VALVE, MAIN_VALVE + 16.0)
			d.drain = MK.map(f, [CLOSES[4], CLOSES[4] + 16.0], [0, 1], MK.ease_in_out)
			d.front_glow = 1.0
		elif _p_risers.has(i):
			var k := _p_risers.find(i)
			d.fill = _front(f, RISER_VALVES[k], RISER_VALVES[k] + 8.0)
			d.drain = MK.map(f, [CLOSES[k] + 2.0, CLOSES[k] + 10.0], [0, 1], MK.ease_in_out)
			d.front_glow = 1.0
			d.pulse_gap = 70.0
		elif i == _p_header:
			d.fill = _front(f, HEADER_VALVE, HEADER_VALVE + 14.0)
			d.drain = MK.map(f, [CLOSES[3] + 2.0, CLOSES[3] + 14.0], [0, 1], MK.ease_in_out)
			d.front_glow = 1.0
		elif i == _p_coolant or i == _p_cool_ret:
			var off := 0.0 if i == _p_coolant else 14.0
			d.fill = _front(f, COOLANT + off, COOLANT + 16.0 + off)
			d.drain = MK.map(f, [372.0 + off * 0.5, 386.0 + off * 0.5], [0, 1], MK.ease_in_out)
			d.flow = _spin(_spin2, f) * 40.0
			d.pulse_gain = maxf(0.4, hold_gain * 0.7) if f >= COOLANT else 0.0
			d.fluid = CYAN.lerp(WHITE, purge * 0.7)
			d.glow = 0.4 + 0.6 * purge
		elif i == _p_side:
			d.fill = _front(f, MAIN_VALVE + 8.0, MAIN_VALVE + 22.0)
			d.drain = MK.map(f, [CLOSES[4] + 4.0, CLOSES[4] + 18.0], [0, 1], MK.ease_in_out)
		return d)


func _frame_mh(f: float) -> void:
	var on := f < MH_EMPTY + 12.0
	_mh_ghost.visible = on
	_mh_tank.visible = on and f >= MH_FILL - 1.0
	_placard.visible = f >= PRESENTS and f < MH_EMPTY
	for l in _mh_labels:
		l.visible = on
	if not on:
		return
	var trace := MK.map(f, [MH_TRACE, MH_TRACE + 20.0], [0, 1], MK.ease_in_out)
	var ghost_o := 1.0 - MK.map(f, [MH_EMPTY - 6.0, MH_EMPTY + 8.0], [0, 1], MK.linear)
	_mh_ghost.apply(func(_i: int) -> Variant:
		if trace <= 0.0:
			return {hide = true}
		return {draw = trace, draw_width = 2.0, stroke = Color(SCFBrand.CREAM, 0.55 * ghost_o), fill_o = 0.0})
	var lv := MK.map(f, [MH_FILL, MH_FULL - 4.0], [-0.03, 1.12], MK.ease_in_out)
	if f >= MH_DRAIN:
		lv = MK.map(f, [MH_DRAIN, MH_EMPTY], [1.12, -0.06], MK.ease_in_out)
	_mh_tank.level = lv
	# placard rises into place as one plate, and leaves the same way
	var pin := MK.map(f, [PRESENTS, PRESENTS + 8.0], [0, 1], MK.ease_out)
	var pout := MK.map(f, [MH_DRAIN + 6.0, MH_DRAIN + 14.0], [0, 1], MK.ease_in_quad)
	_placard.modulate.a = pin * (1.0 - pout)
	_placard.position.y = MH_POS.y + 128.89 * _mh_k + 34.0 + (1.0 - pin) * 24.0 + pout * 24.0
	var lo := MK.prog(f, PRIME_PIPE + 6.0, 8) * (1.0 - MK.map(f, [MH_DRAIN, MH_DRAIN + 10.0], [0, 1], MK.linear))
	_mh_labels[0].modulate.a = lo
	_mh_labels[0].visible_chars = int(MK.map(f, [PRIME_PIPE + 6.0, PRIME_PIPE + 16.0], [0, 14], MK.linear))
	_mh_labels[1].modulate.a = MK.prog(f, MH_GAUGES[2] + 4.0, 6) * (1.0 - MK.map(f, [MH_DRAIN, MH_DRAIN + 10.0], [0, 1], MK.linear))


func _frame_ftf(f: float) -> void:
	var on := f >= RIM_TRACE and f < LAST + 2.0
	_ftf.visible = on
	if not on:
		return
	var trace := MK.map(f, [RIM_TRACE, RIM_TRACE + 16.0], [0, 1], MK.ease_in_out)
	var solid := MK.map(f, [RIM_TRACE + 10.0, RIM_TRACE + 20.0], [0, 1], MK.linear)
	var rim_o := 1.0 - MK.map(f, [RIM_OUT, RIM_OUT + 12.0], [0, 1], MK.linear)
	_rim.apply(func(_i: int) -> Variant:
		return {draw = trace, draw_width = 3.0, stroke = Color(PINK, rim_o), fill_o = solid * rim_o})
	# empty-tank look: dark interior and letters as outlines
	var gt := MK.map(f, [RIM_TRACE + 4.0, RIM_TRACE + 22.0], [0, 1], MK.ease_in_out)
	var ghost_o := 1.0 - MK.map(f, [TANK_EMPTY, RIM_OUT + 10.0], [0, 1], MK.linear)
	_ghost.apply(func(i: int) -> Variant:
		if i == FTFKit.RIM:
			return {hide = true}
		if i == FTFKit.PLATE:
			return {fill = Color("#121c2a"), o = gt * ghost_o}
		return {draw = gt, draw_width = 2.0, stroke = Color(PINK, 0.6 * ghost_o), fill_o = 0.0})
	# level: rises into the drop, brim-full in the hold (surface in the top band), drains out
	var lv := -0.03
	if f >= TANK_FILL:
		lv = lerpf(-0.03, 0.955, MK.ease_in_quad.call(clampf((f - TANK_FILL) / (DROP - TANK_FILL), 0.0, 1.0)))
	if f >= TANK_DRAIN:
		lv = MK.map(f, [TANK_DRAIN, TANK_EMPTY], [0.955, -0.06], MK.ease_in_out)
	_tank.level = lv
	_tank.visible = f >= TANK_FILL - 1.0 and f < TANK_EMPTY + 4.0
	# pressure ring round the rim
	var ring_on := MK.map(f, [DROP, DROP + 4.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [CLOSES[0], CLOSES[0] + 12.0], [0, 1], MK.linear))
	_rim_flow.visible = ring_on > 0.0
	if ring_on > 0.0:
		_rim_flow.set_state(0, {fill = 1.0, flow = _lurch(f, DROP, LAST) * 90.0 + f * 3.0, pulse_gain = 1.0,
			pulse_len = 70.0, pulse_gap = 260.0, glow = 0.0, opacity = ring_on})
	_sheen.visible = _sweep_x(f) > -1000.0


## X of the pressure-wave band (logo-local px), or -INF when none is running.
func _sweep_x(f: float) -> float:
	for at in SWEEPS:
		if f >= at and f < at + 14.0:
			return MK.map(f, [at, at + 14.0], [-300.0, LOGO_W + 300.0], MK.ease_in_out)
	if f >= DROP and f < DROP + 12.0:
		return MK.map(f, [DROP, DROP + 12.0], [-300.0, LOGO_W + 300.0], MK.ease_out)
	return -INF


func _draw_sheen_mask(c: MotionCanvas, f: float) -> void:
	var x := _sweep_x(f)
	if x < -1000.0:
		return
	var h := 340.0 * _k
	var w := 120.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - w, h), Vector2(x, h), Vector2(x + 160.0, 0), Vector2(x + 160.0 - w, 0)]), Color.WHITE)


func _frame_labels(f: float) -> void:
	var a := MK.prog(f, NET_DRAW + 6.0, 10) * (1.0 - MK.map(f, [NET_UNDRAW, NET_UNDRAW + 16.0], [0, 1], MK.linear))
	for i in _net_labels.size():
		var t := _net_labels[i]
		t.modulate.a = a if i > 1 else MK.prog(f, 4.0 + i * 4.0, 8) * (1.0 - MK.map(f, [NET_UNDRAW, NET_UNDRAW + 16.0], [0, 1], MK.linear))
		t.visible = t.modulate.a > 0.01
	# readouts tick on every beat in the hold
	var load := clampf(_tank.level / 0.955, 0.0, 1.0) if f >= TANK_FILL else 0.0
	var step := floorf(f / BEAT)
	var psi := int(lerpf(0.0, 4200.0, _gauge_value(f, 0)) + MK.rand(step * 1.3) * 40.0)
	var lps := int(_pump_speed(f, 0.0, true) * 660.0)
	_ticker.text = "FUEL LOAD %3d%%\nPSI       %4d\nFLOW %4d L/S" % [int(load * 100.0), psi, lps]
	_ticker.modulate.a = a * MK.prog(f, MAIN_VALVE, 8)
	_ticker.visible = _ticker.modulate.a > 0.01


# ================================================================ parts

## Network gauge values 0..1: g 0 = PSI, 1 = FLOW, 2 = TEMP.
func _gauge_value(f: float, g: int) -> float:
	var keys := [[MAIN_VALVE, 0.28], [HEADER_VALVE, 0.42], [RISER_VALVES[0], 0.55], [RISER_VALVES[1], 0.64], [RISER_VALVES[2], 0.74], [DROP, 0.96]]
	if g == 1:
		keys = [[MAIN_VALVE + 4.0, 0.35], [RISER_VALVES[0], 0.6], [DROP, 0.86]]
	elif g == 2:
		keys = [[COOLANT, 0.3], [DROP, 0.62], [PURGE, 0.38]]
	var v := 0.04
	for kv in keys:
		v = lerpf(v, float(kv[1]), MK.spring(f, float(kv[0]), 9, 240))
	if f >= DROP + 4.0 and f < HOLD_END:
		var ph := fposmod(f, BEAT)
		v += 0.05 * exp(-ph * 0.5) * (1.0 if g != 2 else 0.4) - 0.02
		v += (MK.rand(floorf(f / 2.0) * 3.1 + g) - 0.5) * 0.02
	if f >= CLOSES[0]:
		v = lerpf(v, 0.02, MK.map(f, [CLOSES[0] + g * 5.0, 380.0 + g * 4.0], [0, 1], MK.ease_in_out))
	return v


func _mh_gauge_value(f: float, g: int) -> float:
	var targets := [0.72, 0.55, 0.86]
	var v := lerpf(0.04, float(targets[g]), MK.spring(f, float(MH_GAUGES[g]), 8, 240))
	if f >= MH_GAUGES[g] + 6.0:
		v += (MK.rand(floorf(f / 2.0) * 1.7 + g * 9.0) - 0.5) * 0.025
	if f >= MH_DRAIN:
		v = lerpf(v, 0.04, MK.map(f, [MH_DRAIN, MH_DRAIN + 14.0], [0, 1], MK.ease_in_out))
	return v


func _draw_gauge(c: MotionCanvas, ctr: Vector2, r: float, v: float, needle: Color, o: float) -> void:
	if o <= 0.0:
		return
	c.circle(ctr, r, FACE, o)
	c.ring(ctr, r, CHROME, 4.0, o)
	var a0 := deg_to_rad(135.0)
	var span := deg_to_rad(270.0)
	c.draw_arc(ctr, r * 0.8, a0 + span * 0.8, a0 + span, 16, Color(AMBER, 0.85 * o), r * 0.1, true)
	for i in 11:
		var a := a0 + span * i / 10.0
		var d := Vector2(cos(a), sin(a))
		var inner := 0.66 if i % 5 == 0 else 0.74
		c.line(ctr + d * r * inner, ctr + d * r * 0.86, CHROME, 3.0 if i % 5 == 0 else 2.0, o)
	var an := a0 + span * clampf(v, -0.02, 1.04)
	var dn := Vector2(cos(an), sin(an))
	c.line(ctr - dn * r * 0.16, ctr + dn * r * 0.8, needle, 4.0, o)
	c.circle(ctr, r * 0.1, CHROME, o)


func _draw_pump(c: MotionCanvas, ctr: Vector2, r: float, ang: float, fluid: Color, lit: float, o: float) -> void:
	if o <= 0.0:
		return
	c.circle(ctr, r, CORE, o)
	if lit > 0.0:
		c.circle(ctr, r * 0.86, Color(fluid, 0.35 * lit), o)
	for b in 5:
		var a := ang + TAU * b / 5.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		c.polygon(PackedVector2Array([ctr + n * r * 0.1, ctr + d * r * 0.78 + n * r * 0.22, ctr + d * r * 0.82 - n * r * 0.02, ctr - n * r * 0.1]),
			fluid.lerp(CHROME, 0.5 - 0.4 * lit), Color(0, 0, 0, 0), 0.0, o)
	c.ring(ctr, r, CHROME, 6.0, o)
	c.circle(ctr, r * 0.16, CHROME, o)


func _draw_valve(c: MotionCanvas, ctr: Vector2, open: float, vertical: bool, o: float) -> void:
	if o <= 0.0:
		return
	c.circle(ctr, 20.0, CORE, o)
	c.ring(ctr, 20.0, CHROME, 4.0, o)
	# butterfly disc: across the pipe when shut, along it when open
	var base := 0.0 if vertical else PI * 0.5
	var a := base + PI * 0.5 * (1.0 - open)
	var d := Vector2(sin(a), -cos(a))
	c.line(ctr - d * 15.0, ctr + d * 15.0, LIME.lerp(AMBER, 1.0 - clampf(open, 0.0, 1.0)), 6.0, o)
	c.circle(ctr, 4.0, CHROME, o)


func _draw_sight(c: MotionCanvas, r: Rect2, lv: float, kicks: Array, fluid: Color, f: float, o: float) -> void:
	if o <= 0.0:
		return
	c.rect(r, CORE, o)
	var pts := PackedVector2Array()
	var n := 8
	for i in n + 1:
		var u := float(i) / n
		var y := r.end.y - r.size.y * lv - MotionLiquidFill.slosh(f, u, kicks, 7.0, 0.55, 0.08)
		pts.append(Vector2(r.position.x + r.size.x * u, clampf(y, r.position.y, r.end.y)))
	var poly := pts.duplicate()
	poly.append(r.end)
	poly.append(Vector2(r.position.x, r.end.y))
	if lv > 0.0:
		c.polygon(poly, fluid, Color(0, 0, 0, 0), 0.0, o)
		c.polyline(pts, WHITE, 3.0, 0.8 * o)
	c.rect(r, CHROME, o, 3.0)
	for t in 5:
		var y2 := r.position.y + r.size.y * (t + 1) / 6.0
		c.line(Vector2(r.end.x, y2), Vector2(r.end.x + 10.0, y2), CHROME, 2.0, o)


## Fuel thrown off the tank top: ballistic droplets from `at`, `n` of them.
func _splash(c: MotionCanvas, f: float, at: float, n: int, power: float, seed_v: float) -> void:
	var t := f - at
	if t < 0.0 or t > 24.0:
		return
	var top := LOGO_POS.y + 6.0
	for k in n:
		var r1 := MK.rand(k * 3.7 + seed_v)
		var x0 := LOGO_POS.x + 60.0 + r1 * (LOGO_W - 120.0)
		var vy := -(12.0 + 18.0 * MK.rand(k * 1.9 + seed_v)) * power
		var vx := (MK.rand(k * 5.3 + seed_v) - 0.5) * 9.0 * power
		var p := Vector2(x0 + vx * t, top + vy * t + 0.9 * t * t)
		if p.y > top + 4.0 and t > 2.0:
			continue
		var rad := (3.0 + 7.0 * MK.rand(k * 7.1 + seed_v)) * (1.0 - t / 30.0)
		var col: Color = [LIME, PINK, WHITE, LIME][k % 4]
		c.circle(p, rad, col, 1.0 - MK.map(t, [14.0, 24.0], [0, 1], MK.linear))


func _draw_parts(c: MotionCanvas, f: float) -> void:
	_splash(c, f, DROP, 70, 1.0, 11.0)
	for i in SWEEPS.size():
		_splash(c, f, SWEEPS[i], 18, 0.55, 30.0 + i * 7.0)
	# pumps
	var p1_o := MK.prog(f, 0.0, 8) * (1.0 - MK.map(f, [384.0, 398.0], [0, 1], MK.linear))
	var lit1 := MK.map(f, [MH_VALVE, MH_VALVE + 6.0], [0, 1], MK.linear) * (1.0 - MK.map(f, [CLOSES[4], 384.0], [0, 1], MK.linear))
	var p1_fluid := AMBER if f < MAIN_VALVE else LIME
	_draw_pump(c, P1, 52.0, _spin(_spin1, f), p1_fluid, lit1, p1_o)
	var p2_o := MK.prog(f, NET_DRAW + 14.0, 8) * (1.0 - MK.map(f, [384.0, 398.0], [0, 1], MK.linear))
	_draw_pump(c, P2, 46.0, -_spin(_spin2, f), CYAN, MK.map(f, [COOLANT, COOLANT + 8.0], [0, 1], MK.linear), p2_o)
	# primer valve and gauges (Act I)
	var mh_o := MK.prog(f, PRIME_PIPE + 8.0, 6) * (1.0 - MK.map(f, [MH_DRAIN + 10.0, MH_DRAIN + 22.0], [0, 1], MK.linear))
	_draw_valve(c, Vector2(P1.x, 760), _valve(f, MH_VALVE, MH_DRAIN + 8.0), true, mh_o)
	for g in 3:
		var go := MK.prog(f, MH_GAUGES[g] - 6.0, 6) * (1.0 - MK.map(f, [MH_DRAIN, MH_DRAIN + 12.0], [0, 1], MK.linear))
		_draw_gauge(c, Vector2(1420 + g * 150.0, 920), 58.0, _mh_gauge_value(f, g), AMBER, go)
	# network valves
	var net_o := MK.prog(f, NET_DRAW + 10.0, 8) * (1.0 - MK.map(f, [NET_UNDRAW + 6.0, NET_UNDRAW + 20.0], [0, 1], MK.linear))
	_draw_valve(c, Vector2(P1.x, 830), _valve(f, MAIN_VALVE, CLOSES[4]), true, net_o if f >= MH_DRAIN + 22.0 else 0.0)
	for k in 3:
		_draw_valve(c, Vector2(RISER_X[k], 690), _valve(f, RISER_VALVES[k], CLOSES[k]), true, net_o)
	_draw_valve(c, Vector2(HEADER_X - 180.0, 200), _valve(f, HEADER_VALVE, CLOSES[3]), false, net_o)
	# gauges (network)
	var cols := [LIME, LIME, CYAN]
	for g in 3:
		var go2 := MK.prog(f, NET_DRAW + 14.0 + g * 3.0, 8) * (1.0 - MK.map(f, [376.0 + g * 3.0, 392.0 + g * 3.0], [0, 1], MK.linear))
		_draw_gauge(c, Vector2(520 + g * 180.0, 900), 62.0, _gauge_value(f, g), cols[g], go2)
	# sight glasses on the side line
	var sk := [Vector2(MAIN_VALVE + 16.0, 0.8), Vector2(DROP, 1.4)]
	for k in 13:
		sk.append(Vector2(DROP + BEAT * (k + 1), 0.5))
	sk.append(Vector2(CLOSES[4], 1.0))
	for s in 3:
		var sv := MK.map(f, [MAIN_VALVE + 14.0 + s * 3.0, DROP], [0.0, 0.55 + 0.15 * s], MK.ease_out)
		if f >= CLOSES[4]:
			sv = MK.map(f, [CLOSES[4], 384.0], [0.55 + 0.15 * s, 0.0], MK.ease_in_out)
		var so := MK.prog(f, NET_DRAW + 16.0 + s * 2.0, 8) * (1.0 - MK.map(f, [380.0, 394.0], [0, 1], MK.linear))
		_draw_sight(c, Rect2(1080 + s * 54.0, 840, 34, 150), sv, sk, [LIME, CYAN, PINK][s], f + s * 3.0, so)


func _draw_grid(c: MotionCanvas, f: float) -> void:
	var o := MK.prog(f, 0.0, 12) * (1.0 - MK.map(f, [396.0, 406.0], [0, 1], MK.linear))
	if o <= 0.0:
		return
	for x in range(0, 1921, 60):
		c.line(Vector2(x, 0), Vector2(x, 1080), GRID, 1.0, o)
	for y in range(0, 1081, 60):
		c.line(Vector2(0, y), Vector2(1920, y), GRID, 1.0, o)
	for x in range(120, 1920, 240):
		for y in range(120, 1080, 240):
			FTFKit.plus(c, Vector2(x, y), 6.0, Color(CYAN, 0.25), 1.0, o)
