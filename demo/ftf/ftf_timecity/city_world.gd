# SPDX-License-Identifier: Apache-2.0
# The Time City world: the isometric MC-202 machine city (after take 2,
# Megastructure), its Minimal Humans monument and the FTF logo slab, as one
# shared set of MotionSolids that any number of content instances pose at their
# own moment. MotionTimeSlices instances the content once per band; sharing the
# solids keeps that to one world in memory, and `pose(f, view)` culls to the
# band's strip of screen so each band only positions, sorts and draws what it
# shows. Posing is a pure function of (f, view): every draw re-poses when the
# last pose was for another band.
extends RefCounted

const L := preload("res://demo/ftf/ftf_timecity/time_look.gd")

const MATS := {
	cream = [Color("#f8f4eb"), Color("#e6dfd0"), Color("#b7ae9e")],
	red = [Color("#f0453a"), Color("#d72c22"), Color("#901810")],
	black = [Color("#4b4b51"), Color("#2c2c31"), Color("#141417")],
	grey = [Color("#cfcdc6"), Color("#aeaca5"), Color("#7b7a75")],
	platform = [Color("#dedad0"), Color("#25252a"), Color("#111114")],
	pink = [Color("#ff5b93"), Color("#d21b5c"), Color("#8c0f3b")],
}
const RED := L.RED
const INK := L.INK
const CREAM := L.CREAM

# ---- world layout (1 unit = one city cell)
const NX := 22
const NY := 12
const MH_PLAZA := Rect2i(0, 0, 11, 5)
const FTF_PLAZA := Rect2i(11, 0, 11, 5)
const MH_X := 1.6
const MH_Y := 3.4
const MH_WIDTH := 7.6
const FTF_X := 11.6
const FTF_Y := 3.3
const FTF_WIDTH := 9.6
const MH_SLAB := 0.22
const PED := 0.5
const LETTER_D := 0.32
const FTF_D := 0.6

var scene := MotionExtrude.new()
## The city plan (lots, kinds, parts) the cells are built from.
var plan := MotionCityPlan.new()
var cells: Array[Dictionary] = []
var platform: MotionSolid
var base_pipes: Array[MotionSolid] = []
var mh_slabs: Array[MotionSolid] = []
var mh_letters: Array[MotionSolid] = []
var plinth: MotionSolid
var backdrop: MotionSolid
var ftf: MotionSolid
var mh_h := 1.0
var ftf_h := 1.0
var mh_data: MotionSvgData
var ftf_data: MotionSvgData
var mh_on := false
var ftf_on := false
var active_y := MH_Y
var now := 0.0

var _font_mono: Font
var _font_wide: Font
var _font_jp: Font
var _pf := NAN
var _pv := Rect2()
var _special := {}


func _init() -> void:
	_font_mono = FTFKit.font("mono")
	_font_wide = FTFKit.font("wide")
	_font_jp = FTFKit.font("jp")
	mh_data = MotionSvgData.load_any("res://demo/assets/logos/mh_logoFull_standard.svg")
	ftf_data = MotionSvgData.load_any(FTFKit.LOGO)
	scene.min_decal_area = 900.0
	_build_world()
	for s in mh_slabs:
		_special[s] = true
	for s in mh_letters:
		_special[s] = true
	_special[plinth] = true
	_special[backdrop] = true
	_special[ftf] = true
	_special[platform] = true


# ================================================================== build

func _mat(s: MotionSolid, key: String, edge := true) -> MotionSolid:
	var m: Array = MATS[key]
	s.paint(m[0], m[1], m[2])
	if edge and key != "black":
		s.stroke(L.EDGE, 1.2)
	s.data.mat = key
	return s


func _r(cx: int, cy: int, k: float) -> float:
	return plan.rand(cx, cy, k)


