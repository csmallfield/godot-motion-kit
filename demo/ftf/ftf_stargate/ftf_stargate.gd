# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take: STARGATE BOARD (Checkerboard City x Slit-Scan).
#
# Brief: racing over the checkerboard at absurd speed while time displacement
# turns the world into a stargate. The board is a MotionPlaneScan (new): the
# checker plane, its banded sun and its lanes evaluated per pixel at their own
# moment from a history of the board's state, so a slit at the centre or the
# horizon unrolls the board into 2001-style streak walls, flat or in
# perspective (left and right, or a four-wall tunnel), the delay profile
# sweeping and snapping on the beats. The logos come out of the speed through
# MotionTimeSlices columns, as time-stretched arches, and snap sharp on the
# bar; the held FTF logo fringes red/green/blue on the accents through
# MotionTimeSplit (new), over the racing board. Nothing springs in letter by
# letter. Ends on black.
# Palette: ink; MH sunrise cream, amber and red; the stargate cycles paper,
# pink, cyan and lime; the hold races dusky violet checks with neon lanes under
# a pink and lime sun; the FTF logo keeps its own colours.
#
# Tempo: 180 bpm = 10 frames a beat, 40 a bar, first downbeat at frame 0.
# The drop is bar 6 (frame 240, 8.0 s). Any 180 bpm music starting on its
# downbeat at 0.0 s lines up.
#
# Beats (30 fps, 420 frames; beat = 10, bar = 40):
#   0-8      fade up: already racing flat out over the cream board at sunrise
#   8        the centre slit draws; the board's columns start to lag (chevrons)
#   12-30    Minimal Humans pours out of the slit: time-stretched arches
#   30-40    the arches unfold; 40 bar 1: MH snaps sharp, the board snaps straight
#   46       PRESENTS whips in; 54-62 katakana
#   60/70/80/85  kicks: time ripples through the lockup (column wave) and the board (row ripple)
#   100-120  the lockup sinks back into the slit; the board unrolls into perspective walls
#   120      bar 3: STARGATE. Walls left and right of the centre slit; the delay
#            profile sweeps through each beat and snaps on the next; stutters on 150/190
#   160      bar 4: TUNNEL. Four walls about a point below the horizon
#   200      bar 5: back to two walls; the FTF logo pours out of the slit as streaks
#   222-240  everything unfolds from the slit
#   240      bar 6: DROP. Logo sharp and big, shockwave through the board, towers sprout
#   240-340  hold: the board races, towers stream past, lanes recolour per bar
#            (240/280/320), the sun pulses on every beat, time-split fringes on
#            the accents 260/280/290/300/320/330 (logo and board)
#   328-344  towers sink
#   340      bar 8.5: the board stretches into streaks from a horizon slit, the
#            logo is drawn up into it; the streaks drain to black from the slit out
#   396-420  black
#
# Sound: cues in _init; recipes, cue map and a 180 bpm drum & bass song in audio/
# (make.py); tools/bake_audio.gd bakes audio/stargate_track.res, which plays when the
# audio kit isn't linked.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_stargate/stargate_look.gd")
const SRC_MH := preload("res://demo/ftf/ftf_stargate/src_mh.gd")
const SRC_LOGO := preload("res://demo/ftf/ftf_stargate/src_logo.gd")
const AUDIO := "res://demo/ftf/ftf_stargate/audio/"

const W := 1920.0
const H := 1080.0
const CELL := 4.0
const CAM_H := 1.6
const LOT := 14.0
const BCELL := 2.0
const STUTTERS := [150.0, 190.0]
const LANE_BARS := [240.0, 280.0, 320.0]
const GATE_DELAYS := [64.0, 40.0, 76.0, 48.0, 64.0, 34.0, 80.0, 52.0]

var _built := false
var _tr: MotionTravel

var _board: MotionPlaneScan
var _glow: MotionCanvas
var _towers: MotionCanvas
var _stage: Node2D
var _mh: MotionTimeSlices
var _pour: MotionTimeSlices
var _split: MotionTimeSplit
var _hud: MotionCanvas
var _hud_l: MotionText
var _hud_r: MotionText
var _hud_d: MotionText
var _hud_jp: MotionText
var _flash: ColorRect


