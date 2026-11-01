# SPDX-License-Identifier: Apache-2.0
# Geometry for the Night Circuit take: the circuit (a straight, an S-bend, a
# long straight toward the sun), an elevated skyway deck with barrier light
# strips, checkered pylons, checkered gantries and checker skyscrapers on an
# endless board. Merged into a few ArrayMeshes, one per material group, so the
# software-GL render stays cheap. Built once; the composition only moves the
# camera and sets material values.
# Emissive vertices carry their track distance in UV2.x (lit_to / lit_from
# chases; MotionTrack3D strips and quads); checker faces carry UVs in metres
# (MotionPattern3D.box / quad).
extends RefCounted

const DECK := 0.3            # deck height above the board (m)
const HALF_W := 7.0          # track half width
const WALL_H := 0.4
const S1 := 70.0             # first straight
const R := 130.0             # S-bend radius
const S2 := 1500.0           # final straight


## The circuit: a straight toward the sun, a right-left S-bend (45 degrees each
## way, banked), then a long straight toward the sun again.
static func circuit() -> Curve3D:
	var arc := R * PI * 0.25
	var segs := [[S1, 0.0], [arc, 1.0 / R], [arc, -1.0 / R], [S2, 0.0]]
	var pts: Array[Vector3] = [Vector3(0, DECK, 0)]
	var tilts: Array[float] = [0.0]
	var pos := Vector3(0, DECK, 0)
	var th := 0.0
	for sg in segs:
		var length: float = sg[0]
		var k: float = sg[1]
		var n := int(ceil(length / 10.0))
		var ds := length / n
		for i in n:
			th += k * ds * 0.5
			pos += Vector3(sin(th), 0.0, -cos(th)) * ds
			th += k * ds * 0.5
			pts.append(pos)
			tilts.append(0.28 * sin(PI * (i + 1) / n) * signf(k) if k != 0.0 else 0.0)
	return MotionTrack3D.circuit(pts, tilts, 0.17, 0.5)


# ------------------------------------------------------------------ the circuit

