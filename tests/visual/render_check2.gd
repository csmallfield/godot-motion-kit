# SPDX-License-Identifier: Apache-2.0
# More GPU checks (see render_check.gd), for the pieces the F and G ports added:
#   godot --path . --rendering-driver opengl3 res://tests/visual/render_check2.tscn
# Prints ok/FAIL per check and quits with the failure count.
extends Node2D

var _frames := 0
var _fails := 0


func _ready() -> void:
	var bg := ColorRect.new(); bg.color = Color.BLACK; bg.size = Vector2(1920, 1080); add_child(bg)
	# 1. MotionCells: a 1.5 px inset half-covers the edge pixel (an SVG rect at x = 1.5).
	var cells := MotionCells.new(); cells.columns = 4; cells.rows = 2; cells.cell_size = Vector2(24, 24); cells.inset = 1.5
	cells.palette = PackedColorArray([Color.TRANSPARENT, Color.WHITE])
	cells.cells = PackedByteArray([1, 1, 0, 1, 1, 1, 1, 1]); add_child(cells)
	# 2. Grid lines compound where they cross, as two overlapping rects would.
	var grid := MotionCells.new(); grid.columns = 3; grid.rows = 3; grid.position = Vector2(200, 0)
	grid.grid_color = Color(1, 1, 1, 0.25); add_child(grid)
	# 2b. Cells with no inset off the pixel grid meet without a seam; a value past
	# the palette draws nothing.
	var solid := MotionCells.new(); solid.columns = 2; solid.rows = 1; solid.inset = 0.0; solid.position = Vector2(300.5, 0)
	solid.palette = PackedColorArray([Color.TRANSPARENT, Color.WHITE]); solid.cells = PackedByteArray([1, 1]); add_child(solid)
	var beyond := MotionCells.new(); beyond.columns = 1; beyond.rows = 1; beyond.position = Vector2(300, 100)
	beyond.palette = PackedColorArray([Color.TRANSPARENT, Color.WHITE]); beyond.cells = PackedByteArray([5]); add_child(beyond)
	# 2c. Outline-only text: a transparent fill with a stroke still draws the stroke.
	var ot := MotionText.new(); ot.font = SCFBrand.font("outfit", 900); ot.font_size = 120; ot.text = "I"
	ot.color = Color(1, 1, 1, 0); ot.stroke_width = 6.0; ot.stroke_color = Color.WHITE; ot.position = Vector2(1300, 0); add_child(ot)
	ot.set_meta("probe", true)
	# 3. alpha_matrix + flood_color: alpha 0.5 * 2 - 0.5 = 0.5, filled red.
	var fl := MotionFX.new(); fl.size = Vector2(100, 50); fl.position = Vector2(400, 0); fl.alpha_matrix = Vector2(2, -0.5)
	fl.flood_color = Color.RED; add_child(fl)
	var half := ColorRect.new(); half.color = Color(1, 1, 1, 0.5); half.size = Vector2(100, 50); fl.content.add_child(half)
	# 4. source_atop goo: a red and a blue bar 4 px apart, blurred and thresholded.
	# The gap bridges; inside each bar the colour is the bar's own, unblurred.
	var goo := MotionFX.new(); goo.size = Vector2(200, 100); goo.position = Vector2(600, 0); goo.blur = 4.0
	goo.alpha_matrix = Vector2(22, -9.9); goo.source_atop = true; add_child(goo)
	var rb := ColorRect.new(); rb.color = Color.RED; rb.position = Vector2(20, 20); rb.size = Vector2(80, 60); goo.content.add_child(rb)
	var bb := ColorRect.new(); bb.color = Color.BLUE; bb.position = Vector2(104, 20); bb.size = Vector2(80, 60); goo.content.add_child(bb)
	# 5. RINGS: strokes 4 px wide at radii 10, 30, 50, 70, 90.
	var rings := MotionGradient.rings(Vector2(200, 200), Vector2(100, 100), Color.WHITE, 4, 20, 5, 10); rings.position = Vector2(900, 0); add_child(rings)


func _check(name: String, got: float, want: float, tol := 0.03) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("  %s  %s: %.3f (want %.3f)" % ["ok  " if ok else "FAIL", name, got, want])


func _process(_d: float) -> void:
	_frames += 1
	if _frames != 4:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_check("cell edge pixel half covered", img.get_pixel(1, 10).r, 0.5, 0.02)
	_check("cell inside", img.get_pixel(10, 10).r, 1.0, 0.01)
	_check("cell gap", img.get_pixel(0, 10).r, 0.0, 0.01)
	_check("empty cell stays clear", img.get_pixel(60, 10).r, 0.0, 0.01)
	_check("grid line alpha", img.get_pixel(224, 10).r, 0.25, 0.01)
	_check("grid lines compound at a crossing", img.get_pixel(224, 24).r, 1.0 - 0.75 * 0.75, 0.01)
	_check("between grid lines", img.get_pixel(212, 10).r, 0.0, 0.01)
	_check("cells with no inset meet without a seam", img.get_pixel(324, 10).r, 1.0, 0.01)
	_check("a value past the palette draws nothing", img.get_pixel(310, 110).r, 0.0, 0.01)
	var lit := 0
	for x in range(1300, 1420):
		for y in range(0, 150, 3):
			if img.get_pixel(x, y).r > 0.5:
				lit += 1
	_check("outline-only text draws its stroke (lit pixels > 0)", 1.0 if lit > 20 else 0.0, 1.0, 0.0)
	_check("flood red", img.get_pixel(450, 25).r, 0.5, 0.01)
	_check("flood replaces the colour", img.get_pixel(450, 25).g, 0.0, 0.01)
	var inner := img.get_pixel(600 + 98, 50)
	_check("atop: red bar keeps its colour at its edge (r)", inner.r, 1.0, 0.01)
	_check("atop: red bar keeps its colour at its edge (b)", inner.b, 0.0, 0.01)
	var gap := img.get_pixel(600 + 102, 50)
	_check("atop: the gap bridges", gap.r + gap.b, 1.0, 0.1)
	_check("ring at r = 30", img.get_pixel(900 + 130, 100).r, 1.0, 0.02)
	_check("between rings", img.get_pixel(900 + 140, 100).r, 0.0, 0.02)
	print("%d failed" % _fails)
	get_tree().quit(_fails)
