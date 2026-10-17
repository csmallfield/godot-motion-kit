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
	var r_plain: Rect2 = MotionSvg._raster_rect(d.parts[0], 0, Vector2.ZERO)
	var r_blur: Rect2 = MotionSvg._raster_rect(d.parts[0], 0, Vector2(2, 0))
	# Three sigma of room, horizontally only for a horizontal blur.
	if not (is_equal_approx(r_blur.position.x, r_plain.position.x - 6.0) and is_equal_approx(r_blur.size.y, r_plain.size.y)):
		return "blurred raster %s vs plain %s" % [r_blur, r_plain]
	return ""
