# SPDX-License-Identifier: Apache-2.0
## A full-frame op-art tiling in one quad: houndstooth (woven as real 2/2 twill),
## checker, pinwheel, dots, chevrons or stripes, whose cells rotate, scale, invert,
## switch colourway, switch motif and open up, each driven by four fields:
##
## - MASK: anything added under `mask_content` (a MotionSvg logo, MotionText) is
##   rendered offscreen; cells inside it can be transformed, so a logo reads as a
##   region of the pattern before it appears as a vector. With `mask_pixel` the
##   region's edge is per pixel (crisp letters made of tiles), else per cell.
## - HALO: the band just outside the mask, `halo_r` px wide (tiles twisting
##   around a logo).
## - RING: a band, disc or outside of a circle (`ring_mode`), with per-cell stagger
##   (`jitter`): shockwaves, irises, radial shrink-outs.
## - SWEEP: a straight front at `sweep` px along `sweep_angle`: wipes of colourway
##   or motif, cell by cell.
##
## Every channel is `base + by · (mask, halo, ring, sweep) + and · (ring×mask,
## sweep×mask, ring×halo, sweep×halo)` (the `and` terms gate a front by the mask
## or the halo: "cells inside the logo vanish as the ring passes"):
##   rotate (radians), scale, invert (0..1), alt (0..1, the second colourway),
##   clear (0..1, makes the gaps of shrunk cells transparent so what's under the
##   tiling shows through) and motif (> 0.5 switches the cell to `motif_b`).
## A Vasarely `bulge` and a radial `ripple` warp the fabric.
##
## Frame-pure: the shader reads only uniforms that the piece sets from `f`, and
## per-cell randomness is a seeded hash of the cell. Cost: one quad, two cell
## evaluations per pixel (with `mask_pixel`) and nine mask taps; the mask
## viewport stops rendering while the tiling is hidden or `has_mask` is false.
##
##   var t := MotionTiling.new()
##   t.motif = MotionTiling.Motif.HOUNDSTOOTH
##   t.mask_content.add_child(logo)                   # a MotionSvg
##   t.rot_by = MotionTiling.by(PI / 4.0)            # tiles inside the logo turn 45°
##   t.inv_by = MotionTiling.by(1.0)                 # and invert: the logo reads as fabric
##   t.scale_by = MotionTiling.by(0.0, 0.0, -1.0)    # a ring shrinks cells to nothing
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionTiling
extends Node2D

const SHADER := preload("res://addons/motion_kit/tiling/motion_tiling.gdshader")

enum Motif { HOUNDSTOOTH, CHECKER, PINWHEEL, DOTS, CHEVRON, STRIPES }
enum RingMode { BAND, DISC, OUTSIDE }

@export var size := Vector2(1920, 1080):
	set(v): size = v; _resize()
## Tile period in px (a houndstooth tile is 8 threads wide).
@export var cell := 48.0
@export var motif := Motif.HOUNDSTOOTH
@export var motif_b := Motif.CHECKER
## Global rotation in degrees about `origin`.
@export var angle := 0.0
@export var origin := Vector2(960, 540)
@export var scroll := Vector2.ZERO
@export var seed := 1.0

@export_group("Colourways")
@export var ink_a := Color("#0a0a0d")
@export var ink_b := Color("#f2eee6")
@export var alt_a := Color("#e92067")
@export var alt_b := Color("#0a0a0d")
## Shown where cells shrink (cleared by the clear channel).
@export var gap_color := Color("#0a0a0d")
## Each cell switches to the alt colourway at once (crisp op-art fronts) instead of blending.
@export var alt_hard := true
## 0..1: inside the mask the motif takes the mask's own colour.
@export var mask_color := 0.0
## 0..1: inside the mask the ground takes the mask's colour times `mask_ground_shade`
## (light parts of a logo stay light, coloured parts read as a deeper weave of themselves).
@export var mask_ground := 0.0
@export var mask_ground_shade := 0.55

