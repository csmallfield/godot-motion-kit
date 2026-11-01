# SPDX-License-Identifier: Apache-2.0
# Geometry for the Canyon take: the MC-202 machine city of the Megastructure
# take rebuilt in real 3D with the kit's flat look (MotionFlat3D faces,
# MotionEdges3D outlines, MotionDecalAtlas markings). One builder collects
# every solid into one SurfaceTool per palette material, every outline into
# one edge mesh and every marking into two decal meshes (city / ground), so
# the whole city is about ten draw calls. Each object's vertices carry its
# ground anchor (UV2) so the city can pulse and sink in rings from the shader.
#
# Grid: cell (i, j) is centred on world (i, 0, -j) (x east, -z north, y up);
# every fifth row and column is a street one cell wide.
extends RefCounted

const MATS := {
	cream = [Color("#f8f4eb"), Color("#e6dfd0"), Color("#b7ae9e")],
	red = [Color("#f0453a"), Color("#d72c22"), Color("#901810")],
	black = [Color("#4b4b51"), Color("#2c2c31"), Color("#141417")],
	grey = [Color("#cfcdc6"), Color("#aeaca5"), Color("#7b7a75")],
}
const RED := Color("#e8322a")
const INK := Color("#141417")
const CREAM := Color("#f8f4eb")
const GROUND := Color("#dedad0")
const STREET := Color("#c9c5bb")

const MH_PLAZA := Rect2i(-7, -8, 15, 12)     # cells i -7..7, j -8..3
const FTF_PLAZA := Rect2i(5, 11, 9, 9)       # cells i 5..13, j 11..19
const CITY := Rect2i(-16, -50, 42, 80)
const INSET := 0.08
const DOFF := 0.012                          # decals sit this far off their face

var st := {}                                  # material name -> SurfaceTool
var edges := MotionEdges3D.new()
var decals := MotionFlat3D.begin()            # markings on moving objects
var ground_decals := MotionFlat3D.begin()     # markings on the ground (fixed)
var ground := MotionFlat3D.begin()            # ground and street surfaces (fixed)
var uv := {}                                  # atlas cell name -> Rect2
var aspect := {}                              # atlas cell name -> h / w
var cranes: Array[Dictionary] = []            # {pos, key, len, seed}
var tops := {}                                # Vector2i cell -> roof height
var _route: Array = []                        # [a: Vector2, b: Vector2] segments in grid coords
var _canyon := {}                             # Vector2i cells walling the route streets


static func w(gx: float, gy: float, h := 0.0) -> Vector3:
	return Vector3(gx, h, -gy)


static func key_of(gx: float, gy: float) -> Vector2:
	return Vector2(gx, -gy)


static func is_street(i: int, j: int) -> bool:
	return posmod(i, 5) == 0 or posmod(j, 5) == 0


static func rnd(i: int, j: int, k: float) -> float:
	return MK.rand(i * 13.13 + j * 71.7 + k * 5.31 + 0.7)


func _init() -> void:
	for m in MATS.keys():
		st[m] = MotionFlat3D.begin()


# ------------------------------------------------------------------ primitives

func box(mat: String, p: Vector3, size: Vector3, k: Vector2, outline := true) -> void:
	MotionFlat3D.box(st[mat], p, size, k, Color.WHITE, edges if outline else null)


func cyl(mat: String, base: Vector3, r: float, h: float, k: Vector2, seg := 12) -> void:
	MotionFlat3D.cylinder(st[mat], base, r, h, k, Color.WHITE, edges, seg)


func pipe(mat: String, a: Vector3, b: Vector3, r: float, k: Vector2, seg := 8) -> void:
	MotionFlat3D.pipe(st[mat], a, b, r, k, Color.WHITE, edges, seg)


## A decal of atlas cell `name`, `width` world units wide, centred at c with
## u along the artwork's x; v is up for walls, or given for flat decals.
func decal(name: String, c: Vector3, u: Vector3, width: float, k: Vector2, col: Color, v := Vector3.UP, on_ground := false) -> void:
	if not uv.has(name):
		return
	var a: float = aspect[name]
	var hu := u.normalized() * width * 0.5
	var hv := v.normalized() * width * 0.5 * a
	MotionFlat3D.decal(ground_decals if on_ground else decals, c, hu, hv, uv[name], k, col)


