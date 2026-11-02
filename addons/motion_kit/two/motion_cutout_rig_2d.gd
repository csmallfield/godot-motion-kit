# SPDX-License-Identifier: Apache-2.0
## A 2D cutout character drawn from a MotionCutoutAtlas: one Sprite2D per
## baked layer, all sharing the atlas texture and one material, posed by a
## small forward-kinematics pass in script. Built for crowds:
##   - no pivot nodes: moving the character moves one CanvasItem, and pose
##     cost is paid only when you call apply() (skip it on far or idle
##     characters and they keep their last pose for free);
##   - several views (front, back, side...) share one sprite pool: a turn
##     reassigns regions, it builds nothing;
##   - tint, fade and hit flash are the CanvasItem's modulate (set_look),
##     not per-sprite uniforms, so every rig of an atlas batches.
##
##   var rig := MotionCutoutRig2D.new(atlas)
##   rig.add_view(&"front", &"hero/front", MotionCutoutRig2D.EITHER)
##   rig.add_view(&"back", &"hero/back", MotionCutoutRig2D.EITHER)
##   rig.add_view(&"side", &"hero/side", MotionCutoutRig2D.RIGHT)
##   rig.add_view(&"side_left", &"hero/side_left", MotionCutoutRig2D.LEFT)
##   rig.display_scale = 0.5                  # baked at 2x
##   add_child(rig)
##   # each frame:
##   rig.face(velocity)                       # screen direction, y down
##   rig.step(delta)                          # paper turn
##   rig.reset_pose()
##   rig.pose(&"head", 0.1)
##   rig.solve_limb(&"arm_r_upper", &"arm_r_lower", &"hand_r", target, 1.0)
##   rig.apply()
##
## Coordinates: rig-local pixels at the bake scale, origin at the view's
## `origin` (the feet), y down. Rotations are radians, positive clockwise on
## screen (Godot's 2D convention). Views share parts by name; a part a view
## doesn't have is simply not drawn in it.
##
## Facing (face()): 0 degrees is sideways (the art faces right), +90 toward
## the viewer (down the screen), -90 away (up). Views sit at an angle with a
## side, as MotionCutout's do: MIRROR (drawn facing right, mirrored for the
## left), RIGHT and LEFT (one way only; a LEFT view is usually
## MotionSvgData.mirrored() of the right one, the partial mirror that keeps a
## sword in the same hand) and EITHER (never mirrored: front and back).
@tool
class_name MotionCutoutRig2D
extends Node2D

## Emitted when the shown view changes.
signal view_changed(view: StringName, mirrored: bool)

enum { MIRROR, RIGHT, LEFT, EITHER }

## Default facing angles (degrees) for the usual view names.
const ANGLES := {&"front": 90.0, &"front_34": 45.0, &"side": 0.0, &"side_left": 0.0, &"back_34": -45.0, &"back": -90.0}

var atlas: MotionCutoutAtlas
## Mirror and paper-turn node (scale.x); the body hangs below it.
var flip: Node2D
## Whole-body transform for the driver: tumble, squash, hop. Its origin is
## the rig origin (the feet) unless you move it.
var body: Node2D
## View name -> {key, angle, side}.
var views := {}
## The view showing, whether it is mirrored, and whether facing left.
var view: StringName = &""
var mirrored := false
var left := false
## Paper turn: the card narrows to swap views (off: instant swaps).
var paper_turn := true
var turn := MotionSpring.new(1.0, 18.0, 520.0)
## Degrees of hysteresis around the borders between views.
var hysteresis := 12.0
## Scale from baked pixels to the rig's local pixels (0.5 when baked at 2x).
var display_scale := 1.0:
	set(v):
		display_scale = v
		if flip:
			_apply_flip()

var _names: Array[StringName] = []   # every part name of every view, plus props
var _index := {}                     # name -> index
var _parent := PackedInt32Array()    # per index, for the current view (-1 = root)
var _rest := PackedVector2Array()    # per index: offset from the parent's pivot, current view
var _rrot := PackedFloat32Array()    # per index: rest rotation (props), current view
var _pivot := PackedVector2Array()   # per index: rest pivot, rig-local, current view
var _has := PackedByteArray()        # per index: present in the current view
var _order := PackedInt32Array()     # FK order for the current view
var _rot := PackedFloat32Array()
var _off := PackedVector2Array()
var _scl := PackedVector2Array()
var _g: Array[Transform2D] = []
var _depth := PackedInt32Array()     # per index: -1 behind everything, 0, +1 in front
var _sprites: Array[Sprite2D] = []
var _sprite_part := PackedInt32Array()
var _props := {}                     # name -> {parent, key, at, rot, above}
var _view_cache := {}                # view name -> per-view arrays
var _want_view: StringName = &""
var _want_mirror := false
var _want_left := false
var _turn_mid := false               # narrowing toward a swap


