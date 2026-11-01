# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take: CABLES CABLES CABLES.
#
# Brief: thick, glossy, shaded cables everywhere on dark graphite. Everything is
# powered by plugging in: cables snake in from the frame edges, sag, slam their
# connectors home and pull taut on the beat; light pulses race along them; the
# logos are dead silhouettes until the current arrives.
#   I   MINIMAL HUMANS. A dead lockup above a patch strip. Three cables in the
#       studio's red, amber and cream snake in from below; their connectors slam
#       into the strip on beats 1-3 and each powers its layer of the M. On the bar
#       the cables pull taut and the current runs through the wordmark; PRESENTS
#       lights. Pulses race up the cables on the beat. Then the plugs are yanked
#       on sixteenths, the layers die, the cables whip back out of frame.
#   II  COCOON. Six cables in FTF colours snake in from both sides and wrap the
#       dead FTF plate, over the front and around the back, until it is bound.
#       They squeeze on the beats (creak, twitch) while pulses race round them and
#       the camera creeps in; then they are ripped off, unwinding back out of frame.
#   III DROP. Eight cables harpoon in from off frame and slam into the plate's rim
#       on the downbeat: the logo powers on big and suspended in tension. Hold:
#       pulses arrive at the rim on every beat (rim LEDs blink), cables twitch on
#       accents, a surge glows through everything, tags ride the cables, the
#       plate sways on its lines. Outro: the plugs are pulled pair by pair, the
#       plate lurches as it loses support, powers down and falls out of frame.
#       Black to the end.
#
# Tempo: 90 bpm, 4/4, half-time. 20 frames a beat, 80 a bar, first downbeat at
# frame 0 (bars at 0, 80, 160, 240, 320, 400). Drop on bar 3 (frame 240, 8.0 s).
#
# Beats (30 fps, 420 frames):
#   0-20     cables snake in; 20/40/60 MH plugs slam home (red, amber, cream layers)
#   80       taut + current runs through the wordmark; 100 PRESENTS; pulses on beats
#   140/145/150  plugs yanked, layers die; 152-160 cables whip out
#   160-196  cocoon cables snake in and wrap the dead FTF plate (sixteenths)
#   200/220  squeeze (creak, twitch); camera creeps in
#   228-238  cocoon ripped off; 234 suspension cables harpoon in
#   240      DROP: eight plugs slam into the rim, logo powers on, shake
#   260-320  hold: pulses land on every beat, twitches 260/280/320, surge 300
#   336/344/352/360  plugs pulled pair by pair, plate lurches
#   360      powers down and falls; 378 crash off frame; 390-420 black
#
# Sound: the cue sheet in _init, scored by demo/ftf/ftf_cables/audio/ (recipes,
# cue map and a 90 bpm half-time song); the baked track plays without the audio
# kit linked.
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0
const BEAT := 20.0
const BAR := 80.0

# ---- Act I
const PLUG := [20.0, 40.0, 60.0]
const POWER := 80.0
const PRESENTS := 100.0
const UNPLUG := [140.0, 145.0, 150.0]
const MH_OUT := 152.0
# ---- Act II
const WRAP := 160.0
const SQUEEZE := [200.0, 220.0]
const PULL := 228.0
const HARPOON := 234.0
# ---- Act III
const DROP := 240.0
const PULSE_BEATS := [260.0, 280.0, 300.0, 320.0]
const TWITCH := [260.0, 280.0, 320.0]
const SURGE := 300.0
const OUT := [336.0, 344.0, 352.0, 360.0]
const FALL := 360.0
const CRASH := 378.0
const BLACK := 382.0
const END := 420

const GRAPHITE := Color("#17181c")
const DEAD := Color("#2b2c32")
const DEAD_PINK := Color("#3b2a33")
const BG_JACKET := Color("#26272d")
const FTF_DEAD := Color("#3a3b43")
const FTF_DEAD_PINK := Color("#4d3442")

# MH layout
const MH_W := 1080.0
const MH_POS := Vector2(420, 236)
const STRIP := Rect2(420, 600, 1080, 70)
const PORT_X := [560.0, 740.0, 920.0]
const MH_CABLE_W := 34.0
# FTF layout
const LOGO_W := 1440.0
const LOGO_C := Vector2(960, 492)
const SUS_W := 30.0

