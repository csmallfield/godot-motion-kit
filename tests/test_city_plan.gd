# SPDX-License-Identifier: Apache-2.0
# MotionCityPlan: determinism, a small snapshot of the default grammar, the
# street/skip/force rules, the y-down lot frame, and both emitters. The
# reference is the cell grammar of ftf_megastructure.gd before the plan.
extends RefCounted


static func _small() -> MotionCityPlan:
	var p := MotionCityPlan.new()
	p.grid = Rect2i(0, 0, 8, 5)
	p.skip = [Rect2i(0, 0, 2, 2)]
	p.prepare = func(cell: Dictionary) -> void:
		if cell.j <= 1:
			cell.force = "low"
	p.build()
	return p


static func _kinds(p: MotionCityPlan) -> String:
	var out := PackedStringArray()
	for c in p.cells:
		out.append(String(c.kind).substr(0, 2) + String(c.mat).substr(0, 1))
	return " ".join(out)


func test_determinism() -> String:
	var a := var_to_str(_small().cells)
	var b := var_to_str(_small().cells)
	if a != b:
		return "two builds differ"
	var p := _small()
	var c := p.plan_lot(5, 3)
	for q in p.cells:
		if q.i == 5 and q.j == 3 and var_to_str(q) != var_to_str(c):
			return "plan_lot differs from build"
	return ""


func test_snapshot() -> String:
	var p := _small()
	var want := "loc lob loc log loc lob lob lob loc loc lob loc rag rac blc blg rab sir toc tor blb sir tor rag rab emr rar sir toc sic blc emg blb blc tor rab"
	var got := _kinds(p)
	if got != want:
		return "kinds: %s" % got
	if p.cells.size() != 40 - 4:
		return "count %d" % p.cells.size()
	# every number of every part (Godot 4.5 var_to_str formatting)
	var md5 := var_to_str(p.cells).md5_text()
	if md5 != "bed90d65a428c48db0b92f08385b0115":
		return "records md5 %s" % md5
	return ""


func test_reference_grammar() -> String:
	# The Megastructure picker and kind thresholds, written out by hand.
	var p := _small()
	for c in p.cells:
		var i: int = c.i
		var j: int = c.j
		var r := MK.rand(i * 13.13 + j * 71.7 + 0 * 5.31 + 0.7)
		var m := MK.rand(i * 13.13 + j * 71.7 + 1 * 5.31 + 0.7)
		var mat := "cream" if m < 0.42 else ("red" if m < 0.66 else ("grey" if m < 0.82 else "black"))
		var kind := "low"
		if j > 1:
			kind = "empty" if r < 0.08 else ("tower" if r < 0.34 else ("block" if r < 0.58 else ("silos" if r < 0.74 else ("ramp" if r < 0.88 else "rack"))))
		if c.kind != kind or c.mat != mat:
			return "lot %d,%d: %s %s != %s %s" % [i, j, c.kind, c.mat, kind, mat]
		if kind == "tower":
			var h := 1.8 + 2.6 * MK.rand(i * 13.13 + j * 71.7 + 4 * 5.31 + 0.7)
			var shaft: Dictionary = c.parts[0]
			if c.h != h or shaft.at != Vector3(i, j, 0) + Vector3(0.1, 0.1, 0) or shaft.size != Vector3(0.8, 0.8, h):
				return "tower %d,%d" % [i, j]
	return ""


func test_streets_skip_force() -> String:
	var p := MotionCityPlan.new()
	p.grid = Rect2i(-6, -6, 12, 12)
	p.street_every = Vector2i(5, 5)
	p.skip = [Rect2i(1, 1, 2, 2)]
	p.include = func(i: int, _j: int) -> bool: return i != 3
	p.prepare = func(cell: Dictionary) -> void:
		if cell.i == 4 and cell.j == 4:
			cell.force = "stack"
			cell.cap = 0.6
	p.build()
	for c in p.cells:
		var street := posmod(c.i, 5) == 0 or posmod(c.j, 5) == 0
		if (c.kind == "street") != street:
			return "street %d,%d" % [c.i, c.j]
		if Rect2i(1, 1, 2, 2).has_point(Vector2i(c.i, c.j)) or c.i == 3:
			return "skipped lot planned %d,%d" % [c.i, c.j]
		if c.i == 4 and c.j == 4:
			if c.kind != "stack" or not c.forced or c.h > 0.6 or c.top > 0.6 + 0.3:
				return "forced stack %s h %s top %s" % [c.kind, c.h, c.top]
	return ""


