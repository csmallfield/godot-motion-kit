# SPDX-License-Identifier: Apache-2.0
## A procedural machine city as plain data: a grid of lots, a street rule, a
## hashed kind and material per lot and the parts each kind is built from
## (boxes, cylinders, pipes, wedges with positions and sizes). Nothing is drawn
## or allocated beyond dictionaries, so one plan can feed the 2.5D look
## (MotionExtrude solids via `solids()`) or real 3D (MotionFlat3D meshes via
## `to_flat3d()`), and a piece adds its decals and dressing per part by role.
##
##   var plan := MotionCityPlan.new()
##   plan.grid = Rect2i(0, 0, 24, 14)
##   plan.skip = [Rect2i(0, 0, 11, 5)]                    # a plaza
##   plan.prepare = func(cell: Dictionary) -> void:
##       if cell.j <= 1: cell.force = "low"                # low front rows
##   plan.build()
##   for cell in plan.cells:
##       var parts: Array = cell.parts
##       var sol := plan.solids(cell, func(s: MotionSolid, mat: String) -> MotionSolid: return _paint(s, mat))
##       for i in sol.size():
##           if parts[i].role == "shaft": sol[i].add_decal(Vector3(0, -1, 0), _face)
##           scene.add(sol[i])
##
## **Plan space**: x east, y north, z up, one unit per cell (MotionExtrude's
## axes). `to_flat3d()` maps it to Godot's y-up axes as (x, z, -y), a pure swap
## and negation, so a piece built in y-up space keeps its exact numbers.
##
## **Hash**: every random choice is `rand(i, j, key)` =
## `MK.rand(i * hash_i + j * hash_j + key * hash_k + seed)`, a pure function of
## the lot and a key, so the order of calls never matters and a lot's choices
## never depend on its neighbours. Kind and material keys: `kind_key` (0),
## `mat_key` (1); the grammar's own keys are listed in SHAPE.
##
## **Kinds**: `r = rand(i, j, kind_key)`; `r < empty_below` is an empty lot,
## else the first `kinds[n]` with `r < kind_split[n]`, else the last kind.
## `prepare(cell)` may force a kind (`cell.force`, never empty), cap heights
## (`cell.cap`) or replace the main height range (`cell.h_range = [base, span]`).
## Built-in kinds (the Megastructure grammar): tower (shaft, set-back cap,
## mast), block (shaft and roof plant: a tank or two vents), silos (deck and
## two silos), ramp (a wedge), stack (a stepped block), rack (two posts, two
## pipes), low (a low box and a tank). `builders[kind] = func(plan, cell, o)`
## adds a kind or replaces one, using `add_box`/`add_cylinder`/`add_pipe`/`add_wedge`.
##
## **Lot frame**: each lot's parts are placed from its corner
## `o = (i + corner[0] + corner_inset[0], j + corner[1] + corner_inset[1], 0)`
## with local y multiplied by `y_dir` (1 = lots grow north from their south
## edge; -1 = south from their north edge). The two corner terms are kept
## apart only so a piece can reproduce its own float sums.
##
## Numbers are doubles throughout (SHAPE holds floats and arrays, never
## Vector2/3) so heights match pieces written with plain float maths.
@tool
class_name MotionCityPlan
extends RefCounted

