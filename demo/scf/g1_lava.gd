# SPDX-License-Identifier: Apache-2.0
# G1 — LAVA LAMP, ported from scf-intros src/intros/G1_Lava.tsx.
# Goo slowed right down. Blobs drift up and down a blue lamp, break apart and
# pour into the M; the wordmark floats up underneath like wax rising. Then a
# dark blob rises from below and swallows the frame. In the dark, blue, amber
# and red wax rises, gathers into the S, C and F discs, buds off the nodes and
# holds while the lamp keeps going behind it. At the end the wax lets go and
# floats up out of frame.
@tool
extends MotionComposition

const OUT := 350
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const M_W := 400.0
const M_K := M_W / 120.63
const M_X := 960.0 - M_W / 2.0
const M_Y := 100.0

var _built := false
var _pts: Array[Vector2] = []
var _g: Dictionary
var _bg: ColorRect
var _b1: Node2D
var _m_goo: Array = []
var _crisp1: Node2D
var _word1: MotionSvg
var _presents: MotionText
var _swallow: Dictionary
var _b2: Node2D
var _amb: Array = []
var _wax: Array = []
var _crisp2: MotionSvg
var _words: MotionSvg
var _tag_presents: MotionText
var _pills: Node2D
var _pill: Array[MotionPill] = []


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


## One wax blob's lazy path up and down the lamp.
static func _lava(f: float, i: float, spread := 1.0) -> Vector3:
	return Vector3(960 + sin(i * 2.3) * 560 * spread + sin(f / 70.0 + i) * 90,
		560 + sin(f / 52.0 + i * 1.7) * 470 + sin(f / 23.0 + i * 3.1) * 40,
		46 + 52 * MK.rand(i * 3.7) + sin(f / 30.0 + i) * 10)


func _build() -> void:
	_built = true
	_pts = GooKit.m_points(10)
	_g = GooKit.scf_geom(1500, 210, 300)
	_bg = PrintKit.rect(self, Rect2(0, 0, 1920, 1080), SCFBrand.BLUE)

	# ---- beat 1: wax -> M
	_b1 = Node2D.new()
	add_child(_b1)
	for L in 3:
		_m_goo.append(GooKit.goo(_b1, GooKit.M_LAYER_COL[L], 18))
	_crisp1 = GooKit.m_mono(_b1, M_X, M_Y, M_W * GooKit.M_VIEW)
	_word1 = MotionSvg.new()
	_word1.data = SCFBrand.logo("mhFull")
	_word1.width = 820
	_word1.crop = Rect2(140, 0, 345.7, 128.89)
	_word1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_word1.position = Vector2(960 - 410, 560)
	_b1.add_child(_word1)
	_presents = MotionText.new()
	_presents.font = SCFBrand.font("outfit", 800)
	_presents.font_size = 34
	_presents.tracking = 0.6
	_presents.color = SCFBrand.AMBER
	_presents.text = "PRESENTS"
	_presents.align = HORIZONTAL_ALIGNMENT_CENTER
	_presents.box_width = 1920
	_b1.add_child(_presents)
	_swallow = GooKit.goo(_b1, INK, 30)

	# ---- beat 2: wax -> discs
	_b2 = Node2D.new()
	add_child(_b2)
	for k in 3:
		_amb.append(GooKit.goo(_b2, GooKit.DISC_COLS[k], 22))
	for k in 3:
		_wax.append(GooKit.goo(_b2, GooKit.DISC_COLS[k], 18))
	var full := SCFBrand.logo("scfFull")
	_crisp2 = MotionSvg.new()
	_crisp2.data = full
	_crisp2.width = _g.S_W
	_crisp2.position = Vector2(_g.S_X, _g.S_Y)
	_b2.add_child(_crisp2)
	_words = MotionSvg.new()
	_words.data = full
	_words.width = _g.S_W
	_words.only = PackedInt32Array(_g.words)
	_words.position = Vector2(_g.S_X, _g.S_Y)
	_b2.add_child(_words)
	_tag_presents = MotionText.new()
	_tag_presents.font = SCFBrand.font("outfit", 800)
	_tag_presents.font_size = 28
	_tag_presents.tracking = 0.32
	_tag_presents.color = SCFBrand.AMBER
	_tag_presents.text = "MINIMAL HUMANS PRESENTS"
	_tag_presents.position = Vector2(_g.S_X + 110 * _g.S_K, _g.S_Y - 64)
	_b2.add_child(_tag_presents)
	# 1.0 / OPEN FORMAT: flex, gap 14; padding 6px 18px, radius 40
	_pills = Node2D.new()
	_pills.position = Vector2(_g.S_X + 110 * _g.S_K, _g.S_Y + 90 * _g.S_K)
	_b2.add_child(_pills)
	var x := 0.0
	for k in 2:
		var p := MotionPill.new()
		p.font = SCFBrand.font("outfit", 800)
		p.font_size = 26
		p.padding = Vector2(18, 6)
		p.corner_radius = 40
		p.background = [SCFBrand.RED, SCFBrand.BLUE][k]
		p.text_color = CREAM
		p.text = ["1.0", "OPEN FORMAT"][k]
		var sz := p.get_box_size()
		p.position = Vector2(x, 0) + sz * 0.5
		p.set_meta("y", sz.y * 0.5)
		x += sz.x + 14
		_pills.add_child(p)
		_pill.append(p)


