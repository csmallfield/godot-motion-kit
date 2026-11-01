# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take 2: SLIT-SCAN.
#
# Brief: 14 s at 180 bpm (10 frames a beat, 40 a bar, first downbeat at frame
# 0), drum & bass energy. Everything is seen through MotionTimeSlices: the
# picture is cut into bands and each band shows its own moment, so motion
# shears and smears, and in slit mode every band shows the same thin slice of
# the picture, stretched: anything crossing the slit becomes streaks of light,
# the 2001 stargate. Nothing springs in letter by letter: logos arrive out of
# their own time-smear and snap sharp on the beat.
# Palette: ink, cyan, magenta, chrome white; the FTF logo keeps its pink.
#   I   A cyan slit opens in the dark. Studio-coloured light streaks pour out
#       of it (the Minimal Humans lockup and its colour bars rising through
#       the slit), then unfold into the lockup, sharp on bar 1. PRESENTS whips
#       in. Two kicks send time ripples through it. It folds back into
#       streaks, which turn cyan and magenta.
#   II  Bar 3: a square tunnel. Only the centre of the picture is ever
#       shown, magnified into every ring, each ring older than the one inside,
#       so each beat's new pattern is born in the middle and rushes past the
#       camera. Bar 4 doubles the pattern rate; it burns out to white.
#   III Bar 5: the FTF logo rises through the slit as streaks while the slit
#       scans across it, then unfolds sharp on bar 6. The hold has a constant
#       red/green/blue time split (only the speed lines fringe); accents kick
#       the logo so it fringes cyan and magenta, and one tears into random
#       time slices. Bar 8.5: it accelerates off to the right and the column
#       delays stretch it into a streak that drains out. Black by frame 392.
#
# Beats (30 fps, 420 frames; beat = 10, bar = 40):
#   0       slit draws; 2-26 the streak field opens from the slit
#   30-40   unfold; 40 snap: MH sharp (flash)
#   46      PRESENTS whips in; 54-62 katakana types
#   60/70   time ripples (kicks)
#   84-104  fold back into streaks; 96 recolour to cyan / magenta
#   120     cut to the tunnel (flash); a pattern per beat
#   160     patterns on eighths; 186-200 burn to white
#   200     logo streaks (slit scans across it); 226-240 unfold
#   240     snap: logo sharp (flash, shake)
#   256/316 a scanner bump sweeps the logo; 270/290/310/320 accents: kicks with
#           time-split fringes; 300 time tear
#   340     exit: the logo accelerates off right, smeared into a streak
#   384     the slit flashes open at the centre and closes (last hit)
#   392-420 black
#
# Sound: cues in _init; recipes, cue map and a 180 bpm d&b song in audio/
# (make.py); tools/bake_audio.gd bakes audio/ftf_slitscan_track.res, which plays when
# the audio kit isn't linked. Replacement music: 180 bpm, downbeat at 0.0 s.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_slitscan/slit_look.gd")
const SRC_MH := preload("res://demo/ftf/ftf_slitscan/src_mh.gd")
const SRC_TUNNEL := preload("res://demo/ftf/ftf_slitscan/src_tunnel.gd")
const SRC_LOGO := preload("res://demo/ftf/ftf_slitscan/src_logo.gd")
const AUDIO := "res://demo/ftf/ftf_slitscan/audio/"

var _built := false
var _stage: Node2D
var _mh: MotionTimeSlices
var _tunnel_pivot: Node2D
var _tunnel: MotionTimeSlices
var _cols: MotionTimeSlices
var _split: MotionTimeSlices
var _hud: MotionCanvas
var _hud_texts: Array[MotionText] = []
var _flash: ColorRect


