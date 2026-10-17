# SPDX-License-Identifier: Apache-2.0
# B1 — PRINT, revised; ported from scf-intros src/intros/B1_Print.tsx.
# Same poster logic as B, calmer: no tickers, no Japanese, pictograms and
# numbers instead. A long hold with small living details, then the poster
# takes itself apart in hard steps to blank paper.
@tool
extends MotionComposition

const PAPER := PrintKit.PAPER
const INK := PrintKit.INK
const OUT := 362
const CUTS := [0, 8, 15, 21, 27, 32, 36, 40]
const SCF_W := 760.0
const SCF_X := 110.0
const SCF_Y := 236.0
const ROW := ["doc", "nodes", "database", "heart", "arrow"]

var _built := false
var _layouts: Array[Node2D] = []
var _l: Dictionary = {}
var _mh: Node2D
var _p: Dictionary = {}
var _bars: Array[ColorRect] = []
var _scf: Node2D
var _s: Dictionary = {}


func _init() -> void:
	duration = 410
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


## Visible window for build step k of n: in at a + k*gap, out in reverse from OUT.
static func _live(f: float, k: int, n: int, a: float, gap := 3.0) -> bool:
	return f >= a + k * gap and f < OUT + (n - 1 - k) * 3


# ------------------------------------------------------------------ build

func _build() -> void:
	_built = true
	_build_layouts()
	_build_mh()
	for i in 3:
		_bars.append(PrintKit.rect(self, Rect2(i * 640, 1080, 640, 0), [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED][i]))
	_build_scf()


func _layout_root(bg: Color) -> Node2D:
	var n := Node2D.new()
	add_child(n)
	PrintKit.rect(n, Rect2(0, 0, 1920, 1080), bg)
	_layouts.append(n)
	return n


func _icon(parent: Node, name: String, size: float, pos: Vector2, c := INK, bg := PAPER) -> MotionSvg:
	var s := PrintKit.icon(name, size, c, bg)
	s.position = pos
	parent.add_child(s)
	return s


