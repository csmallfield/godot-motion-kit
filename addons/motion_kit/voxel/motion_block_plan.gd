# SPDX-License-Identifier: Apache-2.0
## Block choreography: move a population of grid blocks from one layout to
## another (a city to a voxelised logo and back) in grid moves, in waves.
##
## Each block has a cell (x, y: its south-west corner on the ground grid) and a
## height. A plan holds one move per block, from layout A to layout B, and
## answers `pose(i, f)` → Vector4(x, y, lift, height) for any frame: a pure
## function of f, so seeking and reversing work.
##
##   var who := MotionBlockPlan.assign_nearest(block_cells, target_cells)   # target → block
##   var plan := MotionBlockPlan.new()
##   plan.start = 36.0; plan.waves = 4; plan.wave_step = 18.0; plan.dur = 18.0
##   for i in blocks: plan.set_move(i, Vector3(x, y, h), Vector3(x, y, h * 0.4), 0.0)   # stay, crouch
##   for t in who.size(): plan.set_move(who[t], from[who[t]], Vector3(tx, ty, th), key_t)  # 0..1 → wave
##   # per frame:  var p := plan.pose(i, f)   (x, y, z lift, h)
##
## Moves: STAY changes height in place (telescopes); SLIDE runs along the ground
## in two axis legs (x then y, or y then x); FLY lifts, runs the two legs in the
## air and drops; SINK telescopes down at the source and up at the target.
## `auto_style` picks SLIDE for short moves, FLY (or SINK, `sink_share`) for long.
##
## Waves: a move's `key` (0..1, e.g. its target's distance from the logo's
## centre) picks its wave: wave k starts at `start + k * wave_step`. Inside a
## wave, `jitter` frames of extra delay follow the key, so a wave ripples
## instead of firing as one block.
@tool
class_name MotionBlockPlan
extends RefCounted

enum { STAY, SLIDE, FLY, SINK }

const STRIDE := 11   # x0 y0 h0 x1 y1 h1 t0 style lift yfirst dur

## Frame the first wave starts.
var start := 0.0
## Number of waves (keys 0..1 are split evenly).
var waves := 4
## Frames between wave starts (a beat, for moves on the beat).
var wave_step := 18.0
## Frames one move takes.
var dur := 18.0
## Extra delay inside a wave, in frames, growing with the key.
var jitter := 3.0
## Cruise height of flying blocks (each is varied ±40%).
var lift := 2.0
## Moves up to this many cells slide on the ground; longer ones fly.
var slide_max := 3.0
## Share of long moves that sink and rise instead of flying.
var sink_share := 0.0
## Landing overshoot of the height (telescoping servo), as a fraction of the height.
var land := 0.12
## Seed for the per-block variation.
var seed := 1.0
## Deprecated: use seed.
var seed_v: float:
	get: return seed
	set(v): seed = v

var _m := PackedFloat32Array()
var _count := 0


func _init(n := 0) -> void:
	if n > 0:
		resize(n)


func resize(n: int) -> void:
	_count = n
	_m.resize(n * STRIDE)
	for i in n:
		set_move(i, Vector3.ZERO, Vector3.ZERO, 0.0, STAY)


func size() -> int:
	return _count


## Set block i's move from `a` = (x, y, height) to `b`. `key` (0..1) picks the
## wave; `style` -1 = auto (STAY when the cell doesn't change).
func set_move(i: int, a: Vector3, b: Vector3, key: float, style := -1) -> void:
	var o := i * STRIDE
	var r := MK.rand(i * 1.731 + seed * 17.3)
	var dist := absf(b.x - a.x) + absf(b.y - a.y)
	var st := style
	if st < 0:
		if dist < 0.01:
			st = STAY
		elif dist <= slide_max:
			st = SLIDE
		else:
			st = SINK if MK.rand(i * 3.17 + seed * 5.1) < sink_share else FLY
	var k := clampf(key, 0.0, 0.9999)
	var w := floorf(k * waves)
	var inner := k * waves - w
	_m[o] = a.x
	_m[o + 1] = a.y
	_m[o + 2] = a.z
	_m[o + 3] = b.x
	_m[o + 4] = b.y
	_m[o + 5] = b.z
	_m[o + 6] = start + w * wave_step + inner * jitter
	_m[o + 7] = st
	_m[o + 8] = lift * (0.6 + 0.8 * r)
	_m[o + 9] = 1.0 if MK.rand(i * 7.7 + seed) < 0.5 else 0.0
	_m[o + 10] = dur


## Frame block i's move starts / lands.
func starts(i: int) -> float:
	return _m[i * STRIDE + 6]


func lands(i: int) -> float:
	return _m[i * STRIDE + 6] + _m[i * STRIDE + 10]


func style(i: int) -> int:
	return int(_m[i * STRIDE + 7])


## Where block i ends (x, y, height).
func target(i: int) -> Vector3:
	var o := i * STRIDE
	return Vector3(_m[o + 3], _m[o + 4], _m[o + 5])


func origin(i: int) -> Vector3:
	var o := i * STRIDE
	return Vector3(_m[o], _m[o + 1], _m[o + 2])


## 0 before the move, 1 once landed.
func progress(i: int, f: float) -> float:
	var o := i * STRIDE
	return clampf((f - _m[o + 6]) / _m[o + 10], 0.0, 1.0)


## The frames waves start on (for cues).
func wave_frames() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for w in waves:
		out.append(start + w * wave_step)
	return out


