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
	return MotionMarks.fade(col, opacity)


# Lines thinner than a pixel draw at 1 px with their coverage as alpha, as a
# browser rasterizes them (Godot would otherwise drop pixels and dot the line).
# The helpers below are MotionMarks' primitives drawn into this canvas.
func _thin(col: Color, w: float) -> Array:
	return MotionMarks.thin(col, w)


## A straight line, `w` pixels wide.
func line(a: Vector2, b: Vector2, col: Color, w := 1.0, opacity := 1.0) -> void:
	MotionMarks.line(self, a, b, col, w, opacity)


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
	if dash + gap < 0.25:
		# A pattern finer than a quarter pixel reads as a solid line at its duty
		# cycle (and walking it dash by dash could take millions of steps).
		polyline(pts, col, w, opacity * dash / (dash + gap))
		return
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


## An antialiased polyline (`closed` joins the last point to the first).
func polyline(pts: PackedVector2Array, col: Color, w := 1.0, opacity := 1.0, closed := false) -> void:
	MotionMarks.polyline(self, pts, col, w, opacity, closed)


## A filled and/or stroked polygon (fill alpha 0 to skip the fill; polygons
## Godot can't triangulate are skipped).
func polygon(pts: PackedVector2Array, fill: Color, stroke: Color, w := 1.0, opacity := 1.0) -> void:
	MotionMarks.polygon(self, pts, fill, stroke, w, opacity)


## A filled disc.
func circle(c: Vector2, r: float, fill: Color, opacity := 1.0) -> void:
	MotionMarks.circle(self, c, r, fill, opacity)


## A circle outline, `w` pixels wide.
func ring(c: Vector2, r: float, col: Color, w := 1.0, opacity := 1.0) -> void:
	MotionMarks.ring(self, c, r, col, w, opacity)


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
	MotionMarks.rect(self, r, col, opacity, w)
