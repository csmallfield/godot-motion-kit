# SPDX-License-Identifier: Apache-2.0
## The MotionExtrude graphic look in real 3D (MotionStage3D): flat face tones
## by normal (top / lit / dark, like MotionSolid.paint), crisp outlines
## (MotionEdges3D), decals from a MotionDecalAtlas, depth fog that survives a
## dolly zoom, and frame-pure group motion (rings sinking, beat pulses) that
## moves whole objects inside merged meshes from a key in UV2.
##
##   var flat := MotionFlat3D.new()
##   var red := flat.material(Color("#f0453a"), Color("#d72c22"), Color("#901810"))
##   var ink := flat.edges(Color("#141417"), 1.6)
##   var st := MotionFlat3D.begin()
##   var edges := MotionEdges3D.new()
##   MotionFlat3D.box(st, Vector3(0, 0, 0), Vector3(0.8, 3.0, 0.8), Vector2(0.4, 0.4), Color.WHITE, edges)
##   stage.world.add_child(MotionFlat3D.instance(st.commit(), red))
##   stage.world.add_child(MotionFlat3D.instance(edges.commit(), ink))
##   # every frame:
##   flat.pulse(origin, f - last_beat)
##   flat.fog_for(lens)       # optional: fog that follows a MotionLens3D
##   flat.apply()
##
## World axes are Godot's: y up, -z north. The light is horizontal; sides
## facing it take `lit`. Builders write explicit normals, the group key (UV2)
## and vertex colour, wind faces for back-face culling, and optionally add the
## matching outline edges.
@tool
class_name MotionFlat3D
extends RefCounted

const FLAT := preload("res://addons/motion_kit/three/motion_flat_3d.gdshader")
const FLAT_2S := preload("res://addons/motion_kit/three/motion_flat_3d_double.gdshader")
const DECAL := preload("res://addons/motion_kit/three/motion_decal_3d.gdshader")
const FLAT_I := preload("res://addons/motion_kit/three/motion_flat_3d_instanced.gdshader")
const FLAT_I2S := preload("res://addons/motion_kit/three/motion_flat_3d_instanced_double.gdshader")
const CUTOUT := preload("res://addons/motion_kit/three/motion_cutout_3d.gdshader")

## Horizontal direction the light comes from (Godot axes: +z is south).
var light := Vector3(-0.33, 0.0, 0.94)
var fog_color := Color.WHITE
var fog_begin := 1e5
var fog_end := 2e5
var fog_amount := 0.0
var energy := 1.0
var groups_on := true
var sink_origin := Vector2.ZERO
var sink_t := -1e4
var sink_step := 1.5
var sink_width := 1.8
var sink_dur := 8.0
var sink_depth := 8.0
var pulse_origin := Vector2.ZERO
var pulse_t := 1e4
var pulse_speed := 2.0
var pulse_amp := 0.0
var pulse_decay := 0.35
var pulse_reach := 14.0

var materials: Array[ShaderMaterial] = []
## Registered materials that ignore group motion (ground, roads, ground decals).
var fixed: Array[ShaderMaterial] = []


# ------------------------------------------------------------------ materials

