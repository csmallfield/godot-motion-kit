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
## CSS -webkit-text-stroke: a stroke of this many pixels centred on each glyph's
## outline, painted over the fill (so half of it eats into the letter). A
## transparent `color` gives outline-only type. Widths snap to half pixels, and
## each new width rasterizes new outline glyphs: animate scale, not the width.
@export var stroke_width := 0.0:
	set(v): stroke_width = v; queue_redraw()
@export var stroke_color := Color.BLACK:
	set(v): stroke_color = v; queue_redraw()
## CSS writing-mode: vertical-rl. Glyphs stand upright in columns that run top
## to bottom, right to left, using the font's vertical forms (the long-vowel
## mark turns, small kana shift). Every glyph stands upright, Latin included,
## as with text-orientation: upright (CSS's default, mixed, turns Latin sideways). `box_width` is then the available column
## height: text wraps between characters, never starting a column with
## punctuation or a small kana (Japanese kinsoku), as browsers do.
## The origin stays the top-left of the whole block; tracking runs down.
@export var vertical := false:
	set(v): vertical = v; _dirty = true; queue_redraw()

## Called from _frame as glyph_fn.call(i, f) -> Dictionary (or null) per character.
var glyph_fn: Callable

var _dirty := true
var _glyphs: Array = []    # {font_rid, size, index, pos: Vector2, adv: float, char_i: int}
var _chars := 0
var _width := 0.0
var _height := 0.0
var _baseline := 0.0
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


## A MotionText with `font`, `size`, colour, string and `tracking` (em),
## placed at `pos` and added to `parent` (when given). The one-line text
## factory for pieces: `MotionText.make(self, font, 48, INK, "HELLO", 0.1)`.
static func make(parent: Node, font_v: Font, size: float, col: Color, s: String, tracking_em := 0.0,
		pos := Vector2.ZERO) -> MotionText:
	var t := MotionText.new()
	t.font = font_v
	t.font_size = size
	t.color = col
	t.tracking = tracking_em
	t.text = s
	t.position = pos
	if parent:
		parent.add_child(t)
	return t


## Laid-out size in pixels: widest line including tracking, total line-box height.
func get_text_size() -> Vector2:
	_layout()
	return Vector2(_width, _height)


## Distance from the top of the box to the first line's baseline (for CSS
## align-items: baseline). For vertical text, half the column thickness.
func get_baseline() -> float:
	_layout()
	return _baseline


# FreeType rounds a size's ascent and descent up to whole pixels, so
# ceil(t * s) / s >= t at every size s; the smallest ratio over several sizes is
# the true metric, exact when s is the font's units-per-em (1000 or 2048 for
# nearly every font). Godot measures sizes above 2048 at 2048 and scales.
const _METRIC_SIZES := [1000, 2048, 1024, 1536, 1800, 2000, 1200, 1250]

## Ascent and descent of one font face at `size` px, as a browser computes
## them: NOT including the face's fallbacks (Godot's Font.get_ascent() takes
## the maximum over the fallback chain; browsers size a line only from the
## faces its glyphs actually use), and each rounded to the nearest pixel
## (Chromium rounds; FreeType's size metrics round up, which would put every
## baseline up to a pixel low). The unrounded values are recovered from
## several large sizes (see _METRIC_SIZES), cached per face, so a descent of
## 6.498 px rounds down to 6 as it does in the browser. MSDF fonts are the
## exception: Godot measures them at their msdf_size whatever the size asked,
## so their metrics can be a pixel out at large sizes.
static var _unit_metrics := {}

static func _face_metrics(ts: TextServer, rid: RID, size: float) -> Vector2:
	if not _unit_metrics.has(rid):
		var a := INF
		var d := INF
		for s in _METRIC_SIZES:
			a = minf(a, ts.font_get_ascent(rid, s) / float(s))
			d = minf(d, ts.font_get_descent(rid, s) / float(s))
		_unit_metrics[rid] = Vector2(a, d)
	var m: Vector2 = _unit_metrics[rid] * size
	return Vector2(roundf(m.x), roundf(m.y))


func _primary_metrics(ts: TextServer, size: float) -> Vector2:
	var rids := font.get_rids()
	if rids.is_empty():
		return Vector2(roundf(font.get_ascent(int(round(size)))), roundf(font.get_descent(int(round(size)))))
	return _face_metrics(ts, rids[0], size)