func _init() -> void:
	duration = L.END
	bpm = L.BPM
	fps = 30
	markers = {"in": 0.0, "logo": L.SCAN, "hold": L.LOGO_SNAP, "out": L.EXIT}
	cue(0, &"slit", 0.6)
	cue(L.MH_SNAP, &"rise", 0.9)              # swells in ahead, peaks on the snap
	cue(L.MH_SNAP, &"snap", 0.8)
	cue(L.PRESENTS_AT, &"whip", 0.7)
	cue(L.PRESENTS_AT + 8.0, &"type", 0.5)
	for i in L.MH_KICKS.size():
		cue(L.MH_KICKS[i], &"ripple", 0.6, {pitch = [1.0, 1.19][i]})
	cue(L.MH_FOLD, &"fold", 0.8)
	cue(L.MH_RECOLOUR, &"glitch", 0.7)
	cue(L.TUNNEL, &"tunnel", 1.0)
	var b := L.TUNNEL + L.BEAT
	var n := 0
	while b < L.TUNNEL_WHITE:
		cue(b, &"ring", 0.45 + 0.03 * n, {pitch = [1.0, 1.12, 1.26, 1.5][n % 4] * (1.0 if b < L.TUNNEL_FAST else 1.33)})
		b += L.BEAT if b < L.TUNNEL_FAST else L.BEAT * 0.5
		n += 1
	cue(L.SCAN, &"riser", 1.0)                # peaks on the scan
	cue(L.SCAN, &"scan", 0.9)
	cue(L.LOGO_SNAP, &"snap.big", 1.0)
	for i in L.ACCENTS.size():
		if L.ACCENTS[i] == L.TEAR:
			continue
		cue(L.ACCENTS[i], &"split", 0.7, {pitch = [1.0, 0.89, 1.12, 1.33][i]})
	cue(L.TEAR, &"tear", 0.9)
	for i in L.PASSES.size():
		cue(L.PASSES[i], &"pass", 0.6, {pitch = [1.0, 1.26][i]})
	cue(L.EXIT, &"stretch", 1.0)
	cue(L.GONE - 8.0, &"tail", 0.8)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _slices(layout: MotionTimeSlices.Layout, n: int, src: GDScript) -> MotionTimeSlices:
	var s := MotionTimeSlices.new()
	s.layout = layout
	s.bands = n
	s.builder = func() -> Node: return src.new()
	return s


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = L.INK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_mh = _slices(MotionTimeSlices.Layout.COLUMNS, 160, SRC_MH)
	_mh.slit_width = 2.5
	_stage.add_child(_mh)
	_tunnel_pivot = Node2D.new()
	_tunnel_pivot.position = size * 0.5
	_stage.add_child(_tunnel_pivot)
	_tunnel = _slices(MotionTimeSlices.Layout.BOXES, 14, SRC_TUNNEL)
	_tunnel.position = -size * 0.5
	_tunnel.slit = 1.0
	_tunnel.slit_width = 330.0
	_tunnel.box_power = 1.6
	_tunnel.profile = MotionTimeSlices.Profile.REVERSE
	_tunnel_pivot.add_child(_tunnel)
	_cols = _slices(MotionTimeSlices.Layout.COLUMNS, 160, SRC_LOGO)
	_cols.slit_width = 3.0
	_stage.add_child(_cols)
	_split = _slices(MotionTimeSlices.Layout.CHANNELS, 3, SRC_LOGO)
	_split.profile = MotionTimeSlices.Profile.LINEAR
	_stage.add_child(_split)
	_hud = MotionCanvas.new()
	_hud.draw_fn = _draw_hud
	add_child(_hud)
	var t1 := FTFKit.text(self, "mono4", 20, L.STEEL, "SLIT-SCAN // 180 BPM", 0.14)
	t1.position = Vector2(120, 1000)
	var t2 := FTFKit.text(self, "jp", 30, L.CYAN, "フルスロットル・フラックス")
	t2.position = Vector2(1824 - t2.get_text_size().x, 66)
	var t3 := FTFKit.text(self, "mono4", 20, L.STEEL, "00:00:00:00", 0.14)
	t3.position = Vector2(1640, 1000)
	_hud_texts = [t1, t2, t3]
	_flash = ColorRect.new()
	_flash.size = size
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_add_sound()


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	var map := AUDIO + "ftf_slitscan_map.tres"
	var song := AUDIO + "music/song.tres"
	var track := AUDIO + "ftf_slitscan_track.res"
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


func _in(f: float, a: float, b: float) -> bool:
	return f >= a and f < b


func _frame(f: float) -> void:
	if not _built:
		return
	_stage.position = MK.shakes(f, [L.TUNNEL, L.LOGO_SNAP], 20, 8)
	_frame_mh(f)
	_frame_tunnel(f)
	_frame_logo(f)
	_frame_hud(f)
	var fl := 0.0
	for at in [L.MH_SNAP, L.TUNNEL, L.SCAN, L.LOGO_SNAP]:
		if _in(f, at, at + 4.0):
			fl = maxf(fl, 0.8 * (1.0 - (f - at) / 4.0))
	_flash.color = L.CHROME
	if _in(f, L.TEAR, L.TEAR + 2.0):
		_flash.color = L.MAGENTA
		fl = 0.16
	_flash.color.a = fl
	_flash.visible = fl > 0.01


