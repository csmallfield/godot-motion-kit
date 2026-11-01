# SPDX-License-Identifier: Apache-2.0
# Warning pictograms for the FTF Warning take: invented FTF hazard icons on
# MotionMarks' ISO 7010-style warning triangle, drawn into a MotionCanvas. All
# static; sizes are the triangle's height. (Hazard clamps and barrier arms
# moved to MotionMarks; the old names below forward to it.)
extends RefCounted

const Look := preload("res://demo/ftf/ftf_warning/warning_look.gd")

enum Icon { ANTIGRAV, VOLTAGE, SPEED, MAGNET }


## Deprecated: use MotionMarks.triangle.
static func _tri(c: Vector2, h: float) -> PackedVector2Array:
	return MotionMarks.triangle(c, h)


## Deprecated: use MotionPath.round_polygon.
static func _round(poly: PackedVector2Array, r: float) -> PackedVector2Array:
	return MotionPath.round_polygon(poly, r)


## A warning triangle: black border, `fill` field, black icon. `s` scales it about its centre.
static func warning_sign(c: MotionCanvas, centre: Vector2, h: float, icon: int, fill: Color, s := 1.0, rot := 0.0, opacity := 1.0) -> void:
	if s <= 0.0:
		return
	h *= s
	c.draw_set_transform(centre, rot, Vector2.ONE)
	MotionMarks.warning_triangle(c, Vector2.ZERO, h, fill, Look.INK, opacity)
	var ic := Vector2(0, h * 0.1)
	var u := h * 0.30
	match icon:
		Icon.ANTIGRAV:
			# a wedge ship hovering over the ground, lift arrows under it
			# a thin wedge craft with a tail fin
			c.polygon(PackedVector2Array([ic + Vector2(-u * 0.95, -u * 0.06), ic + Vector2(u * 0.95, -u * 0.36), ic + Vector2(u * 0.8, -u * 0.18), ic + Vector2(-u * 0.95, u * 0.1)]), Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
			c.polygon(PackedVector2Array([ic + Vector2(-u * 0.95, -u * 0.06), ic + Vector2(-u * 0.75, -u * 0.36), ic + Vector2(-u * 0.55, -u * 0.36), ic + Vector2(-u * 0.6, -u * 0.1)]), Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
			c.rect(Rect2(ic + Vector2(-u * 0.95, u * 0.62), Vector2(u * 1.9, u * 0.14)), Look.INK, opacity)
			for k in 2:
				var x := (-0.4 + 0.8 * k) * u
				var base := ic + Vector2(x, u * 0.5)
				c.polygon(PackedVector2Array([base + Vector2(-u * 0.3, 0), base + Vector2(0, -u * 0.4), base + Vector2(u * 0.3, 0), base + Vector2(u * 0.14, 0), base + Vector2(0, -u * 0.19), base + Vector2(-u * 0.14, 0)]), Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
		Icon.VOLTAGE:
			c.polygon(PackedVector2Array([ic + Vector2(u * 0.18, -u * 0.95), ic + Vector2(-u * 0.42, u * 0.12), ic + Vector2(-u * 0.02, u * 0.12), ic + Vector2(-u * 0.22, u * 0.9), ic + Vector2(u * 0.44, -u * 0.18), ic + Vector2(u * 0.04, -u * 0.18)]), Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
		Icon.SPEED:
			for k in 3:
				var x0 := ic.x + (-0.85 + k * 0.6) * u
				var t := u * 0.2
				c.polygon(PackedVector2Array([Vector2(x0, ic.y - u * 0.55), Vector2(x0 + t, ic.y - u * 0.55), Vector2(x0 + t + u * 0.42, ic.y), Vector2(x0 + t, ic.y + u * 0.55), Vector2(x0, ic.y + u * 0.55), Vector2(x0 + u * 0.42, ic.y)]), Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
		Icon.MAGNET:
			# horseshoe opening downwards, pole tips in the field colour
			var c0 := ic + Vector2(0, -u * 0.12)
			var ro := u * 0.62
			var ri := u * 0.28
			var leg := u * 0.62
			var poly := PackedVector2Array()
			poly.append(c0 + Vector2(-ro, leg))
			for k in 17:
				var a := PI + PI * float(k) / 16.0
				poly.append(c0 + Vector2(cos(a), sin(a)) * ro)
			poly.append(c0 + Vector2(ro, leg))
			poly.append(c0 + Vector2(ri, leg))
			for k in 17:
				var a := TAU - PI * float(k) / 16.0
				poly.append(c0 + Vector2(cos(a), sin(a)) * ri)
			poly.append(c0 + Vector2(-ri, leg))
			c.polygon(poly, Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
			for sx in [-1.0, 1.0]:
				c.rect(Rect2(c0 + Vector2(sx * (ro + ri) * 0.5 - (ro - ri) * 0.5 + 3.0, leg - u * 0.2), Vector2(ro - ri - 6.0, u * 0.17)), fill, opacity)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Deprecated: use MotionMarks.hazard_clamp.
static func hazard_clamp(c: MotionCanvas, corner: Vector2, sx: float, sy: float, arm: float, thick: float, col_a: Color, col_b: Color) -> void:
	MotionMarks.hazard_clamp(c, corner, sx, sy, arm, thick, col_a, col_b)


## Deprecated: use MotionMarks.barrier (with ink = Look.INK).
static func barrier(c: MotionCanvas, pivot: Vector2, angle: float, length: float, thick: float, col_a: Color, col_b: Color) -> void:
	MotionMarks.barrier(c, pivot, angle, length, thick, col_a, col_b, Look.INK)
