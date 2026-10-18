# SPDX-License-Identifier: Apache-2.0
# G3 — CELLS, ported from scf-intros src/intros/G3_Cells.tsx.
# Goo under a microscope. One cell divides, and divides again, six
# generations, until sixty-four cells crawl into the shape of the M and stain
# into its three colours; the wordmark grows in cell by cell. The slide
# changes. The view widens, one cell splits into three, they stain blue, amber
# and red, swell into the discs and bud off the nodes. At the end the cells
# break up into vesicles and the iris closes.
@tool
extends MotionComposition

const OUT := 350
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const DARK := Color("#0b0b0b")
const HUD := Color("#8c8c8c")
const M_W := 380.0
const M_K := M_W / 120.63
const M_X := 960.0 - M_W / 2.0
const M_Y := 190.0
const N := 64
const GEN_T := [12, 25, 37, 48, 58, 67]

var _built := false
var _targets: Array[Vector2] = []
var _pos: Array = []          # per generation: Array[Vector2]
var _g: Dictionary
var _slide: MotionFX
var _b1: Node2D
var _cells: Dictionary
var _nuclei: Dictionary
var _crisp1: MotionSvg
var _word1: MotionSvg
var _presents: MotionText
var _b2: Node2D
var _stain_goo: Dictionary
var _disc_goo: Array = []
var _crisp2: MotionSvg
var _words: MotionSvg
var _pills_node: Node2D
var _pills: Array[MotionPill] = []
var _scope: MotionCanvas
var _hud: Array[MotionText] = []


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _hud_text(x: float, y: float, right := false) -> MotionText:
	var t := MotionText.new()
	t.font = PrintKit.mono_font(700)
	t.font_size = 22
	t.color = HUD
	t.tracking = 0.12
	if right:
		t.align = HORIZONTAL_ALIGNMENT_RIGHT
		t.position = Vector2(1920 - x, y)
	else:
		t.position = Vector2(x, y)
	add_child(t)
	_hud.append(t)
	return t


func _build() -> void:
	_built = true
	_targets = GooKit.m_points(9.5)
	_pos = [[Vector2(960, 420)]]
	for g in 6:
		var sep: float = [150, 110, 80, 58, 42, 30][g]
		var nxt := []
		var j := 0
		for p: Vector2 in _pos[g]:
			var a := MK.rand(g * 31 + j * 7) * PI * 2
			nxt.append(p + Vector2(cos(a) * sep, sin(a) * sep * 0.8))
			nxt.append(p - Vector2(cos(a) * sep, sin(a) * sep * 0.8))
			j += 1
		_pos.append(nxt)
	_g = GooKit.scf_geom(1500, 210, 300)

	PrintKit.rect(self, Rect2(0, 0, 1920, 1080), Color("#171717"))
	# the slide: moves, and blurs while it does (CSS filter: blur)
	_slide = MotionFX.new()
	_slide.size = Vector2(1920, 1080)
	add_child(_slide)

	# ---- beat 1
	_b1 = Node2D.new()
	_slide.content.add_child(_b1)
	_cells = GooKit.goo(_b1, CREAM, 9)
	_nuclei = GooKit.goo(_b1, SCFBrand.AMBER, 5)
	_crisp1 = MotionSvg.new()
	_crisp1.data = SCFBrand.logo("mhM")
	_crisp1.width = M_W * GooKit.M_VIEW
	_crisp1.position = Vector2(M_X, M_Y)
	_b1.add_child(_crisp1)
	_word1 = MotionSvg.new()
	_word1.data = SCFBrand.logo("mhFull")
	_word1.width = 680
	_word1.crop = Rect2(140, 0, 345.7, 128.89)
	_word1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_word1.position = Vector2(960 - 340, 610)
	_b1.add_child(_word1)
	_presents = MotionText.new()
	_presents.font = SCFBrand.font("outfit", 800)
	_presents.font_size = 26
	_presents.tracking = 0.6
	_presents.color = SCFBrand.AMBER
	_presents.text = "PRESENTS"
	_presents.align = HORIZONTAL_ALIGNMENT_CENTER
	_presents.box_width = 1920
	_presents.position = Vector2(0, 880)
	_b1.add_child(_presents)

	# ---- beat 2
	_b2 = Node2D.new()
	_slide.content.add_child(_b2)
	_stain_goo = GooKit.goo(_b2, CREAM, 9)
	for k in 3:
		_disc_goo.append(GooKit.goo(_b2, GooKit.DISC_COLS[k], 9))
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
		p.background = [CREAM, SCFBrand.BLUE, SCFBrand.RED][k]
		p.text_color = CREAM if k else INK
		p.text = ["MINIMAL HUMANS PRESENTS", "OPEN FORMAT", "1.0"][k]
		var sz := p.get_box_size()
		p.position = Vector2(x, _g.S_Y + 90 * _g.S_K) + sz * 0.5
		x += sz.x + 14
		_pills_node.add_child(p)
		_pills.append(p)

	# the microscope: iris, reticle, readouts
	_scope = MotionCanvas.new()
	add_child(_scope)
	_scope.draw_fn = _draw_scope
	_hud_text(56, 50)
	_hud_text(56, 50, true)
	_hud_text(56, 1000)
	PrintKit.rect(self, Rect2(1920 - 56 - 160, 1080 - 52 - 6, 160, 6), Color("#5a5a5a"))
	_hud_text(56, 1012, true)


