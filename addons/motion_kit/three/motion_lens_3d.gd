# SPDX-License-Identifier: Apache-2.0
## A camera pose for MotionStage3D that blends smoothly between perspective
## and orthographic projection (a dolly zoom with no pop at the switch), and
## that can match a MotionExtrudeCamera view exactly, so a real 3D scene can
## land in the precise isometric (or any yaw/pitch) orthographic view of the
## 2.5D extrusion pieces.
##
## A lens frames a `target`: `frame_h` world units fit the screen height on the
## plane through the target facing the camera. `persp` scales the perspective:
## 1 is a plain camera with vertical `fov`; towards 0 the field of view narrows
## while the camera backs away so the target keeps its size (k = tan(fov/2) *
## persp, distance = frame_h / 2k); once the camera would be farther than
## `ortho_at` it becomes a true orthographic camera of size frame_h, where the
## remaining perspective (depth range / distance) is far below a pixel.
##
##   var fly := MotionLens3D.look(cam_pos, look_at, 62.0)       # a free camera
##   var iso := MotionLens3D.extrude(45.0, 35.264, 110.0, plaza) # MotionExtrudeCamera parity
##   fly.mix(iso, MK.map(f, [200, 240], [0, 1], MK.ease_in_out)).apply(stage.camera)
##
## `mix` moves the target, turns the view (slerp), scales frame_h in log space
## and lerps perspective strength k linearly, which reads as an even
## flattening. Pass a separate `t_lens` to flatten later than the camera turns
## (lift first, then flatten), which keeps the backing-away camera clear of
## the scene.
@tool
class_name MotionLens3D
extends RefCounted

## The framed point.
var target := Vector3.ZERO
## Camera orientation (-Z looks at the target).
var basis := Basis()
## World units across the screen height at the target.
var frame_h := 10.0
## Perspective strength: 1 = `fov`, 0 = orthographic.
var persp := 1.0
## Vertical field of view in degrees at persp 1.
var fov := 60.0
## Screen offset of the target from the centre, in pixels (+y down); a
## MotionExtrudeCamera's `centre` minus the screen centre.
var offset := Vector2.ZERO
## Scene depth kept in front of the target (the near plane sits there once
## the camera is far away) and behind it (far plane).
var keep := 60.0
var depth := 400.0
## Distance beyond which the lens switches to a true orthographic camera.
var ortho_at := 20000.0
## Nearest near plane in perspective (raise it for depth precision on decals
## and ground markings a few millimetres apart).
var near_min := 0.05
## Screen height in pixels (for `offset` and extrude parity).
var view_h := 1080.0


## A free perspective camera at `from` looking at `at` (the framed target).
static func look(from: Vector3, at: Vector3, fov_deg := 60.0, up := Vector3.UP, roll := 0.0) -> MotionLens3D:
	var l := MotionLens3D.new()
	l.target = at
	l.basis = Basis.looking_at(at - from, up)
	if roll != 0.0:
		l.basis = l.basis * Basis(Vector3.FORWARD, roll)
	l.fov = fov_deg
	l.frame_h = 2.0 * from.distance_to(at) * tan(deg_to_rad(fov_deg) * 0.5)
	return l


## A lens from any camera transform: frames the point `focus` units ahead.
static func from_transform(xf: Transform3D, fov_deg := 60.0, focus := 10.0) -> MotionLens3D:
	var l := MotionLens3D.new()
	l.basis = xf.basis.orthonormalized()
	l.target = xf.origin - l.basis.z * focus
	l.fov = fov_deg
	l.frame_h = 2.0 * focus * tan(deg_to_rad(fov_deg) * 0.5)
	return l


## The orthographic view a MotionExtrudeCamera with these values draws: yaw,
## pitch in degrees (45 / 35.264 = true isometric), `scale` pixels per world
## unit, `target` in Godot axes, the target drawn at `centre` (pixels).
## Extrude axes map to Godot as x -> x, y (north) -> -z, z (up) -> y; use
## `from_extrude()` to convert points.
static func extrude(yaw: float, pitch: float, scale: float, at: Vector3, centre := Vector2(960, 540), screen := Vector2(1920, 1080)) -> MotionLens3D:
	var l := MotionLens3D.new()
	l.target = at
	l.basis = extrude_basis(yaw, pitch)
	l.frame_h = screen.y / scale
	l.view_h = screen.y
	l.persp = 0.0
	l.offset = centre - screen * 0.5
	return l


