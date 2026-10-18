# SPDX-License-Identifier: Apache-2.0
# G5 — GOO PILE, ported from scf-intros src/intros/G5_GooType.tsx.
# The logos themselves are the goo. Every part of the Minimal Humans lockup
# drops into one sticky heap, a single wobbling multicoloured mass, then pulls
# apart into place as the goo sets and goes crisp. The blue frame slumps away
# like jelly. Every part of the SCF lockup, discs, letters, nodes, lines and
# words, pours in from above into a second heap, jiggles, and pulls apart into
# the lockup. At the end the goo comes back, it all slumps into a puddle and
# drains off the bottom.
@tool
extends MotionComposition

const OUT := 350
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const MH := Vector2(210, 300)
const MH_W := 1500.0
const SC := Vector2(180, 300)
const SC_W := 1560.0
const PAD := 64.0

var _built := false
var _mh_k := 1.0
var _sc_k := 1.0
var _mh_parts: Array = []    # [index, centre (logo units)]
var _sc_parts: Array = []
var _sc_word_set := {}
var _b1: Node2D
var _frame_fill: MotionCanvas
var _goo1: MotionFX
var _mh: MotionSvg
var _letters: Array[Node2D] = []
var _b2: Node2D
var _goo2: MotionFX
var _sc: MotionSvg
var _pills: Array[MotionPill] = []


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


static func _parts(d: MotionSvgData, only: Array) -> Array:
	var out := []
	for i in only:
		out.append([i, (d.parts[i].bbox as Rect2).get_center()])
	return out


## Where a part is: dropped from above into a heap at (hx, hy) px, wobbling
## there, then pulled to its home. Returns a MotionSvg part override.
static func _pile(f: float, p: Array, k: int, n: int, origin: Vector2, K: float, drop_at: float, sep_at: float, slump_at: float) -> Dictionary:
	var c: Vector2 = p[1]
	var q := float(k) / n
	var hx := (960 - origin.x) / K + (MK.rand(k * 3.1) - 0.5) * 520 / K * (0.4 + 0.6 * q)
	var hy := (800 - origin.y) / K - q * 260 / K + (MK.rand(k * 7.7) - 0.5) * 60 / K
	var top := (-260 - origin.y) / K
	var at := drop_at + q * 26
	var fall := minf(1.0, maxf(0.0, (f - at) / 11))
	var x := hx
	var y := lerpf(top, hy, fall * fall)
	var t := f - at - 11
	if t > 0:
		y += exp(-t / 6) * sin(t * 0.9) * 30 / K                  # the heap jiggles
	var sep := SCFBrand.sp(f, sep_at + q * 14, 12, 90)
	x = lerpf(x, c.x, sep)
	y = lerpf(y, c.y, sep)
	var rot := (MK.rand(k * 5.3) - 0.5) * 140 * (1 - sep)
	# slump: back into a puddle and down the drain
	var sl := MK.map(f, [slump_at + (1 - q) * 10, slump_at + 24 + (1 - q) * 10], [0, 1], MK.ease_in_out)
	var drain := pow(MK.map(f, [slump_at + 30, slump_at + 60], [0, 1]), 2) * 900 / K
	x = lerpf(x, hx, sl)
	y = lerpf(y, hy + 80 / K, sl) + drain
	if f < at:
		return {hide = true}
	return {tx = x - c.x, ty = y - c.y, rot = rot + (MK.rand(k) - 0.5) * 60 * sl, s = 0.8 if f < at + 4 else 1.0}


## The GooFilterDef: blur, alpha * 22 - 9.9, the source atop it. Below 0.4 px
## the filter is off.
static func _set_goo(fx: MotionFX, blur: float) -> void:
	var on := blur > 0.4
	fx.blur = maxf(0.01, blur) if on else 0.0
	fx.alpha_matrix = Vector2(22, -22 * 0.45) if on else Vector2(1, 0)
	fx.source_atop = on


func _goo_fx(parent: Node) -> MotionFX:
	var fx := MotionFX.new()
	fx.size = Vector2(1920, 1080) + Vector2(PAD, PAD) * 2
	fx.position = -Vector2(PAD, PAD)
	parent.add_child(fx)
	return fx


