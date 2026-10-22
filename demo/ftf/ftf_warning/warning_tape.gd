# SPDX-License-Identifier: Apache-2.0
# Hazard tape along any path, for the FTF Warning take: a ribbon with stripes
# laid out in path space (they follow every bend), square or torn ends, and a
# whip wave that runs down the tape as it is thrown in. Paths share
# MotionTextPath's arc-length model, so text on the tape lines up with it.
#
# A tape is a Dictionary spec evaluated per frame by `pose(spec, f)` (pure), then
# drawn into a MotionCanvas by `draw(c, spec, pose)`. Spec keys:
#   a, b          straight tape from a to b (both usually off screen), or
#   pts, closed   any polyline
#   width         px
#   style         "stripes", "solid" or "text" (solid body, text drawn by a
#                 MotionTextPath that follows the same pose)
#   col_a, col_b  body and stripe colours; edge: colour of thin edge lines (text tapes)
#   period, duty, slant   stripe repeat (px along the path), share of it that is
#                 col_b, and the stripe lean (px the far edge runs ahead)
#   scroll        stripes' speed along the path, px/frame
#   at, dur       the head runs from the start to the end over dur frames from at
#                 (ease out: a throw); dur 0 = already laid
#   out_at, out_dur, out  exit: "follow" (the tail runs off the far end),
#                 "back" (the head runs back to the start), "tear" (split at
#                 tear (0..1 of the length); both halves snap back to their ends)
#   wave_amp, wave_len, wave_decay, wave_speed   the whip wave (px, px, frames, px/frame)
extends RefCounted


## Path points and lengths at frame f, with the whip wave applied.
static func path(spec: Dictionary, f: float) -> Dictionary:
	var pts: PackedVector2Array
	var closed: bool = spec.get("closed", false)
	if spec.has("pts"):
		pts = spec.pts
	else:
		var a: Vector2 = spec.a
		var b: Vector2 = spec.b
		var n := maxi(2, int(a.distance_to(b) / 24.0) + 1)
		pts = PackedVector2Array()
		pts.resize(n)
		for i in n:
			pts[i] = a.lerp(b, float(i) / float(n - 1))
	var amp: float = spec.get("wave_amp", 0.0)
	if amp > 0.0 and not closed:
		var t := f - float(spec.get("at", 0.0))
		if t > 0.0:
			var decay: float = spec.get("wave_decay", 14.0)
			var wl: float = spec.get("wave_len", 700.0)
			var sp: float = spec.get("wave_speed", 60.0)
			var k := amp * exp(-t / decay)
			if k > 0.05:
				var d := (pts[pts.size() - 1] - pts[0]).normalized()
				var nrm := Vector2(-d.y, d.x)
				var acc := 0.0
				var out := PackedVector2Array()
				out.resize(pts.size())
				for i in pts.size():
					if i > 0:
						acc += pts[i - 1].distance_to(pts[i])
					# fixed at the start, free at the head: a throw
					var env := clampf(acc / 300.0, 0.0, 1.0)
					out[i] = pts[i] + nrm * k * env * sin(TAU * (acc - sp * t) / wl)
				pts = out
	var lengths := MotionTextPath.path_lengths(pts, closed)
	return {pts = pts, lengths = lengths, closed = closed, total = lengths[lengths.size() - 1]}


## The visible pieces of the tape at frame f: [{from, to, torn_start, torn_end}], in px.
static func pieces(spec: Dictionary, total: float, f: float) -> Array:
	var at: float = spec.get("at", 0.0)
	var dur: float = spec.get("dur", 0.0)
	if f < at:
		return []
	var head := total
	if dur > 0.0:
		head = total * MK.map(f, [at, at + dur], [0, 1], MK.ease_out)
	var tail := 0.0
	var out: String = spec.get("out", "")
	var out_at: float = spec.get("out_at", 1e9)
	var out_dur: float = spec.get("out_dur", 8.0)
	if out != "" and f >= out_at:
		var u := MK.map(f, [out_at, out_at + out_dur], [0, 1], MK.ease_in_quad)
		match out:
			"follow":
				tail = head * u
			"back":
				head = head * (1.0 - u)
			"tear":
				var tp: float = total * float(spec.get("tear", 0.5))
				var snap := MK.map(f, [out_at, out_at + out_dur], [0, 1], MK.ease_out)
				var l_end := tp * (1.0 - snap)
				var r_start := tp + (head - tp) * snap
				var res := []
				if l_end > 2.0:
					res.append({from = 0.0, to = l_end, torn_start = false, torn_end = true})
				if head - r_start > 2.0:
					res.append({from = r_start, to = head, torn_start = true, torn_end = false})
				return res
	if head - tail <= 1.0:
		return []
	return [{from = tail, to = head, torn_start = false, torn_end = false}]


## Pose for drawing: path + pieces.
static func pose(spec: Dictionary, f: float) -> Dictionary:
	var p := path(spec, f)
	p.pieces = pieces(spec, p.total, f)
	return p


static func _edge(p: Dictionary, s: float, side: float) -> Vector2:
	var pts: PackedVector2Array = p.pts
	var lengths: PackedFloat32Array = p.lengths
	var t := MotionTextPath.path_tangent(pts, lengths, p.closed, s, 10.0)
	return MotionTextPath.path_point(pts, lengths, p.closed, s) + Vector2(-t.y, t.x) * side