func _init(atlas_: MotionCutoutAtlas = null) -> void:
	atlas = atlas_
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flip = Node2D.new()
	flip.name = "Flip"
	add_child(flip)
	body = Node2D.new()
	body.name = "Body"
	flip.add_child(body)


## Add a view drawn from the atlas view `key`, at a facing angle (NAN takes
## the default for its name, ANGLES) and a side (MIRROR, RIGHT, LEFT, EITHER).
## The first view added shows first.
func add_view(name: StringName, key: StringName, side := MIRROR, angle_deg := NAN) -> void:
	assert(atlas and atlas.has_view(key), "MotionCutoutRig2D: no atlas view %s" % key)
	views[name] = {key = key, side = side, angle = angle_deg if not is_nan(angle_deg) else float(ANGLES.get(name, 0.0))}
	for n: StringName in atlas.views[key].names:
		_part_index(n)
	_view_cache.clear()
	if view == &"":
		_show(name, side == LEFT)
		_want_view = view
		_want_mirror = mirrored
		_want_left = left


## Hang a prop (an atlas card) on `parent`: `at` px from the parent's pivot in
## the parent's frame, turned `rot`, drawn just in front of the parent's
## layers (`above`) or just behind them. The prop is a part named `name`:
## pose(), depth() and global_part() work on it.
func add_prop(name: StringName, parent: StringName, key: StringName, at := Vector2.ZERO, rot := 0.0, above := false) -> void:
	assert(atlas and atlas.has_view(key), "MotionCutoutRig2D: no atlas card %s" % key)
	_part_index(name)
	_props[name] = {parent = parent, key = key, at = at, rot = rot, above = above}
	_view_cache.clear()
	if view != &"":
		_show(view, mirrored)


func has_part(name: StringName) -> bool:
	var i: int = _index.get(name, -1)
	return i >= 0 and _has[i] == 1


## A part's rest pivot in the current view (rig-local px).
func rest_pivot(name: StringName) -> Vector2:
	return _pivot[_index[name]]


## Every part back to rest (and every depth override cleared).
func reset_pose() -> void:
	_rot.fill(0.0)
	_off.fill(Vector2.ZERO)
	_scl.fill(Vector2.ONE)


## Pose a part relative to rest: rotation (radians, clockwise), offset (px in
## its parent's frame), scale.
func pose(name: StringName, rot := 0.0, offset := Vector2.ZERO, scale_ := Vector2.ONE) -> void:
	var i: int = _index.get(name, -1)
	if i < 0:
		return
	_rot[i] = rot
	_off[i] = offset
	_scl[i] = scale_


## Add to a part's pose rotation (layers stack: an authored pose, then a
## wobble on top).
func add_rot(name: StringName, rot: float) -> void:
	var i: int = _index.get(name, -1)
	if i >= 0:
		_rot[i] += rot


func get_rot(name: StringName) -> float:
	var i: int = _index.get(name, -1)
	return _rot[i] if i >= 0 else 0.0


## Draw `name` and everything hanging from it in front of the rest of the
## rig (+1), behind it (-1), or in its drawn place (0). Changing it re-sorts
## the layers (cheap, but don't flip it every frame without need).
func depth(name: StringName, d: int) -> void:
	var i: int = _index.get(name, -1)
	if i < 0 or _depth[i] == d:
		return
	_depth[i] = d
	_assign_layers()


