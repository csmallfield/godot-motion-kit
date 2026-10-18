# SPDX-License-Identifier: Apache-2.0
# G2 — SPLASH, ported from scf-intros src/intros/G2_Splash.tsx.
# Goo as poured paint. On black, three streams of paint pour into an M-shaped
# mould one colour at a time, red, then amber, then cream, filling it from the
# bottom up with a wobbling surface and a crown of spray where the stream lands.
# The letters splat on. A big cream drop falls and floods the frame; then a
# blue, an amber and a red drop land where the discs go, and the spray from each
# splash lands as that colour's nodes. At the end ink drips down from the top
# and covers everything.
@tool
extends MotionComposition

const OUT := 352
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const M_W := 470.0
const M_K := M_W / 120.63
const M_X := 250.0
const M_Y := 300.0
const FILL := [[8, 50], [38, 80], [68, 110]]   # pour windows per layer: red, amber, cream
const IMPACT := [178, 190, 202]
const MH_X := 790.0
const MH_K := 1000.0 / 345.7
const MH_Y := 300.0 + (470.0 - 1000.0 * 128.89 / 345.7) / 2.0

var _built := false
var _pts: Array[Vector2] = []
var _g: Dictionary
var _mh_letters: Array = []
var _mh_c: Array = []       # [Vector3(x, y, r)] per letter
var _scf_c: Array = []
var _bg: ColorRect
var _b1: Node2D
var _pour: Array = []
var _crisp1: MotionSvg
var _splat1: Dictionary
var _word1: MotionSvg
var _presents: MotionText
var _drop: Dictionary
var _b2: Node2D
var _disc_goo: Array = []
var _crisp2: MotionSvg
var _splat2: Dictionary
var _words: MotionSvg
var _pills: Array[MotionPill] = []
var _drip: Dictionary
var _cover: ColorRect


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


## Spray from an impact at (x, y) starting `at`: ballistic droplets.
static func _spray(f: float, at: float, x: float, y: float, n: int, seed: float, power := 1.0) -> Array:
	var t := f - at
	var out := []
	if t < 0 or t > 26:
		return out
	for i in n:
		var a := -PI / 2 + (MK.rand(seed + i) - 0.5) * 2.6
		var v := (6 + 14 * MK.rand(seed + i * 3)) * power
		out.append(Vector3(x + cos(a) * v * t, y + sin(a) * v * t + 0.9 * t * t, (5 + 9 * MK.rand(seed + i * 7)) * (1 - t / 26)))
	return out


## A splat: grows past its size, then shrinks as the crisp thing takes over.
static func _splat(f: float, at: float, r: float) -> float:
	var t := f - at
	if t < 0:
		return 0.0
	return r * 0.6 * ((t / 3) * 1.1 if t < 3 else maxf(0.0, 1.1 - (t - 3) / 6))


