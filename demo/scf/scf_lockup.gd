# SPDX-License-Identifier: Apache-2.0
# The SCF lockup from scf-intros (super.tsx SCFLockup): discs drop and jelly-land,
# connectors and nodes pop, the wordmark bounces in, the rule draws, the pills
# pop; it breathes during the hold and unbuilds in mirror from `out_at`,
# leaving an empty frame.
@tool
class_name SCFLockup
extends Node2D

const SCF_W := 1700.0
const TAGS := ["1.0", "OPEN FORMAT", "SQLITE"]
const TAGS_FEATURE := ["1.0", "OPEN FORMAT"]

@export var t0 := 160.0
@export var out_at := 345.0
@export var x := 110.0
@export var y := 270.0
@export var letter_col := SCFBrand.INK
@export var presents_col := SCFBrand.INK
@export var rule_col := SCFBrand.INK
@export var pill_text_col := SCFBrand.CREAM
@export var use_cloud := false
@export var cloud_col := SCFBrand.CREAM
@export var override_edges := false
@export var edges_col := SCFBrand.INK
@export var tags: PackedStringArray = PackedStringArray(TAGS)
@export var pill_cols: Array[Color] = [SCFBrand.RED, SCFBrand.BLUE, SCFBrand.AMBER]
## "bounce" or "draw"
@export var word_in := "bounce"

var part_override: Callable   # (i, base: Variant) -> Variant

var _logo: MotionSvg
var _rule: MotionShape
var _presents: MotionText
var _pills: Array[MotionPill] = []
var _k := 1.0


func _ready() -> void:
	_presents = MotionText.new()
	_presents.text = "MINIMAL HUMANS PRESENTS"
	_presents.font = SCFBrand.font("outfit", 800)
	_presents.font_size = 30
	_presents.tracking = 0.3
	add_child(_presents)
	_logo = MotionSvg.new()
	_logo.data = SCFBrand.logo("scfFull")
	_logo.width = SCF_W
	_logo.chromium_draw = true   # match the Remotion originals
	add_child(_logo)
	_k = SCF_W / _logo.data.view_box.size.x
	_rule = MotionShape.new()
	_rule.kind = MotionShape.Kind.RECT
	_rule.anchor = Vector2.ZERO
	add_child(_rule)
	var fnt := SCFBrand.font("outfit", 800)
	for i in tags.size():
		var p := MotionPill.new()
		p.font = fnt
		p.font_size = 28
		p.text = tags[i]
		var c: Color = pill_cols[i % pill_cols.size()]
		p.background = c
		p.text_color = SCFBrand.INK if (c == SCFBrand.AMBER or c == SCFBrand.CREAM) else pill_text_col
		add_child(p)
		_pills.append(p)


