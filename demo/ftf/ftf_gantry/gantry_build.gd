# SPDX-License-Identifier: Apache-2.0
# Geometry for the Gantry take: the circuit curve, track, barriers, light
# strips, chevron pads, pylons, gantries, tunnel and a skyline, all merged into
# a few ArrayMeshes (one per material group) so the software-GL render stays
# cheap. Built once; the composition only moves the camera and material values.
# Every emissive vertex carries its track distance in UV2.x, so a material's
# lit_to / lit_from run light chases along the circuit.
extends RefCounted

const HALF_W := 7.0          # track half width (m)
const WALL_H := 0.9
const DECK := -0.6           # underside of the deck
const FLOOR_Y := -60.0       # city floor


## The circuit: a straight, a 90 degree banked left-hander climbing a little,
## then a long straight. `straight` is the first straight's length.
static func circuit(straight: float, radius := 150.0) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 0.5
	var pts: Array[Vector3] = []
	var tilts: Array[float] = []
	var n0 := int(ceil(straight / 20.0))
	for i in n0:
		pts.append(Vector3(0, 0, -straight * i / n0))
		tilts.append(0.0)
	var centre := Vector3(-radius, 0, -straight)
	for k in 13:
		var t := k / 12.0
		var a := t * PI * 0.5
		pts.append(centre + Vector3(radius * cos(a), 4.0 * sin(PI * t), -radius * sin(a)))
		tilts.append(-0.34 * sin(PI * t))
	var exit := centre + Vector3(0, 0, -radius)
	for i in range(1, 36):
		pts.append(exit + Vector3(-20.0 * i, 0, 0))
		tilts.append(0.0)
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var h := (next - prev) * 0.17
		c.add_point(pts[i], -h if i > 0 else Vector3.ZERO, h if i < pts.size() - 1 else Vector3.ZERO)
		c.set_point_tilt(i, tilts[i])
	return c


static func frame_at(curve: Curve3D, s: float, height := 0.0, side := 0.0) -> Transform3D:
	return MotionStage3D.path_frame(curve, s, height, side)


# ------------------------------------------------------------------ primitives

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv2x: float) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_uv2(Vector2(uv2x, 0))
		st.add_vertex(v)


## A box of `size` centred at xform's origin, oriented by its basis.
static func box(st: SurfaceTool, xform: Transform3D, size: Vector3, col: Color, uv2x := 0.0, top: Color = Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return xform * Vector3(x * h.x, y * h.y, z * h.z)
	var tc := top if top.a > 0.0 else col
	quad(st, p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), tc, uv2x)
	quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), col, uv2x)
	quad(st, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col, uv2x)
	quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), col, uv2x)
	quad(st, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col, uv2x)
	quad(st, p.call(1, -1, -1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), col, uv2x)


## A strip following the curve between lateral offsets x0..x1 at height y
## (or a vertical strip when y0 != y1 at one offset).
static func strip(st: SurfaceTool, curve: Curve3D, s0: float, s1: float, x0: float, y0: float, x1: float, y1: float, col: Color, step := 2.0) -> void:
	var s := s0
	var prev_a := Vector3.ZERO
	var prev_b := Vector3.ZERO
	var first := true
	while true:
		var fr := frame_at(curve, s)
		var a := fr * Vector3(x0, y0, 0)
		var b := fr * Vector3(x1, y1, 0)
		if not first:
			quad(st, prev_a, prev_b, b, a, col, s)
		prev_a = a
		prev_b = b
		first = false
		if s >= s1:
			break
		s = minf(s + step, s1)


# ------------------------------------------------------------------ the world