@export_group("Warp")
@export var bulge_c := Vector2(960, 540)
@export var bulge_r := 600.0
## -0.9..0.9: above 0 magnifies like a Vasarely sphere, below 0 pinches.
@export var bulge := 0.0
@export var ripple_c := Vector2(960, 540)
## Radius of the ripple's crest; below 0 = off.
@export var ripple_r := -1.0
@export var ripple_w := 120.0
@export var ripple_amp := 0.0

@export_group("Drivers")
## Mask edge per pixel (crisp shapes made of cells) or per cell (stepped).
@export var mask_pixel := true
## Sample the mask in the warped fabric, so the masked shape bends with it.
@export var mask_warp := false
@export var halo_r := 60.0
## Render the mask at this share of `size` (lower is cheaper; edges get softer).
@export_range(0.25, 1.0, 0.25) var mask_scale := 0.5:
	set(v): mask_scale = v; _resize()
@export var ring_c := Vector2(960, 540)
## Below 0 = off.
@export var ring_r := -1.0
@export var ring_w := 120.0
@export var ring_mode := RingMode.BAND
## Front position in px along `sweep_angle`, measured from the field centre.
@export var sweep := -100000.0
@export var sweep_angle := 0.0
@export var sweep_w := 40.0
## 0..1: per-cell stagger of the ring and sweep fronts.
@export var jitter := 0.0

@export_group("Channels: base + by · drivers + and · gated drivers")
@export var rot_base := 0.0
@export var rot_by := Vector4.ZERO
@export var rot_and := Vector4.ZERO
@export var scale_base := 1.0
@export var scale_by := Vector4.ZERO
@export var scale_and := Vector4.ZERO
@export var inv_base := 0.0
@export var inv_by := Vector4.ZERO
@export var inv_and := Vector4.ZERO
@export var alt_base := 0.0
@export var alt_by := Vector4.ZERO
@export var alt_and := Vector4.ZERO
@export var clear_base := 0.0
@export var clear_by := Vector4.ZERO
@export var clear_and := Vector4.ZERO
@export var motif_base := 0.0
@export var motif_by := Vector4.ZERO
@export var motif_and := Vector4.ZERO

@export var level := 1.0

## Anything added here is rendered offscreen and drives the mask and halo fields.
var mask_content: Node2D
## The current frame (set by _frame).
var frame := 0.0

var _mask_vp: SubViewport
var _mat: ShaderMaterial


## Driver weights as a Vector4 (mask, halo, ring, sweep), for the *_by channels.
static func by(mask := 0.0, halo := 0.0, ring := 0.0, sweep_v := 0.0) -> Vector4:
	return Vector4(mask, halo, ring, sweep_v)


## Gated driver weights (ring×mask, sweep×mask, ring×halo, sweep×halo), for the *_and channels.
static func gated(ring_mask := 0.0, sweep_mask := 0.0, ring_halo := 0.0, sweep_halo := 0.0) -> Vector4:
	return Vector4(ring_mask, sweep_mask, ring_halo, sweep_halo)


## Reset every channel to its neutral value (tiles untouched).
func reset_channels() -> void:
	rot_base = 0.0; rot_by = Vector4.ZERO; rot_and = Vector4.ZERO
	scale_base = 1.0; scale_by = Vector4.ZERO; scale_and = Vector4.ZERO
	inv_base = 0.0; inv_by = Vector4.ZERO; inv_and = Vector4.ZERO
	alt_base = 0.0; alt_by = Vector4.ZERO; alt_and = Vector4.ZERO
	clear_base = 0.0; clear_by = Vector4.ZERO; clear_and = Vector4.ZERO
	motif_base = 0.0; motif_by = Vector4.ZERO; motif_and = Vector4.ZERO


func _init() -> void:
	_mask_vp = SubViewport.new()
	_mask_vp.transparent_bg = true
	_mask_vp.disable_3d = true
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mask_content = Node2D.new()
	mask_content.name = "Mask"
	_mask_vp.add_child(mask_content)
	add_child(_mask_vp, false, Node.INTERNAL_MODE_FRONT)
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
	_mask_vp.size = Vector2i(maxi(1, roundi(size.x * mask_scale)), maxi(1, roundi(size.y * mask_scale)))
	_mask_vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(mask_scale, mask_scale))
	queue_redraw()


