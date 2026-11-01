# SPDX-License-Identifier: Apache-2.0
## A texture atlas of 2D drawings for 3D decals: serials, katakana, arrows,
## chevrons, hazard stripes... drawn once with the kit's 2D tools into cells of
## one SubViewport, then mapped onto many quads (MotionFlat3D.decal) in one
## merged mesh with one draw call. Draw artwork in white: vertex colour tints
## it, so one cell serves red, cream and ink markings.
##
##   var atlas := MotionDecalAtlas.new()
##   stage.world.add_child(atlas)      # anywhere in the tree, before first draw
##   var exit_uv := atlas.add(Vector2i(256, 96), func(c: MotionCanvas, sz: Vector2) -> void:
##       c.draw_string(font, Vector2(8, 70), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE))
##   var mat := flat.decals(atlas.texture)
##
## Cells are packed in shelves with `pad` pixels between them. The atlas
## renders once (UPDATE_ONCE) on the first frame drawn; call `refresh()` after
## adding cells later.
@tool
class_name MotionDecalAtlas
extends Node

## Atlas size in pixels.
var size := Vector2i(2048, 2048)
## Gap between cells (avoids bleeding when sampled with filtering).
var pad := 6
var viewport: SubViewport
var texture: ViewportTexture

var _x := 0
var _y := 0
var _row := 0


func _init(atlas_size := Vector2i(2048, 2048)) -> void:
	size = atlas_size
	viewport = SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport, false, Node.INTERNAL_MODE_FRONT)
	texture = viewport.get_texture()


## Reserve a cell of `px` pixels drawn by `fn(c: MotionCanvas, size: Vector2)`;
## returns its UV rect (0..1) for MotionFlat3D.decal().
func add(px: Vector2i, fn: Callable) -> Rect2:
	if _x + px.x + pad > size.x:
		_x = 0
		_y += _row + pad
		_row = 0
	if _y + px.y > size.y:
		push_error("MotionDecalAtlas: out of space")
		return Rect2()
	var at := Vector2(_x, _y)
	var c := MotionCanvas.new()
	c.position = at
	var sz := Vector2(px)
	c.draw_fn = func(cv: MotionCanvas, _f: float) -> void: fn.call(cv, sz)
	viewport.add_child(c)
	_x += px.x + pad
	_row = maxi(_row, px.y)
	return Rect2(at / Vector2(size), sz / Vector2(size))


## Draw the atlas again (after adding cells late).
func refresh() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
