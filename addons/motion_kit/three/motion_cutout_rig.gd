# SPDX-License-Identifier: Apache-2.0
## A cutout character from one SVG: every rig part a flat card on its own
## pivot node, nested as the SVG's groups are, stacked in document order, with
## outlines. Pose parts by rotation and offset in the card plane, and reach
## with two-bone IK (solve_limb). One view per SVG; MotionCutout switches
## between front, back and side views.
##
## Authoring convention (no sidecar needed):
##   - A rig part is a `<g id="name">` holding a pivot marker: an element whose
##     id starts with "pivot" (a small `<circle id="pivot-knee" fill="none">`).
##     The marker's centre is the part's pivot; it is never drawn.
##   - Parts nest as their groups nest: `<g id="thigh"> ... <g id="shin">`.
##   - Document order is draw order. Inside a group, children may come before
##     the group's own shapes (an arm behind the torso it belongs to).
##   - Elements with class "flat" get no outline (eyes, blush, highlights).
##   - Shapes outside every rig part belong to the root (pivot at `origin`).
## `overrides` = {part: {pivot: Vector2, parent: "name"}} adjusts any of it.
##
##   var rig := MotionCutoutRig.build(data, 0.8, flat.cutout(), flat.edges(ink, 2.6, 0.001),
##       {origin = Vector2(110, 318)})
##   rig.pose(&"head", deg_to_rad(8))
##   rig.solve_limb(&"arm_r_upper", &"arm_r_lower", &"hand_r", hand_target, -1.0)
##
## Card-local frame: x right, y up, the card faces +Z; parts sit at
## z = element index × `layer`. Keep the outline material's depth bias below
## `layer`, or a back part's outline draws over the part in front of it.
@tool
class_name MotionCutoutRig
extends Node3D

## Part name -> pivot node (its rest transform is `rest[name]`).
var parts := {}
## Part name -> MeshInstance3D (absent for parts with no shapes of their own).
var meshes := {}
## Part name -> outline MeshInstance3D.
var outlines := {}
## Part name -> rest transform relative to its parent node.
var rest := {}
## Part name -> parent part name (&"" = the rig itself).
var parent_of := {}
## Part name -> pivot in SVG units.
var pivot_svg := {}
## Metres per SVG unit, and the SVG point at the rig's origin.
var k := 0.01
var origin_svg := Vector2.ZERO
## Depth between stacked elements (the `layer` build option).
var layer_step := 0.004
var _z_cache := {}
## The material the parts were built with when it is an actor material
## (MotionFlat3D.actor): flash and tint go to it as plain uniforms.
var actor_material: ShaderMaterial


