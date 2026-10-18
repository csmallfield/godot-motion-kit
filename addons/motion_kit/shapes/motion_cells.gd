# SPDX-License-Identifier: Apache-2.0
## A grid of palette-coloured cells (cellular automata, LED boards, pixel
## mosaics, minimaps), drawn in one quad from a byte per cell. Set `cells`
## (columns x rows bytes, row-major; 0 = empty, n = palette[n]) each frame;
## only the small state texture is re-uploaded.
##
##   var g := MotionCells.new()
##   g.columns = 80; g.rows = 45; g.cell_size = Vector2(24, 24); g.inset = 1.5
##   g.palette = PackedColorArray([Color.TRANSPARENT, CREAM, AMBER, RED])
##   g.grid_color = Color(1, 1, 1, 0.035)
##   g.cells = state_bytes
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionCells
extends Node2D

const SHADER := preload("res://addons/motion_kit/shaders/motion_cells.gdshader")
const MAX_COLOURS := 16

@export var columns := 8:
	set(v): columns = maxi(1, v); _resize()
@export var rows := 8:
	set(v): rows = maxi(1, v); _resize()
## Size of one cell in pixels; the grid covers columns x rows of them from the origin.
@export var cell_size := Vector2(24, 24):
	set(v): cell_size = v; _sync()
## Gap inside each cell edge, in pixels: a cell fills [inset, size - inset].
## Fractional insets are anti-aliased exactly (1.5 gives half-covered edge pixels).
@export var inset := 1.5:
	set(v): inset = v; _sync()
## Colours by cell value; index 0 is never drawn. Up to 16.
@export var palette := PackedColorArray([Color.TRANSPARENT, Color.WHITE]):
	set(v): palette = v; _sync()
## Grid lines along every cell boundary (0..columns, 0..rows); alpha 0 hides them.
## Where lines cross, their alphas compound, as two overlapping rects would.
@export var grid_color := Color(1, 1, 1, 0):
	set(v): grid_color = v; _sync()
@export var grid_width := 1.0:
	set(v): grid_width = v; _sync()
## Row-major cell values, columns * rows bytes.
@export var cells := PackedByteArray():
	set(v): cells = v; _upload()

var _mat: ShaderMaterial
var _img: Image
var _tex: ImageTexture


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_resize()


## Value of the cell at (x, y), or 0 outside the grid.
func get_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= columns or y >= rows or cells.size() < columns * rows:
		return 0
	return cells[y * columns + x]


func _resize() -> void:
	if cells.size() != columns * rows:
		cells.resize(columns * rows)   # setter not re-entered by resize(); upload below
	_img = null
	_upload()


func _upload() -> void:
	if not _mat:
		return
	var data := cells
	if data.size() != columns * rows:
		data = data.duplicate()
		data.resize(columns * rows)
	if _img and _img.get_width() == columns and _img.get_height() == rows:
		_img.set_data(columns, rows, false, Image.FORMAT_R8, data)
		_tex.update(_img)
	else:
		_img = Image.create_from_data(columns, rows, false, Image.FORMAT_R8, data)
		_tex = ImageTexture.create_from_image(_img)
		_mat.set_shader_parameter("state", _tex)
	_sync()


func _sync() -> void:
	if not _mat:
		return
	var pal := PackedColorArray()
	pal.resize(MAX_COLOURS)
	for i in mini(palette.size(), MAX_COLOURS):
		pal[i] = palette[i]
	_mat.set_shader_parameter("palette", pal)
	_mat.set_shader_parameter("cell", cell_size)
	_mat.set_shader_parameter("inset", inset)
	_mat.set_shader_parameter("grid_color", grid_color)
	_mat.set_shader_parameter("grid_width", grid_width)
	_mat.set_shader_parameter("dims", Vector2i(columns, rows))
	queue_redraw()


func _draw() -> void:
	# One quad over the grid, plus the far grid lines just past it.
	var r := Rect2(Vector2.ZERO, cell_size * Vector2(columns, rows))
	if grid_color.a > 0.0:
		r = r.grow_individual(0, 0, grid_width, grid_width)
	draw_rect(r, Color.WHITE)
