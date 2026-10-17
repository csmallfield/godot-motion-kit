# SPDX-License-Identifier: Apache-2.0
## A text label on a rounded background (CSS: padding + border-radius), the
## tag pills of the SCF lockups and a common UI element. The node origin is
## the pill's centre, so scale pops it in place; `top_left` gives the box corner.
@tool
class_name MotionPill
extends Node2D

@export var text := "":
	set(v): text = v; _sync()
@export var font: Font:
	set(v): font = v; _sync()
@export var font_size := 28.0:
	set(v): font_size = v; _sync()
@export var text_color := Color.WHITE:
	set(v): text_color = v; _sync()
@export var background := Color.BLACK:
	set(v): background = v; _sync()
## Horizontal and vertical padding in pixels.
@export var padding := Vector2(18, 6):
	set(v): padding = v; _sync()
@export var corner_radius := 40.0:
	set(v): corner_radius = v; _sync()
@export var tracking := 0.0:
	set(v): tracking = v; _sync()

var _bg: MotionShape
var _label: MotionText


func _init() -> void:
	_bg = MotionShape.new()
	_bg.kind = MotionShape.Kind.RECT
	_label = MotionText.new()
	add_child(_bg, false, Node.INTERNAL_MODE_FRONT)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	_sync()


## Box size in pixels.
func get_box_size() -> Vector2:
	if not font:
		return Vector2.ZERO
	return _label.get_text_size() + padding * 2.0


func _sync() -> void:
	if not _label:
		return
	_label.text = text
	_label.font = font
	_label.font_size = font_size
	_label.color = text_color
	_label.tracking = tracking
	var sz := get_box_size()
	_bg.size = sz
	_bg.radius = minf(corner_radius, sz.y * 0.5)
	_bg.color = background
	_label.position = -sz * 0.5 + padding