func _init() -> void:
	duration = L.END
	bpm = L.BPM
	fps = 30
	markers = {"in": 0.0, "logo": L.POUR, "hold": L.DROP, "out": L.STRETCH}
	_table()
	cue(0, &"open", 0.8)
	cue(L.SLIT_OPEN, &"slit", 0.6)
	cue(L.MH_SNAP, &"smear", 0.9)            # swells in ahead, peaks on the snap
	cue(L.MH_SNAP, &"snap", 0.9)
	cue(L.PRESENTS_AT, &"presents", 0.6)
	for i in L.MH_KICKS.size():
		cue(L.MH_KICKS[i], &"ripple", 0.55 + 0.05 * i, {pitch = [1.0, 0.89, 1.19, 1.33][i]})
	cue(L.MH_FOLD, &"unroll", 0.8)
	cue(L.GATE, &"gate", 1.0)
	cue(L.GATE, &"scanner", 0.75, {pitch = 1.0})    # sweeps through every beat with the delay profile
	cue(L.TUNNEL, &"scanner", 0.8, {pitch = 1.5})
	cue(L.TUNNEL, &"tunnel", 0.9)
	var n := 0
	for b in range(int(L.GATE + L.BEAT), int(L.POUR), int(L.BEAT)):
		var bf := float(b)
		if bf == L.TUNNEL:
			continue
		if bf == L.FLOOR:
			cue(bf, &"flip", 0.8)
			continue
		if bf in STUTTERS:
			cue(bf, &"stutter", 0.7)
		else:
			cue(bf, &"blip", 0.5, {pitch = [1.0, 1.19, 1.5, 1.33, 1.78, 1.5][n % 6]})
			n += 1
	cue(L.POUR, &"pour", 1.0)
	cue(L.DROP, &"drop", 1.0)
	for i in L.ACCENTS.size():
		cue(L.ACCENTS[i], &"fringe", 0.65 + 0.05 * (i % 2), {pitch = [1.0, 1.19, 0.89, 1.33, 1.0, 1.5][i]})
	for i in range(1, LANE_BARS.size()):
		cue(LANE_BARS[i] + 5.0, &"lane", 0.5, {pitch = [1.0, 1.0, 1.26][i]})
	cue(L.STRETCH, &"stretch", 1.0)
	cue(372.0, &"drain", 0.7)


# ------------------------------------------------------------------ timing

const SPEED_FRAMES := [0, 40, 100, 120, 200, 240, 340, 400]
## World units per frame: flat out from the first frame (absurd: two camera heights a frame).
const SPEED := [3.0, 2.5, 2.5, 3.2, 3.2, 3.4, 3.4, 5.5]


func _speed_at(f: float) -> float:
	return _tr.speed(f)


func _table() -> void:
	# Integrate the speed once (on eighths of a frame): travel(f) is a lookup.
	# Past the end it runs on at the final speed (the stretch keeps flying).
	_tr = MotionTravel.from_keys(SPEED_FRAMES, SPEED, L.END + 2, MK.ease_in_out)
	_tr.extrapolate = true
	_tr.end = L.END


func travel(f: float) -> float:
	return _tr.at(f)


func _lateral(f: float) -> float:
	return 3.2 * sin(TAU * f / (L.BAR * 2.0))


func _in(f: float, a: float, b: float) -> bool:
	return f >= a and f < b


func _cycle(i: int) -> Color:
	return [L.PAPER, L.PINK, L.CYAN, L.LIME][posmod(i, 4)]


func _lane_cycle(i: int) -> Color:
	return [L.PINK, L.LIME, L.CYAN][posmod(i, 3)]


# ------------------------------------------------------------------ the board's state over time