var _built := false
var _stage: Node2D
var _bg_set: MotionCableSet
var _bg_cables: Array = []
# act I
var _mh_group: Node2D
var _mh_set: MotionCableSet
var _mh_cables: Array = []
var _mh: MotionSvg
var _mh_k := 1.0
var _strip: MotionCanvas
var _presents: MotionText
var _presents_jp: MotionText
var _strip_label: MotionText
var _port_labels: Array[MotionText] = []
# act II / III
var _ftf_group: Node2D
var _back_set: MotionCableSet
var _front_set: MotionCableSet
var _wraps: Array = []
var _wrap_info: Array = []
var _sus: Array = []
var _fx: MotionFX
var _pivot: Node2D
var _logo: MotionSvg
var _logo_k := 1.0
var _jp: MotionText
var _pill: MotionPill
var _tags: Array[MotionText] = []
var _rim_canvas: MotionCanvas
var _black: ColorRect

# suspension cables: rim point (logo-local), inward plug direction, off-frame anchor (offset from LOGO_C)
const SUS := [
	{rim = Vector2(-660, -171), dir = Vector2(0, 1), anchor = Vector2(-1180, -720), col = "#e92067"},
	{rim = Vector2(-220, -171), dir = Vector2(0, 1), anchor = Vector2(-440, -780), col = "#d7ff1f"},
	{rim = Vector2(260, -171), dir = Vector2(0, 1), anchor = Vector2(440, -780), col = "#19c3e6"},
	{rim = Vector2(720, -40), dir = Vector2(-1, 0), anchor = Vector2(1260, -430), col = "#ff6a13"},
	{rim = Vector2(720, 90), dir = Vector2(-1, 0), anchor = Vector2(1260, 560), col = "#f2eee6"},
	{rim = Vector2(300, 171), dir = Vector2(0, -1), anchor = Vector2(540, 780), col = "#a98bff"},
	{rim = Vector2(-300, 171), dir = Vector2(0, -1), anchor = Vector2(-540, 780), col = "#d7ff1f"},
	{rim = Vector2(-720, 60), dir = Vector2(1, 0), anchor = Vector2(-1260, 440), col = "#e92067"},
]
# which suspension cables are pulled at each OUT step (right side first)
const OUT_ORDER := [[3, 4], [2, 5], [1, 6], [0, 7]]


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": DROP, "hold": DROP + 20.0, "out": OUT[0]}
	cue(0.0, &"snake", 0.6)
	for i in PLUG.size():
		cue(maxf(0.0, PLUG[i] - 22.0) if i > 0 else 4.0, &"snake", 0.5 + 0.1 * i, {pitch = [1.0, 0.9, 1.1][i]})
		cue(PLUG[i], &"plug.in", 0.7 + 0.1 * i, {pitch = [0.89, 1.0, 1.12][i]})
	cue(POWER, &"power.on", 0.9)
	cue(POWER, &"taut", 0.8)
	cue(PRESENTS, &"presents", 0.8)
	cue(120.0, &"pulse", 0.5)
	for i in UNPLUG.size():
		cue(UNPLUG[i], &"plug.out", 0.6 + 0.1 * i, {pitch = [1.12, 1.0, 0.89][i]})
	cue(MH_OUT, &"power.down", 0.7)
	for k in 6:
		cue(WRAP + k * 5.0, &"wrap", 0.5 + 0.05 * k, {pitch = 0.85 + 0.06 * k})
	for i in SQUEEZE.size():
		cue(SQUEEZE[i], &"squeeze", 0.7 + 0.15 * i)
	cue(DROP, &"riser", 1.0)          # its recipe swells in ahead and peaks on the drop
	cue(PULL, &"rip", 0.9)
	cue(DROP, &"drop", 1.0)
	for b in PULSE_BEATS:
		cue(b, &"pulse", 0.6, {pitch = 1.0 + 0.06 * PULSE_BEATS.find(b)})
	for t in TWITCH:
		cue(t, &"taut", 0.5 if t != 320.0 else 0.8, {pitch = 1.1})
	cue(SURGE, &"surge", 0.8)
	for i in OUT.size():
		cue(OUT[i], &"plug.out", 0.75 + 0.06 * i, {pitch = [1.12, 1.0, 0.94, 0.84][i]})
	cue(FALL + 2.0, &"power.down", 0.9)
	cue(FALL + 4.0, &"fall", 0.8)
	cue(CRASH, &"crash", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = GRAPHITE
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	var panel := MotionCanvas.new()
	panel.draw_fn = _draw_panel
	_stage.add_child(panel)
	_bg_set = MotionCableSet.new()
	_stage.add_child(_bg_set)
	_build_bg_cables()
	_build_mh()
	_build_ftf()
	var vig := MotionGradient.radial(size, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6)], [0.0, 0.45, 1.0], Vector2(0.5, 0.48))
	add_child(vig)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = size
	add_child(_black)
	_add_sound()


