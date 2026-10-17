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


## Advance by `dt` seconds and return the new value.
func step(dt: float) -> float:
	if dt <= 0.0:
		return value
	var x0 := value - target          # displacement from rest
	var v0 := velocity
	var w0 := sqrt(stiffness / mass)
	var zeta := damping / (2.0 * sqrt(stiffness * mass))
	var x: float
	var v: float
	if zeta < 1.0:
		var w1 := w0 * sqrt(1.0 - zeta * zeta)
		var env := exp(-zeta * w0 * dt)
		var c := cos(w1 * dt)
		var s := sin(w1 * dt)
		var b := (v0 + zeta * w0 * x0) / w1
		x = env * (x0 * c + b * s)
		v = env * ((-zeta * w0) * (x0 * c + b * s) + (-x0 * w1 * s + b * w1 * c))
	else:
		# Critically damped (Remotion uses this for every ratio >= 1).
		var env := exp(-w0 * dt)
		var b := v0 + w0 * x0
		x = env * (x0 + b * dt)
		v = env * (b - w0 * (x0 + b * dt))
	value = target + x
	velocity = v
	return value
