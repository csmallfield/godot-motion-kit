# SPDX-License-Identifier: Apache-2.0
# The Minimal Humans entrance from scf-intros (super.tsx MHLockup): the monogram
# springs in with its three layers fanned apart, stacks, slides to the lockup,
# then the wordmark draws itself and PRESENTS settles its tracking.
# All timing is relative to `t0`.
@tool
class_name MHLockup
extends Node2D

const MH_W := 1500.0

@export var t0 := 4.0
@export var x := 210.0
@export var y := 280.0
@export var letter_col := SCFBrand.CREAM
@export var draw_col := SCFBrand.AMBER
@export var presents_col := SCFBrand.CREAM
@export var rule_col := SCFBrand.AMBER

var mono_fill: Callable   # optional (layer index) -> Color

var _box: Node2D
var _logo: MotionSvg
var _rule: MotionShape
var _presents: MotionText
var _k := 1.0


func _ready() -> void:
	_box = Node2D.new()
	add_child(_box)
	_logo = MotionSvg.new()
	_logo.data = SCFBrand.logo("mhFull")
	_logo.width = MH_W
	_logo.chromium_draw = true   # match the Remotion originals
	_box.add_child(_logo)
	_k = MH_W / _logo.data.view_box.size.x
	_rule = MotionShape.new()
	_rule.kind = MotionShape.Kind.RECT
	_rule.anchor = Vector2.ZERO
	add_child(_rule)
	_presents = MotionText.new()
	_presents.text = "PRESENTS"
	_presents.font = SCFBrand.font("outfit", 800)
	_presents.font_size = 52
	add_child(_presents)


func _frame(f: float) -> void:
	if not _logo:
		return
	var r := f - t0
	var mono := SCFBrand.sp(f, t0 + 6, 9, 120)
	var fan := 1.0 + (1.0 - SCFBrand.sp(f, t0 + 10, 8, 110)) * 3.0
	var to_lock := MK.map(r, [30, 46], [0, 1], MK.ease_in_out)
	_box.position = Vector2(lerpf(960.0 - 60.0 * _k * 1.3, x, to_lock), lerpf(540.0 - 64.0 * _k * 1.3, y, to_lock))
	_box.scale = Vector2.ONE * lerpf(1.3, 1.0, to_lock)

	var letters: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
	_logo.apply(func(i: int) -> Variant:
		var li := SCFBrand.MH_FULL_M.find(i)
		if li >= 0:
			var off := (2 - li) * (fan - 1.0) * 5.0
			var d := {s = mono, tx = off, ty = off, pivot = Vector2(60, 64)}
			if mono_fill.is_valid():
				var c: Variant = mono_fill.call(li)
				if c != null:
					d.fill = c
			return d
		var k := letters.find(i)
		var at := 44.0 + k * 3.2
		if r < at:
			return {hide = true}
		var dd := MK.map(r, [at, at + 20], [0, 1], MK.linear)
		var fill_o := MK.map(r, [at + 12, at + 22], [0, 1])
		if fill_o >= 1.0:
			return {fill = letter_col}
		return {draw = dd, fill = letter_col, stroke = draw_col, draw_width = 5.0, fill_o = fill_o})

	# PRESENTS: a rule draws, then the word settles its tracking.
	var rw := MK.map(r, [92, 108], [0, 920], MK.ease_in_out)
	_rule.position = Vector2(x + 145.0 * _k, y + 129.0 * _k + 34.0)
	_rule.size = Vector2(rw, 6)
	_rule.color = rule_col
	_rule.visible = rw > 0.0
	_presents.position = Vector2(x + 145.0 * _k, y + 129.0 * _k + 58.0)
	_presents.color = presents_col
	_presents.tracking = lerpf(0.9, 0.42, MK.prog(r, 98, 22))
	_presents.modulate.a = MK.prog(r, 98, 12)