func _layout() -> void:
	if not _dirty:
		return
	_dirty = false
	_glyphs.clear()
	_chars = 0
	_width = 0.0
	_height = 0.0
	_baseline = 0.0
	if not font or text.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var isize := int(round(font_size))
	var k := font_size / float(isize)          # fractional sizes scale the integer-size glyphs
	var prim := _primary_metrics(ts, font_size)
	if vertical:
		_layout_vertical(ts, isize, k, prim)
		return
	var track := tracking * font_size
	var src := text.to_upper() if uppercase else text
	var lines := src.split("\n")
	var y := 0.0
	var char_base := 0
	for line in lines:
		var tl := TextLine.new()
		tl.add_string(line, font, isize)
		var rid := tl.get_rid()
		var glyphs: Array = ts.shaped_text_get_glyphs(rid)
		var x := 0.0
		var recs: Array = []
		# "normal" line height: the primary face is the strut; faces used by
		# fallback glyphs can only make the line taller.
		var asc := prim.x
		var desc := prim.y
		var seen := {}
		for g in glyphs:
			var adv: float = float(g.advance) * k
			var off: Vector2 = (g.get("offset", Vector2.ZERO) as Vector2) * k
			var ci: int = char_base + int(g.start)
			recs.append({font_rid = g.font_rid, size = isize, index = g.index, pos = Vector2(x, 0) + off, adv = adv, char_i = ci, k = k})
			if line_height <= 0.0 and not seen.has(g.font_rid):
				seen[g.font_rid] = true
				var m := _face_metrics(ts, g.font_rid, font_size)
				asc = maxf(asc, m.x)
				desc = maxf(desc, m.y)
			x += adv
			# CSS letter-spacing goes after each character.
			if adv != 0.0:
				x += track
		var box := asc + desc
		var baseline := y + asc
		if line_height > 0.0:
			box = font_size * line_height
			baseline = y + (box - (prim.x + prim.y)) * 0.5 + prim.x   # half-leading on the primary face
		if char_base == 0:
			_baseline = baseline
		var line_w := x
		var ox := 0.0
		var avail := box_width
		match align:
			HORIZONTAL_ALIGNMENT_CENTER:
				ox = (avail - line_w) * 0.5 if avail > 0.0 else -line_w * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:
				ox = (avail - line_w) if avail > 0.0 else -line_w
		for r in recs:
			r.pos += Vector2(ox, baseline)
			r.line_top = y
			r.line_box = box
			_glyphs.append(r)
		_width = maxf(_width, line_w)
		y += box
		char_base += line.length() + 1
	_chars = maxi(0, char_base - 1)
	_height = y


# Characters that may not start a line (and so pull the one before them
# down with them), and ones that may not end a line, after JIS X 4051.
const _NO_START := "、。，．・：；？！ー－〜ゝゞヽヾ々ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ）」』】〕〉》｝］"
const _NO_END := "（「『【〔〈《｛［"