## Two-bone IK on upper -> lower -> tip: rotate `upper` and `lower` so the
## tip's pivot lands on `target` (rig-local px, as the parts' pivots). `bend`
## picks the side the middle joint goes (+1 or -1). True when in reach.
func solve_limb(upper: StringName, lower: StringName, tip: StringName, target: Vector2, bend := 1.0) -> bool:
	var iu: int = _index[upper]
	var il: int = _index[lower]
	var it: int = _index[tip]
	var a0 := _pivot[iu]
	var b0 := _pivot[il]
	var c0 := _pivot[it]
	var l1 := a0.distance_to(b0)
	var l2 := b0.distance_to(c0)
	var p := _parent[iu]
	var pt := _chain(p)
	var root := pt * _rest[iu]
	var s := MotionIK.two_bone_2d(root, target, l1, l2, bend)
	var mid: Vector2 = s.mid
	var end: Vector2 = s.end
	var par_rot := pt.get_rotation()
	var up_rest := (b0 - a0).angle()
	var lo_rest := (c0 - b0).angle()
	var up_rot := (mid - root).angle() - up_rest
	_rot[iu] = wrapf(up_rot - par_rot, -PI, PI)
	_rot[il] = wrapf((end - mid).angle() - lo_rest - up_rot, -PI, PI)
	_off[iu] = Vector2.ZERO
	_off[il] = Vector2.ZERO
	return s.reached


## A part's current transform in rig-local px (its pivot at origin), from the
## current pose. Valid without apply().
func part_transform(name: StringName) -> Transform2D:
	return _chain(_index[name])


## Where a point in a part's frame (px from its pivot) is now, rig-local.
func part_point(name: StringName, local := Vector2.ZERO) -> Vector2:
	return _chain(_index[name]) * local


## Write the pose to the sprites: one forward-kinematics pass. Call once per
## posed frame, after every pose(), solve_limb() and depth().
func apply() -> void:
	for i in _order:
		var p := _parent[i]
		var local := Transform2D(_rrot[i] + _rot[i], _scl[i], 0.0, _rest[i] + _off[i])
		_g[i] = _g[p] * local if p >= 0 else local
	for s in _sprites.size():
		var pi := _sprite_part[s]
		if pi >= 0:
			_sprites[s].transform = _g[pi]


## Pick the view for a screen direction (y down; zero keeps the current one).
## With paper_turn the swap happens in step(), else at once.
func face(dir: Vector2) -> void:
	if dir.length_squared() < 1e-8:
		return
	var is_left := dir.x < -0.001 or (absf(dir.x) <= 0.001 and _want_left)
	var ang := rad_to_deg(atan2(dir.y, absf(dir.x)))
	var best: StringName = &""
	var bd := INF
	for n: StringName in views:
		var v: Dictionary = views[n]
		if (v.side == RIGHT and is_left) or (v.side == LEFT and not is_left):
			continue
		var d := absf(ang - float(v.angle))
		if n == _want_view:
			d -= hysteresis
		if d < bd:
			bd = d
			best = n
	if best == &"":
		return
	var mir: bool = views[best].side == MIRROR and is_left
	_want_left = is_left
	if best == view and mir == mirrored:
		_want_view = best
		_want_mirror = mir
		return
	if best == _want_view and mir == _want_mirror:
		return
	_want_view = best
	_want_mirror = mir
	if not paper_turn:
		left = is_left
		_show(best, mir)
		return
	# narrow toward edge-on in proportion to the turn
	var a0 := float(views[view].angle) * (-1.0 if mirrored else 1.0)
	var a1 := float(views[best].angle) * (-1.0 if mir else 1.0)
	var mirror_change: bool = mirrored != mir or (views[view].side == LEFT) != (views[best].side == LEFT)
	var frac := 1.0 if mirror_change else clampf(absf(a1 - a0) / 90.0, 0.0, 1.0)
	turn.target = 1.0 - frac * 0.92
	_turn_mid = true


## Advance the paper turn (only needed with paper_turn).
func step(dt: float) -> void:
	if not paper_turn or (turn.is_settled(0.002) and not _turn_mid):
		return
	turn.step(dt)
	if _turn_mid and turn.value <= turn.target + 0.06:
		left = _want_left
		_show(_want_view, _want_mirror)
		turn.target = 1.0
		_turn_mid = false
	_apply_flip()


## Tint (rgb multiply), fade (alpha) and hit flash (0..1 toward the material's
## flash colour) as one modulate. A flash shows at full opacity.
func set_look(tint := Color.WHITE, flash := 0.0, alpha := 1.0) -> void:
	modulate = Color(tint.r, tint.g, tint.b, 1.0 + clampf(flash, 0.0, 1.0) if flash > 0.001 else alpha)


## Number of sprites (drawn layers) in the pool.
func layer_count() -> int:
	return _sprites.size()


# ------------------------------------------------------------------ internals

