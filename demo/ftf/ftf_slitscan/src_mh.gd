# SPDX-License-Identifier: Apache-2.0
# Content for act I, seen through MotionTimeSlices: the Minimal Humans lockup
# rising into place through a field of colour bars, PRESENTS whipping in, kicks
# on the beat for the time ripples, then rising out while it recolours.
# Global timeline (it is a nested composition with start = the band's delay),
# and it must accept negative frames.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_slitscan/slit_look.gd")
const MH_W := 1100.0
const MH_POS := Vector2(410, 330)

var _built := false
var _canvas: MotionCanvas
var _box: Node2D
var _svg: MotionSvg
var _k := 1.0
var _presents: MotionText
var _jp: MotionText


func _init() -> void:
	as_source()


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _build() -> void:
	_built = true
	var bg := ColorRect.new()
	bg.color = L.INK
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	_canvas = MotionCanvas.new()
	_canvas.draw_fn = _paint
	add_child(_canvas)
	_box = Node2D.new()
	add_child(_box)
	_svg = MotionSvg.new()
	_svg.data = SCFBrand.logo("mhFull")
	_svg.width = MH_W
	_box.add_child(_svg)
	_k = MH_W / _svg.data.view_box.size.x
	var px := 145.0 * _k
	var py := 128.9 * _k
	_presents = FTFKit.text(_box, "heavy", 50, FTFKit.MH_CREAM, "PRESENTS", 0.5)
	_presents.position = Vector2(px, py + 52)
	_jp = FTFKit.text(_box, "jp", 30, FTFKit.MH_AMBER, "ミニマル・ヒューマンズ 提供")
	_jp.position = Vector2(px + 1060 - _jp.get_text_size().x, py + 60)


func _acid(f: float) -> bool:
	return f >= L.MH_RECOLOUR


func _rise(f: float) -> float:
	# rises from below into place on the snap, then out of the top on the fold
	return MK.map(f, [-4, L.MH_SNAP], [900, 0], MK.ease_out) + MK.map(f, [L.MH_FOLD, 124], [0, -820], MK.ease_in_quad)


func _frame(f: float) -> void:
	if not _built:
		return
	var y := _rise(f)
	var kick := MK.decay_kick(f, L.MH_KICKS, 60.0, 0.4)
	_box.position = MH_POS + Vector2(kick, y)
	var acid := _acid(f)
	_svg.apply(func(i: int) -> Variant:
		if not acid:
			return {}
		if i <= 2:
			return {fill = [L.MAGENTA, L.CYAN, L.CHROME][i]}
		return {fill = L.CHROME})
	var w := MK.map(f, [L.PRESENTS_AT, L.PRESENTS_AT + 6], [1500, 0], MK.ease_out)
	_presents.position.x = 145.0 * _k + w
	_presents.visible = f >= L.PRESENTS_AT
	_presents.color = L.CHROME if acid else FTFKit.MH_CREAM
	_jp.visible_chars = int(MK.map(f, [L.PRESENTS_AT + 8, L.PRESENTS_AT + 16], [0, 14], MK.linear))
	_jp.color = L.CYAN if acid else FTFKit.MH_AMBER


## Colour bars and discs riding past at different speeds, so the slit sees a
## changing sequence of colours (the streaks), and they clear the frame by the snap.
func _paint(c: MotionCanvas, f: float) -> void:
	var acid := _acid(f)
	var cols := [L.MAGENTA, L.CYAN, L.CHROME, L.PINK] if acid else [FTFKit.MH_AMBER, FTFKit.MH_RED, FTFKit.MH_CREAM, FTFKit.MH_BLUE]
	# build-in bars (0..40) and acid bars (96..124)
	for set_i in 2:
		var t0 := -6.0 if set_i == 0 else 92.0
		var span := 44.0 if set_i == 0 else 34.0
		var t := (f - t0) / span
		if t < 0.0 or t > 1.0:
			continue
		for i in 14:
			var sp := 1.0 + MK.rand(i * 3.1 + set_i * 9.0) * 1.6
			var h := 18.0 + MK.rand(i * 5.7 + set_i) * 90.0
			var yy := lerpf(1200.0 + MK.rand(i * 1.9 + set_i * 3.0) * 900.0, -900.0, t * sp * 0.75)
			var x0 := 520.0 + MK.rand(i * 2.3 + set_i) * 400.0
			var col: Color = cols[i % 4]
			c.rect(Rect2(x0, yy, 880.0 - (x0 - 520.0) * 0.5 + 200.0, h), col)
	# discs riding with the lockup (parallax)
	var y := _rise(f)
	if not (f > 124.0):
		c.circle(Vector2(250, 840 + y * 1.35), 170, cols[0])
		c.rect(Rect2(1480, 170 + y * 0.6, 260, 64), cols[3] if not acid else L.CYAN)
		c.circle(Vector2(1480, 202 + y * 0.6), 32, cols[3] if not acid else L.CYAN)
		c.circle(Vector2(1740, 202 + y * 0.6), 32, cols[3] if not acid else L.CYAN)
		for k in 4:
			c.ring(Vector2(1690, 880 + y * 1.6), 36.0 + k * 30.0, cols[1], 11.0)
	# PRESENTS rule
	var rw := MK.map(f, [L.PRESENTS_AT - 2, L.PRESENTS_AT + 8], [0, 1060], MK.ease_out)
	if rw > 0.0:
		var p := MH_POS + Vector2(145.0 * _k, 128.9 * _k + 30.0 + y) + Vector2(MK.decay_kick(f, L.MH_KICKS, 60.0, 0.4), 0)
		c.rect(Rect2(p, Vector2(rw, 6)), L.MAGENTA if acid else FTFKit.MH_AMBER)