func _build() -> void:
	_built = true
	_pts = GooKit.m_points(7)
	_g = GooKit.scf_geom(1560, 180, 300)
	var mh := SCFBrand.logo("mhFull")
	var full := SCFBrand.logo("scfFull")
	_mh_letters = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
	for i in _mh_letters:
		var b: Rect2 = mh.parts[i].bbox
		_mh_c.append(Vector3(MH_X + (b.get_center().x - 140) * MH_K, MH_Y + b.get_center().y * MH_K, maxf(b.size.x, b.size.y) * MH_K * 0.55))
	for i in _g.words:
		var b: Rect2 = full.parts[i].bbox
		_scf_c.append(Vector3(_g.S_X + b.get_center().x * _g.S_K, _g.S_Y + b.get_center().y * _g.S_K, maxf(b.size.x, b.size.y) * _g.S_K * 0.55))
	_bg = PrintKit.rect(self, Rect2(0, 0, 1920, 1080), INK)

	# ---- beat 1
	_b1 = Node2D.new()
	add_child(_b1)
	for L in 3:
		_pour.append(GooKit.goo(_b1, GooKit.M_LAYER_COL[L], 11))
	_crisp1 = MotionSvg.new()
	_crisp1.data = SCFBrand.logo("mhM")
	_crisp1.width = M_W * GooKit.M_VIEW
	_crisp1.position = Vector2(M_X, M_Y)
	_b1.add_child(_crisp1)
	_splat1 = GooKit.goo(_b1, CREAM, 8)
	_word1 = MotionSvg.new()
	_word1.data = mh
	_word1.width = 1000
	_word1.crop = Rect2(140, 0, 345.7, 128.89)
	_word1.only = PackedInt32Array(_mh_letters)
	_word1.position = Vector2(MH_X, MH_Y)
	_b1.add_child(_word1)
	_presents = MotionText.new()
	_presents.font = SCFBrand.font("outfit", 900)
	_presents.font_size = 40
	_presents.tracking = 0.6
	_presents.color = SCFBrand.AMBER
	_presents.text = "PRESENTS"
	_presents.position = Vector2(800, 840)
	_b1.add_child(_presents)
	_drop = GooKit.goo(_b1, CREAM, 14)

	# ---- beat 2
	_b2 = Node2D.new()
	add_child(_b2)
	for k in 3:
		_disc_goo.append(GooKit.goo(_b2, GooKit.DISC_COLS[k], 10))
	_crisp2 = MotionSvg.new()
	_crisp2.data = full
	_crisp2.width = _g.S_W
	_crisp2.position = Vector2(_g.S_X, _g.S_Y)
	_b2.add_child(_crisp2)
	_splat2 = GooKit.goo(_b2, INK, 7)
	_words = MotionSvg.new()
	_words.data = full
	_words.width = _g.S_W
	_words.only = PackedInt32Array(_g.words)
	_words.position = Vector2(_g.S_X, _g.S_Y)
	_b2.add_child(_words)
	# flex, gap 14; padding 7px 16px, radius 30, each scaled about its centre
	var x: float = _g.S_X + 110 * _g.S_K
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
		p.position = Vector2(x, _g.S_Y + 90 * _g.S_K) + sz * 0.5
		x += sz.x + 14
		_b2.add_child(p)
		_pills.append(p)
	_drip = GooKit.goo(_b2, INK, 20)
	_cover = PrintKit.rect(_b2, Rect2(0, 0, 1920, 1080), INK)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var b1 := f < 158
	_bg.color = INK if b1 else CREAM
	_b1.visible = b1
	_b2.visible = not b1
	if b1:
		_frame_b1(f)
	else:
		_frame_b2(f)


func _frame_b1(f: float) -> void:
	for L in 3:
		var off: Vector2 = GooKit.M_LAYER_OFF[L]
		var a: float = FILL[L][0]
		var b: float = FILL[L][1]
		var level := MK.interp(f, [a + 6, b], [122, -4])   # in M units, from the bottom up
		var surf_y := M_Y + (level + off.y) * M_K
		var cx := M_X + (60 + off.x) * M_K
		var shrink := 1.0 - MK.map(f, [118, 126], [0, 1]) if f > 118 else 1.0
		var blobs := []
		for p in _pts:
			if p.y < level:
				continue
			var near := maxf(0.0, 1 - (p.y - level) / 8)
			blobs.append(Vector3(M_X + (p.x + off.x) * M_K, M_Y + (p.y + off.y) * M_K + sin(p.x / 6 + f / 2) * near * 10, 7 * M_K * 0.72 * shrink))
		# the stream: falls from the top, stops once the mould is full and drops away
		var tail := pow(maxf(0.0, f - b) / 6, 2) * 120
		if f >= a and f < b + 14:
			var y := -60 + tail
			while y < surf_y:
				blobs.append(Vector3(cx + sin(y / 60 + f / 3) * 6, y + fmod(f * 22, 26), 17 + sin(y / 40 + f) * 3))
				y += 26
			blobs += _spray(f, floorf(f / 3) * 3, cx, surf_y, 5, f * 13 + L * 7, 0.6)
		GooKit.set_blobs(_pour[L], blobs)

	var crisp1 := MK.map(f, [114, 120], [0, 1])
	_crisp1.visible = crisp1 > 0.0
	_crisp1.modulate.a = crisp1
	var sb := []
	for k in _mh_letters.size():
		var c: Vector3 = _mh_c[k]
		var at := 118 + k * 1.5
		sb.append(Vector3(c.x, c.y, _splat(f, at, c.z)))
		sb += _spray(f, at, c.x, c.y, 4, _mh_letters[k] * 9, 0.5)
	GooKit.set_blobs(_splat1, sb)
	_word1.apply(func(i: int):
		var at := 118 + _mh_letters.find(i) * 1.5 + 3
		return {hide = true} if f < at else {fill = CREAM, s = 1 + 0.25 * exp(-(f - at) / 3)})
	_presents.modulate.a = MK.map(f, [140, 144], [0, 1])

	_drop.fx.visible = f >= 132
	if f >= 132:
		var big := MK.interp(f, [132, 150], [-400, 540], func(t: float) -> float: return t * t)
		var flood := MK.interp(f, [150, 162], [0, 1], func(t: float) -> float: return 1 - (1 - t) * (1 - t))
		var db := [Vector3(960, big, 110), Vector3(960, big - 120, 70)]
		if f >= 150:
			db.append(Vector3(960, 540, lerpf(120, 1500, flood)))
			for s: Vector3 in _spray(f, 150, 960, 540, 18, 777, 2.2):
				db.append(Vector3(s.x, s.y, s.z * 3))
		GooKit.set_blobs(_drop, db)


