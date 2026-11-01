# SPDX-License-Identifier: Apache-2.0
## Crisp black outlines for MotionStage3D worlds: an edge mesh whose quads the
## edge shader widens to a constant pixel width in screen space (perspective
## and orthographic alike), depth-tested against the solids so hidden edges
## stay hidden. Crease edges (box corners, rims, the line where a building
## meets the ground) draw whenever a face beside them looks at the camera;
## smooth edges (between the facets of a cylinder) draw only where they form
## the silhouette, so round things get outline sides that follow the view.
##
##   var edges := MotionEdges3D.new()
##   MotionFlat3D.box(st, Vector3(0, 0, 0), Vector3(1, 3, 1), key, Color.WHITE, edges)
##   var mi := MeshInstance3D.new()
##   mi.mesh = edges.commit()
##   mi.material_override = flat.edges(Color("#141417"), 1.6)
##
## Or outline any mesh after the fact (an extruded logo from MotionSvgMesh):
##   mi.mesh = MotionEdges3D.from_mesh(logo_mesh, {crease_deg = 40.0})
##
## Each edge is 4 vertices and 6 indices; group keys (UV2) move edges with
## their objects exactly like the faces (see motion_flat_3d.gdshaderinc).
@tool
class_name MotionEdges3D
extends RefCounted

const SHADER := preload("res://addons/motion_kit/three/motion_edges_3d.gdshader")

## Edge kinds (CUSTOM1.w).
const SMOOTH := 0       ## silhouette only
const CREASE := 1       ## when either neighbouring face looks at the camera
const ALWAYS := 2       ## always; the depth test decides (meshes without reliable winding)

var _st := SurfaceTool.new()
var _n := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)


## Number of edges added so far.
func count() -> int:
	return _n


## One edge from a to b between faces with normals na and nb.
func add(a: Vector3, b: Vector3, na: Vector3, nb: Vector3, kind := CREASE, key := Vector2.ZERO) -> void:
	var c1 := Color(nb.x, nb.y, nb.z, float(kind))
	for v in [[a, b, 1.0], [a, b, -1.0], [b, a, -1.0], [b, a, 1.0]]:
		var p: Vector3 = v[0]
		var o: Vector3 = v[1]
		_st.set_normal(na)
		_st.set_uv2(key)
		_st.set_custom(0, Color(o.x, o.y, o.z, v[2]))
		_st.set_custom(1, c1)
		_st.add_vertex(p)
	var i := _n * 4
	for k in [0, 2, 3, 0, 3, 1]:
		_st.add_index(i + k)
	_n += 1


## A polyline of crease edges (closed when `closed`), all with the same normals.
func add_loop(pts: PackedVector3Array, na: Vector3, nb: Vector3, kind := CREASE, key := Vector2.ZERO, closed := true) -> void:
	var m := pts.size()
	for i in (m if closed else m - 1):
		add(pts[i], pts[(i + 1) % m], na, nb, kind, key)


## The edge ArrayMesh (empty edges give an empty mesh).
func commit() -> ArrayMesh:
	if _n == 0:
		return ArrayMesh.new()
	return _st.commit()


## The kit's edge material: `color`, `width_px` on screen, `bias` world units
## towards the camera. MotionFlat3D.edges() makes one registered with a look.
static func material(color := Color("#121214"), width_px := 1.6, bias := 0.04) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("width_px", width_px)
	m.set_shader_parameter("bias", bias)
	return m


## Outline an existing mesh: welds vertices (`weld` units), finds every edge,
## keeps boundaries and creases sharper than `crease_deg` (winding-proof: the
## angle test uses |cos|), and draws them `kind` (ALWAYS by default, for
## meshes such as MotionSvgMesh whose triangles are not consistently wound).
## `xform` places the source; `key` is the group key for every edge.
static func from_mesh(mesh: Mesh, opts := {}) -> ArrayMesh:
	var crease: float = opts.get("crease_deg", 35.0)
	var weld: float = opts.get("weld", 0.001)
	var kind: int = opts.get("kind", ALWAYS)
	var key: Vector2 = opts.get("key", Vector2.ZERO)
	var xform: Transform3D = opts.get("xform", Transform3D.IDENTITY)
	var cos_c := cos(deg_to_rad(crease))
	var ids := {}
	var pos: Array[Vector3] = []
	var edges := {}      # int key -> [a, b, normals...]
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for t in tri:
			var vi := [0, 0, 0]
			var p := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
			for k in 3:
				var j := idx[t * 3 + k] if idx.size() > 0 else t * 3 + k
				var v: Vector3 = xform * verts[j]
				p[k] = v
				var q := Vector3i((v / weld).round())
				if not ids.has(q):
					ids[q] = pos.size()
					pos.append(v)
				vi[k] = ids[q]
			var n: Vector3 = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0])
			if n.length_squared() < 1e-14:
				continue
			n = n.normalized()
			for k in 3:
				var a: int = vi[k]
				var b: int = vi[(k + 1) % 3]
				if a == b:
					continue
				var ek := mini(a, b) * 4194304 + maxi(a, b)
				if edges.has(ek):
					(edges[ek] as Array).append(n)
				else:
					edges[ek] = [mini(a, b), maxi(a, b), n]
	var out := MotionEdges3D.new()
	for e in edges.values():
		var ea: Array = e
		var na: Vector3 = ea[2]
		var keep := ea.size() != 4      # boundary (one face) or non-manifold
		var nb := -na
		if ea.size() == 4:
			nb = ea[3]
			keep = absf(na.dot(nb)) < cos_c
		if keep:
			out.add(pos[ea[0]], pos[ea[1]], na, nb, kind, key)
	return out.commit()
