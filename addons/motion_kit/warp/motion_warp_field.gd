# SPDX-License-Identifier: Apache-2.0
## A procedural colour field and/or a warped content layer, drawn in one quad.
##
## The FIELD is concentric rings, radial rays and horizontal stripes (any mix,
## weighted), optionally posterized into hard 70s bands, coloured by a cosine
## palette or a Gradient LUT that can be cycled (`pal_shift`), with a striped
## sun disc on top. The CONTENT is any CanvasItem subtree added under
## `content`: it renders offscreen and is sampled through its own liquid warp
## (`content_warp`), drip (`content_melt`) and RGB split, so a logo can be
## poured in liquid and set solid by animating those to 0.
##
## Both go through a seeded, analytic two-level domain warp (`warp`, px), an
## optional kaleidoscope (`kaleido` 0..1 blend, `segments`) and an optional
## horizon below which the scene mirrors in rippling water. Everything is a
## uniform set from the properties; `_frame(f)` sets `time`, so the picture is
## a pure function of the frame (scrub, seek and reverse are exact).
##
## Use two nodes to put other things between the field and a warped logo: one
## with `draw_field = true` and no content, one with `draw_field = false`.
@tool
@icon("res://addons/motion_kit/icons/field.svg")
class_name MotionWarpField
extends Node2D

const SHADER := preload("res://addons/motion_kit/warp/motion_warp_field.gdshader")

@export var size := Vector2(1920, 1080):
	set(v): size = v; _resize()
@export var seed := 1.0

@export_group("Field")
@export var draw_field := true
@export var centre := Vector2(960, 700)
## Weights of the three band kinds; mix them for spirals and plaids.
@export var rings := 1.0
@export var rays := 0.0
@export var stripes := 0.0
## Bands per 1000 px for rings and stripes; rays per turn for rays.
@export var freq := 9.0
## Scrolls the bands outward / down, in bands.
@export var phase := 0.0
## Rays twist with radius (turns per 1000 px): spirals.
@export var twist := 0.0
## Posterize into this many hard bands per band unit (0 = smooth).
@export var steps := 0.0
@export var field_level := 1.0
## Show the field only inside this radius about `centre` (px; huge = everywhere).
@export var iris := 1.0e6
@export var iris_soft := 120.0
## A bright ring about `centre` (radius px, < 0 = off): animate it for shockwaves.
@export var ring_r := -1.0
@export var ring_w := 40.0
@export var ring_gain := 1.0
@export var ring_color := Color.WHITE

@export_group("Sun")
## Sun disc radius in px (0 = none). It sits at `centre` and warps with the field.
@export var sun_r := 0.0
@export var sun_color := Color("#ffd23f")
@export var sun_color_b := Color("#ff3d8b")
## Cut lines across the sun's lower half (the 70s sunset sun); scroll them.
@export var sun_slits := 0.0
@export var sun_slit_scroll := 0.0
@export var sun_glow := 0.0

@export_group("Palette")
## Cosine palette a + b cos(2 pi (c t + d)) (iq): default is a full rainbow.
@export var pal_a := Vector3(0.5, 0.5, 0.5)
@export var pal_b := Vector3(0.5, 0.5, 0.5)
@export var pal_c := Vector3(1, 1, 1)
@export var pal_d := Vector3(0.0, 0.33, 0.67)
## Cycles the palette; animate it for colour cycling.
@export var pal_shift := 0.0
## Palette cycles per band.
@export var pal_spread := 1.0
## A gradient used instead of the cosine palette as `lut_mix` goes to 1 (repeats).
@export var gradient: Gradient:
	set(v): gradient = v; _make_lut()
@export_range(0.0, 1.0) var lut_mix := 0.0

@export_group("Content")
## px of liquid displacement, px of downward drip, px of RGB split on the content.
@export var content_warp := 0.0
@export var content_melt := 0.0
@export var content_chroma := 0.0
@export var content_level := 1.0

@export_group("Warp")
## px of domain warp on the field.
@export var warp := 0.0
@export var warp_scale := 420.0
## Noise drift per frame.
@export var warp_speed := 0.01
@export_range(0.0, 1.0) var kaleido := 0.0
@export var segments := 6.0
@export var kaleido_spin := 0.0

@export_group("Horizon")
## Below this y (px) the scene mirrors in rippling water (huge = off).
@export var horizon := 1.0e6
@export var ripple := 6.0
@export var reflect_dim := 0.55
@export var horizon_glow := 0.0
@export var horizon_color := Color("#ffe6b0")

@export_group("Other")
@export var level := 1.0
@export_range(0.25, 2.0, 0.25) var render_scale := 1.0:
	set(v): render_scale = v; _resize()