## Dark solids: deck, barriers, pylons.
static func track_solid(curve: Curve3D, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := Color("#141832")
	var lane := Color("#1d2244")
	var wall := Color("#0c0f22")
	strip(st, curve, 0, length, -HALF_W, 0, HALF_W, 0, deck)
	for x in [-2.4, 2.4]:   # faint lane bands
		strip(st, curve, 0, length, x - 0.08, 0.01, x + 0.08, 0.01, lane)
	for sgn in [-1.0, 1.0]:
		var xi: float = sgn * HALF_W
		var xo: float = sgn * (HALF_W + 0.5)
		strip(st, curve, 0, length, xi, 0, xi, WALL_H, wall)
		strip(st, curve, 0, length, xo, DECK, xo, WALL_H, wall)
		strip(st, curve, 0, length, xi, WALL_H, xo, WALL_H, wall)
	strip(st, curve, 0, length, -HALF_W - 0.5, DECK, HALF_W + 0.5, DECK, Color("#07081a"))
	# pylons down to the city floor
	var s := 15.0
	while s < length:
		var fr := frame_at(curve, s)
		var top := fr.origin + Vector3(0, DECK, 0)
		var h := top.y - FLOOR_Y
		box(st, Transform3D(Basis(fr.basis.get_rotation_quaternion()), top - Vector3(0, h * 0.5, 0)).orthonormalized(), Vector3(3.0, h, 2.0), Color("#0b0d1e"))
		s += 34.0
	return st.commit()


## Emissive strips along the barriers and under the deck edge (chase on UV2.x = s).
static func track_lights(curve: Curve3D, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	strip(st, curve, 0, length, -HALF_W - 0.45, WALL_H + 0.02, -HALF_W - 0.05, WALL_H + 0.02, FTFKit.PINK)
	strip(st, curve, 0, length, HALF_W + 0.05, WALL_H + 0.02, HALF_W + 0.45, WALL_H + 0.02, FTFKit.CYAN)
	strip(st, curve, 0, length, -HALF_W - 0.52, DECK + 0.1, -HALF_W - 0.52, DECK + 0.3, FTFKit.PINK.darkened(0.2))
	strip(st, curve, 0, length, HALF_W + 0.52, DECK + 0.1, HALF_W + 0.52, DECK + 0.3, FTFKit.CYAN.darkened(0.2))
	# dashed centre line: short lime dashes
	var s := 0.0
	while s < length - 4.0:
		strip(st, curve, s, s + 3.0, -0.07, 0.02, 0.07, 0.02, FTFKit.LIME * 0.22, 3.0)
		s += 9.0
	return st.commit()


## Chevron speed pads (three chevrons pointing along travel) at distances `at`.
static func pads(curve: Curve3D, at: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s0 in at:
		var base: float = s0
		for k in 3:
			var s: float = base + k * 2.2
			var fr := frame_at(curve, s, 0.03)
			var tip := fr * Vector3(0, 0, -3.2)
			var la := fr * Vector3(-2.0, 0, 0.4)
			var ra := fr * Vector3(2.0, 0, 0.4)
			var lb := fr * Vector3(-2.0, 0, 1.2)
			var rb := fr * Vector3(2.0, 0, 1.2)
			var mid := fr * Vector3(0, 0, -2.0)
			quad(st, la, tip, mid, lb, FTFKit.LIME, base)
			quad(st, tip, ra, rb, mid, FTFKit.LIME, base)
	return st.commit()


## A gantry frame over the track at s: two pylons and a beam, with emissive
## edge strips added to `lights` (chase value s).
static func gantry(solid: SurfaceTool, lights: SurfaceTool, curve: Curve3D, s: float, half_span: float, beam_y: float, beam_h: float, col: Color) -> Transform3D:
	var fr := frame_at(curve, s)
	var b := Basis(fr.basis.get_rotation_quaternion())
	var dark := Color("#0d1026")
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * half_span
		box(solid, Transform3D(b, fr * Vector3(x, (beam_y + beam_h + DECK) * 0.5, 0)), Vector3(1.2, beam_y + beam_h - DECK, 1.2), dark)
		box(lights, Transform3D(b, fr * Vector3(x - sgn * 0.62, (beam_y + beam_h) * 0.5, 0.2)), Vector3(0.12, beam_y + beam_h, 0.12), col, s)
	box(solid, Transform3D(b, fr * Vector3(0, beam_y + beam_h * 0.5, 0)), Vector3(half_span * 2.0 + 1.2, beam_h, 1.0), dark)
	box(lights, Transform3D(b, fr * Vector3(0, beam_y - 0.06, 0.52)), Vector3(half_span * 2.0 + 1.2, 0.12, 0.06), col, s)
	box(lights, Transform3D(b, fr * Vector3(0, beam_y + beam_h + 0.06, 0.52)), Vector3(half_span * 2.0 + 1.2, 0.12, 0.06), col, s)
	return fr


## A tunnel shell from s0 to s1 with light rings every `gap` metres.
static func tunnel(solid: SurfaceTool, lights: SurfaceTool, curve: Curve3D, s0: float, s1: float, gap := 6.0) -> void:
	var shell := Color("#090b1c")
	strip(solid, curve, s0, s1, -HALF_W - 1.5, -0.2, -HALF_W - 1.5, 7.5, shell)
	strip(solid, curve, s0, s1, HALF_W + 1.5, -0.2, HALF_W + 1.5, 7.5, shell)
	strip(solid, curve, s0, s1, -HALF_W - 1.5, 7.5, HALF_W + 1.5, 7.5, shell)
	var s := s0
	var k := 0
	while s <= s1:
		var fr := frame_at(curve, s)
		var b := Basis(fr.basis.get_rotation_quaternion())
		var col := FTFKit.PINK if k % 2 == 0 else FTFKit.CYAN
		box(lights, Transform3D(b, fr * Vector3(0, 7.35, 0)), Vector3(HALF_W * 2.0 + 2.6, 0.18, 0.25), col, s)
		for sgn in [-1.0, 1.0]:
			box(lights, Transform3D(b, fr * Vector3(sgn * (HALF_W + 1.35), 3.6, 0)), Vector3(0.18, 7.6, 0.25), col, s)
		s += gap
		k += 1


## Skyline: dark towers either side of the circuit with lit floor bands.
## Returns [bodies, windows].
static func skyline(curve: Curve3D, length: float, seed_v := 3.0) -> Array:
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var win := SurfaceTool.new()
	win.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := [FTFKit.PINK, FTFKit.CYAN, FTFKit.LILAC, Color("#ffd27a"), FTFKit.CYAN]
	var s := 0.0
	var i := 0
	while s < length + 200.0:
		for sgn in [-1.0, 1.0]:
			var r := MK.rand(i * 3.7 + seed_v + sgn)
			var lateral: float = sgn * (36.0 + MK.rand(i * 5.1 + seed_v) * 140.0)
			var fr := frame_at(curve, s)
			var b := Basis(Vector3.UP, fr.basis.get_euler().y)
			var w := 14.0 + r * 26.0
			var d := 14.0 + MK.rand(i * 2.3 + seed_v) * 24.0
			var h := 40.0 + pow(MK.rand(i * 7.7 + seed_v), 1.6) * 150.0
			var base := fr * Vector3(lateral, 0, 0)
			base.y = FLOOR_Y
			box(body, Transform3D(b, base + Vector3(0, h * 0.5, 0)), Vector3(w, h, d), Color("#04050d"), s, Color("#0b0e26"))
			var c: Color = cols[int(MK.rand(i * 9.1 + seed_v) * cols.size()) % cols.size()]
			var bands := 2 + int(MK.rand(i * 4.4 + seed_v) * 5.0)
			for k in bands:
				var y := FLOOR_Y + h * (0.25 + 0.7 * MK.rand(i * 13.0 + k * 1.3 + seed_v))
				box(win, Transform3D(b, Vector3(base.x, y, base.z)), Vector3(w + 0.3, 0.5, d + 0.3), c.darkened(0.15 + 0.4 * MK.rand(k + i * 0.7)), s)
			box(win, Transform3D(b, Vector3(base.x, FLOOR_Y + h + 0.2, base.z)), Vector3(w + 0.4, 0.4, d + 0.4), c, s)
			i += 1
		s += 22.0 + MK.rand(s * 0.13 + seed_v) * 20.0
	return [body.commit(), win.commit()]


## A light-trail lane: a thin ribbon along the circuit at lateral offset x,
## to be lit as a moving window (a ship's trail) with lit_from / lit_to.
static func trail_lane(curve: Curve3D, length: float, x: float, y: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	strip(st, curve, 0, length, x - 0.35, y, x + 0.35, y, col, 1.0)
	strip(st, curve, 0, length, x, y - 0.25, x, y + 0.25, col, 1.0)
	return st.commit()