## Dark solids: deck, lane bands, barriers, underside.
static func track_solid(curve: Curve3D, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lane := Color("#241f46")
	var wall := Color("#0d0b1e")
	for x in [-2.4, 2.4]:
		MotionTrack3D.strip(st, curve, 0, length, x - 0.08, 0.01, x + 0.08, 0.01, lane)
	for sgn in [-1.0, 1.0]:
		var xi: float = sgn * HALF_W
		var xo: float = sgn * (HALF_W + 0.5)
		MotionTrack3D.strip(st, curve, 0, length, xi, 0, xi, WALL_H, wall)
		MotionTrack3D.strip(st, curve, 0, length, xo, -1.0, xo, WALL_H, wall)
		MotionTrack3D.strip(st, curve, 0, length, xi, WALL_H, xo, WALL_H, wall)
	MotionTrack3D.strip(st, curve, 0, length, -HALF_W - 0.5, -1.0, HALF_W + 0.5, -1.0, Color("#07061a"))
	return st.commit()


## The deck surface alone (for a pattern material in world XZ).
static func track_deck(curve: Curve3D, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MotionTrack3D.strip(st, curve, 0, length, -HALF_W, 0, HALF_W, 0, Color.WHITE)
	return st.commit()


## Checkered pylons under the deck, every 30 m (into a pattern SurfaceTool).
static func pylons(st: SurfaceTool, curve: Curve3D, length: float) -> void:
	var s := 12.0
	while s < length:
		var fr := MotionTrack3D.level_frame(curve, s)
		var h := fr.origin.y - 1.0
		MotionPattern3D.box(st, Transform3D(fr.basis, Vector3(fr.origin.x, h * 0.5, fr.origin.z)), Vector3(4.0, h, 2.0), Color(0.75, 0.7, 0.95), s)
		s += 30.0


## Emissive strips along the barriers and the deck edge, and the dashed centre line.
static func track_lights(curve: Curve3D, length: float, left: Color, right: Color, centre: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MotionTrack3D.strip(st, curve, 0, length, -HALF_W - 0.45, WALL_H + 0.02, -HALF_W - 0.05, WALL_H + 0.02, left)
	MotionTrack3D.strip(st, curve, 0, length, HALF_W + 0.05, WALL_H + 0.02, HALF_W + 0.45, WALL_H + 0.02, right)
	MotionTrack3D.strip(st, curve, 0, length, -HALF_W - 0.52, -0.9, -HALF_W - 0.52, -0.6, left.darkened(0.25))
	MotionTrack3D.strip(st, curve, 0, length, HALF_W + 0.52, -0.9, HALF_W + 0.52, -0.6, right.darkened(0.25))
	var s := 0.0
	while s < length - 4.0:
		MotionTrack3D.strip(st, curve, s, s + 3.0, -0.08, 0.02, 0.08, 0.02, centre * 0.35, 3.0)
		s += 9.0
	return st.commit()


## Chevron speed pads (three chevrons pointing along travel) at distances `at`.
static func pads(curve: Curve3D, at: Array, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s0 in at:
		var base: float = s0
		for k in 3:
			var s: float = base + k * 2.2
			var fr := MotionTrack3D.frame(curve, s, 0.03)
			var tip := fr * Vector3(0, 0, -3.2)
			var la := fr * Vector3(-2.0, 0, 0.4)
			var ra := fr * Vector3(2.0, 0, 0.4)
			var lb := fr * Vector3(-2.0, 0, 1.2)
			var rb := fr * Vector3(2.0, 0, 1.2)
			var mid := fr * Vector3(0, 0, -2.0)
			MotionTrack3D.quad(st, la, tip, mid, lb, col, base)
			MotionTrack3D.quad(st, tip, ra, rb, mid, col, base)
	return st.commit()


## A checkered gantry over the deck at s: two pylons standing on the board and
## a beam (checker faces into `checks`, tinted `tint`), with emissive edge
## strips into `lights` (chase value s). Returns the deck frame at s.
static func gantry(checks: SurfaceTool, lights: SurfaceTool, curve: Curve3D, s: float, half_span: float, beam_y: float, beam_h: float, tint: Color, col: Color) -> Transform3D:
	var fr := MotionTrack3D.frame(curve, s)
	var lv := MotionTrack3D.level_frame(curve, s)
	var b := lv.basis
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * half_span
		var foot := lv * Vector3(x, 0, 0)
		foot.y = 0.0
		var top := fr.origin.y + beam_y + beam_h
		MotionPattern3D.box(checks, Transform3D(b, foot + Vector3(0, top * 0.5, 0)), Vector3(1.6, top, 1.6), tint, s)
		MotionPattern3D.box(lights, Transform3D(b, foot + b * Vector3(-sgn * 0.84, 0, 0.84) + Vector3(0, top * 0.5, 0)), Vector3(0.12, top, 0.12), col, s)
	var beam_c := fr * Vector3(0, beam_y + beam_h * 0.5, 0)
	MotionPattern3D.box(checks, Transform3D(b, beam_c), Vector3(half_span * 2.0 + 1.6, beam_h, 1.2), tint, s)
	MotionPattern3D.box(lights, Transform3D(b, fr * Vector3(0, beam_y - 0.07, 0.62)), Vector3(half_span * 2.0 + 1.6, 0.14, 0.06), col, s)
	MotionPattern3D.box(lights, Transform3D(b, fr * Vector3(0, beam_y + beam_h + 0.07, 0.62)), Vector3(half_span * 2.0 + 1.6, 0.14, 0.06), col, s)
	return fr


## Checker skyscrapers either side of the circuit, standing on the board,
## turned to the circuit's heading. Bodies go into `checks` (vertex colour
## tints the light checks); a lit roof band per tower into `lights`.
## `clear(s)` is the half-width kept free around the circuit at s.
static func skyline(checks: SurfaceTool, lights: SurfaceTool, curve: Curve3D, length: float, clear: Callable, placed: Array, seed_v := 5.0, s_from := -60.0, spread := 150.0, gap := 18.0) -> void:
	var pale := [Color("#d8cff0"), Color("#c9d6f2"), Color("#efe6f5")]
	var accents := [FTFKit.PINK, FTFKit.CYAN, FTFKit.LIME, FTFKit.ORANGE, FTFKit.LILAC]
	var cell := 4.0
	var s := s_from
	var i := 0
	while s < length + 300.0:
		for sgn in [-1.0, 1.0]:
			i += 1
			if MK.rand(i * 1.37 + seed_v) < 0.1:
				continue
			var near: float = clear.call(s)
			var lateral: float = sgn * (near + 4.0 + pow(MK.rand(i * 5.1 + seed_v), 1.5) * spread)
			var lv := MotionTrack3D.level_frame(curve, s, lateral)
			var w := cell * (3.0 + floorf(MK.rand(i * 2.9 + seed_v) * 5.0))
			var d := cell * (3.0 + floorf(MK.rand(i * 2.3 + seed_v) * 5.0))
			var h := cell * floorf(5.0 + pow(MK.rand(i * 7.7 + seed_v), 1.4) * 32.0)
			var base := lv.origin
			base.y = 0.0
			# keep the circuit clear (the S-bend brings other parts of it close)
			var cp := curve.get_closest_point(base)
			var flat := Vector2(cp.x - base.x, cp.z - base.z).length()
			if flat < near + maxf(w, d) * 0.75:
				continue
			var rad := maxf(w, d) * 0.72
			var hit := false
			for pl: Vector3 in placed:
				if Vector2(pl.x - base.x, pl.z - base.z).length() < pl.y + rad:
					hit = true
					break
			if hit:
				continue
			placed.append(Vector3(base.x, rad, base.z))
			var acc := MK.rand(i * 9.1 + seed_v) < 0.3
			var tint: Color = accents[int(MK.rand(i * 4.7 + seed_v) * accents.size()) % accents.size()] if acc else pale[i % pale.size()]
			MotionPattern3D.box(checks, Transform3D(lv.basis, base + Vector3(0, h * 0.5, 0)), Vector3(w, h, d), tint, s, tint.darkened(0.5))
			var rim: Color = tint if acc else accents[int(MK.rand(i * 3.1 + seed_v) * accents.size()) % accents.size()]
			MotionPattern3D.box(lights, Transform3D(lv.basis, base + Vector3(0, h + 0.3, 0)), Vector3(w + 0.5, 0.6, d + 0.5), rim, s)
			if MK.rand(i * 6.3 + seed_v) < 0.5:
				MotionPattern3D.box(lights, Transform3D(lv.basis, base + Vector3(0, h * (0.35 + 0.4 * MK.rand(i * 8.8)), 0)), Vector3(w + 0.4, 0.35, d + 0.4), rim.darkened(0.2), s)
		s += gap + MK.rand(s * 0.13 + seed_v) * gap * 0.9


