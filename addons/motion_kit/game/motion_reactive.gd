# SPDX-License-Identifier: Apache-2.0
## Drop under any Control (a Button, a menu item) to give it spring feedback on
## hover, focus and press. Works with the mouse, touch and gamepad focus, and
## inside Containers: the offset is applied on top of wherever layout puts the
## control. The parent's pivot is set to its centre, so it scales in place.
@tool
@icon("res://addons/motion_kit/icons/spring.svg")
class_name MotionReactive
extends Node

@export var hover_scale := 1.08
@export var focus_scale := 1.08
@export var press_scale := 0.94
## Pixels the control moves while hovered or focused (e.g. a nudge to the right).
@export var hover_offset := Vector2.ZERO
@export var damping := 9.0
@export var stiffness := 180.0
## Also tween the parent's modulate towards this colour while hovered.
@export var hover_tint := Color.WHITE
@export var ignore_time_scale := true

var _scale := MotionSpring.new(1.0)
var _off_x := MotionSpring.new(0.0)
var _off_y := MotionSpring.new(0.0)
var _tint := MotionSpring.new(0.0)
var _ctrl: Control
var _base_pos := Vector2.ZERO
var _written := Vector2.INF   # last position this node set
var _hover := false
var _focus := false
var _press := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ctrl = get_parent() as Control
	if not _ctrl:
		push_warning("MotionReactive must be a child of a Control")
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in [_scale, _off_x, _off_y, _tint]:
		s.damping = damping
		s.stiffness = stiffness
	_ctrl.mouse_entered.connect(func(): _hover = true)
	_ctrl.mouse_exited.connect(func(): _hover = false; _press = false)
	_ctrl.focus_entered.connect(func(): _focus = true)
	_ctrl.focus_exited.connect(func(): _focus = false)
	if _ctrl is BaseButton:
		(_ctrl as BaseButton).button_down.connect(func(): _press = true)
		(_ctrl as BaseButton).button_up.connect(func(): _press = false)
	_ctrl.resized.connect(_centre_pivot)
	_centre_pivot()
	_base_pos = _ctrl.position
	if _ctrl.get_parent() is Container:
		(_ctrl.get_parent() as Container).sort_children.connect(func(): _written = Vector2.INF)


## Take the control's current position as its rest position. Called
## automatically when anything else (a Container, your code) moves it.
func rebase() -> void:
	if _ctrl:
		_base_pos = _ctrl.position


func _centre_pivot() -> void:
	_ctrl.pivot_offset = _ctrl.size * 0.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _ctrl:
		return
	var dt := delta / Engine.time_scale if ignore_time_scale and Engine.time_scale > 0.0 else delta
	var lit := _hover or _focus
	_scale.target = press_scale if _press else (maxf(hover_scale if _hover else 1.0, focus_scale if _focus else 1.0))
	_off_x.target = hover_offset.x if lit else 0.0
	_off_y.target = hover_offset.y if lit else 0.0
	_tint.target = 1.0 if lit else 0.0
	var s := _scale.step(dt)
	_ctrl.scale = Vector2(s, s)
	var off := Vector2(_off_x.step(dt), _off_y.step(dt))
	if hover_offset != Vector2.ZERO or off != Vector2.ZERO:
		# Someone else moved the control (a Container sorting, a script): that is the new rest.
		if _ctrl.position != _written:
			_base_pos = _ctrl.position
		_written = _base_pos + off
		_ctrl.position = _written
	if hover_tint != Color.WHITE:
		_ctrl.modulate = Color.WHITE.lerp(hover_tint, clampf(_tint.step(dt), 0.0, 1.0))
