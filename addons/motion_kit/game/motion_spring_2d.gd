# SPDX-License-Identifier: Apache-2.0
## MotionSpring for a Vector2: every axis follows the same exact
## closed-form step (MotionSpring.coefficients), so it moves like MK.spring on
## each component and costs one coefficient solve per step.
##
##   var follow := MotionSpring2D.new(start, 14, 120)
##   follow.target = hero_position + look_ahead
##   camera_target = follow.step(delta)
##   follow.impulse(hit_dir * 6.0)   # a kick in units per second
class_name MotionSpring2D
extends RefCounted

var value := Vector2()
var velocity := Vector2()
var target := Vector2()
var damping := 10.0
var stiffness := 140.0
var mass := 1.0


func _init(initial := Vector2(), damping_ := 10.0, stiffness_ := 140.0, mass_ := 1.0) -> void:
	value = initial
	target = initial
	damping = damping_
	stiffness = stiffness_
	mass = mass_


## Jump to `v` with no motion.
func snap(v: Vector2) -> void:
	value = v
	target = v
	velocity = Vector2()


## Add `v` to the velocity.
func impulse(v: Vector2) -> void:
	velocity += v


func is_settled(eps := 0.0005) -> bool:
	return value.distance_to(target) < eps and velocity.length() < eps * 10.0


## Advance by `dt` seconds and return the new value.
func step(dt: float) -> Vector2:
	if dt <= 0.0:
		return value
	var c := MotionSpring.coefficients(dt, damping, stiffness, mass)
	var x0 := value - target
	var v0 := velocity
	value = target + x0 * c[0] + v0 * c[1]
	velocity = x0 * c[2] + v0 * c[3]
	return value
