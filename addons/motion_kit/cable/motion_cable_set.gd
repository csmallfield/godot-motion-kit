# SPDX-License-Identifier: Apache-2.0
## Draws MotionCables as glossy shaded tubes, in depth order, with drop shadows,
## jacket bands, light pulses and connectors. One node draws many cables in one
## canvas; several sets with `z_min` / `z_max` windows share the same cables, so
## other nodes (a logo plate) can sit between cable layers and cables can weave
## over and under them (see MotionCable.z_ranges).
##
##   var set := MotionCableSet.new()
##   set.cables = [a, b, c]
##   add_child(set)          # redraws every frame; set the cables' properties in _frame
##
## Static helpers draw a matching connector or a panel socket anywhere:
## `draw_plug(canvas, kind, pos, dir, width, ...)` and `draw_port(canvas, pos, dir, width, lit, led)`.
@tool
@icon("res://addons/motion_kit/icons/flow.svg")
class_name MotionCableSet
extends MotionCanvas

## The cables this set draws (shared between sets is fine).
var cables: Array = []
## Only parts of cables whose depth is within [z_min, z_max] are drawn here.
var z_min := -INF
var z_max := INF
## Draw shadows (each cable part's shadow is drawn just before it).
var shadows := true
## Optional filter: Callable(cable) -> bool.
var filter: Callable


func _init() -> void:
	draw_fn = _paint


func _paint(c: MotionCanvas, f: float) -> void:
	var parts := []
	for i in cables.size():
		var cb: MotionCable = cables[i]
		if cb == null or cb.opacity <= 0.0 or cb.points.size() < 2:
			continue
		if filter.is_valid() and not bool(filter.call(cb)):
			continue
		cb.build(f)
		for p in cb.pieces():
			var zz: float = p[2]
			if zz < z_min or zz > z_max:
				continue
			parts.append([zz, i, cb, float(p[0]), float(p[1])])
	parts.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	for p in parts:
		_draw_part(c, p[2], p[3], p[4])


func _draw_part(c: MotionCanvas, cb: MotionCable, u0: float, u1: float) -> void:
	var total := cb.length()
	if total <= 0.0:
		return
	# overlap neighbouring pieces by a pixel so z-split seams don't show
	var pad := 1.0 / total
	var a := u0 - (pad if u0 > cb.start else 0.0)
	var b := u1 + (pad if u1 < cb.reveal else 0.0)
	var pts := cb.sub(a, b)
	if pts.size() < 2:
		return
	var w := cb.width
	var op := cb.opacity
	var is_head := absf(u1 - cb.reveal) < 0.0001 and cb.plug_head != MotionCable.Plug.NONE
	var is_tail := absf(u0 - cb.start) < 0.0001 and cb.plug_tail != MotionCable.Plug.NONE
	if shadows and cb.shadow.a > 0.0:
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + cb.shadow_offset)
		draw_polyline(sh, Color(cb.shadow, cb.shadow.a * op), w * 1.05, true)
		if is_head:
			_plug_shadow(cb, cb.reveal, 1.0)
		if is_tail:
			_plug_shadow(cb, cb.start, -1.0)
	if cb.glow > 0.0:
		var gc := cb.glow_color if cb.glow_color.a > 0.0 else cb.jacket
		draw_polyline(pts, Color(gc, 0.18 * cb.glow * op), w * 2.4, true)
		draw_polyline(pts, Color(gc, 0.25 * cb.glow * op), w * 1.6, true)
	_tube(pts, cb.jacket, cb, op)
	# jacket bands and stripes, shaded like the tube
	var la := a * total
	var lb := b * total
	if cb.stripe_every > 0.0:
		var s := fposmod(cb.stripe_phase, cb.stripe_every) - cb.stripe_every
		while s < lb:
			var s0 := maxf(s, la)
			var s1 := minf(s + cb.stripe_len, lb)
			if s1 > s0 + 0.5:
				_tube(cb.sub(s0 / total, s1 / total), cb.stripe_color, cb, op)
			s += cb.stripe_every
	for band in cb.bands:
		var mid: float = float(band.u) * total
		var half: float = float(band.len) * 0.5
		var s0 := maxf(mid - half, la)
		var s1 := minf(mid + half, lb)
		if s1 > s0 + 0.5:
			_tube(cb.sub(s0 / total, s1 / total), band.color, cb, op)
	# light pulses
	for pu in cb.pulses:
		var mid2: float = float(pu.u) * total
		var half2: float = float(pu.get("len", 90.0)) * 0.5
		var s0 := maxf(mid2 - half2, la)
		var s1 := minf(mid2 + half2, lb)
		if s1 <= s0 + 0.5:
			continue
		var pp := cb.sub(s0 / total, s1 / total)
		var pc: Color = pu.get("color", Color.WHITE)
		var pw: float = float(pu.get("power", 1.0)) * op
		draw_polyline(pp, Color(pc, 0.22 * pw), w * 1.9, true)
		draw_polyline(pp, Color(pc, 0.55 * pw), w * 0.95, true)
		draw_polyline(pp, Color(pc.lerp(Color.WHITE, 0.6), 0.95 * pw), w * 0.42, true)
	# sliding specular hotspot
	if cb.glint >= 0.0 and cb.gloss > 0.0:
		var gl := cb.glint * total
		var s0 := maxf(gl - w * 1.6, la)
		var s1 := minf(gl + w * 1.6, lb)
		if s1 > s0 + 0.5:
			var gp := _offset(cb.sub(s0 / total, s1 / total), cb, w * 0.22)
			draw_polyline(gp, Color(1, 1, 1, 0.85 * cb.gloss * op), w * 0.2, true)
	if is_head:
		_plug_at(cb, cb.reveal, 1.0, op)
	if is_tail:
		_plug_at(cb, cb.start, -1.0, op)