func _build_bg_cables() -> void:
	var routes := [
		[Vector2(-160, -20), Vector2(2080, 60)],
		[Vector2(-160, 120), Vector2(1100, 40), Vector2(2080, 200)],
		[Vector2(-160, 760), Vector2(2080, 700)],
		[Vector2(-160, 930), Vector2(900, 1000), Vector2(2080, 900)],
		[Vector2(330, -160), Vector2(160, 520), Vector2(-160, 1200)],
		[Vector2(1620, -160), Vector2(1800, 560), Vector2(2080, 1200)],
	]
	var stripes := [FTFKit.PINK, FTFKit.LIME, FTFKit.CYAN, FTFKit.ORANGE, FTFKit.LILAC, FTFKit.CREAM]
	for i in routes.size():
		var c := MotionCable.new()
		c.points = PackedVector2Array(routes[i])
		c.width = [18.0, 22.0, 20.0, 26.0, 16.0, 18.0][i]
		c.jacket = BG_JACKET
		c.gloss = 0.45
		c.sag = [70.0, 60.0, 40.0, 50.0, 30.0, 30.0][i]
		c.tension = 0.25
		c.stripe_every = 260.0 + i * 30.0
		c.stripe_len = 14.0
		c.stripe_color = (stripes[i] as Color).darkened(0.45)
		c.stripe_phase = i * 77.0
		c.shadow = Color(0, 0, 0, 0.35)
		c.shadow_offset = Vector2(6, 9)
		c.z = -10.0
		_bg_cables.append(c)
	_bg_set.cables = _bg_cables


func _build_mh() -> void:
	_mh_group = Node2D.new()
	_stage.add_child(_mh_group)
	_mh_set = MotionCableSet.new()
	_mh_group.add_child(_mh_set)
	var cols := [FTFKit.MH_RED, FTFKit.MH_AMBER, FTFKit.MH_CREAM]
	var routes := [
		[Vector2(-180, 1160), Vector2(140, 980), Vector2(360, 1050), Vector2(560, 940)],
		[Vector2(760, 1260), Vector2(880, 1080), Vector2(640, 1010), Vector2(740, 930)],
		[Vector2(2100, 1120), Vector2(1640, 990), Vector2(1240, 1070), Vector2(920, 940)],
	]
	for i in 3:
		var c := MotionCable.new()
		var rear := Vector2(PORT_X[i], STRIP.end.y + MotionCable.plug_length(MotionCable.Plug.MULTIPIN, MH_CABLE_W) - 22.0)
		var pts: Array = routes[i].duplicate()
		pts.append(rear)
		c.points = PackedVector2Array(pts)
		c.width = MH_CABLE_W
		c.jacket = cols[i]
		c.plug_head = MotionCable.Plug.MULTIPIN
		c.plug_color = Color("#1c1d22")
		c.sag = 160.0
		c.gloss = 0.85
		c.bands = [{u = 0.86, len = 26.0, color = Color("#111114")}]
		_mh_cables.append(c)
	_mh_set.cables = _mh_cables
	_strip = MotionCanvas.new()
	_strip.draw_fn = _draw_strip
	_mh_group.add_child(_strip)
	_mh = MotionSvg.new()
	_mh.data = _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_mh.width = MH_W
	_mh.position = MH_POS
	_mh_group.add_child(_mh)
	_mh_k = MH_W / _mh.data.view_box.size.x
	_strip_label = FTFKit.text(_mh_group, "mono", 18, FTFKit.STONE, "PATCH BAY 01 // MINIMAL HUMANS // FOSS STUDIO BERLIN", 0.12)
	_strip_label.position = Vector2(STRIP.position.x, STRIP.position.y - 34)
	for i in 3:
		var t := FTFKit.text(_mh_group, "mono", 16, FTFKit.STONE, ["L1 / RED", "L2 / AMBER", "L3 / CREAM"][i], 0.1)
		t.position = Vector2(PORT_X[i] + 40, STRIP.position.y + 14)
		_port_labels.append(t)
	_presents = FTFKit.text(_mh_group, "heavy", 46, DEAD, "PRESENTS", 0.36)
	_presents.position = Vector2(STRIP.end.x - 30 - _presents.get_text_size().x, STRIP.position.y + 4)
	_presents_jp = FTFKit.text(_mh_group, "jp", 22, DEAD, "ミニマル・ヒューマンズ　提供")
	_presents_jp.position = Vector2(STRIP.end.x - 30 - _presents_jp.get_text_size().x, STRIP.end.y + 14)


