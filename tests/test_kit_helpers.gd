# SPDX-License-Identifier: Apache-2.0
# Shared helpers promoted from the FTF pieces: beats (MK, MotionComposition),
# MotionSvgData.load_any / contours, MotionFonts fallbacks and ladder,
# MotionText.make, MotionTrack3D and the time effects' shared profile.
extends RefCounted

const LOGO := "res://demo/ftf/assets/ftf_logo.svg"


func test_beat_pulse() -> String:
	if MK.beat_frames(150.0) != 12.0 or MK.beat_frames(112.5) != 16.0 or MK.beat_frames(120.0, 60.0) != 30.0:
		return "beat_frames"
	if MK.beat_pulse(5.0, 12.0, 10.0, 50.0) != 0.0 or MK.beat_pulse(50.0, 12.0, 10.0, 50.0) != 0.0:
		return "outside"
	if MK.beat_pulse(22.0, 12.0, 10.0, 50.0) != 1.0:
		return "on the beat"
	if MK.beat_pulse(25.0, 12.0, 10.0, 50.0, 0.18) != exp(-3.0 * 0.18):
		return "rate"
	if MK.beat_pulse(25.0, 18.0, 10.0, 50.0, 0.0, 3.5) != exp(-fmod(15.0, 18.0) / 3.5):
		return "tau"
	return ""


func test_kicks_accent_flicker() -> String:
	var ats := [10.0, 20.0]
	if MK.decay_kick(5.0, ats, 40.0) != 0.0:
		return "kick before"
	var want := 40.0 * exp(-12.0 * 0.45) - 40.0 * exp(-2.0 * 0.45)
	if MK.decay_kick(22.0, ats, 40.0) != want:
		return "kick alternating"
	if MK.decay_kick(22.0, ats, 40.0, 0.45, false) != 40.0 * exp(-12.0 * 0.45) + 40.0 * exp(-2.0 * 0.45):
		return "kick same sign"
	if MK.accent(25.0, ats) != exp(-5.0 * 0.3) or MK.accent(5.0, ats) != 0.0:
		return "accent"
	if MK.flicker(3.0, 5.0, 7.0) != 0.0 or MK.flicker(14.0, 5.0, 7.0) != 1.0:
		return "flicker ends"
	for t in 8:
		var v := MK.flicker(5.0 + t, 5.0, 7.0)
		if v != 1.0 and v != 0.15:
			return "flicker levels"
	return ""


func test_composition_tempo() -> String:
	var c := MotionComposition.new()
	if c.beat_frames() != 0.0:
		return "no bpm"
	c.bpm = 150.0
	if c.beat_frames() != 12.0 or c.bar_frames() != 48.0 or c.beat_at(30.0) != 2.5 or c.beat_at(30.0, 6.0) != 2.0:
		return "beats %s %s %s" % [c.beat_frames(), c.bar_frames(), c.beat_at(30.0)]
	c.as_source()
	var ok := c.duration == 100000 and not c.autoplay and not c.hide_outside
	c.free()
	return "" if ok else "as_source"


func test_svg_load_any_and_contours() -> String:
	var d := MotionSvgData.load_any(LOGO)
	if d == null or d.part_count() < 40:
		return "load_any"
	var raw := d.outline(1, 0.25)
	var placed := d.contours(1, 2.0, Vector2(10, 20))
	if placed.size() != raw.size() or placed[0][3] != Vector2(10, 20) + raw[0][3] * 2.0:
		return "contours placement"
	var many := d.contours([1, 2], 1.0, Vector2.ZERO)
	if many.size() != raw.size() + d.outline(2, 0.25).size():
		return "contours list"
	for c in d.contours([1, 2], 1.0, Vector2.ZERO, 0.25, true):
		if c.size() <= 2 or c[0].distance_to(c[c.size() - 1]) < 0.01:
			return "clean"
	return ""


