# SPDX-License-Identifier: Apache-2.0
## An image as a coarse grid of square cells: the SCF "pixel build". Cells come
## from an SVG (rasterized at 10x, box-averaged to the grid, kept where alpha
## passes a threshold, snapped to a palette) or are set directly.
## `show_fn(i) -> bool` gates cells per frame for build-ins and break-ups.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionPixelGrid
extends Node2D

## Each cell: Vector3i-like Dictionary {x, y, color}
var cells: Array[Dictionary] = []
var cols := 16
var rows := 12
## Rendered width in pixels.
@export var width := 740.0:
	set(v): width = v; queue_redraw()
## Gap between cells in pixels.
@export var gap := 2.0:
	set(v): gap = v; queue_redraw()
## Colour replacements, e.g. {Color("#010101"): Color("#3a3a3a")}.
var recolor := {}
var show_fn: Callable


## Build cells from an SVG: `cols` cells across; rows follow the aspect ratio.
static func cells_from_svg(data: MotionSvgData, grid_cols: int, palette: Array[Color], alpha_threshold := 110.0 / 255.0) -> Dictionary:
	var vb := data.view_box
	# About 60 source pixels per cell (the Remotion grids came from 10x a ~96-unit
	# viewBox), independent of how large the viewBox is.
	var W := clampi(grid_cols * 60, 64, 4096)
	var H := maxi(1, int(round(W * vb.size.y / vb.size.x)))
	var img := Image.new()
	img.load_svg_from_string(data.to_svg_string(W, H), 1.0)
	img.convert(Image.FORMAT_RGBAF)
	var gh := int(round(grid_cols * float(H) / W))
	var out: Array[Dictionary] = []
	for y in gh:
		for x in grid_cols:
			# Area-weighted box filter (like PIL's BOX resize), premultiplied.
			var fx0 := x * W / float(grid_cols)
			var fx1 := (x + 1) * W / float(grid_cols)
			var fy0 := y * H / float(gh)
			var fy1 := (y + 1) * H / float(gh)
			var acc := Vector4.ZERO
			var wsum := 0.0
			for yy in range(int(floor(fy0)), mini(int(ceil(fy1)), H)):
				var wy := minf(fy1, yy + 1.0) - maxf(fy0, float(yy))
				for xx in range(int(floor(fx0)), mini(int(ceil(fx1)), W)):
					var wx := minf(fx1, xx + 1.0) - maxf(fx0, float(xx))
					var c := img.get_pixel(xx, yy)
					var w := wx * wy
					acc += Vector4(c.r * c.a, c.g * c.a, c.b * c.a, c.a) * w
					wsum += w
			if wsum <= 0.0:
				continue
			acc /= wsum
			if acc.w > alpha_threshold:
				# Un-premultiply, then snap to the palette.
				var rgb := Vector3(acc.x, acc.y, acc.z) / acc.w
				var best := palette[0]
				var bd := INF
				for p in palette:
					var d := rgb.distance_squared_to(Vector3(p.r, p.g, p.b))
					if d < bd:
						bd = d
						best = p
				out.append({x = x, y = y, color = best})
	return {cols = grid_cols, rows = gh, cells = out}


func set_grid(g: Dictionary) -> void:
	cols = g.cols
	rows = g.rows
	cells = g.cells
	queue_redraw()


func _frame(_f: float) -> void:
	if show_fn.is_valid():
		queue_redraw()


func _draw() -> void:
	var cell := width / float(cols)
	for i in cells.size():
		if show_fn.is_valid() and not show_fn.call(i):
			continue
		var c: Dictionary = cells[i]
		var col: Color = recolor.get(c.color, c.color)
		draw_rect(Rect2(c.x * cell, c.y * cell, cell - gap, cell - gap), col)