## Add what the content layer shows here (MotionSvg, MotionText, shapes...).
var content: Node2D

var _vp: SubViewport
var _rect: ColorRect
var _mat: ShaderMaterial
var _time := 0.0
var _lut: GradientTexture1D


func _init() -> void:
	content = MotionOffscreen.holder("Content")
	_vp = MotionOffscreen.make(self, content, SubViewport.UPDATE_DISABLED)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)
	_make_lut()
	_resize()


func _ready() -> void:
	if not Engine.is_editor_hint():
		for c in get_children():
			c.reparent(content, false)
	_resize()
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply()


func _resize() -> void:
	if not _vp:
		return
	MotionOffscreen.fit(_vp, size, render_scale)
	_rect.size = size


func _make_lut() -> void:
	if _lut == null:
		_lut = GradientTexture1D.new()
		_lut.width = 512
	var g := gradient
	if g == null:
		g = Gradient.new()
	_lut.gradient = g
	if _mat:
		_mat.set_shader_parameter("lut", _lut)


func _frame(f: float) -> void:
	_time = f
	_apply()


func _process(_d: float) -> void:
	_apply()


func _has_content() -> bool:
	return content.get_child_count() > 0


func _apply() -> void:
	if not _mat:
		return
	var on := is_visible_in_tree() and _has_content() and content_level > 0.0
	MotionOffscreen.gate(_vp, on)
	var m := _mat
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("time", _time)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("draw_field", draw_field)
	m.set_shader_parameter("centre", centre)
	m.set_shader_parameter("rings", rings)
	m.set_shader_parameter("rays", rays)
	m.set_shader_parameter("stripes", stripes)
	m.set_shader_parameter("freq", freq)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("twist", twist)
	m.set_shader_parameter("steps", steps)
	m.set_shader_parameter("field_level", field_level)
	m.set_shader_parameter("iris", iris)
	m.set_shader_parameter("iris_soft", iris_soft)
	m.set_shader_parameter("ring_r", ring_r)
	m.set_shader_parameter("ring_w", ring_w)
	m.set_shader_parameter("ring_gain", ring_gain)
	m.set_shader_parameter("ring_color", ring_color)
	m.set_shader_parameter("sun_r", sun_r)
	m.set_shader_parameter("sun_color", sun_color)
	m.set_shader_parameter("sun_color_b", sun_color_b)
	m.set_shader_parameter("sun_slits", sun_slits)
	m.set_shader_parameter("sun_slit_scroll", sun_slit_scroll)
	m.set_shader_parameter("sun_glow", sun_glow)
	m.set_shader_parameter("pal_a", pal_a)
	m.set_shader_parameter("pal_b", pal_b)
	m.set_shader_parameter("pal_c", pal_c)
	m.set_shader_parameter("pal_d", pal_d)
	m.set_shader_parameter("pal_shift", pal_shift)
	m.set_shader_parameter("pal_spread", pal_spread)
	m.set_shader_parameter("lut_mix", lut_mix)
	m.set_shader_parameter("draw_content", on)
	m.set_shader_parameter("content_tex", _vp.get_texture())
	m.set_shader_parameter("content_warp", content_warp)
	m.set_shader_parameter("content_melt", content_melt)
	m.set_shader_parameter("content_chroma", content_chroma)
	m.set_shader_parameter("content_level", content_level)
	m.set_shader_parameter("warp", warp)
	m.set_shader_parameter("warp_scale", warp_scale)
	m.set_shader_parameter("warp_speed", warp_speed)
	m.set_shader_parameter("kaleido", kaleido)
	m.set_shader_parameter("segments", segments)
	m.set_shader_parameter("kaleido_spin", kaleido_spin)
	m.set_shader_parameter("horizon", horizon)
	m.set_shader_parameter("ripple", ripple)
	m.set_shader_parameter("reflect_dim", reflect_dim)
	m.set_shader_parameter("horizon_glow", horizon_glow)
	m.set_shader_parameter("horizon_color", horizon_color)
	m.set_shader_parameter("level", level)


## A cosine palette from four Vector3s in one call (see iquilezles.org/articles/palettes).
func set_palette(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	pal_a = a
	pal_b = b
	pal_c = c
	pal_d = d


## A Gradient from evenly spaced colours (hard steps when `hard`), for `gradient`.
static func bands_gradient(colors: Array, hard := true) -> Gradient:
	var g := Gradient.new()
	var n := colors.size()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in n:
		var c: Color = colors[i]
		if hard:
			offs.append(float(i) / n)
			cols.append(c)
		else:
			offs.append(float(i) / maxf(1.0, n - 1.0))
			cols.append(c)
	g.offsets = offs
	g.colors = cols
	if hard:
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g