## Points along one edge between arc lengths s0 and s1 (side = signed half width).
static func _edge_run(p: Dictionary, s0: float, s1: float, side: float, step := 20.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(1, int(absf(s1 - s0) / step))
	for i in n + 1:
		out.append(_edge(p, lerpf(s0, s1, float(i) / float(n)), side))
	return out


static func _ribbon(c: MotionCanvas, p: Dictionary, s0: float, s1: float, w: float, col: Color, opacity := 1.0) -> void:
	if s1 - s0 < 0.5:
		return
	var left := _edge_run(p, s0, s1, -w * 0.5)
	var right := _edge_run(p, s1, s0, w * 0.5)
	c.polygon(left + right, col, Color(0, 0, 0, 0), 0.0, opacity)


## A ragged end: a zigzag across the tape, `len` px deep, at s, facing `dir` (+1 = towards the head).
static func _torn(c: MotionCanvas, p: Dictionary, s: float, dir: float, w: float, col: Color, seed_v: float, length := 26.0) -> void:
	var poly := PackedVector2Array()
	poly.append(_edge(p, s, -w * 0.5))
	var n := 7
	for i in range(1, n):
		var u := float(i) / float(n)
		var depth := length * (0.25 + 0.75 * MK.rand(seed_v + i * 3.7))
		var base_s := s + dir * depth
		var side := lerpf(-w * 0.5, w * 0.5, u)
		poly.append(_edge(p, base_s, side))
	poly.append(_edge(p, s, w * 0.5))
	c.polygon(poly, col, Color(0, 0, 0, 0))


static func draw(c: MotionCanvas, spec: Dictionary, p: Dictionary, f: float, opacity := 1.0) -> void:
	var w: float = spec.get("width", 80.0)
	var col_a: Color = spec.get("col_a", Color("#ffd400"))
	var col_b: Color = spec.get("col_b", Color("#0b0b0c"))
	var style: String = spec.get("style", "stripes")
	var seed_v: float = spec.get("seed", 1.0)
	for pc in p.pieces:
		var s0: float = pc.from
		var s1: float = pc.to
		_ribbon(c, p, s0, s1, w, col_a, opacity)
		if pc.torn_end:
			_torn(c, p, s1, 1.0, w, col_a, seed_v + 11.0)
		if pc.torn_start:
			_torn(c, p, s0, -1.0, w, col_a, seed_v + 29.0)
		match style:
			"stripes":
				_stripes(c, spec, p, s0, s1, w, col_b, f, opacity)
			"text":
				var e: Color = spec.get("edge", col_b)
				var ew: float = spec.get("edge_w", 4.0)
				var inset: float = spec.get("edge_inset", 7.0)
				_ribbon_offset(c, p, s0, s1, -w * 0.5 + inset, ew, e, opacity)
				_ribbon_offset(c, p, s0, s1, w * 0.5 - inset, ew, e, opacity)


static func _ribbon_offset(c: MotionCanvas, p: Dictionary, s0: float, s1: float, off: float, w: float, col: Color, opacity: float) -> void:
	if s1 - s0 < 0.5:
		return
	var left := _edge_run(p, s0, s1, off - w * 0.5)
	var right := _edge_run(p, s1, s0, off + w * 0.5)
	c.polygon(left + right, col, Color(0, 0, 0, 0), 0.0, opacity)


static func _stripes(c: MotionCanvas, spec: Dictionary, p: Dictionary, s0: float, s1: float, w: float, col: Color, f: float, opacity: float) -> void:
	var period: float = spec.get("period", 70.0)
	var duty: float = spec.get("duty", 0.5)
	var slant: float = spec.get("slant", w * 0.5)
	var shift: float = float(spec.get("scroll", 0.0)) * f
	var k0 := floori((s0 - absf(slant) - shift) / period) - 1
	var k1 := ceili((s1 + absf(slant) - shift) / period) + 1
	for k in range(k0, k1 + 1):
		var a := shift + k * period
		var b := a + period * duty
		var la := clampf(a - slant, s0, s1)
		var lb := clampf(b - slant, s0, s1)
		var ra := clampf(a + slant, s0, s1)
		var rb := clampf(b + slant, s0, s1)
		if lb - la < 0.3 and rb - ra < 0.3:
			continue
		var poly := PackedVector2Array()
		if lb - la >= 0.3:
			poly.append_array(_edge_run(p, la, lb, -w * 0.5, 24.0))
		else:
			poly.append(_edge(p, la, -w * 0.5))
		if rb - ra >= 0.3:
			poly.append_array(_edge_run(p, rb, ra, w * 0.5, 24.0))
		else:
			poly.append(_edge(p, ra, w * 0.5))
		if poly.size() >= 3:
			c.polygon(poly, col, Color(0, 0, 0, 0), 0.0, opacity)


## A closed rounded rectangle as a polyline (clockwise from the top-left
## corner's end), for frames of tape.
static func rounded_rect(r: Rect2, radius: float, seg := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI * 0.5],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	out.append(Vector2(r.position.x + radius, r.position.y))
	for cc in cs:
		var cen: Vector2 = cc[0]
		var a0: float = cc[1]
		for i in seg + 1:
			var a := a0 + PI * 0.5 * float(i) / float(seg)
			out.append(cen + Vector2(cos(a), sin(a)) * radius)
	return out
