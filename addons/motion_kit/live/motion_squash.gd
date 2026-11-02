# SPDX-License-Identifier: Apache-2.0
## Squash and stretch: a volume-preserving scale from a spring you kick with
## impulses (and can bias from a velocity), plus pure helpers for event-timed
## squash. Positive amounts stretch along the axis, negative squash.
##
##   var sq := MotionSquash.new()
##   sq.impulse(0.6)                       # a jump, a dash: stretch
##   sq.bias = clampf(speed * 0.02, 0, 0.1)
##   var s := sq.step(clock.dt)            # Vector2(across, along)
##   pivot.scale = Vector3(s.x, s.y, s.x)  # pivot at the feet
##   # or event-pure, from a MotionClock:
##   var a := MotionSquash.land(clock.frames_since(&"land"), -0.18)
class_name MotionSquash
extends RefCounted

var spring := MotionSpring.new(0.0, 9.0, 260.0)
## A held amount the spring settles to (stretch with speed, crouch...).
var bias := 0.0
## 2 = area-preserving (flat cutouts), 3 = volume-preserving (solids).
var dims := 2
var limit := 0.45


func _init(damping := 9.0, stiffness := 260.0, dims_ := 2) -> void:
	spring = MotionSpring.new(0.0, damping, stiffness)
	dims = dims_


## Kick it (units of amount per second).
func impulse(v: float) -> void:
	spring.impulse(v)


## Advance and return the scale as Vector2(across, along).
func step(dt: float) -> Vector2:
	spring.target = bias
	spring.step(dt)
	return MotionSquash.scale_for(clampf(spring.value, -limit, limit), dims)


func amount() -> float:
	return spring.value


## The scale for an amount: along = 1 + a, across keeps area (2) or volume (3).
static func scale_for(a: float, dims_ := 2) -> Vector2:
	var along := maxf(1.0 + a, 0.05)
	var across := 1.0 / along if dims_ == 2 else 1.0 / sqrt(along)
	return Vector2(across, along)


## Event-pure landing squash: `amount` at frame 0 (negative squashes),
## springing back with a little overshoot. f = frames since the event.
static func land(f: float, amount := -0.18, damping := 7.0, stiffness := 320.0) -> float:
	if f < 0.0:
		return 0.0
	return (1.0 - MK.spring(f, 0.0, damping, stiffness)) * amount