# ------------------------------------------------------------------ frame

func _rise(f: float, k: int, at: float) -> float:
	return (1.0 - MK.map(f, [at, at + 40 + (k % 5) * 6], [0, 1], MK.ease_in_out)) * 900


func _frame(f: float) -> void:
	if not _built:
		return
	var b1 := f < 172
	_bg.color = SCFBrand.BLUE if b1 else INK
	_b1.visible = b1
	_b2.visible = not b1
	if b1:
		_frame_b1(f)
	else:
		_frame_b2(f)


func _frame_b1(f: float) -> void:
	var shrink1 := MK.map(f, [112, 124], [0, 1])
	for L in 3:
		var off: Vector2 = GooKit.M_LAYER_OFF[L]
		var blobs := []
		for i in _pts.size():
			var w := _lava(f, i + L * 7, 0.9)
			var gi := i + L * 5
			var t := MK.map(f, [40 + (gi % 19) * 1.2, 84 + (gi % 19) * 1.2], [0, 1], MK.ease_in_out)
			var tp := Vector2(M_X, M_Y) + (_pts[i] + off) * M_K
			blobs.append(Vector3(lerpf(w.x, tp.x, t), lerpf(w.y + _rise(f, i, 0), tp.y, t),
				lerpf(w.z * 0.55, 10 * M_K * 0.7, t) * (1 - shrink1)))
		GooKit.set_blobs(_m_goo[L], blobs)

	var crisp1 := MK.map(f, [108, 116], [0, 1])
	_crisp1.visible = crisp1 > 0.0
	_crisp1.modulate.a = crisp1
	_crisp1.scale = Vector2.ONE * (1 + 0.03 * sin(f / 14.0))

	_word1.visible = f >= 112
	if _word1.visible:
		var letters: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
		_word1.apply(func(i: int):
			var k := letters.find(i)
			var at := 112 + k * 1.2
			if f < at:
				return {hide = true}
			var s := GooKit.wob(f, at, 0.8, 4)
			return {ty = (1 - s) * 70, o = MK.map(f, [at, at + 6], [0, 1]), fill = CREAM})

	_presents.modulate.a = MK.map(f, [128, 138], [0, 1])
	_presents.position = Vector2(0, 900 + (1 - GooKit.wob(f, 128, 0.5, 6)) * 40)

	var sw := MK.interp(f, [142, 172], [0, 1], func(t: float) -> float: return t * t)
	_swallow.fx.visible = sw > 0.0
	if sw > 0.0:
		var blobs := [Vector3(960, 1500, lerpf(0, 1900, sw))]
		for j in 6:
			blobs.append(Vector3(200 + j * 300, lerpf(1300, 300, sw) + sin(j * 2 + f / 6.0) * 120, lerpf(60, 600, sw)))
		GooKit.set_blobs(_swallow, blobs)