func _build_layouts() -> void:
	# 0: paper, giant MH, red dot, a column of pictograms
	var l0 := _layout_root(PAPER)
	_l.mh = PrintKit.big("MH", 1100, INK)
	l0.add_child(_l.mh)
	var dot := MotionShape.circle(220, SCFBrand.RED)
	dot.position = Vector2(230, 220)
	l0.add_child(dot)
	PrintKit.micro_right(l0, "MINIMAL HUMANS™\nPRODUCT MH-001\nBERLIN / DE", 80, 120)
	for k in 3:
		_icon(l0, ["skull", "heart", "arrowDown"][k], 56, Vector2(1920 - 80 - 56, 220 + k * 70))
	l0.add_child(PrintKit.reg(80, 80))
	l0.add_child(PrintKit.reg(1840, 1000))

	# 1: red, the M's face on its side, a big 001 and a skull
	var l1 := _layout_root(SCFBrand.RED)
	var rot := Node2D.new()
	l1.add_child(rot)
	_l.rot = rot
	var m := PrintKit.logo(rot, "mhM", 1300, Vector2.ZERO)
	m.only = PackedInt32Array([2])
	m.apply(func(_i): return {fill = PAPER})
	_l.rot_half = Vector2(m.get_size().x, m.get_size().y + PrintKit.STRUT_GAP) * 0.5
	m.position = -_l.rot_half
	rot.rotation_degrees = -90.0
	var n001 := PrintKit.big("001", 260, INK)
	n001.align = HORIZONTAL_ALIGNMENT_RIGHT
	n001.position = Vector2(1920 - 90, 110)
	l1.add_child(n001)
	# an inline <svg> in a div: the div is the strut's descent taller
	_icon(l1, "skull", 260, Vector2(1920 - 90 - 260, 1080 - 80 - 260 - PrintKit.STRUT_GAP), INK, SCFBrand.RED)

	# 2: the sheet of twelve, two of them pictograms
	var l2 := _layout_root(PAPER)
	_l.cells = []
	for i in 12:
		var bw := 8.0 if i == 6 else 2.0
		var pos := Vector2(140 + (i % 4) * 420, 110 + floorf(i / 4.0) * 300)
		var box := MotionShape.new()
		box.kind = MotionShape.Kind.RECT
		box.anchor = Vector2.ZERO
		box.size = Vector2(380, 270)
		box.position = pos
		box.border_width = bw
		box.border_color = SCFBrand.RED if i == 6 else INK
		l2.add_child(box)
		var inner := Vector2(380, 270) - Vector2(bw, bw) * 2.0
		var cell := {box = box}
		if i == 2 or i == 9:
			cell.icon = _icon(l2, "skull" if i == 2 else "heart", 150, pos + Vector2(bw, bw) + (inner - Vector2(150, 150)) * 0.5)
			cell.name = "skull" if i == 2 else "heart"
		else:
			var lm := PrintKit.logo(l2, "mhM", 180, Vector2.ZERO)
			lm.position = pos + Vector2(bw, bw) + (inner - lm.get_size()) * 0.5
			cell.logo = lm
		_l.cells.append(cell)
	_l.sheet = PrintKit.micro_at(l2, "", 140, 1010)

	# 3: amber, an ink disc with a heart
	var l3 := _layout_root(SCFBrand.AMBER)
	var disc := Node2D.new()
	l3.add_child(disc)
	_l.disc = disc
	disc.add_child(MotionShape.circle(820, INK))
	_icon(disc, "heart", 460, Vector2(-230, -230), PAPER)
	PrintKit.micro_at(l3, "PRESENTED BY\nMINIMAL HUMANS", 80, 80)
	l3.add_child(PrintKit.reg(1840, 80))

	# 4: blue, MINIMAL HUMANS, barcode, three arrows
	var l4 := _layout_root(SCFBrand.BLUE)
	_l.mhw = PrintKit.big("MINIMAL\nHUMANS", 400, PAPER)
	l4.add_child(_l.mhw)
	_l.bar = PrintKit.barcode(80, 880, 520, 120, 0, PAPER)
	l4.add_child(_l.bar)
	for k in 3:
		_icon(l4, "arrow", 90, Vector2(1920 - 80 - 290 + k * 100, 1080 - 80 - 90), PAPER)


func _build_mh() -> void:
	_mh = Node2D.new()
	add_child(_mh)
	var c := _mh
	PrintKit.rect(c, Rect2(0, 0, 1920, 1080), PAPER)
	_p.rule = PrintKit.rect(c, Rect2(80, 150, 1760, 14), INK)
	_p.head = PrintKit.micro_at(c, "MH—001 / BERLIN DE / FREE + OPEN SOURCE", 80, 100)
	_p.sheet = PrintKit.micro_right(c, "SHEET 01 / 02", 80, 100)
	_p.logo = PrintKit.logo(c, "mhFull", 1560, Vector2(80, 236))
	_p.tm = PrintKit.micro_at(c, "™", 1650, 236, INK, 40)

	# PRESENTS on ink, then a red block with an arrow, stretched to the same height
	var box := Node2D.new()
	box.position = Vector2(547, 680)
	c.add_child(box)
	var t := MotionText.new()
	t.font = SCFBrand.font("inter", 900)
	t.font_size = 92
	t.color = PAPER
	t.tracking = 0.04
	t.text = "PRESENTS"
	var ts := t.get_text_size()
	var h := 16 + ts.y + 10
	PrintKit.rect(box, Rect2(0, 0, 30 + ts.x + 30, h), INK)
	t.position = Vector2(30, 16)
	box.add_child(t)
	var x := 30 + ts.x + 30
	PrintKit.rect(box, Rect2(x, 0, 130, h), SCFBrand.RED)
	_icon(box, "arrow", 86, Vector2(x + 22, (h - 86) * 0.5))
	_p.presents = box

	_p.regs = PrintKit.regs(c)
	_p.strip = PrintKit.add(c, PrintKit.strip(80, 900))
	_p.barcode = PrintKit.add(c, PrintKit.barcode(360, 900, 300, 40, 9))
	var icons := Node2D.new()
	c.add_child(icons)
	for k in 4:
		_icon(icons, ["skull", "heart", "star", "database"][k], 52, Vector2(1500 + k * 70, 892))
	_p.icons = icons


