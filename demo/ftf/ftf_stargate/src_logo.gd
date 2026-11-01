# SPDX-License-Identifier: Apache-2.0
# Content for act III on a transparent background, seen through MotionTimeSlices
# (the pour and the outro) and MotionTimeSplit (the hold): the FTF logo, big,
# rising out of the board through the slit, kicking on the accents (the time
# split fringes only show on motion), bobbing slowly, then drifting up while
# the slit swallows it. An ink shadow under it keeps the white plate apart
# from the checks. Global timeline; accepts negative frames.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_stargate/stargate_look.gd")
const LOGO_W := 1480.0
const C := Vector2(960, 456)

var _built := false
var _pivot: Node2D
var _shadow: MotionSvg
var _logo: MotionSvg


func _init() -> void:
	duration = 100000
	autoplay = false
	hide_outside = false


func _ready() -> void:
	if not _built:
		_built = true
		_pivot = Node2D.new()
		add_child(_pivot)
		var data: MotionSvgData = load(FTFKit.LOGO)
		var origin := -data.view_box.size * (LOGO_W / data.view_box.size.x) * 0.5
		_shadow = MotionSvg.new()
		_shadow.data = data
		_shadow.width = LOGO_W
		_shadow.position = origin + Vector2(12, 16)
		_shadow.only = PackedInt32Array([FTFKit.PLATE])
		_shadow.modulate = Color(L.INK, 0.8)
		_pivot.add_child(_shadow)
		_logo = MotionSvg.new()
		_logo.data = data
		_logo.width = LOGO_W
		_logo.position = origin
		_pivot.add_child(_logo)
	super._ready()


static func offset(f: float) -> Vector2:
	var y := MK.map(f, [L.POUR - 4.0, L.UNFOLD + 10.0], [780.0, 0.0], MK.ease_out)
	var x := L.decay_kick(f, L.ACCENTS, 40.0, 0.42)
	if f > L.DROP:   # a slow bob on the bar, so the split has motion to bend
		y += 9.0 * sin((f - L.DROP) * TAU / L.BAR) * MK.map(f, [L.DROP, L.DROP + 10.0], [0, 1])
	y -= L.decay_kick(f, L.ACCENTS, 14.0, 0.42, false)
	if f > L.STRETCH:
		var t := (f - L.STRETCH) / 50.0
		y -= 260.0 * t * t
	return Vector2(x, y)


func _frame(f: float) -> void:
	if not _built:
		return
	_pivot.position = C + offset(f)
	var pop := 1.0 + 0.045 * L.accent(f, L.ACCENTS, 0.35) + 0.06 * exp(-maxf(f - L.DROP, 0.0) * 0.3) * float(f >= L.DROP)
	_pivot.scale = Vector2.ONE * pop
	_pivot.visible = _pivot.position.y < 1500.0 and _pivot.position.y > -500.0