func _build_world() -> void:
	platform = MotionSolid.box(Vector3(-0.7, -0.7, -1.5), Vector3(NX + 1.4, NY + 1.4, 1.5))
	_mat(platform, "platform", false)
	platform.sort_key = 1e9
	platform.draw_front_cap = true
	platform.add_decal(Vector3(0, -1, 0), _dec(func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _platform_face(c, sz, xf)))
	platform.add_decal(Vector3(1, 0, 0), _dec(func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _platform_east(c, sz, xf)))
	for k in 2:
		var p := MotionSolid.pipe(Vector3(-0.7, -0.84 - k * 0.1, -1.0 - k * 0.26), 0.11 - k * 0.02, NX + 1.4)
		_mat(p, "red" if k == 0 else "cream")
		p.sort_key = -1e9 + k
		p.layer = 1
		base_pipes.append(p)
		scene.add(p)
	# The Megastructure city grammar (MotionCityPlan defaults) with this
	# take's coarser cylinders and pipes.
	plan.grid = Rect2i(0, 0, NX, NY)
	plan.skip = [MH_PLAZA]
	plan.shape = {tank_seg = 12, silo_seg = 12, pipe_seg = 10}
	plan.prepare = func(cell: Dictionary) -> void:
		if cell.j <= 1:
			cell.force = "low"
	for pc in plan.build():
		_build_cell(pc)

	var mk := MH_WIDTH / mh_data.view_box.size.x
	mh_h = mh_data.view_box.size.y * mk
	for i in 3:
		var s := MotionSolid.from_svg(mh_data, i, mk, Vector3(MH_X, MH_Y, mh_h), Vector3.RIGHT, Vector3(0, 0, 1), MH_SLAB)
		var col: Color = mh_data.parts[i].fill
		s.paint(col.lightened(0.15), col.darkened(0.18), col.darkened(0.45))
		s.clip_z = PED
		mh_slabs.append(s)
	for i in range(3, 16):
		var s := MotionSolid.from_svg(mh_data, i, mk, Vector3(MH_X, MH_Y, mh_h), Vector3.RIGHT, Vector3(0, 0, 1), LETTER_D)
		s.paint(Color("#fbf7ef"), Color("#cfc6b4"), Color("#8f8676"))
		s.clip_z = PED
		mh_letters.append(s)
	backdrop = MotionSolid.new()
	backdrop.set_outline(MotionSolid.rect_pts(MH_WIDTH + 1.2, 2.75))
	backdrop.origin = Vector3(MH_X - 0.6, MH_Y + 1.35, 0.0)
	backdrop.u = Vector3.RIGHT
	backdrop.v = Vector3(0, 0, 1)
	backdrop.depth = 0.3
	_mat(backdrop, "black")
	backdrop.clip_z = 0.0
	backdrop.add_decal("front", _dec(func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _backdrop_face(c, sz, xf)))
	plinth = MotionSolid.box(Vector3(MH_X - 0.25, MH_Y - 0.75, 0.0), Vector3(MH_WIDTH + 0.5, 1.45, PED))
	_mat(plinth, "black")
	plinth.clip_z = 0.0
	plinth.add_decal(Vector3(0, -1, 0), _dec(func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _presents(c, sz, xf)))

	var fk := FTF_WIDTH / ftf_data.view_box.size.x
	ftf_h = ftf_data.view_box.size.y * fk
	ftf = MotionSolid.from_svg(ftf_data, FTFKit.RIM, fk, Vector3(FTF_X, FTF_Y, ftf_h), Vector3.RIGHT, Vector3(0, 0, 1), FTF_D)
	_mat(ftf, "pink")
	ftf.clip_z = 0.0


func _in_rect(r: Rect2i, cx: int, cy: int) -> bool:
	return r.has_point(Vector2i(cx, cy))