## Camera basis matching MotionExtrudeCamera(yaw, pitch) in Godot axes.
static func extrude_basis(yaw: float, pitch: float) -> Basis:
	var th := deg_to_rad(yaw)
	var ph := deg_to_rad(pitch)
	var to_cam := Vector3(cos(ph) * sin(th), sin(ph), cos(ph) * cos(th))
	var right := Vector3(cos(th), 0.0, -sin(th))
	var up := to_cam.cross(right)
	return Basis(right, up, to_cam)


## A MotionExtrude (x east, y north, z up) point in Godot axes.
static func from_extrude(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, -p.y)


## Perspective strength as tan(half fov): what mix() interpolates.
func k() -> float:
	return tan(deg_to_rad(fov) * 0.5) * clampf(persp, 0.0, 1.0)


## Camera distance from the target at this persp (`keep` + 1 once orthographic,
## where the orthographic camera sits).
func camera_distance() -> float:
	if is_ortho():
		return keep + 1.0
	return frame_h / (2.0 * k())


func is_ortho() -> bool:
	var kk := k()
	return kk <= 1e-9 or frame_h / (2.0 * kk) >= ortho_at


## The camera transform (orthographic lenses sit `keep` + 1 in front of the target).
func transform() -> Transform3D:
	var d := camera_distance()
	return Transform3D(basis.orthonormalized(), target + basis.orthonormalized().z * d)


## A blend towards `b`; `t_lens` (default t) times the perspective change separately.
func mix(b: MotionLens3D, t: float, t_lens := -1.0) -> MotionLens3D:
	var tl := t if t_lens < 0.0 else t_lens
	var l := MotionLens3D.new()
	l.target = target.lerp(b.target, t)
	l.basis = Basis(basis.orthonormalized().get_rotation_quaternion().slerp(b.basis.orthonormalized().get_rotation_quaternion(), t))
	l.frame_h = exp(lerpf(log(frame_h), log(b.frame_h), t))
	l.offset = offset.lerp(b.offset, t)
	l.keep = lerpf(keep, b.keep, t)
	l.depth = lerpf(depth, b.depth, t)
	l.view_h = lerpf(view_h, b.view_h, t)
	l.ortho_at = ortho_at
	l.near_min = near_min
	# perspective strength: lerp k, keep the wider fov's shape, recover persp
	var ka := k()
	var kb := b.k()
	l.fov = maxf(fov, b.fov)
	var kmax := tan(deg_to_rad(l.fov) * 0.5)
	l.persp = lerpf(ka, kb, tl) / kmax
	return l


## Place a Camera3D: projection, fov or size, near/far, transform, offsets.
func apply(cam: Camera3D) -> void:
	var px := frame_h / view_h        # world units per pixel at the target
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.transform = transform()
	if is_ortho():
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = frame_h
		cam.near = 0.05
		cam.far = keep + 1.0 + depth
		# shift the camera in its own plane: the target lands `offset` px off centre
		cam.h_offset = -offset.x * px
		cam.v_offset = offset.y * px
		cam.frustum_offset = Vector2.ZERO
	else:
		# A frustum projection: Camera3D clamps `fov` to 1 degree or more, but
		# the dolly zoom needs far narrower; the near-plane size has no limit.
		# The offset becomes a lens shift (no parallax), as on the target plane.
		var d := camera_distance()
		var near := maxf(near_min, d - keep)
		var near_h := 2.0 * near * k()
		cam.projection = Camera3D.PROJECTION_FRUSTUM
		cam.near = near
		cam.far = d + depth
		cam.size = near_h
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.frustum_offset = Vector2(-offset.x, offset.y) * (near_h / view_h)


## Where a world point lands on screen with this lens (pixels), without a camera.
func project(p: Vector3, screen := Vector2(1920, 1080)) -> Vector2:
	var b := basis.orthonormalized()
	var rel := p - target
	var x := rel.dot(b.x)
	var y := rel.dot(b.y)
	var s := view_h / frame_h
	if not is_ortho():
		var d := camera_distance()
		var z := d - rel.dot(b.z)
		s *= d / maxf(z, 1e-4)
	return screen * 0.5 + offset + Vector2(x, -y) * s
