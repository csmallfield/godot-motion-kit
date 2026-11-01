# SPDX-License-Identifier: Apache-2.0
## Offscreen 2D rendering for nodes that draw a CanvasItem subtree into a
## texture first (masks, plates, warps, FX passes, time splits, panels): a
## transparent, 2D-only SubViewport added as an internal child, sized to a
## node's size times a render scale, and rendering only while it is needed.
## All static.
##
##   _vp = MotionOffscreen.make(self, content)              # content: a Node2D
##   MotionOffscreen.fit(_vp, size, render_scale)          # in _resize()
##   MotionOffscreen.gate(_vp, is_visible_in_tree())       # in _process / _frame
##   material.set_shader_parameter("tex", _vp.get_texture())
@tool
class_name MotionOffscreen
extends RefCounted


## A transparent SubViewport without 3D, holding `content` (if given), added to
## `owner` as an internal child (`internal`: a Node.InternalMode).
## `filter`: a Viewport.DefaultCanvasItemTextureFilter, or -1 for the default.
## `px`: the viewport size, if known now (negative: leave it, size it with fit()).
static func make(owner: Node, content: Node = null, mode := SubViewport.UPDATE_ALWAYS,
		filter := -1, px := Vector2i(-1, -1), internal := Node.INTERNAL_MODE_FRONT) -> SubViewport:
	var vp := viewport(mode, filter, px)
	if content:
		vp.add_child(content)
	owner.add_child(vp, false, internal)
	return vp


## The same viewport as make(), not added anywhere yet. Viewports render in the
## order they were created, so when the content holds viewports of its own
## (nested offscreen nodes), create this one first, then the content.
static func viewport(mode := SubViewport.UPDATE_ALWAYS, filter := -1, px := Vector2i(-1, -1)) -> SubViewport:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	if px.x >= 0 and px.y >= 0:
		vp.size = px
	vp.render_target_update_mode = mode
	if filter >= 0:
		vp.canvas_item_default_texture_filter = filter as Viewport.DefaultCanvasItemTextureFilter
	return vp


## A Node2D named `node_name`, for a viewport's content root.
static func holder(node_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	return n


## The pixel size for `size` at `scale`: at least 1x1, rounded to the nearest
## pixel (`round_px`) or truncated.
static func pixels(size: Vector2, scale := 1.0, round_px := true) -> Vector2i:
	var p := size * scale
	if round_px:
		return Vector2i(maxi(1, roundi(p.x)), maxi(1, roundi(p.y)))
	return Vector2i(maxi(1, int(p.x)), maxi(1, int(p.y)))


## Size `vp` to `size * scale` pixels (see pixels()) and scale its canvas by
## `scale`, so content keeps authoring in the owner's units. The canvas
## transform can only be set in the tree: call it again from _ready().
static func fit(vp: SubViewport, size: Vector2, scale := 1.0, round_px := true) -> void:
	vp.size = pixels(size, scale, round_px)
	if vp.is_inside_tree():
		vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(scale, scale))


## Render `vp` every frame while `on`, not at all otherwise (a hidden node
## needn't render offscreen). Returns true when the mode changed.
static func gate(vp: SubViewport, on: bool) -> bool:
	var want := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if vp.render_target_update_mode == want:
		return false
	vp.render_target_update_mode = want
	return true
