# SPDX-License-Identifier: Apache-2.0
# RACE IDENT — an example made directly in Godot with the kit (no Remotion
# original), following skills/godot-motion-kit/SKILL.md.
#
# Brief: a 6 s race-start ident for a futuristic racer. Hazard bands slam in
# from both sides and keep crawling; a 3-2-1 countdown punches in on the beat,
# each number kicking the screen; GO bursts with a glow and speed lines; GRID
# READY settles its tracking under it and a LAP 1/3 pill pops. It holds with
# the bands crawling and GO breathing, then everything snaps out to black so
# the game can cut straight in.
#
# Beats (30 fps, 180 frames):
#   0-12    bands slam in (staggered springs)
#   12/30/48  3, 2, 1 (spring pop + shake on each)
#   66      GO: glow burst, speed lines, shake
#   80-110  GRID READY tracking settles; 96 LAP pill pops
#   120-150 hold: bands crawl, GO breathes
#   150-174 out: springs back the other way, ends on black
#
# Sound: the cue sheet in _init (whooshes, count blips, the GO hit, a tick and
# a pop) drives a MotionCuePlayer; Movie Maker records it into f.wav.
@tool
extends MotionComposition

const INK := Color("#0e0f12")
const AMBER := Color("#ffb627")
const CYAN := Color("#3ad6ff")
const CREAM := Color("#f2ede4")
const FONT_HEAVY := "res://demo/assets/fonts/outfit-latin-900-normal.woff2"
const FONT_MONO := "res://demo/assets/fonts/space-mono-latin-700-normal.woff2"
const COUNT := [12, 30, 48]
const GO_AT := 66
const OUT := 150

var _built := false
var _stage: Node2D
var _bands: Array[MotionGradient] = []
var _count_pivot: Node2D
var _count: MotionText
var _go_fx: MotionFX
var _go_pivot: Node2D
var _lines: MotionCanvas
var _title: MotionText
var _pill: MotionPill


func _init() -> void:
	duration = 180
	fps = 30
	markers = {"in": 0.0, "hold": 120.0, "out": float(OUT)}
	# The cue sheet: every moment sound should land on, from the same constants
	# the animation uses. It fires whether or not anything listens.
	cue(0, &"whoosh.in", 0.8)
	cue(4, &"whoosh.in", 0.6)
	for i in COUNT.size():
		cue(COUNT[i], &"count", 0.7 + 0.15 * i, {n = 3 - i, pitch = [0.9, 1.0, 1.12][i]})
	cue(GO_AT, &"go", 1.0)
	cue(80, &"tick", 0.5)
	cue(96, &"pop", 0.8)
	cue(OUT, &"whoosh.out", 0.9)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _text(parent: Node, path: String, size: float, col: Color, s: String) -> MotionText:
	var t := MotionText.new()
	t.font = MotionFonts.font(path)
	t.font_size = size
	t.color = col
	t.text = s
	parent.add_child(t)
	return t


## A node at `centre` holding `t` centred on it, so scaling pops in place.
func _centred(parent: Node, t: MotionText, centre: Vector2) -> Node2D:
	var p := Node2D.new()
	p.position = centre
	parent.add_child(p)
	t.get_parent().remove_child(t)
	p.add_child(t)
	t.position = -t.get_text_size() * 0.5
	return p


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = INK
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()      # everything that shakes
	add_child(_stage)

	for k in 2:
		var b := MotionGradient.stripes(Vector2(2400, 70), -45.0, [AMBER, AMBER, INK, INK], [0.0, 34.0, 34.0, 68.0])
		b.position = Vector2(-240, 150 if k == 0 else 880)
		_stage.add_child(b)
		_bands.append(b)

	_lines = MotionCanvas.new()
	_stage.add_child(_lines)
	_lines.draw_fn = _draw_lines

	_count = _text(_stage, FONT_HEAVY, 420, CREAM, "3")
	_count_pivot = _centred(_stage, _count, Vector2(960, 520))

	# GO glows: the text renders offscreen and a blurred copy blooms under it.
	_go_fx = MotionFX.new()
	_go_fx.size = size
	_go_fx.glow = 12.0
	_go_fx.glow_strength = 1.0
	_stage.add_child(_go_fx)
	var go := _text(_go_fx.content, FONT_HEAVY, 380, AMBER, "GO")
	_go_pivot = _centred(_go_fx.content, go, Vector2(960, 500))

	_title = _text(_stage, FONT_MONO, 44, CYAN, "GRID READY")
	_title.align = HORIZONTAL_ALIGNMENT_CENTER
	_title.box_width = 1920
	_title.position = Vector2(0, 690)

	_pill = MotionPill.new()
	_pill.font = MotionFonts.font(FONT_MONO)
	_pill.font_size = 28
	_pill.tracking = 0.12
	_pill.padding = Vector2(18, 6)
	_pill.background = CYAN
	_pill.text_color = INK
	_pill.text = "LAP 1/3"
	_pill.position = Vector2(960, 790)
	_stage.add_child(_pill)

	# A stand-in listener: one WAV per cue name. An audio system would
	# subscribe to the same cues (cue_fired, or MotionCue.bus for all pieces).
	var sfx := MotionCuePlayer.new()
	sfx.composition = self
	sfx.sounds = {
		&"whoosh.*": load("res://demo/assets/audio/sfx/whoosh.wav"),
		&"count": load("res://demo/assets/audio/sfx/blip.wav"),
		&"go": load("res://demo/assets/audio/sfx/hit.wav"),
		&"tick": load("res://demo/assets/audio/sfx/tick.wav"),
		&"pop": load("res://demo/assets/audio/sfx/pop.wav"),
	}
	add_child(sfx)


