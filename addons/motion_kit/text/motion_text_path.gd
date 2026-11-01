# SPDX-License-Identifier: Apache-2.0
## Text set along a path: each glyph sits on the path at its own arc length,
## turned to the path's direction, like SVG <textPath>. Animate `offset` to run
## the text along the path (a ticker on hazard tape, a slogan circling a badge),
## set `repeat` to tile it along the whole path, and `closed` for loops.
##
## The path is `points` (a polyline in this node's space; sample curves finely).
## Glyphs are shaped once with the font's fallbacks, as MotionText shapes them,
## so Latin, Cyrillic and Japanese mix in one line.
##
## Per-glyph overrides (glyph_fn) take the MotionText keys:
##   tx, ty (along and across the path, px), s, rot (degrees), o, color, hide
## glyph_fn(i, s) gets the glyph's index in the text and its arc length on the
## path (px from the path's start), so effects can follow the path (a wave
## running along the tape) or the text (a highlighted word).
@tool
@icon("res://addons/motion_kit/icons/text.svg")
class_name MotionTextPath
extends Node2D

enum Align { START, CENTER, END }

@export var text := "":
	set(v): text = v; _dirty = true; queue_redraw()
@export var font: Font:
	set(v): font = v; _dirty = true; queue_redraw()
@export var font_size := 48.0:
	set(v): font_size = v; _dirty = true; queue_redraw()
@export var color := Color.WHITE:
	set(v): color = v; queue_redraw()
## CSS letter-spacing in em, added after every character.
@export var tracking := 0.0:
	set(v): tracking = v; _dirty = true; queue_redraw()
## The path, in this node's space.
@export var points := PackedVector2Array():
	set(v): points = v; _path_dirty = true; queue_redraw()
## Join the last point back to the first; arc lengths wrap.
@export var closed := false:
	set(v): closed = v; _path_dirty = true; queue_redraw()
## Where the text starts along the path, in px (animate it to scroll; any
## value works, it wraps on closed or repeating paths).
@export var offset := 0.0:
	set(v): offset = v; queue_redraw()
## Where the text sits relative to `offset` when not repeating.
@export var align := Align.START:
	set(v): align = v; queue_redraw()
## Tile the text along the whole path, `gap` px apart.
@export var repeat := false:
	set(v): repeat = v; queue_redraw()
## On a closed path, stretch the gap so a whole number of copies fills the
## loop (no copy cut off at the seam).
@export var fit_loop := true:
	set(v): fit_loop = v; queue_redraw()
@export var gap := 0.0:
	set(v): gap = v; queue_redraw()
## Baseline position across the path, in em of font_size: 0.35 centres capitals
## on the path; 0 puts the baseline on it.
@export var baseline := 0.35:
	set(v): baseline = v; queue_redraw()
## Extra shift across the path in px (positive = to the right of travel).
@export var shift := 0.0:
	set(v): shift = v; queue_redraw()
## Keep glyphs upright instead of turning them with the path.
@export var upright := false:
	set(v): upright = v; queue_redraw()
## Flip glyphs 180° (text running right to left along a path still reads).
@export var flip := false:
	set(v): flip = v; queue_redraw()
## Only glyphs whose centre lies between these arc lengths are drawn (px from
## the path's start; `show_to` < 0 means the path's end). A tape drawn on
## progressively shows its text with it.
@export var show_from := 0.0:
	set(v): show_from = v; queue_redraw()
@export var show_to := -1.0:
	set(v): show_to = v; queue_redraw()
## Fade glyphs within this many px of the show window's ends.
@export var edge_fade := 0.0:
	set(v): edge_fade = v; queue_redraw()

## (i: int, s: float) -> Dictionary of overrides, evaluated at draw time.
var glyph_fn: Callable:
	set(v): glyph_fn = v; queue_redraw()

var _dirty := true
var _path_dirty := true
var _glyphs: Array = []          # {font_rid, size, index, x, adv, char_i, k}
var _width := 0.0
var _lengths := PackedFloat32Array()
var _total := 0.0
var _path := MotionPath.new()


func _frame(_f: float) -> void:
	if glyph_fn.is_valid():
		queue_redraw()


## Width of one copy of the text (px, tracking included).
func get_text_width() -> float:
	_layout()
	return _width


## Length of the path in px.
func path_length() -> float:
	_update_path()
	return _total


## The point on the path at arc length s (px), and its unit tangent.
func point_at(s: float) -> Vector2:
	_update_path()
	return _path.point_at(s)


func tangent_at(s: float, window := 8.0) -> Vector2:
	_update_path()
	return _path.tangent_at(s, window)


## The path as a measured MotionPath (closed paths wrap, open ones run on past their ends).
func measured() -> MotionPath:
	_update_path()
	return _path


