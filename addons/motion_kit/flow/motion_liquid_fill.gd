# SPDX-License-Identifier: Apache-2.0
## A vessel filling with liquid: whatever you put under `fill` shows only below
## an animated liquid surface, so a logo (in its own colours) fills up from the
## bottom like a tank. The surface is analytic: a level, a tilt, damped
## standing waves kicked at given frames (slosh) and small travelling ripples,
## so it is a pure function of the frame. Optional: a meniscus band (whatever
## you put under `surface` shows only in a thin band at the surface, e.g. a
## lighter copy of the logo, so the highlight follows the vessel's shape),
## bubbles rising below the surface, and a foam line.
##
##   var tank := MotionLiquidFill.new()
##   tank.size = Vector2(1400, 333)
##   tank.fill.add_child(logo)                 # the logo in its own colours
##   tank.surface.add_child(logo_light)        # optional: a white copy for the meniscus
##   tank.kicks = [Vector2(176, 1.0), Vector2(200, 1.6)]
##   # in _frame: tank.level = MK.map(f, [176, 200], [0, 1])
##
## Coordinates: the vessel is the rect (0, 0)–size in local space; level 0 is
## its bottom edge, 1 its top. The masks are drawn with draw_* calls
## (clip_children), so they follow the node's transform.
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionLiquidFill
extends Node2D

@export var size := Vector2(400, 200)
## 0 = empty (surface at the bottom edge), 1 = surface at the top edge.
@export var level := 0.0
## Surface slope: px the right end sits above the left end.
@export var tilt := 0.0
## Standing-wave amplitude in px per unit of kick.
@export var wave_amp := 10.0
## Slosh angular frequency in radians per frame (the first mode).
@export var wave_freq := 0.42
## Exponential damping per frame of the slosh.
@export var damping := 0.07
## Travelling ripple amplitude (px) and speed (px per frame).
@export var ripple := 1.5
@export var ripple_len := 140.0
@export var ripple_speed := 6.0
## Meniscus band thickness (px). The `surface` children show inside it.
@export var meniscus := 6.0
## Plain meniscus colour used when `surface` has no children.
@export var meniscus_color := Color(1, 1, 1, 0.85)
## Foam: a row of small bright bubbles just under the surface.
@export var foam := 0.0
@export var foam_color := Color(1, 1, 1, 0.9)
## Bubbles rising below the surface.
@export var bubbles := 0
@export var bubble_color := Color(1, 1, 1, 0.7)
@export var bubble_size := 6.0
@export var bubble_speed := 4.0
@export var seed_value := 1.0

## Slosh kicks: Vector2(frame, strength) or {at, amp, mode} (mode 1 = sloshing
## end to end, 2 = a hump in the middle; default both).
var kicks: Array = []
## Children here are revealed below the surface.
var fill: Node2D
## Children here show only in the meniscus band (optional).
var surface: Node2D
var frame := 0.0

var _clip: MotionCanvas
var _band: MotionCanvas
var _fx: MotionCanvas
var _plain: MotionCanvas
const SAMPLES := 64


func _init() -> void:
	_clip = MotionCanvas.new()
	_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_clip.draw_fn = _draw_liquid_mask
	add_child(_clip)
	fill = Node2D.new()
	fill.name = "Fill"
	_clip.add_child(fill)
	_fx = MotionCanvas.new()
	_fx.draw_fn = _draw_bubbles
	_clip.add_child(_fx)
	_band = MotionCanvas.new()
	_band.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_band.draw_fn = _draw_band_mask
	add_child(_band)
	surface = Node2D.new()
	surface.name = "Surface"
	_band.add_child(surface)
	_plain = MotionCanvas.new()
	_plain.draw_fn = _draw_plain_meniscus
	add_child(_plain)


func _frame(f: float) -> void:
	frame = f
	var top := _min_surface_y()
	var bottom := _max_surface_y()
	# An empty clip mask clips nothing: hide what would be empty.
	_clip.visible = top < size.y - 0.5
	var band_on := bottom > -meniscus and top < size.y + meniscus and level > -0.02 and level < 1.0 + (wave_amp * 2.0 + absf(tilt) + meniscus) / maxf(1.0, size.y)
	_band.visible = band_on and surface.get_child_count() > 0
	_plain.visible = band_on and surface.get_child_count() == 0 and meniscus > 0.0
	for c: MotionCanvas in [_clip, _band, _fx, _plain]:
		c.frame = f
		c.queue_redraw()


