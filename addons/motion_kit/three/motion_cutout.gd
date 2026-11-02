# SPDX-License-Identifier: Apache-2.0
## A cutout character seen from a fixed game camera: up to three views of the
## same rig (front, back, side; MotionCutoutRig each), one shown at a time,
## picked from the facing direction, with a paper turn between them (the
## card's width springs through zero and the view swaps while it is edge-on).
## Mirroring covers the other side: side art faces right, front and back
## mirror with the horizontal facing too.
##
##   var cut := MotionCutout.new()
##   cut.add_view(&"front", front_rig); cut.add_view(&"back", back_rig); cut.add_view(&"side", side_rig)
##   cut.lean(camera_pitch_deg, 20.0)
##   cut.face(Vector2(move.x, move.z))      # world x, z (+z toward the camera)
##   cut.step(clock.dt)
##   cut.rig.solve_limb(...)                # pose the view that's showing
##
## Lean: the cards tilt back by `lean_deg` toward the camera and stretch by
## 1 / cos(pitch - lean), so the art keeps its drawn proportions on screen.
## Upright cards (0) occlude correctly against props behind them; fully
## facing cards (lean = pitch) can dip into them.
@tool
class_name MotionCutout
extends Node3D

## Emitted when the shown view changes (at the edge-on moment of a turn).
signal view_changed(view: StringName, mirrored: bool)

## Name -> MotionCutoutRig.
var views := {}
## The view showing now, and whether it is mirrored.
var view: StringName = &""
var mirrored := false
var rig: MotionCutoutRig
## Paper turn spring (the card's width); off = instant swaps.
var paper_turn := true
var turn := MotionSpring.new(1.0, 16.0, 420.0)
## Degrees of hysteresis around the 45-degree sector borders.
var hysteresis := 12.0
## The card holder (lean and stretch); views hang below `flip`.
var card: Node3D
var flip: Node3D

var _want_view: StringName = &""
var _want_mirror := false


func _init() -> void:
	card = Node3D.new()
	card.name = "Card"
	add_child(card)
	flip = Node3D.new()
	flip.name = "Flip"
	card.add_child(flip)


## Add a view (the first one added shows first).
func add_view(name: StringName, r: MotionCutoutRig) -> void:
	views[name] = r
	flip.add_child(r)
	r.visible = false
	if view == &"":
		_show(name, false)
		_want_view = name


## Tilt the cards back toward a camera pitched `pitch_deg` below the horizon.
func lean(pitch_deg: float, lean_deg := 20.0) -> void:
	var l := deg_to_rad(lean_deg)
	card.rotation = Vector3(-l, 0, 0)
	card.scale = Vector3(1, 1.0 / maxf(cos(deg_to_rad(pitch_deg) - l), 0.2), 1)


## Face a direction (world x, z; +z toward the camera). A zero vector keeps
## the current facing.
func face(dir: Vector2) -> void:
	if dir.length_squared() < 1e-6:
		return
	var v := choose(dir, _want_view, hysteresis, views.has(&"side"), views.has(&"back"))
	_want_view = v
	_want_mirror = dir.x < -1e-3 if absf(dir.x) > 1e-3 else _want_mirror
	if not paper_turn:
		_show(_want_view, _want_mirror)


## The view for a facing: "side" in the left and right sectors, "front"
## toward the camera, "back" away; the current view keeps an extra
## `hyst` degrees so diagonals don't flicker.
static func choose(dir: Vector2, current: StringName, hyst := 12.0, has_side := true, has_back := true) -> StringName:
	var a := rad_to_deg(atan2(dir.y, absf(dir.x)))      # 0 = sideways, +90 toward camera, -90 away
	var side_half := 45.0 + (hyst if current == &"side" else -hyst if current != &"" else 0.0)
	if has_side and absf(a) < side_half:
		return &"side"
	if a > 0.0 or not has_back:
		return &"front"
	return &"back"


## Advance the paper turn by `dt` seconds.
func step(dt: float) -> void:
	var want_sign := -1.0 if _want_mirror else 1.0
	var changing := _want_view != view or _want_mirror != mirrored
	if not paper_turn:
		_show(_want_view, _want_mirror)
		turn.snap(want_sign)
	elif changing:
		# a flip to the other side springs straight through zero; a view change
		# on the same side narrows to edge-on and opens again
		var crossing := _want_mirror != mirrored
		turn.target = want_sign if crossing else 0.0
		turn.step(dt)
		if absf(turn.value) < 0.15 or (crossing and signf(turn.value) == want_sign):
			_show(_want_view, _want_mirror)
	else:
		turn.target = want_sign
		turn.step(dt)
	flip.scale = Vector3(turn.value, 1, 1)


func _show(name: StringName, mirror: bool) -> void:
	for n in views:
		(views[n] as MotionCutoutRig).visible = n == name
	var changed := name != view or mirror != mirrored
	view = name
	mirrored = mirror
	rig = views[name]
	if changed:
		view_changed.emit(view, mirrored)
