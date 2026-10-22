# SPDX-License-Identifier: Apache-2.0
# Warning pictograms for the FTF Warning take (ISO 7010-style triangles with
# invented FTF hazards), drawn into a MotionCanvas, plus hazard clamps and
# barrier arms. All static; sizes are the triangle's height.
extends RefCounted

const Look := preload("res://demo/ftf/ftf_warning/warning_look.gd")

enum Icon { ANTIGRAV, VOLTAGE, SPEED, MAGNET }


static func _tri(c: Vector2, h: float) -> PackedVector2Array:
	var w := h * 1.1547   # equilateral
	return PackedVector2Array([c + Vector2(0, -h * 0.62), c + Vector2(w * 0.5, h * 0.38), c + Vector2(-w * 0.5, h * 0.38)])


static func _round(poly: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[(i - 1 + n) % n]
		var b := poly[i]
		var cc := poly[(i + 1) % n]
		var p1 := b + (a - b).normalized() * r
		var p2 := b + (cc - b).normalized() * r
		for k in 6:
			var u := float(k) / 5.0
			out.append(p1.lerp(b, u).lerp(b.lerp(p2, u), u))
	return out


## A warning triangle: black border, `fill` field, black icon. `s` scales it about its centre.
static func warning_sign(c: MotionCanvas, centre: Vector2, h: float, icon: int, fill: Color, s := 1.0, rot := 0.0, opacity := 1.0) -> void:
	if s <= 0.0:
		return
	h *= s
	c.draw_set_transform(centre, rot, Vector2.ONE)
	var outer := _round(_tri(Vector2.ZERO, h), h * 0.1)
	c.polygon(outer, Look.INK, Color(0, 0, 0, 0), 0.0, opacity)
	var inner := _round(_tri(Vector2(0, h * 0.035), h * 0.74), h * 0.06)
	c.polygon(inner, fill, Color(0, 0, 0, 0), 0.0, opacity)
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


## An L-shaped hazard clamp at `corner`, arms pointing along +x/-x (sx) and +y/-y (sy).
static func hazard_clamp(c: MotionCanvas, corner: Vector2, sx: float, sy: float, arm: float, thick: float, col_a: Color, col_b: Color) -> void:
	var r1 := Rect2(corner + Vector2(minf(0, sx * arm), minf(0, sy * thick)), Vector2(arm, thick))
	var r2 := Rect2(corner + Vector2(minf(0, sx * thick), minf(0, sy * arm)), Vector2(thick, arm))
	for r in [r1, r2]:
		c.rect(r, col_a)
	# diagonal stripes clipped to each arm
	for r in [r1, r2]:
		var rr: Rect2 = r
		var k0 := -6
		for k in range(k0, int((rr.size.x + rr.size.y) / 34.0) + 6):
			var x := rr.position.x + k * 34.0
			var band := PackedVector2Array([Vector2(x, rr.position.y), Vector2(x + 17, rr.position.y), Vector2(x + 17 - rr.size.y, rr.end.y), Vector2(x - rr.size.y, rr.end.y)])
			var rect := PackedVector2Array([rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)])
			for poly in Geometry2D.intersect_polygons(band, rect):
				c.polygon(poly, col_b, Color(0, 0, 0, 0))
	# bolt
	c.circle(corner + Vector2(sx, sy) * thick * 0.5, thick * 0.22, col_b)
	c.ring(corner + Vector2(sx, sy) * thick * 0.5, thick * 0.3, col_b, 3.0)


## A barrier arm from `pivot`, `angle` radians (0 = pointing along +x), blocks alternating.
static func barrier(c: MotionCanvas, pivot: Vector2, angle: float, length: float, thick: float, col_a: Color, col_b: Color) -> void:
	c.draw_set_transform(pivot, angle, Vector2.ONE)
	var n := 8
	var bl := length / n
	for i in n:
		c.rect(Rect2(i * bl, -thick * 0.5, bl + 0.5, thick), col_a if i % 2 == 0 else col_b)
	c.rect(Rect2(0, -thick * 0.5, length, thick), Look.INK, 1.0, 3.0)
	c.circle(Vector2.ZERO, thick * 0.7, Look.INK)
	c.circle(Vector2.ZERO, thick * 0.3, col_a)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# post
	c.rect(Rect2(pivot + Vector2(-thick * 0.45, 0), Vector2(thick * 0.9, 1080.0 - pivot.y)), Look.INK)
	c.rect(Rect2(pivot + Vector2(-thick * 0.45, thick), Vector2(thick * 0.9, 18)), col_a)
