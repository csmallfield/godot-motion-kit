# SPDX-License-Identifier: Apache-2.0
## A spring that chases a target and keeps its velocity between frames: the
## reactive counterpart of MK.spring, with the same damping, stiffness and mass
## numbers, so a button's hover feels like the intros.
##
##   var s := MotionSpring.new(1.0, 9, 180)
##   s.target = 1.15          # on hover
##   scale = Vector2.ONE * s.step(delta)
##
## Each step advances the exact closed-form solution (as Remotion does per
## frame), so it is stable at any frame rate.
class_name MotionSpring
extends RefCounted

var value := 0.0
var velocity := 0.0
var target := 0.0
var damping := 10.0
var stiffness := 140.0
var mass := 1.0


func _init(initial := 0.0, damping_ := 10.0, stiffness_ := 140.0, mass_ := 1.0) -> void:
	value = initial
	target = initial
	damping = damping_
	stiffness = stiffness_
	mass = mass_


## Jump to `v` with no motion.
func snap(v: float) -> void:
	value = v
	target = v
	velocity = 0.0


func is_settled(eps := 0.0005) -> bool:
	return absf(value - target) < eps and absf(velocity) < eps * 10.0


## Kick it: add `v` to the velocity (units per second).
func impulse(v: float) -> void:
	velocity += v


## Advance by `dt` seconds and return the new value.
func step(dt: float) -> float:
	if dt <= 0.0:
		return value
	var c := MotionSpring.coefficients(dt, damping, stiffness, mass)
	var x0 := value - target          # displacement from rest
	var v0 := velocity
	value = target + c[0] * x0 + c[1] * v0
	velocity = c[2] * x0 + c[3] * v0
	return value


## The exact step as a linear map: after `dt` seconds a displacement x0 and
## velocity v0 become x = c[0]·x0 + c[1]·v0 and v = c[2]·x0 + c[3]·v0. Linear,
## so the same four numbers step every axis of a vector spring (and a whole
## array of springs with one setting) for the cost of one.
static func coefficients(dt: float, damping_: float, stiffness_: float, mass_ := 1.0) -> PackedFloat64Array:
	var w0 := sqrt(stiffness_ / mass_)
	var zeta := damping_ / (2.0 * sqrt(stiffness_ * mass_))
	if zeta < 1.0:
		var w1 := w0 * sqrt(1.0 - zeta * zeta)
		var env := exp(-zeta * w0 * dt)
		var c := cos(w1 * dt)
		var s := sin(w1 * dt)
		return PackedFloat64Array([
			env * (c + zeta * w0 / w1 * s), env * s / w1,
			-env * s * w0 * w0 / w1, env * (c - zeta * w0 / w1 * s)])
	# Critically damped (Remotion uses this for every ratio >= 1).
	var e := exp(-w0 * dt)
	return PackedFloat64Array([e * (1.0 + w0 * dt), e * dt, -e * w0 * w0 * dt, e * (1.0 - w0 * dt)])
