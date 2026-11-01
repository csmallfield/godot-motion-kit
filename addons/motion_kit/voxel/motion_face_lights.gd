# SPDX-License-Identifier: Apache-2.0
## Night lighting for MotionSolid faces, drawn inside decals (MotionSolid.add_decal):
## rows of lit windows that flicker, neon edge strips with a cheap glow, and a
## light chasing round a face's rim. Everything is a function of the arguments
## (pass the frame in), seeded per face, and drawn with a handful of calls per
## face so a city of a thousand blocks stays cheap.
##
##   b.add_decal(Vector3(0, -1, 0), func(c, size, s, xf):
##       MotionFaceLights.windows(c, size, s.data.sd, now, Color("#dfe8ff")))
##   b.add_decal("front", func(c, size, s, xf):
##       MotionFaceLights.rim(c, size, Color("#19c3e6"), 6.0)
##       MotionFaceLights.chase(c, size, fmod(now / 36.0, 1.0), 0.2, Color.WHITE, 8.0))
##
## Sizes are decal units (MotionExtrude.DECAL_PX = 100 per world unit), y down
## from a wall's top edge. Lower MotionExtrude.min_decal_area (the default 600
## px² skips small faces) when blocks are small on screen.
@tool
class_name MotionFaceLights
extends RefCounted


## Rows of lit windows on a wall: one dashed strip per lit floor (one draw
## call a floor). `lit` is the share of floors lit; `flicker` the chance a floor
## toggles in any `period` frames; `level` dims or kills them all (power).
## `palette` (optional) is a list of colours a floor picks from by its hash;
## `col` is used when empty.
static func windows(c: CanvasItem, size: Vector2, sd: float, f: float, col: Color, level := 1.0,
		lit := 0.5, flicker := 0.05, period := 6.0, floor_px := 24.0, pane := 14.0, margin := 9.0,
		palette: Array = []) -> void:
	if level <= 0.01 or size.y < floor_px:
		return
	var rows := int((size.y - margin) / floor_px)
	var w := size.x - margin * 2.0
	if w <= pane:
		return
	# Whole panes across the face, centred.
	var n := maxi(1, int((w + pane * 0.6) / (pane * 1.6)))
	var span := n * pane * 1.6 - pane * 0.6
	var x0 := (size.x - span) * 0.5
	for r in rows:
		var h := MK.rand(sd * 7.13 + r * 1.37)
		var on := h < lit
		var tick := floorf((f + h * period) / period)
		if MK.rand(sd * 3.1 + r * 5.7 + tick * 0.77) < flicker:
			on = not on
		if not on:
			continue
		var k := col
		if not palette.is_empty():
			k = palette[int(MK.rand(sd + r * 9.1) * palette.size()) % palette.size()]
		var y := margin + r * floor_px + floor_px * 0.3
		var a := Color(k, k.a * level * (0.7 + 0.3 * MK.rand(sd + r * 2.3)))
		c.draw_dashed_line(Vector2(x0, y), Vector2(x0 + span + pane * 0.6, y), a, floor_px * 0.36, pane, false)


## A neon strip from a to b: a wide faint glow under a thin bright core.
static func strip(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, glow := 3.0, glow_alpha := 0.22) -> void:
	if col.a <= 0.01:
		return
	if glow > 0.0:
		c.draw_line(a, b, Color(col, col.a * glow_alpha), w * glow)
	c.draw_line(a, b, col, w)


## A strip round a face's rim (a roof's edge, a wall's frame), inset by half its width.
static func rim(c: CanvasItem, size: Vector2, col: Color, w: float, glow := 3.0, glow_alpha := 0.22) -> void:
	if col.a <= 0.01:
		return
	var r := Rect2(Vector2.ONE * w * 0.5, size - Vector2.ONE * w)
	if glow > 0.0:
		c.draw_rect(r, Color(col, col.a * glow_alpha), false, w * glow)
	c.draw_rect(r, col, false, w)


## A dash of light running round a face's rim: `phase` 0..1 is where its head
## is along the perimeter (clockwise from the top-left), `length` its share of
## the perimeter.
static func chase(c: CanvasItem, size: Vector2, phase: float, length: float, col: Color, w: float, glow := 3.0) -> void:
	var r := Rect2(Vector2.ONE * w * 0.5, size - Vector2.ONE * w)
	chase_path(c, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), phase, length, col, w, glow)


## The same along any closed polyline (first point repeated at the end), for
## example a logo's outline in a cap_transform.
static func chase_path(c: CanvasItem, pts: PackedVector2Array, phase: float, length: float, col: Color, w: float, glow := 3.0) -> void:
	if col.a <= 0.01 or pts.size() < 2:
		return
	var per := 0.0
	for i in pts.size() - 1:
		per += pts[i].distance_to(pts[i + 1])
	var head := fposmod(phase, 1.0) * per
	for seg in _sub(pts, per, head - length * per, head):
		var p: PackedVector2Array = seg
		if p.size() >= 2:
			if glow > 0.0:
				c.draw_polyline(p, Color(col, col.a * 0.25), w * glow)
			c.draw_polyline(p, col, w)


## The part of a closed polyline between arc lengths a and b (wrapping), as one or two pieces.
static func _sub(pts: PackedVector2Array, per: float, a: float, b: float) -> Array:
	if a < 0.0:
		return [_piece(pts, a + per, per), _piece(pts, 0.0, b)]
	return [_piece(pts, a, b)]


static func _piece(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := 0.0
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var l := p.distance_to(q)
		if l <= 0.0:
			continue
		var s1 := s + l
		if s1 >= a and s <= b:
			var t0 := clampf((a - s) / l, 0.0, 1.0)
			var t1 := clampf((b - s) / l, 0.0, 1.0)
			if out.is_empty():
				out.append(p.lerp(q, t0))
			out.append(p.lerp(q, t1))
		s = s1
	return out