func has_mask() -> bool:
	return mask_content != null and mask_content.get_child_count() > 0 and mask_content.visible


func _frame(f: float) -> void:
	frame = f
	_sync()


func _process(_d: float) -> void:
	# The mask only renders while it can be seen.
	if _mask_vp:
		var want := SubViewport.UPDATE_ALWAYS if (is_visible_in_tree() and has_mask()) else SubViewport.UPDATE_DISABLED
		if _mask_vp.render_target_update_mode != want:
			_mask_vp.render_target_update_mode = want
	_sync()


func _sync() -> void:
	if not _mat:
		return
	var m := _mat
	m.set_shader_parameter("field_size", size)
	m.set_shader_parameter("cell", maxf(cell, 1.0))
	m.set_shader_parameter("angle", deg_to_rad(angle))
	m.set_shader_parameter("origin", origin)
	m.set_shader_parameter("scroll", scroll)
	m.set_shader_parameter("motif", int(motif))
	m.set_shader_parameter("motif_b", int(motif_b))
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("ink_a", ink_a)
	m.set_shader_parameter("ink_b", ink_b)
	m.set_shader_parameter("alt_a", alt_a)
	m.set_shader_parameter("alt_b", alt_b)
	m.set_shader_parameter("gap_color", gap_color)
	m.set_shader_parameter("mask_color", mask_color)
	m.set_shader_parameter("mask_ground", mask_ground)
	m.set_shader_parameter("mask_ground_shade", mask_ground_shade)
	m.set_shader_parameter("bulge_c", bulge_c)
	m.set_shader_parameter("bulge_r", bulge_r)
	m.set_shader_parameter("bulge", clampf(bulge, -0.95, 0.95))
	m.set_shader_parameter("ripple_c", ripple_c)
	m.set_shader_parameter("ripple_r", ripple_r)
	m.set_shader_parameter("ripple_w", ripple_w)
	m.set_shader_parameter("ripple_amp", ripple_amp)
	m.set_shader_parameter("mask", _mask_vp.get_texture())
	m.set_shader_parameter("has_mask", has_mask())
	m.set_shader_parameter("mask_pixel", mask_pixel)
	m.set_shader_parameter("mask_warp", mask_warp)
	m.set_shader_parameter("halo_r", halo_r)
	m.set_shader_parameter("ring_c", ring_c)
	m.set_shader_parameter("ring_r", ring_r)
	m.set_shader_parameter("ring_w", ring_w)
	m.set_shader_parameter("ring_mode", int(ring_mode))
	m.set_shader_parameter("sweep", sweep)
	m.set_shader_parameter("sweep_angle", sweep_angle)
	m.set_shader_parameter("sweep_w", sweep_w)
	m.set_shader_parameter("jitter", jitter)
	m.set_shader_parameter("rot_base", rot_base)
	m.set_shader_parameter("rot_by", rot_by)
	m.set_shader_parameter("rot_and", rot_and)
	m.set_shader_parameter("scale_base", scale_base)
	m.set_shader_parameter("scale_by", scale_by)
	m.set_shader_parameter("scale_and", scale_and)
	m.set_shader_parameter("inv_base", inv_base)
	m.set_shader_parameter("inv_by", inv_by)
	m.set_shader_parameter("inv_and", inv_and)
	m.set_shader_parameter("alt_hard", alt_hard)
	m.set_shader_parameter("alt_base", alt_base)
	m.set_shader_parameter("alt_by", alt_by)
	m.set_shader_parameter("alt_and", alt_and)
	m.set_shader_parameter("clear_base", clear_base)
	m.set_shader_parameter("clear_by", clear_by)
	m.set_shader_parameter("clear_and", clear_and)
	m.set_shader_parameter("motif_base", motif_base)
	m.set_shader_parameter("motif_by", motif_by)
	m.set_shader_parameter("motif_and", motif_and)
	m.set_shader_parameter("level", level)
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), Color.WHITE)