func _frame_mh(f: float) -> void:
	_mh.visible = f < L.TUNNEL
	if not _mh.visible:
		return
	_mh.reveal_from = 0.5
	_mh.reveal = MK.map(f, [2, 26], [0.02, 1], MK.ease_out)
	_mh.slit_pos = MK.interp(f, [0, L.MH_FOLD, 104], [0.5, 0.5, 0.42])
	if f < L.MH_SNAP:
		var u := MK.map(f, [L.MH_SNAP - 10.0, L.MH_SNAP], [0, 1], MK.ease_in_quad)
		_mh.profile = MotionTimeSlices.Profile.EDGES   # the slit is now; the past pours out both ways
		_mh.slit = 1.0 - u
		_mh.delay = 36.0 * (1.0 - u)
	elif f < L.MH_FOLD:
		_mh.slit = 0.0
		_mh.profile = MotionTimeSlices.Profile.SINE
		_mh.waves = 1.5
		_mh.phase = -f * 0.06
		var k := 0.0
		for at in L.MH_KICKS:
			if f >= at:
				k += 16.0 * exp(-(f - float(at)) * 0.25)
		_mh.delay = k
	else:
		_mh.profile = MotionTimeSlices.Profile.EDGES
		_mh.delay = MK.map(f, [L.MH_FOLD, 100], [0, 30], MK.ease_in_quad)
		_mh.slit = MK.map(f, [88, 104], [0, 1], MK.ease_in_out)


func _frame_tunnel(f: float) -> void:
	_tunnel_pivot.visible = _in(f, L.TUNNEL, L.SCAN)
	if not _tunnel_pivot.visible:
		return
	_tunnel.delay = 20.0 if f < L.TUNNEL_FAST else 13.0
	var pulse := 0.0
	var step := L.BEAT if f < L.TUNNEL_FAST else L.BEAT * 0.5
	var since := fposmod(f - L.TUNNEL, step) if f < L.TUNNEL_FAST else fposmod(f - L.TUNNEL_FAST, step)
	pulse = exp(-since * 0.5)
	_tunnel_pivot.scale = Vector2.ONE * (1.06 + 0.05 * pulse + MK.map(f, [L.TUNNEL_WHITE, L.SCAN], [0, 0.6], MK.ease_in_quad))
	_tunnel_pivot.rotation = (f - L.TUNNEL) * -0.006


func _frame_logo(f: float) -> void:
	var pass_i := -1
	for i in L.PASSES.size():
		if _in(f, L.PASSES[i], L.PASSES[i] + 14.0):
			pass_i = i
	var cols_on := _in(f, L.SCAN, L.LOGO_SNAP) or _in(f, L.TEAR, L.TEAR + 6.0) or _in(f, L.EXIT, L.GONE) or pass_i >= 0
	_cols.visible = cols_on
	_split.visible = _in(f, L.LOGO_SNAP, L.EXIT) and not cols_on
	if _cols.visible:
		if f < L.LOGO_SNAP:
			var u := MK.map(f, [L.UNFOLD, L.LOGO_SNAP], [0, 1], MK.ease_in_out)
			_cols.profile = MotionTimeSlices.Profile.EDGES
			_cols.step = 0.0
			_cols.slit = 1.0 - u
			_cols.delay = 30.0 * (1.0 - u)
			_cols.slit_pos = MK.interp(f, [L.SCAN, L.SCAN + 13.0, L.UNFOLD], [0.2, 0.8, 0.5], MK.ease_in_out)
			_cols.reveal = MK.map(f, [L.SCAN, L.SCAN + 8.0], [0.1, 1], MK.ease_out)
			_cols.reveal_from = _cols.slit_pos
		elif pass_i >= 0:   # a scanner bump sweeps left to right across the bands
			var at: float = L.PASSES[pass_i]
			var centre := MK.map(f, [at, at + 14.0], [-0.1, 1.1], MK.linear)
			_cols.slit = 0.0
			_cols.reveal = 1.0
			_cols.step = 0.0
			_cols.profile = MotionTimeSlices.Profile.CUSTOM
			_cols.profile_fn = func(u: float) -> float: return exp(-pow((u - centre) / 0.07, 2.0))
			_cols.delay = 20.0
		elif f < L.EXIT:   # the tear
			_cols.slit = 0.0
			_cols.reveal = 1.0
			_cols.profile = MotionTimeSlices.Profile.RANDOM
			_cols.seed_value = floorf(f / 2.0)
			_cols.step = 2.0
			_cols.delay = 10.0
		else:
			_cols.slit = 0.0
			_cols.reveal = 1.0
			_cols.step = 0.0
			_cols.profile = MotionTimeSlices.Profile.REVERSE
			_cols.delay = MK.map(f, [L.EXIT, L.EXIT + 14.0], [0, 26], MK.ease_out)
	if _split.visible:
		var d := 1.0
		for at in L.ACCENTS:
			if f >= at:
				d += 5.0 * exp(-(f - float(at)) * 0.3)
		_split.delay = d