func _build_scf() -> void:
	_scf = Node2D.new()
	add_child(_scf)
	PrintKit.rect(_scf, Rect2(0, 0, 1920, 1080), PAPER)
	var M: Dictionary = SCFBrand.SCF_MARK
	var discs := [M.discS, M.discC, M.discF]
	var cols := [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]
	var words := ["STORY", "CONTEXT", "FRAMEWORK"]
	var icons := ["doc", "nodes", "database"]
	_s.cols = []
	for i in 3:
		var col := MotionShape.new()
		col.kind = MotionShape.Kind.RECT
		col.anchor = Vector2.ZERO
		col.color = cols[i]
		col.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_scf.add_child(col)
		var letter := MotionText.new()
		letter.font = PrintKit.archivo()
		letter.line_height = 1.0
		letter.color = PAPER
		letter.text = "SCF"[i]
		col.add_child(letter)
		var fg := INK if i == 1 else PAPER
		var top := PrintKit.micro_at(col, "0%d\n%s" % [i + 1, words[i]], 40, 40, fg, 22)
		var ic := _icon(col, icons[i], 80, Vector2(40, 0), fg, cols[i])
		_s.cols.append({col = col, letter = letter, top = top, icon = ic, d = PrintKit.scf_disc(discs[i], SCF_X, SCF_Y, SCF_W)})
	_s.mark = PrintKit.logo(_scf, "scfMark", SCF_W, Vector2(SCF_X, SCF_Y))
	_s.rule = PrintKit.rect(_scf, Rect2(80, 150, 1760, 14), INK)
	_s.head = PrintKit.micro_at(_scf, "MINIMAL HUMANS PRESENTS / SCF — 1.0 / OPEN FORMAT", 80, 100)
	_s.sheet = PrintKit.micro_right(_scf, "", 80, 100)
	var full := PrintKit.logo(_scf, "scfFull", 800, Vector2(960, 236))
	full.crop = Rect2(108, 4, 175, 76)
	full.only = PackedInt32Array(SCFBrand.SCF_FULL.story + SCFBrand.SCF_FULL.context + SCFBrand.SCF_FULL.framework)
	_s.full = full

	var info := Node2D.new()
	info.position = Vector2(966, 640)
	_scf.add_child(info)
	var x := 0.0
	var rows := [["FORMAT", "SQLITE"], ["QUERIES", "16 CANONICAL"], ["LICENCE", "APACHE-2.0\nCC BY 4.0"], ["VERSION", "1.0"]]
	_s.vals = []
	for i in 4:
		var wcol: float = [150.0, 210.0, 200.0, 110.0][i]
		PrintKit.rect(info, Rect2(x, 0, wcol, 6), [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED, INK][i])
		var key := MotionText.new()
		key.font = PrintKit.mono_font(400)
		key.font_size = 14
		key.color = INK
		key.modulate.a = 0.7
		key.text = rows[i][0]
		key.position = Vector2(x, 16)
		info.add_child(key)
		var val := MotionText.new()
		val.font = PrintKit.mono_font(700)
		val.font_size = 18
		val.color = INK
		val.text = rows[i][1]
		val.position = Vector2(x, 16 + key.get_text_size().y)
		info.add_child(val)
		_s.vals.append(val)
		x += wcol + 46
	_s.info = info
	_s.regs = []
	for p in [Vector2(50, 50), Vector2(1870, 50), Vector2(50, 1030), Vector2(1870, 1030)]:
		_s.regs.append(PrintKit.add(_scf, PrintKit.reg(p.x, p.y)))
	_s.strip = PrintKit.add(_scf, PrintKit.strip(80, 900))
	_s.barcode = PrintKit.add(_scf, PrintKit.barcode(360, 900, 300, 40, 44))
	# five 70 px boxes, gap 14, a pictogram centred in each; one at a time reverses
	var row := Node2D.new()
	row.position = Vector2(1380, 884)
	_scf.add_child(row)
	_s.row = row
	_s.row_cells = []
	for i in ROW.size():
		var bg := PrintKit.rect(row, Rect2(i * 84, 0, 70, 70), INK)
		var ic := _icon(row, ROW[i], 50, Vector2(i * 84 + 10, 10))
		_s.row_cells.append({bg = bg, icon = ic})


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	for n in _layouts:
		n.visible = false
	_mh.visible = f >= 44 and f < 142
	for b in _bars:
		b.visible = _mh.visible
	_scf.visible = f >= 142
	if f < 44:
		var idx := 0
		for i in CUTS.size():
			if f >= CUTS[i]:
				idx = i
		_show_layout(idx % 5, floori(idx / 5.0) + idx % 3)
	elif f < 142:
		_frame_mh(f)
		for i in 3:
			var t := MK.map(f, [126 + i * 3, 138 + i * 3], [0, 1], MK.ease_in_out)
			_bars[i].position.y = 1080 - t * 1080
			_bars[i].size.y = t * 1080
	else:
		_frame_scf(f)