func _iris(f: float) -> float:
	var o := f - OUT
	if f < 170:
		return 500.0
	return lerpf(500, 1250, MK.map(f, [176, 214], [0, 1], MK.ease_in_out)) * (1 - MK.interp(o, [14, 46], [0, 1], func(t: float) -> float: return t * t))


## radial-gradient(circle at 50% 50%, transparent iris px, #0b0b0b iris+3 px),
## the iris ring with its 72 ticks, and the crosshair.
func _draw_scope(c: MotionCanvas, f: float) -> void:
	var iris := _iris(f)
	var ctr := Vector2(960, 540)
	var seg := 256
	var clear := Color(DARK, 0.0)
	for s in seg:
		var a0 := float(s) / seg * TAU
		var a1 := float(s + 1) / seg * TAU
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		c.draw_polygon(PackedVector2Array([ctr + d0 * iris, ctr + d1 * iris, ctr + d1 * (iris + 3), ctr + d0 * (iris + 3)]),
			PackedColorArray([clear, clear, DARK, DARK]))
		c.draw_polygon(PackedVector2Array([ctr + d0 * (iris + 3), ctr + d1 * (iris + 3), ctr + d1 * 2400, ctr + d0 * 2400]),
			PackedColorArray([DARK, DARK, DARK, DARK]))
	c.ring(ctr, iris + 1, Color("#2e2e2e"), 4)
	if iris > 40:
		for k in 72:
			var a := float(k) / 72 * TAU
			var l := 22.0 if k % 6 == 0 else 10.0
			var d := Vector2(cos(a), sin(a))
			c.line(ctr + d * (iris + 8), ctr + d * (iris + 8 + l), Color("#3a3a3a"), 2)
	# 1 px lines centred on pixel edges: two half-covered rows (columns) each
	var hair := Color(1, 1, 1, 0.06)
	for k in 2:
		c.rect(Rect2(930, 539 + k, 60, 1), hair)
	for k in 2:
		c.rect(Rect2(959 + k, 510, 1, 60), hair)


# ------------------------------------------------------------------ frame

func _cell_at(f: float, i: int) -> Vector3:
	var p: Vector2 = _pos[0][0]
	var gen := 0.0
	for g in 6:
		var t := MK.map(f, [GEN_T[g], GEN_T[g] + 9], [0, 1], MK.ease_in_out)
		if t <= 0.0:
			break
		var n: Vector2 = _pos[g + 1][i >> (5 - g)]
		p = p.lerp(n, t)
		gen = g + t
	return Vector3(p.x, p.y, 92 / pow(2, gen / 2))