func _build_ftf() -> void:
	_ftf_group = Node2D.new()
	_stage.add_child(_ftf_group)
	_back_set = MotionCableSet.new()
	_back_set.z_max = -0.5
	_ftf_group.add_child(_back_set)
	_fx = MotionFX.new()
	_fx.size = size
	_fx.glow = 16.0
	_fx.glow_strength = 0.0
	_ftf_group.add_child(_fx)
	_pivot = Node2D.new()
	_pivot.position = LOGO_C
	_fx.content.add_child(_pivot)
	_logo = MotionSvg.new()
	_logo.data = _svg(FTFKit.LOGO)
	_logo.width = LOGO_W
	_logo_k = LOGO_W / _logo.data.view_box.size.x
	_logo.position = -_logo.data.view_box.size * _logo_k * 0.5
	_pivot.add_child(_logo)
	_rim_canvas = MotionCanvas.new()
	_rim_canvas.draw_fn = _draw_rim
	_pivot.add_child(_rim_canvas)
	_jp = FTFKit.text(_pivot, "jp", 46, FTFKit.LIME, "フルスロットル・フラックス")
	_jp.position = Vector2(-700, 206)
	_pill = FTFKit.pill(_pivot, "F-9000 // ANTI-GRAVITY LEAGUE", FTFKit.PINK, FTFKit.WHITE, 24)
	_pill.position = Vector2(700 - _pill.get_box_size().x * 0.5, 236)
	_front_set = MotionCableSet.new()
	_front_set.z_min = -0.5
	_ftf_group.add_child(_front_set)
	_build_wraps()
	_build_suspension()
	for i in SUS.size():
		var t := FTFKit.text(_ftf_group, "mono", 16, FTFKit.STONE, "CH-%02d // %d V" % [i + 1, [48, 120, 400, 230, 48, 400, 120, 230][i]], 0.1)
		_tags.append(t)