func _edge(cb: MotionCable, col: Color) -> Color:
	if cb.edge.a > 0.0:
		return cb.edge
	return col.darkened(0.72)


## A shaded tube along pts: dark rim, body, lit side and specular line, offset
## towards the light so the highlight stays on the lit side as the cable turns.
func _tube(pts: PackedVector2Array, col: Color, cb: MotionCable, op: float) -> void:
	if pts.size() < 2:
		return
	var w := cb.width
	draw_polyline(pts, Color(_edge(cb, col), op), w, true)
	draw_polyline(pts, Color(col.darkened(0.38), op), w * 0.84, true)
	draw_polyline(_offset(pts, cb, w * 0.05), Color(col, op), w * 0.64, true)
	draw_polyline(_offset(pts, cb, w * 0.14), Color(col.lightened(0.22), op), w * 0.34, true)
	if cb.gloss > 0.0:
		draw_polyline(_offset(pts, cb, w * 0.22), Color(col.lightened(0.75), 0.75 * cb.gloss * op), w * 0.1, true)


func _offset(pts: PackedVector2Array, cb: MotionCable, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	var L := cb.light.normalized()
	var n := pts.size()
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		var nrm := Vector2(-t.y, t.x).normalized()
		out[i] = pts[i] + nrm * (nrm.dot(L) * d)
	return out


func _plug_at(cb: MotionCable, u: float, sgn: float, op: float) -> void:
	var p := cb.point_at(u)
	var d := cb.tangent_at(u) * sgn
	var kind := cb.plug_head if sgn > 0.0 else cb.plug_tail
	var band := cb.plug_band if cb.plug_band.a > 0.0 else cb.jacket
	draw_plug(self, kind, p, d, cb.width, cb.plug_color, band, cb.plug_lit, cb.plug_light, op)


func _plug_shadow(cb: MotionCable, u: float, sgn: float) -> void:
	var kind := cb.plug_head if sgn > 0.0 else cb.plug_tail
	var p := cb.point_at(u) + cb.shadow_offset
	var d := cb.tangent_at(u) * sgn
	var l := MotionCable.plug_length(kind, cb.width)
	var h := cb.width * (1.9 if kind == MotionCable.Plug.MULTIPIN else 1.25)
	draw_set_transform(p, d.angle(), Vector2.ONE)
	draw_rect(Rect2(0, -h * 0.5, l, h), Color(cb.shadow, cb.shadow.a * cb.opacity))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A cylinder seen side-on: horizontal bands from dark to light to dark across its height.
static func _chrome(c: CanvasItem, r: Rect2, base: Color, op: float, shine := 0.85) -> void:
	var steps := [0.0, 0.12, 0.28, 0.42, 0.6, 0.78, 0.9, 1.0]
	var tones := [-0.55, -0.2, 0.35, shine, 0.15, -0.25, -0.6]
	for i in tones.size():
		var y0: float = r.position.y + r.size.y * float(steps[i])
		var y1: float = r.position.y + r.size.y * float(steps[i + 1])
		var tv: float = tones[i]
		var col := base.lightened(tv) if tv > 0.0 else base.darkened(-tv)
		c.draw_rect(Rect2(r.position.x, y0, r.size.x, y1 - y0 + 0.6), Color(col, op))


## Draw a connector whose rear (the cable entry) is at `pos`, pointing along `dir`.
static func draw_plug(c: CanvasItem, kind: int, pos: Vector2, dir: Vector2, w: float, housing: Color,
		band: Color, lit := 0.0, light := Color("#d7ff1f"), op := 1.0) -> void:
	if kind == MotionCable.Plug.NONE:
		return
	var chrome := Color("#b9bcc4")
	c.draw_set_transform(pos, dir.angle(), Vector2.ONE)
	match kind:
		MotionCable.Plug.JACK:
			# rubber boot tapering into a chrome barrel, insulator ring, sleeve and tip
			var boot := PackedVector2Array([Vector2(-2, -w * 0.5), Vector2(w * 1.5, -w * 0.62), Vector2(w * 1.5, w * 0.62), Vector2(-2, w * 0.5)])
			c.draw_colored_polygon(boot, Color(housing, op))
			for k in 4:
				c.draw_rect(Rect2(w * (0.2 + k * 0.3), -w * 0.56, w * 0.08, w * 1.12), Color(housing.lightened(0.18), op))
			c.draw_rect(Rect2(w * 1.15, -w * 0.62, w * 0.22, w * 1.24), Color(band, op))
			_chrome(c, Rect2(w * 1.5, -w * 0.62, w * 1.7, w * 1.24), chrome, op)
			_chrome(c, Rect2(w * 3.2, -w * 0.3, w * 0.9, w * 0.6), chrome, op)
			c.draw_rect(Rect2(w * 3.65, -w * 0.3, w * 0.16, w * 0.6), Color(0.05, 0.05, 0.06, op))
			_chrome(c, Rect2(w * 4.1, -w * 0.24, w * 0.5, w * 0.48), chrome, op, 1.0)
		MotionCable.Plug.MULTIPIN:
			var boot2 := PackedVector2Array([Vector2(-2, -w * 0.5), Vector2(w * 1.1, -w * 0.78), Vector2(w * 1.1, w * 0.78), Vector2(-2, w * 0.5)])
			c.draw_colored_polygon(boot2, Color(housing, op))
			_chrome(c, Rect2(w * 1.1, -w * 0.95, w * 1.5, w * 1.9), housing.lightened(0.35), op, 0.6)
			for k in 7:
				c.draw_rect(Rect2(w * (1.2 + k * 0.2), -w * 0.95, w * 0.06, w * 1.9), Color(0, 0, 0, 0.45 * op))
			c.draw_rect(Rect2(w * 2.6, -w * 0.95, w * 0.25, w * 1.9), Color(band, op))
			_chrome(c, Rect2(w * 2.85, -w * 0.8, w * 0.75, w * 1.6), chrome, op)
			for k in 3:
				c.draw_rect(Rect2(w * 3.6, -w * 0.5 + k * w * 0.42, w * 0.3, w * 0.14), Color(chrome.lightened(0.3), op))
		MotionCable.Plug.BLADE:
			var body := Rect2(0, -w * 0.75, w * 2.3, w * 1.5)
			c.draw_rect(body, Color(housing, op))
			c.draw_rect(Rect2(0, -w * 0.75, w * 2.3, w * 0.22), Color(housing.lightened(0.25), op))
			for k in 5:
				c.draw_rect(Rect2(w * (0.25 + k * 0.32), -w * 0.75, w * 0.1, w * 1.5), Color(0, 0, 0, 0.35 * op))
			c.draw_rect(Rect2(w * 1.9, -w * 0.75, w * 0.2, w * 1.5), Color(band, op))
			_chrome(c, Rect2(w * 2.3, -w * 0.55, w * 0.7, w * 0.22), chrome, op)
			_chrome(c, Rect2(w * 2.3, w * 0.33, w * 0.7, w * 0.22), chrome, op)
		MotionCable.Plug.BARREL:
			_chrome(c, Rect2(0, -w * 0.62, w * 2.0, w * 1.24), housing.lightened(0.2), op, 0.5)
			c.draw_rect(Rect2(w * 1.4, -w * 0.62, w * 0.3, w * 1.24), Color(band, op))
			_chrome(c, Rect2(w * 2.0, -w * 0.4, w * 0.8, w * 0.8), chrome, op)
	if lit > 0.0:
		var lc := Color(light, op * clampf(lit, 0.0, 1.0))
		c.draw_circle(Vector2(w * 0.7, 0), w * 0.42, Color(light, 0.25 * op * lit))
		c.draw_circle(Vector2(w * 0.7, 0), w * 0.16, lc)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A panel-mount socket at `pos` facing out along -dir (a plug arriving along `dir`
## lands in it): recess, chrome bezel, and an LED ring lit 0..1.
static func draw_port(c: CanvasItem, pos: Vector2, dir: Vector2, w: float, lit := 0.0, led := Color("#d7ff1f"), op := 1.0) -> void:
	c.draw_set_transform(pos, dir.angle(), Vector2.ONE)
	var r := w * 1.25
	c.draw_circle(Vector2.ZERO, r * 1.55, Color(0.03, 0.03, 0.04, op))
	c.draw_arc(Vector2.ZERO, r * 1.42, 0, TAU, 48, Color(led, (0.15 + 0.85 * lit) * op), r * 0.16, true)
	if lit > 0.0:
		c.draw_arc(Vector2.ZERO, r * 1.42, 0, TAU, 48, Color(led, 0.25 * lit * op), r * 0.5, true)
	c.draw_circle(Vector2.ZERO, r * 1.15, Color(0.62, 0.63, 0.67, op))
	c.draw_circle(Vector2(-r * 0.08, -r * 0.08), r * 1.02, Color(0.82, 0.83, 0.86, op))
	c.draw_circle(Vector2.ZERO, r * 0.9, Color(0.36, 0.37, 0.4, op))
	c.draw_circle(Vector2.ZERO, r * 0.72, Color(0.02, 0.02, 0.03, op))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