## A decal on a box face: face 0 south, 1 east, 2 north, 3 west; `cx` 0..1
## across the face (left to right seen from outside), `cy` height of the centre.
func face_decal(name: String, p: Vector3, size: Vector3, face: int, cx: float, cy: float, width: float, k: Vector2, col: Color) -> void:
	var c: Vector3
	var u: Vector3
	match face:
		0:
			c = Vector3(p.x + cx * size.x, cy, p.z + size.z + DOFF)
			u = Vector3.RIGHT
		1:
			c = Vector3(p.x + size.x + DOFF, cy, p.z + size.z - cx * size.z)
			u = Vector3.FORWARD
		2:
			c = Vector3(p.x + size.x - cx * size.x, cy, p.z - DOFF)
			u = Vector3.LEFT
		_:
			c = Vector3(p.x - DOFF, cy, p.z + cx * size.z)
			u = Vector3.BACK
	decal(name, c, u, width, k, col)


## A decal lying on a roof or the ground, artwork up = north rotated by `rot`.
func flat_decal(name: String, c: Vector3, width: float, k: Vector2, col: Color, rot := 0.0, on_ground := false) -> void:
	var u := Vector3.RIGHT.rotated(Vector3.UP, rot)
	var v := Vector3.FORWARD.rotated(Vector3.UP, rot)
	decal(name, c + Vector3(0, DOFF, 0), u, width, k, col, v, on_ground)


# ------------------------------------------------------------------ the route

## Route streets (grid segments) whose walls are tall canyons.
func set_route(segments: Array) -> void:
	_route = segments
	for sg in segments:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
		for t in n + 1:
			var p := a.lerp(b, float(t) / maxf(1.0, float(n)))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_canyon[Vector2i(roundi(p.x), roundi(p.y)) + d] = true


func _route_dist(p: Vector2) -> float:
	var best := 1e9
	for sg in _route:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


# ------------------------------------------------------------------ the city

func build_city() -> void:
	for j in range(CITY.position.y, CITY.end.y):
		for i in range(CITY.position.x, CITY.end.x):
			var c := Vector2i(i, j)
			if MH_PLAZA.has_point(c) or FTF_PLAZA.has_point(c):
				continue
			var p := Vector2(i, j)
			var near_route := _route_dist(p) < 9.5
			var near_iso := p.distance_to(Vector2(9, 15)) < 17.0
			var near_mh := p.distance_to(Vector2(0, -2)) < 14.0
			if not (near_route or near_iso or near_mh):
				continue
			if is_street(i, j):
				_street_cell(i, j)
			else:
				_cell(i, j)
	_ground_plane()


func _ground_plane() -> void:
	var r := Rect2(-120, -160, 260, 280)
	MotionFlat3D.quad(ground, Vector3(r.position.x, 0, r.end.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.end.x, 0, r.position.y),
		Vector3(r.position.x, 0, r.position.y), Vector3.UP, Vector2(1e4, 1e4), GROUND)


func _street_cell(i: int, j: int) -> void:
	var y := 0.003
	var a := w(i - 0.5, j - 0.5, y)
	var b := w(i + 0.5, j + 0.5, y)
	MotionFlat3D.quad(ground, Vector3(a.x, y, a.z), Vector3(b.x, y, a.z), Vector3(b.x, y, b.z), Vector3(a.x, y, b.z), Vector3.UP,
		Vector2(1e4, 1e4), Color(STREET.r / GROUND.r, STREET.g / GROUND.g, STREET.b / GROUND.b))
	var ns := posmod(i, 5) == 0       # a north-south street
	var ew := posmod(j, 5) == 0
	var k := Vector2(1e4, 1e4)
	if ns and ew:
		# intersection: crossing hatches on its four sides
		for d in [Vector2(0, 0.42), Vector2(0, -0.42)]:
			flat_decal("hatch_h", w(i + d.x, j + d.y, 0.004), 0.9, k, CREAM, 0.0, true)
		for d in [Vector2(0.42, 0), Vector2(-0.42, 0)]:
			flat_decal("hatch_h", w(i + d.x, j + d.y, 0.004), 0.9, k, CREAM, PI * 0.5, true)
	else:
		# a lane dash along the street, a chevron now and then
		var rot := 0.0 if ns else PI * 0.5
		flat_decal("dash", w(i, j, 0.004), 0.05, k, CREAM, rot, true)
		if rnd(i, j, 40) > 0.86:
			flat_decal("chev_up", w(i, j, 0.005), 0.5, k, RED if rnd(i, j, 41) > 0.5 else INK, rot, true)


