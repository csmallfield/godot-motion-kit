# SPDX-License-Identifier: Apache-2.0
## An orthographic camera for MotionExtrude scenes (2.5D extruded solids drawn
## into a MotionCanvas). World axes: x east, y north, z up.
##
## `yaw` turns the camera around the vertical axis (0 = standing south, looking
## north; positive swings it east), `pitch` raises it (0 = a flat front
## elevation, 35.26 = true isometric with yaw 45, 90 = a plan seen from above).
## Blending yaw and pitch to 0 turns an isometric view into a perfectly flat
## front view, so anything on a south-facing face ends up readable as 2D.
##
##   var cam := MotionExtrudeCamera.new()
##   cam.yaw = 40; cam.pitch = 32; cam.scale = 90; cam.target = Vector3(10, 6, 0)
##   cam.update()
##   var p := cam.project(Vector3(1, 2, 3))
@tool
class_name MotionExtrudeCamera
extends RefCounted

## Degrees around the vertical; 0 looks north from the south.
var yaw := 45.0
## Degrees above the horizon; 0 = front elevation, 90 = plan.
var pitch := 35.264
## The world point drawn at `centre`.
var target := Vector3.ZERO
## Pixels per world unit.
var scale := 100.0
## Where `target` lands on screen.
var centre := Vector2(960, 540)
## Screen-space roll in degrees (a Dutch angle), applied about `centre`.
var roll := 0.0

## Camera basis after update(): right and up span the screen, forward points
## into the scene (bigger depth = farther away).
var right := Vector3.RIGHT
var up := Vector3.UP
var forward := Vector3.FORWARD
## Horizontal part of `forward`, for painter's ordering on a ground plan.
var forward_h := Vector3(0, 1, 0)

var _rx := Vector2(1, 0)
var _ry := Vector2(0, 1)


## Recompute the basis. Call after changing yaw, pitch or roll.
func update() -> MotionExtrudeCamera:
	var th := deg_to_rad(yaw)
	var ph := deg_to_rad(pitch)
	var to_cam := Vector3(cos(ph) * sin(th), -cos(ph) * cos(th), sin(ph))
	forward = -to_cam
	right = Vector3(cos(th), sin(th), 0.0)
	up = right.cross(forward)
	forward_h = Vector3(-sin(th), cos(th), 0.0)
	var r := deg_to_rad(roll)
	_rx = Vector2(cos(r), sin(r))
	_ry = Vector2(-sin(r), cos(r))
	return self


## A world direction as a screen vector (no translation): the linear part of project().
func vec(v: Vector3) -> Vector2:
	var sx := v.dot(right) * scale
	var sy := -v.dot(up) * scale
	return _rx * sx + _ry * sy


## A world point on screen.
func project(p: Vector3) -> Vector2:
	return centre + vec(p - target)


## Distance into the scene along the view direction (bigger = farther).
func depth(p: Vector3) -> float:
	return (p - target).dot(forward)


## Painter's key for something standing on the ground at `p` (bigger = farther).
func ground_key(p: Vector3) -> float:
	return Vector3(p.x - target.x, p.y - target.y, 0.0).dot(forward_h)


## True when a face with outward normal `n` faces the camera.
func facing(n: Vector3) -> bool:
	return n.dot(forward) < -1e-5


## The screen transform of a plane through `origin` spanned by world vectors
## `a` and `b`: local (x, y) maps to origin + x * a + y * b. Draw into it with
## CanvasItem.draw_set_transform_matrix, or set it on a node (a MotionSvg on a face).
func plane_transform(origin: Vector3, a: Vector3, b: Vector3) -> Transform2D:
	return Transform2D(vec(a), vec(b), project(origin))


## The MotionLens3D that draws this view of a MotionStage3D scene (Godot axes,
## see MotionLens3D.from_extrude): orthographic, same yaw, pitch, roll, scale
## and centre, so lens.project(MotionLens3D.from_extrude(p)) == project(p).
func to_lens(screen := Vector2(1920, 1080)) -> MotionLens3D:
	var l := MotionLens3D.extrude(yaw, pitch, scale, MotionLens3D.from_extrude(target), centre, screen)
	if roll != 0.0:
		var r := deg_to_rad(roll)
		var b := l.basis
		l.basis = Basis(b.x * cos(r) + b.y * sin(r), b.y * cos(r) - b.x * sin(r), b.z)
	return l
