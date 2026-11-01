# SPDX-License-Identifier: Apache-2.0
## Distance over time, tabled once so every frame stays a pure lookup: a
## camera flying along a track, a pump's spin angle, anything whose position is
## the integral of a speed you author. Build it once (in `_build()`), then read
## `at(f)` every frame; seeking and reversing are free.
##
##   _tr = MotionTravel.from_keys([0, 60, 120, 420], [0.5, 2.0, 4.0, 4.0], 422)
##   var z := _tr.at(f)            # distance travelled at frame f
##   var v := _tr.speed(f)         # units per frame at f
##
## Three ways in:
## - `from_speed(fn, size)`: integrate a speed function (units per frame) on
##   `substeps` slices of each frame (midpoint rule; `midpoint = false` for a
##   left Euler sum, e.g. one sample per frame).
## - `from_keys(keys, values, size, easing)`: the same with the speed authored
##   as MK.interp keys.
## - `from_anchors(frames, distances, size)`: no speed at all: a monotone
##   (Fritsch-Carlson) cubic through hand-placed (frame, distance) anchors, so
##   the camera passes each landmark on its frame without overshooting.
##
## Entry i holds the distance at frame i (entry 0 is 0 for the integrators).
## Between entries `at()` interpolates linearly. Outside the table it clamps
## (the default) or, with `extrapolate`, runs on at the speed at the ends
## (before 0: `f * speed(0)`; after `end`: `at(end) + (f - end) * speed(end)`).
##
## Precision: `precise = true` stores Float64 (long tracks where Float32 would
## step); the default Float32 table matches pieces written with
## PackedFloat32Array. Integration always accumulates in float (64-bit).
@tool
class_name MotionTravel
extends RefCounted

## Store the table as Float64 (PackedFloat64Array) instead of Float32.
var precise := false
## Run on past the table at the end speeds instead of clamping.
var extrapolate := false
## The last frame of the table's own range when extrapolating (defaults to the
## last entry); `at()` extrapolates from here on.
var end := 0

var _fn: Callable
var _d32 := PackedFloat32Array()
var _d64 := PackedFloat64Array()
var _v32 := PackedFloat32Array()
var _v64 := PackedFloat64Array()


## Integrate `speed(f) -> units per frame` into a table of `size` entries
## (frames 0..size-1). Each frame is split into `substeps` slices sampled at
## their midpoints (or their starts with `midpoint = false`).
static func from_speed(speed: Callable, size: int, substeps := 8, precise_table := false,
		midpoint := true) -> MotionTravel:
	var t := MotionTravel.new()
	t.precise = precise_table
	t._fn = speed
	var off := 0.5 if midpoint else 0.0
	var vals := PackedFloat64Array()
	vals.resize(size)
	var acc := 0.0
	for i in size:
		vals[i] = acc
		for k in substeps:
			acc += float(speed.call(i + (k + off) / float(substeps))) / float(substeps)
	t._store(vals)
	var sp := PackedFloat64Array()
	sp.resize(size)
	for i in size:
		sp[i] = float(speed.call(float(i)))
	if t.precise:
		t._v64 = sp
	else:
		t._v32 = _to32(sp)
	return t


## `from_speed` with the speed given as MK.interp keys: `values[i]` units per
## frame at frame `keys[i]`, eased between keys and held outside them.
static func from_keys(keys: Array, values: Array, size: int, easing: Callable = MK.ease_in_out,
		substeps := 8, precise_table := false) -> MotionTravel:
	return from_speed(func(f: float) -> float: return MK.interp(f, keys, values, easing),
		size, substeps, precise_table)


