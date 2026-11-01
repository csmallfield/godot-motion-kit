# SPDX-License-Identifier: Apache-2.0
# Content for FTF Time City, seen through MotionTimeSlices (and once plain):
# the machine city at its own moment f. Every instance shares one world
# (city_world.gd) and culls itself to the strip of screen its band shows
# (MotionViewRect.of), so 32 columns cost about one city in total plus a
# small per-band overhead. Accepts negative frames (black, nothing built).
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_timecity/time_look.gd")
const World := preload("res://demo/ftf/ftf_timecity/city_world.gd")

static var _shared: RefCounted

var _built := false
var _w: World
var _f := 0.0
var _view := Rect2()
var _bg: ColorRect
var _dark: ColorRect
var _back: MotionCanvas
var _front: MotionCanvas
var _mh_sides: Array[MotionCanvas] = []
var _mh_masks: Array[MotionCanvas] = []
var _mh_svgs: Array[MotionSvg] = []
var _mh_polys: Array = [[], [], [], []]
var _ftf_sides: MotionCanvas
var _ftf_mask: MotionCanvas
var _ftf_svg: MotionSvg
var _ftf_polys: Array = []


func _init() -> void:
	duration = 100000
	autoplay = false
	hide_outside = false


static func world() -> World:
	if _shared == null:
		_shared = World.new()
	return _shared


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _build() -> void:
	_built = true
	_w = world()
	_bg = ColorRect.new()
	_bg.color = L.PAPER
	_bg.size = size
	add_child(_bg)
	_back = _canvas(func(c: MotionCanvas, f: float) -> void:
		_pose()
		_w.scene.draw_solid(c, _w.platform)
		_w.ground_markings(c, f)
		_w.scene.draw(c, func(s: MotionSolid) -> bool: return not _w.is_special(s) and not _w.is_front(s)))
	_mh_sides.append(_canvas(_sides_fn(_w.backdrop, true)))
	_mh_sides.append(_canvas(_sides_fn(_w.plinth, true)))
	for i in 3:
		_mh_sides.append(_canvas(_sides_fn(_w.mh_slabs[i])))
		var m := _mask_canvas(i)
		_mh_masks.append(m)
		_mh_svgs.append(_svg_node(m, _w.mh_data, [i]))
	_mh_sides.append(_canvas(func(c: MotionCanvas, _f2: float) -> void:
		_pose()
		for s in _w.mh_letters:
			_w.scene.draw_solid(c, s)))
	var lm := _mask_canvas(3)
	_mh_masks.append(lm)
	_mh_svgs.append(_svg_node(lm, _w.mh_data, range(3, 16)))
	_ftf_sides = _canvas(_sides_fn(_w.ftf))
	_ftf_mask = MotionCanvas.new()
	_ftf_mask.draw_fn = func(c: MotionCanvas, _f2: float) -> void:
		for poly in _ftf_polys:
			c.draw_colored_polygon(poly, Color.WHITE)
	add_child(_ftf_mask)
	_ftf_svg = _svg_node(_ftf_mask, _w.ftf_data, [])
	_front = _canvas(func(c: MotionCanvas, _f2: float) -> void:
		_pose()
		_w.scene.draw(c, func(s: MotionSolid) -> bool: return not _w.is_special(s) and _w.is_front(s)))
	_dark = ColorRect.new()
	_dark.color = L.BLACK
	_dark.size = size
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)


func _canvas(fn: Callable) -> MotionCanvas:
	var c := MotionCanvas.new()
	c.draw_fn = fn
	add_child(c)
	return c


func _sides_fn(s: MotionSolid, with_cap := false) -> Callable:
	return func(c: MotionCanvas, _f2: float) -> void:
		_pose()
		s.draw_front_cap = with_cap
		_w.scene.draw_solid(c, s)


func _mask_canvas(i: int) -> MotionCanvas:
	var m := MotionCanvas.new()
	m.draw_fn = func(c: MotionCanvas, _f2: float) -> void:
		for poly in _mh_polys[i]:
			c.draw_colored_polygon(poly, Color.WHITE)
	add_child(m)
	return m


func _svg_node(parent: Node, data: MotionSvgData, only: Array) -> MotionSvg:
	var s := MotionSvg.new()
	s.data = data
	s.width = data.view_box.size.x
	if not only.is_empty():
		s.only = PackedInt32Array(only)
	parent.add_child(s)
	return s


## Re-pose the shared world for this instance (another band may have posed it since).
func _pose() -> void:
	_w.pose(_f, _view)


func _frame(f: float) -> void:
	if not _built:
		return
	_f = f
	_view = MotionViewRect.of(self, 6.0)
	if not _view.has_area():
		_view = Rect2(Vector2.ZERO, size)
	_w.pose_light(f)
	var vis := _view
	var dark := 1.0 - MK.map(f, [0, 10], [0, 1], MK.linear) + MK.map(f, [L.DARK, L.DARK_END], [0, 1], MK.ease_in_quad)
	_dark.color.a = clampf(dark, 0.0, 1.0)
	_dark.visible = _dark.color.a > 0.002
	var full := _dark.color.a >= 0.999
	_bg.visible = not full
	_back.visible = not full
	_front.visible = not full
	var sc := _w.scene
	# monument
	var mh_on := _w.mh_on and not full
	for c in _mh_sides:
		c.visible = mh_on and vis.intersects(MotionViewRect.box(sc.camera, Vector3(World.MH_X + World.MH_WIDTH * 0.5, World.MH_Y, 1.4), Vector3(World.MH_WIDTH * 0.5 + 0.8, 1.6, 2.2)))
	for i in 4:
		var src: Array[MotionSolid] = []
		if i < 3:
			src.append(_w.mh_slabs[i])
		else:
			src = _w.mh_letters
		_place_cap(_mh_masks[i], _mh_svgs[i], src, _mh_polys[i], mh_on, vis)
	var ftf_list: Array[MotionSolid] = [_w.ftf]
	_ftf_sides.visible = _w.ftf_on and not full and vis.intersects(MotionViewRect.box(sc.camera, Vector3(World.FTF_X + World.FTF_WIDTH * 0.5, World.FTF_Y, _w.ftf.origin.z - _w.ftf_h * 0.5), Vector3(World.FTF_WIDTH * 0.5 + 0.2, 0.8, _w.ftf_h * 0.5 + 0.2)))
	_place_cap(_ftf_mask, _ftf_svg, ftf_list, _ftf_polys, _w.ftf_on and not full, vis)


## Put an SVG on solids' caps (the first solid's transform), masked while cut by the ground.
func _place_cap(mask: MotionCanvas, svg: MotionSvg, list: Array[MotionSolid], polys: Array, on: bool, vis: Rect2) -> void:
	polys.clear()
	if not on:
		mask.visible = false
		return
	var sc := _w.scene
	var whole := true
	var box := Rect2()
	for q in list:
		var poly := sc.cap_polygon(q)
		if not sc.cap_unclipped(q):
			whole = false
		if poly.size() >= 3 and absf(MotionExtrude._area2(poly)) > 2.0:
			polys.append(poly)
			var b := MotionExtrude._bounds(poly)
			box = b if not box.has_area() else box.merge(b)
	if polys.is_empty() or not vis.intersects(box):
		mask.visible = false
		return
	svg.transform = sc.cap_transform(list[0])
	mask.visible = true
	mask.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED if whole else CanvasItem.CLIP_CHILDREN_ONLY
	if whole:
		polys.clear()
	mask.queue_redraw()
