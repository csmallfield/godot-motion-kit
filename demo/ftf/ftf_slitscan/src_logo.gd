# SPDX-License-Identifier: Apache-2.0
# Content for act III, seen through MotionTimeSlices: the FTF logo rising
# through the slit (streaks), holding with small kicks on the accents (the
# time-split fringes show only on motion), then accelerating off to the right
# (the column delays stretch it into a streak). Speed lines stream behind.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_slitscan/slit_look.gd")
const LOGO_W := 1300.0
const C := Vector2(960, 520)

var _built := false
var _canvas: MotionCanvas
var _pivot: Node2D
var _logo: MotionSvg


func _init() -> void:
	as_source()


func _ready() -> void:
	if not _built:
		_built = true
		var bg := ColorRect.new()
		bg.color = L.INK
		bg.size = Vector2(1920, 1080)
		add_child(bg)
		_canvas = MotionCanvas.new()
		_canvas.draw_fn = _paint
		add_child(_canvas)
		_pivot = Node2D.new()
		add_child(_pivot)
		_logo = MotionSvg.new()
		_logo.data = load(FTFKit.LOGO)
		_logo.width = LOGO_W
		_logo.position = -_logo.data.view_box.size * (LOGO_W / _logo.data.view_box.size.x) * 0.5
		_pivot.add_child(_logo)
	super._ready()


static func logo_offset(f: float) -> Vector2:
	var y := MK.map(f, [L.SCAN - 4.0, L.UNFOLD + 8.0], [760, 0], MK.ease_out)
	var x := MK.decay_kick(f, L.ACCENTS, 46.0, 0.5)
	if f > L.LOGO_SNAP:   # a slow bob, so the scanner passes and time split have motion to bend
		y += 12.0 * sin((f - L.LOGO_SNAP) * TAU / L.BAR) * MK.map(f, [L.LOGO_SNAP, L.LOGO_SNAP + 10.0], [0, 1])
	if f > L.EXIT:
		var t := (f - L.EXIT) / 26.0
		x += 2700.0 * t * t
	return Vector2(x, y)


func _frame(f: float) -> void:
	if not _built:
		return
	_pivot.position = C + logo_offset(f)
	_pivot.visible = _pivot.position.x < 2700.0


## Speed lines: horizontal dashes streaming left, faster as the logo leaves.
func _paint(c: MotionCanvas, f: float) -> void:
	var boost := 1.0 + maxf(0.0, f - L.EXIT) * 0.25
	var fade := 1.0 - MK.map(f, [L.EXIT + 16.0, L.GONE - 12.0], [0, 1])
	if fade <= 0.0:
		return
	for i in 46:
		var y := 40.0 + MK.rand(i * 4.7) * 1000.0
		var sp := (26.0 + MK.rand(i * 2.1) * 60.0) * boost
		var len := 80.0 + MK.rand(i * 3.3) * 360.0
		var x := fposmod(MK.rand(i * 1.3) * 2600.0 - f * sp, 2600.0) - 340.0
		var col := L.CYAN if i % 3 else L.MAGENTA
		c.rect(Rect2(x, y, len * minf(boost, 3.0), 2.0 + floorf(MK.rand(i * 9.1) * 3.0)), col, 0.55 * fade)
