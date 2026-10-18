# SPDX-License-Identifier: Apache-2.0
# F3 — GOO, ported from scf-intros src/intros/F3_Goo.tsx.
# Supergraphic gone liquid: lava-lamp blobs on blue pour themselves into the
# three layers of the M, the wordmark drops in letter by letter and lands like
# jelly, then cream floods up and takes the frame. Three blobs fall in, wobble
# and settle into the S, C and F discs; the nodes pinch off them on goo bridges
# and snap free. It holds, then everything melts and drips off the bottom.
@tool
extends MotionComposition

const OUT := 350
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const M_W := 470.0
const M_X := 250.0
const M_Y := 300.0
const S_W := 1560.0
const S_X := 180.0
const S_Y := 300.0
const PAD := 64.0          # the goo filter region reaches past the frame
const LAYER_OFF := [Vector2(9.3, 8.3), Vector2(4.7, 4.2), Vector2(0, 0)]

var _built := false
var _bg: ColorRect
var _mk := 1.0
var _m_pts: Array[Vector2] = []
var _b1: Node2D
var _m_goo: Array = []          # [MotionFX, MotionCanvas, blobs]
var _crisp_m_pivot: Node2D
var _word1: MotionSvg
var _pres: Array = []
var _flood: MotionCanvas
var _b2: Node2D
var _d_goo: Array = []
var _discs: Array = []
var _nodes: Array = []
var _crisp2: MotionSvg
var _word2: MotionSvg
var _tags: Array[MotionPill] = []
var _sk := 1.0


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


static func _in_poly(x: float, y: float, P: Array) -> bool:
	var c := false
	var j := P.size() - 1
	for i in P.size():
		var xi: float = P[i][0]
		var yi: float = P[i][1]
		var xj: float = P[j][0]
		var yj: float = P[j][1]
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
			c = not c
		j = i
	return c


## One goo layer: black circles, blurred, alpha * 26 - 11, filled with `col`
## (the SVG filter), in a MotionFX padded past the frame like the filter region.
func _goo(parent: Node, col: Color, sigma: float) -> Dictionary:
	var fx := MotionFX.new()
	fx.size = Vector2(1920 + PAD * 2, 1080 + PAD * 2)
	fx.position = -Vector2(PAD, PAD)
	fx.blur = sigma
	fx.alpha_matrix = Vector2(26, -11)
	fx.flood_color = col
	parent.add_child(fx)
	var cv := MotionCanvas.new()
	cv.position = Vector2(PAD, PAD)
	fx.content.add_child(cv)
	var g := {fx = fx, cv = cv, blobs = []}
	cv.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		for b in g.blobs:
			if b.z > 0.5:
				c.circle(Vector2(b.x, b.y), b.z, Color.BLACK)
	return g