func _frame_b2(f: float) -> void:
	var o := f - OUT
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var crisp2 := MK.map(f, [236, 244], [0, 1]) * (1 - MK.map(o, [0, 6], [0, 1]))
	var amb_o := 0.22 * MK.map(f, [236, 260], [0, 1]) * (1 - MK.map(o, [0, 20], [0, 1]))
	for k in 3:
		# ambient wax behind
		var blobs := []
		for j in 4:
			var w := _lava(f * 0.7, j * 5 + k * 13 + 40, 1.1)
			blobs.append(Vector3(w.x, w.y, w.z * 0.6))
		GooKit.set_blobs(_amb[k], blobs)
		_amb[k].fx.modulate.a = amb_o
		_amb[k].fx.visible = amb_o > 0.0
		# the disc's wax
		var d: Dictionary = _g.discs[k]
		var let_go := MK.interp(o, [2 + k * 5, 50 + k * 5], [0, 1], func(t: float) -> float: return t * t)
		var t := MK.map(f, [196 + k * 6, 232 + k * 6], [0, 1], MK.ease_in_out)
		blobs = []
		for j in 8:
			var w := _lava(f, j * 3 + k * 11, 0.8)
			var up := let_go * (1400 + 300 * MK.rand(j + k))
			var drift := let_go * sin(j * 1.9) * 260
			blobs.append(Vector3(lerpf(w.x, d.x, t) + drift, lerpf(w.y + _rise(f, j, 172), d.y, t) - up,
				lerpf(w.z * 0.8, d.r if j == 0 else d.r * 0.55, t) * (0.0 if f < 176 else 1.0)))
		for i in _g.nodes.size():
			var n: Dictionary = _g.nodes[i]
			if n.col != GooKit.DISC_COLS[k]:
				continue
			var tn: float = sp.call(238 + i * 2, 12, 90)
			blobs.append(Vector3(lerpf(d.x, n.x, tn), lerpf(d.y, n.y, tn) - let_go * (1200 + 200 * MK.rand(i)),
				n.r * 1.1 if f >= 236 else 0.0))
		GooKit.set_blobs(_wax[k], blobs)
		_wax[k].fx.modulate.a = 1.0 - crisp2

	var F: Dictionary = SCFBrand.SCF_FULL
	var words: Array = _g.words
	_crisp2.visible = crisp2 > 0.0
	_crisp2.modulate.a = crisp2
	if _crisp2.visible:
		_crisp2.apply(func(i: int):
			if i == F.cloud or words.has(i):
				return {hide = true}
			var di := 0 if (F.S as Array).has(i) else (1 if (F.C as Array).has(i) else (2 if (F.F as Array).has(i) else -1))
			if di >= 0:
				var s: float = sp.call(240 + di * 4, 9, 160)
				return {hide = true} if s <= 0.01 else {s = s}
			if (F.edges as Array).has(i):
				return {s = MK.map(f, [244, 258], [0, 1]), pivot = Vector2(52.8, 43.4), fill = CREAM}
			var w := [F.discS, F.discC, F.discF].find(i)
			if w >= 0:
				var b := sin(f / 16.0 + w * 2) * 0.015
				return {sx = 1 + b, sy = 1 - b}
			return null)
	_words.apply(func(i: int):
		var k := words.find(i)
		var at := 250 + k * 1.1
		if f < at:
			return {hide = true}
		var s := GooKit.wob(f, at, 0.8, 4)
		var away := pow(maxf(0.0, o - 4 - k * 0.6) / 14.0, 2) * 400 if o > 0 else 0.0
		return {ty = (1 - s) * 70 - away, fill = CREAM,
			o = MK.map(f, [at, at + 6], [0, 1]) * (1 - MK.map(o, [10 + k * 0.6, 30 + k * 0.6], [0, 1]))})
	var fade := 1 - MK.map(o, [0, 10], [0, 1])
	_tag_presents.modulate.a = MK.map(f, [276, 288], [0, 1]) * fade
	_pills.modulate.a = MK.map(f, [282, 292], [0, 1]) * fade
	for k in 2:
		_pill[k].position.y = float(_pill[k].get_meta("y")) + (1 - GooKit.wob(f, 282 + k * 4, 0.6, 6)) * 30
