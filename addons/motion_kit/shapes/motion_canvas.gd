# SPDX-License-Identifier: Apache-2.0
## Immediate-mode drawing for one frame: the counterpart of an inline <svg>
## built from loops (track floors, speed lines, wireframes, particle dust).
## Set `draw_fn` to Callable(canvas: MotionCanvas, f: float); it runs inside
## _draw every time the frame changes, and calls the helpers below.
##
##   canvas.draw_fn = func(c: MotionCanvas, f: float):
##       for i in 25:
##           c.line(Vector2(960, 560), Vector2(-1400 + i * 196, 1080), AMBER, 1.5, 0.5)
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionCanvas
extends Node2D

var draw_fn: Callable
var frame := 0.0


func _frame(f: float) -> void:
	frame = f
	queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self, frame)


func _c(col: Color, opacity: float) -> Color:
	return Color(col, col.a * opacity)


# Lines thinner than a pixel draw at 1 px with their coverage as alpha, as a
# browser rasterizes them (Godot would otherwise drop pixels and dot the line).
func _thin(col: Color, w: float) -> Array:
	if w < 1.0:
		return [Color(col, col.a * maxf(w, 0.0)), 1.0]
	return [col, w]


## A straight line, `w` pixels wide.
func line(a: Vector2, b: Vector2, col: Color, w := 1.0, opacity := 1.0) -> void:
	var t := _thin(_c(col, opacity), w)
	draw_line(a, b, t[0], t[1], true)


## A dashed line: `dash` on, `gap` off, in pixels (SVG stroke-dasharray).
func dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float, gap: float, opacity := 1.0) -> void:
	var len := a.distance_to(b)
	if len <= 0.0 or dash <= 0.0:
		return
	gap = maxf(gap, 0.0)
	var dir := (b - a) / len
	var s := 0.0
	var t := _thin(_c(col, opacity), w)
	while s < len:
		draw_line(a + dir * s, a + dir * minf(s + dash, len), t[0], t[1], true)
		s += dash + gap


## A dashed polyline (SVG stroke-dasharray "dash gap" with stroke-dashoffset):
## the pattern runs continuously around corners, and a dash that crosses a
## corner bends with it. A positive offset moves the pattern backwards along
## the line, as in SVG.
func dashed_polyline(pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float, offset := 0.0, opacity := 1.0) -> void:
	if pts.size() < 2 or dash <= 0.0:
		return
	gap = maxf(gap, 0.0)
	var t := _thin(_c(col, opacity), w)
	# Walk the line carrying the pattern state (on/off and what is left of the
	# current dash or gap), so every step makes progress whatever the floats do.
	var ph := fposmod(offset, dash + gap)
	var on := ph < dash
	var left := (dash - ph) if on else (dash + gap - ph)
	var run := PackedVector2Array()
	if on:
		run.append(pts[0])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var len := a.distance_to(b)
		if len <= 0.0:
			continue
		var dir := (b - a) / len
		var s := 0.0
		while s < len:
			var step := minf(left, len - s)
			s += step
			left -= step
			if left <= 1e-9:
				if on:
					run.append(a + dir * s)
					if run.size() >= 2:
						draw_polyline(run, t[0], t[1], true)
					run = PackedVector2Array()
				else:
					run = PackedVector2Array([a + dir * s])
				on = not on
				left = dash if on else gap
				if left <= 0.0:          # gap 0: the next dash starts at once
					on = true
					left = dash
					run = PackedVector2Array([a + dir * s])
		if on:
			run.append(b)
	if on and run.size() >= 2:
		draw_polyline(run, t[0], t[1], true)


func polyline(pts: PackedVector2Array, col: Color, w := 1.0, opacity := 1.0, closed := false) -> void:
	if pts.size() < 2:
		return
	var p := pts
	if closed:
		p = pts.duplicate()
		p.append(pts[0])
	var t := _thin(_c(col, opacity), w)
	draw_polyline(p, t[0], t[1], true)


## A filled and/or stroked polygon (fill alpha 0 to skip the fill).
func polygon(pts: PackedVector2Array, fill: Color, stroke: Color, w := 1.0, opacity := 1.0) -> void:
	if pts.size() < 3:
		return
	if fill.a > 0.0:
		# Skip polygons Godot can't triangulate (self-intersecting), which would error.
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			draw_colored_polygon(pts, _c(fill, opacity))
	if stroke.a > 0.0 and w > 0.0:
		polyline(pts, stroke, w, opacity, true)


func circle(c: Vector2, r: float, fill: Color, opacity := 1.0) -> void:
	if r > 0.0:
		draw_circle(c, r, _c(fill, opacity), true, -1.0, true)


## A circle outline, `w` pixels wide.
func ring(c: Vector2, r: float, col: Color, w := 1.0, opacity := 1.0) -> void:
	if r > 0.0:
		var t := _thin(_c(col, opacity), w)
		draw_arc(c, r, 0.0, TAU, maxi(24, int(r * 0.6)), t[0], t[1], true)


## An ellipse outline with radii rx, ry.
func ellipse(c: Vector2, rx: float, ry: float, col: Color, w := 1.0, opacity := 1.0) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var n := maxi(24, int(maxf(rx, ry) * 0.6))
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := TAU * i / n
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	var th := _thin(_c(col, opacity), w)
	draw_polyline(pts, th[0], th[1], true)


## A filled rectangle, or an outline when `w` > 0 (inside the rect, like a CSS border).
func rect(r: Rect2, col: Color, opacity := 1.0, w := 0.0) -> void:
	if w <= 0.0:
		draw_rect(r, _c(col, opacity))
	else:
		var c := _c(col, opacity)
		draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), c)
		draw_rect(Rect2(r.position + Vector2(0, w), Vector2(w, r.size.y - 2 * w)), c)
		draw_rect(Rect2(r.position + Vector2(r.size.x - w, w), Vector2(w, r.size.y - 2 * w)), c)
