# SPDX-License-Identifier: Apache-2.0
## What part of a node's own space is actually on screen: for content that
## culls itself. The main use is heavy content seen through MotionTimeSlices.
## Each band renders its own instance into a SubViewport the size of the band,
## with the content shifted to the band's source rectangle, so a band only ever
## shows a thin strip of the picture. Content that asks `MotionViewRect.of(self)`
## in its `_frame(f)` gets that strip (in its own 1920x1080 coordinates) and
## can skip everything outside it: with rows or columns the bands then cost
## about one full picture in total instead of one picture each.
##
##   func _frame(f):
##       var view := MotionViewRect.of(self, 8.0)       # this band's strip, padded
##       scene.cull_rect = view                         # MotionExtrude culls per solid
##       for cell in cells:                             # cheap per-cell cull first
##           cell.on = view.intersects(MotionViewRect.box(scene.camera, cell.centre, cell.half))
##
## It works anywhere: in the root viewport it is the visible frame (through any
## stage shake or scale), inside a MotionFX or a SubViewport it is that
## viewport's area. Frame-pure: it reads the node's current transform only, so
## call it from `_frame` after the parents have been placed (MotionTimeSlices
## places each band's holder in its own `_frame`, before the walk reaches the
## content).
@tool
class_name MotionViewRect
extends RefCounted


## The rectangle of `item`'s local space its viewport shows, grown by `pad`.
## Empty when the item isn't in the tree.
static func of(item: CanvasItem, pad := 0.0) -> Rect2:
	if item == null or not item.is_inside_tree():
		return Rect2()
	var vp := item.get_viewport()
	if vp == null:
		return Rect2()
	var inv := item.get_global_transform_with_canvas().affine_inverse()
	return (inv * vp.get_visible_rect()).grow(pad)


## True when `item` renders into a SubViewport smaller than `full` (a band of a
## MotionTimeSlices, a cropped MotionFX): content may then cull harder.
static func is_partial(item: CanvasItem, full := Vector2(1920, 1080)) -> bool:
	var r := of(item)
	return r.has_area() and (r.size.x < full.x - 0.5 or r.size.y < full.y - 0.5)


## Screen bounds of a world box (centre, half extents) through an orthographic
## MotionExtrudeCamera: exact for the box, so a cheap, conservative cull for
## anything inside it. The camera must be updated.
static func box(cam: MotionExtrudeCamera, centre: Vector3, half: Vector3) -> Rect2:
	var c := cam.project(centre)
	var ex := cam.vec(Vector3(half.x, 0, 0)).abs()
	var ey := cam.vec(Vector3(0, half.y, 0)).abs()
	var ez := cam.vec(Vector3(0, 0, half.z)).abs()
	var e := ex + ey + ez
	return Rect2(c - e, e * 2.0)