func _build() -> void:
	_built = true
	_bg = PrintKit.rect(self, Rect2(0, 0, 1920, 1080), SCFBrand.BLUE)
	_mk = M_W / 120.63
	var outline: Array = JSON.parse_string(FileAccess.get_file_as_string("res://demo/scf/m_outline.json")).mOutline
	var y := 4.0
	while y < 120.0:
		var x := 4.0
		while x < 120.0:
			if _in_poly(x, y, outline):
				_m_pts.append(Vector2(x, y))
			x += 8.5
		y += 8.5

	# ---- beat 1
	_b1 = Node2D.new()
	add_child(_b1)
	for col in [SCFBrand.RED, SCFBrand.AMBER, CREAM]:
		_m_goo.append(_goo(_b1, col, 16))
	var mono := MotionSvg.new()
	mono.data = SCFBrand.logo("mhM")
	mono.width = M_W * (129.95 / 120.63)
	var div := Vector2(mono.width, mono.get_size().y + PrintKit.STRUT_GAP)
	_crisp_m_pivot = Node2D.new()                       # transform-origin 50% 100%
	_crisp_m_pivot.position = Vector2(M_X, M_Y) + Vector2(div.x * 0.5, div.y)
	_b1.add_child(_crisp_m_pivot)
	mono.position = -Vector2(div.x * 0.5, div.y)
	_crisp_m_pivot.add_child(mono)
	_word1 = MotionSvg.new()
	_word1.data = SCFBrand.logo("mhFull")
	_word1.width = 1000
	_word1.crop = Rect2(140, 0, 345.7, 128.89)
	_word1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_word1.position = Vector2(790, 300 + (470 - 1000 * 128.89 / 345.7) / 2.0)
	_b1.add_child(_word1)
	# PRESENTS, a letter in each amber dot: flex, gap 10
	for k in 8:
		var n := Node2D.new()
		n.position = Vector2(800 + k * 68 + 29, 830 + 29)
		_b1.add_child(n)
		n.add_child(MotionShape.circle(58, SCFBrand.AMBER))
		var t := MotionText.new()
		t.font = SCFBrand.font("outfit", 900)
		t.font_size = 30
		t.color = INK
		t.text = "PRESENTS"[k]
		t.position = -t.get_text_size() * 0.5
		n.add_child(t)
		_pres.append(n)
	_flood = MotionCanvas.new()
	_b1.add_child(_flood)
	_flood.draw_fn = func(c: MotionCanvas, f: float) -> void:
		var flood := MK.interp(f, [140, 170], [0, 1], MK.ease_in_quad)
		if flood <= 0.0:
			return
		var top := lerpf(1180, -160, flood)
		var pts := PackedVector2Array([Vector2(0, 1200), Vector2(0, top)])
		for i in 25:
			pts.append(Vector2(roundf(i / 24.0 * 1920.0), roundf(top + sin(i * 0.9 + f / 3.0) * 60.0 * (1.0 - flood * 0.6))))
		pts.append(Vector2(1920, 1200))
		c.polygon(pts, CREAM, Color(0, 0, 0, 0))

	# ---- beat 2
	_b2 = Node2D.new()
	add_child(_b2)
	var full := SCFBrand.logo("scfFull")
	_sk = S_W / full.view_box.size.x
	var F: Dictionary = SCFBrand.SCF_FULL
	for i in [F.discS, F.discC, F.discF]:
		_discs.append(_circle_of(full, i))
	for i in F.nodes:
		_nodes.append(_circle_of(full, i))
	for col in [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]:
		_d_goo.append(_goo(_b2, col, 14))
	_crisp2 = MotionSvg.new()
	_crisp2.data = full
	_crisp2.width = S_W
	_crisp2.position = Vector2(S_X, S_Y)
	_b2.add_child(_crisp2)
	_word2 = MotionSvg.new()
	_word2.data = full
	_word2.width = S_W
	_word2.only = PackedInt32Array(F.story + F.context + F.framework)
	_word2.position = Vector2(S_X, S_Y)
	_b2.add_child(_word2)
	var x := S_X + 110 * _sk
	for k in 3:
		var p := MotionPill.new()
		p.font = SCFBrand.font("outfit", 800)
		p.font_size = 24
		p.tracking = 0.14
		p.padding = Vector2(18, 8)
		p.corner_radius = 30
		p.background = [INK, SCFBrand.BLUE, SCFBrand.RED][k]
		p.text_color = CREAM
		p.text = ["MINIMAL HUMANS PRESENTS", "OPEN FORMAT", "1.0"][k]
		var sz := p.get_box_size()
		p.position = Vector2(x, S_Y - 64) + sz * 0.5
		x += sz.x + 12
		_b2.add_child(p)
		_tags.append(p)


func _circle_of(d: MotionSvgData, i: int) -> Dictionary:
	var bb: Rect2 = d.parts[i].bbox
	return {p = Vector2(S_X, S_Y) + bb.get_center() * _sk, r = bb.size.x * 0.5 * _sk, col = d.parts[i].fill}


## Gravity drop and jelly landing for one letter (a MotionSvg part override).
static func _jelly(r: float, h: float, pivot: Vector2) -> Dictionary:
	if r < 0.0:
		return {hide = true}
	var fall := minf(1.0, r / 9.0)
	var t := r - 9.0
	var sq := 0.42 * exp(-t / 4.5) * cos(t * 0.95) if t > 0.0 else 0.0
	return {ty = -(1.0 - fall * fall) * h, sy = 1.0 - sq, sx = 1.0 + sq * 0.7, pivot = pivot}


static func _bottom_centre(d: MotionSvgData, i: int) -> Vector2:
	var bb: Rect2 = d.parts[i].bbox
	return Vector2(bb.position.x + bb.size.x * 0.5, bb.end.y)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var b1 := f < 168
	_bg.color = SCFBrand.BLUE if b1 else CREAM
	_b1.visible = b1
	_b2.visible = not b1
	if b1:
		_frame_b1(f, sp)
	else:
		_frame_b2(f, sp)


func _frame_b1(f: float, sp: Callable) -> void:
	var fade_in := MK.map(f, [0, 22], [0, 1])
	var shrink := 1.0 - MK.map(f, [92, 104], [0, 1])
	for L in 3:
		var blobs := []
		var off: Vector2 = LAYER_OFF[L]
		for i in _m_pts.size():
			var seed := float(i * 7 + L * 131)
			var lx := 960 + sin(f / 23.0 + seed) * (420 + 260 * MK.rand(seed)) + sin(f / 9.0 + seed * 2) * 40
			var ly := 540 + cos(f / 29.0 + seed * 1.3) * (300 + 120 * MK.rand(seed + 1)) - (1 - fade_in) * 900 * MK.rand(seed + 2)
			var t := MK.map(f, [18 + (i % 23) * 1.2, 58 + (i % 23) * 1.2], [0, 1], MK.ease_in_out)
			var tp := Vector2(M_X, M_Y) + (_m_pts[i] + off) * _mk
			var r := lerpf(16 + 22 * MK.rand(seed + 3), 8.5 * _mk * 0.62, t) * shrink
			blobs.append({x = lerpf(lx, tp.x, t), y = lerpf(ly, tp.y, t), z = r})
		_m_goo[L].blobs = blobs
		_m_goo[L].cv.queue_redraw()
	var crisp := MK.map(f, [86, 94], [0, 1])
	_crisp_m_pivot.visible = crisp > 0.0
	_crisp_m_pivot.modulate.a = crisp
	var wob := 0.06 * exp(-(f - 88) / 6.0) * cos((f - 88) * 0.8) if f > 88 else 0.0
	_crisp_m_pivot.scale = Vector2.ONE * (1.0 + wob)
	_word1.visible = f >= 92
	if _word1.visible:
		var d := SCFBrand.logo("mhFull")
		var letters: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
		_word1.apply(func(i: int):
			var j := _jelly(f - (92 + letters.find(i) * 2.4), 300, _bottom_centre(d, i))
			if not j.has("hide"):
				j.fill = CREAM
			return j)
	for k in 8:
		var s: float = sp.call(126 + k * 1.5, 7, 220)
		_pres[k].scale = Vector2.ONE * maxf(0.0, s)
		_pres[k].visible = s > 0.0
	_flood.queue_redraw()