func _build_cell(pc: Dictionary) -> void:
	var parts: Array = pc.parts
	if parts.is_empty():
		return
	var cx: int = pc.i
	var cy: int = pc.j
	var cell := {cx = cx, cy = cy, solids = [], rest = [], top = 0.0, ftf = _in_rect(FTF_PLAZA, cx, cy)}
	var sol := plan.solids(pc, _mat)
	for n in sol.size():
		var s := sol[n]
		var part: Dictionary = parts[n]
		match part.role:
			"shaft":
				if pc.kind == "tower":
					_tower_decals(s, cx, cy)
				elif pc.kind == "block":
					_block_decals(s, cx, cy)
			"silo":
				if part.stack == 1:
					s.add_decal("front", _dec(func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, _xf: Transform2D) -> void:
						c.draw_circle(sz * 0.5, sz.x * 0.28, INK)))
			"ramp":
				s.add_decal("front", _dec(func(c: MotionCanvas, sz: Vector2, so: MotionSolid, _xf: Transform2D) -> void:
					MotionMarks.chevron_row(c, Vector2(8, sz.y - 22), 3, 14, CREAM if so.data.mat == "red" else RED)))
		s.clip_z = 0.0
		s.stack = part.stack
		s.sort_at = Vector3(cx + 0.5, cy + 0.5, 0.0)
		s.data.cell = Vector2(cx + 0.5, cy + 0.5)
		cell.solids.append(s)
		cell.rest.append(s.origin.z)
		cell.top = maxf(cell.top, s.origin.z + (s.depth if s.normal().z > 0.5 else 0.6))
	for s in cell.solids:
		scene.add(s)
	var top: float = cell.top
	cell.c = Vector3(cx + 0.5, cy + 0.5, top * 0.5)
	cell.h = Vector3(0.62, 0.62, top * 0.55 + 0.1)
	cell.p = Vector2(cx + 0.5, cy + 0.5)
	cell.d_mh = (cell.p as Vector2).distance_to(Vector2(MH_X + MH_WIDTH * 0.5, 2.0))
	cell.d_ftf = (cell.p as Vector2).distance_to(Vector2(FTF_X + FTF_WIDTH * 0.5, 1.5))
	cells.append(cell)


## Wrap a decal so it skips drawing when its face is outside the posed view.
func _dec(fn: Callable) -> Callable:
	return func(c: MotionCanvas, sz: Vector2, s: MotionSolid, xf: Transform2D) -> void:
		if _pv.has_area() and not (xf * Rect2(Vector2.ZERO, sz)).intersects(_pv):
			return
		fn.call(c, sz, s, xf)


func _tower_decals(b: MotionSolid, cx: int, cy: int) -> void:
	var kind := int(_r(cx, cy, 20) * 4.0)
	var serial: String = ["MX-150", "A3", "FTF-09", "B-7", "K45", "S07", "T23", "N-9000"][int(_r(cx, cy, 21) * 8.0)]
	var jp: String = ["全開", "流束", "反重力", "第一", "起動", "信号", "機体"][int(_r(cx, cy, 22) * 7.0)]
	var accent := RED if b.data.mat != "red" else CREAM
	var ink := INK if b.data.mat in ["cream", "grey"] else CREAM
	b.add_decal(Vector3(0, -1, 0), _dec(_tower_face.bind(kind, serial, jp, accent, ink)))


func _tower_face(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D, kind: int, serial: String, jp: String, accent: Color, ink: Color) -> void:
	match kind:
		0:
			for j in 3:
				c.draw_rect(Rect2(0, 24 + j * 22, sz.x, 9), accent)
			_txt(c, xf, _font_mono, Vector2(8, sz.y - 14), serial, 13, ink)
		1:
			_txt(c, xf * Transform2D(-PI / 2, Vector2(sz.x - 12, sz.y - 10)), _font_wide, Vector2.ZERO, serial, 30, accent)
			c.draw_set_transform_matrix(xf)
			_txt(c, xf, _font_jp, Vector2(8, 30), jp, 18, ink)
		2:
			c.draw_circle(Vector2(sz.x * 0.5, 50), 24, accent)
			c.draw_circle(Vector2(sz.x * 0.5, 50), 10, ink)
			_txt(c, xf, _font_mono, Vector2(8, 100), serial, 12, ink)
		_:
			for j in 4:
				MotionMarks.chevron_up(c, Vector2(sz.x * 0.5, 30 + j * 22), 26, accent)


func _block_decals(b: MotionSolid, cx: int, cy: int) -> void:
	var kind := int(_r(cx, cy, 30) * 3.0)
	var ink := INK if b.data.mat in ["cream", "grey"] else CREAM
	var accent := RED if b.data.mat != "red" else CREAM
	b.add_decal(Vector3(0, -1, 0), _dec(_block_face.bind(kind, accent, ink)))