func test_font_fallbacks_are_not_shared() -> String:
	var path := "res://demo/assets/fonts/space-mono-latin-700-normal.woff2"
	var jp := MotionFonts.font("res://demo/ftf/assets/noto-jp-ftf-900.woff2")
	var sym := MotionFonts.font("res://demo/assets/fonts/dejavu-sans-mono-bold-symbols.ttf")
	var plain := MotionFonts.font(path)
	var a := MotionFonts.font(path, false, [jp])
	var b := MotionFonts.font(path, false, [jp, sym])
	if a == plain or a == b or not plain.fallbacks.is_empty():
		return "one font per fallback list"
	if a.fallbacks != [jp] or b.fallbacks != [jp, sym]:
		return "fallbacks %s %s" % [a.fallbacks, b.fallbacks]
	if MotionFonts.font(path, false, [jp]) != a:
		return "cached"
	return ""


func test_ladder_and_text_make() -> String:
	if MotionFonts.ladder_size(10.0, 1.08) != pow(1.08, roundf(log(10.0) / log(1.08))):
		return "ladder"
	if MotionFonts.ladder_size(10.0, 1.08, true) > 10.0:
		return "ladder floor"
	var parent := Node2D.new()
	var t := MotionText.make(parent, MotionFonts.font(LOGO.get_base_dir() + "/noto-jp-ftf-900.woff2"), 40, Color.RED, "提供", 0.1, Vector2(3, 4))
	var ok := t.get_parent() == parent and t.font_size == 40.0 and t.color == Color.RED and t.text == "提供" \
		and t.tracking == 0.1 and t.position == Vector2(3, 4)
	parent.free()
	return "" if ok else "make"


func test_track_3d() -> String:
	var pts: Array[Vector3] = []
	var tilts: Array[float] = []
	for i in 6:
		pts.append(Vector3(0, 0, -20.0 * i))
		tilts.append(0.2 if i == 3 else 0.0)
	var c := MotionTrack3D.circuit(pts, tilts)
	if c.point_count != 6 or not is_equal_approx(c.get_point_tilt(3), 0.2) or c.get_point_in(0) != Vector3.ZERO or c.get_point_out(5) != Vector3.ZERO:
		return "circuit"
	if not c.get_point_out(2).is_equal_approx(Vector3(0, 0, -40.0 * 0.17)):
		return "handles"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MotionTrack3D.strip(st, c, 0.0, 10.0, -1.0, 0.0, 1.0, 0.0, Color.WHITE, 2.0)
	var arr := st.commit_to_arrays()
	if (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != 5 * 6:
		return "strip quads"
	if (arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)[0].x != 2.0:
		return "strip uv2 carries s"
	var lf := MotionTrack3D.level_frame(c, 60.0)
	if absf(lf.basis.x.y) > 1e-5:
		return "level frame banks"
	var lane := MotionTrack3D.trail_lane(c, 20.0, 2.0, 0.7, Color.RED)
	if lane.get_surface_count() != 1:
		return "trail lane"
	return ""


func test_time_profile_shared() -> String:
	var s := MotionTimeSlices.new()
	var tc := MotionTimeCache.new()
	var err := ""
	for p in MotionTimeSlices.Profile.values():
		if p == MotionTimeSlices.Profile.CUSTOM:
			continue
		s.profile = p
		tc.profile = p
		for u in [0.0, 0.3, 1.0]:
			var v := MotionTimeSlices.profile_value(p, u, 3, s.waves, s.phase, s.seed_value)
			if s.profile_at(u, 3) != v or tc.profile_at(u, 3) != v:
				err = "profile %d at %s" % [p, u]
	if MotionTimeSlices.profile_value(MotionTimeSlices.Profile.CENTRE, 0.5, 0) != 1.0:
		err = "centre"
	if MotionTimeSlices.profile_value(MotionTimeSlices.Profile.CUSTOM, 0.25, 0, 1.0, 0.0, 1.0, func(u: float) -> float: return u * 2.0) != 0.5:
		err = "custom"
	s.free()
	tc.free()
	return err
