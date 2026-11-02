# SPDX-License-Identifier: Apache-2.0
## Extruded 3D meshes from Motion SVG data: every part becomes a solid with a
## front cap, a back cap and side walls, in one ArrayMesh (one draw call).
##
##   var mesh := MotionSvgMesh.build(load("res://logo.svg"), 24.0, {
##       depth = 0.6,
##       part_fn = func(i): return {depth = 1.2} if i in LETTERS else {},
##   })
##   var mi := MeshInstance3D.new(); mi.mesh = mesh
##   mi.material_override = MotionStage3D.unlit(Color.WHITE, 1.2)
##
## Coordinates: the viewBox maps to `width` world units across, X right, Y up,
## extruded towards +Z (the front cap faces +Z). `anchor` (fractions of the
## viewBox) sits at the origin, the centre by default.
## Holes (counters in letters, rings) are found by nesting: a contour inside
## an odd number of the part's other contours is a hole. Caps are triangulated
## by cutting each hole open to the outside with a hairline slit, so Godot's
## ear-clipping triangulator sees simple polygons; side walls follow the true
## contours, so the slit never shows in 3D.
##
## Vertex data, for materials: COLOR = the part's colour (sides use
## `side_color`, by default the colour darkened by `side_shade`); UV = position
## in the viewBox (0..1); UV2 = (UV.x, part index), so MotionStage3D.unlit()'s
## `lit_to` can sweep a light across the logo or switch parts on by index.
## Triangles are not consistently wound: use a material with culling off
## (MotionStage3D.unlit() is).
@tool
class_name MotionSvgMesh
extends RefCounted

## Options:
##   depth: float        extrusion in world units (default width * 0.02)
##   tolerance: float    curve flattening, in SVG units (default 0.5)
##   anchor: Vector2     viewBox point at the origin, as fractions (default 0.5, 0.5)
##   layer: float        each part's z offset step, so overlapping parts don't
##                       z-fight (default depth * 0.04)
##   side_shade: float   how much darker the side walls are (default 0.5)
##   flat: bool          front caps only, no back or sides: cutout cards (use
##                       depth 0, a small `layer` so parts stack toward +Z, and
##                       MotionFlat3D.cutout())
##   only: Array         part indices to include (default all)
##   part_fn: Callable   (i) -> Dictionary overriding per part: hide, color,
##                       side_color, back_color, depth, z
##   uv2_x: Callable     (i, uv: Vector2) -> float, the light position written
##                       to UV2.x (default uv.x)
static func build(data: MotionSvgData, width := 10.0, opts := {}) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	append(st, data, width, opts)
	var mesh := st.commit()
	return mesh


## Append the extruded parts to an open SurfaceTool (to merge a logo into a
## larger mesh). `xform` places it.
static func append(st: SurfaceTool, data: MotionSvgData, width := 10.0, opts := {}, xform := Transform3D.IDENTITY) -> void:
	var vb := data.view_box
	var k := width / vb.size.x
	var depth: float = opts.get("depth", width * 0.02)
	var tol: float = opts.get("tolerance", 0.5)
	var anchor: Vector2 = opts.get("anchor", Vector2(0.5, 0.5))
	var layer: float = opts.get("layer", depth * 0.04)
	var shade: float = opts.get("side_shade", 0.5)
	var flat: bool = opts.get("flat", false)
	var only: Array = opts.get("only", [])
	var part_fn: Callable = opts.get("part_fn", Callable())
	var uv2_fn: Callable = opts.get("uv2_x", Callable())
	var a := vb.position + vb.size * anchor
	for i in data.parts.size():
		if not only.is_empty() and not only.has(i):
			continue
		var p: Dictionary = data.parts[i]
		var o: Dictionary = part_fn.call(i) if part_fn.is_valid() else {}
		if o.get("hide", false):
			continue
		var fill: Color = p.fill
		if fill.a <= 0.0 and not o.has("color"):
			continue
		var col: Color = o.get("color", fill)
		var side: Color = o.get("side_color", col.darkened(shade))
		var back: Color = o.get("back_color", side)
		var d: float = o.get("depth", depth)
		var z0: float = o.get("z", i * layer)
		var z1 := z0 + d
		var contours := _contours(data.outline(i, tol))
		if contours.is_empty():
			continue
		var holes := _hole_flags(contours)
		var to3 := func(v: Vector2, z: float) -> Vector3:
			return xform * Vector3((v.x - a.x) * k, -(v.y - a.y) * k, z)
		var uv_of := func(v: Vector2) -> Vector2:
			return (v - vb.position) / vb.size
		var uv2_of := func(uv: Vector2) -> Vector2:
			return Vector2(uv2_fn.call(i, uv) if uv2_fn.is_valid() else uv.x, float(i))
		var nz := (xform.basis * Vector3(0, 0, 1)).normalized()
		# caps
		for poly in _cap_polygons(contours, holes):
			var tris := Geometry2D.triangulate_polygon(poly)
			if tris.is_empty():
				tris = _fallback_triangles(poly)
			for t in tris:
				var v: Vector2 = poly[t]
				var uv: Vector2 = uv_of.call(v)
				st.set_color(col); st.set_normal(nz); st.set_uv(uv); st.set_uv2(uv2_of.call(uv))
				st.add_vertex(to3.call(v, z1))
			if flat:
				continue
			for t in range(tris.size() - 1, -1, -1):
				var v: Vector2 = poly[tris[t]]
				var uv: Vector2 = uv_of.call(v)
				st.set_color(back); st.set_normal(-nz); st.set_uv(uv); st.set_uv2(uv2_of.call(uv))
				st.add_vertex(to3.call(v, z0))
		if flat:
			continue
		# side walls along the true contours
		for c in contours:
			var n := c.size()
			for j in n:
				var p0: Vector2 = c[j]
				var p1: Vector2 = c[(j + 1) % n]
				if p0.distance_squared_to(p1) < 1e-10:
					continue
				var e := (p1 - p0).normalized()
				var nrm := (xform.basis * Vector3(e.y, e.x, 0.0)).normalized()
				var u0: Vector2 = uv_of.call(p0)
				var u1: Vector2 = uv_of.call(p1)
				var quad := [[p0, z0, u0], [p1, z0, u1], [p1, z1, u1], [p0, z0, u0], [p1, z1, u1], [p0, z1, u0]]
				for q in quad:
					st.set_color(side); st.set_normal(nrm); st.set_uv(q[2]); st.set_uv2(uv2_of.call(q[2]))
					st.add_vertex(to3.call(q[0], q[1]))