## Speed lines radiating from the centre after GO, longer and fainter as they go.
func _draw_lines(c: MotionCanvas, f: float) -> void:
	var t := f - GO_AT
	if t < 0.0 or f > OUT + 24:
		return
	var fade := 1.0 - MK.map(f, [OUT, OUT + 18], [0, 1])
	for i in 48:
		var a := MK.rand(i * 7.1) * TAU
		var speed := 30.0 + 50.0 * MK.rand(i * 3.3)
		var r0 := 160.0 + fmod(t * speed + MK.rand(i) * 900.0, 900.0)
		var dir := Vector2(cos(a), sin(a))
		c.line(Vector2(960, 520) + dir * r0, Vector2(960, 520) + dir * (r0 + 60 + speed), CREAM, 2.0, 0.35 * fade)


func _frame(f: float) -> void:
	if not _built:
		return
	var out := MK.interp(f, [OUT, OUT + 24], [0, 1], MK.ease_in_back)   # 0 -> 1 on the way out
	_stage.position = MK.shakes(f, COUNT + [GO_AT], 16, 8)

	# Bands: slam in from opposite sides, crawl forever, slam out the way they came.
	for k in 2:
		var s := MK.spring(f, k * 4, 12, 140)
		var side := -1.0 if k == 0 else 1.0
		_bands[k].position.x = -240 + side * (1.0 - s + out) * 2400
		_bands[k].shift = Vector2(f * 3.0 * side, 0)

	# Countdown: the number for the current beat pops from 1.6x and settles.
	var beat := -1
	for i in COUNT.size():
		if f >= COUNT[i]:
			beat = i
	_count_pivot.visible = beat >= 0 and f < GO_AT
	if _count_pivot.visible:
		_count.text = str(3 - beat)
		_count.position = -_count.get_text_size() * 0.5
		var s := MK.spring(f, COUNT[beat], 20, 220)
		_count_pivot.scale = Vector2.ONE * lerpf(1.6, 1.0, s)
		_count_pivot.modulate.a = minf(1.0, s * 3.0)

	# GO: spring in with overshoot, breathe on the hold, shrink away on the out.
	var go := MK.spring(f, GO_AT, 8, 180)
	var breathe := 1.0 + 0.02 * sin((f - GO_AT) / 6.0) if f > 110 else 1.0
	_go_fx.visible = f >= GO_AT and out < 1.0
	_go_pivot.scale = Vector2.ONE * maxf(0.0, go * breathe * (1.0 - out))
	_go_fx.glow = lerpf(40.0, 12.0, MK.map(f, [GO_AT, GO_AT + 20], [0, 1]))

	# GRID READY settles from wide tracking; LAP pill pops.
	var title := MK.prog(f, 80, 30)
	_title.visible = f >= 80 and out < 1.0
	_title.tracking = lerpf(0.9, 0.18, title)
	_title.modulate.a = minf(1.0, title * 2.0) * (1.0 - out)
	var pill := MK.spring(f, 96, 9, 200) * (1.0 - out)
	_pill.visible = pill > 0.0
	_pill.scale = Vector2.ONE * maxf(0.0, pill)