func _frame_b2(f: float) -> void:
	var o := f - OUT
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var crisp2 := MK.map(f, [236, 242], [0, 1])
	for k in 3:
		var d: Dictionary = _g.discs[k]
		var at: float = IMPACT[k]
		var out := []
		if f < at:
			var y := MK.interp(f, [at - 16, at], [-200, d.y], func(t: float) -> float: return t * t)
			if f >= at - 16:
				out = [Vector3(d.x, y, d.r * 0.55), Vector3(d.x, y - d.r * 0.7, d.r * 0.38)]
		else:
			var t := f - at
			out.append(Vector3(d.x, d.y, d.r * (1 + 0.35 * exp(-t / 5) * cos(t * 0.7))))
			out += _spray(f, at, d.x, d.y - d.r * 0.3, 10, k * 50 + 3, 1.2)
			# droplets that land as this colour's nodes
			for n: Dictionary in _g.nodes:
				if n.col != GooKit.DISC_COLS[k]:
					continue
				var u := minf(1.0, t / 14)
				out.append(Vector3(lerpf(d.x, n.x, u), lerpf(d.y, n.y, u) - sin(u * PI) * 120, n.r * (0.6 + 0.4 * u)))
		GooKit.set_blobs(_disc_goo[k], out)
		_disc_goo[k].fx.modulate.a = 1 - crisp2

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
				var s: float = sp.call(238 + di * 3, 8, 220)
				return {hide = true} if s <= 0.01 else {s = s}
			if (F.edges as Array).has(i):
				return {s = MK.map(f, [240, 252], [0, 1]), pivot = Vector2(52.8, 43.4)}
			return null)
	var sb := []
	for k in words.size():
		var c: Vector3 = _scf_c[k]
		var at := 246 + k * 1.3
		sb.append(Vector3(c.x, c.y, _splat(f, at, c.z)))
		sb += _spray(f, at, c.x, c.y, 3, words[k] * 11, 0.45)
	GooKit.set_blobs(_splat2, sb)
	_words.apply(func(i: int):
		var at := 246 + words.find(i) * 1.3 + 3
		return {hide = true} if f < at else {fill = INK, s = 1 + 0.25 * exp(-(f - at) / 3)})
	for k in 3:
		var s := maxf(0.0, sp.call(278 + k * 5, 7, 240))
		_pills[k].scale = Vector2.ONE * s
		_pills[k].visible = s > 0.0

	_drip.fx.visible = o > 0
	if o > 0:
		var db := []
		for j in 26:
			var v := 0.8 + MK.rand(j * 5) * 1.2
			var end := -200 + maxf(0.0, o - MK.rand(j) * 12) * 38 * v
			var x := j * 76 + 20.0
			var r := 58 + 30 * MK.rand(j * 3)
			db.append(Vector3(x, end, r * 1.15))
			var y := -260.0
			while y < end:
				db.append(Vector3(x + sin(y / 90 + j) * 8, y, r))
				y += 55
		GooKit.set_blobs(_drip, db)
	_cover.visible = o > 40
	_cover.color.a = MK.map(o, [40, 48], [0, 1])
