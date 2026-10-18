# SPDX-License-Identifier: Apache-2.0
# Text metrics, the 3D projection helpers and the drawing helpers.
extends RefCounted


func _text(family: String, size: float, txt: String) -> MotionText:
	var t := MotionText.new()
	t.font = SCFBrand.font(family, 400)
	t.font_size = size
	t.text = txt
	return t


func test_text_line_box_matches_chromium() -> String:
	# Line-box heights Chromium gives these faces with line-height: normal:
	# round(ascent) + round(descent) from the hhea/typo tables.
	var cases := [["michroma", 52.0, 74.0], ["michroma", 20.0, 28.0], ["space_mono", 20.0, 29.0], ["jp", 26.0, 37.0], ["jp", 20.0, 29.0]]
	for c in cases:
		var t := _text(c[0], c[1], "AB")
		var h := t.get_text_size().y
		t.free()
		if not is_equal_approx(h, c[2]):
			return "%s %spx: line box %s, want %s" % [c[0], c[1], h, c[2]]
	return ""


func test_text_fallback_face_grows_line_only_when_used() -> String:
	# Michroma falls back to Noto JP for kana. The line box only grows when a
	# kana is actually on the line (Godot's Font.get_ascent() would always include it).
	var latin := _text("michroma", 52.0, "STORY")
	var mixed := _text("michroma", 52.0, "STORY ス")
	var a := latin.get_text_size().y
	var b := mixed.get_text_size().y
	latin.free(); mixed.free()
	if not is_equal_approx(a, 74.0):
		return "latin-only line box %s, want 74" % a
	# Noto JP at 52 px: ascent 60.32 -> 60, descent 14.98 -> 15, so the line is 60 + 15.
	if not is_equal_approx(b, 75.0):
		return "mixed line box %s, want 75" % b
	return ""


func test_letter_spacing_counts_after_every_character() -> String:
	var t := _text("space_mono", 20.0, "ABCD")
	var w0 := t.get_text_size().x
	t.tracking = 0.5
	var w1 := t.get_text_size().x
	t.free()
	return "" if is_equal_approx(w1 - w0, 4 * 10.0) else "tracking added %s, want 40" % (w1 - w0)


func test_projection_helpers() -> String:
	var p := MK.rot_y(Vector3(1, 0, 0), PI / 2)
	if not p.is_equal_approx(Vector3(0, 0, -1)):
		return "rot_y %s" % p
	p = MK.rot_x(Vector3(0, 1, 0), PI / 2)
	if not p.is_equal_approx(Vector3(0, 0, 1)):
		return "rot_x %s" % p
	var s: Variant = MK.project(Vector3(100, -50, 1000), 100.0, 900.0, Vector2(960, 540))
	if s == null or not (s as Vector3).is_equal_approx(Vector3(1060, 490, 900)):
		return "project %s" % [s]
	if MK.project(Vector3(0, 0, 130), 100.0, 900.0, Vector2.ZERO) != null:
		return "a point nearer than `near` should not project"
	return ""


func test_canvas_thin_lines_use_coverage_alpha() -> String:
	var c := MotionCanvas.new()
	var t: Array = c._thin(Color(1, 1, 1, 0.8), 0.5)
	var u: Array = c._thin(Color(1, 1, 1, 0.8), 2.0)
	c.free()
	if not (is_equal_approx(t[1], 1.0) and is_equal_approx((t[0] as Color).a, 0.4)):
		return "0.5 px line drew as %s" % [t]
	if not (is_equal_approx(u[1], 2.0) and is_equal_approx((u[0] as Color).a, 0.8)):
		return "2 px line drew as %s" % [u]
	return ""


func test_gradient_constructors() -> String:
	var g := MotionGradient.stripes(Vector2(400, 100), -45.0, [Color.BLACK, Color.BLACK, Color.WHITE, Color.WHITE], [0, 34, 34, 68])
	var ok := g.kind == MotionGradient.Kind.STRIPES and g.positions.size() == 4 and is_equal_approx(g.positions[3], 68.0)
	var r := MotionGradient.radial(Vector2(100, 100), [Color.WHITE, Color.BLACK], [0.0, 0.65], Vector2(0.25, 0.5))
	ok = ok and r.kind == MotionGradient.Kind.RADIAL and r.center.is_equal_approx(Vector2(0.25, 0.5))
	g.free(); r.free()
	return "" if ok else "constructor fields wrong"


func test_part_blur_grows_the_raster() -> String:
	var d := MotionSvgData.from_string('<svg viewBox="0 0 10 10"><rect x="2" y="2" width="6" height="6" fill="#fff"/></svg>')
	var r_plain: Rect2 = MotionSvg._raster_rect(d.parts[0], Vector2i.ZERO, Vector2.ZERO)
	var r_blur: Rect2 = MotionSvg._raster_rect(d.parts[0], Vector2i.ZERO, Vector2(2, 0))
	# Three sigma of room, horizontally only for a horizontal blur.
	if not (is_equal_approx(r_blur.position.x, r_plain.position.x - 6.0) and is_equal_approx(r_blur.size.y, r_plain.size.y)):
		return "blurred raster %s vs plain %s" % [r_blur, r_plain]
	return ""


