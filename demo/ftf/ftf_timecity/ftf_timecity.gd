# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — round 4: TIME CITY (Megastructure x Slit-Scan).
#
# Brief: the isometric MC-202 megastructure seen through time displacement.
# The whole city (red, cream, black and grey extruded solids on a black
# platform, the Minimal Humans monument, the FTF logo slab) is one nested
# composition rendered through MotionTimeSlices, so different bands of the
# picture show it at different moments.
#   I   Black. The paper and the city rise in a slit-scan wave sweeping right
#       to left across 32 time-displaced columns (the left edge lags 30
#       frames), towards the empty plaza. The wave folds into a travelling time ripple while the
#       monument rises out of the plaza and unfolds through it; the camera
#       cranes down to a near-front view, and on bar 1 the delays collapse:
#       the lockup snaps sharp. It holds for two seconds (PRESENTS stamped on
#       the plinth), alive: the camera sways, the city pulses on the beats and
#       a ripple of time runs down through the picture on each beat.
#   II  The monument sinks and the camera cranes across the roofs, smeared
#       through time (each row of the picture a little older than the one
#       above). Landing on the FTF plaza, the blocks in front drain away; the
#       FTF slab rises out of the floor through a time smear (rows below lag
#       behind, so the rising slab trails its own past), the camera swings to
#       a flat front elevation, and on bar 4 the smear collapses: the logo
#       locks perfectly sharp, big, over the skyline.
#   Hold Bars 4-6: the city pulses outward from the logo on every beat, the
#       camera breathes; accents knock the picture and a red/green/blue time
#       split fringes it (CHANNELS); bar 5 tears time into random row delays;
#       a ripple scans down before the exit.
#   III Bar 6: the columns fold into a slit through the logo's centre: the
#       city stretches into slit-scan streaks while it sinks into the
#       platform; the ground goes dark and the black runs out from the slit to
#       the edges. Black from frame 412.
#
# Tempo: 120 bpm, 4/4, first downbeat at frame 0: a beat is 15 frames, a bar 60.
#
# Beats (30 fps, 420 frames):
#   0       black; 0-10 paper fades up through the column wave
#   4-17    content: city rings rise; the wave carries it right to left (0-30)
#   30-46   the wave folds into a travelling ripple; 34 monument rises
#   44-60   unfold; camera cranes to the near-front read
#   60      SNAP (bar 1): delays collapse to 0, lockup sharp, shake
#   75      PRESENTS stamp + ripple; 90 ripple; 97.5 katakana; 105 ripple
#   120     monument sinks (bar 2); 120-172 crane smeared through rows
#   165     arrive at the FTF plaza; 168 blocks drain in rings
#   180     FTF slab starts rising (bar 3) through a row time smear
#   226-240 the smear collapses; 240 DROP (bar 4): logo sharp, front elevation
#   270/285/315/345  accents: knock + CHANNELS time split
#   300     time tear (bar 5); 330 a ripple scans down
#   360     streaks (bar 6): the columns fold into the slit by 372 (delay 0),
#           then the slit-scan cache spreads the past outward (delay 0->14)
#   376     the logo sinks, then the city in rings: the streaks fall in a V
#   388-400 ground goes dark; black runs out from the slit; 412-420 black
#
# Sound: cues in _init from the same constants; recipes, cue map and a 120 bpm
# tape-warped industrial electro song in audio/ (make.py); tools/bake_audio.gd bakes
# audio/ftf_timecity_track.res, which plays when the audio kit isn't linked.
# Replacement music: 120 bpm, downbeat at 0.0 s.
#
# Time displacement cost: see KIT_NOTES.md. The content culls itself to each
# band's strip (MotionViewRect.of) and all instances share one world.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_timecity/time_look.gd")
const SRC := preload("res://demo/ftf/ftf_timecity/src_city.gd")
const AUDIO := "res://demo/ftf/ftf_timecity/audio/"

const COLS := 32
const ROWS := 24
const STREAKS := 96
const SLIT_W := 3.0
const FOLD := 12.0            # frames the columns take to fold into the slit

var _built := false
var _stage: Node2D
var _plain: MotionComposition
var _cols: MotionTimeSlices
var _rows: MotionTimeSlices
var _split: MotionTimeCache
var _streak: MotionTimeCache
var _hud: MotionCanvas
var _fade: ColorRect
var _mode := &"plain"