func _frame_hud(f: float) -> void:
	var hold := MK.map(f, [L.LOGO_SNAP + 4.0, L.LOGO_SNAP + 12.0], [0, 1]) * (1.0 - MK.map(f, [L.EXIT, L.EXIT + 6.0], [0, 1]))
	for t in _hud_texts:
		t.modulate.a = hold
		t.visible = hold > 0.0
	_hud_texts[2].text = MK.timecode(f)


func _slit_x(f: float) -> float:
	if f < L.TUNNEL:
		return _mh.slit_pos * size.x
	return _cols.slit_pos * size.x


func _draw_hud(c: MotionCanvas, f: float) -> void:
	# the slit: a hairline while slit mode is on
	var a := 0.0
	if f < L.MH_SNAP:
		a = MK.map(f, [0, 4], [0, 1]) * (1.0 - MK.map(f, [L.MH_SNAP - 6.0, L.MH_SNAP], [0, 1]))
	elif _in(f, 90, L.TUNNEL):
		a = MK.map(f, [90, 100], [0, 0.8])
	elif _in(f, L.SCAN, L.LOGO_SNAP):
		a = 1.0 - MK.map(f, [L.LOGO_SNAP - 8.0, L.LOGO_SNAP], [0, 1])
	if a > 0.0:
		var x := _slit_x(f)
		var h := MK.map(f, [0, 6], [0, 540], MK.ease_out) if f < 10.0 else 540.0
		c.line(Vector2(x, 540 - h), Vector2(x, 540 + h), L.CYAN, 2.0, a)
		for y in [60.0, 1020.0]:
			c.line(Vector2(x - 14, y), Vector2(x + 14, y), L.CYAN, 2.0, a)
	# the end: the slit opens once more at the centre and closes to nothing
	var te := L.GONE - 8.0
	if _in(f, te, te + 14.0):
		var o := MK.map(f, [te, te + 3.0], [0, 540], MK.ease_out) * (1.0 - MK.map(f, [te + 5.0, te + 13.0], [0, 1], MK.ease_in_quad))
		c.line(Vector2(960, 540 - o), Vector2(960, 540 + o), L.CYAN, 3.0)
		c.circle(Vector2(960, 540), 5.0 * (1.0 - MK.map(f, [te + 10.0, te + 14.0], [0, 1])), L.CHROME)
	# hold: corner brackets and a ruler with a playhead
	var hold := MK.map(f, [L.LOGO_SNAP + 2.0, L.LOGO_SNAP + 10.0], [0, 1]) * (1.0 - MK.map(f, [L.EXIT, L.EXIT + 6.0], [0, 1]))
	if hold > 0.0:
		for p in [Vector2(64, 64), Vector2(1856, 64), Vector2(64, 1016), Vector2(1856, 1016)]:
			var sx := 1.0 if p.x < 960 else -1.0
			var sy := 1.0 if p.y < 540 else -1.0
			c.line(p, p + Vector2(40 * sx, 0), L.CHROME, 2.0, hold)
			c.line(p, p + Vector2(0, 40 * sy), L.CHROME, 2.0, hold)
		var x0 := 700.0
		var x1 := 1300.0
		c.line(Vector2(x0, 1010), Vector2(x1, 1010), L.STEEL, 1.0, hold)
		for i in 21:
			var x := lerpf(x0, x1, i / 20.0)
			c.line(Vector2(x, 1010), Vector2(x, 1003 if i % 5 else 996), L.STEEL, 1.0, hold)
		var ph := lerpf(x0, x1, f / float(L.END))
		c.rect(Rect2(ph - 2, 992, 4, 22), L.MAGENTA, hold)
