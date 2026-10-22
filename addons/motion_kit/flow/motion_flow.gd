# SPDX-License-Identifier: Apache-2.0
## Fluid flowing along pipes: a network of thick paths (polylines, corners
## rounded once at build time) whose contents are a pure function of state you
## set every frame: how far the fluid front has travelled (`fill`), how far the
## tail has drained (`drain`), pulses and bubbles moving with the flow, its
## colour, glow and pressure. For fuel lines, coolant loops, data buses, any
## "something travels down a line" diagram.
##
##   var flow := MotionFlow.new()
##   var main := flow.add_pipe(PackedVector2Array([Vector2(0, 800), Vector2(900, 800), Vector2(900, 400)]),
##       {width = 26, radius = 60, fluid = LIME})
##   flow.apply(func(i): return {fill = MK.map(f, [20, 34], [0, 1]), flow = f * 14.0})
##
## Arc lengths are in pixels. Everything is drawn in one _draw, so a few dozen
## pipes with pulses cost a few hundred draw calls and no offscreen pass.
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionFlow
extends Node2D

## Defaults for add_pipe() options and per-frame state.
const PIPE_DEFAULTS := {
	width = 22.0,          # outer width of the pipe (px)
	wall_width = 4.0,      # wall thickness each side
	radius = 40.0,         # corner radius applied to the points
	segments = 10,         # samples per rounded corner
	wall = Color(0.55, 0.6, 0.68),
	core = Color(0.08, 0.1, 0.14),   # empty pipe interior
	fluid = Color(0.85, 1.0, 0.12),
	pulse = Color(1, 1, 1),          # pulse colour (mixed over the fluid by pulse_gain)
	caps = true,           # round end caps on the wall
	arrows = 0.0,          # spacing of flow arrows on the wall (0 = none)
	arrow_color = Color(0.08, 0.1, 0.14),
}
const STATE_DEFAULTS := {
	draw = 1.0,            # 0..1 of the pipe wall drawn from the start (a pipe tracing itself)
	draw_from = 0.0,       # 0..1 where the drawn wall starts (un-drawing from the start)
	fill = 0.0,            # 0..1 fluid front position along the pipe
	drain = 0.0,           # 0..1 fluid tail position (fluid between drain and fill)
	flow = 0.0,            # px the contents have moved (animate f * speed)
	pulse_len = 30.0,      # px length of each pulse
	pulse_gap = 90.0,      # px between pulse starts
	pulse_gain = 0.0,      # 0..1 how bright pulses are over the fluid
	glow = 0.35,           # 0..1 halo around the fluid
	bubbles = 0,           # bubbles in the fluid
	bubble_speed = 1.3,    # bubbles move this many times faster than `flow`
	bubble_color = Color(1, 1, 1, 0.85),
	fluid = null,          # override the pipe's fluid colour this frame
	opacity = 1.0,
	front_glow = 0.0,      # 0..1 a bright bead at the travelling front
}

var _pipes: Array[Dictionary] = []
var _nodes: Array[Dictionary] = []
var _state: Array[Dictionary] = []


## Add a pipe through `points` (screen px, local to this node). Returns its index.
## `opts` overrides PIPE_DEFAULTS.
func add_pipe(points: PackedVector2Array, opts := {}) -> int:
	var p := PIPE_DEFAULTS.duplicate()
	p.merge(opts, true)
	var pts: PackedVector2Array = rounded(points, float(p.radius), int(p.segments)) if float(p.radius) > 0.0 else points
	p.points = pts
	p.cum = _cumulative(pts)
	p.length = (p.cum as PackedFloat32Array)[pts.size() - 1]
	_pipes.append(p)
	_state.append(STATE_DEFAULTS.duplicate())
	queue_redraw()
	return _pipes.size() - 1


## A junction, tee or fitting drawn over the pipes: a disc of `radius` with a ring.
## `state_fn(f) -> {o, fill}` is optional; returns its index.
func add_node(pos: Vector2, radius := 16.0, ring := Color(0.55, 0.6, 0.68), fill := Color(0.08, 0.1, 0.14)) -> int:
	_nodes.append({pos = pos, radius = radius, ring = ring, fill = fill, o = 1.0, lit = Color(0, 0, 0, 0)})
	return _nodes.size() - 1


func pipe_count() -> int:
	return _pipes.size()


func length(i: int) -> float:
	return float(_pipes[i].length)


func points(i: int) -> PackedVector2Array:
	return _pipes[i].points