## Everything about the board that changes with time, at frame t (any t, also
## negative): what the scan shader reads from its history.
func _state(t: float) -> Dictionary:
	var sp := _speed_at(t)
	var lat_v := 3.2 * TAU / (L.BAR * 2.0) * cos(TAU * t / (L.BAR * 2.0))
	var pulse := MK.beat_pulse(t, L.BEAT, L.MH_SNAP, L.MH_FOLD, 0.3) * 0.8 + MK.beat_pulse(t, L.BEAT, L.GATE, L.POUR, 0.3) + 0.6 * MK.beat_pulse(t, L.BEAT, L.DROP, L.STRETCH, 0.3)
	var a := FTFKit.MH_CREAM
	var b := Color("#0c0b10")
	var acc := Color(FTFKit.MH_AMBER, 0.9)
	if t >= L.MH_FOLD and t < L.DROP:
		var k := int(floorf((t - L.MH_FOLD) / (L.BEAT * 2.0)))   # every two beats (1.5 per second)
		a = _cycle(k)
		b = L.INK
		acc = Color(_cycle(k + 2), 1.0)
	elif t >= L.DROP:
		var bar_i := int(floorf((t - L.DROP) / L.BAR))
		a = L.DUSK
		b = L.INK
		acc = Color(_lane_cycle(bar_i), 1.0)
	var lvl := 1.0 - MK.map(t, [360.0, L.DARK - 4.0], [0, 1], MK.ease_in_quad)
	lvl *= MK.map(t, [0, 8], [0, 1])
	var sun := 1.0 + 0.07 * pulse
	return {
		offset = Vector2(_lateral(t), travel(t)),
		cell = Vector2(CELL, CELL) * (1.0 + 0.22 * pulse),
		blur = Vector2(absf(lat_v) / CELL, sp / CELL) * 0.5,
		color_a = a, color_b = b, accent = acc, sun = sun, level = lvl,
	}


# ------------------------------------------------------------------ build