func _pick(i: int, j: int, k: float) -> String:
	var r := rnd(i, j, k)
	if r < 0.40:
		return "cream"
	if r < 0.64:
		return "red"
	if r < 0.82:
		return "grey"
	return "black"


func _ink_on(mat: String) -> Color:
	return INK if mat in ["cream", "grey"] else CREAM


func _accent_on(mat: String) -> Color:
	return RED if mat != "red" else CREAM


func _cell(i: int, j: int) -> void:
	var k := key_of(i, j)
	var o := w(i - 0.5 + INSET, j + 0.5 - INSET)       # min corner (x min, z min = north edge)
	var fw := 1.0 - 2.0 * INSET
	var mat := _pick(i, j, 1)
	var r := rnd(i, j, 0)
	var canyon := _canyon.has(Vector2i(i, j))
	var front := (i - 9) + (15 - j) > 3 and Vector2(i, j).distance_to(Vector2(9, 15)) < 13.0
	var h_cap := 1.5 if front else 9.0
	if r < 0.05 and not canyon:
		return                                        # empty lot
	var top := 0.0
	if canyon or r < 0.34:
		# tower: shaft, set-back cap, antenna or a crane later
		var h := minf(h_cap, (2.0 if canyon else 1.6) + (2.8 if canyon else 2.4) * rnd(i, j, 4))
		box(mat, o, Vector3(fw, h, fw), k)
		_tower_decals(o, Vector3(fw, h, fw), mat, i, j, k)
		var cm := _pick(i, j, 6)
		var ch := 0.25 + 0.3 * rnd(i, j, 5)
		box(cm, o + Vector3(0.16, h, 0.16), Vector3(fw - 0.32, ch, fw - 0.32), k)
		top = h + ch
		if rnd(i, j, 7) > 0.6:
			cyl("black", o + Vector3(fw * 0.5, top, fw * 0.5), 0.035, 0.6, k, 6)
		elif rnd(i, j, 8) > 0.55:
			flat_decal("helipad", o + Vector3(fw * 0.5, top, fw * 0.5), fw - 0.42, k, _accent_on(cm))
	elif r < 0.6:
		# mid block with roof plant
		var h := minf(h_cap, 0.6 + 1.2 * rnd(i, j, 8))
		box(mat, o, Vector3(fw, h, fw), k)
		_block_decals(o, Vector3(fw, h, fw), mat, i, j, k)
		top = h
		if rnd(i, j, 9) > 0.45:
			var tr := 0.18 + 0.08 * rnd(i, j, 10)
			cyl("cream" if mat == "red" else "red", o + Vector3(0.36, h, 0.45), tr, 0.3 + 0.3 * rnd(i, j, 11), k)
		else:
			for q in 2:
				box("grey", o + Vector3(0.12 + q * 0.34, h, 0.2), Vector3(0.24, 0.16, 0.42), k)
				flat_decal("vent", o + Vector3(0.24 + q * 0.34, h + 0.16, 0.41), 0.2, k, INK)
	elif r < 0.76:
		# silos on a low deck
		box("grey", o, Vector3(fw, 0.12, fw), k)
		var sm := "cream" if rnd(i, j, 12) > 0.4 else "red"
		for q in 2:
			var sh := minf(h_cap, 0.9 + 1.0 * rnd(i, j, 13 + q))
			cyl(sm, o + Vector3(0.24 + q * 0.38, 0.12, 0.62 - q * 0.38), 0.18, sh, k, 14)
			top = maxf(top, sh + 0.12)
		flat_decal("circle", o + Vector3(0.24, 0.12 + minf(h_cap, 0.9 + rnd(i, j, 13)), 0.62), 0.24, k, INK)
	elif r < 0.88:
		# stepped stack
		var h1 := minf(h_cap, 0.5 + 0.8 * rnd(i, j, 15))
		box(mat, o, Vector3(fw, h1, fw), k)
		var m2 := _pick(i, j, 16)
		var h2 := minf(h_cap * 0.5, 0.4 + 0.9 * rnd(i, j, 17))
		box(m2, o + Vector3(0.0, h1, 0.0), Vector3(fw * 0.55, h2, fw * 0.55), k)
		face_decal("hazard", o, Vector3(fw, h1, fw), 0, 0.5, h1 - 0.08, fw, k, _accent_on(mat))
		top = h1 + h2
	else:
		# pipe rack on a plinth
		box("black", o + Vector3(0.1, 0, 0.36), Vector3(0.1, 0.9, 0.12), k)
		box("black", o + Vector3(fw - 0.2, 0, 0.36), Vector3(0.1, 0.9, 0.12), k)
		pipe("red", o + Vector3(-0.08, 0.6, 0.42), o + Vector3(fw + 0.08, 0.6, 0.42), 0.09, k)
		pipe("cream", o + Vector3(-0.08, 0.84, 0.42), o + Vector3(fw + 0.08, 0.84, 0.42), 0.07, k)
		top = 0.9
	tops[Vector2i(i, j)] = top
	# cranes on some towers around the FTF plaza
	if top > 2.2 and not front and Vector2(i, j).distance_to(Vector2(9, 15)) < 11.0 and rnd(i, j, 50) > 0.55 and cranes.size() < 6:
		cranes.append({pos = o + Vector3(fw * 0.5, top, fw * 0.5), key = k, len = 1.6 + 0.8 * rnd(i, j, 51), seed = float(i * 7 + j)})