## The grammar's numbers (the Megastructure city). Override any of them in
## `shape`. Ranges are [base, span, hash key] (value = base + span * rand);
## chances are [threshold, hash key] (taken when rand > threshold).
const SHAPE := {
	inset = 0.1,                    # shaft inset from the lot corner
	width = 0.8,                    # shaft footprint (1 - 2 * inset)
	tower_h = [1.8, 2.6, 4],
	cap_at = 0.24, cap_w = 0.52,    # tower cap: offset from the corner, width
	cap_h = [0.35, 0.3, 5],
	cap_mat_key = 6,
	mast = [0.55, 7], mast_at = 0.5, mast_r = 0.04, mast_h = 0.7, mast_seg = 6,
	mast_z32 = true,                # mast stands on the cap's stored (single precision) height
	block_h = [0.7, 1.1, 8],
	tank = [0.45, 9], tank_at = [0.38, 0.55], tank_r = [0.2, 0.08, 10], tank_h = [0.35, 0.3, 11], tank_seg = 0,
	vent_x = [0.2, 0.34], vent_y = 0.3, vent_size = [0.24, 0.42, 0.16],
	deck_at = 0.05, deck_w = 0.9, deck_h = 0.12,
	silo_mat = [0.4, 12], silo_x = [0.3, 0.4], silo_y = [0.3, 0.4], silo_r = 0.19, silo_h = [1.0, 0.9, 13], silo_seg = 14,
	ramp_at = [0.08, 0.1], ramp_len = 0.84, ramp_w = 0.8, ramp_h0 = 0.15, ramp_h = [1.1, 0.8, 15],
	stack_h = [0.5, 0.8, 15], step_k = 0.55, step_mat_key = 16, step_h = [0.4, 0.9, 17],
	post_x = [0.12, 0.12 + 0.66], post_y = 0.42, post_size = [0.1, 0.16, 0.95],
	pipe_x = [0.0, 1.0], pipe_y = 0.5, pipe_z = [0.55, 0.55 + 0.3], pipe_r = [0.11, 0.11], pipe_seg = 0,
	low_h = [0.18, 0.3, 2], low_tank = [0.5, 3], low_tank_at = 0.5, low_tank_r = 0.22, low_tank_h = 0.25,
}

## Lots (i, j) to plan, rows (j) outer, columns (i) inner.
var grid := Rect2i(0, 0, 24, 14)
## Lots left out entirely (plazas).
var skip: Array[Rect2i] = []
## Optional `func(i: int, j: int) -> bool`; lots it rejects are left out.
var include := Callable()
## Street period per axis (0 = none): lot i is a street when
## `posmod(i, street_every.x) == street_at.x` (same for j). Streets get records
## of kind "street" with no parts.
var street_every := Vector2i.ZERO
## Street phase per axis (see `street_every`).
var street_at := Vector2i.ZERO

## Hash offset (see the class doc).
var seed := 0.7
## Hash weight of the column.
var hash_i := 13.13
## Hash weight of the row.
var hash_j := 71.7
## Hash weight of the key.
var hash_k := 5.31

## Material names, light to dark. The grammar uses [0] light, [1] accent,
## [2] neutral (decks, vents) and [3] dark (posts, masts).
var materials := PackedStringArray(["cream", "red", "grey", "black"])
## `pick(i, j, key)` returns materials[n] for the first `r < mat_split[n]`.
var mat_split: Array[float] = [0.42, 0.66, 0.82]
## Hash key of a lot's main material.
var mat_key := 1.0

## Kind names in threshold order (the last one takes the rest).
var kinds := PackedStringArray(["tower", "block", "silos", "ramp", "rack"])
## Upper thresholds of all kinds but the last.
var kind_split: Array[float] = [0.34, 0.58, 0.74, 0.88]
## Lots with `r` below this are empty (unless forced).
var empty_below := 0.08
## Hash key of the kind draw.
var kind_key := 0.0
## Optional `func(cell: Dictionary) -> void`, called per lot before its kind is
## drawn; may set `force`, `cap`, `h_range` or any field of its own.
var prepare := Callable()
## Lot corner offset (see the class doc).
var corner: Array[float] = [0.0, 0.0]
## Second lot corner term (see the class doc).
var corner_inset: Array[float] = [0.0, 0.0]
## 1: lots grow north from their corner; -1: south.
var y_dir := 1.0
## Overrides of SHAPE values.
var shape := {}
## kind -> `func(plan: MotionCityPlan, cell: Dictionary, o: Vector3) -> void`.
var builders := {}

## The planned lots after `build()`: {i, j, kind, mat, r, h, top, cap, forced,
## corner, parts}. `h` is the main body's height, `top` its roof (tower: cap
## top; silos: the taller silo; stack: both steps). Parts:
## {type: "box"|"cylinder"|"pipe"|"wedge", role, mat, stack, at, ...} with
## box `size`; cylinder `r`, `h`, `seg`; pipe `to`, `r`, `len`, `seg`; wedge
## `len`, `w`, `h0`, `h1`. `plain` parts take no outline in 2.5D; `seg` 0 means
## the emitter's default.
var cells: Array[Dictionary] = []