func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = L.INK
	bg.size = size
	add_child(bg)
	_board = MotionPlaneScan.new()
	_board.history = 100
	_board.history_fn = _state
	_board.cell_scroll = Vector2(CELL, CELL)
	_board.pattern_shift = Vector2(0.5, 0.0)
	_board.accent_width = 0.5
	add_child(_board)
	_towers = MotionCanvas.new()
	_towers.draw_fn = _draw_towers
	add_child(_towers)
	_glow = MotionCanvas.new()
	_glow.draw_fn = _draw_glow
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_stage = Node2D.new()
	add_child(_stage)
	_mh = MotionTimeSlices.new()
	_mh.layout = MotionTimeSlices.Layout.COLUMNS
	_mh.bands = 160
	_mh.slit_width = 2.5
	_mh.builder = func() -> Node: return SRC_MH.new()
	_stage.add_child(_mh)
	_pour = MotionTimeSlices.new()
	_pour.layout = MotionTimeSlices.Layout.COLUMNS
	_pour.bands = 160
	_pour.slit_width = 3.0
	_pour.builder = func() -> Node: return SRC_LOGO.new()
	_stage.add_child(_pour)
	_split = MotionTimeSplit.new()
	_split.region = Rect2(120, 150, 1680, 620)
	_split.builder = func() -> Node: return SRC_LOGO.new()
	_stage.add_child(_split)
	_hud = MotionCanvas.new()
	_hud.draw_fn = _draw_hud
	add_child(_hud)
	_hud_l = FTFKit.text(self, "mono", 20, L.PAPER, "F-9000 // STARGATE BOARD", 0.14)
	_hud_l.position = Vector2(72, 54)
	_hud_r = FTFKit.text(self, "mono", 20, L.PAPER, "180 BPM // 10 F", 0.14)
	_hud_r.position = Vector2(W - 72 - _hud_r.get_text_size().x, 54)
	_hud_d = FTFKit.text(self, "mono", 20, L.CYAN, "DELAY 000 F", 0.14)
	_hud_d.position = Vector2(72, H - 78)
	_hud_jp = FTFKit.text(self, "jp", 28, L.PAPER, "フルスロットル・フラックス")
	_hud_jp.position = Vector2(W - 72 - _hud_jp.get_text_size().x, H - 86)
	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = Color(L.PAPER, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_add_sound()


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	var map := AUDIO + "stargate_map.tres"
	var song := AUDIO + "music/song.tres"
	var track := AUDIO + "stargate_track.res"
	if ResourceLoader.exists(BRIDGE) and ResourceLoader.exists(map):
		var bridge: Node = (load(BRIDGE) as GDScript).new()
		bridge.set("cue_map", load(map))
		if ResourceLoader.exists(song):
			bridge.set("song", load(song))
		if ResourceLoader.exists(track):
			bridge.set("track", load(track))
		bridge.set("track_path", track)
		add_child(bridge)
	elif ResourceLoader.exists(track):
		var p := AudioStreamPlayer.new()
		p.stream = load(track)
		add_child(p)
		audio = p
		clock = Clock.AUDIO


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	_frame_board(f)
	_frame_mh(f)
	_frame_logo(f)
	_stage.position = MK.shakes(f, [L.MH_SNAP], 8, 8) + MK.shakes(f, [L.DROP], 22, 12)
	_frame_hud(f)
	var fl := 0.0
	if _in(f, L.DROP, L.DROP + 5.0):
		fl = 0.3 * (1.0 - (f - L.DROP) / 5.0)
	_flash.color.a = fl
	_flash.visible = fl > 0.0


## The horizon's screen height for a camera pitch (degrees) and fov.
func _horizon_y(pitch: float, fov_deg: float) -> float:
	return H * 0.5 + H * 0.5 / tan(deg_to_rad(fov_deg) * 0.5) * tan(deg_to_rad(pitch))


func _frame_board(f: float) -> void:
	var p := _board
	var st := _state(f)
	# ---- camera (shared by every moment the scan shows)
	var jolt := MK.shakes(f, [L.MH_SNAP, L.GATE], 10, 8) + MK.shakes(f, [L.DROP], 24, 12)
	p.height = CAM_H
	p.fov = 74.0 + 6.0 * exp(-maxf(f - L.DROP, 0.0) * 0.25) * float(f >= L.DROP)
	var pitch := MK.interp(f, [0, 30, L.MH_FOLD, L.GATE - 6.0], [11.0, 9.0, 9.0, 0.0], MK.ease_in_out)
	if f >= L.FLOOR:
		pitch = -7.0 if f < L.POUR else 0.0
	if f >= L.UNFOLD:
		pitch = MK.map(f, [L.UNFOLD, L.DROP], [0.0, 2.5], MK.ease_in_out) + MK.map(f, [L.STRETCH, 360.0], [0.0, -1.0], MK.ease_in_out)
	var sway := sin(TAU * (f - L.DROP) / (L.BAR * 2.0)) * MK.map(f, [L.DROP, L.DROP + 20], [0, 1]) * (1.0 - MK.map(f, [L.STRETCH, L.STRETCH + 12], [0, 1]))
	p.pitch = pitch + jolt.y * 0.04
	p.yaw = 2.5 * sway + jolt.x * 0.03
	p.roll = 4.0 * sway + 3.0 * sin(TAU * f / (L.BAR * 2.0)) * MK.map(f, [L.GATE, L.GATE + 10], [0, 1]) * (1.0 - MK.map(f, [L.POUR, L.UNFOLD], [0, 1]))
	p.curve = 0.0010 * sway
	p.ground_offset = st.offset
	p.cell = st.cell
	p.motion_blur = st.blur
	p.color_a = st.color_a
	p.color_b = st.color_b
	p.accent_color = st.accent
	p.accent_every = 4.0 if _in(f, L.MH_FOLD, L.DROP) else (8.0 if f < L.DROP else 4.0)
	p.accent_width = 0.5 if f < L.DROP else 0.35
	# ---- sky, sun, fog per section
	var hold := MK.map(f, [L.POUR, L.DROP], [0, 1], MK.ease_in_out)
	var gate := MK.map(f, [L.MH_FOLD, L.GATE], [0, 1]) * (1.0 - hold)
	var hz := Color("#f08a3a").lerp(Color("#3a1a6a"), gate).lerp(Color("#ff4f9a"), hold)
	p.sky_top = Color("#120814").lerp(Color("#05050c"), gate).lerp(Color("#140a2c"), hold)
	p.sky_horizon = hz
	p.sky_spread = 0.4
	p.fog_color = hz
	p.fog_range = Vector2(26.0, 190.0)
	p.sun_elevation = lerpf(MK.map(f, [0, L.MH_SNAP], [-5.0, -0.5], MK.ease_out), 2.0, maxf(gate, hold))
	p.sun_size = lerpf(10.0, 12.0, maxf(gate, hold))
	p.sun_top = Color("#ffe9a6").lerp(L.CYAN, gate).lerp(Color("#ffe14a"), hold)
	p.sun_bottom = FTFKit.MH_RED.lerp(L.PINK, maxf(gate, hold))
	p.sun_bands = Vector3(9.0, f * 0.02, 0.3)
	p.sun_glow = 0.14 + 0.16 * MK.beat_pulse(f, L.BEAT, L.DROP, L.STRETCH, 0.25)
	# ---- shockwave from the logo's foot on the drop
	var ring := Vector4(0, 0, -1, 2)
	var rcol := Color(1, 1, 1, 0)
	var push := 0.0
	for at: float in [L.DROP, 280.0, 320.0]:
		if f >= at and f < at + 30.0:
			var t := (f - at) / 30.0
			ring = Vector4(0.0, 16.0, lerpf(1.0, 140.0, MK.ease_out.call(t)), lerpf(2.0, 9.0, t))
			rcol = Color(L.LIME.lerp(L.PAPER, 0.4), (0.8 if at == L.DROP else 0.45) * (1.0 - t))
			push = (1.0 if at == L.DROP else 0.5) * (1.0 - t)
	p.ring = ring
	p.ring_color = rcol
	p.ring_push = push
	p.level = 1.0 - MK.map(f, [L.DARK - 6.0, L.DARK], [0, 1], MK.ease_in_quad)
	_frame_scan(f)
	p.capture(f)
	p.sync_now()


## The scan: where the slit is, how much the board reads it, and how far back.
func _frame_scan(f: float) -> void:
	var p := _board
	var hy := _horizon_y(p.pitch, p.fov)
	p.split = 0.0
	p.delay_step = 0.0
	p.ripple = Vector3.ZERO
	p.delay_curve = 1.0
	p.wall_near = 22.0
	p.gap = 1.0
	if f < L.MH_FOLD:
		# I: columns lag behind the centre (chevrons) until the snap; then ripples through rows
		p.axis = MotionPlaneScan.Axis.VERTICAL
		p.slit_at = Vector2(960, hy)
		p.scan = 0.0
		p.walls = 0.0
		if f < L.MH_SNAP:
			p.delay = MK.map(f, [L.SLIT_OPEN, 30.0], [0.0, 22.0], MK.ease_in_out) * (1.0 - MK.map(f, [36.0, L.MH_SNAP], [0, 1], MK.ease_in_quad))
			p.delay_curve = 1.4
		else:
			p.axis = MotionPlaneScan.Axis.HORIZONTAL
			var k := MK.decay_kick(f, L.MH_KICKS, 1.0, 0.22, false)
			p.delay = 9.0 * minf(k, 1.6)
			p.delay_span = Vector2(960, 420)
			p.delay_curve = 1.0
			p.ripple = Vector3(0.6, 2.5, f * 0.12)
	elif f < L.POUR:
		# the unroll, then the stargate: perspective walls about the slit crossing
		var un := MK.map(f, [L.MH_FOLD, L.GATE], [0, 1], MK.ease_in_out)
		var low := f >= L.FLOOR
		p.axis = MotionPlaneScan.Axis.VERTICAL
		if low:
			p.axis = MotionPlaneScan.Axis.TUNNEL if f >= L.TUNNEL else MotionPlaneScan.Axis.HORIZONTAL
		var drift := 70.0 * sin(TAU * (f - L.GATE) / (L.BAR * 2.0)) * float(f >= L.GATE)
		p.slit_at = Vector2(960.0 + drift, 540.0 if low else hy)
		p.scan = un
		p.walls = un
		p.wall_ref = Vector2(960, 540)
		if f < L.GATE:
			p.delay = 64.0 * un
		else:
			var bi := int(floorf((f - L.GATE) / L.BEAT))
			var ph := fmod(f - L.GATE, L.BEAT) / L.BEAT
			# each beat snaps to a new depth and the profile sweeps through the beat
			p.delay = GATE_DELAYS[bi % GATE_DELAYS.size()] * (1.0 + 0.12 * ph)
			p.delay_curve = lerpf(0.6, 1.7, MK.ease_in_out.call(ph))
			p.ripple = Vector3(0.05, 3.0, f * 0.05)
			if float(L.GATE + bi * L.BEAT) in STUTTERS:
				p.delay_step = 8.0
	else:
		p.axis = MotionPlaneScan.Axis.VERTICAL
		p.slit_at = Vector2(960, hy)
		p.wall_ref = Vector2(960, 540)
		if f < L.DROP:
			var u := 1.0 - MK.map(f, [L.UNFOLD, L.DROP], [0, 1], MK.ease_in_out)
			p.scan = u
			p.walls = u
			p.delay = 60.0 * u
		elif f < L.STRETCH:
			p.scan = 0.0
			p.walls = 0.0
			p.delay = 0.0
			# a fraction of a frame: at this speed that is a fraction of a check
			p.split = 0.22 * MK.accent(f, L.ACCENTS, 0.28)
			if p.split < 0.02:
				p.split = 0.0
		else:
			# the outro: the centre slit stretches the board into flat streaks
			p.walls = 0.0
			p.scan = MK.map(f, [L.STRETCH, L.STRETCH + 20.0], [0, 1], MK.ease_in_out)
			p.delay_span = Vector2(960, 540)
			p.delay = MK.map(f, [L.STRETCH, 380.0], [0.0, 70.0], MK.ease_in_quad)
			p.delay_curve = 0.8


func _frame_mh(f: float) -> void:
	var m := _mh
	m.visible = _in(f, L.POUR_MH - 2.0, L.GATE + 2.0)
	if not m.visible:
		return
	m.slit_pos = 0.5
	m.reveal_from = 0.5
	m.reveal = MK.map(f, [L.POUR_MH, 30.0], [0.02, 1], MK.ease_out)
	if f < L.MH_SNAP:
		var u := MK.map(f, [30.0, L.MH_SNAP], [0, 1], MK.ease_in_quad)
		m.profile = MotionTimeSlices.Profile.EDGES   # the slit is now; the past pours out both ways
		m.slit = 1.0 - u
		m.delay = 34.0 * (1.0 - u)
	elif f < L.MH_FOLD:
		m.slit = 0.0
		m.profile = MotionTimeSlices.Profile.SINE
		m.waves = 1.2
		m.phase = -f * 0.05
		m.delay = 12.0 * minf(MK.decay_kick(f, L.MH_KICKS, 1.0, 0.25, false), 1.6)
	else:
		m.profile = MotionTimeSlices.Profile.EDGES
		m.delay = MK.map(f, [L.MH_FOLD, 112.0], [0, 30], MK.ease_in_quad)
		m.slit = MK.map(f, [L.MH_FOLD + 4.0, L.GATE], [0, 1], MK.ease_in_out)


func _frame_logo(f: float) -> void:
	var pour_on := _in(f, L.POUR, L.DROP) or _in(f, L.STRETCH, L.DARK)
	_pour.visible = pour_on
	_split.visible = _in(f, L.DROP, L.STRETCH)
	if pour_on:
		_pour.slit_pos = 0.5
		_pour.reveal_from = 0.5
		_pour.profile = MotionTimeSlices.Profile.EDGES
		if f < L.DROP:
			var u := MK.map(f, [L.UNFOLD, L.DROP], [0, 1], MK.ease_in_out)
			_pour.slit = 1.0 - u
			_pour.delay = 30.0 * (1.0 - u)
			_pour.reveal = MK.map(f, [L.POUR, L.POUR + 10.0], [0.05, 1], MK.ease_out)
		else:
			# drawn up into the slit, then drained with the board
			_pour.slit = MK.map(f, [L.STRETCH, 366.0], [0, 1], MK.ease_in_out)
			_pour.delay = MK.map(f, [L.STRETCH, 366.0], [0, 36], MK.ease_in_quad)
			_pour.reveal = 1.0 - MK.map(f, [362.0, 388.0], [0, 1], MK.ease_in_quad)
			_pour.modulate.a = 1.0 - MK.map(f, [372.0, 392.0], [0, 1])
	if _split.visible:
		_split.delay = 3.2 * MK.accent(f, L.ACCENTS, 0.3)
		if _split.delay < 0.08:
			_split.delay = 0.0


func _frame_hud(f: float) -> void:
	var on := MK.map(f, [L.MH_SNAP + 4.0, L.MH_SNAP + 14.0], [0, 0.8]) * (1.0 - MK.map(f, [L.STRETCH, L.STRETCH + 10.0], [0, 1]))
	for t in [_hud_l, _hud_r, _hud_d, _hud_jp]:
		(t as CanvasItem).modulate.a = on
		(t as CanvasItem).visible = on > 0.0
	_hud_d.text = "DELAY %03d F" % int(roundf(_board.delay_at(Vector2(0, 0)) if _board.scan > 0.0 or _board.delay > 0.0 else 0.0))
	_hud_jp.visible_chars = int(MK.map(f, [L.DROP + 6, L.DROP + 22], [0, 14], MK.linear)) if f >= L.DROP else (14 if f >= L.MH_SNAP + 10.0 else 0)


# ------------------------------------------------------------------ overlays

func _slit_alpha(f: float) -> float:
	var a := 0.0
	if _in(f, L.SLIT_OPEN, L.MH_SNAP):
		a = MK.map(f, [L.SLIT_OPEN, L.SLIT_OPEN + 4.0], [0, 1]) * (1.0 - MK.map(f, [34.0, L.MH_SNAP], [0, 1]))
	elif _in(f, L.MH_FOLD, L.DROP):
		a = MK.map(f, [L.MH_FOLD, L.MH_FOLD + 8.0], [0, 0.9]) * (1.0 - MK.map(f, [L.UNFOLD + 6.0, L.DROP], [0, 1]))
	elif _in(f, L.STRETCH, L.DARK):
		a = MK.map(f, [L.STRETCH, L.STRETCH + 8.0], [0, 0.8]) * (1.0 - MK.map(f, [370.0, 390.0], [0, 1]))
	return a


func _draw_hud(c: MotionCanvas, f: float) -> void:
	var a := _slit_alpha(f)
	var p := _board
	if a > 0.0:
		var x := p.slit_at.x
		var h := MK.map(f, [L.SLIT_OPEN, L.SLIT_OPEN + 6.0], [0, 540], MK.ease_out) if f < 20.0 else 540.0
		if f >= L.FLOOR and f < L.POUR:
			# floor and tunnel: a small square at the crossing instead of the hairline
			var r := Rect2(p.slit_at - Vector2(26, 15), Vector2(52, 30))
			c.rect(r, L.CYAN, a, 2.0)
		else:
			c.line(Vector2(x, 540 - h), Vector2(x, 540 + h), L.CYAN, 2.0, a * 0.8)
			for y in [64.0, 1016.0]:
				c.line(Vector2(x - 14, y), Vector2(x + 14, y), L.CYAN, 2.0, a)
	# corner brackets through the holds
	var hold := MK.map(f, [L.DROP + 2.0, L.DROP + 10.0], [0, 1]) * (1.0 - MK.map(f, [L.STRETCH, L.STRETCH + 6.0], [0, 1]))
	if hold > 0.0:
		for q in [Vector2(48, 96), Vector2(1872, 96), Vector2(48, 984), Vector2(1872, 984)]:
			var sx := 1.0 if q.x < 960 else -1.0
			var sy := 1.0 if q.y < 540 else -1.0
			c.line(q, q + Vector2(36 * sx, 0), L.PAPER, 2.0, hold)
			c.line(q, q + Vector2(0, 36 * sy), L.PAPER, 2.0, hold)


## A soft light where the walls meet (additive), breathing on the beat.
func _draw_glow(c: MotionCanvas, f: float) -> void:
	var on := MK.map(f, [L.MH_FOLD + 6.0, L.GATE], [0, 1]) * (1.0 - MK.map(f, [L.UNFOLD, L.DROP], [0, 1]))
	if on <= 0.0:
		return
	var pulse := MK.beat_pulse(f, L.BEAT, L.GATE, L.POUR, 0.35)
	var col := L.CYAN.lerp(L.PAPER, 0.4)
	var ctr := _board.slit_at
	# a radial fan with vertex colours: smooth, no rings
	var r := 380.0 * (1.0 + 0.2 * pulse)
	var a0 := on * 0.34 * (1.0 + 0.6 * pulse)
	var n := 48
	for ring_i in 3:
		var r0: float = r * float([0.0, 0.12, 0.4][ring_i])
		var r1: float = r * float([0.12, 0.4, 1.0][ring_i])
		var c0 := Color(col, a0 * float([1.0, 0.45, 0.14][ring_i]))
		var c1 := Color(col, a0 * float([0.45, 0.14, 0.0][ring_i]))
		for i in n:
			var t0 := TAU * i / n
			var t1 := TAU * (i + 1) / n
			var d0 := Vector2(cos(t0), sin(t0))
			var d1 := Vector2(cos(t1), sin(t1))
			c.draw_polygon(PackedVector2Array([ctr + d0 * r0, ctr + d0 * r1, ctr + d1 * r1, ctr + d1 * r0]),
				PackedColorArray([c0, c1, c1, c0]))


# ------------------------------------------------------------------ towers (the hold)

func _lot(k: int, side: int) -> Dictionary:
	var key := k * 2 + (1 if side > 0 else 0)
	var r0 := MK.rand(key * 1.37 + 21.0)
	if r0 < 0.18:
		return {}
	var w := 4.0 + 2.0 * floorf(MK.rand(key * 2.71 + 3.0) * 3.0)
	var d := 4.0 + 2.0 * floorf(MK.rand(key * 3.93 + 7.0) * 3.0)
	var h := 8.0 + 2.0 * floorf(MK.rand(key * 5.17 + 1.0) * 10.0)
	var x := side * (12.0 + floorf(MK.rand(key * 7.7) * 6.0) * 2.0)
	return {w = w, d = d, h = h, x = x, z = k * LOT, accent = MK.rand(key * 9.1 + 5.0) < 0.3, idx = key, seed = r0}


func _tower_h(f: float, lot: Dictionary) -> float:
	var st: float = float(lot.seed) * 8.0
	var a := MK.map(f, [L.DROP + st * 0.5, L.DROP + 12.0 + st], [0, 1], MK.ease_out)
	a *= 1.0 - MK.map(f, [328.0 + st * 0.5, 342.0 + st * 0.5], [0, 1], MK.ease_in_quad)
	return a


func _draw_towers(c: MotionCanvas, f: float) -> void:
	if not _in(f, L.DROP, 352.0):
		return
	var p := _board
	var tr := travel(f)
	var k0 := int(floorf((tr + 0.5) / LOT))
	var k1 := int(floorf((tr + 200.0) / LOT))
	var items := []
	for k in range(k0, k1 + 1):
		for side in [-1, 1]:
			var lot := _lot(k, side)
			if lot.is_empty():
				continue
			var zn: float = float(lot.z) - float(lot.d) * 0.5 - tr
			if zn + float(lot.d) < 0.8:
				continue
			items.append([zn, lot])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var bar_i := maxi(0, int(floorf((f - L.DROP) / L.BAR)))
	for it in items:
		var lot: Dictionary = it[1]
		var hh: float = float(lot.h) * _tower_h(f, lot)
		if hh < 0.3:
			continue
		var w: float = lot.w
		var d: float = lot.d
		var x0: float = float(lot.x) - w * 0.5
		var x1: float = x0 + w
		var zn: float = float(lot.z) - d * 0.5 - tr
		var zf: float = zn + d
		if zf < 3.0:
			continue
		var side := 1 if float(lot.x) > 0.0 else -1
		var a := Color("#d9d4f0")
		if lot.accent:
			a = _lane_cycle(int(lot.idx) + bar_i)
		# the side face starts 3 units out: every corner stays well in front of the camera (yaw / pitch / roll)
		p.draw_checker_box(c, x0 - _lateral(f), x1 - _lateral(f), zn, zf, hh, BCELL, a, L.INK, side,
			Color(0.6, 0.6, 0.68), 3.0, true)