func test_y_down_frame_and_flat3d() -> String:
	# A lot laid out from its north-west corner with y_dir -1 maps to y-up
	# space exactly as w(x, y, h) = (x, h, -y) plus a local (dx, up, dz).
	var p := MotionCityPlan.new()
	p.grid = Rect2i(3, 7, 1, 1)
	p.corner = [-0.5, 0.5]
	p.corner_inset = [0.08, -0.08]
	p.y_dir = -1.0
	p.shape = {inset = 0.0, width = 0.84}
	p.prepare = func(cell: Dictionary) -> void: cell.force = "block"
	p.build()
	var c: Dictionary = p.cells[0]
	var o3 := Vector3(3 - 0.5 + 0.08, 0.0, -(7 + 0.5 - 0.08))
	var shaft: Dictionary = c.parts[0]
	if MotionCityPlan.to_y_up(shaft.at) != o3:
		return "corner %s != %s" % [MotionCityPlan.to_y_up(shaft.at), o3]
	if c.parts[1].type == "box":
		var want := o3 + Vector3(0.2, c.h, 0.3)
		if MotionCityPlan.to_y_up(c.parts[1].at) != want:
			return "vent %s != %s" % [MotionCityPlan.to_y_up(c.parts[1].at), want]
	var surf := {}
	for m in p.materials:
		surf[m] = MotionFlat3D.begin()
	var edges := MotionEdges3D.new()
	MotionCityPlan.to_flat3d(c, surf, Vector2(3, -7), edges)
	var arr: Array = (surf[c.mat] as SurfaceTool).commit_to_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if verts.size() < 30 or edges.count() < 12:
		return "flat3d verts %d edges %d" % [verts.size(), edges.count()]
	for v in verts.slice(0, 30):
		if v.z < o3.z - 1e-5 or v.z > o3.z + 0.84 + 1e-5 or v.y < 0.0:
			return "shaft vertex outside the lot %s" % v
	return ""


func test_solids_emitter() -> String:
	var p := _small()
	var n := 0
	for c in p.cells:
		var sol := p.solids(c, func(s: MotionSolid, m: String) -> void:
			s.stroke(Color.BLACK, 1.0)
			s.data.mat = m)
		if sol.size() != (c.parts as Array).size():
			return "solid count"
		for k in sol.size():
			var part: Dictionary = c.parts[k]
			if sol[k].stack != part.stack or sol[k].data.mat != part.mat:
				return "stack/mat"
			if part.get("plain", false) != (sol[k].outline_width == 0.0):
				return "plain outline"
			if part.type == "box" and (sol[k].origin != part.at or sol[k].depth != part.size.z):
				return "box placement"
		n += sol.size()
	return "" if n > 40 else "too few solids %d" % n


func test_wedge_flat3d() -> String:
	var p := MotionCityPlan.new()
	p.grid = Rect2i(0, 0, 1, 1)
	p.prepare = func(cell: Dictionary) -> void: cell.force = "ramp"
	p.build()
	var c: Dictionary = p.cells[0]
	var surf := {}
	for m in p.materials:
		surf[m] = MotionFlat3D.begin()
	var edges := MotionEdges3D.new()
	MotionCityPlan.to_flat3d(c, surf, Vector2.ZERO, edges)
	var verts: PackedVector3Array = (surf[c.parts[0].mat] as SurfaceTool).commit_to_arrays()[Mesh.ARRAY_VERTEX]
	if verts.size() != 30 or edges.count() != 10:
		return "wedge verts %d edges %d" % [verts.size(), edges.count()]
	var top := 0.0
	for v in verts:
		top = maxf(top, v.y)
	if absf(top - float(c.h)) > 1e-5:
		return "wedge top %s != %s" % [top, c.h]
	return ""