func _show_layout(n: int, v: int) -> void:
	_layouts[n].visible = true
	match n:
		0:
			_l.mh.position = Vector2(-60 + v * 40, 120)
		1:
			_l.rot.position = Vector2(300 + v * 80, -160) + _l.rot_half
		2:
			for i in 12:
				var inv := (i + v) % 5 == 0
				var cell: Dictionary = _l.cells[i]
				cell.box.color = INK if inv else Color(INK, 0.0)
				if cell.has("icon"):
					PrintKit.set_icon(cell.icon, cell.name, PAPER if inv else INK, INK if inv else PAPER)
				else:
					cell.logo.apply(func(j: int):
						if inv:
							return {fill = [SCFBrand.BLUE, SCFBrand.AMBER, PAPER][j]}
						return {fill = INK} if j == 2 else null)
			_l.sheet.text = "MINIMAL HUMANS™ — PRODUCT MH-001 — SHEET %d/12" % (v + 1)
		3:
			_l.disc.position = Vector2(960 + (v - 1) * 120, 540)
		4:
			_l.mhw.position = Vector2(60 - v * 50, 120)
			_l.bar.set_meta("seed", float(v * 31))
			_l.bar.queue_redraw()


func _frame_mh(f: float) -> void:
	var on := func(k: int) -> bool: return f >= 44 + k * 3
	_p.rule.visible = on.call(0)
	_p.head.visible = on.call(1)
	_p.sheet.visible = on.call(1)
	_p.logo.visible = on.call(2)
	var settled: bool = on.call(4)
	var words: bool = on.call(3)
	_p.logo.apply(func(j: int):
		if j <= 2:
			var d := {tx = 0.0 if settled else (2 - j) * -10.0, ty = 0.0 if settled else (2 - j) * -10.0}
			if j == 2:
				d.fill = INK
			return d
		return {fill = INK} if words and f >= 53 + floorf((j - 3) / 3.0) else {hide = true})
	_p.tm.visible = on.call(5)
	_p.presents.visible = on.call(6)
	_p.regs.visible = settled
	_p.strip.visible = on.call(7)
	_p.barcode.visible = on.call(7)
	_p.icons.visible = on.call(8)