## The slosh displacement (px, positive = surface up) at x01 (0..1 across the
## vessel) and frame f, from `kicks`. Static so canvases can draw small vessels
## (sight glasses) with the same physics.
static func slosh(f: float, x01: float, kick_list: Array, amp := 10.0, freq := 0.42, damp := 0.07) -> float:
	var y := 0.0
	for k in kick_list:
		var at: float
		var a: float
		var mode := 0
		if k is Vector2:
			at = (k as Vector2).x
			a = (k as Vector2).y
		else:
			at = float(k.at)
			a = float(k.get("amp", 1.0))
			mode = int(k.get("mode", 0))
		var t := f - at
		if t < 0.0:
			continue
		var env := a * amp * exp(-t * damp)
		if mode != 2:   # mode 1: end-to-end slosh
			y += env * sin(t * freq) * cos(PI * x01)
		if mode != 1:   # mode 2: central hump, faster, smaller
			y += env * 0.45 * sin(t * freq * 1.7 + 0.6) * cos(TAU * x01)
	return y


## Surface y in local px at local x.
func surface_y(x: float) -> float:
	var u := clampf(x / maxf(1.0, size.x), 0.0, 1.0)
	var y := size.y * (1.0 - level) - tilt * (u - 0.5)
	y -= slosh(frame, u, kicks, wave_amp, wave_freq, damping)
	if ripple > 0.0:
		y -= ripple * sin(TAU * (x / ripple_len) - frame * ripple_speed * TAU / ripple_len)
		y -= ripple * 0.5 * sin(TAU * (x / (ripple_len * 0.37)) + frame * ripple_speed * 1.3 * TAU / ripple_len + 1.7)
	return y


func _surface_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in SAMPLES + 1:
		var x := size.x * float(i) / SAMPLES
		pts.append(Vector2(x, surface_y(x)))
	return pts


func _min_surface_y() -> float:
	var m := INF
	for p in _surface_points():
		m = minf(m, p.y)
	return m


func _max_surface_y() -> float:
	var m := -INF
	for p in _surface_points():
		m = maxf(m, p.y)
	return m


func _draw_liquid_mask(c: MotionCanvas, _f: float) -> void:
	var pts := _surface_points()
	var bottom := size.y + 4.0
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(p.x, minf(p.y, bottom)))
	poly.append(Vector2(size.x, bottom))
	poly.append(Vector2(0, bottom))
	# extend a little past the sides so anti-aliased edges of the content survive
	poly[0].x -= 4.0
	poly[SAMPLES].x += 4.0
	poly[SAMPLES + 1].x += 4.0
	poly[SAMPLES + 2].x -= 4.0
	c.draw_colored_polygon(poly, Color.WHITE)


func _band_poly(thick: float) -> PackedVector2Array:
	var pts := _surface_points()
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(p + Vector2(0, -thick * 0.25))
	for i in range(pts.size() - 1, -1, -1):
		poly.append(pts[i] + Vector2(0, thick * 0.75))
	return poly


func _draw_band_mask(c: MotionCanvas, _f: float) -> void:
	c.draw_colored_polygon(_band_poly(meniscus), Color.WHITE)


func _draw_plain_meniscus(c: MotionCanvas, _f: float) -> void:
	var pts := _surface_points()
	c.draw_polyline(pts, meniscus_color, meniscus, true)


func _draw_bubbles(c: MotionCanvas, f: float) -> void:
	var top := _min_surface_y()
	if bubbles > 0:
		for k in bubbles:
			var r0 := MK.rand(k * 3.17 + seed_value)
			var x := size.x * MK.rand(k * 9.71 + seed_value * 2.0)
			var speed := bubble_speed * (0.6 + 0.8 * MK.rand(k * 1.3 + seed_value))
			var span := size.y + 40.0
			var y := size.y + 20.0 - fposmod(r0 * span + f * speed, span)
			x += sin(f * 0.15 + k) * 6.0
			if y < surface_y(x) + 4.0:
				continue
			var rad := bubble_size * (0.5 + MK.rand(k * 5.1 + seed_value))
			c.draw_arc(Vector2(x, y), rad, 0.0, TAU, 14, bubble_color, maxf(1.5, rad * 0.35), true)
	if foam > 0.0:
		var n := int(size.x / 14.0)
		for k in n:
			var x2 := (float(k) + MK.rand(k * 2.3 + seed_value)) * 14.0
			var sy := surface_y(x2)
			if sy > size.y or sy < 0.0:   # no foam above a brim-full vessel
				continue
			var rad2 := (2.0 + 4.0 * MK.rand(k * 7.7 + floorf(f / 3.0))) * foam
			c.draw_circle(Vector2(x2, sy + rad2 + 1.0), rad2, foam_color)