## Six cables wrapping the plate: in from a side, then diagonals across the front
## (z +1), tight U-turns round the top and bottom edges (z +1), and diagonals round
## the back (z -1, hidden behind the plate). Left and right cables cross into a lattice.
func _build_wraps() -> void:
	var half_h := LOGO_W / _logo.data.view_box.size.x * _logo.data.view_box.size.y * 0.5
	var top := LOGO_C.y - half_h - 10.0
	var bot := LOGO_C.y + half_h + 10.0
	var x_min := LOGO_C.x - LOGO_W * 0.5 + 40.0
	var x_max := LOGO_C.x + LOGO_W * 0.5 - 40.0
	var cols := [FTFKit.PINK, FTFKit.LIME, FTFKit.CYAN, FTFKit.ORANGE, FTFKit.CREAM, FTFKit.LILAC]
	var widths := [34.0, 30.0, 32.0, 36.0, 28.0, 30.0]
	for k in 6:
		var w: float = widths[k]
		var sgn := 1.0 if k % 2 == 0 else -1.0
		var x := (x_min + k * 28.0) if sgn > 0.0 else (x_max - k * 28.0)
		var step := 110.0 + (k % 3) * 20.0
		var turn := w * 2.8   # bend radius well above the cable's own radius
		var on_top := k % 4 < 2
		var pts := []
		var zr := []
		var entry_y := (top - 160.0 + k * 50.0) if on_top else (bot + 160.0 - k * 50.0)
		pts.append(Vector2(-260.0 if sgn > 0.0 else W + 260.0, entry_y))
		pts.append(Vector2(x - sgn * 120.0, (top if on_top else bot) + (-70.0 if on_top else 70.0)))
		var spans := []      # z per span after the lead-in
		var front := true
		while (sgn > 0.0 and x < x_max) or (sgn < 0.0 and x > x_min):
			var e := top if on_top else bot
			var out := -1.0 if on_top else 1.0
			# a rounded U round the edge: down to the edge, out, across, back in
			pts.append(Vector2(x, e))
			pts.append(Vector2(x + sgn * turn * 0.12, e + out * turn * 0.4))
			pts.append(Vector2(x + sgn * turn * 0.5, e + out * turn * 0.55))
			pts.append(Vector2(x + sgn * turn * 0.88, e + out * turn * 0.4))
			pts.append(Vector2(x + sgn * turn, e))
			for q in 4:
				spans.append(1.0)                   # the U-turn round the edge
			spans.append(1.0 if front else -1.0)    # the diagonal to the other edge
			x += sgn * (step + turn)
			on_top = not on_top
			front = not front
		pts.append(Vector2(x - sgn * step * 0.5, LOGO_C.y))   # tuck the end behind the plate
		spans[spans.size() - 1] = -1.0
		var lens := [0.0]
		for i in range(1, pts.size()):
			lens.append(float(lens[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
		var total: float = lens[lens.size() - 1]
		for j in spans.size():
			var i := j + 2
			if i + 1 < lens.size():
				zr.append([float(lens[i]) / total, float(lens[i + 1]) / total, spans[j]])
		var c := MotionCable.new()
		c.points = PackedVector2Array(pts)
		c.pinned = true
		c.width = w
		c.jacket = cols[k]
		c.tension = 1.0
		c.sag = 0.0
		c.samples = 7
		c.z = 1.0
		c.z_ranges = zr
		c.stripe_every = 200.0
		c.stripe_len = 12.0
		c.stripe_color = Color("#111114")
		c.stripe_phase = k * 40.0
		c.shadow_offset = Vector2(10, 16)
		_wraps.append(c)
	_back_set.cables = _bg_none() + _wraps
	_front_set.cables = _wraps.duplicate()


func _bg_none() -> Array:
	return []


func _build_suspension() -> void:
	for i in SUS.size():
		var c := MotionCable.new()
		c.width = SUS_W
		c.jacket = Color(SUS[i].col)
		c.plug_head = MotionCable.Plug.MULTIPIN
		c.plug_color = Color("#1c1d22")
		c.tension = 1.0
		c.sag = 60.0
		c.z = -1.0
		c.gloss = 0.9
		c.bands = [{u = 0.9, len = 22.0, color = Color("#111114")}, {u = 0.2, len = 30.0, color = Color("#111114")}]
		_sus.append(c)
	_back_set.cables = _back_set.cables + _sus


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_cables/audio/cables_map.tres"
	const SONG := "res://demo/ftf/ftf_cables/audio/music/cables_song.tres"
	const TRACK := "res://demo/ftf/ftf_cables/audio/ftf_cables_track.res"
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

## Power of a thing switched on at `on` and off at `off` (quick ramps, no flashing).
static func _power(f: float, on: float, off := INF, ramp := 3.0) -> float:
	if f < on:
		return 0.0
	var p := clampf((f - on) / ramp, 0.0, 1.0)
	if f >= off:
		p *= 1.0 - clampf((f - off) / ramp, 0.0, 1.0)
	return p


## A pulse that travels the cable from its tail and arrives at its head on `arrive`.
static func _pulse(f: float, arrive: float, travel: float, col: Color, len := 120.0) -> Dictionary:
	var u := 1.0 - (arrive - f) / travel
	return {u = u, len = len, color = col, power = 1.0 if u <= 1.0 else maxf(0.0, 1.0 - (u - 1.0) * 6.0)}


func _pulses_for(f: float, beats: Array, travel: float, col: Color) -> Array:
	var out := []
	for b in beats:
		var u := 1.0 - (float(b) - f) / travel
		if u > -0.05 and u < 1.12:
			out.append(_pulse(f, float(b), travel, col))
	return out


func _logo_xf(f: float) -> Transform2D:
	return Transform2D(_pivot.rotation, _pivot.scale, 0.0, _pivot.position)


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	# camera: creep in during the cocoon, snap back on the drop; shakes on slams
	var creep := MK.map(f, [WRAP, DROP - 2.0], [0, 1], MK.ease_in_quad) if f < DROP else 0.0
	var s := 1.0 + 0.05 * creep + 0.025 * (1.0 - MK.spring(f, DROP, 10, 200)) * (1.0 if f >= DROP else 0.0)
	var shake := MK.shakes(f, PLUG, 9, 7) + MK.shakes(f, [DROP], 26, 12) + MK.shakes(f, SQUEEZE + [POWER] + OUT, 6, 6) + MK.shakes(f, [CRASH], 14, 10)
	_stage.scale = Vector2.ONE * s
	_stage.position = Vector2(W, H) * 0.5 * (1.0 - s) + shake
	_frame_bg(f)
	_frame_mh(f)
	_frame_ftf(f)
	_black.color.a = MK.map(f, [BLACK, BLACK + 10.0], [0, 1], MK.linear) if f < END else 1.0
	_black.color.a = maxf(_black.color.a, 1.0 - MK.map(f, [0, 8], [0, 1], MK.linear))
	_black.visible = _black.color.a > 0.001


func _frame_bg(f: float) -> void:
	var hits := PLUG + [POWER, DROP, SURGE] + TWITCH + OUT
	for i in _bg_cables.size():
		var c: MotionCable = _bg_cables[i]
		c.gravity = Vector2(sin(f / 41.0 + i * 1.3) * 0.18, 1.0)
		c.tension = 0.25 + 0.1 * sin(f / 29.0 + i)
		var tg := []
		for h in hits:
			if f >= float(h) and f < float(h) + 60.0:
				tg.append(MotionCable.tug(float(h), 10.0 + i * 1.5, 11.0 + i, 18.0))
		c.tugs = tg
		# a faint pulse on the beat in the hold keeps the back alive
		c.pulses = []
		if f >= DROP and f < OUT[0]:
			for b in [260.0, 280.0, 300.0, 320.0]:
				var u := (f - float(b) + 6.0) / 30.0
				if u > 0.0 and u < 1.0:
					c.pulses.append({u = u if i % 2 == 0 else 1.0 - u, len = 70.0, color = FTFKit.CYAN if i % 2 == 0 else FTFKit.PINK, power = 0.35})


func _frame_mh(f: float) -> void:
	_mh_group.visible = f < WRAP + 2.0
	if not _mh_group.visible:
		return
	_mh_group.modulate.a = MK.map(f, [MH_OUT + 2.0, WRAP], [1, 0], MK.linear)
	var taut := MK.spring(f, POWER, 9, 170) if f >= POWER else 0.0
	for i in 3:
		var c: MotionCable = _mh_cables[i]
		var at: float = PLUG[i]
		var t0 := maxf(0.0, at - 24.0)
		# snake in along the route, accelerating into the slam; yank back out
		var rin := MK.map(f, [t0, at], [0, 1], MK.ease_in_quad)
		var out_t: float = UNPLUG[i]
		var rout := MK.map(f, [out_t, out_t + 9.0], [0, 1], MK.ease_in_quad)
		c.reveal = rin * (1.0 - rout)
		c.tension = lerpf(0.0, 1.0, taut) * (1.0 - rout * 0.8)
		c.tugs = [MotionCable.tug(at, 22.0, 10.0, 12.0), MotionCable.tug(POWER, 30.0, 9.0, 14.0), MotionCable.tug(out_t, 46.0, 7.0, 10.0)]
		var lit := _power(f, at, out_t, 3.0)
		c.plug_lit = lit
		c.glow = 0.35 * lit
		c.glint = fposmod((f - at) / 40.0, 1.0) if lit > 0.0 else -1.0
		c.pulses = _pulses_for(f, [100.0, 120.0, 140.0], 18.0, Color(c.jacket).lightened(0.3)) if f >= POWER and f < out_t else []

	# the lockup: dead until the current arrives
	var front := MK.map(f, [POWER, POWER + 9.0], [140.0, 530.0], MK.ease_in_out)
	var word_off := _power(f, 0.0, UNPLUG[2], 3.0)
	_mh.apply(func(i: int) -> Variant:
		var orig: Color = _mh.data.parts[i].fill
		if i <= 2:
			# parts 0, 1, 2 are the red, amber and cream layers: cable i powers part i
			var p := _power(f, PLUG[i], UNPLUG[i], 3.0)
			return {fill = DEAD.lerp(orig, p)}
		var bb: Rect2 = _mh.data.parts[i].bbox
		var cx := bb.get_center().x
		var p2 := 0.0
		if f >= POWER:
			p2 = clampf((front - cx) / 18.0, 0.0, 1.0) * word_off
		var col := DEAD.lerp(orig, p2)
		var hot := clampf(1.0 - absf(front - cx) / 40.0, 0.0, 1.0) * (1.0 if f < POWER + 10.0 and f >= POWER else 0.0)
		return {fill = col.lerp(Color.WHITE, hot * 0.7)})
	var pr := _power(f, PRESENTS, UNPLUG[1], 4.0)
	_presents.color = DEAD.lerp(FTFKit.MH_CREAM, pr)
	_presents_jp.color = DEAD.lerp(FTFKit.MH_AMBER, pr)
	_strip_label.modulate.a = MK.prog(f, 4, 10)
	for i in 3:
		_port_labels[i].color = FTFKit.STONE.lerp(Color([FTFKit.MH_RED, FTFKit.MH_AMBER, FTFKit.MH_CREAM][i]), _power(f, PLUG[i], UNPLUG[i]))


func _draw_panel(c: MotionCanvas, f: float) -> void:
	# graphite wall: panel seams, rivets, stencil marks
	var seam := Color("#202126")
	for x in range(0, 1921, 240):
		c.line(Vector2(x, 0), Vector2(x, 1080), seam, 3.0)
	for y in range(0, 1081, 270):
		c.line(Vector2(0, y), Vector2(1920, y), seam, 3.0)
	for x in range(0, 1921, 240):
		for y in range(0, 1081, 270):
			for o in [Vector2(14, 14), Vector2(-14, 14), Vector2(14, -14), Vector2(-14, -14)]:
				c.circle(Vector2(x, y) + o, 3.5, Color("#26272d"))
	MotionMarks.hatch(c, MotionPoly.rect(Rect2(1680, 990, 200, 40)), 18, 7, Color("#222328"), 45.0, 0.0)
	MotionMarks.hatch(c, MotionPoly.rect(Rect2(40, 40, 200, 40)), 18, 7, Color("#222328"), 45.0, 0.0)


func _draw_strip(c: MotionCanvas, f: float) -> void:
	var r := STRIP
	c.rect(Rect2(r.position + Vector2(8, 12), r.size), Color(0, 0, 0, 0.5))
	c.rect(r, Color("#202127"))
	c.rect(Rect2(r.position, Vector2(r.size.x, 6)), Color("#34353c"))
	c.rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), Color("#0f0f12"))
	for i in 3:
		var lit := _power(f, PLUG[i], UNPLUG[i])
		var col := Color([FTFKit.MH_RED, FTFKit.MH_AMBER, FTFKit.MH_CREAM][i])
		var x: float = PORT_X[i]
		# the socket on the strip's lower edge, an LED above it
		c.rect(Rect2(x - 30, r.end.y - 18, 60, 18), Color("#0b0b0d"))
		c.rect(Rect2(x - 36, r.end.y - 22, 72, 5), Color("#8a8c93"))
		c.circle(Vector2(x, r.position.y + 26), 9.0, Color(col, 0.25 + 0.75 * lit))
		if lit > 0.0:
			c.circle(Vector2(x, r.position.y + 26), 20.0, Color(col, 0.25 * lit))



# ---------------------------------------------------------------- acts II / III

func _frame_ftf(f: float) -> void:
	_ftf_group.visible = f >= WRAP - 2.0 and f < BLACK + 12.0
	if not _ftf_group.visible:
		return
	_ftf_group.modulate.a = MK.map(f, [WRAP - 2.0, WRAP + 8.0], [0, 1], MK.linear)

	# -- the plate's motion: slam scale on the drop, sway in the hold, lurch and fall
	var slam := MK.spring(f, DROP, 11, 240) if f >= DROP else 0.0
	var sc := 1.0 + 0.06 * (1.0 - slam) * (1.0 if f >= DROP else 0.0)
	var sway := Vector2(sin(f / 23.0) * 7.0, sin(f / 17.0) * 5.0) * MK.map(f, [DROP, DROP + 30], [0, 1], MK.linear)
	var rot := 0.0
	var drop_y := 0.0
	var steps_rot := [3.5, 8.0, 14.0]
	var steps_y := [14.0, 36.0, 70.0]
	for i in 3:
		if f >= OUT[i]:
			var k := MK.spring(f, OUT[i], 8, 150)
			var prev_r: float = 0.0 if i == 0 else steps_rot[i - 1]
			var prev_y: float = 0.0 if i == 0 else steps_y[i - 1]
			rot = lerpf(prev_r, steps_rot[i], k)
			drop_y = lerpf(prev_y, steps_y[i], k)
	if f >= FALL:
		var t := f - FALL
		drop_y += 2.4 * t * t
		rot += 0.9 * t
	_pivot.position = LOGO_C + sway + Vector2(0, drop_y)
	_pivot.rotation = deg_to_rad(rot)
	_pivot.scale = Vector2.ONE * sc

	# -- logo power
	var on := 1.0 if f >= DROP else 0.0
	if f >= FALL + 2.0:
		on = 1.0 - clampf((f - FALL - 2.0) / 8.0, 0.0, 1.0)
	var surge := MK.interp(f, [SURGE, SURGE + 6.0, SURGE + 18.0], [0.0, 1.0, 0.0], MK.ease_in_out) if f >= SURGE else 0.0
	var beat_kick := 0.0
	for b in PULSE_BEATS:
		if f >= float(b):
			beat_kick = maxf(beat_kick, exp(-(f - float(b)) / 4.0))
	_logo.apply(func(i: int) -> Variant:
		var orig: Color = _logo.data.parts[i].fill
		var pinkish := orig.g < 0.9
		var dead := FTF_DEAD_PINK if pinkish else FTF_DEAD
		return {fill = dead.lerp(orig, on)})
	_fx.glow_strength = on * (0.35 + 0.9 * (1.0 - MK.map(f, [DROP, DROP + 16], [0, 1], MK.ease_out)) + 0.6 * surge + 0.25 * beat_kick) if f >= DROP else 0.0
	_fx.glow = 16.0 + 26.0 * (1.0 - MK.map(f, [DROP, DROP + 16], [0, 1], MK.ease_out)) if f >= DROP else 16.0
	_jp.modulate.a = on * MK.prog(f, DROP + 6, 8)
	_pill.modulate.a = on * MK.prog(f, DROP + 10, 8)
	_pill.scale = Vector2.ONE * (1.0 if f >= DROP + 10 else 0.0)

	_frame_wraps(f)
	_frame_suspension(f, on, surge)


func _frame_wraps(f: float) -> void:
	for k in _wraps.size():
		var c: MotionCable = _wraps[k]
		var at := WRAP + k * 5.0
		var rin := MK.map(f, [at, at + 30.0], [0, 1], MK.ease_out)
		var out_at := PULL + k * 1.0
		var rout := MK.map(f, [out_at, out_at + 6.0], [0, 1], MK.ease_in_quad)
		# ripping off: the cable slides back along itself and out the way it came
		c.reveal = rin * (1.0 - rout)
		c.opacity = 1.0 if c.reveal > 0.0 else 0.0
		var tg := [MotionCable.tug(at + 30.0, 12.0, 9.0, 12.0)]
		for sq in SQUEEZE:
			tg.append(MotionCable.tug(sq, 9.0 + k, 7.0, 10.0))
		tg.append(MotionCable.tug(out_at, 34.0, 6.0, 8.0))
		c.tugs = tg
		c.pulses = _pulses_for(f, [210.0, 230.0], 26.0, Color(c.jacket).lightened(0.35)) if f >= 196.0 and f < PULL else []
		c.glint = fposmod((f - at) / 50.0 + k * 0.17, 1.0)


func _frame_suspension(f: float, on: float, surge: float) -> void:
	var xf := _logo_xf(f)
	for i in _sus.size():
		var c: MotionCable = _sus[i]
		var info: Dictionary = SUS[i]
		var dir: Vector2 = xf.basis_xform(info.dir).normalized()
		var rim: Vector2 = xf * (info.rim as Vector2)
		var L := MotionCable.plug_length(MotionCable.Plug.MULTIPIN, SUS_W)
		var rear := rim + dir * (SUS_W * 0.5) - dir * L
		var anchor: Vector2 = LOGO_C + (info.anchor as Vector2)
		c.points = PackedVector2Array([anchor, rear - dir * 90.0, rear])
		var at := HARPOON + i * 0.5
		var rin := MK.map(f, [at, DROP], [0, 1], MK.ease_in_quad)
		var step := -1
		for s in OUT_ORDER.size():
			if (OUT_ORDER[s] as Array).has(i):
				step = s
		var out_at: float = OUT[step] + ((OUT_ORDER[step] as Array).find(i)) * 2.0
		var rout := MK.map(f, [out_at, out_at + 9.0], [0, 1], MK.ease_in_quad)
		c.reveal = rin * (1.0 - rout)
		c.opacity = 1.0 if c.reveal > 0.0 else 0.0
		# taut when landed; a little slack creeps in as the plate lurches
		c.tension = 1.0 - 0.25 * rout
		var tg := [MotionCable.tug(DROP, 38.0, 8.0, 12.0)]
		for t in TWITCH:
			if (t == 260.0 and i % 2 == 0) or (t == 280.0 and i % 2 == 1) or t == 320.0:
				tg.append(MotionCable.tug(t, 16.0 if t != 320.0 else 30.0, 7.0, 11.0))
		tg.append(MotionCable.tug(SURGE, 10.0, 6.0, 10.0))
		tg.append(MotionCable.tug(out_at, 50.0, 6.0, 9.0))
		c.tugs = tg
		var alive := f >= DROP and f < out_at
		var arrive := []
		for b in PULSE_BEATS:
			arrive.append(b)
		arrive.append(DROP + 20.0)
		c.pulses = _pulses_for(f, arrive, 14.0, Color(c.jacket).lightened(0.4)) if alive else []
		var land := 0.0
		for b in arrive:
			if f >= float(b):
				land = maxf(land, exp(-(f - float(b)) / 5.0))
		c.plug_lit = (0.35 + 0.65 * land) * on if alive else 0.0
		c.glow = (0.25 * on + 0.8 * surge) if alive else 0.0
		c.glint = fposmod((f - DROP) / 30.0 + i * 0.13, 1.0) if alive else -1.0
		# tags riding the cables
		var tag := _tags[i]
		c.build(f)
		var tp := c.point_at(0.42)
		tag.position = tp + Vector2(22, -28)
		tag.modulate.a = MK.prog(f, DROP + 14.0 + i * 2.0, 6) * (1.0 - MK.map(f, [out_at, out_at + 4.0], [0, 1], MK.linear))
		tag.visible = tag.modulate.a > 0.0


func _draw_rim(c: MotionCanvas, f: float) -> void:
	# rim LEDs next to each socket, blinking as pulses land; ports dark until powered
	if f < DROP:
		return
	for i in SUS.size():
		var info: Dictionary = SUS[i]
		var rim: Vector2 = info.rim
		var dir: Vector2 = info.dir
		var side := Vector2(-dir.y, dir.x)
		var cab: MotionCable = _sus[i]
		var lit: float = cab.plug_lit
		var p := rim + dir * 26.0 + side * 34.0
		c.circle(p, 7.0, Color(cab.jacket, 0.3 + 0.7 * lit))
		if lit > 0.4:
			c.circle(p, 16.0, Color(cab.jacket, 0.25 * lit))