## Block i at frame f: Vector4(x, y, lift above the ground, height).
func pose(i: int, f: float) -> Vector4:
	var o := i * STRIDE
	var x0 := _m[o]
	var y0 := _m[o + 1]
	var h0 := _m[o + 2]
	var x1 := _m[o + 3]
	var y1 := _m[o + 4]
	var h1 := _m[o + 5]
	var t := (f - _m[o + 6]) / _m[o + 10]
	if t <= 0.0:
		return Vector4(x0, y0, 0.0, h0)
	if t >= 1.0:
		return Vector4(x1, y1, 0.0, h1)
	var st := int(_m[o + 7])
	var yfirst := _m[o + 9] > 0.5
	match st:
		STAY:
			return Vector4(x0, y0, 0.0, _telescope(h0, h1, t))
		SLIDE:
			# Travel 0..0.8 along the L path, then the height settles.
			var s := _io(clampf(t / 0.8, 0.0, 1.0))
			var p := _leg(x0, y0, x1, y1, s, yfirst)
			var h := _telescope(h0, h1, clampf((t - 0.15) / 0.85, 0.0, 1.0))
			return Vector4(p.x, p.y, 0.0, h)
		FLY:
			var lz := _m[o + 8]
			var z := 0.0
			var s := 0.0
			if t < 0.2:
				z = lz * _out(t / 0.2)
			elif t < 0.75:
				z = lz
				s = _io((t - 0.2) / 0.55)
			else:
				s = 1.0
				z = lz * (1.0 - _inq(clampf((t - 0.75) / 0.13, 0.0, 1.0)))
			var p := _leg(x0, y0, x1, y1, s, yfirst)
			var hm := lerpf(h0, h1, _io(clampf((t - 0.15) / 0.6, 0.0, 1.0)))
			if t > 0.88:
				var k := (t - 0.88) / 0.12
				hm = h1 * (1.0 + land * sin(k * PI) * (1.0 - k))
			return Vector4(p.x, p.y, z, hm)
		_:   # SINK: down at the source, up at the target
			if t < 0.45:
				return Vector4(x0, y0, 0.0, h0 * (1.0 - _inq(t / 0.45)))
			if t < 0.55:
				return Vector4(x1, y1, 0.0, 0.0)
			return Vector4(x1, y1, 0.0, h1 * _back((t - 0.55) / 0.45))


func _telescope(h0: float, h1: float, t: float) -> float:
	var e := _io(clampf(t / 0.8, 0.0, 1.0))
	var h := lerpf(h0, h1, e)
	if t > 0.8:
		var k := (t - 0.8) / 0.2
		h += (h1 - h0) * land * sin(k * PI) * (1.0 - k)
	return maxf(0.0, h)


# Cheap closed-form easings (the plan runs for every block every frame).
static func _io(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func _inq(t: float) -> float:
	return t * t


static func _back(t: float) -> float:
	var c := 1.4
	var u := t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u


static func _leg(x0: float, y0: float, x1: float, y1: float, s: float, yfirst: bool) -> Vector2:
	var dx := absf(x1 - x0)
	var dy := absf(y1 - y0)
	var total := dx + dy
	if total < 1e-6:
		return Vector2(x0, y0)
	var d := s * total
	if yfirst:
		if d <= dy:
			return Vector2(x0, y0 + signf(y1 - y0) * d)
		return Vector2(x0 + signf(x1 - x0) * (d - dy), y1)
	if d <= dx:
		return Vector2(x0 + signf(x1 - x0) * d, y0)
	return Vector2(x1, y0 + signf(y1 - y0) * (d - dx))


# ---------------------------------------------------------------- matching

## Cheap assignment of blocks to targets: targets are taken in `order` (their
## indices; default: farthest from the targets' centroid first, so the rim
## claims blocks before the middle does) and each takes the nearest free block
## (bucketed ring search, O(n·r²)). Returns, per target, the block index, or -1
## when the blocks ran out. `exclude` (block index → true) keeps blocks out.
static func assign_nearest(blocks: PackedVector2Array, targets: PackedVector2Array, order := PackedInt32Array(), exclude := {}) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(targets.size())
	out.fill(-1)
	if blocks.is_empty() or targets.is_empty():
		return out
	var lo := blocks[0]
	var hi := blocks[0]
	for p in blocks:
		lo = lo.min(p)
		hi = hi.max(p)
	var bucket := {}
	for i in blocks.size():
		if exclude.has(i):
			continue
		var key := Vector2i(floori(blocks[i].x), floori(blocks[i].y))
		if not bucket.has(key):
			bucket[key] = []
		(bucket[key] as Array).append(i)
	var ord := order
	if ord.is_empty():
		var c := Vector2.ZERO
		for t in targets:
			c += t
		c /= targets.size()
		var idx := range(targets.size())
		idx.sort_custom(func(a: int, b: int) -> bool:
			return targets[a].distance_squared_to(c) > targets[b].distance_squared_to(c))
		ord = PackedInt32Array(idx)
	var reach := int(ceil(maxf(hi.x - lo.x, hi.y - lo.y))) + 2
	for ti in ord:
		var tp := targets[ti]
		var tc := Vector2i(floori(tp.x), floori(tp.y))
		var best := -1
		var best_d := INF
		var best_key := Vector2i.ZERO
		for r in reach:
			if best >= 0 and float(r - 1) > sqrt(best_d):
				break
			for dy in range(-r, r + 1):
				var row_edge := absi(dy) == r
				var step := 1 if row_edge else 2 * r
				var dx := -r
				while dx <= r:
					var key := tc + Vector2i(dx, dy)
					if bucket.has(key):
						for bi in bucket[key]:
							var d := blocks[bi].distance_squared_to(tp)
							if d < best_d:
								best_d = d
								best = bi
								best_key = key
					if step == 0:
						break
					dx += step
		if best < 0:
			continue
		out[ti] = best
		(bucket[best_key] as Array).erase(best)
	return out