const SERIALS := ["MX-150", "A3", "FTF-09", "B-7", "K45", "S07", "T23", "N-9000"]


func _tower_decals(o: Vector3, size: Vector3, mat: String, i: int, j: int, k: Vector2) -> void:
	var ink := _ink_on(mat)
	var acc := _accent_on(mat)
	for face in 4:
		var r := rnd(i, j, 20 + face)
		var kind := int(rnd(i, j, 30 + face) * 6.0)
		if r < 0.3:
			continue
		match kind:
			0:
				face_decal("ser%d" % int(rnd(i, j, 21) * 8.0), o, size, face, 0.5, size.y - 0.2, size.x * 0.8, k, ink)
				face_decal("solid", o, size, face, 0.5, size.y - 0.42, size.x, k, acc)
			1:
				face_decal("jp%d" % int(rnd(i, j, 22) * 7.0), o, size, face, 0.72, size.y - 0.75, 0.24, k, acc)
				face_decal("barcode", o, size, face, 0.3, size.y - 0.3, 0.3, k, ink)
			2:
				face_decal("circle", o, size, face, 0.5, size.y - 0.45, 0.46, k, acc)
				face_decal("ser%d" % int(rnd(i, j, 23) * 8.0), o, size, face, 0.5, size.y - 0.85, size.x * 0.6, k, ink)
			3:
				face_decal("chev_v", o, size, face, 0.5, size.y - 0.65, 0.26, k, acc)
			4:
				face_decal("num%d" % (1 + int(rnd(i, j, 24) * 6.0)), o, size, face, 0.5, size.y - 0.4, 0.5, k, acc)
			_:
				for b in 3:
					face_decal("solid", o, size, face, 0.5, size.y - 0.2 - b * 0.22, size.x, k, acc)
		if size.y > 2.0 and r > 0.7:
			face_decal("hazard", o, size, face, 0.5, 0.18, size.x, k, acc)


