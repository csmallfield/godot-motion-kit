# SPDX-License-Identifier: Apache-2.0
# The SVG parser against the brand files, using the part bounding boxes and
# colours that Chromium reported for the same files in the Remotion project
# (tests/fixtures/logo_bboxes.json).
extends RefCounted

const DIR := "res://demo/assets/logos/"
var ref: Dictionary

func _init() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/logo_bboxes.json"))

func test_every_brand_file_parses() -> String:
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".svg"):
			continue
		var d := MotionSvgData.from_file(DIR + f)
		if d.parts.is_empty():
			return "%s: no parts" % f
		# The CI layout sheet carries live text; it must be reported, not silently dropped.
		var expect_warning := f == "mh_MinimalHumans_CI_layout.svg"
		if expect_warning != (d.warnings.size() > 0):
			return "%s: warnings %s" % [f, d.warnings]
	return ""

func test_part_counts_bboxes_and_fills_match_chromium() -> String:
	var worst := 0.0
	var where := ""
	for f in ref:
		var d := MotionSvgData.from_file(DIR + f)
		var r: Dictionary = ref[f]
		if d.parts.size() != r.bbox.size():
			return "%s: %d parts, Chromium saw %d" % [f, d.parts.size(), r.bbox.size()]
		var vb: Array = r.viewBox
		if not d.view_box.is_equal_approx(Rect2(vb[0], vb[1], vb[2], vb[3])):
			return "%s: viewBox %s" % [f, d.view_box]
		for i in d.parts.size():
			var b: Rect2 = d.parts[i].bbox
			var rb: Array = r.bbox[i]
			var diff := maxf(maxf(absf(b.position.x - rb[0]), absf(b.position.y - rb[1])), maxf(absf(b.size.x - rb[2]), absf(b.size.y - rb[3])))
			if diff > worst:
				worst = diff
				where = "%s part %d: %s vs %s" % [f, i, b, rb]
			var want := Color.html(r.fill[i])
			var got: Color = d.parts[i].fill
			if not Color(got.r, got.g, got.b).is_equal_approx(want):
				return "%s part %d fill %s, want %s" % [f, i, got.to_html(false), r.fill[i]]
	print("        bbox: worst |diff| %s logo units (%s)" % [String.num(worst, 4), where])
	# 0.02 logo units is under a tenth of a pixel at the sizes the intros use.
	return "" if worst < 0.02 else "worst bbox diff %s at %s" % [worst, where]

func test_path_tokens() -> String:
	# Compact numbers and arc flags as exporters write them.
	# M 10,-5.5  (implicit L) .5,.5  L 10,2  a5 5 0 0 1 1,0 (relative)  z
	var subs := MotionSvgParser.path_to_cubics("M10-5.5.5.5L1e1,2a5 5 0 011 0z")
	if subs.size() != 1 or not subs[0].closed:
		return "expected one closed subpath, got %s" % [subs]
	var pts: PackedVector2Array = subs[0].pts
	var want := [Vector2(10, -5.5), Vector2(0.5, 0.5), Vector2(10, 2), Vector2(11, 2), Vector2(10, -5.5)]
	var ends := [pts[0], pts[3], pts[6], pts[9], pts[pts.size() - 1]]
	for i in want.size():
		if not (ends[i] as Vector2).is_equal_approx(want[i]):
			return "point %d is %s, want %s" % [i, ends[i], want[i]]
	return ""

func test_class_rules_override_attributes() -> String:
	var d := MotionSvgData.from_string('<svg viewBox="0 0 10 10"><style>.a{fill:#ff0000}</style><rect class="a" fill="#00ff00" width="5" height="5"/><rect style="fill:#0000ff" class="a" width="5" height="5"/></svg>')
	if not (d.parts[0].fill as Color).is_equal_approx(Color.RED):
		return "class rule should beat the presentation attribute"
	if not (d.parts[1].fill as Color).is_equal_approx(Color.BLUE):
		return "style attribute should beat the class rule"
	return ""

func test_group_transforms() -> String:
	var d := MotionSvgData.from_string('<svg viewBox="0 0 100 100"><g id="g1" transform="translate(10 20) scale(2)"><circle cx="5" cy="5" r="5"/></g></svg>')
	var b: Rect2 = d.parts[0].bbox
	if not b.position.is_equal_approx(Vector2(10, 20)) or absf(b.size.x - 20.0) > 0.01:
		return "bbox %s" % b
	if not (d.parts[0].groups as PackedStringArray).has("g1"):
		return "group id not recorded"
	return ""

func test_outline_length_of_circle() -> String:
	var d := MotionSvgData.from_string('<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40"/></svg>')
	var line: PackedVector2Array = d.outline(0, 0.01)[0]
	var length := 0.0
	for i in line.size() - 1:
		length += line[i].distance_to(line[i + 1])
	var want := TAU * 40.0
	return "" if absf(length - want) < 0.1 else "length %s, want %s" % [length, want]