func test_text_metrics_round_like_chromium_near_half() -> String:
	# Space Mono's descent at 18 px is 6.498 px: Chromium rounds it to 6, so the
	# line box is 20 + 6. FreeType's rounded-up size metrics would give 7.
	var t := _text("space_mono", 18.0, "AB")
	var h := t.get_text_size().y
	var b := t.get_baseline()
	t.free()
	return "" if is_equal_approx(h, 26.0) and is_equal_approx(b, 20.0) else "line box %s, baseline %s; want 26, 20" % [h, b]


func _vertical(text: String, size: float, track: float, avail: float) -> MotionText:
	var t := MotionText.new()
	t.font = SCFBrand.font("jp", 900)
	t.font_size = size
	t.tracking = track
	t.vertical = true
	t.box_width = avail
	t.text = text
	return t


## Characters per column, right to left.
func _columns(t: MotionText) -> Array:
	var size := t.get_text_size()
	var thick: float = size.x / roundf(size.x / (t._glyphs[0].line_box as float))
	var counts := {}
	for g in t._glyphs:
		var col := int(floorf((size.x - (g.pivot as Vector2).x) / thick))
		counts[col] = counts.get(col, 0) + 1
	var out := []
	for k in counts.size():
		out.append(counts[k])
	return out


func test_vertical_text_wraps_into_columns() -> String:
	# B Print: 96 px, letter-spacing 0.1em, 960 px of column: nine characters,
	# then the last two in a second column to the left (as Chromium lays it out).
	var t := _vertical(SCFBrand.JP.mh, 96.0, 0.1, 960.0)
	var cols := _columns(t)
	var w := t.get_text_size().x
	t.free()
	if cols != [9, 2]:
		return "columns %s, want [9, 2]" % [cols]
	return "" if w > 200.0 and w < 300.0 else "two columns %s px wide" % w


func test_vertical_text_keeps_small_kana_and_dashes_off_column_tops() -> String:
	# Seven characters fit; the eighth, ー, may not start a column, nor may the
	# small ュ before it, so ヒュー moves down together.
	var t := _vertical("ミニマル・ヒュー", 96.0, 0.0, 7 * 96.0)
	var cols := _columns(t)
	t.free()
	return "" if cols == [5, 3] else "columns %s, want [5, 3]" % [cols]


func test_svg_raster_density_per_axis() -> String:
	var d := MotionSvgData.from_string('<svg viewBox="0 0 10 10"><rect x="0" y="0" width="10" height="10" fill="#fff"/></svg>')
	var r: Rect2 = MotionSvg._raster_rect(d.parts[0], Vector2i(0, 4), Vector2.ZERO)
	# bucket 0 = 1 texel per unit across, bucket 4 = 4 texels per unit down.
	# Padding: 2 texels plus half the (default 1 unit) stroke width each side,
	# so 10 + 2 * 2.5 = 15 units across and 10 + 2 * 1 = 12 units (48 texels) down.
	var tex := Vector2(r.size.x * 1.0, r.size.y * 4.0)
	return "" if tex.is_equal_approx(Vector2(15, 48)) else "raster %s texels" % tex


func test_vertical_text_without_a_legal_break_overflows() -> String:
	# Nothing may start a column here, so there is no break opportunity: the
	# column overflows rather than putting a long-vowel mark at a column top.
	var t := _vertical("ミーーーー", 96.0, 0.0, 2 * 96.0)
	var cols := _columns(t)
	t.free()
	return "" if cols == [5] else "columns %s, want [5]" % [cols]


func test_svg_capped_density_rounds_down() -> String:
	# A density past the texture cap takes the √2 step at or below the cap, so
	# the raster fits whole instead of being clamped (which cropped the part).
	var r := [Vector2(1, 1), Vector2(10.0, 50.0), false]
	var b := MotionSvg._part_bucket(Vector2(40.0, 40.0), r)
	var dens := MotionSvg._bucket_xy(b)
	if dens.x > 10.0 + 1e-6 or dens.y > 40.0 * 1.4143:
		return "bucket %s gives density %s past the cap (10, 50)" % [b, dens]
	if dens.x <= 10.0 / 1.4143:
		return "density %s fell more than a step below the cap" % dens
	# Just under the cap, rounding up would cross it: 9 must not become 11.3.
	var under := MotionSvg._bucket_xy(MotionSvg._part_bucket(Vector2(9.0, 9.0), r))
	return "" if under.x <= 10.0 + 1e-6 else "density 9 under cap 10 rounded up to %s" % under.x


func test_cells_resize_and_read() -> String:
	var c := MotionCells.new()
	c.columns = 3
	c.rows = 2
	if c.cells.size() != 6:
		c.free()
		return "cells %d, want 6" % c.cells.size()
	c.cells = PackedByteArray([0, 1, 2, 3, 4, 5])
	c.set_cell(1, 0, 9)
	c.refresh()
	if c.get_cell(1, 0) != 9:
		c.free()
		return "set_cell did not store"
	var got := [c.get_cell(0, 0), c.get_cell(2, 1), c.get_cell(3, 0), c.get_cell(-1, 0)]
	c.free()
	return "" if got == [0, 5, 0, 0] else "get_cell %s, want [0, 5, 0, 0]" % [got]
