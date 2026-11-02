# SPDX-License-Identifier: Apache-2.0
## An angle that turns toward a target on a spring, the short way round, kept
## within limits: a head, eyes or torso looking at something with lag.
##
##   var head := MotionAimSpring.new(0.0, 12.0, 160.0)
##   head.limit_min = deg_to_rad(-14); head.limit_max = deg_to_rad(14)
##   head.target = (enemy - hero).angle()
##   head_node.rotation.z = head.step(dt)
##
## Same exact closed-form step as MotionSpring (MotionSpring.coefficients).
class_name MotionAimSpring
extends RefCounted

var value := 0.0
var velocity := 0.0
## Wanted angle (radians); wrapped to the nearest turn of `value`.
var target := 0.0
var damping := 12.0
var stiffness := 160.0
var mass := 1.0
## Limits on the result (radians); INF / -INF for none.
var limit_min := -INF
var limit_max := INF


func _init(initial := 0.0, damping_ := 12.0, stiffness_ := 160.0, mass_ := 1.0) -> void:
	value = initial
	target = initial
	damping = damping_
	stiffness = stiffness_
	mass = mass_


func snap(a: float) -> void:
	value = clampf(a, limit_min, limit_max)
	target = value
	velocity = 0.0


func impulse(v: float) -> void:
	velocity += v


## Advance by `dt` seconds and return the angle.
func step(dt: float) -> float:
	if dt <= 0.0:
		return value
	var goal := clampf(value + wrapf(target - value, -PI, PI), limit_min, limit_max)
	var c := MotionSpring.coefficients(dt, damping, stiffness, mass)
	var x0 := value - goal
	var v0 := velocity
	value = goal + c[0] * x0 + c[1] * v0
	velocity = c[2] * x0 + c[3] * v0
	if value < limit_min or value > limit_max:      # stop at the limits, don't bounce through
		value = clampf(value, limit_min, limit_max)
		velocity = 0.0
	return value