func _build() -> void:
	_built = true
	var mh := SCFBrand.logo("mhFull")
	var full := SCFBrand.logo("scfFull")
	_mh_k = MH_W / mh.view_box.size.x
	_sc_k = SC_W / full.view_box.size.x
	_mh_parts = _parts(mh, SCFBrand.MH_FULL_M + SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	var F: Dictionary = SCFBrand.SCF_FULL
	var all := []
	for i in full.parts.size():
		if i != F.cloud:
			all.append(i)
	_sc_parts = _parts(full, all)
	for i in F.story + F.context + F.framework:
		_sc_word_set[i] = true
	PrintKit.rect(self, Rect2(0, 0, 1920, 1080), CREAM)

	# ---- beat 1: the blue frame (it slumps away like jelly)
	_b1 = Node2D.new()
	add_child(_b1)
	_frame_fill = MotionCanvas.new()
	_b1.add_child(_frame_fill)
	_frame_fill.draw_fn = func(c: MotionCanvas, f: float) -> void:
		var r := MK.interp(f, [140, 168], [0, 1], func(t: float) -> float: return t * t) * 900
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(1920, 0)])
		var seg := 48
		for s in seg + 1:   # bottom-right corner
			var a := float(s) / seg * PI * 0.5
			pts.append(Vector2(1920 - r + cos(a) * r, 1080 - r + sin(a) * r))
		for s in seg + 1:   # bottom-left corner
			var a := PI * 0.5 + float(s) / seg * PI * 0.5
			pts.append(Vector2(r + cos(a) * r, 1080 - r + sin(a) * r))
		c.polygon(pts, SCFBrand.BLUE, Color(0, 0, 0, 0))
	_goo1 = _goo_fx(_b1)
	_mh = MotionSvg.new()
	_mh.data = mh
	_mh.width = MH_W
	_mh.position = MH + Vector2(PAD, PAD)
	_goo1.content.add_child(_mh)
	# PRESENTS: a flex row of inline-block letters, each transformed about its centre
	var x := MH.x + 145 * _mh_k
	var y := MH.y + 129 * _mh_k + 40
	for k in 8:
		var t := MotionText.new()
		t.font = SCFBrand.font("outfit", 900)
		t.font_size = 52
		t.tracking = 0.42
		t.color = SCFBrand.AMBER
		t.text = "PRESENTS"[k]
		var sz := t.get_text_size()
		var piv := Node2D.new()
		piv.position = Vector2(x, y) + sz * 0.5
		t.position = -sz * 0.5
		piv.add_child(t)
		_b1.add_child(piv)
		_letters.append(piv)
		x += sz.x

	# ---- beat 2
	_b2 = Node2D.new()
	add_child(_b2)
	_goo2 = _goo_fx(_b2)
	_sc = MotionSvg.new()
	_sc.data = full
	_sc.width = SC_W
	_sc.position = SC + Vector2(PAD, PAD)
	_goo2.content.add_child(_sc)
	var px := SC.x + 110 * _sc_k
	for k in 3:
		var p := MotionPill.new()
		p.font = SCFBrand.font("outfit", 800)
		p.font_size = 24
		p.tracking = 0.12
		p.padding = Vector2(16, 7)
		p.corner_radius = 30
		p.background = [INK, SCFBrand.BLUE, SCFBrand.RED][k]
		p.text_color = CREAM
		p.text = ["MINIMAL HUMANS PRESENTS", "OPEN FORMAT", "1.0"][k]
		var sz := p.get_box_size()
		p.position = Vector2(px, SC.y - 66) + sz * 0.5
		px += sz.x + 12
		_b2.add_child(p)
		_pills.append(p)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var o := f - OUT
	var b1 := f < 170
	_b1.visible = b1
	_b2.visible = not b1
	if b1:
		var blur1 := MK.map(f, [70, 104], [16, 0], MK.ease_in_out) + MK.map(f, [136, 150], [0, 18])
		var slump := MK.interp(f, [140, 168], [0, 1], func(t: float) -> float: return t * t)
		# translateY scaleY skewX about (50%, 0%)
		_b1.transform = Transform2D(0.0, Vector2(960, slump * 1200)) \
			* Transform2D(Vector2(1, 0), Vector2(0, 1 + slump * 0.3), Vector2.ZERO) \
			* Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(sin(f / 3) * slump * 6)), 1), Vector2.ZERO) \
			* Transform2D(0.0, Vector2(-960, 0))
		_set_goo(_goo1, blur1)
		var n := _mh_parts.size()
		var idx := {}
		for k in n:
			idx[_mh_parts[k][0]] = k
		_mh.apply(func(i: int):
			if not idx.has(i):
				return {hide = true}
			var k: int = idx[i]
			return _pile(f, _mh_parts[k], k, n, MH, _mh_k, 6, 76, 9999))
		for k in 8:
			var s := SCFBrand.sp(f, 112 + k * 1.6, 7, 200)
			var sy := maxf(0.0, s)
			_letters[k].visible = sy > 0.0
			_letters[k].scale = Vector2(1 + (1 - minf(1.0, s)) * 0.4, maxf(sy, 1e-4))
			_letters[k].get_child(0).position.y = -(_letters[k].get_child(0) as MotionText).get_text_size().y * 0.5
			_letters[k].position.y = MH.y + 129 * _mh_k + 40 + (_letters[k].get_child(0) as MotionText).get_text_size().y * 0.5 + (1 - s) * -80
	else:
		var blur2 := MK.map(f, [228, 262], [16, 0], MK.ease_in_out) + MK.map(o, [0, 16], [0, 18])
		_set_goo(_goo2, blur2)
		var n := _sc_parts.size()
		var idx := {}
		for k in n:
			idx[_sc_parts[k][0]] = k
		_sc.apply(func(i: int):
			if not idx.has(i):
				return {hide = true}
			var k: int = idx[i]
			var t := _pile(f, _sc_parts[k], k, n, SC, _sc_k, 172, 232, OUT)
			if not t.has("hide") and _sc_word_set.has(i):
				t.fill = INK
			return t)
		for k in 3:
			var s := SCFBrand.sp(f, 272 + k * 5, 7, 200) * (1 - MK.map(o, [k * 2, 8 + k * 2], [0, 1]))
			_pills[k].visible = s > 0.0
			_pills[k].scale = Vector2(maxf(s, 1e-4), maxf(1e-4, minf(1.2, s)))