# ---------------------------------------------------------------- path maths
# The arc-length model is MotionPath's (single-precision sums, run on past the
# ends); these statics are kept for older callers.

## Cumulative arc lengths of a polyline (closed adds the closing segment).
## Deprecated: use MotionPath.cumulative(pts, is_closed, true).
static func path_lengths(pts: PackedVector2Array, is_closed := false) -> PackedFloat32Array:
	return MotionPath.cumulative(pts, is_closed, true)


## Point at arc length s. Open paths extend straight past their ends; closed
## paths wrap. Deprecated: use MotionPath.point_on.
static func path_point(pts: PackedVector2Array, lengths: PackedFloat32Array, is_closed: bool, s: float) -> Vector2:
	return MotionPath.point_on(pts, lengths, is_closed, s)


## Unit tangent at s, as the chord over ±window px (smooths polyline corners).
## Deprecated: use MotionPath.tangent_on.
static func path_tangent(pts: PackedVector2Array, lengths: PackedFloat32Array, is_closed: bool, s: float, window := 8.0) -> Vector2:
	return MotionPath.tangent_on(pts, lengths, is_closed, s, window)


func _update_path() -> void:
	if not _path_dirty:
		return
	_path_dirty = false
	_path = MotionPath.new(points, closed, true)
	_path.extend = true
	_lengths = _path.lengths
	_total = _path.length


func _layout() -> void:
	if not _dirty:
		return
	_dirty = false
	_glyphs.clear()
	_width = 0.0
	if not font or text.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var isize := maxi(1, int(round(font_size)))
	var k := font_size / float(isize)
	var track := tracking * font_size
	var tl := TextLine.new()
	tl.add_string(text, font, isize)
	var x := 0.0
	for g in ts.shaped_text_get_glyphs(tl.get_rid()):
		var adv: float = float(g.advance) * k
		_glyphs.append({font_rid = g.font_rid, size = isize, index = g.index, x = x, adv = adv, char_i = int(g.start), k = k})
		x += adv
		if adv != 0.0:
			x += track
	_width = x


func _draw() -> void:
	_layout()
	_update_path()
	if _glyphs.is_empty() or points.size() < 2 or _total <= 0.0:
		return
	var ts := TextServerManager.get_primary_interface()
	var ci := get_canvas_item()
	var period := _width + gap
	if closed and repeat and fit_loop and period > 0.0:
		period = _total / maxf(1.0, floorf(_total / period))
	var lo := show_from
	var hi := show_to if show_to >= 0.0 else _total
	var base := offset
	if not repeat:
		match align:
			Align.CENTER:
				base -= _width * 0.5
			Align.END:
				base -= _width
	var copies := [0]
	if repeat and period > 0.0:
		copies = []
		if closed:
			var c := ceili(_total / period)
			for r in c:
				copies.append(r)
		else:
			var r0 := floori((lo - base) / period) - 1
			var r1 := ceili((hi - base) / period) + 1
			for r in range(r0, r1 + 1):
				copies.append(r)
	var base_y := baseline * font_size
	for r in copies:
		for g in _glyphs:
			var adv: float = g.adv
			if adv <= 0.0 and g.index == 0:
				continue
			var local: float = float(r) * period + float(g.x)
			# on a loop the last copy stops at the seam instead of overlapping the first
			if closed and repeat and local + adv > _total + 0.01:
				continue
			var s: float = base + local + adv * 0.5
			if closed:
				s = fposmod(s, _total)
			if s < lo or s > hi:
				continue
			var o: Dictionary = {}
			if glyph_fn.is_valid():
				var res: Variant = glyph_fn.call(int(g.char_i), s)
				if res is Dictionary:
					o = res
			if o.get("hide", false):
				continue
			var col: Color = o.get("color", color)
			col.a *= float(o.get("o", 1.0))
			if edge_fade > 0.0:
				col.a *= clampf(minf(s - lo, hi - s) / edge_fade, 0.0, 1.0)
			if col.a <= 0.0:
				continue
			s += float(o.get("tx", 0.0))
			var t := _path.tangent_at(s, maxf(2.0, adv * 0.5))
			var nrm := Vector2(-t.y, t.x)
			var p := _path.point_at(s) + nrm * (shift + float(o.get("ty", 0.0)))
			var ang := 0.0 if upright else t.angle()
			if flip:
				ang += PI
			ang += deg_to_rad(float(o.get("rot", 0.0)))
			var sc := float(o.get("s", 1.0)) * float(g.k)
			var xf := Transform2D(ang, p) * Transform2D(Vector2(sc, 0), Vector2(0, sc), Vector2.ZERO)
			draw_set_transform_matrix(xf)
			ts.font_draw_glyph(g.font_rid, ci, g.size, Vector2(-adv * 0.5 / float(g.k), base_y / float(g.k)), g.index, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