## Point at arc length `s` px along pipe i (clamped).
func point_at(i: int, s: float) -> Vector2:
	return _point(_pipes[i], s)


## Unit tangent at arc length `s` px.
func tangent_at(i: int, s: float) -> Vector2:
	var p: Dictionary = _pipes[i]
	return (_point(p, s + 1.0) - _point(p, s - 1.0)).normalized()


## Set pipe i's state for this frame (keys of STATE_DEFAULTS); unset keys reset to defaults.
func set_state(i: int, d: Dictionary) -> void:
	var s := STATE_DEFAULTS.duplicate()
	s.merge(d, true)
	_state[i] = s
	queue_redraw()


## Set every pipe's state from fn(i) -> Dictionary, like MotionSvg.apply.
func apply(fn: Callable) -> void:
	for i in _pipes.size():
		var d: Variant = fn.call(i)
		set_state(i, d if d is Dictionary else {})


## Set a node's look: {o, lit (Color added as an inner glow disc)}.
func set_node(i: int, d: Dictionary) -> void:
	_nodes[i].merge(d, true)
	queue_redraw()


func _draw() -> void:
	# Walls under everything, then fluids, then fittings.
	for i in _pipes.size():
		_draw_wall(_pipes[i], _state[i])
	for i in _pipes.size():
		_draw_fluid(_pipes[i], _state[i])
	for n in _nodes:
		var o: float = n.o
		if o <= 0.0:
			continue
		var r: float = n.radius
		draw_circle(n.pos, r, Color(n.fill, (n.fill as Color).a * o))
		var lit: Color = n.lit
		if lit.a > 0.0:
			draw_circle(n.pos, r * 0.62, Color(lit, lit.a * o))
		draw_arc(n.pos, r, 0.0, TAU, 32, Color(n.ring, (n.ring as Color).a * o), maxf(2.0, r * 0.22), true)


func _draw_wall(p: Dictionary, s: Dictionary) -> void:
	var o: float = s.opacity
	var a: float = clampf(s.draw_from, 0.0, 1.0) * float(p.length)
	var b: float = clampf(s.draw, 0.0, 1.0) * float(p.length)
	if o <= 0.0 or b <= a:
		return
	var seg := sub_path(p, a, b)
	if seg.size() < 2:
		return
	var w: float = p.width
	var wall: Color = p.wall
	var core: Color = p.core
	draw_polyline(seg, Color(wall, wall.a * o), w, true)
	draw_polyline(seg, Color(core, core.a * o), w - 2.0 * float(p.wall_width), true)
	if p.caps:
		for e in [seg[0], seg[seg.size() - 1]]:
			draw_circle(e, w * 0.5, Color(wall, wall.a * o))
			draw_circle(e, w * 0.5 - float(p.wall_width), Color(core, core.a * o))
	var sp: float = p.arrows
	if sp > 0.0:
		var ac: Color = p.arrow_color
		var k := sp * 0.5
		while k < b:
			if k > a:
				var c := _point(p, k)
				var t := (_point(p, k + 1.0) - _point(p, k - 1.0)).normalized()
				var nrm := Vector2(-t.y, t.x)
				var h := (w - 2.0 * float(p.wall_width)) * 0.32
				draw_colored_polygon(PackedVector2Array([c + t * h, c - t * h + nrm * h, c - t * h - nrm * h]), Color(ac, ac.a * o * 0.6))
			k += sp


