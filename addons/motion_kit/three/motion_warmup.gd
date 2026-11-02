# SPDX-License-Identifier: Apache-2.0
## Hitch prevention at load: draw every material in a scene once, out of
## sight, so shaders and pipelines compile during loading rather than on the
## frame something first appears (a hit flash's first use, an enemy walking
## on screen, a cave). Godot 4.4+ Forward+ compiles ubershaders in the
## background, which removes most of these hitches; this covers the rest,
## and the Compatibility renderer, which has no such fallback.
##
##   await MotionWarmup.run(camera, MotionWarmup.collect(get_tree().current_scene))
##
## Also call MotionSvg.prewarm() for 2D SVG rasters and warm audio (the audio
## kit's pools) at the same time.
@tool
class_name MotionWarmup
extends RefCounted


## Every distinct material used under `root`: overrides, surface overrides,
## mesh surface materials, MultiMesh meshes.
static func collect(root: Node) -> Array[Material]:
	var seen := {}
	var out: Array[Material] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(true):
			stack.append(c)
		var mats: Array = []
		if n is GeometryInstance3D:
			mats.append((n as GeometryInstance3D).material_override)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					mats.append(mi.get_surface_override_material(s))
					mats.append(mi.mesh.surface_get_material(s))
		if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh and (n as MultiMeshInstance3D).multimesh.mesh:
			var mm := (n as MultiMeshInstance3D).multimesh.mesh
			for s in mm.get_surface_count():
				mats.append(mm.surface_get_material(s))
		for m in mats:
			if m is Material and not seen.has(m):
				seen[m] = true
				out.append(m)
	return out


## Draw each material on a tiny quad just in front of `camera` for `frames`
## frames, then remove them. Await it during loading (behind a cover, a
## title card or a black frame).
static func run(camera: Camera3D, materials: Array[Material], frames := 2) -> void:
	if camera == null or materials.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "MotionWarmup"
	camera.add_child(holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.001, 0.001)
	var d := maxf(camera.near * 4.0, 0.2)
	for i in materials.size():
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = materials[i]
		mi.position = Vector3(float(i % 16) * 0.0005, float(i / 16) * 0.0005, -d)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	for f in frames:
		await camera.get_tree().process_frame
	holder.queue_free()
