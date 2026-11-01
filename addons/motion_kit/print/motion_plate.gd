# SPDX-License-Identifier: Apache-2.0
## One colour plate of a printed sheet (risograph, screen print, offset).
## Put what the plate prints under `content`, drawn in black on transparent:
## black prints solid ink, greys print a tint, white knocks out (so a white
## shape drawn over a black one leaves paper showing, a print "knockout").
## The plate renders offscreen and is multiplied onto whatever is drawn under
## it, so plates overprint each other and the paper the way transparent inks
## do: pink over blue gives purple, anything under black stays black.
##
## Per plate: `ink` colour and `density` (ink printing in), a halftone screen
## (`cell`, `angle_deg`, `dot`), registration error (`misregister`,
## `misrotate`, about the plate's centre, carrying the screen with it), ink
## texture (`roughness`, `grain`, `mottle`, `slur`) and a press roller
## (`roll` 0..1 along `roll_dir`, with a ragged edge and a shadow).
##
## Frame-pure: every property is plain state set from `f`; the noise is seeded
## and static. Plates must be drawn over an opaque backdrop (a MotionPaper),
## not inside a transparent MotionFX, since multiply needs something to
## multiply with. A hidden plate stops rendering its content.
@tool
@icon("res://addons/motion_kit/icons/print.svg")
class_name MotionPlate
extends Node2D

const SHADER := preload("res://addons/motion_kit/print/motion_plate.gdshader")

enum Dot { ROUND, LINE, SQUARE, DIAMOND }

## Size of the plate (the content area) in pixels.
@export var size := Vector2(1920, 1080):
	set(v): size = v; _resize()
@export var ink := Color("#e92067")
## How much ink is laid down: 0 nothing, 1 full. Animate it to fade a plate in.
@export_range(0.0, 1.0) var density := 1.0
## Multiplies the content's ink amount (draw black, set 0.4 for a 40% tint).
@export var tone_scale := 1.0
@export_group("Registration")
## How far the plate is off register, in pixels (see `register()`).
@export var misregister := Vector2.ZERO
## Rotation error in degrees, about the plate's centre.
@export var misrotate := 0.0
@export_group("Halftone")
## Halftone cell in pixels; 0 prints solid ink.
@export var cell := 0.0
## Screen angle in degrees (traditionally 15, 45, 75 or 0 for different plates).
@export var angle_deg := 15.0
@export var dot := Dot.ROUND
@export_group("Ink")
## Ragged ink edges, in pixels.
@export var roughness := 0.0
## Speckles where the ink missed the paper, 0..1.
@export_range(0.0, 1.0) var grain := 0.0
## Uneven ink laydown, 0..1.
@export_range(0.0, 1.0) var mottle := 0.0
## A doubled ghost image offset by `slur` pixels at `slur_amount` strength.
@export var slur := Vector2.ZERO
@export_range(0.0, 1.0) var slur_amount := 0.0
@export var seed := 1.0
@export_group("Roller")
## 0..1 how far the press roller has printed the plate (1 = all of it).
@export_range(0.0, 1.0) var roll := 1.0
## The roller's direction of travel.
@export var roll_dir := Vector2(1, 0)
## Ragged width of the roller's edge in pixels.
@export var roll_soft := 36.0
## Darkens a band at the roller while it passes, 0..1.
@export_range(0.0, 1.0) var roll_shadow := 0.0

## Where to add what the plate prints.
var content: Node2D

var _vp: SubViewport
var _view: Sprite2D
var _mat: ShaderMaterial


func _init() -> void:
	content = MotionOffscreen.holder("Content")
	_vp = MotionOffscreen.make(self, content, SubViewport.UPDATE_ALWAYS, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
	_view = Sprite2D.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_view.material = _mat
	add_child(_view, false, Node.INTERNAL_MODE_FRONT)
	_resize()


func _ready() -> void:
	if not Engine.is_editor_hint():
		for c in get_children():
			c.reparent(content, false)
	_resize()
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _vp:
		MotionOffscreen.gate(_vp, is_visible_in_tree())


func _resize() -> void:
	if not _vp:
		return
	MotionOffscreen.fit(_vp, size, 1.0, false)
	_view.position = size * 0.5


func _frame(_f: float) -> void:
	_apply()


func _process(_d: float) -> void:
	_apply()


func _apply() -> void:
	if not _mat:
		return
	_view.position = size * 0.5 + misregister
	_view.rotation = deg_to_rad(misrotate)
	_mat.set_shader_parameter("ink", ink)
	_mat.set_shader_parameter("density", density)
	_mat.set_shader_parameter("plate_size", size)
	_mat.set_shader_parameter("tone_scale", tone_scale)
	_mat.set_shader_parameter("cell", cell)
	_mat.set_shader_parameter("angle", deg_to_rad(angle_deg))
	_mat.set_shader_parameter("dot_shape", int(dot))
	_mat.set_shader_parameter("roughness", roughness)
	_mat.set_shader_parameter("grain", grain)
	_mat.set_shader_parameter("mottle", mottle)
	_mat.set_shader_parameter("seed", seed)
	_mat.set_shader_parameter("roll", roll)
	_mat.set_shader_parameter("roll_dir", roll_dir)
	_mat.set_shader_parameter("roll_soft", roll_soft)
	_mat.set_shader_parameter("roll_shadow", roll_shadow)
	_mat.set_shader_parameter("slur", slur)
	_mat.set_shader_parameter("slur_amount", slur_amount)


## Registration error that holds at `error` and snaps into register at frame
## `settle_at` over `snap` frames, with a small overshoot (the plate clamping
## home). Frame-pure.
static func register(f: float, settle_at: float, error: Vector2, snap := 3.0) -> Vector2:
	if f < settle_at:
		return error
	var t := clampf((f - settle_at) / snap, 0.0, 1.0)
	var over := sin(t * PI) * 0.18 * exp(-(f - settle_at) / (snap * 1.5))
	return error * (1.0 - t) - error * over


## The roller's progress for a plate printing from frame `at` over `frames`:
## 0 before, eased 0..1 during, 1 after. Frame-pure.
static func print_in(f: float, at: float, frames := 10.0) -> float:
	return MK.map(f, [at, at + frames], [0, 1], MK.ease_in_out)


## Press-shake: a short vertical judder when plates hit, as a parent offset.
static func thunk(f: float, ats: Array, amp := 4.0, dur := 6.0) -> Vector2:
	var y := 0.0
	for a in ats:
		var t := f - float(a)
		if t >= 0.0 and t < dur:
			y += amp * (1.0 - t / dur) * (1.0 if int(t) % 2 == 0 else -1.0)
	return Vector2(0, y)
