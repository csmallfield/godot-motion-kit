# SPDX-License-Identifier: Apache-2.0
# G4 — FERRO, ported from scf-intros src/intros/G4_Ferro.tsx.
# Goo as ferrofluid. A puddle of black fluid on cream throws spikes on every
# beat as an unseen magnet pulses, then flows into the M; one last pulse and it
# takes its colours, and the wordmark is pulled up out of the baseline. The
# magnet drags everything off to the right. Three coloured ferro blobs are
# dragged in, bristle as the magnet sweeps past, then relax into smooth discs;
# the spike tips break off and land as the nodes. At the end the magnet comes
# back, everything bristles once more and is torn off frame.
@tool
extends MotionComposition

const OUT := 350
const BEAT := 15
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const M_W := 470.0
const M_K := M_W / 120.63
const M_X := 250.0
const M_Y := 300.0

var _built := false
var _pts: Array[Vector2] = []
var _mc := Vector2(M_X + 60 * M_K, M_Y + 60 * M_K)
var _g: Dictionary
var _b1: Node2D
var _fill: Dictionary
var _ink: Dictionary
var _mono: MotionSvg
var _word1: MotionSvg
var _pres_pivot: Node2D
var _b2: Node2D
var _ferro: Array = []
var _crisp2: MotionSvg
var _words_box: Node2D
var _words: MotionSvg
var _words_c := Vector2.ZERO
var _pills_node: Node2D
var _pills: Array[MotionPill] = []
var _field: MotionText


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


## Pulse after each beat: 1 on the beat, decaying.
static func _pulse(f: float, from: float, to: float) -> float:
	if f < from or f >= to:
		return 0.0
	return exp(-fmod(f - from, BEAT) / 4.5)


## A ferro blob: a core with tapering spikes. `bias` (when not NAN) leans the
## spikes toward an angle.
static func _spiky(cx: float, cy: float, R: float, L: float, seed: float, f: float, bias := NAN, bias_amt := 0.0) -> Array:
	var out := [Vector3(cx, cy, R)]
	if L < 1:
		return out
	var n := 30
	for j in n:
		var a := float(j) / n * PI * 2 + f / 90 + seed
		var lean := 1.0 if is_nan(bias) else 1.0 + bias_amt * cos(a - bias)
		var len := L * (0.55 + 0.45 * sin(j * 2.7 + seed + f / 9)) * maxf(0.1, lean)
		for s in 10:
			var u := s / 9.0
			var d := R * 0.85 + len * u
			out.append(Vector3(cx + cos(a) * d, cy + sin(a) * d, lerpf(minf(R * 0.26, 34), 1.2, pow(u, 0.7)) + 1.5))
	return out


static func _rise(f: float, at: float) -> float:
	return 0.0 if f < at else minf(1.25, 1 - exp(-(f - at) / 3) * cos((f - at) * 0.8))


## translateX(tx) skewX(deg) about `origin` (CSS transform-origin).
static func _shear(origin: Vector2, tx: float, deg: float) -> Transform2D:
	return Transform2D(0.0, origin + Vector2(tx, 0)) * Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(deg)), 1), Vector2.ZERO) \
		* Transform2D(0.0, -origin)