## Drop closing duplicates and degenerate contours.
static func _contours(raw: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for c in raw:
		var pts := PackedVector2Array()
		for v in c:
			if pts.is_empty() or pts[pts.size() - 1].distance_squared_to(v) > 1e-8:
				pts.append(v)
		if pts.size() > 2 and pts[0].distance_squared_to(pts[pts.size() - 1]) < 1e-8:
			pts.remove_at(pts.size() - 1)
		if pts.size() >= 3 and absf(MotionPoly.signed_area(pts)) > 1e-6:
			out.append(pts)
	return out


## Deprecated: use MotionPoly.signed_area.
static func _area(c: PackedVector2Array) -> float:
	return MotionPoly.signed_area(c)


## A contour is a hole when it lies inside an odd number of the others
## (MotionPoly.hole_flags, most-vertices rule).
static func _hole_flags(contours: Array[PackedVector2Array]) -> Array[bool]:
	return MotionPoly.hole_flags(contours)


## Deprecated: use MotionPoly.contour_inside.
static func _inside(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return MotionPoly.contour_inside(a, b)


## Simple polygons covering the filled area: each outer contour with every
## hole cut open to the right by a hairline slit.
static func _cap_polygons(contours: Array[PackedVector2Array], holes: Array[bool]) -> Array[PackedVector2Array]:
	var right := -INF
	for c in contours:
		for v in c:
			right = maxf(right, v.x)
	var out: Array[PackedVector2Array] = []
	for i in contours.size():
		if holes[i]:
			continue
		var outer := contours[i]
		if Geometry2D.is_polygon_clockwise(outer):
			outer = _reversed(outer)
		var polys: Array[PackedVector2Array] = [outer]
		for j in contours.size():
			if not holes[j] or not MotionPoly.contour_inside(contours[j], outer):
				continue
			var cutter := _slit_hole(contours[j], right + 10.0)
			var next: Array[PackedVector2Array] = []
			for p in polys:
				# the slit opens every hole to the outside, so no result is a hole
				for r in Geometry2D.clip_polygons(p, cutter):
					if r.size() >= 3:
						next.append(r)
			polys = next
		out.append_array(polys)
	return out


## The hole merged with a thin slit from its rightmost point out past `to_x`.
static func _slit_hole(hole: PackedVector2Array, to_x: float) -> PackedVector2Array:
	var m := hole[0]
	for v in hole:
		if v.x > m.x:
			m = v
	var e := 0.004
	var slit := PackedVector2Array([Vector2(m.x - e * 4.0, m.y - e), Vector2(to_x, m.y - e), Vector2(to_x, m.y + e), Vector2(m.x - e * 4.0, m.y + e)])
	var best := hole
	var best_a := 0.0
	for r in Geometry2D.merge_polygons(hole, slit):
		var ar := absf(MotionPoly.signed_area(r))
		if ar > best_a:
			best = r
			best_a = ar
	return best


static func _reversed(c: PackedVector2Array) -> PackedVector2Array:
	var r := c.duplicate()
	r.reverse()
	return r


## When ear clipping fails, convex pieces fanned out.
static func _fallback_triangles(poly: PackedVector2Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for piece in Geometry2D.decompose_polygon_in_convex(poly):
		var idx := PackedInt32Array()
		for v in piece:
			var best := 0
			for j in poly.size():
				if poly[j].distance_squared_to(v) < poly[best].distance_squared_to(v):
					best = j
			idx.append(best)
		for j in range(1, idx.size() - 1):
			out.append_array([idx[0], idx[j], idx[j + 1]])
	return out