func _block_face(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D, kind: int, accent: Color, ink: Color) -> void:
	match kind:
		0:
			_txt(c, xf, _font_mono, Vector2(8, 22), "EXIT", 14, ink)
			MotionMarks.arrow(c, Vector2(52, 16), 18, accent)
		1:
			for j in 5:
				c.draw_rect(Rect2(6 + j * 14, 10, 8, sz.y - 20), accent)
		_:
			c.draw_rect(Rect2(0, 8, sz.x, 12), accent)


# ---------------------------------------------------------------- decals

func _platform_face(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	# The platform's south face: serials, katakana and hazard hatch, readable
	# in the front elevation under the logo. Items outside this band are skipped.
	c.draw_rect(Rect2(0, 0, sz.x, 6), RED)
	var inv := xf.affine_inverse()
	var vis := inv * _pv if _pv.has_area() else Rect2(Vector2.ZERO, sz)
	var y := 42.0
	var x := 40.0
	var items := ["TIME CITY 01", "フルスロットル・フラックス", "F-9000 // ANTI-GRAVITY LEAGUE", "反重力レース", "T-36F // TIME", "FULL THROTTLE FLUX", "全開流束", "MX-150 // 120 BPM", "第一", "MINIMAL HUMANS // BERLIN"]
	var k := 0
	if vis.position.y < 70.0 and vis.end.y > 0.0:
		while x < sz.x - 420.0:
			var t: String = items[k % items.size()]
			var w := _font_mono.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			if x + w > vis.position.x and x < vis.end.x:
				_txt(c, xf, _font_mono, Vector2(x, y), t, 22.0, CREAM if k % 4 != 2 else RED)
			x += w + 60.0
			if k % 3 == 0 and x - 46 > vis.position.x - 40 and x - 46 < vis.end.x:
				MotionMarks.chevron_row(c, Vector2(x - 46, y - 17), 2, 18, RED)
			k += 1
	var hy := 58.0
	var i := maxf(0.0, floorf((vis.position.x - 40.0) / 36.0) * 36.0)
	while i < minf(sz.x, vis.end.x + 36.0):
		c.draw_colored_polygon(PackedVector2Array([Vector2(i, hy), Vector2(i + 16, hy), Vector2(i + 30, hy + 18), Vector2(i + 14, hy + 18)]), Color(RED, 0.9))
		i += 36.0


func _platform_east(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	c.draw_rect(Rect2(0, 0, sz.x, 6), RED)
	_txt(c, xf, _font_wide, Vector2(40, 74), "MX-150", 46, CREAM)
	_txt(c, xf, _font_jp, Vector2(320, 70), "反重力レース　第一", 30, RED)


func _presents(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	var f := now
	var s := MK.map(f, [L.STAMP, L.STAMP + 3], [0, 1], MK.ease_out)
	if s <= 0.0:
		return
	var a := minf(1.0, s * 2.0)
	var r := Rect2(24, 8, 296, sz.y - 16)
	var k := lerpf(1.25, 1.0, s)
	c.draw_rect(Rect2(r.get_center() - r.size * 0.5 * k, r.size * k), Color(RED, a))
	_txt(c, xf, _font_wide, Vector2(44, sz.y - 12), "PRESENTS", 28, Color(CREAM, a))
	var j := MK.map(f, [L.STAMP_JP, L.STAMP_JP + 3], [0, 1], MK.ease_out)
	if j > 0.0:
		_txt(c, xf, _font_jp, Vector2(350, sz.y - 13), "ミニマル・ヒューマンズ　提供", 24, Color(CREAM, j))


func _backdrop_face(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	c.draw_rect(Rect2(0, 0, sz.x, 10), RED)
	_txt(c, xf, _font_mono, Vector2(24, 44), "MINIMAL HUMANS // FOSS STUDIO // BERLIN", 18, CREAM)
	_txt(c, xf, _font_jp, Vector2(sz.x - 330, 46), "ミニマル・ヒューマンズ", 24, RED)
	MotionMarks.chevron_row(c, Vector2(sz.x - 120, 62), 4, 22, RED)
	for i in 6:
		c.draw_rect(Rect2(24 + i * 18, 64, 10, 22), CREAM if i % 2 == 0 else RED)


func _txt(c: MotionCanvas, xf: Transform2D, font: Font, pos: Vector2, t: String, size: float, col: Color) -> void:
	MotionExtrude.draw_text(c, xf, font, pos, t, size, col)


# ================================================================== motion

## Height offset of a city cell at frame f (0 = standing, negative = sunk).
func cell_offset(cell: Dictionary, f: float) -> float:
	var depth: float = cell.top + 0.3
	var d0: float = cell.d_mh
	var df: float = cell.d_ftf
	# I: rings rise from the MH plaza on thirty-seconds (the columns' time
	# wave spreads them across the frame)
	var ring := mini(L.RINGS - 1, int(d0 / 2.9))
	var t0 := L.RISE + ring * L.RING_STEP
	if f < t0:
		return -depth
	var up := MK.spring(f, t0, 15, 300)
	var off := -(1.0 - minf(up, 1.04)) * depth
	# II: the FTF plaza drains in rings away from the logo
	if cell.ftf:
		var td := L.DRAIN + floorf(df / 2.0) * 2.0
		off -= MK.map(f, [td, td + 7], [0, 1], MK.ease_in_quad) * depth
	# MH hold and logo hold: a pulse runs out from the monument / logo on every beat
	if f >= L.MH_SNAP and f < L.MH_SINK:
		var bt := L.MH_SNAP + floorf((f - L.MH_SNAP) / L.BEAT) * L.BEAT + d0 * 0.6
		if f >= bt:
			off -= 0.09 * exp(-(f - bt) * 0.3) * (1.0 - smoothstep(5.0, 13.0, d0))
	if f >= L.DROP - 2.0 and f < L.SINK:
		var bt2 := L.DROP + floorf((f - L.DROP) / L.BEAT) * L.BEAT + df * 0.5
		if f >= bt2:
			off -= 0.1 * exp(-(f - bt2) * 0.32) * (1.0 - smoothstep(6.0, 14.0, df))
	# III: everything sinks in rings from the logo outwards
	var ts := L.SINK + 4.0 + floorf(df / 1.8) * 1.6
	off -= MK.map(f, [ts, ts + 8], [0, 1], MK.ease_in_quad) * (depth + 0.2)
	return off


func _ease_keys(f: float, keys: Array, vals: Array, ease: Callable) -> float:
	return MK.interp(f, keys, vals, ease)


## The content camera: plan-ish build, near-front MH read, crane to the FTF
## plaza, flat front elevation for the logo.
func camera(f: float) -> void:
	var cam := scene.camera
	var t_open := Vector3(10.5, 5.5, 0.4)
	var t_mh := Vector3(MH_X + MH_WIDTH * 0.5, 2.8, 1.35)
	var t_ftf := Vector3(FTF_X + FTF_WIDTH * 0.5, 2.6, 1.0)
	var io := MK.ease_in_out
	var keys := [0.0, 38.0, 60.0, 120.0, 134.0, 150.0, 165.0, 186.0, 238.0, 360.0, 420.0]
	cam.yaw = _ease_keys(f, keys, [26, 32, 7, 7, 12, 46, 36, 30, 0, 0, 0], io)
	cam.pitch = _ease_keys(f, keys, [54, 44, 11, 11, 18, 50, 33, 28, 2.5, 2.5, 2.5], io)
	var zs := [52, 60, 142, 150, 136, 60, 92, 98, 150, 150, 168]
	var lz := []
	for z in zs:
		lz.append(log(float(z)))
	cam.scale = exp(_ease_keys(f, keys, lz, io))
	# the snap: the crane into the MH read lands hard on the bar
	var snap := MK.bezier(0.55, 0.0, 0.25, 1.0)
	if f >= 38.0 and f <= 60.0:
		var u: float = snap.call(clampf((f - 38.0) / 22.0, 0.0, 1.0))
		cam.yaw = lerpf(32, 7, u)
		cam.pitch = lerpf(44, 11, u)
		cam.scale = exp(lerpf(log(60.0), log(142.0), u))
	cam.target = t_open.lerp(t_mh, MK.map(f, [20, 60], [0, 1], snap))
	cam.target = cam.target.lerp(t_ftf, MK.map(f, [128, 165], [0, 1], MK.bezier(0.6, 0.0, 0.25, 1.0)))
	if f >= 120.0:
		cam.target.z = MK.interp(f, [120, 140, 165, 186, 238, 360], [1.35, 1.0, 0.9, 1.0, 1.5, 1.5], io)
	# MH hold: a slow sway, so the ripples of time have motion to bend
	if f > L.MH_SNAP and f < L.MH_SINK + 10.0:
		var e := MK.map(f, [L.MH_SNAP, L.MH_SNAP + 12], [0, 1]) * (1.0 - MK.map(f, [L.MH_SINK - 6, L.MH_SINK + 10], [0, 1]))
		cam.yaw += 3.0 * sin((f - L.MH_SNAP) * TAU / 60.0) * e
		cam.target.x += 0.25 * sin((f - L.MH_SNAP) * TAU / 120.0) * e
	# logo hold: breathing yaw; a slow push in the outro
	if f > L.DROP:
		var e2 := MK.map(f, [L.DROP, L.DROP + 20], [0, 1])
		cam.yaw += 3.0 * sin((f - L.DROP) * TAU / 120.0) * e2
	var kick := L.kicks(f, L.ACCENTS, 26.0, 0.32) + L.kicks(f, [L.TEAR], 40.0, 0.25)
	cam.centre = Vector2(960, 540) + MK.shakes(f, [L.MH_SNAP, L.DROP], 16, 9) + MK.shakes(f, [L.STAMP, L.ARRIVE], 6, 6) + Vector2(kick, 0.0)
	for at in L.RIPPLES:
		if f >= at:
			cam.centre.y += 10.0 * exp(-(f - float(at)) * 0.3) * sin((f - float(at)) * 0.9)


## Pose the world at frame f for the strip `view` of the screen (empty = all).
## Cheap when called again with the same arguments.
func pose(f: float, view: Rect2) -> void:
	if f == _pf and view == _pv:
		return
	_pose(f, view)


func _pose(f: float, view: Rect2) -> void:
	_pf = f
	_pv = view
	pose_light(f)
	_pf = f
	var cam := scene.camera
	var cull := view.has_area()
	for cell in cells:
		var sol: Array = cell.solids
		var on := true
		if cull:
			on = view.intersects(MotionViewRect.box(cam, cell.c, cell.h))
		var off := cell_offset(cell, f) if on else 0.0
		if on and off < -(cell.top as float) - 0.05:
			on = false
		var rest: Array = cell.rest
		for i in sol.size():
			var s: MotionSolid = sol[i]
			s.visible = on
			if on:
				s.origin.z = (rest[i] as float) + off
	scene.cull_rect = view.grow(4.0) if cull else Rect2()
	scene.prepare()


## Camera, monument and logo slab only (cheap): enough for cap transforms and
## masks. Invalidates the full pose.
func pose_light(f: float) -> void:
	_pf = NAN
	now = f
	camera(f)
	scene.camera.update()
	# Monument: rises out of the plaza, unfolds, sinks.
	var mh_up := MK.map(f, [L.MH_RISE, L.MH_RISE + 18.0], [0, 1], MK.bezier(0.5, 0.0, 0.2, 1.0))
	var mh_down := MK.map(f, [L.MH_SINK, L.MH_SINK + 13], [0, 1], MK.ease_in_quad)
	var mh_off := -(1.0 - mh_up + mh_down) * (mh_h + 0.6)
	var unfold := MK.map(f, [L.MH_UNFOLD, L.MH_SNAP], [0, 1], MK.bezier(0.3, 0.0, 0.2, 1.0))
	var gap := 0.42 * unfold
	for i in 3:
		mh_slabs[i].origin = Vector3(MH_X, MH_Y + (2 - i) * gap, PED + mh_h + mh_off)
	for s in mh_letters:
		s.origin = Vector3(MH_X, MH_Y, PED + mh_h + mh_off)
		s.depth = lerpf(0.04, LETTER_D, unfold)
	plinth.origin.z = -(1.0 - MK.map(f, [L.MH_RISE - 6, L.MH_RISE + 2], [0, 1], MK.ease_out)) * (PED + 0.1) - MK.map(f, [L.MH_SINK + 8, L.MH_SINK + 16], [0, 1], MK.ease_in_quad) * (PED + 0.1)
	backdrop.origin.z = -(1.0 - MK.map(f, [L.MH_RISE - 3, L.MH_RISE + 14], [0, 1], MK.bezier(0.5, 0.0, 0.2, 1.0)) + mh_down) * 3.0
	mh_on = f >= L.MH_RISE - 8 and f < L.MH_SINK + 18
	# FTF slab: rises out of the floor, locks on the drop, sinks first at the end.
	var ftf_up := MK.map(f, [L.FTF_RISE + 4.0, L.DROP - 2.0], [0, 1], MK.bezier(0.3, 0.12, 0.3, 1.0))
	var ftf_down := MK.map(f, [L.SINK, L.SINK + 12], [0, 1], MK.ease_in_quad)
	ftf.origin.z = ftf_h - (1.0 - ftf_up + ftf_down) * (ftf_h + 0.4)
	ftf_on = f >= L.FTF_RISE and f < L.SINK + 13
	active_y = MH_Y if f < 160.0 else FTF_Y


func is_special(s: MotionSolid) -> bool:
	return _special.has(s)


func is_front(s: MotionSolid) -> bool:
	if s.layer == 1:
		return true
	var cpos: Vector2 = s.data.get("cell", Vector2(-1, 99))
	return cpos.y < active_y - 0.6


## Painted markings on the platform top (ground plane decals).
func ground_markings(c: MotionCanvas, f: float) -> void:
	var cam := scene.camera
	var xf := cam.plane_transform(Vector3(0, NY, 0), Vector3(1, 0, 0) / MotionExtrude.DECAL_PX, Vector3(0, -1, 0) / MotionExtrude.DECAL_PX)
	c.draw_set_transform_matrix(xf)
	var gy := func(y: float) -> float: return (NY - y) * MotionExtrude.DECAL_PX
	var on1 := MK.map(f, [16, 26], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [L.MH_SINK + 10, L.MH_SINK + 20], [0, 1]))
	var vis1 := not _pv.has_area() or _pv.intersects(MotionViewRect.box(cam, Vector3(MH_X + 4.0, 0.7, 0.0), Vector3(4.6, 0.6, 0.05)))
	if on1 > 0.0 and vis1:
		var x0 := MH_X * 100.0
		for i in int(18 * on1):
			var x := x0 + i * 42.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, gy.call(1.1)), Vector2(x + 20, gy.call(1.1)), Vector2(x + 44, gy.call(0.65)), Vector2(x + 24, gy.call(0.65))]), Color(INK, 0.85))
		_txt(c, xf, _font_mono, Vector2(x0, gy.call(0.25)), "PLAZA 01 // TIME CITY // EXIT >>", 22, RED)
	var on2 := MK.map(f, [L.DRAIN + 4, L.DRAIN + 14], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [L.SINK + 16, L.SINK + 26], [0, 1]))
	var vis2 := not _pv.has_area() or _pv.intersects(MotionViewRect.box(cam, Vector3(FTF_X + 4.8, 1.3, 0.0), Vector3(5.4, 1.2, 0.05)))
	if on2 > 0.0 and vis2:
		var x1 := FTF_X * 100.0
		for i in int(14 * on2):
			MotionMarks.chevron_row(c, Vector2(x1 + 40 + i * 64, gy.call(2.25)), 1, 46, RED if i % 2 == 0 else INK)
		_txt(c, xf, _font_mono, Vector2(x1, gy.call(0.3)), "PLAZA 02 // F-9000 // TIME GRID", 22, INK)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