func _draw_fluid(p: Dictionary, s: Dictionary) -> void:
	var o: float = s.opacity
	var L: float = p.length
	var a: float = clampf(s.drain, 0.0, 1.0) * L
	var b: float = clampf(s.fill, 0.0, 1.0) * L
	if o <= 0.0 or b - a < 0.5:
		return
	var inner: float = float(p.width) - 2.0 * float(p.wall_width)
	var fluid: Color = s.fluid if s.fluid is Color else p.fluid
	var seg := sub_path(p, a, b)
	var glow: float = s.glow
	if glow > 0.0:
		draw_polyline(seg, Color(fluid, 0.10 * glow * o), inner + float(p.width) * 1.6, true)
		draw_polyline(seg, Color(fluid, 0.22 * glow * o), inner + float(p.width) * 0.6, true)
	draw_polyline(seg, Color(fluid, fluid.a * o), inner, true)
	# rounded fluid ends sit inside the pipe
	draw_circle(seg[0], inner * 0.5, Color(fluid, fluid.a * o))
	draw_circle(seg[seg.size() - 1], inner * 0.5, Color(fluid, fluid.a * o))
	# pulses: slugs of brighter fluid moving with the flow
	var gain: float = s.pulse_gain
	if gain > 0.0:
		var gap: float = maxf(4.0, s.pulse_gap)
		var plen: float = s.pulse_len
		var pc: Color = fluid.lerp(s.get("pulse_color", p.pulse), clampf(gain, 0.0, 1.0))
		var start := fposmod(float(s.flow), gap) - gap
		var x := start
		while x < L:
			var x0 := maxf(x, a)
			var x1 := minf(x + plen, b)
			if x1 - x0 > 0.5:
				draw_polyline(sub_path(p, x0, x1), Color(pc, o), inner * 0.62, true)
			x += gap
	# bubbles
	var nb: int = s.bubbles
	if nb > 0:
		var bc: Color = s.bubble_color
		var span := maxf(1.0, b - a)
		for k in nb:
			var r0 := MK.rand(k * 7.31 + L)
			var pos := a + fposmod(r0 * span + float(s.flow) * float(s.bubble_speed) * (0.7 + 0.6 * MK.rand(k * 3.7)), span)
			var c := _point(p, pos)
			var t := (_point(p, pos + 1.0) - _point(p, pos - 1.0)).normalized()
			var off := Vector2(-t.y, t.x) * (MK.rand(k * 1.9 + 4.0) - 0.5) * inner * 0.5
			var rad := inner * (0.10 + 0.12 * MK.rand(k * 5.3))
			draw_arc(c + off, rad, 0.0, TAU, 12, Color(bc, bc.a * o), maxf(1.0, rad * 0.45), true)
	# a bright bead at the travelling front
	var fg: float = s.front_glow
	if fg > 0.0 and b < L - 0.5:
		var c2 := _point(p, b)
		draw_circle(c2, inner * 1.2, Color(fluid, 0.25 * fg * o))
		draw_circle(c2, inner * 0.55, Color(Color.WHITE, 0.9 * fg * o))


# ------------------------------------------------------------ geometry

## A path through `pts` with each corner replaced by a smooth arc of radius `r`
## (clamped to half the shorter neighbouring leg), sampled with `seg` points.
static func rounded(pts: PackedVector2Array, r: float, seg := 10) -> PackedVector2Array:
	if pts.size() < 3 or r <= 0.0:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var b := pts[i]
		var c := pts[i + 1]
		var d1 := (a - b).normalized()
		var d2 := (c - b).normalized()
		var ang := absf(d1.angle_to(d2))
		if ang > PI - 0.01:   # straight through
			out.append(b)
			continue
		var t := minf(r / tan(ang * 0.5), minf(a.distance_to(b), b.distance_to(c)) * 0.5)
		var p1 := b + d1 * t
		var p2 := b + d2 * t
		for k in seg + 1:
			var u := float(k) / seg
			out.append(p1.lerp(b, u).lerp(b.lerp(p2, u), u))
	out.append(pts[pts.size() - 1])
	return out


static func _cumulative(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(pts.size())
	var acc := 0.0
	cum[0] = 0.0
	for i in range(1, pts.size()):
		acc += pts[i - 1].distance_to(pts[i])
		cum[i] = acc
	return cum


static func _index(cum: PackedFloat32Array, s: float) -> int:
	var i := cum.bsearch(s, true) - 1
	return clampi(i, 0, cum.size() - 2)


static func _point(p: Dictionary, s: float) -> Vector2:
	var pts: PackedVector2Array = p.points
	var cum: PackedFloat32Array = p.cum
	if pts.size() == 1:
		return pts[0]
	s = clampf(s, 0.0, float(p.length))
	var i := _index(cum, s)
	var seg := cum[i + 1] - cum[i]
	var u := (s - cum[i]) / seg if seg > 0.0 else 0.0
	return pts[i].lerp(pts[i + 1], u)


## The piece of pipe `p` (an internal record) between arc lengths a and b px.
static func sub_path(p: Dictionary, a: float, b: float) -> PackedVector2Array:
	var pts: PackedVector2Array = p.points
	var cum: PackedFloat32Array = p.cum
	var out := PackedVector2Array()
	a = clampf(a, 0.0, float(p.length))
	b = clampf(b, 0.0, float(p.length))
	if b <= a:
		return out
	var ia := _index(cum, a)
	var ib := _index(cum, b)
	out.append(_point(p, a))
	for k in range(ia + 1, ib + 1):
		out.append(pts[k])
	out.append(_point(p, b))
	return out
