# SPDX-License-Identifier: Apache-2.0
## A rectangle filled with a CSS-style gradient: linear, radial, conic or
## repeating (stripes such as hazard bands), optionally blended with what is
## behind it (CSS mix-blend-mode: add, multiply, screen, overlay).
##
##   var g := MotionGradient.linear(Vector2(1920, 1080), 105.0, [Color(1,1,1,0), Color.WHITE, Color(1,1,1,0)], [0.4, 0.5, 0.6])
##   var hazard := MotionGradient.stripes(Vector2(1920, 54), -45.0, [AMBER, AMBER, BLACK, BLACK], [0, 34, 34, 68])
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionGradient
extends Node2D

enum Kind { LINEAR, RADIAL, CONIC, STRIPES }
enum Blend { NORMAL, ADD, MULTIPLY, SCREEN, OVERLAY }

const SHADER := preload("res://addons/motion_kit/shaders/motion_gradient.gdshader")
const MAX_STOPS := 8

@export var kind := Kind.LINEAR:
	set(v): kind = v; _sync()
## Rectangle size in pixels; the node origin is its top-left corner.
@export var size := Vector2(100, 100):
	set(v): size = v; _sync()
## CSS angle in degrees (LINEAR, STRIPES): 180 = top to bottom, 90 = left to right.
@export var angle := 180.0:
	set(v): angle = v; _sync()
## Centre for RADIAL and CONIC, as a fraction of the size.
@export var center := Vector2(0.5, 0.5):
	set(v): center = v; _sync()
@export var colors: PackedColorArray = PackedColorArray([Color.BLACK, Color.WHITE]):
	set(v): colors = v; _sync()
## Stop positions: 0..1 for LINEAR, RADIAL, CONIC; pixels for STRIPES (the
## last stop is the repeat length).
@export var positions: PackedFloat32Array = PackedFloat32Array([0.0, 1.0]):
	set(v): positions = v; _sync()
## CSS background-position in pixels: moves the gradient (scrolling stripes).
@export var shift := Vector2.ZERO:
	set(v): shift = v; _sync()
@export var blend := Blend.NORMAL:
	set(v): blend = v; _sync()
@export_range(0.0, 1.0) var opacity := 1.0:
	set(v): opacity = v; _sync()

var _mat: ShaderMaterial


static func linear(sz: Vector2, angle_deg: float, cols: Array, pos: Array) -> MotionGradient:
	var g := MotionGradient.new()
	g.kind = Kind.LINEAR
	g.size = sz
	g.angle = angle_deg
	g.colors = PackedColorArray(cols)
	g.positions = PackedFloat32Array(pos)
	return g


static func stripes(sz: Vector2, angle_deg: float, cols: Array, px: Array) -> MotionGradient:
	var g := linear(sz, angle_deg, cols, px)
	g.kind = Kind.STRIPES
	return g


static func radial(sz: Vector2, cols: Array, pos: Array, at := Vector2(0.5, 0.5)) -> MotionGradient:
	var g := linear(sz, 0.0, cols, pos)
	g.kind = Kind.RADIAL
	g.center = at
	return g


func _validate_property(property: Dictionary) -> void:
	if property.name == "material":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_sync()


func _sync() -> void:
	if not _mat:
		return
	var n := mini(mini(colors.size(), positions.size()), MAX_STOPS)
	var cols := PackedColorArray()
	var pos := PackedFloat32Array()
	cols.resize(MAX_STOPS)
	pos.resize(MAX_STOPS)
	for i in MAX_STOPS:
		cols[i] = colors[mini(i, n - 1)] if n > 0 else Color.BLACK
		pos[i] = positions[mini(i, n - 1)] if n > 0 else 0.0
	_mat.set_shader_parameter("kind", int(kind))
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("angle_deg", angle)
	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("shift", shift)
	_mat.set_shader_parameter("stop_count", maxi(n, 1))
	_mat.set_shader_parameter("stop_colors", cols)
	_mat.set_shader_parameter("stop_pos", pos)
	_mat.set_shader_parameter("blend", int(blend))
	_mat.set_shader_parameter("opacity", opacity)
	queue_redraw()


func _draw() -> void:
	if size.x > 0.0 and size.y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