func _frame_scf(f: float) -> void:
	var morph := MK.map(f, [176, 202], [0, 1], MK.ease_in_out)
	var logo_on := f >= 202
	var on := func(k: int) -> bool: return _live(f, k, 8, 204)
	var hold := f > 232 and f < OUT
	var disc_step := 1.0 if f < OUT + 20 else (0.66 if f < OUT + 23 else (0.33 if f < OUT + 26 else 0.0))
	for i in 3:
		var c: Dictionary = _s.cols[i]
		var col: MotionShape = c.col
		col.visible = not logo_on
		if logo_on:
			continue
		var r: float = c.d.r
		var pos := Vector2(lerpf(i * 640.0, c.d.c.x - r, morph), lerpf(0.0, c.d.c.y - r, morph))
		var sz := Vector2(lerpf(640.0, r * 2.0, morph), lerpf(1080.0, r * 2.0, morph))
		col.position = pos
		col.size = sz
		col.radius = lerpf(0.0, r, morph)
		var slide := maxf(0.0, 1.0 - floorf((f - 144 - i * 4) / 2.0) * 0.18) if f < 174 else 0.0
		var letter: MotionText = c.letter
		letter.font_size = lerpf(900.0, r * 1.5, morph)
		letter.position = (sz - letter.get_text_size()) * 0.5 + Vector2(0, slide * 1100.0)
		var fade := morph < 0.2
		c.top.visible = fade
		c.icon.visible = fade
		c.top.modulate.a = 1.0 - morph * 5.0
		c.icon.modulate.a = 1.0 - morph * 5.0
		c.icon.position.y = sz.y - 40 - 80 - PrintKit.STRUT_GAP
	var mark: MotionSvg = _s.mark
	mark.visible = logo_on
	if logo_on:
		var M: Dictionary = SCFBrand.SCF_MARK
		var d := SCFBrand.logo("scfMark")
		mark.apply(func(i: int):
			var disc := -1
			if i == M.discS or (M.S as Array).has(i):
				disc = M.discS
			elif i == M.discC or (M.C as Array).has(i):
				disc = M.discC
			elif i == M.discF or (M.F as Array).has(i):
				disc = M.discF
			if disc >= 0:
				if disc_step <= 0.0:
					return {hide = true}
				return {s = disc_step, pivot = (d.parts[disc].bbox as Rect2).get_center()}
			if (M.edges as Array).has(i):
				return null if f >= 206 and f < OUT + 16 else {hide = true}
			var k := (M.nodes as Array).find(i)
			if k >= 0:
				var vis := f >= 208 + floorf(MK.rand(k * 3) * 10.0) and f < OUT + 4 + floorf(MK.rand(k * 5) * 12.0)
				return {ty = sin(f / 14.0 + k) * 0.5 if hold else 0.0} if vis else {hide = true}
			return null)
	var rule: ColorRect = _s.rule
	rule.visible = f >= 204
	rule.size.x = 1760.0 if f < OUT + 21 else maxf(0.0, 1760.0 - floorf((f - OUT - 21) / 2.0) * 440.0)
	_s.head.visible = on.call(0)
	_s.sheet.visible = on.call(0)
	_s.sheet.text = "SHEET 02 / 02 · NO. %04d" % (mini(int(f), OUT) - 200)
	var F: Dictionary = SCFBrand.SCF_FULL
	_s.full.apply(func(j: int):
		var w := 0 if (F.story as Array).has(j) else (1 if (F.context as Array).has(j) else 2)
		return {fill = INK} if on.call(1 + w) else {hide = true})
	_s.info.visible = on.call(4)
	_s.vals[3].text = "1.0 ■" if hold and fmod(f, 30.0) < 15.0 else "1.0"
	for i in 4:
		var reg: Node2D = _s.regs[i]
		reg.visible = on.call(5)
		reg.rotation_degrees = (f - 232) * 0.8 * (-1.0 if i % 2 else 1.0) if hold else 0.0
	_s.strip.visible = on.call(6)
	_s.barcode.visible = on.call(6)
	_s.barcode.set_meta("seed", 44.0 + (floorf(f / 12.0) if hold else 0.0))
	_s.barcode.queue_redraw()
	_s.row.visible = on.call(7)
	for i in ROW.size():
		var inv := hold and posmod(floori((f - 232) / 18.0), ROW.size()) == i
		var cell: Dictionary = _s.row_cells[i]
		cell.bg.visible = inv
		PrintKit.set_icon(cell.icon, ROW[i], PAPER if inv else INK, INK if inv else PAPER)