# ------------------------------------------------------------------ hashing

## The lot hash: a pure function of (i, j, key) in 0..1.
func rand(i: float, j: float, k: float) -> float:
	return MK.rand(i * hash_i + j * hash_j + k * hash_k + seed)


## Material of lot (i, j) for hash key k.
func pick(i: int, j: int, k: float) -> String:
	var r := rand(i, j, k)
	for n in mat_split.size():
		if r < mat_split[n]:
			return materials[n]
	return materials[materials.size() - 1]


## True when lot (i, j) is on a street.
func is_street(i: int, j: int) -> bool:
	return (street_every.x > 0 and posmod(i, street_every.x) == street_at.x) \
		or (street_every.y > 0 and posmod(j, street_every.y) == street_at.y)


## A SHAPE value, with `shape` overrides.
func value(key: String) -> Variant:
	return shape.get(key, SHAPE[key])


# ------------------------------------------------------------------ planning

## Plan every lot of the grid into `cells` (rows outer). Returns `cells`.
func build() -> Array[Dictionary]:
	cells.clear()
	for j in range(grid.position.y, grid.end.y):
		for i in range(grid.position.x, grid.end.x):
			var c := plan_lot(i, j)
			if not c.is_empty():
				cells.append(c)
	return cells


## Plan one lot; {} when it is skipped or excluded.
func plan_lot(i: int, j: int) -> Dictionary:
	for r in skip:
		if r.has_point(Vector2i(i, j)):
			return {}
	if include.is_valid() and not include.call(i, j):
		return {}
	var cell := {i = i, j = j, kind = "street", mat = "", r = 0.0, h = 0.0, top = 0.0, cap = INF, forced = false,
		corner = Vector3.ZERO, parts = [] as Array[Dictionary]}
	if is_street(i, j):
		return cell
	cell.mat = pick(i, j, mat_key)
	cell.r = rand(i, j, kind_key)
	if prepare.is_valid():
		prepare.call(cell)
	var r: float = cell.r
	var kind := ""
	if cell.has("force") and String(cell.force) != "":
		kind = cell.force
		cell.forced = true
	elif r < empty_below:
		kind = "empty"
	else:
		kind = kinds[kinds.size() - 1]
		for n in kind_split.size():
			if r < kind_split[n]:
				kind = kinds[n]
				break
	cell.kind = kind
	if kind == "empty":
		return cell
	var o := Vector3(i + corner[0] + corner_inset[0], j + corner[1] + corner_inset[1], 0)
	cell.corner = o
	if builders.has(kind):
		(builders[kind] as Callable).call(self, cell, o)
	else:
		match kind:
			"tower": _tower(cell, o)
			"block": _block(cell, o)
			"silos": _silos(cell, o)
			"ramp": _ramp(cell, o)
			"stack": _stack(cell, o)
			"rack": _rack(cell, o)
			"low": _low(cell, o)
			_: push_error("MotionCityPlan: no builder for kind '%s'" % kind)
	return cell


# ------------------------------------------------------------------ parts

## A local offset in the lot frame (y follows `y_dir`).
func local(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y_dir * y, z)


## Add a box part from corner `at` (size y may be negative: the box spans at..at+size).
func add_box(cell: Dictionary, role: String, mat: String, stack: int, at: Vector3, size: Vector3) -> Dictionary:
	var p := {type = "box", role = role, mat = mat, stack = stack, at = at, size = size}
	(cell.parts as Array).append(p)
	return p


## Add an upright cylinder part standing on `at`.
func add_cylinder(cell: Dictionary, role: String, mat: String, stack: int, at: Vector3, r: float, h: float, seg := 0) -> Dictionary:
	var p := {type = "cylinder", role = role, mat = mat, stack = stack, at = at, r = r, h = h, seg = seg}
	(cell.parts as Array).append(p)
	return p


