# SPDX-License-Identifier: Apache-2.0
## Trauma camera shake, the stateful game model: hits add trauma (0..1), it
## decays over time, and the shake is trauma^power times smooth seeded noise,
## in translation and roll. Directional kicks add a decaying jolt along a hit
## vector on top, so a blow from the left knocks the view right.
##
##   var trauma := MotionTrauma.new()
##   trauma.add(0.35)                         # on a hit
##   trauma.kick(screen_dir, 10.0)            # along the hit, in pixels
##   trauma.step(clock.dt)                    # every frame
##   lens.offset = trauma.offset()            # pixels; roll with trauma.roll()
##
## MK.shake / MK.shakes stay the event-pure option (a pure function of frames
## since the hit, for authored pieces and replays). Trauma differs in that
## overlapping hits saturate instead of stacking, and the noise does not
## restart on every hit. Both are deterministic: the noise is seeded and
## sampled from accumulated time, so a replay with the same steps matches.
class_name MotionTrauma
extends RefCounted

var trauma := 0.0
## Trauma lost per second.
var decay := 1.6
## Shake = trauma^power (2 keeps small hits subtle and big ones big).
var power := 2.0
## Largest translation at full trauma (pixels, or world units for offset3()).
var max_offset := Vector2(22.0, 16.0)
## Largest roll at full trauma (radians).
var max_roll := deg_to_rad(2.5)
## Noise speed in cycles per second.
var frequency := 16.0
var seed := 0.0
## Directional kicks: a damped jolt, `kick_rate` 1/s decay, `kick_hz` swing.
var kick_rate := 14.0
var kick_hz := 9.0

var time := 0.0
var _kicks: Array[Dictionary] = []   # {dir: Vector2, amp, age}


func _init(seed_ := 0.0) -> void:
	seed = seed_


## Add trauma (clamped to 1).
func add(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## A jolt of `amount` along `dir` (screen space: normalised for you).
func kick(dir: Vector2, amount: float) -> void:
	if dir.length_squared() < 1e-10:
		return
	_kicks.append({dir = dir.normalized(), amp = amount, age = 0.0})


## Advance by `dt` seconds (a clock's dt, so hit-stop can hold the shake, or
## real time so the camera keeps shaking through a freeze; your choice).
func step(dt: float) -> void:
	if dt <= 0.0:
		return
	time += dt
	trauma = maxf(0.0, trauma - decay * dt)
	for i in range(_kicks.size() - 1, -1, -1):
		var k: Dictionary = _kicks[i]
		k.age = float(k.age) + dt
		if exp(-float(k.age) * kick_rate) < 0.002:
			_kicks.remove_at(i)


## 0..1: how hard it is shaking now.
func amount() -> float:
	return pow(trauma, power)


## Translation now (noise plus kicks).
func offset() -> Vector2:
	var s := amount()
	var v := Vector2(noise(1.0), noise(2.0)) * max_offset * s
	for k in _kicks:
		var age: float = k.age
		var amp: float = k.amp
		var dir: Vector2 = k.dir
		v += dir * amp * exp(-age * kick_rate) * cos(age * kick_hz * TAU)
	return v


## Translation in 3D (x, y, z noise channels; no kicks).
func offset3(scale := Vector3.ONE) -> Vector3:
	var s := amount()
	return Vector3(noise(1.0), noise(2.0), noise(4.0)) * scale * s


## Roll now (radians).
func roll() -> float:
	return noise(3.0) * max_roll * amount()


## True when nothing is moving.
func is_still() -> bool:
	return trauma <= 0.0 and _kicks.is_empty()


## Smooth seeded value noise in -1..1 for channel `ch` at the current time.
func noise(ch: float) -> float:
	return MotionTrauma.value_noise(time * frequency, seed * 13.37 + ch * 101.3)


## 1D value noise in -1..1 (smoothstep between seeded lattice values).
static func value_noise(x: float, s: float) -> float:
	var i := floorf(x)
	var u := x - i
	u = u * u * (3.0 - 2.0 * u)
	var a := MK.rand(i * 1.618 + s) * 2.0 - 1.0
	var b := MK.rand((i + 1.0) * 1.618 + s) * 2.0 - 1.0
	return lerpf(a, b, u)