func _frame_b2(f: float, sp: Callable) -> void:
	var o := f - OUT
	var cols := [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]
	var melt := func(k: int) -> float: return MK.interp(o, [k * 4, 24 + k * 4], [0, 1], MK.ease_in_quad)
	var crisp2 := MK.map(f, [228, 236], [0, 1]) * (1 - MK.map(o, [0, 4], [0, 1]))
	for k in 3:
		var blobs := []
		var d: Dictionary = _discs[k]
		var s: float = sp.call(170 + k * 9, 9, 90)
		var st := MK.map(f, [196 + k * 6, 226 + k * 6], [0, 1], MK.ease_in_out)
		var m: float = melt.call(k)
		var cy := lerpf(-400, d.p.y, s)
		for j in 7:
			var a := float(j) / 7.0 * TAU + f / (9.0 + k)
			var orbit: float = d.r * 0.45 * (1 - st) * (1 + 0.3 * sin(f / 5.0 + j))
			var fall_j := m * (900 + 500 * MK.rand(j + k * 9))
			var r: float = lerpf(d.r * 0.72, d.r * (1.0 if j == 0 else 0.6), st) * (1 - 0.35 * m) * (1.0 if f >= 170 + k * 9 else 0.0)
			blobs.append({x = d.p.x + cos(a) * orbit, y = cy + sin(a) * orbit * 1.2 + fall_j, z = r})
		for i in _nodes.size():
			var n: Dictionary = _nodes[i]
			var ck := cols.find(n.col)
			if ck != k:
				continue
			var h: Dictionary = _discs[ck] if ck >= 0 else _discs[1]
			var t: float = sp.call(214 + i * 2.2, 11, 130)
			var mm: float = melt.call(ck)
			blobs.append({x = lerpf(h.p.x, n.p.x, t), y = lerpf(h.p.y, n.p.y, t) + mm * (700 + 300 * MK.rand(i)), z = n.r * (1 - 0.3 * mm) if f >= 210 else 0.0})
		_d_goo[k].blobs = blobs
		_d_goo[k].cv.queue_redraw()
		_d_goo[k].fx.modulate.a = 1.0 - crisp2

	var F: Dictionary = SCFBrand.SCF_FULL
	var words: Array = F.story + F.context + F.framework
	_crisp2.visible = crisp2 > 0.0
	_crisp2.modulate.a = crisp2
	if _crisp2.visible:
		_crisp2.apply(func(i: int):
			if i == F.cloud or words.has(i):
				return {hide = true}
			var di := 0 if (F.S as Array).has(i) else (1 if (F.C as Array).has(i) else (2 if (F.F as Array).has(i) else -1))
			if di >= 0:
				var s: float = sp.call(232 + di * 4, 8, 220)
				return {hide = true} if s <= 0.01 else {s = s}
			if (F.edges as Array).has(i):
				return {s = MK.map(f, [236, 250], [0, 1]), pivot = Vector2(52.8, 43.4)}
			var w := [F.discS, F.discC, F.discF].find(i)
			if w >= 0:
				var wob := sin(f / 6.0 + w * 2) * 0.012
				return {sx = 1 + wob, sy = 1 - wob}
			return null)
	var d := SCFBrand.logo("scfFull")
	_word2.apply(func(i: int):
		var k := words.find(i)
		var j := _jelly(f - (240 + k * 1.6), 320, _bottom_centre(d, i))
		if j.has("hide"):
			return j
		var fall := pow(maxf(0.0, o - 2 - (words.size() - k) * 0.5) / 10.0, 2) * 300 if o > 0 else 0.0
		j.ty += fall
		j.fill = INK
		return j)
	for k in 3:
		var s: float = sp.call(268 + k * 4, 8, 200) * (1 - MK.map(o, [k * 2, 8 + k * 2], [0, 1]))
		_tags[k].scale = Vector2.ONE * maxf(0.0, s)
		_tags[k].visible = s > 0.0
