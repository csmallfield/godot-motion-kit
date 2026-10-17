# SPDX-License-Identifier: Apache-2.0
## Motion Kit maths. Every function here is a pure function of its arguments,
## so a composition built from them draws the same picture for the same frame.
##
## Frames are floats. Remotion compositions run at integer frames; at higher
## refresh rates the same functions are simply evaluated in between.
class_name MK
extends RefCounted

const EPS := 1e-7


# ------------------------------------------------------------------ easing

static func linear(t: float) -> float:
	return t


## A CSS-style cubic-bezier easing curve, returned as a Callable(t) -> float.
## Curve control points (0,0), (x1,y1), (x2,y2), (1,1). x1 and x2 must lie in
## [0, 1]; y1 and y2 may overshoot (that is how "back" easings work).
static func bezier(x1: float, y1: float, x2: float, y2: float) -> Callable:
	if is_equal_approx(x1, y1) and is_equal_approx(x2, y2):
		return MK.linear
	var curve := _Bezier.new(x1, y1, x2, y2)
	# A lambda captures `curve` and keeps it alive; a bound method Callable would not.
	return func(t: float) -> float: return curve.ease(t)


## Named curves used throughout the SCF pieces.
static var ease: Callable = bezier(0.22, 1.0, 0.36, 1.0)          ## Strong ease-out (Remotion `ease` in anim.ts).
static var ease_in_out: Callable = bezier(0.65, 0.0, 0.35, 1.0)
static var ease_in_back: Callable = bezier(0.6, -0.28, 0.735, 0.045)
static var ease_out_back: Callable = bezier(0.175, 0.885, 0.32, 1.275)
static var ease_in_quad: Callable = func(t: float) -> float: return t * t


# ------------------------------------------------------------------ interpolation

enum Extrapolate { CLAMP, EXTEND, IDENTITY }

## Multi-key interpolation, Remotion `interpolate` semantics: `inputs` must be
## ascending; `easing` is applied per segment. Clamped at both ends by default.
static func interp(x: float, inputs: Array, outputs: Array, easing: Callable = MK.linear,
		left := Extrapolate.CLAMP, right := Extrapolate.CLAMP) -> float:
	var n := inputs.size()
	assert(n >= 2 and n == outputs.size(), "interp: inputs and outputs need the same length >= 2")
	var i := 0
	while i < n - 2 and x >= float(inputs[i + 1]):
		i += 1
	var a := float(inputs[i])
	var b := float(inputs[i + 1])
	var oa := float(outputs[i])
	var ob := float(outputs[i + 1])
	if x < a:
		match left:
			Extrapolate.CLAMP: return oa
			Extrapolate.IDENTITY: return x
	if x > b:
		match right:
			Extrapolate.CLAMP: return ob
			Extrapolate.IDENTITY: return x
	if is_equal_approx(a, b):
		return oa if x <= a else ob
	var t := (x - a) / (b - a)
	if t >= 0.0 and t <= 1.0:
		t = easing.call(t)
	return oa + (ob - oa) * t


## `map` from the SCF anim.ts: clamped interpolation, eased with `ease` by default.
static func map(f: float, inputs: Array, outputs: Array, easing: Callable = MK.ease) -> float:
	return interp(f, inputs, outputs, easing)


## 0 → 1 over [start, start + dur], eased.
static func prog(f: float, start: float, dur := 18.0, easing: Callable = MK.ease) -> float:
	return interp(f, [start, start + dur], [0.0, 1.0], easing)


## Visible window: fades in at `a`, out at `b`.
static func win(f: float, a: float, b: float, fade := 12.0) -> float:
	return minf(prog(f, a, fade), 1.0 - prog(f, b - fade, fade))


## Fade-and-rise for an element entering at `start`: returns {o, y}.
static func rise(f: float, start: float, dist := 24.0, dur := 18.0) -> Dictionary:
	var t := prog(f, start, dur)
	return {o = t, y = (1.0 - t) * dist}


# ------------------------------------------------------------------ springs

## Damped spring 0 → 1 that starts at frame `at`, configured the way Remotion's
## spring() is (damping, stiffness, mass at a given fps).
##
## Remotion advances a closed-form oscillator once per frame. Stepping an exact
## solution composes exactly, so evaluating it once at t = (f - at) / fps gives
## the same value. Like Remotion, every damping ratio of 1 and above uses the
## critically damped solution.
static func spring(f: float, at := 0.0, damping := 10.0, stiffness := 100.0, mass := 1.0, fps := 30.0) -> float:
	var t := maxf(0.0, f - at) / fps
	if t <= 0.0:
		return 0.0
	var w0 := sqrt(stiffness / mass)
	var zeta := damping / (2.0 * sqrt(stiffness * mass))
	if zeta < 1.0:
		var w1 := w0 * sqrt(1.0 - zeta * zeta)
		var env := exp(-zeta * w0 * t)
		return 1.0 - env * (cos(w1 * t) + (zeta * w0 / w1) * sin(w1 * t))
	return 1.0 - exp(-w0 * t) * (1.0 + w0 * t)


## Spring from `from` to `to`.
static func spring_to(f: float, at: float, from: float, to: float, damping := 10.0, stiffness := 100.0,
		mass := 1.0, fps := 30.0) -> float:
	return from + (to - from) * spring(f, at, damping, stiffness, mass, fps)