func _jit(f: float, i: int, a := 3.0) -> Vector2:
	return Vector2(sin(f / 7 + i * 1.3) * a, cos(f / 9 + i * 2.1) * a)


func _frame(f: float) -> void:
	if not _built:
		return
	var o := f - OUT
	var b1 := f < 158
	var slide := MK.map(f, [146, 170], [0, 1], MK.ease_in_out)
	var focus := sin(PI * MK.map(f, [146, 176], [0, 1])) * 14
	_slide.position.x = -slide * 1900 if b1 else (1 - slide) * 1900
	_slide.blur = focus if focus > 0.3 else 0.0
	_b1.visible = b1
	_b2.visible = not b1
	if b1:
		_frame_b1(f)
	else:
		_frame_b2(f)

	_hud[0].text = "SPECIMEN MH-01" if b1 else "SPECIMEN SCF-1.0"
	_hud[1].text = "×400 · GEN %d" % mini(6, floori(MK.map(f, [12, 76], [0, 6.99]))) if b1 else "×40"
	var n := 0
	if f < 158:
		var gens := 0
		for t in GEN_T:
			if f >= t + 5:
				gens += 1
		n = 1 << gens
	else:
		n = 1 if f < 187 else (2 if f < 199 else 3)
	_hud[2].text = "%d CELL%s" % [n, "" if n == 1 else "S"]
	_hud[3].text = "50 µm" if b1 else "500 µm"


func _frame_b1(f: float) -> void:
	var cells := []
	var nuclei := []
	var fade := 1 - MK.map(f, [126, 134], [0, 1])
	var nfade := 1 - MK.map(f, [100, 116], [0, 1])
	for i in N:
		var c := _cell_at(f, i)
		var t := MK.map(f, [74 + (i % 16) * 1.2, 104 + (i % 16) * 1.2], [0, 1], MK.ease_in_out)
		var tg := Vector2(M_X, M_Y) + _targets[int(roundf(i * (_targets.size() - 1) / float(N - 1)))] * M_K
		var j := _jit(f, i, 3 * (1 - t))
		var x := lerpf(c.x, tg.x, t) + j.x
		var y := lerpf(c.y, tg.y, t) + j.y
		var r := lerpf(c.z, 9.5 * M_K * 0.9, t) * fade
		cells.append(Vector3(x, y, r))
		nuclei.append(Vector3(x + 2, y - 1, r * 0.42 * nfade))
	GooKit.set_blobs(_cells, cells)
	GooKit.set_blobs(_nuclei, nuclei)

	var crisp1 := MK.map(f, [120, 128], [0, 1])
	_crisp1.visible = crisp1 > 0.0
	_crisp1.modulate.a = crisp1
	if _crisp1.visible:
		_crisp1.apply(func(i: int):
			if i >= 2:
				return null
			return {s = MK.map(f, [118 + i * 4, 128 + i * 4], [0.9, 1]), o = MK.map(f, [118 + i * 4, 126 + i * 4], [0, 1])})
	_word1.visible = f >= 124
	if _word1.visible:
		var letters: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
		_word1.apply(func(i: int):
			var at: float = 124 + letters.find(i) * 1.3
			return {hide = true} if f < at else {s = GooKit.wob(f, at, 0.9, 3.5), fill = CREAM})
	_presents.modulate.a = MK.map(f, [138, 144], [0, 1])