func _init() -> void:
	duration = L.END
	bpm = L.BPM
	fps = 30
	markers = {"in": 0.0, "logo": L.FTF_RISE, "hold": L.DROP, "out": L.STREAK}
	cue(0, &"tape.start", 0.7)
	cue(L.RISE, &"wave", 0.9)
	for k in 6:   # the wave crossing the rising blocks, on sixteenths
		cue(7.5 + 3.75 * k, &"block", 0.5 + 0.06 * k, {pitch = [1.0, 1.12, 1.26, 1.5, 1.68, 2.0][k]})
	cue(L.MH_RISE, &"mh.rise", 0.9)          # reversed swell, peaks on the snap
	cue(L.MH_SNAP, &"snap", 1.0)
	for i in L.RIPPLES.size():
		if L.RIPPLES[i] != L.STAMP:      # the stamp carries the first one
			cue(L.RIPPLES[i], &"ripple", 0.6, {pitch = [1.0, 0.89, 1.19][i]})
	cue(L.STAMP, &"stamp", 0.85)
	cue(L.STAMP_JP, &"stamp.small", 0.55)
	cue(L.MH_SINK, &"sink", 0.75)
	cue(L.CRANE, &"crane", 0.9)
	cue(L.ARRIVE, &"arrive", 0.85)
	cue(L.DRAIN, &"drain", 0.7)
	cue(L.FTF_RISE, &"ftf.rise", 1.0)        # long reversed tape swell into the drop
	cue(L.DROP, &"drop", 1.0)
	for i in L.ACCENTS.size():
		cue(L.ACCENTS[i], &"fringe", 0.7, {pitch = [1.0, 1.19, 0.89, 1.33][i]})
	cue(L.TEAR, &"tear", 0.9)
	cue(L.PASS, &"pass", 0.6)
	cue(L.STREAK, &"streak", 1.0)
	cue(L.DARK, &"drain.out", 0.8)
	cue(L.DARK_END + 4.0, &"end", 0.8)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _slices(layout: MotionTimeSlices.Layout, n: int) -> MotionTimeSlices:
	var s := MotionTimeSlices.new()
	s.layout = layout
	s.bands = n
	s.builder = func() -> Node: return SRC.new()
	s.visible = false
	_stage.add_child(s)
	return s


func _cache(layout: MotionTimeCache.Layout, n: int, slots: int) -> MotionTimeCache:
	var s := MotionTimeCache.new()
	s.layout = layout
	s.bands = n
	s.slots = slots
	s.builder = func() -> Node: return SRC.new()
	s.visible = false
	_stage.add_child(s)
	return s


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = L.BLACK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_plain = SRC.new()
	_plain.hide_outside = true
	_stage.add_child(_plain)
	_cols = _slices(MotionTimeSlices.Layout.COLUMNS, COLS)
	_cols.profile = MotionTimeSlices.Profile.CUSTOM
	_cols.delay = 1.0
	_rows = _slices(MotionTimeSlices.Layout.ROWS, ROWS)
	_rows.delay = 1.0
	# accents: a red/cyan time split, two renders of the city (red lags)
	_split = _cache(MotionTimeCache.Layout.CHANNELS, 3, 2)
	_split.channel_shares = [1.0, 0.0, 0.0]
	_split.step = 0.0
	# outro: 96 slit-scan columns, each distinct delay rendered once as a 3 px line
	_streak = _cache(MotionTimeCache.Layout.COLUMNS, STREAKS, 24)
	_streak.profile = MotionTimeSlices.Profile.EDGES
	_streak.slit_width = SLIT_W
	_streak.step = 1.0
	_hud = MotionCanvas.new()
	_hud.draw_fn = _draw_hud
	add_child(_hud)
	_fade = ColorRect.new()
	_fade.color = L.BLACK
	_fade.size = size
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_add_sound()


func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	var map := AUDIO + "timecity_map.tres"
	var song := AUDIO + "music/song.tres"
	var track := AUDIO + "ftf_timecity_track.res"
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


## A gaussian bump of delay travelling across the bands from u = -0.15 to 1.15.
func _bump(f: float, at: float, dur: float, frames: float, width := 0.12) -> Callable:
	var centre := MK.map(f, [at, at + dur], [-0.15, 1.15], MK.linear)
	return func(u: float) -> float: return frames * exp(-pow((u - centre) / width, 2.0))


