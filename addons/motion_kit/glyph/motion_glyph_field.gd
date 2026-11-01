# SPDX-License-Identifier: Apache-2.0
## A field of cycling glyphs drawn in one quad: katakana, digits, arrows,
## blocks, whatever `charset` holds. Each cell changes glyph at its own seeded
## rate; its brightness and colour come from a MASK: anything you put under
## `mask_content` (a MotionSvg logo, a MotionText line, shapes) is rendered
## offscreen and read back per cell, so logos and type appear as dense, bright
## glyphs inside the field. Waves (a scan band, a ring), rain and a gravity
## fall move through it, and `solidify` turns cells from glyphs into the solid
## mask, so a logo can condense out of the field into its real vector form.
##
## Frame-pure: every animated value is a uniform set from `_frame(f)`, and
## glyph steps are floor(f * rate), so scrubbing, seeking and reverse play are
## exact. Cost: one quad (a hash, five mask taps and one atlas tap per pixel),
## one mask viewport the size of the field, and a glyph atlas drawn once.
##
##   var field := MotionGlyphField.new()
##   field.font = MotionFonts.font("res://fonts/noto-jp.woff2")
##   field.charset = "アイウエオカキク0123456789■□▲●"
##   add_child(field)
##   var logo := MotionSvg.new(); logo.data = load("res://logo.svg")
##   field.mask_content.add_child(logo)        # lights the glyphs where the logo is
##   # in _frame(f): field.reveal = MK.prog(f, 30, 20); field.solidify = ...
@tool
@icon("res://addons/motion_kit/icons/field.svg")
class_name MotionGlyphField
extends Node2D

const SHADER := preload("res://addons/motion_kit/glyph/motion_glyph_field.gdshader")

## Field size in pixels (the composition size, usually).
@export var size := Vector2(1920, 1080):
	set(v): size = v; _resize()
## Cell size in pixels. The atlas is drawn at this size, so glyphs stay crisp.
@export var cell := Vector2(18, 18):
	set(v): cell = v; _atlas_dirty = true
@export var font: Font:
	set(v): font = v; _atlas_dirty = true
## Every glyph the field can show, in atlas order.
@export_multiline var charset := "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン0123456789":
	set(v): charset = v; _atlas_dirty = true
## Glyph size inside its cell (the rest is gap).
@export_range(0.3, 1.2) var glyph_scale := 0.9
## Font size as a share of the cell height (the atlas raster).
@export_range(0.3, 1.2) var font_scale := 0.86
@export var seed := 1.0

@export_group("Glyph sets")
## Glyphs the dim field picks from: (start, count) in `charset`; count 0 = all.
@export var dim_range := Vector2i(0, 0)
## Glyphs lit (masked) cells pick from.
@export var lit_range := Vector2i(0, 0)
## Glyph changes per frame, per cell, between these.
@export var cycle_min := 0.03
@export var cycle_max := 0.3
## Lit cells cycle this much faster (or slower).
@export var lit_cycle := 1.0

@export_group("Mask")
## Coverage (0..1 of a cell) at which a cell lights, and the soft range around it.
@export var threshold := 0.35
@export var softness := 0.15
## Share of lit cells shown, 0..1.
@export_range(0.0, 1.0) var reveal := 1.0
## 0: `reveal` dissolves cells in a seeded order; 1: it sweeps across along `reveal_angle`.
@export_range(0.0, 1.0) var reveal_sweep := 0.0
@export var reveal_angle := 90.0
@export var lit_color := Color.WHITE
## 0: lit glyphs take the mask's own colour; 1: lit_color.
@export_range(0.0, 1.0) var tint := 0.0
@export_range(0.0, 1.0) var lit_level := 1.0
## 0..1: lit cells get a filled block in their colour behind the glyph.
@export_range(0.0, 1.0) var lit_fill := 0.0
## 0..1: glyphs on filled cells take ink_color, cut out of the block like a stencil.
@export_range(0.0, 1.0) var lit_invert := 0.0
@export var ink_color := Color.BLACK
## Render the mask at this share of `size` (lower is cheaper; solidify gets softer).
@export_range(0.25, 2.0, 0.25) var mask_scale := 1.0:
	set(v): mask_scale = v; _resize()