func _frame_b2(f: float) -> void:
	var o := f - OUT
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var split1 := MK.map(f, [182, 192], [0, 1], MK.ease_in_out)
	var split2 := MK.map(f, [194, 204], [0, 1], MK.ease_in_out)
	var to_disc := MK.map(f, [208, 236], [0, 1], MK.ease_in_out)
	var lyse := MK.map(o, [0, 26], [0, 1])
	var crisp2 := MK.map(f, [248, 254], [0, 1]) * (1 - MK.map(o, [0, 4], [0, 1]))
	var three := [Vector2(960 - 150 * split1, 540), Vector2(960 + 150 * split1 - 120 * split2, 540 - 40 * split2),
		Vector2(960 + 150 * split1 + 120 * split2, 540 + 40 * split2)]
	var all := []
	var stains := []
	for k in 3:
		var d: Dictionary = _g.discs[k]
		var st: Vector2 = three[k]
		var r0 := lerpf(90, 64, split1) if k == 0 else lerpf(lerpf(90, 64, split1), 46, split2)
		var x := lerpf(st.x, d.x, to_disc)
		var y := lerpf(st.y, d.y, to_disc)
		var r := lerpf(r0, d.r, to_disc)
		var out := []
		if lyse < 1:
			var j := _jit(f, k, 2)
			out.append(Vector3(x + j.x, y + j.y, r * (1 - lyse)))
		if lyse > 0:
			for v in 9:
				var a := MK.rand(k * 9 + v) * PI * 2
				var dist := lyse * (80 + 260 * MK.rand(v + k * 3))
				out.append(Vector3(x + cos(a) * dist, y + sin(a) * dist, r * 0.36 * (1 - lyse * 0.35)))
		# buds: grow on the edge, pinch off, drift to the node
		for i in _g.nodes.size():
			var n: Dictionary = _g.nodes[i]
			if n.col != GooKit.DISC_COLS[k]:
				continue
			var at: float = 234 + i * 2
			var grow := MK.map(f, [at, at + 6], [0, 1])
			var leave := MK.map(f, [at + 4, at + 18], [0, 1], MK.ease_in_out)
			var ang := atan2(n.y - d.y, n.x - d.x)
			var e: Vector2 = Vector2(d.x, d.y) + Vector2(cos(ang), sin(ang)) * d.r * 0.9
			out.append(Vector3(lerpf(e.x, n.x, leave) + cos(ang) * lyse * 300, lerpf(e.y, n.y, leave) + sin(ang) * lyse * 300, n.r * grow * (1 - lyse)))
		all += out
		var stain := MK.map(f, [200 + k * 4, 212 + k * 4], [0, 1])
		stains.append(stain)
		GooKit.set_blobs(_disc_goo[k], out)
		_disc_goo[k].fx.modulate.a = stain * (1 - crisp2)
		_disc_goo[k].fx.visible = stain * (1 - crisp2) > 0.0
	GooKit.set_blobs(_stain_goo, all)
	_stain_goo.fx.modulate.a = 1 - minf(stains[0], minf(stains[1], stains[2]))
	_stain_goo.fx.visible = _stain_goo.fx.modulate.a > 0.0

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
				var s: float = sp.call(250 + di * 3, 9, 200)
				return {hide = true} if s <= 0.01 else {s = s}
			if (F.edges as Array).has(i):
				return {s = MK.map(f, [252, 264], [0, 1]), pivot = Vector2(52.8, 43.4), fill = CREAM}
			return null)
	_words.apply(func(i: int):
		var k := words.find(i)
		var at: float = 258 + k * 1.1
		if f < at:
			return {hide = true}
		return {s = GooKit.wob(f, at, 0.9, 3.5) * (1 - MK.map(o, [k * 0.5, 8 + k * 0.5], [0, 1])), fill = CREAM})
	_pills_node.modulate.a = 1 - MK.map(o, [0, 8], [0, 1])
	for k in 3:
		var at: float = 284 + k * 5
		var s := 0.0 if f < at else maxf(0.0, GooKit.wob(f, at, 0.9, 3.5))
		_pills[k].scale = Vector2.ONE * s
		_pills[k].visible = s > 0.0