## Add a straight pipe part from `at` to `to` (2.5D: runs `len` along x).
func add_pipe(cell: Dictionary, role: String, mat: String, stack: int, at: Vector3, to: Vector3, r: float, len: float, seg := 0) -> Dictionary:
	var p := {type = "pipe", role = role, mat = mat, stack = stack, at = at, to = to, r = r, len = len, seg = seg}
	(cell.parts as Array).append(p)
	return p


## Add a wedge (ramp) part: `len` along x, `w` along y, rising from h0 to h1.
func add_wedge(cell: Dictionary, role: String, mat: String, stack: int, at: Vector3, len: float, w: float, h0: float, h1: float) -> Dictionary:
	var p := {type = "wedge", role = role, mat = mat, stack = stack, at = at, len = len, w = w, h0 = h0, h1 = h1}
	(cell.parts as Array).append(p)
	return p


## base + span * rand(key) for a [base, span, key] range, capped at `cap`.
func _range(cell: Dictionary, rg: Array, cap: float) -> float:
	return minf(cap, rg[0] + rg[1] * rand(cell.i, cell.j, rg[2]))


func _chance(cell: Dictionary, key: String) -> bool:
	var c: Array = value(key)
	return rand(cell.i, cell.j, c[1]) > c[0]


## The lot's main height: its kind's range (or `cell.h_range`), capped.
func _main_h(cell: Dictionary, key: String) -> float:
	var rg: Array = value(key)
	if cell.has("h_range"):
		var hr: Array = cell.h_range
		rg = [hr[0], hr[1], rg[2]]
	return _range(cell, rg, cell.cap)


func _shaft(cell: Dictionary, o: Vector3, h: float) -> Dictionary:
	var ins: float = value("inset")
	var w: float = value("width")
	return add_box(cell, "shaft", cell.mat, 0, o + local(ins, ins, 0), local(w, w, h))


func _light_or(mat: String, other: int) -> String:
	return materials[0] if mat != materials[0] else materials[other]


func _tower(cell: Dictionary, o: Vector3) -> void:
	var h := _main_h(cell, "tower_h")
	_shaft(cell, o, h)
	var ca: float = value("cap_at")
	var cw: float = value("cap_w")
	var ch := _range(cell, value("cap_h"), INF)
	var csize := local(cw, cw, ch)
	add_box(cell, "cap", pick(cell.i, cell.j, value("cap_mat_key")), 1, o + local(ca, ca, h), csize)
	cell.h = h
	cell.top = h + ch
	if _chance(cell, "mast"):
		var ma: float = value("mast_at")
		var z: float = h + csize.z if value("mast_z32") else cell.top
		add_cylinder(cell, "mast", materials[3], 2, o + local(ma, ma, z), value("mast_r"), value("mast_h"), value("mast_seg"))


func _block(cell: Dictionary, o: Vector3) -> void:
	var h := _main_h(cell, "block_h")
	_shaft(cell, o, h)
	cell.h = h
	cell.top = h
	if _chance(cell, "tank"):
		var at: Array = value("tank_at")
		var tm: String = materials[0] if cell.mat == materials[1] else materials[1]
		add_cylinder(cell, "tank", tm, 1, o + local(at[0], at[1], h), _range(cell, value("tank_r"), INF), _range(cell, value("tank_h"), INF), value("tank_seg"))
	else:
		var vx: Array = value("vent_x")
		var vs: Array = value("vent_size")
		for k in 2:
			add_box(cell, "vent", materials[2], 1, o + local(vx[0] + k * vx[1], value("vent_y"), h), local(vs[0], vs[1], vs[2]))


func _silos(cell: Dictionary, o: Vector3) -> void:
	var da: float = value("deck_at")
	var dw: float = value("deck_w")
	var dh: float = value("deck_h")
	add_box(cell, "deck", materials[2], 0, o + local(da, da, 0), local(dw, dw, dh))
	var sm: String = materials[0] if _chance(cell, "silo_mat") else materials[1]
	var sx: Array = value("silo_x")
	var sy: Array = value("silo_y")
	var rg: Array = value("silo_h")
	var top := 0.0
	for k in 2:
		var sh := _range(cell, [rg[0], rg[1], rg[2] + k], cell.cap)
		var p := add_cylinder(cell, "silo", sm, 1 + k, o + local(sx[0] + k * sx[1], sy[0] + k * sy[1], dh), value("silo_r"), sh, value("silo_seg"))
		p.plain = true
		top = maxf(top, sh + dh)
	cell.h = dh
	cell.top = top