func _part_index(n: StringName) -> int:
	if _index.has(n):
		return _index[n]
	var i := _names.size()
	_names.append(n)
	_index[n] = i
	_parent.append(-1)
	_rest.append(Vector2.ZERO)
	_pivot.append(Vector2.ZERO)
	_has.append(0)
	_rrot.append(0.0)
	_rot.append(0.0)
	_off.append(Vector2.ZERO)
	_scl.append(Vector2.ONE)
	_g.append(Transform2D.IDENTITY)
	_depth.append(0)
	return i


## Product of a part's chain of local transforms (identity for the root).
func _chain(i: int) -> Transform2D:
	var t := Transform2D.IDENTITY
	while i >= 0:
		t = Transform2D(_rrot[i] + _rot[i], _scl[i], 0.0, _rest[i] + _off[i]) * t
		i = _parent[i]
	return t


func _apply_flip() -> void:
	var w := turn.value if paper_turn else 1.0
	flip.scale = Vector2((-1.0 if mirrored else 1.0) * w, 1.0) * display_scale


func _view_data(name: StringName) -> Dictionary:
	if _view_cache.has(name):
		return _view_cache[name]
	var av: Dictionary = atlas.views[views[name].key]
	var n := _names.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	var pivot := PackedVector2Array()
	pivot.resize(n)
	var has := PackedByteArray()
	has.resize(n)
	var order := PackedInt32Array()
	for pn: StringName in av.names:
		var i: int = _index[pn]
		has[i] = 1
		pivot[i] = av.pivot[pn]
		parent[i] = _index[av.parent[pn]] if pn != &"" else -1
		order.append(i)
	# layers: [part index, region, offset, base order]
	var layers := []
	for L in av.layers:
		layers.append([_index[L.part], L.region, L.offset])
	# props: after the view's parts, inserted next to their parent's layers
	for pn: StringName in _props:
		var pr: Dictionary = _props[pn]
		var pi: int = _index.get(pr.parent, -1)
		if pi < 0 or has[pi] == 0:
			continue
		var i: int = _index[pn]
		has[i] = 1
		parent[i] = pi
		pivot[i] = pivot[pi] + (pr.at as Vector2)
		order.append(i)
		var card: Dictionary = atlas.views[pr.key].layers[0]
		var at := -1
		for li in layers.size():
			if layers[li][0] == pi:
				if at < 0 or pr.above:
					at = li if not pr.above else li + 1
		if at < 0:
			at = layers.size()
		layers.insert(at, [i, card.region, card.offset])
	var rest := PackedVector2Array()
	rest.resize(n)
	var rrot := PackedFloat32Array()
	rrot.resize(n)
	for i in order:
		rest[i] = pivot[i] - (pivot[parent[i]] if parent[i] >= 0 else Vector2.ZERO)
	for pn: StringName in _props:
		rrot[_index[pn]] = float(_props[pn].rot)
	var d := {parent = parent, pivot = pivot, has = has, order = order, rest = rest, rrot = rrot, layers = layers}
	_view_cache[name] = d
	return d


func _show(name: StringName, mir: bool) -> void:
	var d := _view_data(name)
	_parent = d.parent
	_pivot = d.pivot
	_has = d.has
	_order = d.order
	_rest = d.rest
	_rrot = d.rrot
	view = name
	mirrored = mir
	_assign_layers()
	_apply_flip()
	apply()
	view_changed.emit(view, mirrored)


## Hand the view's layers to the sprite pool, in draw order with depth
## overrides applied (a part takes the strongest override up its chain).
func _assign_layers() -> void:
	if view == &"":
		return
	var layers: Array = _view_cache[view].layers if _view_cache.has(view) else _view_data(view).layers
	var keyed := []
	for li in layers.size():
		var pi: int = layers[li][0]
		var dd := 0
		var j := pi
		while j >= 0:
			if _depth[j] != 0:
				dd = _depth[j]
				break
			j = _parent[j]
		keyed.append([dd, li])
	keyed.sort_custom(func(a, b) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	while _sprites.size() < layers.size():
		var s := Sprite2D.new()
		s.texture = atlas.texture
		s.material = MotionCutoutAtlas.material()
		s.centered = false
		s.region_enabled = true
		body.add_child(s)
		_sprites.append(s)
		_sprite_part.append(-1)
	for s in _sprites.size():
		var sp := _sprites[s]
		if s < keyed.size():
			var L: Array = layers[keyed[s][1]]
			_sprite_part[s] = L[0]
			sp.region_rect = L[1]
			sp.offset = L[2]
			sp.visible = true
			sp.transform = _g[L[0]]
		else:
			_sprite_part[s] = -1
			sp.visible = false
