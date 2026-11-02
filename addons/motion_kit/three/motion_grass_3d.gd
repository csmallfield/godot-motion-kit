# SPDX-License-Identifier: Apache-2.0
## Grass tufts for the flat graphic look: a MultiMesh of small flat tuft
## cards (three blades), scattered by a seeded hash over a rectangle (with an
## optional mask), coloured per instance, swaying in the wind and pushed
## over by MotionRipples rings. One draw call for the whole field.
##
##   var ripples := MotionRipples.new()
##   var grass := MotionGrass3D.field(Rect2(-8, -7, 16, 13), 6.0, Color("#6fb34f"), 3,
##       func(p: Vector2) -> bool: return not on_path(p))
##   add_child(grass)
##   ripples.register(grass.material_override as ShaderMaterial)
##   flat.register(grass.material_override, false)    # fog with the look
##   # every frame: ripples.step(dt); ripples.apply(); MotionGrass3D.tick(grass, time)
##
## Tufts are cards in the XY plane turned to face the camera's yaw (`facing`)
## and leaned back by `lean` toward a pitched camera, like cutout cards.
@tool
class_name MotionGrass3D
extends RefCounted

const SHADER := preload("res://addons/motion_kit/three/motion_grass_3d.gdshader")


## A field of tufts: `density` per square metre over `rect` (world x, z),
## base colour varied per tuft, `seed`, `mask(p: Vector2) -> bool` to keep
## a tuft. Options: height (0.22), width (0.2), lean_deg (25), facing (yaw
## radians, 0 = facing +Z), variation (0.12).
static func field(rect: Rect2, density: float, color: Color, seed := 1, mask := Callable(), opts := {}) -> MultiMeshInstance3D:
	var h: float = opts.get("height", 0.22)
	var w: float = opts.get("width", 0.2)
	var lean := deg_to_rad(float(opts.get("lean_deg", 25.0)))
	var yaw: float = opts.get("facing", 0.0)
	var vary: float = opts.get("variation", 0.12)
	var pts: Array[Vector2] = []
	var n := int(rect.get_area() * density)
	for i in n:
		var p := rect.position + Vector2(MK.rand(i * 1.13 + seed * 7.1), MK.rand(i * 2.71 + seed * 3.3)) * rect.size
		if mask.is_valid() and not mask.call(p):
			continue
		pts.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft_mesh(w, h)
	mm.instance_count = pts.size()
	for i in pts.size():
		var s := 0.75 + MK.rand(i * 5.9 + seed) * 0.5
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -lean) * Basis.from_scale(Vector3(s * (1.0 if MK.rand(i * 9.1) < 0.5 else -1.0), s, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(pts[i].x, 0.0, pts[i].y)))
		var k := 1.0 + (MK.rand(i * 3.7 + seed * 2.0) - 0.5) * 2.0 * vary
		mm.set_instance_color(i, Color(color.r * k, color.g * k, color.b * k, 1.0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## One tuft: three tapered blades in the XY plane, root at the origin.
## Vertex alpha is height along the blade (the shader bends tips only).
static func tuft_mesh(w := 0.2, h := 0.22) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in [[-0.32, 0.8, -0.18], [0.0, 1.0, 0.04], [0.3, 0.75, 0.2]]:
		var x0: float = b[0] * w
		var hh: float = b[1] * h
		var tilt: float = b[2] * w
		var half := w * 0.16
		for v in [[x0 - half, 0.0, 0.0], [x0 + half, 0.0, 0.0], [x0 + tilt, hh, 1.0]]:
			st.set_color(Color(1, 1, 1, v[2]))
			st.set_normal(Vector3.BACK)
			st.add_vertex(Vector3(v[0], v[1], 0.0))
	return st.commit()


## Advance the wind (call every frame with a time in seconds).
static func tick(grass: MultiMeshInstance3D, time_s: float) -> void:
	(grass.material_override as ShaderMaterial).set_shader_parameter(&"time_s", time_s)