## The SCF `springy`: a looser hand-tuned wobble, in frames.
static func springy(f: float, start: float, stiffness := 0.5, damping := 0.16) -> float:
	if f < start:
		return 0.0
	var t := f - start
	return 1.0 - exp(-damping * t * 1.6) * cos(sqrt(stiffness) * t)


## Damped wobble 0 → overshoot → 1 after `at` (goo.tsx `wob`).
static func wob(f: float, at: float, k := 0.9, d := 5.0) -> float:
	var t := f - at
	if t < 0.0:
		return 0.0
	return 1.0 - exp(-t / d) * cos(t * k)


# ------------------------------------------------------------------ noise and time

## Deterministic pseudo-random in [0, 1) for a seed. Same formula as the SCF
## Remotion `rand`, so seeded effects line up with the originals.
static func rand(seed: float) -> float:
	var x := sin(seed * 12.9898 + 78.233) * 43758.5453
	return x - floorf(x)


## Frame quantised to every n frames: stuttered, on-twos motion.
static func step(f: float, n: float) -> float:
	return floorf(f / n) * n


## Decaying camera shake after an impact at `at`.
static func shake(f: float, at: float, amp := 18.0, dur := 10.0) -> Vector2:
	var t := f - at
	if t < 0.0 or t > dur:
		return Vector2.ZERO
	var k := 1.0 - t / dur
	return Vector2((rand(at * 7.0 + t) - 0.5) * 2.0 * amp * k, (rand(at * 13.0 + t) - 0.5) * 2.0 * amp * k)


## Sum of several shakes.
static func shakes(f: float, ats: Array, amp := 18.0, dur := 10.0) -> Vector2:
	var s := Vector2.ZERO
	for a in ats:
		s += shake(f, float(a), amp, dur)
	return s


## Typewriter: characters of `text` revealed at `cps` characters per second.
static func typed(text: String, f: float, start: float, cps := 38.0, fps := 30.0) -> String:
	return text.substr(0, maxi(0, int(floorf(((f - start) * cps) / fps))))


## CRT power-off from `at`: squash to a line, then to a dot.
## Returns {scale: Vector2, bright: float, dot: float}.
static func crt_off(f: float, at: float) -> Dictionary:
	var y := interp(f, [at, at + 8.0], [1.0, 0.004], MK.ease_in_quad)
	var x := interp(f, [at + 8.0, at + 14.0], [1.0, 0.0], MK.ease_in_quad)
	var dot := 0.0
	if f >= at + 12.0 and f < at + 20.0:
		dot = 1.0 - (f - at - 12.0) / 8.0
	return {scale = Vector2(x, y), bright = 1.0 - y, dot = dot}


## Timecode string HH:MM:SS:FF for frame `f` (the "ON AIR" clocks).
static func timecode(f: float, fps := 30.0) -> String:
	var fi := int(floorf(f))
	var s := fi / int(fps)
	return "00:00:%02d:%02d" % [s, fi % int(fps)]


# ------------------------------------------------------------------ cubic bezier solver

class _Bezier:
	extends RefCounted
	var x1: float
	var y1: float
	var x2: float
	var y2: float
	const SAMPLES := 11
	var _samples := PackedFloat64Array()

	func _init(a: float, b: float, c: float, d: float) -> void:
		x1 = a; y1 = b; x2 = c; y2 = d
		_samples.resize(SAMPLES)
		for i in SAMPLES:
			_samples[i] = _calc(i / float(SAMPLES - 1), x1, x2)

	static func _calc(t: float, p1: float, p2: float) -> float:
		# ((A t + B) t + C) t with A = 1 - 3p2 + 3p1, B = 3p2 - 6p1, C = 3p1
		return (((1.0 - 3.0 * p2 + 3.0 * p1) * t + (3.0 * p2 - 6.0 * p1)) * t + 3.0 * p1) * t

	static func _slope(t: float, p1: float, p2: float) -> float:
		return 3.0 * (1.0 - 3.0 * p2 + 3.0 * p1) * t * t + 2.0 * (3.0 * p2 - 6.0 * p1) * t + 3.0 * p1

	func _t_for_x(x: float) -> float:
		var step := 1.0 / float(SAMPLES - 1)
		var start := 0.0
		var i := 1
		while i < SAMPLES - 1 and _samples[i] <= x:
			start += step
			i += 1
		i -= 1
		var dist := (x - _samples[i]) / (_samples[i + 1] - _samples[i])
		var guess := start + dist * step
		var slope := _slope(guess, x1, x2)
		if slope >= 0.001:
			for _n in 4:
				var s := _slope(guess, x1, x2)
				if s == 0.0:
					return guess
				guess -= (_calc(guess, x1, x2) - x) / s
			return guess
		if slope == 0.0:
			return guess
		# bisection
		var lo := start
		var hi := start + step
		var cur := 0.0
		for _n in 10:
			cur = lo + (hi - lo) / 2.0
			var cx := _calc(cur, x1, x2) - x
			if absf(cx) <= 0.0000001:
				break
			if cx > 0.0:
				hi = cur
			else:
				lo = cur
		return cur

	func ease(x: float) -> float:
		if x <= 0.0:
			return 0.0
		if x >= 1.0:
			return 1.0
		return _calc(_t_for_x(x), y1, y2)
