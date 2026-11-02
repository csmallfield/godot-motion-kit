# SPDX-License-Identifier: Apache-2.0
## A cutout character seen from a fixed game camera: several views of the
## same rig (MotionCutoutRig each), one shown at a time, picked from the
## facing direction, with a paper turn between them (the card's width springs
## toward edge-on and the view swaps while it is narrow).
## Each view sits at a facing angle: 0 sideways (the art faces right), +90
## toward the camera, -90 away. Mirroring covers the left half, so three
## views (front, side, back) give 4 directions and five (adding front_34 at
## +45 and back_34 at -45) give 8. Views named front, front_34, side,
## back_34 and back get those angles by default; any other name passes one.
##
##   var cut := MotionCutout.new()
##   cut.add_view(&"front", front_rig); cut.add_view(&"back", back_rig); cut.add_view(&"side", side_rig)
##   cut.add_view(&"front_34", f34_rig); cut.add_view(&"back_34", b34_rig)    # optional: 8 directions
##   cut.lean(camera_pitch_deg, 20.0)
##   cut.face(Vector2(move.x, move.z))      # world x, z (+z toward the camera)
##   cut.step(clock.dt)
##   cut.rig.solve_limb(...)                # pose the view that's showing
##
## A turn between neighbouring views narrows the card in proportion to the
## angle between them (to edge-on for 90 degrees, halfway for 45), so an
## 8-direction turn is a small flick rather than a full flip.
##
## Which way a view faces, and whether it mirrors (add_view's `side`):
##   MIRROR  drawn facing right, mirrored for the left (the default)
##   RIGHT   drawn facing right, used only when facing right
##   LEFT    drawn facing left, used only when facing left (a separate
##           drawing, or MotionSvgData.mirrored() of the right one: the
##           partial mirror that keeps a sword in the same hand)
##   EITHER  never mirrored, used on both sides (front and back views of a
##           character with a fixed sword hand)
##
##   cut.add_view(&"front", front_rig, NAN, MotionCutout.EITHER)
##   cut.add_view(&"side", side_rig, NAN, MotionCutout.RIGHT)
##   cut.add_view(&"side_left", MotionCutoutRig.build(side_data.mirrored(), ...), 0.0, MotionCutout.LEFT)
##
## A turn between a RIGHT and a LEFT view narrows edge-on, like a mirror flip.
##
## Many views means many part meshes: build them with one actor material per
## character (MotionFlat3D.actor), not the shared cutout() material, whose
## per-instance uniforms each hold a block of a global buffer (the
## Compatibility renderer runs out at a few hundred meshes).
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

enum { MIRROR, RIGHT, LEFT, EITHER }

## Default facing angles (degrees) for the usual view names.
const ANGLES := {&"front": 90.0, &"front_34": 45.0, &"side": 0.0, &"back_34": -45.0, &"back": -90.0}

## Name -> MotionCutoutRig.
var views := {}
## Name -> facing angle in degrees (0 sideways, +90 toward the camera).
var angles := {}
## Name -> MIRROR, RIGHT, LEFT or EITHER.
var sides := {}
## True while the character faces left (whatever the view does about it).
var left := false
## Views left out of the choice (switch 8 directions down to 4 at runtime).
var disabled := {}
## The view showing now, and whether it is mirrored.
var view: StringName = &""
var mirrored := false
var rig: MotionCutoutRig
## Paper turn spring (the card's width); off = instant swaps.
var paper_turn := true
var turn := MotionSpring.new(1.0, 16.0, 420.0)
## Degrees of hysteresis around the borders between views.
var hysteresis := 12.0
## Shear the card so depth along it has no screen parallax (see lean()).
var shear_depth := true
## The card holder (lean, stretch and shear); views hang below `flip`.
var card: Node3D
var flip: Node3D

var _pitch := 50.0
var _want_view: StringName = &""
var _want_mirror := false


func _init() -> void:
	card = Node3D.new()
	card.name = "Card"
	add_child(card)
	flip = Node3D.new()
	flip.name = "Flip"
	card.add_child(flip)


## Add a view (the first one added shows first) at a facing angle in
## degrees (NAN takes the default for its name, ANGLES) and a `side`
## (MIRROR, RIGHT, LEFT or EITHER: see above).
func add_view(name: StringName, r: MotionCutoutRig, angle_deg := NAN, side := MIRROR) -> void:
	views[name] = r
	angles[name] = angle_deg if not is_nan(angle_deg) else float(ANGLES.get(name, 0.0))
	sides[name] = side
	flip.add_child(r)
	r.visible = false
	if view == &"":
		_show(name, false)
		_want_view = name