func _block_decals(o: Vector3, size: Vector3, mat: String, i: int, j: int, k: Vector2) -> void:
	var ink := _ink_on(mat)
	var acc := _accent_on(mat)
	for face in [0, 1]:
		var kind := int(rnd(i, j, 60 + face) * 4.0)
		match kind:
			0:
				face_decal("exit", o, size, face, 0.42, size.y * 0.6, 0.5, k, ink)
			1:
				face_decal("chev_h", o, size, face, 0.5, size.y * 0.55, 0.6, k, acc)
			2:
				face_decal("solid", o, size, face, 0.5, size.y - 0.1, size.x, k, acc)
			_:
				pass


# ------------------------------------------------------------------ street furniture

## A walkway across a street at grid point (gx, gy): `ns` true for a
## north-south street (the deck runs east-west), deck underside at h.
func walkway(gx: float, gy: float, ns: bool, h: float, mat: String) -> void:
	var k := key_of(gx, gy)
	var c := w(gx, gy)
	var across := 1.3
	var depth := 0.42
	var th := 0.14
	var size := Vector3(across, th, depth) if ns else Vector3(depth, th, across)
	var p := c + Vector3(-size.x * 0.5, h, -size.z * 0.5)
	box(mat, p, size, k)
	# railings along both long edges
	var rl := Vector3(across - 0.1, 0.14, 0.025) if ns else Vector3(0.025, 0.14, across - 0.1)
	for e in [0.0, depth - 0.025]:
		box("black", p + (Vector3(0.05, th, e) if ns else Vector3(e, th, 0.05)), rl, k)
	# hazard stripes on both deck sides facing along the street
	var acc := RED if mat != "red" else CREAM
	for face in ([0, 2] if ns else [1, 3]):
		face_decal("hazard", p, size, face, 0.5, h + th * 0.5, across - 0.1, k, acc)


## A pipe rack across a street at (gx, gy), lowest pipe at h.
func pipe_rack(gx: float, gy: float, ns: bool, h: float) -> void:
	var k := key_of(gx, gy)
	var c := w(gx, gy)
	var ax := Vector3.RIGHT if ns else Vector3.BACK
	var al := Vector3.BACK if ns else Vector3.RIGHT
	var half := 0.66
	var specs := [[0.0, 0.0, 0.06, "red"], [0.13, 0.1, 0.045, "cream"], [0.05, 0.26, 0.055, "grey"]]
	for sp in specs:
		var a: float = sp[0]
		var dy: float = sp[1]
		var r: float = sp[2]
		var base := c + al * (a - 0.06) + Vector3(0, h + dy + r, 0)
		pipe(sp[3], base - ax * half, base + ax * half, r, k)
	var beam := Vector3(half * 2.0, 0.05, 0.06) if ns else Vector3(0.06, 0.05, half * 2.0)
	box("black", c + Vector3(-beam.x * 0.5, h - 0.05, -beam.z * 0.5), beam, k)


## Long pipes along a canyon wall: from grid a to b at height h, offset `side`
## across the street from its centre line.
func wall_pipe(a: Vector2, b: Vector2, h: float, side: float, r: float, mat: String) -> void:
	var d := (b - a).normalized()
	var n := Vector2(d.y, -d.x)
	var pa := a + n * side
	var pb := b + n * side
	pipe(mat, w(pa.x, pa.y, h), w(pb.x, pb.y, h), r, key_of((pa.x + pb.x) * 0.5, (pa.y + pb.y) * 0.5), 8)


## A blade sign sticking out of a canyon wall with katakana on both sides.
func blade(gx: float, gy: float, ns: bool, side: float, h: float, mat: String, txt: String) -> void:
	var k := key_of(gx, gy)
	var c := w(gx, gy)
	var size := Vector3(0.26, 0.9, 0.04) if ns else Vector3(0.04, 0.9, 0.26)
	var out := side * 0.58 - (0.26 if side > 0.0 else 0.0)
	var p := c + (Vector3(out, h, -0.02) if ns else Vector3(-0.02, h, out))
	box(mat, p, size, k)
	var col := CREAM if mat in ["red", "black"] else RED
	for face in ([0, 2] if ns else [1, 3]):
		face_decal(txt, p, size, face, 0.5, h + 0.45, 0.17, k, col)