func _frame(f: float) -> void:
	if not _logo:
		return
	var M: Dictionary = SCFBrand.SCF_FULL
	var r := f - t0
	var o := f - out_at
	var land := {S = 8.0, C = 14.0, F = 20.0}
	var leave := {F = 34.0, C = 38.0, S = 42.0}
	var words: Array = M.story + M.context + M.framework
	var hold := r > 92.0 and o < 0.0
	var data := _logo.data
	var out_e := func(start: float, dur: float) -> float:
		return MK.map(o, [start, start + dur], [0, 1], MK.ease_in_back)

	var part := func(i: int) -> Variant:
		if i == M.cloud:
			if not use_cloud:
				return {hide = true}
			var s: float = SCFBrand.sp(f, t0 + 2, 11, 110) * (1.0 - out_e.call(44, 12))
			return {hide = true} if s <= 0.001 else {s = s, fill = cloud_col}
		var d := ""
		if i == M.discS or (M.S as Array).has(i): d = "S"
		elif i == M.discC or (M.C as Array).has(i): d = "C"
		elif i == M.discF or (M.F as Array).has(i): d = "F"
		if d != "":
			var disc_i: int = M["disc" + d]
			var bb: Rect2 = data.parts[disc_i].bbox
			var cx := bb.get_center().x
			var cy := bb.get_center().y
			var rr := bb.size.x * 0.5
			var at: float = land[d]
			if r < at - 8.0:
				return {hide = true}
			var s: float = SCFBrand.sp(f, t0 + at - 8.0, 7, 160)
			var tt := r - at
			var sq := 0.24 * exp(-tt / 5.0) * cos(tt * 0.95) if tt > 0.0 else 0.0
			var ph := 1.2 if d == "C" else (2.4 if d == "F" else 0.0)
			var bob := sin((r - 92.0) / 9.0 + ph) * 1.4 * minf(1.0, (r - 92.0) / 10.0) if hold else 0.0
			var lt: float = leave[d]
			var antic := MK.map(o, [lt - 4.0, lt], [0, 1]) * (1.0 - MK.map(o, [lt, lt + 3.0], [0, 1]))
			var up := MK.map(o, [lt, lt + 12.0], [0, 1], MK.ease_in_quad)
			if up >= 1.0:
				return {hide = true}
			return {ty = (1.0 - s) * -170.0 + bob - up * 190.0, sy = 1.0 - sq - antic * 0.22 + up * 0.15,
				sx = 1.0 + sq * 0.8 + antic * 0.18 - up * 0.1, pivot = Vector2(cx, cy + rr)}
		var ei := (M.edges as Array).find(i)
		if ei >= 0:
			var at := 30.0 + ei * 2.0
			if r < at:
				return {hide = true}
			var s: float = SCFBrand.sp(f, t0 + at, 9, 180) * (1.0 - out_e.call(28, 8))
			if s <= 0.001:
				return {hide = true}
			var e := {s = s, pivot = Vector2(52.8, 43.4)}
			if override_edges:
				e.fill = edges_col
			return e
		var k := (M.nodes as Array).find(i)
		if k >= 0:
			var at := 36.0 + k * 1.6
			if r < at:
				return {hide = true}
			var bob := sin((r - 92.0) / 7.0 + k) * 0.9 if hold else 0.0
			var s: float = SCFBrand.sp(f, t0 + at, 6, 200) * (1.0 - out_e.call(16.0 + ((M.nodes as Array).size() - 1 - k) * 1.2, 8))
			return {hide = true} if s <= 0.001 else {s = s, ty = bob}
		var w := words.find(i)
		if w >= 0:
			var at := 70.0 + w * 1.1
			if r < at:
				return {hide = true}
			var back := (words.size() - 1 - w) * 0.6
			var ex := MK.map(o, [4.0 + back, 12.0 + back], [0, 1], MK.ease_in_back)
			if ex >= 1.0:
				return {hide = true}
			if word_in == "draw":
				var dd := MK.map(r, [at, at + 18], [0, 1])
				var fo := MK.map(r, [at + 10, at + 20], [0, 1])
				var base := {fill = letter_col} if fo >= 1.0 else {draw = dd, fill = letter_col, draw_width = 3.0, fill_o = fo}
				base.ty = ex * 50.0
				base.s = 1.0 - ex * 0.5
				return base
			var s: float = SCFBrand.sp(f, t0 + at, 8, 180)
			return {fill = letter_col, ty = (1.0 - s) * 40.0 + ex * 50.0, s = lerpf(0.4, 1.0, minf(1.0, s)) * (1.0 - ex * 0.5)}
		return null

	_logo.apply(func(i: int) -> Variant:
		var base: Variant = part.call(i)
		return part_override.call(i, base) if part_override.is_valid() else base)
	_logo.position = Vector2(x, y)

	_presents.position = Vector2(x + 110.0 * _k, y - 56.0)
	_presents.color = presents_col
	_presents.modulate.a = MK.prog(r, 76, 10) * (1.0 - MK.prog(o, 2, 6))

	var rule_w := MK.map(r, [82, 96], [0, 171.0 * _k], MK.ease_in_out) * (1.0 - MK.map(o, [0, 8], [0, 1], MK.ease_in_out))
	_rule.position = Vector2(x + 110.0 * _k, y + 84.0 * _k)
	_rule.size = Vector2(rule_w, 14)
	_rule.color = rule_col
	_rule.visible = rule_w > 0.0

	# Pills: a flex row with a 16 px gap, each popping from its centre.
	var px := x + 110.0 * _k
	var py := y + 84.0 * _k + 30.0
	for i in _pills.size():
		var p := _pills[i]
		var sz := p.get_box_size()
		p.position = Vector2(px + sz.x * 0.5, py + sz.y * 0.5)
		px += sz.x + 16.0
		var s: float = SCFBrand.sp(f, t0 + 92.0 + i * 3.0, 8, 200) * (1.0 - MK.map(o, [i * 2.0, i * 2.0 + 6.0], [0, 1], MK.ease_in_back))
		p.scale = Vector2.ONE * maxf(0.0, s)
		p.visible = s > 0.0
