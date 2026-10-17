# SPDX-License-Identifier: Apache-2.0
## Text laid out once and drawn glyph by glyph, so each glyph can move, scale,
## rotate, fade or change colour: the kinetic type of the SCF pieces.
##
## The origin is the top-left of the line box, like an absolutely positioned
## <div>: the first baseline sits at half-leading + ascent below it.
## `tracking` is CSS letter-spacing in em (added after every character).
##
## Per-glyph overrides (glyph_fn or apply) use the MotionSvg keys:
##   tx, ty, s, sx, sy, rot (degrees), o, color, hide
## The pivot is the centre of the glyph's advance box.
@tool
@icon("res://addons/motion_kit/icons/text.svg")
class_name MotionText
extends Node2D

@export_multiline var text := "":
	set(v): text = v; _dirty = true; queue_redraw()
@export var font: Font:
	set(v): font = v; _dirty = true; queue_redraw()
@export var font_size := 48.0:
	set(v): font_size = v; _dirty = true; queue_redraw()
@export var color := Color.WHITE:
	set(v): color = v; queue_redraw()
## CSS letter-spacing in em.
@export var tracking := 0.0:
	set(v): tracking = v; _dirty = true; queue_redraw()
## CSS line-height as a multiple of font_size; 0 means "normal" (the font's own).
@export var line_height := 0.0:
	set(v): line_height = v; _dirty = true; queue_redraw()
@export var align := HORIZONTAL_ALIGNMENT_LEFT:
	set(v): align = v; _dirty = true; queue_redraw()
## Width of the box that `align` aligns within. 0 aligns about the origin
## (centre: the text is centred on x = 0; right: it ends at x = 0).
@export var box_width := 0.0:
	set(v): box_width = v; _dirty = true; queue_redraw()
## Characters shown, -1 for all (a typewriter sets this).
@export var visible_chars := -1:
	set(v): visible_chars = v; queue_redraw()
## Uppercase the text when drawing (CSS text-transform: uppercase).
@export var uppercase := false:
	set(v): uppercase = v; _dirty = true; queue_redraw()

## Called from _frame as glyph_fn.call(i, f) -> Dictionary (or null) per character.
var glyph_fn: Callable

var _dirty := true
var _glyphs: Array = []    # {font_rid, size, index, pos: Vector2, adv: float, char_i: int}
var _chars := 0
var _width := 0.0
var _height := 0.0
var _overrides := {}


func _frame(f: float) -> void:
	if glyph_fn.is_valid():
		apply(func(i: int) -> Variant: return glyph_fn.call(i, f))


## Set every character's override from fn(i) -> Dictionary (null or {} for none).
func apply(fn: Callable) -> void:
	_layout()
	_overrides.clear()
	for i in _chars:
		var d: Variant = fn.call(i)
		if d != null and not (d as Dictionary).is_empty():
			_overrides[i] = d
	queue_redraw()


func clear_glyphs() -> void:
	_overrides.clear()
	queue_redraw()


## Number of characters (the indices glyph overrides use).
func char_count() -> int:
	_layout()
	return _chars


## Laid-out size in pixels: widest line including tracking, total line-box height.
func get_text_size() -> Vector2:
	_layout()
	return Vector2(_width, _height)


func _line_box() -> float:
	if not font:
		return font_size
	var asc := font.get_ascent(int(round(font_size)))
	var desc := font.get_descent(int(round(font_size)))
	return font_size * line_height if line_height > 0.0 else asc + desc


func _layout() -> void:
	if not _dirty:
		return
	_dirty = false
	_glyphs.clear()
	_chars = 0
	_width = 0.0
	_height = 0.0
	if not font or text.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var isize := int(round(font_size))
	var k := font_size / float(isize)          # fractional sizes scale the integer-size glyphs
	var asc := font.get_ascent(isize) * k
	var desc := font.get_descent(isize) * k
	var box := _line_box()
	var half_leading := (box - (asc + desc)) * 0.5
	var track := tracking * font_size
	var src := text.to_upper() if uppercase else text
	var lines := src.split("\n")
	var y := 0.0
	var char_base := 0
	var line_records: Array = []
	for line in lines:
		var tl := TextLine.new()
		tl.add_string(line, font, isize)
		var rid := tl.get_rid()
		var glyphs: Array = ts.shaped_text_get_glyphs(rid)
		var x := 0.0
		var recs: Array = []
		for g in glyphs:
			var adv: float = float(g.advance) * k
			var off: Vector2 = (g.get("offset", Vector2.ZERO) as Vector2) * k
			var ci: int = char_base + int(g.start)
			recs.append({font_rid = g.font_rid, size = isize, index = g.index, pos = Vector2(x, 0) + off, adv = adv, char_i = ci, k = k})
			x += adv
			# CSS letter-spacing goes after each character.
			if adv != 0.0:
				x += track
		var line_w := x
		var ox := 0.0
		var avail := box_width
		match align:
			HORIZONTAL_ALIGNMENT_CENTER:
				ox = (avail - line_w) * 0.5 if avail > 0.0 else -line_w * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:
				ox = (avail - line_w) if avail > 0.0 else -line_w
		var baseline := y + half_leading + asc
		for r in recs:
			r.pos += Vector2(ox, baseline)
			r.line_top = y
			_glyphs.append(r)
		_width = maxf(_width, line_w)
		y += box
		char_base += line.length() + 1
	_chars = maxi(0, char_base - 1)
	_height = y


func _draw() -> void:
	_layout()
	if _glyphs.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var ci := get_canvas_item()
	var box := _line_box()
	var count := visible_chars if visible_chars >= 0 else 1 << 30
	for g in _glyphs:
		var i: int = g.char_i
		if i >= count:
			continue
		var o: Dictionary = _overrides.get(i, {})
		if o.get("hide", false):
			continue
		var col: Color = o.get("color", color)
		col.a *= float(o.get("o", 1.0))
		if col.a <= 0.0:
			continue
		var s := float(o.get("s", 1.0))
		var sx := float(o.get("sx", 1.0)) * s
		var sy := float(o.get("sy", 1.0)) * s
		if absf(sx) < 1e-6 or absf(sy) < 1e-6:
			continue
		var pos: Vector2 = g.pos
		var pivot := Vector2(pos.x + float(g.adv) * 0.5, float(g.line_top) + box * 0.5)
		var xf := Transform2D(0.0, Vector2(float(o.get("tx", 0.0)), float(o.get("ty", 0.0))) + pivot) \
			* Transform2D(deg_to_rad(float(o.get("rot", 0.0))), Vector2.ZERO) \
			* Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO) \
			* Transform2D(0.0, -pivot)
		var k: float = g.k
		if not is_equal_approx(k, 1.0):
			xf = xf * Transform2D(Vector2(k, 0), Vector2(0, k), pos - pos * k)
		draw_set_transform_matrix(xf)
		ts.font_draw_glyph(g.font_rid, ci, g.size, pos, g.index, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
