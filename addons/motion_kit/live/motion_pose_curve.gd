# SPDX-License-Identifier: Apache-2.0
## Authored key poses as data: named channels of keys (frames at `fps`) with
## an easing per channel or per segment, plus named markers (when a hitbox
## opens, when the next attack may cancel in). Sample a channel at "frames
## since the move started" (a MotionClock) and layer procedural offsets on
## top. A sword swing becomes four to six keys you can tweak in the
## inspector or a .tres without touching code.
##
##   var swing := preload("res://moves/swing_1.tres") as MotionPoseCurve
##   var f := clock.frames_since(&"swing")
##   var arc := swing.sample(&"arc", f, view)        # "arc.front" overrides "arc" in that view
##   var live := swing.between(f, &"active_from", &"active_to")
##
## Channels: {name: {keys: [frames], values: [float | Vector2 | Vector3],
## ease: "ease_out" | [x1, y1, x2, y2] | [one per segment]}}. Easing names:
## linear, ease_out, ease_in_out, ease_in_back, ease_out_back, ease_in_quad.
## A channel named "x.view" is used instead of "x" when sampled for that view.
@tool
class_name MotionPoseCurve
extends Resource

## Length of the move in frames (after it, sample() holds the last keys).
@export var length := 18.0
@export var fps := 30.0
@export var channels: Dictionary = {}
## Named frames: active_from, active_to, cancel, end, hit...
@export var markers: Dictionary = {}
## Free-form move data: power, reach, sound intensity, knockback...
@export var data: Dictionary = {}

var _cache := {}      # channel -> {keys: Array, values: Array, eases: Array[Callable]}
var _keys := {}       # [name, view] -> the channel key used (resolved once)


## Channel `name` at frame `f` (for `view`, if given). Missing channels give
## `fallback`.
func sample(name: StringName, f: float, view: StringName = &"", fallback: Variant = 0.0) -> Variant:
	var key: String = _keys.get([name, view], "")
	if key == "":
		key = String(name)
		if view != &"" and channels.has("%s.%s" % [key, view]):
			key = "%s.%s" % [key, view]
		if not channels.has(key):
			key = "-"
		_keys[[name, view]] = key
	if key == "-":
		return fallback
	var c := _compiled(key)
	var keys: Array = c.keys
	var values: Array = c.values
	var n := keys.size()
	if n == 0:
		return fallback
	if n == 1 or f <= float(keys[0]):
		return values[0]
	if f >= float(keys[n - 1]):
		return values[n - 1]
	var i := 0
	while i < n - 2 and f >= float(keys[i + 1]):
		i += 1
	var u := (f - float(keys[i])) / maxf(float(keys[i + 1]) - float(keys[i]), 1e-9)
	var e: Callable = (c.eases as Array)[mini(i, (c.eases as Array).size() - 1)]
	var t: float = e.call(clampf(u, 0.0, 1.0))
	var a: Variant = values[i]
	var b: Variant = values[i + 1]
	return lerp(a, b, t)


## Float channel in degrees, returned in radians.
func sample_deg(name: StringName, f: float, view: StringName = &"", fallback := 0.0) -> float:
	return deg_to_rad(float(sample(name, f, view, fallback)))


func has_channel(name: StringName, view: StringName = &"") -> bool:
	return channels.has(String(name)) or (view != &"" and channels.has("%s.%s" % [name, view]))


## A marker's frame (`fallback` if unset).
func marker(name: StringName, fallback := -1.0) -> float:
	return float(markers.get(String(name), fallback))


## True while `f` is between two markers (inclusive).
func between(f: float, from: StringName, to: StringName) -> bool:
	return f >= marker(from, INF) and f <= marker(to, -INF)


## True once the move has run its length.
func is_done(f: float) -> bool:
	return f >= length


## Seconds the move lasts.
func duration() -> float:
	return length / fps


## Mix two moves' channel at weight `w` (0 = this, 1 = other), each sampled
## at its own frame: a combo blending into the next swing.
func blend(other: MotionPoseCurve, w: float, name: StringName, f_self: float, f_other: float, view: StringName = &"", fallback: Variant = 0.0) -> Variant:
	var a: Variant = sample(name, f_self, view, fallback)
	if other == null or w <= 0.0:
		return a
	return lerp(a, other.sample(name, f_other, view, fallback), clampf(w, 0.0, 1.0))


## Call after editing `channels` from code.
func changed_channels() -> void:
	_cache.clear()
	_keys.clear()
	emit_changed()


static func easing(spec: Variant) -> Callable:
	if spec is Array and (spec as Array).size() == 4 and not ((spec as Array)[0] is String):
		var a: Array = spec
		return MK.bezier(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	match String(spec):
		"ease_out": return MK.ease_out
		"ease_in_out": return MK.ease_in_out
		"ease_in_back": return MK.ease_in_back
		"ease_out_back": return MK.ease_out_back
		"ease_in_quad": return MK.ease_in_quad
	return MK.linear


func _compiled(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var ch: Dictionary = channels[key]
	var keys: Array = Array(ch.get("keys", []))
	var values: Array = Array(ch.get("values", []))
	var spec: Variant = ch.get("ease", "linear")
	var eases: Array[Callable] = []
	if spec is Array and not ((spec as Array).size() == 4 and not ((spec as Array)[0] is String)):
		for s in spec:
			eases.append(MotionPoseCurve.easing(s))
	else:
		eases.append(MotionPoseCurve.easing(spec))
	var c := {keys = keys, values = values, eases = eases}
	_cache[key] = c
	return c
