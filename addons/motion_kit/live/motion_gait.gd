# SPDX-License-Identifier: Apache-2.0
## Procedural gait with foot planting, on the ground plane (world x, z): each
## foot stays where it was planted until the body has moved its home a
## stride away, then steps along an arc to land ahead of the body. Feet
## alternate (one in the air at a time); stride and step time scale with
## speed; standing still, feet settle home. It also gives the body a dip on
## each plant, a rise while a foot is up, and a lean from speed and
## acceleration, all on springs.
##
##   var gait := MotionGait.new(settings, 2)
##   gait.planted.connect(func(i, pos): GameEvents.emit(&"step.grass", pos))
##   # _physics_process, with a clock so hit-stop freezes the walk too:
##   gait.step(delta * clock.rate(), global_position, velocity, facing)
##   # _process: interpolated between physics steps
##   var foot := gait.foot(0, Engine.get_physics_interpolation_fraction())
##
## Positions are world space on the body's ground height (y = lift above it).
## Fixed step: run it in _physics_process and read foot() with the physics
## interpolation fraction, or it jitters at high refresh rates.
class_name MotionGait
extends RefCounted

## A foot landed: index and world position.
signal planted(foot: int, position: Vector3)
## A foot left the ground.
signal lifted(foot: int, position: Vector3)

var settings: MotionGaitSettings
## Body offset from the springs: y = bob (metres), x = forward lean, z =
## sideways lean (radians), in the facing frame.
var body := Vector3.ZERO

var _n := 2
var _pos: Array[Vector3] = []      # current (lifted feet include height)
var _prev: Array[Vector3] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _t: PackedFloat64Array = []    # step progress 0..1, -1 = planted
var _dur: PackedFloat64Array = []
var _still := 0.0
var _last_vel := Vector3.ZERO
var _dip := MotionSpring.new(0.0, 18.0, 260.0)
var _lean := MotionSpring2D.new(Vector2.ZERO, 14.0, 120.0)
var _next := 0                     # which foot steps next when both want to
var _ready := false


func _init(p_settings: MotionGaitSettings = null, feet := 2) -> void:
	settings = p_settings if p_settings else MotionGaitSettings.new()
	_n = feet
	for i in _n:
		_pos.append(Vector3.ZERO)
		_prev.append(Vector3.ZERO)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
	_t.resize(_n)
	_dur.resize(_n)
	_t.fill(-1.0)


## Put every foot at home under a body at `at` facing `facing` (no steps).
func reset(at: Vector3, facing := Vector3.FORWARD) -> void:
	for i in _n:
		_pos[i] = home(i, at, Vector3.ZERO, facing)
		_prev[i] = _pos[i]
		_t[i] = -1.0
	_ready = true


## Where foot `i` wants to be for a body at `at` moving at `vel`.
func home(i: int, at: Vector3, vel: Vector3, facing: Vector3) -> Vector3:
	var f := Vector3(facing.x, 0.0, facing.z)
	f = f.normalized() if f.length_squared() > 1e-8 else Vector3.FORWARD
	var across := Vector3(-f.z, 0.0, f.x)
	var side := (float(i) / maxf(_n - 1, 1)) * 2.0 - 1.0          # -1 .. 1 across the feet
	var h := at + across * side * settings.hip_width + Vector3(vel.x, 0.0, vel.z) * settings.lead
	h.y = at.y
	return h


## Advance by `dt` (local seconds: pass delta * clock.rate()).
func step(dt: float, at: Vector3, vel: Vector3, facing: Vector3) -> void:
	if not _ready:
		reset(at, facing)
	for i in _n:
		_prev[i] = _pos[i]
	if dt <= 0.0:
		return
	var s := settings
	var planar := Vector3(vel.x, 0.0, vel.z)
	var speed := planar.length()
	var k := clampf(speed / maxf(s.reference_speed, 1e-3), 0.0, 1.5)
	var dur := lerpf(s.step_time, s.step_time_fast, minf(k, 1.0))
	var stride := s.stride * lerpf(1.0, maxf(k, 0.35), s.stride_speed_scale)
	_still = _still + dt if speed < 0.15 else 0.0
	var airborne := 0
	# feet in the air
	for i in _n:
		if _t[i] < 0.0:
			continue
		_t[i] = minf(1.0, _t[i] + dt / _dur[i])
		# keep aiming at a moving home's landing point
		_to[i] = home(i, at, planar, facing) + planar * _dur[i] * (1.0 - _t[i]) * 0.5
		var u := _t[i]
		var e := u * u * (3.0 - 2.0 * u)
		var p := _from[i].lerp(_to[i], e)
		p.y = at.y + s.lift * pow(sin(PI * u), s.lift_shape)
		_pos[i] = p
		if _t[i] >= 1.0:
			_t[i] = -1.0
			_pos[i].y = at.y
			_dip.velocity -= s.plant_dip * s.dip_stiffness * 0.08 * (0.4 + 0.6 * minf(k, 1.0))
			planted.emit(i, _pos[i])
		else:
			airborne += 1
	# planted feet: does one need to step?
	if airborne == 0:
		var best := -1
		var best_d := 0.0
		for j in _n:
			var i := (_next + j) % _n
			var h := home(i, at, planar, facing)
			var d := Vector2(_pos[i].x - h.x, _pos[i].z - h.z).length()
			var need: bool = d > stride * 0.5 if speed >= 0.15 else (d > s.settle_distance and _still >= s.settle_delay)
			if need and d > best_d + 1e-4:
				best = i
				best_d = d
		if best >= 0:
			_from[best] = _pos[best]
			_dur[best] = dur
			_t[best] = 0.0
			_next = (best + 1) % _n
			_to[best] = home(best, at, planar, facing) + planar * dur * 0.5
			lifted.emit(best, _pos[best])
	# keep planted feet on the ground height (stairs, slopes come later)
	for i in _n:
		if _t[i] < 0.0:
			_pos[i].y = at.y
	# body springs
	_dip.damping = s.dip_damping
	_dip.stiffness = s.dip_stiffness
	_dip.target = 0.0
	_dip.step(dt)
	var up := 0.0
	for i in _n:
		if _t[i] >= 0.0:
			up = maxf(up, sin(PI * _t[i]))
	var f := Vector3(facing.x, 0.0, facing.z)
	f = f.normalized() if f.length_squared() > 1e-8 else Vector3.FORWARD
	var across := Vector3(-f.z, 0.0, f.x)
	var acc := (planar - _last_vel) / dt
	_last_vel = planar
	var want := Vector2(
			acc.dot(f) * s.lean_accel + planar.dot(f) * s.lean_speed,
			acc.dot(across) * s.lean_accel + planar.dot(across) * s.lean_speed)
	_lean.damping = s.lean_damping
	_lean.stiffness = s.lean_stiffness
	_lean.target = want.limit_length(s.lean_max)
	var l := _lean.step(dt)
	body = Vector3(l.x, _dip.value + up * s.step_rise, l.y)


## Foot `i` in world space, interpolated `frac` of the way from the previous
## physics step to the current one.
func foot(i: int, frac := 1.0) -> Vector3:
	return _prev[i].lerp(_pos[i], clampf(frac, 0.0, 1.0))


## True while foot `i` is planted.
func is_planted(i: int) -> bool:
	return _t[i] < 0.0


## Step progress of foot `i` (0..1), or -1 while planted.
func progress(i: int) -> float:
	return _t[i]


func foot_count() -> int:
	return _n
