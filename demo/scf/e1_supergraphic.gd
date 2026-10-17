# SPDX-License-Identifier: Apache-2.0
# E1 — SUPERGRAPHIC, ported line for line from scf-intros/src/intros/E1_Supergraphic.tsx.
# The M springs in, the wordmark draws itself, SCF builds, holds with the nodes
# breathing, and unbuilds in reverse to an empty cream frame.
@tool
extends MotionComposition

const SCF_T0 := 160.0
const OUT := 345.0


var _mh_layer: Node2D
var _scf_layer: Node2D
var _bg: ColorRect
var _wipe_blue: MotionShape
var _red_disc: MotionShape
var _amber_disc: MotionShape
var _wipe_amber: MotionShape
var _wipe_red: MotionShape
var _wipe_cream: MotionShape
var _scf_bg: ColorRect
var _shapes: Array[MotionShape] = []
var _mh: MHLockup
var _scf: SCFLockup


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _mh_layer:
		_build()
		# Keep the scene's own children (the Sound player) above nothing visual.
	super._ready()


func _build() -> void:
	_bg = _rect(self, SCFBrand.AMBER)
	_mh_layer = Node2D.new(); add_child(_mh_layer)
	_wipe_blue = MotionShape.new(); _mh_layer.add_child(_wipe_blue)
	_red_disc = MotionShape.new(); _mh_layer.add_child(_red_disc)
	_amber_disc = MotionShape.new(); _mh_layer.add_child(_amber_disc)
	_mh = MHLockup.new(); _mh.t0 = 4; _mh_layer.add_child(_mh)
	_wipe_amber = MotionShape.new(); _mh_layer.add_child(_wipe_amber)
	_wipe_red = MotionShape.new(); _mh_layer.add_child(_wipe_red)
	_wipe_cream = MotionShape.new(); _mh_layer.add_child(_wipe_cream)

	_scf_layer = Node2D.new(); add_child(_scf_layer)
	_scf_bg = _rect(_scf_layer, SCFBrand.CREAM)
	for i in 3:
		var s := MotionShape.new(); _scf_layer.add_child(s); _shapes.append(s)
	_scf = SCFLockup.new()
	_scf.t0 = SCF_T0
	_scf.out_at = OUT
	_scf.tags = PackedStringArray(SCFLockup.TAGS_FEATURE)
	_scf_layer.add_child(_scf)


func _rect(parent: Node, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(SCFBrand.W, SCFBrand.H)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _frame(f: float) -> void:
	if not _mh_layer:
		return
	var drift := func(k: float) -> float: return sin(f / 40.0 + k) * 6.0
	var shape_out := func(k: float) -> float: return 1.0 - MK.map(f, [OUT + 46 + k * 4, OUT + 58 + k * 4], [0, 1], MK.ease_in_back)

	# MH on blue
	_mh_layer.visible = f < 170
	SCFBrand.circle_wipe(_wipe_blue, f, 2, 960, 540, SCFBrand.BLUE, 12)
	SCFBrand.disc(_red_disc, SCFBrand.W - 140 - drift.call(1.0) - 110, 110, 110, SCFBrand.RED, SCFBrand.sp(f, 112, 9, 150))
	SCFBrand.disc(_amber_disc, -260, SCFBrand.H - (-260 + drift.call(2.0)) - 560, 560, SCFBrand.AMBER, SCFBrand.sp(f, 118, 12, 90))
	SCFBrand.circle_wipe(_wipe_amber, f, 146, 0, 1080, SCFBrand.AMBER)
	SCFBrand.circle_wipe(_wipe_red, f, 151, 1920, 0, SCFBrand.RED)
	SCFBrand.circle_wipe(_wipe_cream, f, 156, 960, 540, SCFBrand.CREAM, 10)

	# SCF on cream
	_scf_layer.visible = f >= 166
	SCFBrand.disc(_shapes[0], SCFBrand.W + 520 - 900, SCFBrand.H - (-560 + drift.call(3.0)) - 900, 900, SCFBrand.BLUE, SCFBrand.sp(f, 162, 12, 90) * shape_out.call(0.0))
	SCFBrand.disc(_shapes[1], -240 + drift.call(4.0), -240, 560, SCFBrand.AMBER, SCFBrand.sp(f, 166, 12, 90) * shape_out.call(1.0))
	SCFBrand.disc(_shapes[2], SCFBrand.W - 120 - 120, 90 + drift.call(5.0), 120, SCFBrand.RED, SCFBrand.sp(f, 172, 8, 160) * shape_out.call(2.0))