## A face-tone material registered with this look. `under` defaults to a
## darker `dark` (undersides of walkways and pipes). `moves` false keeps it out
## of group motion (the ground). `two_sided` skips back-face culling (meshes
## without consistent winding, such as MotionSvgMesh logos: paint those with
## white tones so their vertex colours show as built). `instanced` gives
## per-instance `flash` and `tint` (set_flash / set_tint) for things that react
## one at a time: actors, props that get hit.
func material(top: Color, lit: Color, dark: Color, under := Color(0, 0, 0, 0), soft := 0.0, moves := true, two_sided := false,
		instanced := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if instanced:
		m.shader = FLAT_I2S if two_sided else FLAT_I
	else:
		m.shader = FLAT_2S if two_sided else FLAT
	m.set_shader_parameter("top", top)
	m.set_shader_parameter("lit", lit)
	m.set_shader_parameter("dark", dark)
	m.set_shader_parameter("under", under if under.a > 0.0 else dark.darkened(0.25))
	m.set_shader_parameter("soft", soft)
	return register(m, moves)


## An outline material registered with this look.
func edges(color := Color("#121214"), width_px := 1.6, bias := 0.04) -> ShaderMaterial:
	return register(MotionEdges3D.material(color, width_px, bias))


## A decal material for an atlas texture, registered with this look.
func decals(atlas: Texture2D, moves := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = DECAL
	m.set_shader_parameter("atlas", atlas)
	return register(m, moves)


## A material for flat cutout parts (MotionSvgMesh with `flat`): unlit vertex
## colour, two-sided, fogged with this look, per-instance `flash`, `tint` and
## `opacity`. Out of group motion (characters move on the CPU).
func cutout() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CUTOUT
	return register(m, false)


## Hit flash on one instance of an instanced or cutout material: rgb pulled
## toward `color` by `amount` (0 clears it). Keep flashes small and at most
## three a second (photosensitivity).
static func set_flash(gi: GeometryInstance3D, color: Color, amount: float) -> void:
	gi.set_instance_shader_parameter(&"flash", Color(color.r, color.g, color.b, clampf(amount, 0.0, 1.0)))


## Multiply one instance's colour (instanced and cutout materials).
static func set_tint(gi: GeometryInstance3D, color: Color) -> void:
	gi.set_instance_shader_parameter(&"tint", color)


## Add any material using motion_flat_3d.gdshaderinc so apply() drives it.
func register(m: ShaderMaterial, moves := true) -> ShaderMaterial:
	materials.append(m)
	if not moves:
		fixed.append(m)
	return m


## A MeshInstance3D with a material override.
static func instance(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


# ------------------------------------------------------------------ per frame

## Rings sinking away from `origin` (ground x, z): `t` frames since the start.
func sink(origin: Vector2, t: float, step := 1.5, width := 1.8, dur := 8.0, depth := 8.0) -> void:
	sink_origin = origin
	sink_t = t
	sink_step = step
	sink_width = width
	sink_dur = dur
	sink_depth = depth


## A bob running out from `origin`; `t` frames since the beat.
func pulse(origin: Vector2, t: float, amp := 0.07, speed := 2.0, decay := 0.35, reach := 14.0) -> void:
	pulse_origin = origin
	pulse_t = t
	pulse_amp = amp
	pulse_speed = speed
	pulse_decay = decay
	pulse_reach = reach


## Linear depth fog from `begin` to `end` units in front of the camera.
func fog(color: Color, begin: float, end: float, amount := 1.0) -> void:
	fog_color = color
	fog_begin = begin
	fog_end = end
	fog_amount = amount


## Fog measured from a lens's target rather than its camera: `before` and
## `after` are depths relative to the target plane, so a dolly zoom (the
## camera running far back) keeps the same fog around what it frames.
func fog_for(lens: MotionLens3D, color: Color, before: float, after: float, amount := 1.0) -> void:
	var d := lens.camera_distance()
	fog(color, d + before, d + after, amount)


## Push every value to every registered material. Call once per frame.
func apply() -> void:
	for m in materials:
		m.set_shader_parameter("light_dir", light)
		m.set_shader_parameter("fog_color", fog_color)
		m.set_shader_parameter("fog_begin", fog_begin)
		m.set_shader_parameter("fog_end", fog_end)
		m.set_shader_parameter("fog_amount", fog_amount)
		m.set_shader_parameter("energy", energy)
		m.set_shader_parameter("groups_on", 1.0 if groups_on and not fixed.has(m) else 0.0)
		m.set_shader_parameter("sink_origin", sink_origin)
		m.set_shader_parameter("sink_t", sink_t)
		m.set_shader_parameter("sink_step", sink_step)
		m.set_shader_parameter("sink_width", sink_width)
		m.set_shader_parameter("sink_dur", sink_dur)
		m.set_shader_parameter("sink_depth", sink_depth)
		m.set_shader_parameter("pulse_origin", pulse_origin)
		m.set_shader_parameter("pulse_t", pulse_t)
		m.set_shader_parameter("pulse_speed", pulse_speed)
		m.set_shader_parameter("pulse_amp", pulse_amp)
		m.set_shader_parameter("pulse_decay", pulse_decay)
		m.set_shader_parameter("pulse_reach", pulse_reach)


## The shader's group offset for `key`, in GDScript: move nodes that are not
## part of a merged mesh (cranes, traffic) exactly with the city around them.
func offset(key: Vector2) -> float:
	if not groups_on:
		return 0.0
	var off := 0.0
	var d := key.distance_to(sink_origin)
	if sink_t >= 0.0:
		var k := floorf(d / sink_width) if sink_width > 0.0 else d
		var p := clampf((sink_t - k * sink_step) / maxf(sink_dur, 1e-3), 0.0, 1.0)
		off -= p * p * sink_depth
	if pulse_amp != 0.0:
		var dp := key.distance_to(pulse_origin)
		var age := pulse_t - dp / maxf(pulse_speed, 1e-3)
		if age >= 0.0:
			off -= pulse_amp * exp(-age * pulse_decay) * (1.0 - smoothstep(pulse_reach * 0.6, pulse_reach, dp))
	return off


# ------------------------------------------------------------------ builders

## A SurfaceTool ready for the builders.
static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A planar quad a-b-c-d, counter-clockwise seen from the side `n` points to.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, key: Vector2, col := Color.WHITE,
		uv := Rect2(0, 0, 1, 1)) -> void:
	var uvs := [uv.position + Vector2(0, uv.size.y), uv.end, uv.position + Vector2(uv.size.x, 0), uv.position]
	var pts := [a, b, c, d]
	for k in [0, 2, 1, 0, 3, 2]:    # Godot culls counter-clockwise: emit clockwise
		st.set_normal(n)
		st.set_color(col)
		st.set_uv(uvs[k])
		st.set_uv2(key)
		st.add_vertex(pts[k])


## An axis-aligned box from corner `p` (min x, y, z) of `size`. No bottom face
## unless `bottom`; with `edges`, its 12 outline edges (bottom ones as creases
## against the ground).
static func box(st: SurfaceTool, p: Vector3, size: Vector3, key: Vector2, col := Color.WHITE, edges: MotionEdges3D = null, bottom := false) -> void:
	var q := p + size
	var v := func(i: int) -> Vector3:
		return Vector3(q.x if i & 1 else p.x, q.y if i & 2 else p.y, q.z if i & 4 else p.z)
	# corners: bit0 x, bit1 y, bit2 z
	var faces := [
		[[2, 6, 7, 3], Vector3.UP],
		[[4, 5, 7, 6], Vector3.BACK],      # +z (south)
		[[1, 0, 2, 3], Vector3.FORWARD],   # -z (north)
		[[5, 1, 3, 7], Vector3.RIGHT],
		[[0, 4, 6, 2], Vector3.LEFT],
	]
	if bottom:
		faces.append([[0, 1, 5, 4], Vector3.DOWN])
	for fc in faces:
		var ids: Array = fc[0]
		quad(st, v.call(ids[0]), v.call(ids[1]), v.call(ids[2]), v.call(ids[3]), fc[1], key, col)
	if edges:
		var U := Vector3.UP
		var D := Vector3.DOWN
		var S := Vector3.BACK
		var N := Vector3.FORWARD
		var E := Vector3.RIGHT
		var Wv := Vector3.LEFT
		for e in [[2, 3, U, N], [6, 7, U, S], [2, 6, U, Wv], [3, 7, U, E],
				[0, 2, N, Wv], [1, 3, N, E], [4, 6, S, Wv], [5, 7, S, E],
				[0, 1, N, D], [4, 5, S, D], [0, 4, Wv, D], [1, 5, E, D]]:
			edges.add(v.call(e[0]), v.call(e[1]), e[2], e[3], MotionEdges3D.CREASE, key)


## A vertical cylinder standing on `base` (centre of its bottom), with a top
## cap; flat-shaded facets (a crisp poster terminator that is identical in
## perspective and orthographic views), silhouette edges plus both rims.
static func cylinder(st: SurfaceTool, base: Vector3, r: float, h: float, key: Vector2, col := Color.WHITE, edges: MotionEdges3D = null, seg := 14) -> void:
	_tube(st, base, Vector3.UP, Vector3.RIGHT, Vector3.BACK, r, h, key, col, edges, seg, true, false)


## A horizontal (or any) pipe from a to b with flat end caps.
static func pipe(st: SurfaceTool, a: Vector3, b: Vector3, r: float, key: Vector2, col := Color.WHITE, edges: MotionEdges3D = null, seg := 10) -> void:
	var ax := (b - a).normalized()
	var ref := Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT
	var u := ax.cross(ref).normalized()
	var w := u.cross(ax).normalized()
	_tube(st, a, ax, u, w, r, a.distance_to(b), key, col, edges, seg, true, true)


static func _tube(st: SurfaceTool, base: Vector3, ax: Vector3, u: Vector3, w: Vector3, r: float, h: float, key: Vector2, col: Color,
		edges: MotionEdges3D, seg: int, top_cap: bool, bottom_cap: bool, facets := true) -> void:
	var top := base + ax * h
	var ring := PackedVector3Array()
	var nrm := PackedVector3Array()
	for i in seg:
		var a := TAU * i / seg
		var n := u * cos(a) + w * sin(a)
		nrm.append(n)
		ring.append(n * r)
	for i in seg:
		var j := (i + 1) % seg
		# side quad: counter-clockwise seen from outside
		var pts := [base + ring[i], base + ring[j], top + ring[j], top + ring[i]]
		var fnm := (nrm[i] + nrm[j]).normalized()
		var ns := [fnm, fnm, fnm, fnm] if facets else [nrm[i], nrm[j], nrm[j], nrm[i]]
		var order := [0, 2, 1, 0, 3, 2]
		if u.cross(w).dot(ax) < 0.0:
			order = [0, 1, 2, 0, 2, 3]
		for k in order:
			st.set_normal(ns[k])
			st.set_color(col)
			st.set_uv(Vector2.ZERO)
			st.set_uv2(key)
			st.add_vertex(pts[k])
	var flip := u.cross(w).dot(ax) < 0.0
	if top_cap:
		for i in seg:
			var j := (i + 1) % seg
			var tri := [top, top + ring[j], top + ring[i]] if not flip else [top, top + ring[i], top + ring[j]]
			for p in tri:
				st.set_normal(ax)
				st.set_color(col)
				st.set_uv(Vector2.ZERO)
				st.set_uv2(key)
				st.add_vertex(p)
	if bottom_cap:
		for i in seg:
			var j := (i + 1) % seg
			var tri := [base, base + ring[i], base + ring[j]] if not flip else [base, base + ring[j], base + ring[i]]
			for p in tri:
				st.set_normal(-ax)
				st.set_color(col)
				st.set_uv(Vector2.ZERO)
				st.set_uv2(key)
				st.add_vertex(p)
	if edges:
		for i in seg:
			var j := (i + 1) % seg
			var fn := (nrm[i] + nrm[j]).normalized()
			edges.add(top + ring[i], top + ring[j], ax, fn, MotionEdges3D.CREASE, key)
			edges.add(base + ring[i], base + ring[j], -ax, fn, MotionEdges3D.CREASE, key)
			var fp := (nrm[(i + seg - 1) % seg] + nrm[i]).normalized()
			edges.add(base + ring[i], top + ring[i], fp, fn, MotionEdges3D.SMOOTH, key)


## A flat decal quad centred at `c`, spanning `half_u` and `half_v` (world
## vectors, v pointing up in the artwork), mapped to `uv` of the atlas. Lay it
## 0.01-0.03 units off its face.
static func decal(st: SurfaceTool, c: Vector3, half_u: Vector3, half_v: Vector3, uv: Rect2, key: Vector2, col := Color.WHITE) -> void:
	var n := half_u.cross(half_v).normalized()
	quad(st, c - half_u - half_v, c + half_u - half_v, c + half_u + half_v, c - half_u + half_v, n, key, col, uv)
