# SPDX-License-Identifier: Apache-2.0
## Event rings for shaders: hits, footsteps and landings send a ring running
## out across the ground, and any shader including
## `shaders/motion_ripples.gdshaderinc` reads them (grass that bends and
## ripples, water, ground decals). The ring-rise idea from Time City, driven
## by game events instead of beats. Up to 16 rings at once; the oldest is
## replaced.
##
##   var ripples := MotionRipples.new()
##   ripples.register(grass.material_override)
##   GameEvents.event.connect(func(n, pos, k, d): ripples.add(pos, k))
##   ripples.step(clock.dt); ripples.apply()          # every frame
##
## offset(p) mirrors the shader in GDScript for CPU-moved things.
class_name MotionRipples
extends RefCounted

const MAX := 16

## Metres per second the rings run out, their width, and their decay (1/s).
var speed := 3.0
var width := 0.6
var decay := 2.2
## Seconds after which a ring is dropped.
var life := 1.8
var time := 0.0
var materials: Array[ShaderMaterial] = []

var _rings: Array[Vector4] = []      # x, z, start time, strength


## Start a ring at a world point (Vector3: x, z used; or Vector2 x, z).
func add(pos: Variant, strength := 1.0) -> void:
	var p := Vector2(pos.x, pos.z) if pos is Vector3 else (pos as Vector2)
	if _rings.size() >= MAX:
		_rings.pop_front()
	_rings.append(Vector4(p.x, p.y, time, strength))


func register(m: ShaderMaterial) -> ShaderMaterial:
	materials.append(m)
	return m


func step(dt: float) -> void:
	time += maxf(dt, 0.0)
	while not _rings.is_empty() and time - _rings[0].z > life:
		_rings.pop_front()


## The rings as the shader wants them: (x, z, age, strength), padded.
func uniforms() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for r in _rings:
		out.append(Vector4(r.x, r.y, time - r.z, r.w))
	while out.size() < MAX:
		out.append(Vector4(0, 0, -1, 0))
	return out


## Push every value to every registered material (once per frame).
func apply() -> void:
	var u := uniforms()
	for m in materials:
		m.set_shader_parameter(&"mk_ripples", u)
		m.set_shader_parameter(&"mk_ripple_count", _rings.size())
		m.set_shader_parameter(&"mk_ripple_speed", speed)
		m.set_shader_parameter(&"mk_ripple_width", width)
		m.set_shader_parameter(&"mk_ripple_decay", decay)


## The shader's result at a world point: Vector3(push x, push z, amount).
func offset(pos: Variant) -> Vector3:
	var p := Vector2(pos.x, pos.z) if pos is Vector3 else (pos as Vector2)
	var push := Vector2.ZERO
	var amount := 0.0
	for r in _rings:
		var age := time - r.z
		var d := p - Vector2(r.x, r.y)
		var dist := d.length()
		var k := 1.0 - smoothstep(0.0, width, absf(dist - age * speed))
		k *= r.w * exp(-age * decay)
		amount += k
		if dist > 1e-4:
			push += d / dist * k
	return Vector3(push.x, push.y, amount)


func count() -> int:
	return _rings.size()