func _build() -> void:
	_built = true
	_pts = GooKit.m_points(8)
	_g = GooKit.scf_geom(1560, 180, 300)
	PrintKit.rect(self, Rect2(0, 0, 1920, 1080), CREAM)

	# ---- beat 1
	_b1 = Node2D.new()
	add_child(_b1)
	_fill = GooKit.goo(_b1, INK, 8)
	_ink = GooKit.goo(_b1, INK, 5, 34)
	_mono = MotionSvg.new()
	_mono.data = SCFBrand.logo("mhM")
	_mono.width = M_W * GooKit.M_VIEW
	_mono.position = Vector2(M_X, M_Y)
	_mono.set_part(2, {fill = INK})
	_b1.add_child(_mono)
	_word1 = MotionSvg.new()
	_word1.data = SCFBrand.logo("mhFull")
	_word1.width = 1000
	_word1.crop = Rect2(140, 0, 345.7, 128.89)
	_word1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_word1.position = Vector2(790, 300 + (470 - 1000 * 128.89 / 345.7) / 2)
	_b1.add_child(_word1)
	var pres := MotionText.new()
	pres.font = SCFBrand.font("outfit", 900)
	pres.font_size = 40
	pres.tracking = 0.6
	pres.color = SCFBrand.RED
	pres.text = "PRESENTS"
	var psz := pres.get_text_size()
	_pres_pivot = Node2D.new()               # transform-origin 50% 100%
	_pres_pivot.position = Vector2(800, 840) + Vector2(psz.x * 0.5, psz.y)
	pres.position = -Vector2(psz.x * 0.5, psz.y)
	_pres_pivot.add_child(pres)
	_b1.add_child(_pres_pivot)

	# ---- beat 2
	_b2 = Node2D.new()
	add_child(_b2)
	for k in 3:
		_ferro.append(GooKit.goo(_b2, GooKit.DISC_COLS[k], 5, 34))
	var full := SCFBrand.logo("scfFull")
	_crisp2 = MotionSvg.new()
	_crisp2.data = full
	_crisp2.width = _g.S_W
	_crisp2.position = Vector2(_g.S_X, _g.S_Y)
	_b2.add_child(_crisp2)
	_words_box = Node2D.new()
	_b2.add_child(_words_box)
	_words = MotionSvg.new()
	_words.data = full
	_words.width = _g.S_W
	_words.only = PackedInt32Array(_g.words)
	_words.position = Vector2(_g.S_X, _g.S_Y)
	_words_box.add_child(_words)
	# the div around the inline svg: its size plus the strut gap; origin its centre
	_words_c = Vector2(_g.S_X, _g.S_Y) + Vector2(_g.S_W, _words.get_size().y + PrintKit.STRUT_GAP) * 0.5
	_pills_node = Node2D.new()
	_b2.add_child(_pills_node)
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
		p.set_meta("box", Rect2(Vector2(x, _g.S_Y + 90 * _g.S_K), sz))
		x += sz.x + 14
		_pills_node.add_child(p)
		_pills.append(p)

	# the magnet, felt not seen: a faint field line marker at the edge
	_field = MotionText.new()
	_field.font = PrintKit.mono_font(700)
	_field.font_size = 22
	_field.tracking = 0.14
	_field.color = INK
	_field.modulate.a = 0.45
	_field.text = "FIELD 0.00 T"
	_field.position = Vector2(48, 1080 - 40 - _field.get_text_size().y)
	add_child(_field)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var b1 := f < 162
	_b1.visible = b1
	_b2.visible = not b1
	var spikes := 260 * _pulse(f, 15, 60) + 70 * _pulse(f, 60, 75)
	var relax := MK.map(f, [232, 246], [0, 1], MK.ease_in_out)
	if b1:
		_frame_b1(f, spikes)
	else:
		_frame_b2(f, relax)
	_field.text = "FIELD %.2f T" % (0.4 + spikes / 120.0 if b1 else 0.4 + (1 - relax) * 0.8)


func _frame_b1(f: float, spikes: float) -> void:
	var drag := MK.interp(f, [140, 162], [0, 1], func(t: float) -> float: return t * t * t)
	_b1.transform = _shear(Vector2(960, 540), drag * 2400, -drag * 30)
	var ink := []
	var mfill := []
	if f < 116:
		var puddle := 170 * SCFBrand.sp(f, 0, 12, 120)
		ink += _spiky(960, 540, puddle * (1 - MK.map(f, [60, 98], [0, 1])), spikes, 1, f)
		for i in _pts.size():
			var t := MK.map(f, [50 + (i % 21) * 0.9, 80 + (i % 21) * 0.9], [0, 1], MK.ease_in_out)
			if t <= 0.0:
				continue
			var a := MK.rand(i) * PI * 2
			var rr := MK.rand(i * 3) * 130
			mfill.append(Vector3(lerpf(960 + cos(a) * rr, M_X + _pts[i].x * M_K, t), lerpf(540 + sin(a) * rr, M_Y + _pts[i].y * M_K, t), lerpf(14, 8 * M_K * 0.88, t)))
		if f >= 98:
			ink += _spiky(_mc.x, _mc.y, 40, 520 * exp(-(f - 98) / 5), 4, f)   # the last pulse
	var colour_in := MK.map(f, [102, 112], [0, 1])
	_fill.fx.visible = f < 116
	_ink.fx.visible = f < 116
	_fill.fx.modulate.a = 1 - colour_in
	GooKit.set_blobs(_fill, mfill)
	GooKit.set_blobs(_ink, ink)
	_mono.visible = colour_in > 0.0
	_mono.modulate.a = colour_in
	_word1.visible = f >= 112
	if _word1.visible:
		var d := SCFBrand.logo("mhFull")
		var letters: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
		_word1.apply(func(i: int):
			var s := _rise(f, 112 + letters.find(i) * 1.4)
			if s <= 0.01:
				return {hide = true}
			var bb: Rect2 = d.parts[i].bbox
			return {sy = s, sx = 1 - (s - 1) * 0.5, pivot = Vector2(bb.get_center().x, bb.end.y), fill = INK})
	var ps := _rise(f, 130)
	_pres_pivot.visible = ps > 0.0
	_pres_pivot.scale = Vector2(1, maxf(ps, 1e-4))