## Which slicer shows the picture at f, and its settings. Every switch happens
## where the outgoing slicer's delays are all 0, so the cut is invisible.
func _frame(f: float) -> void:
	if not _built:
		return
	_mode = &"plain"
	if f < L.MH_SNAP:
		_mode = &"cols"
		_cols.slit = 0.0
		# the wave (left lags WAVE_D) folds into a travelling ripple, which
		# collapses on the bar: sharp
		var m := MK.map(f, [30.0, 46.0], [0, 1], MK.ease_in_out)
		var amp := 12.0 * (1.0 - MK.map(f, [50.0, L.MH_SNAP], [0, 1], MK.ease_in_quad))
		var wave_d := L.WAVE_D * (1.0 - MK.map(f, [52.0, L.MH_SNAP], [0, 1], MK.ease_in_quad))
		var ph := f * 0.045
		_cols.profile_fn = func(u: float) -> float:
			var rip := amp * (0.5 + 0.5 * sin(TAU * (1.4 * u - ph)))
			return lerpf(wave_d * (1.0 - u), rip, m)
	else:
		for at in L.RIPPLES:
			if _in(f, at, at + 14.0):
				_mode = &"rows"
				_rows.profile = MotionTimeSlices.Profile.CUSTOM
				_rows.step = 0.0
				_rows.profile_fn = _bump(f, at, 14.0, 10.0)
		if _in(f, L.MH_SINK, 172.0):
			_mode = &"rows"
			_rows.profile = MotionTimeSlices.Profile.LINEAR
			_rows.step = 0.0
			_rows.delay = MK.map(f, [L.MH_SINK, 140.0], [0, 14], MK.ease_in_out) * (1.0 - MK.map(f, [158.0, 172.0], [0, 1], MK.ease_in_out))
		elif _in(f, L.FTF_RISE, L.DROP):
			_mode = &"rows"
			_rows.profile = MotionTimeSlices.Profile.LINEAR
			_rows.step = 0.0
			_rows.delay = MK.map(f, [L.FTF_RISE, 198.0], [0, 22], MK.ease_in_out) * (1.0 - MK.map(f, [L.COLLAPSE, L.DROP], [0, 1], MK.ease_in_quad))
		elif _in(f, L.TEAR, L.TEAR + 10.0):
			_mode = &"rows"
			_rows.profile = MotionTimeSlices.Profile.RANDOM
			_rows.seed = floorf(f / 2.0)
			_rows.step = 2.0
			_rows.delay = 10.0 * (1.0 - MK.map(f, [L.TEAR + 6.0, L.TEAR + 10.0], [0, 1], MK.linear))
		elif _in(f, L.PASS, L.PASS + 16.0):
			_mode = &"rows"
			_rows.profile = MotionTimeSlices.Profile.CUSTOM
			_rows.step = 0.0
			_rows.profile_fn = _bump(f, L.PASS, 16.0, 9.0, 0.14)
		for at in L.ACCENTS:
			if _in(f, at, at + 12.0):
				_mode = &"split"
				_split.delay = 6.0 * exp(-(f - float(at)) * 0.22) * (1.0 - MK.map(f, [at + 9.0, at + 12.0], [0, 1], MK.linear))
		if _in(f, L.STREAK, L.STREAK + FOLD):
			# the columns fold into the slit, all at the present (delay 0)
			_mode = &"cols"
			_cols.slit = MK.map(f, [L.STREAK, L.STREAK + FOLD], [0, 1], MK.ease_in_quad)
			_cols.slit_width = SLIT_W
			_cols.slit_pos = 0.5
			_cols.profile_fn = func(_u: float) -> float: return 0.0
		elif f >= L.STREAK + FOLD:
			# handed to the slit-scan cache: the past spreads out from the slit
			_mode = &"streak"
			_streak.delay = MK.map(f, [L.STREAK + FOLD, L.STREAK + FOLD + 14.0], [0, 14], MK.ease_in_out)
			_streak.slit_pos = 0.5
	if _mode == &"rows" and _rows.profile == MotionTimeSlices.Profile.CUSTOM:
		_rows.delay = 1.0
	_cols.visible = _mode == &"cols"
	_rows.visible = _mode == &"rows"
	_split.visible = _mode == &"split"
	_streak.visible = _mode == &"streak"
	_plain.start = 0.0 if _mode == &"plain" else 1e9
	_fade.color.a = MK.map(f, [L.BLACK_AT - 6.0, L.BLACK_AT], [0, 1], MK.linear)
	_fade.visible = _fade.color.a > 0.0


func _draw_hud(c: MotionCanvas, f: float) -> void:
	# the slit: a red hairline while the columns fold into it
	if _in(f, L.STREAK, L.BLACK_AT):
		var a := MK.map(f, [L.STREAK + 4.0, L.STREAK + 12.0], [0, 0.9]) * (1.0 - MK.map(f, [L.DARK_END, L.DARK_END + 10.0], [0, 1]))
		if a > 0.0:
			c.line(Vector2(960, 0), Vector2(960, 1080), L.RED, 2.0, a)
