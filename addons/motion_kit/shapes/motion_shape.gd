# SPDX-License-Identifier: Apache-2.0
## Circles, rounded rectangles, pills, rings and arcs drawn as signed-distance
## fields: one quad each, edges anti-aliased at any scale. The node's origin
## is the shape's centre (`anchor` moves it), so scale and rotation pivot there
## the way the SCF discs and wipes did.
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionShape
extends Node2D

enum Kind { CIRCLE, RECT, RING, ARC }

const SHADER := preload("res://addons/motion_kit/shaders/motion_shape.gdshader")

@export var kind := Kind.CIRCLE:
	set(v): kind = v; _sync()
## Full size in pixels. A circle uses size.x as its diameter unless size.y differs (ellipse).
@export var size := Vector2(100, 100):
	set(v): size = v; _sync()
@export var color := Color.WHITE:
	set(v): color = v; _sync()
## Corner radius for RECT; a radius of size.y / 2 makes a pill.
@export var radius := 0.0:
	set(v): radius = v; _sync()
## Line width for RING and ARC.
@export var thickness := 4.0:
	set(v): thickness = v; _sync()
## Visible part of a RING or ARC, in turns from 12 o'clock, clockwise.
@export var sweep_from := 0.0:
	set(v): sweep_from = v; _sync()
@export var sweep_to := 1.0:
	set(v): sweep_to = v; _sync()
## Split a RING or ARC into this many dashes (0 = solid).
@export var dashes := 0.0:
	set(v): dashes = v; _sync()
@export_range(0.0, 1.0) var dash_fill := 0.9:
	set(v): dash_fill = v; _sync()
## Soft edge: CSS blur radius in pixels (box-shadow blur, filter: blur). 0 = sharp.
@export var blur := 0.0:
	set(v): blur = v; _sync()
## Where the node origin sits on the shape: (0.5, 0.5) centre, (0, 0) top-left.
@export var anchor := Vector2(0.5, 0.5):
	set(v): anchor = v; queue_redraw()

var _mat: ShaderMaterial


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_sync()


## A pill sized w × h (fully rounded ends).
static func pill(w: float, h: float, col: Color) -> MotionShape:
	var s := MotionShape.new()
	s.kind = Kind.RECT
	s.size = Vector2(w, h)
	s.radius = h * 0.5
	s.color = col
	return s


static func circle(diameter: float, col: Color) -> MotionShape:
	var s := MotionShape.new()
	s.size = Vector2(diameter, diameter)
	s.color = col
	return s


func _sync() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("kind", [0, 1, 2, 3][kind])
	_mat.set_shader_parameter("half_size", size * 0.5)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("thickness", thickness)
	_mat.set_shader_parameter("sweep_from", sweep_from)
	_mat.set_shader_parameter("sweep_to", sweep_to)
	_mat.set_shader_parameter("dash_count", dashes)
	_mat.set_shader_parameter("dash_fill", dash_fill)
	_mat.set_shader_parameter("fill_color", color)
	_mat.set_shader_parameter("blur", blur)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Pad by a few screen pixels so the soft edge is never clipped.
	var sc := get_global_transform_with_canvas().get_scale()
	var k := maxf(absf(sc.x), absf(sc.y))
	var pad := 3.0 / maxf(k, 1e-4) + blur * 1.6
	var h := size * 0.5 + Vector2(pad, pad)
	var c := (Vector2(0.5, 0.5) - anchor) * size
	_mat.set_shader_parameter("center", c)
	var pts := PackedVector2Array([c + Vector2(-h.x, -h.y), c + Vector2(h.x, -h.y), c + Vector2(h.x, h.y), c + Vector2(-h.x, h.y)])
	draw_colored_polygon(pts, Color.WHITE)