func _ramp(cell: Dictionary, o: Vector3) -> void:
	var at: Array = value("ramp_at")
	var h1 := _main_h(cell, "ramp_h")
	var w: float = value("ramp_w")
	var p := o + local(at[0], at[1], 0)
	if y_dir < 0.0:
		p.y -= w
	add_wedge(cell, "ramp", _accent_or(cell.mat), 0, p, value("ramp_len"), w, value("ramp_h0"), h1)
	cell.h = h1
	cell.top = h1


func _accent_or(mat: String) -> String:
	return materials[1] if mat != materials[1] else materials[0]


func _stack(cell: Dictionary, o: Vector3) -> void:
	var h1 := _main_h(cell, "stack_h")
	_shaft(cell, o, h1)
	var w: float = value("width")
	var sw: float = w * value("step_k")
	var h2 := _range(cell, value("step_h"), cell.cap * 0.5)
	add_box(cell, "step", pick(cell.i, cell.j, value("step_mat_key")), 1, o + local(0.0, 0.0, h1), local(sw, sw, h2))
	cell.h = h1
	cell.top = h1 + h2


func _rack(cell: Dictionary, o: Vector3) -> void:
	var px: Array = value("post_x")
	var ps: Array = value("post_size")
	for k in 2:
		add_box(cell, "post", materials[3], k, o + local(px[k], value("post_y"), 0), local(ps[0], ps[1], ps[2]))
	var qx: Array = value("pipe_x")
	var qz: Array = value("pipe_z")
	var qr: Array = value("pipe_r")
	var qy: float = value("pipe_y")
	for k in 2:
		var p := add_pipe(cell, "pipe", materials[1] if k == 0 else materials[0], 2 + k, o + local(qx[0], qy, qz[k]), o + local(qx[1], qy, qz[k]),
			qr[k], qx[1] - qx[0], value("pipe_seg"))
		p.plain = true
	cell.h = ps[2]
	cell.top = ps[2]


func _low(cell: Dictionary, o: Vector3) -> void:
	var h := _main_h(cell, "low_h")
	_shaft(cell, o, h)
	cell.h = h
	cell.top = h
	if _chance(cell, "low_tank"):
		var a: float = value("low_tank_at")
		add_cylinder(cell, "tank", _light_or(cell.mat, 1), 1, o + local(a, a, h), value("low_tank_r"), value("low_tank_h"))


# ------------------------------------------------------------------ emitters

## A MotionSolid for one part (2.5D, MotionExtrude), unpainted.
static func solid(part: Dictionary) -> MotionSolid:
	var s: MotionSolid
	var seg: int = part.get("seg", 0)
	match part.type:
		"box":
			var at: Vector3 = part.at
			var size: Vector3 = part.size
			if size.y < 0.0:
				at.y += size.y
				size.y = -size.y
			s = MotionSolid.box(at, size)
		"cylinder":
			s = MotionSolid.cylinder(part.at, part.r, part.h, seg) if seg > 0 else MotionSolid.cylinder(part.at, part.r, part.h)
		"pipe":
			s = MotionSolid.pipe(part.at, part.r, part.len, Vector3.RIGHT, seg) if seg > 0 else MotionSolid.pipe(part.at, part.r, part.len)
		"wedge":
			s = MotionSolid.wedge(part.at, part.len, part.w, part.h0, part.h1)
	s.stack = part.stack
	return s


## One MotionSolid per part of `cell`, in part order. `paint` is
## `func(s: MotionSolid, mat: String) -> void` (e.g. a palette lookup and
## stroke); `plain` parts lose their outline after painting.
func solids(cell: Dictionary, paint := Callable()) -> Array[MotionSolid]:
	var out: Array[MotionSolid] = []
	for part: Dictionary in cell.parts:
		var s := solid(part)
		if paint.is_valid():
			paint.call(s, part.mat)
		if part.get("plain", false):
			s.outline_width = 0.0
		out.append(s)
	return out