func _layout_vertical(ts: TextServer, isize: int, k: float, prim: Vector2) -> void:
	var track := tracking * font_size
	var src := text.to_upper() if uppercase else text
	# Column thickness: the horizontal line box of the faces actually used (the
	# primary face as the strut), with the glyphs centred on it (the ideographic
	# central baseline).
	var thick := prim.x + prim.y
	var seen := {}
	var columns: Array = []        # each: Array of glyph records
	var char_base := 0
	for para in src.split("\n"):
		var rid := ts.create_shaped_text(TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		ts.shaped_text_add_string(rid, para, font.get_rids(), isize)
		ts.shaped_text_shape(rid)
		var recs: Array = []
		for g in ts.shaped_text_get_glyphs(rid):
			if not seen.has(g.font_rid):
				seen[g.font_rid] = true
				var m := _face_metrics(ts, g.font_rid, font_size)
				thick = maxf(thick, m.x + m.y)
			var adv: float = float(g.advance) * k
			recs.append({font_rid = g.font_rid, size = isize, index = g.index, off = (g.get("offset", Vector2.ZERO) as Vector2) * k,
				adv = adv, char_i = char_base + int(g.start), ch = para.substr(int(g.start), 1), k = k})
		ts.free_rid(rid)
		# Greedy columns with kinsoku.
		var col: Array = []
		var used := 0.0
		for r in recs:
			var step: float = r.adv + (track if r.adv != 0.0 else 0.0)
			if box_width > 0.0 and not col.is_empty() and used + step > box_width + 0.01:
				# Don't start the next column with a forbidden character, or end this
				# one with an opening bracket: find the latest legal break before here.
				# With none (a run of ーーー), there is no break opportunity and the
				# column overflows, as in a browser.
				var cut := col.size()
				while cut > 0 and (_NO_START.contains((col[cut] if cut < col.size() else r).ch) or _NO_END.contains(col[cut - 1].ch)):
					cut -= 1
				if cut == 0:
					col.append(r)
					used += step
					continue
				var nxt: Array = col.slice(cut)
				nxt.append(r)
				col = col.slice(0, cut)
				columns.append(col)
				col = []
				used = 0.0
				for c in nxt:
					col.append(c)
					used += c.adv + (track if c.adv != 0.0 else 0.0)
				continue
			col.append(r)
			used += step
		columns.append(col)
		char_base += para.length() + 1
	if line_height > 0.0:
		thick = font_size * line_height
	_chars = maxi(0, char_base - 1)
	_baseline = thick * 0.5
	_width = thick * columns.size()
	_height = 0.0
	for ci in columns.size():
		var cx := _width - thick * (ci + 0.5)
		var y := 0.0
		for r in columns[ci]:
			r.pos = Vector2(cx, y) + r.off
			r.pivot = Vector2(cx, y + r.adv * 0.5)
			r.line_top = 0.0
			r.line_box = thick
			_glyphs.append(r)
			y += r.adv + (track if r.adv != 0.0 else 0.0)
		_height = maxf(_height, y)


func _draw() -> void:
	_layout()
	if _glyphs.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var ci := get_canvas_item()
	var count := visible_chars if visible_chars >= 0 else 1 << 30
	var stroked := stroke_width > 0.0
	# Fills first, then strokes over all of them, as Chromium paints
	# -webkit-text-stroke: a glyph's fill never covers its neighbour's stroke.
	var strokes := []
	for g in _glyphs:
		var i: int = g.char_i
		if i >= count:
			continue
		var o: Dictionary = _overrides.get(i, {})
		if o.get("hide", false):
			continue
		var col: Color = o.get("color", color)
		col.a *= float(o.get("o", 1.0))
		var sc := Color(stroke_color, stroke_color.a * float(o.get("o", 1.0)))
		var stroke_on := stroked and sc.a > 0.0
		if col.a <= 0.0 and not stroke_on:
			continue
		var s := float(o.get("s", 1.0))
		var sx := float(o.get("sx", 1.0)) * s
		var sy := float(o.get("sy", 1.0)) * s
		if absf(sx) < 1e-6 or absf(sy) < 1e-6:
			continue
		var pos: Vector2 = g.pos
		var pivot: Vector2 = g.get("pivot", Vector2(pos.x + float(g.adv) * 0.5, float(g.line_top) + float(g.line_box) * 0.5))
		var xf := Transform2D(0.0, Vector2(float(o.get("tx", 0.0)), float(o.get("ty", 0.0))) + pivot) \
			* Transform2D(deg_to_rad(float(o.get("rot", 0.0))), Vector2.ZERO) \
			* Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO) \
			* Transform2D(0.0, -pivot)
		var k: float = g.k
		if not is_equal_approx(k, 1.0):
			xf = xf * Transform2D(Vector2(k, 0), Vector2(0, k), pos - pos * k)
		if col.a > 0.0:
			draw_set_transform_matrix(xf)
			ts.font_draw_glyph(g.font_rid, ci, g.size, pos, g.index, col)
		if stroke_on:
			strokes.append([g, xf, sc])
	for e in strokes:
		var g: Dictionary = e[0]
		draw_set_transform_matrix(e[1])
		# Godot's outline of size n is a stroke n / 2 wide, centred on the contour
		# (whole sizes only, so the width snaps to half pixels).
		ts.font_draw_glyph_outline(g.font_rid, ci, g.size, maxi(1, int(round(stroke_width * 2.0 / float(g.k)))), g.pos, g.index, e[2])
	draw_set_transform_matrix(Transform2D.IDENTITY)