## A table of `size` entries through (frames[i], distances[i]) anchors on a
## monotone cubic (Fritsch-Carlson): it passes every anchor, never overshoots
## between them, and runs on linearly at the last tangent past the last anchor.
## Frames must increase. Float64 by default.
static func from_anchors(frames: Array, distances: Array, size: int, precise_table := true) -> MotionTravel:
	var t := MotionTravel.new()
	t.precise = precise_table
	var xs: Array[float] = []
	var ys: Array[float] = []
	for i in frames.size():
		xs.append(float(frames[i]))
		ys.append(float(distances[i]))
	var n := xs.size()
	var dl: Array[float] = []
	for i in n - 1:
		dl.append((ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]))
	var m: Array[float] = [dl[0]]
	for i in range(1, n - 1):
		m.append(0.0 if dl[i - 1] * dl[i] <= 0.0 else (dl[i - 1] + dl[i]) * 0.5)
	m.append(dl[n - 2])
	for i in n - 1:
		if dl[i] == 0.0:
			m[i] = 0.0
			m[i + 1] = 0.0
			continue
		var a := m[i] / dl[i]
		var b := m[i + 1] / dl[i]
		var h := a * a + b * b
		if h > 9.0:
			var s := 3.0 / sqrt(h)
			m[i] = s * a * dl[i]
			m[i + 1] = s * b * dl[i]
	var vals := PackedFloat64Array()
	vals.resize(size)
	for f in size:
		var x := float(f)
		var k := 0
		while k < n - 2 and x > xs[k + 1]:
			k += 1
		var hh := xs[k + 1] - xs[k]
		if x > xs[n - 1]:
			vals[f] = ys[n - 1] + m[n - 1] * (x - xs[n - 1])
			continue
		var u := (x - xs[k]) / hh
		var u2 := u * u
		var u3 := u2 * u
		vals[f] = (2 * u3 - 3 * u2 + 1) * ys[k] + (u3 - 2 * u2 + u) * hh * m[k] + (-2 * u3 + 3 * u2) * ys[k + 1] + (u3 - u2) * hh * m[k + 1]
	t._store(vals)
	return t


## Speed (units per frame) from [[frame, speed], ...] pairs, smoothstepped
## between pairs and held after the last: a speed function for `from_speed`
## that eases into each key and arrives on it exactly (the pair at or after
## `f` is the one reached).
static func keyed_speed(pairs: Array, f: float) -> float:
	for k in range(1, pairs.size()):
		var a: Array = pairs[k - 1]
		var b: Array = pairs[k]
		if f <= b[0]:
			var t := clampf((f - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return lerpf(a[1], b[1], t * t * (3.0 - 2.0 * t))
	return pairs[pairs.size() - 1][1]


func _store(vals: PackedFloat64Array) -> void:
	if precise:
		_d64 = vals
	else:
		_d32 = _to32(vals)
	end = vals.size() - 1


static func _to32(vals: PackedFloat64Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(vals.size())
	for i in vals.size():
		out[i] = vals[i]
	return out


## Number of table entries (frames 0..size()-1).
func size() -> int:
	return _d64.size() if precise else _d32.size()


## The tabled distance at entry i (no interpolation).
func entry(i: int) -> float:
	return _d64[i] if precise else _d32[i]


## Distance travelled at frame f (linear between entries; clamped or
## extrapolated outside, see `extrapolate`).
func at(f: float) -> float:
	var n := size()
	if n == 0:
		return 0.0
	if n == 1:
		return entry(0)
	if extrapolate:
		if f < 0.0:
			return f * speed(0.0)
		if f >= end:
			return entry(end) + (f - end) * speed(float(end))
		var j := int(floorf(f))
		return lerpf(entry(j), entry(j + 1), f - j)
	var i := clampi(int(floorf(f)), 0, n - 2)
	return lerpf(entry(i), entry(i + 1), clampf(f - i, 0.0, 1.0))


## Speed in units per frame at f: the speed function itself for the
## integrators, the table's slope (central difference over a frame) for anchors.
func speed(f: float) -> float:
	if _fn.is_valid():
		return float(_fn.call(f))
	return at(f + 0.5) - at(f - 0.5)


## The speed sampled at whole frame clampi(int(f), 0, size - 1), stored at the
## table's precision (a per-frame read-out, e.g. a speedometer or motion blur).
## Only the integrators sample it; anchors fall back to `speed()`.
func frame_speed(f: float) -> float:
	var i := clampi(int(f), 0, size() - 1)
	if precise and not _v64.is_empty():
		return _v64[i]
	if not precise and not _v32.is_empty():
		return _v32[i]
	return speed(float(i))
