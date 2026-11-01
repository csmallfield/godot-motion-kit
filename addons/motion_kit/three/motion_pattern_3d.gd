# SPDX-License-Identifier: Apache-2.0
## Patterned 3D surfaces for MotionStage3D worlds: an endless checkerboard
## floor, checker skyscrapers, checkered gantries and signs, all from one
## shader (motion_pattern_3d.gdshader). It is the 3D counterpart of
## MotionPatternPlane: because the pattern lives on real geometry inside the
## stage, depth, occlusion and fog match everything else in the world (a sign
## can rise out of the board, buildings hide the board behind them).
##
##   var board := MotionPattern3D.material(Color("#4b3a7a"), Color("#0b0916"), 8.0)
##   var floor := MotionPattern3D.ground(stage.world, board)
##   # in _frame(f):
##   MotionPattern3D.follow(floor, stage.camera.global_position)
##   board.set_shader_parameter("motion", MotionPattern3D.motion_for(pos_prev, pos_next, 0.5))
##
## Faces built with `box()` carry UVs in metres, so `space = UV` lines the
## cells up with each face's edges whatever the box's rotation.
## Pure: everything is set from uniforms; the ground follows the camera but
## the pattern is world-locked.
@tool
class_name MotionPattern3D
extends RefCounted

const SHADER := preload("res://addons/motion_kit/three/motion_pattern_3d.gdshader")

enum Pattern { CHECKER, STRIPES, GRID, SOLID }
enum Space { WORLD_XZ, UV, TRIPLANAR }


## A pattern material. `cell` in metres; `space` WORLD_XZ for floors, UV for
## faces built with box() (cells line up with the edges), TRIPLANAR for
## anything else. Vertex colours tint color_a.
static func material(color_a := Color.WHITE, color_b := Color.BLACK, cell := 4.0, space := Space.WORLD_XZ, pattern := Pattern.CHECKER) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color_a", color_a)
	m.set_shader_parameter("color_b", color_b)
	m.set_shader_parameter("cell", Vector2(cell, cell))
	m.set_shader_parameter("space", int(space))
	m.set_shader_parameter("pattern", int(pattern))
	return m


## An endless floor: a big plane at height `y` under `parent`. Call follow()
## every frame so its edge never comes into view (the pattern stays put).
static func ground(parent: Node3D, mat: Material, size := 8000.0, y := 0.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = y
	parent.add_child(mi)
	return mi


## Keep a ground() plane centred under the camera.
static func follow(floor: Node3D, camera_pos: Vector3) -> void:
	floor.position = Vector3(camera_pos.x, floor.position.y, camera_pos.z)


## The `motion` uniform for a camera that moves from `a` to `b` in one frame:
## the movement while the shutter is open (0.5 = a 180 degree shutter).
static func motion_for(a: Vector3, b: Vector3, shutter := 0.5) -> Vector3:
	return (b - a) * shutter


## Set the ring shockwave: centre (world point; only x, z count), radius and
## width in metres, colour (alpha = strength) and how far it pushes the
## pattern (cells). radius <= 0 turns it off.
static func ring(mat: ShaderMaterial, centre: Vector3, radius: float, width := 4.0, col := Color(1, 1, 1, 0), push := 0.0) -> void:
	mat.set_shader_parameter("ring", Vector4(centre.x, centre.z, radius, width))
	mat.set_shader_parameter("ring_color", col)
	mat.set_shader_parameter("ring_push", push)


## Sprout geometry by a key: model-space y (put the ground at the mesh's
## y = 0) is scaled by 1 - smoothstep(from, to, UV2.x - key). With towers
## keyed by track distance and `key` = the camera's distance, the city lies
## flat far ahead and rises as you approach (keeping a horizon or a sun in
## view). `from >= to` turns it off.
static func grow(mat: ShaderMaterial, key: float, from: float, to: float) -> void:
	mat.set_shader_parameter("grow", Vector3(key, from, to))


## One quad (a, b, c, d counter-clockwise or not: the material draws both
## sides) with UVs in metres: u along a->b, v along a->d. UV2.x = `uv2x`
## (a light-window key: track distance, height...).
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv2x := 0.0, uv0 := Vector2.ZERO) -> void:
	var w := a.distance_to(b)
	var h := a.distance_to(d)
	var uv := [uv0, uv0 + Vector2(w, 0), uv0 + Vector2(w, h), uv0 + Vector2(0, h)]
	var pts := [a, b, c, d]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_uv(uv[k])
		st.set_uv2(Vector2(uv2x, 0))
		st.add_vertex(pts[k])


## A box of `size` centred at xform's origin, oriented by its basis, with UVs
## in metres on every face (v runs up the side faces from the bottom, so
## checks start whole at the base). `top` colours the roof (default `col`).
static func box(st: SurfaceTool, xform: Transform3D, size: Vector3, col: Color, uv2x := 0.0, top := Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return xform * Vector3(x * h.x, y * h.y, z * h.z)
	var tc := top if top.a > 0.0 else col
	# sides: bottom edge first, so v = height above the base
	quad(st, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col, uv2x)      # +Z
	quad(st, p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), col, uv2x)  # -Z
	quad(st, p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), col, uv2x)      # +X
	quad(st, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col, uv2x)  # -X
	quad(st, p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), tc, uv2x)       # top
	quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), col, uv2x)  # bottom