## Tilt the cards back toward a camera pitched `pitch_deg` below the horizon.
## With `shear_depth` the card is also sheared so depth along the card
## (part layers, MotionCutoutRig.depth, props hung in front) lands on the
## same screen point at any depth: without it a part 0.1 m forward shows
## 0.05 m lower at pitch 50 and lean 20 (sin(pitch - lean) per metre).
func lean(pitch_deg: float, lean_deg := 20.0) -> void:
	_pitch = pitch_deg
	var l := deg_to_rad(lean_deg)
	var gap := deg_to_rad(pitch_deg) - l
	var stretch := Basis.from_scale(Vector3(1, 1.0 / maxf(cos(gap), 0.2), 1))
	var shear := Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, sin(gap) if shear_depth else 0.0, 1))
	card.transform = Transform3D(Basis(Vector3.RIGHT, -l) * stretch * shear, card.position)


## A world offset from the character (x and z on the ground, y up) as the
## card-plane offset that lands on the same screen point in the view showing
## (x mirrored with the view, y up the screen): world foot positions from a
## MotionGait become IK targets this way. Uses the pitch given to lean().
func ground_to_card(offset: Vector3) -> Vector3:
	var p := deg_to_rad(_pitch)
	return Vector3(offset.x * (-1.0 if mirrored else 1.0), -offset.z * sin(p) + offset.y * cos(p), 0.0)


## Face a direction (world x, z; +z toward the camera). A zero vector keeps
## the current facing.
func face(dir: Vector2) -> void:
	if dir.length_squared() < 1e-6:
		return
	if absf(dir.x) > 1e-3:
		left = dir.x < 0.0
	var usable := {}
	for n in angles:
		var sd: int = sides.get(n, MIRROR)
		if not disabled.has(n) and not (sd == RIGHT and left) and not (sd == LEFT and not left):
			usable[n] = angles[n]
	if usable.is_empty():
		usable = angles
	var v := nearest(dir, usable, _want_view, hysteresis)
	if not views.has(v):
		v = views.keys()[0]
	_want_view = v
	_want_mirror = left and int(sides.get(v, MIRROR)) == MIRROR
	if not paper_turn:
		_show(_want_view, _want_mirror)


## The view whose angle is nearest the facing (`dir`: world x, z, +z toward
## the camera; left and right fold together, mirroring covers the left). The
## current view keeps `hyst` extra degrees past each border, so diagonals
## don't flicker (keep it under half the spacing between views).
static func nearest(dir: Vector2, view_angles: Dictionary, current: StringName, hyst := 12.0) -> StringName:
	var a := facing_angle(dir)
	var best: StringName = &""
	var best_d := INF
	for n: StringName in view_angles:
		var d := absf(a - float(view_angles[n])) - (2.0 * hyst if n == current else 0.0)
		if d < best_d:
			best_d = d
			best = n
	return best


## A facing as a view angle: 0 sideways, +90 toward the camera, -90 away.
static func facing_angle(dir: Vector2) -> float:
	return rad_to_deg(atan2(dir.y, absf(dir.x)))


## The three-view choice (front, side, back), kept for existing callers:
## "side" in the left and right sectors, "front" toward the camera, "back"
## away; the current view keeps an extra `hyst` degrees.
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
		var narrow := narrow_for(float(angles.get(view, 0.0)), float(angles.get(_want_view, 0.0)))
		if _facing(view, mirrored) * _facing(_want_view, _want_mirror) < 0:
			narrow = 0.0                # right-facing to left-facing drawings: a full turn
		turn.target = want_sign if crossing else want_sign * narrow
		turn.step(dt)
		if absf(turn.value) < narrow + 0.15 or (crossing and signf(turn.value) == want_sign):
			_show(_want_view, _want_mirror)
	else:
		turn.target = want_sign
		turn.step(dt)
	flip.scale = Vector3(turn.value, 1, 1)


## +1 for a view showing a right-facing character, -1 left, 0 either.
func _facing(name: StringName, flipped: bool) -> int:
	match int(sides.get(name, MIRROR)):
		RIGHT:
			return 1
		LEFT:
			return -1
		EITHER:
			return 0
	return -1 if flipped else 1


## How narrow the card gets on a same-side turn between views `from` and
## `to` (degrees): 0 (edge-on) for 90 degrees or more, 0.5 for 45.
static func narrow_for(from_deg: float, to_deg: float) -> float:
	return clampf(1.0 - absf(to_deg - from_deg) / 90.0, 0.0, 1.0)


func _show(name: StringName, mirror: bool) -> void:
	for n in views:
		(views[n] as MotionCutoutRig).visible = n == name
	var changed := name != view or mirror != mirrored
	view = name
	mirrored = mirror
	rig = views[name]
	if changed:
		view_changed.emit(view, mirrored)