@export_group("Dim field")
@export var base_color := Color("#2dff6a")
## A second base colour, taken by cells left of `base_front` (a moving colour front).
@export var base_color_b := Color("#ff2d7a")
@export var base_front := -100000.0
@export var base_front_jitter := 160.0
@export_range(0.0, 1.0) var base_density := 0.4
@export_range(0.0, 1.0) var base_level := 0.25
@export_range(0.0, 1.0) var base_flicker := 0.0

@export_group("Motion")
## Whole-grid offset in pixels; the mask stays where it is.
@export var scroll := Vector2.ZERO
## Rain: px per frame downwards, columns at their own speeds. Lit glyphs pass
## through the mask (it stays put).
@export var rain := 0.0
@export var rain_var := 0.6
## Fall: frames since columns began to drop (< 0 = off). Glyphs carry their
## mask brightness with them, so a lit logo falls apart column by column.
@export var fall_t := -1.0
@export var fall_g := 0.6
@export var fall_spread := 30.0

@export_group("Highlights")
@export var hot_color := Color.WHITE
## A horizontal band at y that lights the glyphs it passes.
@export var scan_y := -100000.0
@export var scan_w := 40.0
@export var scan_gain := 1.0
## A ring of radius ring_r (< 0 = off) around ring_c.
@export var ring_c := Vector2(960, 540)
@export var ring_r := -1.0
@export var ring_w := 90.0
@export var ring_gain := 1.0

@export_group("Solidify")
## 0..1: cells turn from glyphs into the solid mask.
@export_range(0.0, 1.0) var solidify := 0.0
## How ragged the solidify front is.
@export_range(0.0, 1.0) var solidify_noise := 0.5
## 0: random order; 1: outwards from ring_c.
@export_range(0.0, 1.0) var solidify_sweep := 0.0

@export_group("")
@export_range(0.0, 1.0) var level := 1.0

## Where to add the nodes that light the field.
var mask_content: Node2D
## The current frame (set by _frame; drives glyph cycling and rain).
var frame := 0.0

var _mask_vp: SubViewport
var _atlas_vp: SubViewport
var _atlas_draw: _AtlasDraw
var _atlas_cols := 16
var _atlas_dirty := true
var _atlas_frames := 0
var _mat: ShaderMaterial


