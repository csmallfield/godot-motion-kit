# SPDX-License-Identifier: Apache-2.0
# Content for act II, seen through MotionTimeSlices BOXES at slit = 1: only the
# centre box (about 320 x 180) is ever shown, magnified into every ring of the
# tunnel, each ring older than the one inside it. So each beat's new pattern is
# born in the centre and rushes outward. A slow spin twists the tunnel.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_slitscan/slit_look.gd")
const C := Vector2(960, 540)

var _built := false
var _canvas: MotionCanvas


func _init() -> void:
	duration = 100000
	autoplay = false
	hide_outside = false


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
	super._ready()


func _beat(f: float) -> int:
	if f < L.TUNNEL_FAST:
		return int(floorf((f - L.TUNNEL) / L.BEAT))
	return 4 + int(floorf((f - L.TUNNEL_FAST) / (L.BEAT * 0.5)))


func _paint(c: MotionCanvas, f: float) -> void:
	if f < L.TUNNEL - 30.0:
		return
	var b := _beat(f)
	var white := MK.map(f, [L.TUNNEL_WHITE, L.SCAN], [0, 1], MK.ease_in_quad)
	var spin := (f - L.TUNNEL) * 0.035 + (0.25 if b % 2 == 1 else 0.0)
	c.draw_set_transform(C, spin, Vector2.ONE)
	var pal := [L.MAGENTA, L.CYAN, L.CHROME, L.PINK, L.INK]
	var k := posmod(b, 8)
	var a: Color = pal[k % 4]
	var bcol: Color = pal[(k + 1) % 4]
	var r := Rect2(-260, -260, 520, 520)
	match k:
		0:   # chevrons streaming outward
			c.rect(r, L.INK)
			for i in 6:
				MotionMarks.chevrons(c, Vector2(-240, -150 + i * 60), 10, 40, a, fmod(f / 3.0, 1.0))
		1:   # checker
			c.rect(r, L.INK)
			for y in 10:
				for x in 10:
					if (x + y) % 2 == 0:
						c.rect(Rect2(-260 + x * 52, -260 + y * 52, 52, 52), a)
		2:   # concentric squares
			c.rect(r, a)
			for i in 6:
				var s := 30.0 + i * 40.0
				c.polyline(MotionPoly.rect(Rect2(-s, -s, s * 2, s * 2)), L.INK, 12.0, 1.0, true)
		3:   # split field
			c.rect(Rect2(-260, -260, 260, 520), a)
			c.rect(Rect2(0, -260, 260, 520), bcol)
			c.circle(Vector2.ZERO, 50, L.INK)
		4:   # diagonal stripes
			c.rect(r, L.INK)
			MotionMarks.hatch(c, MotionPoly.rect(r), 46, 20, a, 45.0, f * 3.0)
		5:   # X box on chrome
			c.rect(r, L.CHROME)
			MotionMarks.xbox(c, Vector2.ZERO, 200, L.INK, 16.0)
		6:   # rings
			c.rect(r, L.INK)
			for i in 7:
				c.ring(Vector2.ZERO, 20.0 + i * 34.0, a if i % 2 == 0 else bcol, 10.0)
		7:   # crosshair on magenta
			c.rect(r, a)
			MotionMarks.crosshair(c, Vector2.ZERO, 60, L.INK, 12.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if white > 0.0:
		c.rect(Rect2(C - Vector2(300, 300), Vector2(600, 600)), L.CHROME, white)
