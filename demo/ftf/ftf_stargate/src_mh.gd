# SPDX-License-Identifier: Apache-2.0
# Content for act I, seen through MotionTimeSlices (columns): the Minimal Humans
# lockup on a transparent background, rising into place through the centre
# slit (the column delays turn the rise into time-stretched arches), PRESENTS
# whipping in, a vertical jolt on each kick (the time ripples bend it into a
# wave), then sinking back toward the slit. Global timeline (a nested
# composition with start = the band's delay); accepts negative frames.
@tool
extends MotionComposition

const L := preload("res://demo/ftf/ftf_stargate/stargate_look.gd")
const MH_W := 1060.0
const TOP := 128.0

var _built := false
var _box: Node2D
var _svg: MotionSvg
var _k := 1.0
var _rule: MotionCanvas
var _presents: MotionText
var _jp: MotionText


func _init() -> void:
	duration = 100000
	autoplay = false
	hide_outside = false


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _build() -> void:
	_built = true
	_box = Node2D.new()
	add_child(_box)
	_svg = MotionSvg.new()
	var path := "res://demo/assets/logos/mh_logoFull_standard.svg"
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	_svg.data = res if res is MotionSvgData else MotionSvgData.from_file(path)
	_svg.width = MH_W
	_box.add_child(_svg)
	_k = MH_W / _svg.data.view_box.size.x
	var px := 145.0 * _k
	var py := 128.9 * _k
	_rule = MotionCanvas.new()
	_rule.draw_fn = func(c: MotionCanvas, f: float) -> void:
		var rw := MK.map(f, [L.PRESENTS_AT - 2, L.PRESENTS_AT + 8], [0, MH_W - px], MK.ease_out)
		if rw > 0.0:
			c.rect(Rect2(px, py + 24.0, rw, 6.0), FTFKit.MH_AMBER)
	_box.add_child(_rule)
	_presents = FTFKit.text(_box, "heavy", 50, FTFKit.MH_CREAM, "PRESENTS", 0.5)
	_presents.position = Vector2(px, py + 44)
	_jp = FTFKit.text(_box, "jp", 26, FTFKit.MH_AMBER, "ミニマル・ヒューマンズ　提供")
	_jp.position = Vector2(maxf(MH_W - _jp.get_text_size().x, px + _presents.get_text_size().x + 40.0), py + 56)


## Vertical offset: up out of the board into place on the snap, back down on the fold.
static func rise(f: float) -> float:
	var y := MK.map(f, [L.POUR_MH - 4.0, L.MH_SNAP], [760.0, 0.0], MK.bezier(0.2, 0.0, 0.1, 1.0))
	y += MK.map(f, [L.MH_FOLD, L.GATE], [0.0, 640.0], MK.ease_in_quad)
	y += L.decay_kick(f, L.MH_KICKS, 34.0, 0.32)
	return y


func _frame(f: float) -> void:
	if not _built:
		return
	_box.position = Vector2(960.0 - MH_W * 0.5, TOP + rise(f))
	_box.visible = f < L.GATE + 2.0
	var w := MK.map(f, [L.PRESENTS_AT, L.PRESENTS_AT + 6], [1400, 0], MK.ease_out)
	_presents.position.x = 145.0 * _k + w
	_presents.visible = f >= L.PRESENTS_AT
	_jp.visible_chars = int(MK.map(f, [L.PRESENTS_AT + 8, L.PRESENTS_AT + 16], [0, 14], MK.linear))