## Draws every glyph of the charset into an atlas grid, white on transparent.
class _AtlasDraw extends Node2D:
	var font: Font
	var chars: PackedStringArray
	var cols := 16
	var cell := Vector2i(18, 18)
	var font_size := 16

	func _draw() -> void:
		if font == null:
			return
		var asc := font.get_ascent(font_size)
		var desc := font.get_descent(font_size)
		for i in chars.size():
			var ch := chars[i]
			var o := Vector2((i % cols) * cell.x, floori(i / float(cols)) * cell.y)
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var base := o + Vector2((cell.x - w) * 0.5, (cell.y - (asc + desc)) * 0.5 + asc)
			draw_string(font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _init() -> void:
	mask_content = MotionOffscreen.holder("Mask")
	_mask_vp = MotionOffscreen.make(self, mask_content)
	_atlas_draw = _AtlasDraw.new()
	_atlas_vp = MotionOffscreen.make(self, _atlas_draw)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_resize()


func _ready() -> void:
	_resize()
	_sync()


func _resize() -> void:
	if not _mask_vp:
		return
	MotionOffscreen.fit(_mask_vp, size, mask_scale)
	queue_redraw()


func _build_atlas() -> void:
	_atlas_dirty = false
	var chars := PackedStringArray()
	for i in charset.length():
		var ch := charset[i]
		if ch != "\n":
			chars.append(ch)
	var c := Vector2i(ceili(cell.x), ceili(cell.y))
	_atlas_cols = maxi(1, mini(chars.size(), floori(4096.0 / c.x)))
	var rows := ceili(chars.size() / float(_atlas_cols))
	_atlas_vp.size = Vector2i(_atlas_cols * c.x, maxi(1, rows) * c.y)
	_atlas_draw.font = font
	_atlas_draw.chars = chars
	_atlas_draw.cols = _atlas_cols
	_atlas_draw.cell = c
	_atlas_draw.font_size = maxi(4, roundi(c.y * font_scale))
	_atlas_draw.queue_redraw()
	_atlas_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_atlas_frames = 0
	_mat.set_shader_parameter("atlas", _atlas_vp.get_texture())
	_mat.set_shader_parameter("atlas_cols", _atlas_cols)
	_mat.set_shader_parameter("atlas_cell_uv", Vector2(1.0 / _atlas_cols, 1.0 / maxi(1, rows)))
	_mat.set_shader_parameter("glyph_total", maxi(1, chars.size()))


## Index of a character in `charset` (for glyph ranges), or -1.
func glyph_index(ch: String) -> int:
	return charset.replace("\n", "").find(ch)


func _frame(f: float) -> void:
	frame = f
	_sync()


func _process(_d: float) -> void:
	# The atlas is static: let it render a few times, then stop updating it.
	if _atlas_vp and _atlas_vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS and not _atlas_dirty:
		_atlas_frames += 1
		if _atlas_frames > 4 and not Engine.is_editor_hint():
			_atlas_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# A hidden field needn't render its mask.
	if _mask_vp:
		MotionOffscreen.gate(_mask_vp, is_visible_in_tree())


func _sync() -> void:
	if not _mat:
		return
	if _atlas_dirty:
		_build_atlas()
	var m := _mat
	m.set_shader_parameter("field_size", size)
	m.set_shader_parameter("cell", cell)
	m.set_shader_parameter("glyph_scale", glyph_scale)
	m.set_shader_parameter("dim_range", dim_range)
	m.set_shader_parameter("lit_range", lit_range)
	m.set_shader_parameter("frame", frame)
	m.set_shader_parameter("cycle_min", cycle_min)
	m.set_shader_parameter("cycle_max", cycle_max)
	m.set_shader_parameter("lit_cycle", lit_cycle)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("mask", _mask_vp.get_texture())
	m.set_shader_parameter("has_mask", mask_content.get_child_count() > 0)
	m.set_shader_parameter("threshold", threshold)
	m.set_shader_parameter("softness", softness)
	m.set_shader_parameter("reveal", reveal)
	m.set_shader_parameter("reveal_sweep", reveal_sweep)
	m.set_shader_parameter("reveal_angle", reveal_angle)
	m.set_shader_parameter("lit_color", lit_color)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("lit_level", lit_level)
	m.set_shader_parameter("lit_fill", lit_fill)
	m.set_shader_parameter("lit_invert", lit_invert)
	m.set_shader_parameter("ink_color", ink_color)
	m.set_shader_parameter("base_color", base_color)
	m.set_shader_parameter("base_color_b", base_color_b)
	m.set_shader_parameter("base_front", base_front)
	m.set_shader_parameter("base_front_jitter", base_front_jitter)
	m.set_shader_parameter("base_density", base_density)
	m.set_shader_parameter("base_level", base_level)
	m.set_shader_parameter("base_flicker", base_flicker)
	m.set_shader_parameter("scroll", scroll)
	m.set_shader_parameter("rain", rain)
	m.set_shader_parameter("rain_var", rain_var)
	m.set_shader_parameter("fall_t", fall_t)
	m.set_shader_parameter("fall_g", fall_g)
	m.set_shader_parameter("fall_spread", fall_spread)
	m.set_shader_parameter("hot_color", hot_color)
	m.set_shader_parameter("scan_y", scan_y)
	m.set_shader_parameter("scan_w", scan_w)
	m.set_shader_parameter("scan_gain", scan_gain)
	m.set_shader_parameter("ring_c", ring_c)
	m.set_shader_parameter("ring_r", ring_r)
	m.set_shader_parameter("ring_w", ring_w)
	m.set_shader_parameter("ring_gain", ring_gain)
	m.set_shader_parameter("solidify", solidify)
	m.set_shader_parameter("solidify_noise", solidify_noise)
	m.set_shader_parameter("solidify_sweep", solidify_sweep)
	m.set_shader_parameter("level", level)
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), Color.WHITE)
