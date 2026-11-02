# SPDX-License-Identifier: Apache-2.0
## A verlet rope or chain with a pinned root: scarves, capes, tails, hair,
## dangling props. Fixed-step and time-corrected (a slowed clock keeps the
## motion consistent), with length constraints, shape memory relative to the
## root (so a cape swings round when the root turns, unlike MotionCable's
## analytic sag), air drag against a moving medium, frame acceleration, an
## optional floor and sphere colliders. Works in 2D (keep z at 0) and 3D.
##
##   var scarf := MotionChain.new(10, 0.05, root_xf, Vector3.DOWN)
##   scarf.drag = 3.0
##   # _physics_process, on the entity's clock (0 while hit-stopped):
##   scarf.medium_velocity = wind - body_velocity     # air as the body sees it
##   scarf.step(delta * clock.rate(), root_xf)
##   # _process: interpolated between physics steps
##   ribbon.update(scarf.render_points(Engine.get_physics_interpolation_fraction()))
##
## Coordinates are whatever frame the root transform is in; simulate in the
## frame the chain is drawn in (a cutout's card plane, a character's local
## space with frame_accel, or world space).
class_name MotionChain
extends RefCounted

var points := PackedVector3Array()
var lengths := PackedFloat64Array()
## Rest direction of each segment in the root's frame (shape memory).
var rest_dirs := PackedVector3Array()
var gravity := Vector3(0.0, -9.8, 0.0)
## Fraction of velocity lost per 1/60 s.
var damping := 0.04
## Pull toward the medium's velocity (1/s): air resistance; with
## `medium_velocity` = -body velocity the chain trails behind motion.
var drag := 0.0
var medium_velocity := Vector3.ZERO
## Acceleration of the simulation frame (a character's local space): every
## point feels -frame_accel.
var frame_accel := Vector3.ZERO
## 0..1: how strongly each segment returns to its rest direction (in the
## root's frame) per step, fading along the chain by `stiffness_falloff`.
var stiffness := 0.0
var stiffness_falloff := 0.7
var iterations := 4
## Finish each step with a root-to-tip pass that removes any stretch left
## by the iterations (a little energy is lost; ropes don't look like springs).
var inextensible := true
## Points stay above this y (in the chain's frame); -INF for none.
var floor_y := -INF
## Spheres points stay out of: [{center: Vector3, radius: float}].
var colliders: Array[Dictionary] = []

var _prev := PackedVector3Array()      # verlet history
var _snap := PackedVector3Array()      # positions before the last step (render interpolation)
var _last_dt := 1.0 / 60.0
var _root := Transform3D.IDENTITY


## `count` points, `segment` metres apart, hanging from `root` along `dir`
## (in the root's frame).
func _init(count := 8, segment := 0.05, root := Transform3D.IDENTITY, dir := Vector3.DOWN) -> void:
	_root = root
	var d := dir.normalized()
	for i in count:
		rest_dirs.append(d)
		if i > 0:
			lengths.append(segment)
	teleport(root)


## Put the chain at rest along its rest directions from `root` (no motion).
func teleport(root: Transform3D) -> void:
	_root = root
	points.resize(rest_dirs.size())
	var p := root.origin
	for i in points.size():
		if i > 0:
			p += (root.basis * rest_dirs[i]).normalized() * lengths[i - 1]
		points[i] = p
	_prev = points.duplicate()
	_snap = points.duplicate()


## Advance by `dt` seconds (0 freezes it) with the root at `root`.
func step(dt: float, root: Transform3D) -> void:
	_snap = points.duplicate()
	if dt <= 0.0:
		return
	_root = root
	var n := points.size()
	var ratio := dt / maxf(_last_dt, 1e-6)
	var keep := pow(1.0 - clampf(damping, 0.0, 1.0), dt * 60.0)
	var acc0 := gravity - frame_accel
	for i in range(1, n):
		var p := points[i]
		var v := (p - _prev[i]) / maxf(_last_dt, 1e-6)
		var a := acc0 + (medium_velocity - v) * drag
		var nxt := p + (p - _prev[i]) * ratio * keep + a * dt * (dt + _last_dt) * 0.5
		_prev[i] = p
		points[i] = nxt
	points[0] = root.origin
	_prev[0] = root.origin
	_last_dt = dt
	for it in iterations:
		_constrain(root)
	if inextensible:
		for i in range(1, n):
			var d := points[i] - points[i - 1]
			var len := d.length()
			if len > lengths[i - 1] and len > 1e-9:
				points[i] = points[i - 1] + d * (lengths[i - 1] / len)


func _constrain(root: Transform3D) -> void:
	var n := points.size()
	points[0] = root.origin
	for i in range(1, n):
		var a := points[i - 1]
		var b := points[i]
		var d := b - a
		var len := d.length()
		var rest := lengths[i - 1]
		if len > 1e-9:
			var corr := d * ((len - rest) / len)
			if i == 1:
				b -= corr                       # the root is pinned
			else:
				a += corr * 0.5
				b -= corr * 0.5
				points[i - 1] = a
		# shape memory toward the rest direction in the root's frame
		if stiffness > 0.0:
			var k := stiffness * pow(stiffness_falloff, float(i - 1)) / float(iterations)
			var target := points[i - 1] + (root.basis * rest_dirs[i]).normalized() * rest
			b = b.lerp(target, clampf(k, 0.0, 1.0))
		if b.y < floor_y:
			b.y = floor_y
		for c in colliders:
			var cc: Vector3 = c.center
			var r: float = c.radius
			var off := b - cc
			if off.length_squared() < r * r and off.length_squared() > 1e-12:
				b = cc + off.normalized() * r
		points[i] = b


## Positions between the last two steps (`frac` from
## Engine.get_physics_interpolation_fraction()).
func render_points(frac := 1.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(points.size())
	var f := clampf(frac, 0.0, 1.0)
	for i in points.size():
		out[i] = _snap[i].lerp(points[i], f)
	return out


## Mirror the chain across the root's x (a cutout flipping sides): positions,
## history and rest directions, so it doesn't whip.
func mirror_x() -> void:
	var cx := _root.origin.x
	points = _mirrored(points, cx)
	_prev = _mirrored(_prev, cx)
	_snap = _mirrored(_snap, cx)
	for i in rest_dirs.size():
		rest_dirs[i].x = -rest_dirs[i].x


static func _mirrored(arr: PackedVector3Array, cx: float) -> PackedVector3Array:
	var out := arr.duplicate()
	for i in out.size():
		out[i].x = 2.0 * cx - out[i].x
	return out


## Total rest length.
func length() -> float:
	var s := 0.0
	for l in lengths:
		s += l
	return s