## Plan space to Godot's y-up space: (x, z, -y).
static func to_y_up(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, -p.y)


## Write the parts of `cell` into MotionFlat3D surfaces (material name ->
## SurfaceTool from MotionFlat3D.begin()), with outlines into `edges` when
## given. `key` is the group key (UV2) the parts move with.
static func to_flat3d(cell: Dictionary, surfaces: Dictionary, key: Vector2, edges: MotionEdges3D = null, col := Color.WHITE) -> void:
	for part: Dictionary in cell.parts:
		var st: SurfaceTool = surfaces[part.mat]
		var seg: int = part.get("seg", 0)
		match part.type:
			"box":
				var at: Vector3 = part.at
				var s: Vector3 = part.size
				var p := Vector3(at.x, at.z, -at.y)
				var sz := Vector3(s.x, s.z, -s.y)
				if sz.z < 0.0:
					p.z += sz.z
					sz.z = -sz.z
				MotionFlat3D.box(st, p, sz, key, col, edges)
			"cylinder":
				MotionFlat3D.cylinder(st, to_y_up(part.at), part.r, part.h, key, col, edges, seg if seg > 0 else 14)
			"pipe":
				MotionFlat3D.pipe(st, to_y_up(part.at), to_y_up(part.to), part.r, key, col, edges, seg if seg > 0 else 10)
			"wedge":
				_wedge3d(st, part, key, col, edges)


static func _wedge3d(st: SurfaceTool, part: Dictionary, key: Vector2, col: Color, edges: MotionEdges3D) -> void:
	var at: Vector3 = part.at
	var x0 := at.x
	var x1: float = at.x + part.len
	var zs := -at.y                       # south edge (plan y min)
	var zn: float = -(at.y + part.w)      # north edge
	var b := at.z
	var t0: float = b + part.h0
	var t1: float = b + part.h1
	var slope := Vector3(-(t1 - t0), x1 - x0, 0.0).normalized()
	var wn := Vector3(x0, t0, zn)
	var ws := Vector3(x0, t0, zs)
	var es := Vector3(x1, t1, zs)
	var en := Vector3(x1, t1, zn)
	MotionFlat3D.quad(st, wn, ws, es, en, slope, key, col)
	MotionFlat3D.quad(st, Vector3(x0, b, zs), Vector3(x1, b, zs), es, ws, Vector3.BACK, key, col)
	MotionFlat3D.quad(st, Vector3(x1, b, zn), Vector3(x0, b, zn), wn, en, Vector3.FORWARD, key, col)
	MotionFlat3D.quad(st, Vector3(x0, b, zn), Vector3(x0, b, zs), ws, wn, Vector3.LEFT, key, col)
	MotionFlat3D.quad(st, Vector3(x1, b, zs), Vector3(x1, b, zn), en, es, Vector3.RIGHT, key, col)
	if edges:
		var C := MotionEdges3D.CREASE
		edges.add(wn, en, slope, Vector3.FORWARD, C, key)
		edges.add(ws, es, slope, Vector3.BACK, C, key)
		edges.add(wn, ws, slope, Vector3.LEFT, C, key)
		edges.add(en, es, slope, Vector3.RIGHT, C, key)
		edges.add(Vector3(x0, b, zn), wn, Vector3.FORWARD, Vector3.LEFT, C, key)
		edges.add(Vector3(x0, b, zs), ws, Vector3.BACK, Vector3.LEFT, C, key)
		edges.add(Vector3(x1, b, zn), en, Vector3.FORWARD, Vector3.RIGHT, C, key)
		edges.add(Vector3(x1, b, zs), es, Vector3.BACK, Vector3.RIGHT, C, key)
		edges.add(Vector3(x0, b, zs), Vector3(x1, b, zs), Vector3.BACK, Vector3.DOWN, C, key)
		edges.add(Vector3(x0, b, zn), Vector3(x1, b, zn), Vector3.FORWARD, Vector3.DOWN, C, key)