## Build a rig from `data`, `width` metres wide. Options: origin (SVG point
## at the node origin; default bottom centre of the viewBox), layer (0.004),
## tolerance (0.5), pivot_prefix ("pivot"), flat_class ("flat"), overrides.
static func build(data: MotionSvgData, width: float, material: Material, outline_material: Material = null, opts := {}) -> MotionCutoutRig:
	var rig := MotionCutoutRig.new()
	if material is ShaderMaterial and (material as ShaderMaterial).shader == MotionFlat3D.CUTOUT_ACTOR:
		rig.actor_material = material
	var vb := data.view_box
	rig.k = width / vb.size.x
	rig.origin_svg = opts.get("origin", Vector2(vb.position.x + vb.size.x * 0.5, vb.end.y))
	var layer: float = opts.get("layer", 0.004)
	rig.layer_step = layer
	var tol: float = opts.get("tolerance", 0.5)
	var prefix: String = opts.get("pivot_prefix", "pivot")
	var flat_class: String = opts.get("flat_class", "flat")
	var overrides: Dictionary = opts.get("overrides", {})

	# 1. rig parts: groups holding a pivot marker (or named in overrides)
	var is_part := {}
	for i in data.parts.size():
		var p: Dictionary = data.parts[i]
		var gs: PackedStringArray = p.groups
		if String(p.id).begins_with(prefix) and not gs.is_empty():
			var name := gs[gs.size() - 1]
			is_part[name] = true
			rig.pivot_svg[StringName(name)] = data.centre(i)
	for name in overrides:
		is_part[String(name)] = true
		var o: Dictionary = overrides[name]
		if o.has("pivot"):
			rig.pivot_svg[StringName(name)] = o.pivot
	# 2. hierarchy and element ownership from each element's group chain
	var owned := {}        # part -> [element indices]
	var outlined := {}     # part -> [element indices]
	for i in data.parts.size():
		var p: Dictionary = data.parts[i]
		var chain: Array[StringName] = []
		for g in (p.groups as PackedStringArray):
			if is_part.has(g):
				chain.append(StringName(g))
		for c in chain.size():
			if not rig.parent_of.has(chain[c]):
				rig.parent_of[chain[c]] = chain[c - 1] if c > 0 else &""
		if String(p.id).begins_with(prefix):
			continue
		var fill: Color = p.fill
		if fill.a <= 0.0:
			continue
		var owner: StringName = chain[chain.size() - 1] if not chain.is_empty() else &""
		(owned.get_or_add(owner, []) as Array).append(i)
		if not (p.classes as PackedStringArray).has(flat_class):
			(outlined.get_or_add(owner, []) as Array).append(i)
	for name in overrides:
		var o: Dictionary = overrides[name]
		if o.has("parent"):
			rig.parent_of[StringName(name)] = StringName(o.parent)
		elif not rig.parent_of.has(StringName(name)):
			rig.parent_of[StringName(name)] = &""
	# 3. nodes, parents first
	var order := rig._ordered()
	for name: StringName in order:
		var node := Node3D.new()
		node.name = String(name)
		var par: StringName = rig.parent_of[name]
		var t := Transform3D(Basis(), rig.svg_to_local(rig.pivot_svg[name]) - (rig.svg_to_local(rig.pivot_svg[par]) if par != &"" else Vector3.ZERO))
		node.transform = t
		rig.rest[name] = t
		rig.parts[name] = node
		(rig if par == &"" else rig.parts[par] as Node3D).add_child(node)
	# 4. meshes: each part's own shapes, around its pivot
	for owner: StringName in owned:
		var host: Node3D = rig if owner == &"" else rig.parts[owner]
		var piv := rig.svg_to_local(rig.pivot_svg[owner]) if owner != &"" else Vector3.ZERO
		var xf := Transform3D(Basis(), rig.svg_to_local(vb.position) - piv)
		var mopts := {flat = true, depth = 0.0, layer = layer, anchor = Vector2.ZERO, tolerance = tol, only = owned[owner]}
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		MotionSvgMesh.append(st, data, width, mopts, xf)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = st.commit()
		mi.material_override = material
		host.add_child(mi)
		rig.meshes[owner] = mi
		if outline_material and outlined.has(owner):
			var eo := mopts.duplicate()
			eo["only"] = outlined[owner]
			var est := SurfaceTool.new()
			est.begin(Mesh.PRIMITIVE_TRIANGLES)
			MotionSvgMesh.append(est, data, width, eo, xf)
			var em := MotionEdges3D.from_mesh(est.commit(), {kind = MotionEdges3D.ALWAYS, crease_deg = 89.0})
			var ei := MeshInstance3D.new()
			ei.name = "Outline"
			ei.mesh = em
			ei.material_override = outline_material
			host.add_child(ei)
			rig.outlines[owner] = ei
	return rig


## A single flat card from an SVG (a prop: a sword, a sign, a pouch): every
## part stacked `layer` apart toward +Z, `anchor` (fractions of the viewBox)
## at the origin, outlines on every part without class "flat". For anything
## that moves in parts, build() a rig instead.
static func card(data: MotionSvgData, width: float, material: Material, outline_material: Material = null, anchor := Vector2(0.5, 1.0), layer := 0.012) -> MeshInstance3D:
	var opts := {flat = true, depth = 0.0, layer = layer, anchor = anchor}
	var mi := MeshInstance3D.new()
	mi.mesh = MotionSvgMesh.build(data, width, opts)
	mi.material_override = material
	if outline_material:
		var only := []
		for i in data.parts.size():
			if not (data.parts[i].classes as PackedStringArray).has("flat"):
				only.append(i)
		if not only.is_empty():
			var eo := opts.duplicate()
			eo["only"] = only
			var edges := MeshInstance3D.new()
			edges.name = "Outline"
			edges.mesh = MotionEdges3D.from_mesh(MotionSvgMesh.build(data, width, eo), {kind = MotionEdges3D.ALWAYS, crease_deg = 89.0})
			edges.material_override = outline_material
			mi.add_child(edges)
	return mi


## An SVG point in rig-local metres (z 0).
func svg_to_local(p: Vector2) -> Vector3:
	return Vector3((p.x - origin_svg.x) * k, -(p.y - origin_svg.y) * k, 0.0)


func has_part(name: StringName) -> bool:
	return parts.has(name)


func part(name: StringName) -> Node3D:
	return parts.get(name)


## A part's pivot at rest, in rig-local metres.
func rest_pivot(name: StringName) -> Vector3:
	return svg_to_local(pivot_svg[name])


## Every part back to its rest transform.
func reset_pose() -> void:
	for name in parts:
		(parts[name] as Node3D).transform = rest[name]


## Pose a part relative to rest: rotation (radians, counter-clockwise in the
## card plane), offset (metres in its parent's card plane), scale.
func pose(name: StringName, rot := 0.0, offset := Vector2.ZERO, scale_ := Vector2.ONE) -> void:
	var r: Transform3D = rest[name]
	(parts[name] as Node3D).transform = Transform3D(
			Basis(Vector3.BACK, rot) * Basis.from_scale(Vector3(scale_.x, scale_.y, 1.0)),
			r.origin + Vector3(offset.x, offset.y, 0.0))


