# SPDX-License-Identifier: Apache-2.0
# Demo menu: a composition with markers (in → hold → out) and real Godot
# buttons. The build-in is frame-pure; the buttons react with springs
# (MotionReactive); choosing an item plays the build-in backwards as the outro,
# then MotionTransition changes scene. Mouse, keyboard and gamepad all work.
extends MotionComposition

const HOLD := 110.0   # the last item's spring (from frame 65) has settled by here
const ITEMS := [
	["E1  SUPERGRAPHIC", "res://demo/scf/e1_supergraphic.tscn", "circle"],
	["D1  SIGNAL", "res://demo/scf/d1_signal.tscn", "glitch"],
	["A  PIT LANE", "res://demo/scf/a_pit_lane.tscn", "bars"],
	["C  VECTOR TRACK", "res://demo/scf/c_vector_track.tscn", "crt"],
	["TRANSITIONS", "", ""],
	["QUIT", "", ""],
]
const STYLES := ["circle", "bars", "clock", "glitch", "crt", "fade"]

static var _style_i := 0

var _discs: Array[MotionShape] = []
var _mono: MotionSvg
var _title: MotionText
var _sub: MotionText
var _slots: Array[Control] = []
var _rule: MotionShape
var _choice := -1


func _init() -> void:
	duration = HOLD + 240
	markers = {"in": 0.0, "hold": HOLD}
	autoplay = false


func _ready() -> void:
	var bg := ColorRect.new(); bg.color = SCFBrand.INK; bg.size = size; bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	for spec in [[SCFBrand.BLUE, 900.0], [SCFBrand.AMBER, 520.0], [SCFBrand.RED, 130.0]]:
		var d := MotionShape.circle(spec[1], spec[0]); add_child(d); _discs.append(d)
	_mono = MotionSvg.new(); _mono.data = SCFBrand.logo("mhM"); _mono.width = 150; _mono.position = Vector2(150, 120); add_child(_mono)
	_title = MotionText.new(); _title.font = SCFBrand.font("outfit", 900); _title.font_size = 150; _title.color = SCFBrand.CREAM
	_title.text = "MOTION KIT"; _title.tracking = -0.01; _title.position = Vector2(330, 112); add_child(_title)
	_sub = MotionText.new(); _sub.font = SCFBrand.font("space_mono", 700); _sub.font_size = 24; _sub.color = SCFBrand.AMBER
	_sub.tracking = 0.12; _sub.text = "GODOT MOTION KIT · DEMO"; _sub.position = Vector2(340, 300); add_child(_sub)
	_rule = MotionShape.new(); _rule.kind = MotionShape.Kind.RECT; _rule.anchor = Vector2.ZERO; _rule.color = SCFBrand.AMBER
	_rule.position = Vector2(150, 372); add_child(_rule)

	var font := SCFBrand.font("outfit", 800)
	for i in ITEMS.size():
		var slot := Control.new(); slot.position = Vector2(150, 420 + i * 100); slot.size = Vector2(900, 90)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var b := Button.new()
		b.text = ITEMS[i][0]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 58)
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, SCFBrand.CREAM)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.size = Vector2(900, 90)
		var r := MotionReactive.new(); r.hover_offset = Vector2(28, 0); r.hover_scale = 1.03; r.focus_scale = 1.03
		r.press_scale = 0.96; r.hover_tint = SCFBrand.AMBER
		b.add_child(r)
		b.pressed.connect(_choose.bind(i))
		slot.add_child(b)
		_slots.append(slot)
	MotionTransition.colour = SCFBrand.BLUE
	super._ready()
	play_segment("in", "hold")
	segment_finished.connect(_on_segment)
	(_slots[0].get_child(0) as Button).grab_focus.call_deferred()


func _frame(f: float) -> void:
	if _slots.is_empty():
		return
	var sp := func(at: float, d := 10.0, k := 140.0) -> float: return MK.spring(f, at, d, k)
	var drift := func(k: float) -> float: return sin(f / 40.0 + k) * 6.0
	SCFBrand.disc(_discs[0], 1920 - 380, 1080 - 380 + drift.call(1.0), 900, SCFBrand.BLUE, sp.call(4, 12, 90))
	SCFBrand.disc(_discs[1], 1920 - 700 + drift.call(2.0), -260, 520, SCFBrand.AMBER, sp.call(10, 12, 90))
	SCFBrand.disc(_discs[2], 1920 - 260, 470 + drift.call(3.0), 130, SCFBrand.RED, sp.call(16, 8, 160))

	var mono: float = sp.call(6, 9, 120)
	var fan: float = 1.0 + (1.0 - sp.call(10, 8, 110)) * 3.0
	_mono.apply(func(i): return {s = mono, tx = (2 - i) * (fan - 1.0) * 5.0, ty = (2 - i) * (fan - 1.0) * 5.0})
	_title.glyph_fn = func(i: int, ff: float) -> Variant:
		var s: float = MK.spring(ff, 14 + i * 2.0, 8, 180)
		return {o = minf(1.0, s * 2.0), ty = (1.0 - s) * 60.0, s = lerpf(0.4, 1.0, minf(1.0, s))}
	_sub.modulate.a = MK.prog(f, 34, 14)
	_sub.tracking = lerpf(0.5, 0.12, MK.prog(f, 34, 22))
	_rule.size = Vector2(MK.map(f, [30, 48], [0, 760], MK.ease_in_out), 6)
	_rule.visible = _rule.size.x > 0.0
	for i in _slots.size():
		var s: float = sp.call(40 + i * 5.0, 9, 150)
		_slots[i].position.x = 150 - (1.0 - s) * 420.0
		_slots[i].modulate.a = clampf(s * 1.5, 0.0, 1.0)


func _choose(i: int) -> void:
	if playing or MotionTransition.busy:
		return
	match ITEMS[i][0]:
		"QUIT":
			get_tree().quit()
		"TRANSITIONS":
			var style: String = STYLES[_style_i % STYLES.size()]
			_style_i += 1
			_sub.text = "TRANSITION · " + style.to_upper()
			await MotionTransition.cover(style)
			await MotionTransition.uncover(style)
		_:
			_choice = i
			play_backwards(0)   # the build-in, mirrored, is the outro


func _on_segment(_name: StringName) -> void:
	pass


func _process(delta: float) -> void:
	super._process(delta)
	if _choice >= 0 and not playing and frame <= 0.0:
		var item: Array = ITEMS[_choice]
		_choice = -1
		IntroPlayer.next_scene = item[1]
		IntroPlayer.style = item[2]
		MotionTransition.change_scene("res://demo/intro_player.tscn", item[2])
