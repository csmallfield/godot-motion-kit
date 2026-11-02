# SPDX-License-Identifier: Apache-2.0
## Analytic two-bone IK (law of cosines), in 2D and 3D. Godot 4.5 has no
## TwoBoneIK3D, and cutout rigs are plain nodes, so these are pure functions:
## give the root joint, the target and the two bone lengths, get the middle
## joint (knee, elbow) and where the end lands.
##
##   var s := MotionIK.two_bone_2d(hip, foot_target, thigh, shin, 1.0)
##   thigh_node.rotation = (s.mid - hip).angle() - thigh_rest_angle
##
## Out of reach, the chain straightens toward the target (`reached` false);
## closer than |l1 - l2| it folds as far as it can. MotionCutoutRig.solve_limb
## applies the 2D solve to a rig's parts.
class_name MotionIK
extends RefCounted


## 2D solve. `bend` +1 puts the middle joint counter-clockwise of the
## root→target line (y up), -1 clockwise. Returns {mid, end, reached}.
static func two_bone_2d(root: Vector2, target: Vector2, l1: float, l2: float, bend := 1.0) -> Dictionary:
	var d := target - root
	var dist := d.length()
	var dir := d / dist if dist > 1e-9 else Vector2.RIGHT
	var r := clampf(dist, absf(l1 - l2) + 1e-6, l1 + l2 - 1e-6)
	var cos_a := clampf((l1 * l1 + r * r - l2 * l2) / (2.0 * l1 * r), -1.0, 1.0)
	var a := acos(cos_a) * (1.0 if bend >= 0.0 else -1.0)
	var mid := root + dir.rotated(a) * l1
	return {mid = mid, end = root + dir * r, reached = dist <= l1 + l2}


## 3D solve. The middle joint bends toward `pole` (a point the knee or elbow
## should point at). Returns {mid, end, reached}.
static func two_bone_3d(root: Vector3, target: Vector3, pole: Vector3, l1: float, l2: float) -> Dictionary:
	var d := target - root
	var dist := d.length()
	var dir := d / dist if dist > 1e-9 else Vector3.FORWARD
	var r := clampf(dist, absf(l1 - l2) + 1e-6, l1 + l2 - 1e-6)
	var cos_a := clampf((l1 * l1 + r * r - l2 * l2) / (2.0 * l1 * r), -1.0, 1.0)
	var side := (pole - root) - dir * (pole - root).dot(dir)
	if side.length_squared() < 1e-12:
		side = dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).cross(dir)
	side = side.normalized()
	var mid := root + dir * (cos_a * l1) + side * (sqrt(maxf(0.0, 1.0 - cos_a * cos_a)) * l1)
	return {mid = mid, end = root + dir * r, reached = dist <= l1 + l2}