func _frame_b2(f: float, relax: float) -> void:
	var o := f - OUT
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var mag_x := lerpf(-300, 2200, MK.map(f, [194, 236], [0, 1], MK.ease_in_out))
	var crisp2 := MK.map(f, [246, 252], [0, 1]) * (1 - MK.map(o, [0, 4], [0, 1]))
	var tear := MK.interp(o, [14, 42], [0, 1], func(t: float) -> float: return t * t * t)
	for k in 3:
		var d: Dictionary = _g.discs[k]
		var enter := MK.map(f, [164 + k * 6, 192 + k * 6], [0, 1], MK.ease_in_out)
		var x := lerpf(-400, d.x, enter) + tear * 2600
		var bristle := (1 - relax) * (60 + 90 * _pulse(f, 195, 240)) + (280 * exp(-maxf(0.0, o - 2) / 10) if o > 0 else 0.0)
		var bias := atan2(0, mag_x - x)
		var out := _spiky(x, d.y, d.r * (0.82 if f < 246 else 1.0) + relax * d.r * 0.18, bristle * enter, k * 3 + 1, f, bias if f < 240 else NAN, 0.8)
		for i in _g.nodes.size():
			var n: Dictionary = _g.nodes[i]
			if n.col != GooKit.DISC_COLS[k]:
				continue
			var t := MK.map(f, [236 + i * 1.5, 250 + i * 1.5], [0, 1], MK.ease_in_out)
			if t <= 0.0:
				continue
			var a := atan2(n.y - d.y, n.x - d.x)
			out.append(Vector3(lerpf(d.x + cos(a) * (d.r + 50), n.x, t) + tear * 2600, lerpf(d.y + sin(a) * (d.r + 50), n.y, t), n.r))
		GooKit.set_blobs(_ferro[k], out)
		_ferro[k].fx.modulate.a = 1 - crisp2

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
				var s: float = sp.call(248 + di * 3, 8, 220)
				return {hide = true} if s <= 0.01 else {s = s}
			if (F.edges as Array).has(i):
				return {s = MK.map(f, [250, 262], [0, 1]), pivot = Vector2(52.8, 43.4)}
			return null)
	_words_box.transform = _shear(_words_c, tear * 2600, -tear * 30)
	var full := SCFBrand.logo("scfFull")
	_words.apply(func(i: int):
		var s := _rise(f, 256 + words.find(i) * 1.1)
		if s <= 0.01:
			return {hide = true}
		var bb: Rect2 = full.parts[i].bbox
		return {sy = s, sx = 1 - (s - 1) * 0.5, pivot = Vector2(bb.get_center().x, bb.end.y), fill = INK})
	_pills_node.position.x = tear * 2600
	for k in 3:
		var s := _rise(f, 282 + k * 5)
		var box: Rect2 = _pills[k].get_meta("box")
		_pills[k].visible = s > 0.05
		_pills[k].scale = Vector2(1, maxf(s, 1e-4))
		_pills[k].position = Vector2(box.get_center().x, box.end.y - box.size.y * 0.5 * s)