## Move a part (and everything hanging from it) toward the camera (+) or
## away (-) by `dz` metres, on top of its pose: a sword arm drawn behind the
## body brought in front for a swing's active frames. Call after pose() or
## solve_limb() each frame (reset_pose() clears it). front_depth() and
## back_depth() give the offsets that clear every other part. Under a
## MotionCutout with shear_depth the part stays put on screen.
func depth(name: StringName, dz: float) -> void:
	var n := parts[name] as Node3D
	n.position.z = (rest[name] as Transform3D).origin.z + dz


## The depth offset that puts `name` and its children in front of every
## other part of this rig (one layer clear).
func front_depth(name: StringName) -> float:
	var own := _subtree_z(name)
	var all := _subtree_z(&"")
	return all.y - own.x + layer_step


## The depth offset that puts `name` and its children behind every other
## part of this rig (one layer clear).
func back_depth(name: StringName) -> float:
	var own := _subtree_z(name)
	var all := _subtree_z(&"")
	return all.x - own.y - layer_step


## (min, max) mesh depth of a part and everything under it, at rest ("" for
## the whole rig).
func _subtree_z(name: StringName) -> Vector2:
	if _z_cache.has(name):
		return _z_cache[name]
	var lo := INF
	var hi := -INF
	for owner: StringName in meshes:
		var n := owner
		var inside := name == &""
		while not inside and n != &"":
			inside = n == name
			n = parent_of.get(n, &"")
		if inside:
			var bb := (meshes[owner] as MeshInstance3D).mesh.get_aabb()
			lo = minf(lo, bb.position.z)
			hi = maxf(hi, bb.end.z)
	var r := Vector2(lo, hi) if lo <= hi else Vector2.ZERO
	_z_cache[name] = r
	return r


## A part's current transform in rig-local space (no scene tree needed).
func rig_transform(name: StringName) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := name
	while n != &"":
		t = (parts[n] as Node3D).transform * t
		n = parent_of[n]
	return t


## Two-bone IK on a chain upper -> lower -> tip: rotate `upper` and `lower`
## (keeping their offsets) so the tip's pivot lands on `target` (rig-local,
## x and y used). `bend` +1 / -1 picks the side the middle joint goes.
## Returns true when the target was in reach.
func solve_limb(upper: StringName, lower: StringName, tip: StringName, target: Vector3, bend := 1.0) -> bool:
	var a0 := rest_pivot(upper)
	var b0 := rest_pivot(lower)
	var c0 := rest_pivot(tip)
	var l1 := Vector2(b0.x - a0.x, b0.y - a0.y).length()
	var l2 := Vector2(c0.x - b0.x, c0.y - b0.y).length()
	var par: StringName = parent_of[upper]
	var pt := rig_transform(par) if par != &"" else Transform3D.IDENTITY
	var root3 := pt * (rest[upper] as Transform3D).origin
	var root := Vector2(root3.x, root3.y)
	var s := MotionIK.two_bone_2d(root, Vector2(target.x, target.y), l1, l2, bend)
	var mid: Vector2 = s.mid
	var end: Vector2 = s.end
	var par_rot := atan2(pt.basis.x.y, pt.basis.x.x)
	var up_rest := Vector2(b0.x - a0.x, b0.y - a0.y).angle()
	var lo_rest := Vector2(c0.x - b0.x, c0.y - b0.y).angle()
	var up_rot := (mid - root).angle() - up_rest
	pose(upper, wrapf(up_rot - par_rot, -PI, PI))
	pose(lower, wrapf((end - mid).angle() - lo_rest - up_rot, -PI, PI))
	return s.reached


## Hit flash on every part (rgb toward `color` by `amount`).
## Hit flash on the whole rig. With an actor material (MotionFlat3D.actor)
## it is one uniform on that material (every view sharing it flashes
## together); with the shared cutout() material, an instance uniform per part.
func set_flash(color: Color, amount: float) -> void:
	if actor_material:
		MotionFlat3D.set_actor_flash(actor_material, color, amount)
		return
	for m in meshes.values():
		MotionFlat3D.set_flash(m, color, amount)


## Multiply the whole rig's colour (actor material or per part, as set_flash).
func set_tint(color: Color) -> void:
	if actor_material:
		actor_material.set_shader_parameter(&"tint", color)
		return
	for m in meshes.values():
		MotionFlat3D.set_tint(m, color)



## Parent names before children.
func _ordered() -> Array[StringName]:
	var out: Array[StringName] = []
	var seen := {}
	var visit := func(n: StringName, me: Callable) -> void:
		if seen.has(n):
			return
		var p: StringName = parent_of[n]
		if p != &"":
			me.call(p, me)
		seen[n] = true
		out.append(n)
	for n: StringName in parent_of:
		visit.call(n, visit)
	return out
