# SPDX-License-Identifier: Apache-2.0
# B — PRINT, ported from scf-intros src/intros/B_Print.tsx.
# Designers Republic poster logic: paper, ink, flat fluoro fields, micro-type,
# registration marks. Motion is hard cuts and layout jumps, not easing.
@tool
extends MotionComposition

const PAPER := PrintKit.PAPER
const INK := PrintKit.INK
const FLICKER := [0, 7, 13, 18, 22, 26, 29, 32, 35, 38, 41, 44, 47]
const SCF_W := 760.0
const SCF_X := 110.0
const SCF_Y := 236.0

var _built := false
var _layouts: Array[Node2D] = []
var _l: Dictionary = {}          # named nodes of the flicker layouts
var _mh: MotionFX                # MH poster (an isolated group so invert() covers it alone)
var _p: Dictionary = {}          # MH poster nodes
var _bars: Array[ColorRect] = []
var _scf: Node2D
var _s: Dictionary = {}          # SCF poster nodes


func _init() -> void:
	duration = 300
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


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


func _build_layouts() -> void:
	# 0: paper, giant MH, red dot
	var l0 := _layout_root(PAPER)
	_l.mh = PrintKit.big("MH", 1100, INK)
	l0.add_child(_l.mh)
	var dot := MotionShape.circle(220, SCFBrand.RED)
	dot.position = Vector2(230, 220)
	l0.add_child(dot)
	PrintKit.micro_right(l0, "MINIMAL HUMANS™\nPRODUCT MH-001\nBERLIN / DE\nFREE + OPEN SOURCE", 80, 120)
	l0.add_child(PrintKit.reg(80, 80))
	l0.add_child(PrintKit.reg(1840, 1000))

	# 1: red, the M's cream face turned on its side, vertical Japanese
	var l1 := _layout_root(SCFBrand.RED)
	var rot := Node2D.new()
	l1.add_child(rot)
	_l.rot = rot
	var m := PrintKit.logo(rot, "mhM", 1300, Vector2.ZERO)
	m.only = PackedInt32Array([2])
	m.apply(func(_i): return {fill = PAPER})
	var mh := m.get_size()
	_l.rot_half = Vector2(mh.x, mh.y + PrintKit.STRUT_GAP) * 0.5   # the wrapping div's centre
	m.position = -_l.rot_half
	rot.rotation_degrees = -90.0
	PrintKit.vjp(l1, SCFBrand.JP.mh, 96, INK, 0.1, 120, 120)
	var tm := PrintKit.micro_at(l1, "™ ©\nMH/001", 80, 0)
	tm.position.y = 1080 - 70 - tm.get_text_size().y

	# 2: a sheet of twelve M marks, every fifth one reversed
	var l2 := _layout_root(PAPER)
	_l.cells = []
	for i in 12:
		var bw := 8.0 if i == 6 else 2.0
		var pos := Vector2(140 + (i % 4) * 420, 110 + floorf(i / 4.0) * 300)
		var box := MotionShape.new()
		box.kind = MotionShape.Kind.RECT
		box.anchor = Vector2.ZERO
		box.size = Vector2(380, 270)            # border-box
		box.position = pos
		box.border_width = bw
		box.border_color = SCFBrand.RED if i == 6 else INK
		l2.add_child(box)
		var lm := PrintKit.logo(l2, "mhM", 180, Vector2.ZERO)
		lm.position = pos + Vector2(bw, bw) + (Vector2(380, 270) - Vector2(bw, bw) * 2.0 - lm.get_size()) * 0.5
		_l.cells.append({box = box, logo = lm})
	_l.sheet = PrintKit.micro_at(l2, "", 140, 1010)

	# 3: blue, MINIMAL HUMANS, barcode
	var l3 := _layout_root(SCFBrand.BLUE)
	_l.mhw = PrintKit.big("MINIMAL\nHUMANS", 400, PAPER)
	l3.add_child(_l.mhw)
	_l.bar3 = PrintKit.barcode(80, 880, 520, 120, 0, PAPER)
	l3.add_child(_l.bar3)
	var est := PrintKit.micro_right(l3, "EST. BERLIN\n™", 80, 0, PAPER)
	est.position.y = 1080 - 70 - est.get_text_size().y

	# 4: amber, an ink disc with 提供
	var l4 := _layout_root(SCFBrand.AMBER)
	var disc := Node2D.new()
	l4.add_child(disc)
	_l.disc = disc
	disc.add_child(MotionShape.circle(820, INK))
	var jp := MotionText.new()
	jp.font = SCFBrand.font("jp", 900)
	jp.font_size = 380
	jp.color = PAPER
	jp.text = SCFBrand.JP.presents
	jp.position = -jp.get_text_size() * 0.5
	disc.add_child(jp)
	PrintKit.micro_at(l4, "PRESENTED BY\nMINIMAL HUMANS", 80, 80)
	l4.add_child(PrintKit.reg(1840, 80))

	# 5: ink, the MH code glyphs stretched tall
	var l5 := _layout_root(INK)
	var code := PrintKit.logo(l5, "mhShort", 1500, Vector2.ZERO)
	code.only = PackedInt32Array(SCFBrand.MH_SHORT_CODE)
	code.apply(func(_i): return {tx = -142.0, ty = -40.0})
	_l.code = code
	_l.code_h = code.get_size().y + PrintKit.STRUT_GAP
	_l.code_mh = PrintKit.micro_at(l5, "", 80, 0, SCFBrand.AMBER)


func _build_mh() -> void:
	_mh = MotionFX.new()
	add_child(_mh)
	var c := _mh.content
	PrintKit.rect(c, Rect2(0, 0, 1920, 1080), PAPER)
	_p.rule = PrintKit.rect(c, Rect2(80, 150, 1760, 14), INK)
	_p.head = PrintKit.micro_at(c, "MH—001 / BERLIN DE / FREE + OPEN SOURCE / A STUDIO OF TWO", 80, 100)
	_p.sheet = PrintKit.micro_right(c, "SHEET 01 / 02", 80, 100)
	_p.logo = PrintKit.logo(c, "mhFull", 1560, Vector2(80, 236))
	_p.tm = PrintKit.micro_at(c, "™", 1650, 236, INK, 40)

	# PRESENTS 提供 on an ink block: flex, gap 30, baseline-aligned, padding 16 30 10
	var box := Node2D.new()
	box.position = Vector2(547, 680)
	c.add_child(box)
	var t1 := MotionText.new()
	t1.font = SCFBrand.font("inter", 900)
	t1.font_size = 92
	t1.color = PAPER
	t1.tracking = 0.04
	t1.text = "PRESENTS"
	var t2 := MotionText.new()
	t2.font = SCFBrand.font("jp", 900)
	t2.font_size = 70
	t2.color = SCFBrand.RED
	t2.text = SCFBrand.JP.presents
	var asc := maxf(t1.get_baseline(), t2.get_baseline())
	var y1 := asc - t1.get_baseline()
	var y2 := asc - t2.get_baseline()
	var ch := maxf(y1 + t1.get_text_size().y, y2 + t2.get_text_size().y)
	var w := 30 + t1.get_text_size().x + 30 + t2.get_text_size().x + 30
	PrintKit.rect(box, Rect2(0, 0, w, 16 + ch + 10), INK)
	t1.position = Vector2(30, 16 + y1)
	t2.position = Vector2(30 + t1.get_text_size().x + 30, 16 + y2)
	box.add_child(t1)
	box.add_child(t2)
	_p.presents = box

	_p.jp = PrintKit.vjp(c, SCFBrand.JP.mh, 40, SCFBrand.RED, 0.2, 70, 240)
	_p.strip = PrintKit.add(c, PrintKit.strip(80, 860))
	_p.barcode = PrintKit.add(c, PrintKit.barcode(360, 860, 300, 40, 9))
	_p.blurb = PrintKit.micro_at(c, "A FREE + OPEN SOURCE STUDIO\nFROM BERLIN — PRESENTS ITS FIRST OPEN FORMAT", 720, 862)
	_p.regs = PrintKit.regs(c)
	_p.ticker = PrintKit.Ticker.new(960, "MINIMAL HUMANS PRESENTS", SCFBrand.RED, INK, 14)
	c.add_child(_p.ticker)


func _build_scf() -> void:
	_scf = Node2D.new()
	add_child(_scf)
	PrintKit.rect(_scf, Rect2(0, 0, 1920, 1080), PAPER)
	var M: Dictionary = SCFBrand.SCF_MARK
	var discs := [M.discS, M.discC, M.discF]
	var cols := [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]
	var words := ["STORY", "CONTEXT", "FRAMEWORK"]
	var kanji := ["物語", "文脈", "構造"]
	_s.cols = []
	for i in 3:
		# A coloured column that rounds into its disc; overflow: hidden clips the letter.
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
		var top := PrintKit.micro_at(col, "0%d\n%s" % [i + 1, words[i]], 40, 40, fg)
		var bot := PrintKit.micro_at(col, kanji[i], 40, 0, fg, 40)
		_s.cols.append({col = col, letter = letter, top = top, bot = bot, d = PrintKit.scf_disc(discs[i], SCF_X, SCF_Y, SCF_W)})
	_s.mark = PrintKit.logo(_scf, "scfMark", SCF_W, Vector2(SCF_X, SCF_Y))
	_s.rule = PrintKit.rect(_scf, Rect2(80, 150, 1760, 14), INK)
	_s.head = PrintKit.micro_at(_scf, "MINIMAL HUMANS PRESENTS / SCF — 1.0 / OPEN FORMAT", 80, 100)
	_s.sheet = PrintKit.micro_right(_scf, "SHEET 02 / 02", 80, 100)
	var full := PrintKit.logo(_scf, "scfFull", 800, Vector2(960, 236))
	full.crop = Rect2(108, 4, 175, 76)
	full.only = PackedInt32Array(SCFBrand.SCF_FULL.story + SCFBrand.SCF_FULL.context + SCFBrand.SCF_FULL.framework)
	_s.full = full

	# FORMAT / QUERIES / LICENCE / VERSION: flex row, gap 46
	var info := Node2D.new()
	info.position = Vector2(966, 640)
	_scf.add_child(info)
	var x := 0.0
	var rows := [["FORMAT", "SQLITE"], ["QUERIES", "16 CANONICAL"], ["LICENCE", "APACHE-2.0\nCC BY 4.0"], ["VERSION", "1.0"]]
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
		x += wcol + 46
	_s.info = info
	_s.jp = PrintKit.vjp(_scf, SCFBrand.JP.scf, 32, SCFBrand.BLUE, 0.12, 70, 236)
	_s.regs = PrintKit.regs(_scf)
	_s.strip = PrintKit.add(_scf, PrintKit.strip(80, 860))
	_s.barcode = PrintKit.add(_scf, PrintKit.barcode(360, 860, 300, 40, 44))
	_s.ticker = PrintKit.Ticker.new(960, "STORY CONTEXT FRAMEWORK", INK, PAPER, -14)
	_scf.add_child(_s.ticker)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var fi := int(floorf(f))
	for n in _layouts:
		n.visible = false
	_mh.visible = f >= 48 and f < 142
	for b in _bars:
		b.visible = _mh.visible
	_scf.visible = f >= 142
	if f < 48:
		var idx := 0
		for i in FLICKER.size():
			if f >= FLICKER[i]:
				idx = i
		_show_layout(idx % 6, floori(idx / 6.0) + idx % 3)
	elif f < 142:
		_frame_mh(f, fi)
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
			_l.rot.position = Vector2(360 + v * 80, -160) + _l.rot_half
		2:
			for i in 12:
				var inv := (i + v) % 5 == 0
				var cell: Dictionary = _l.cells[i]
				cell.box.color = INK if inv else Color(INK, 0.0)
				cell.logo.apply(func(j: int):
					if inv:
						return {fill = [SCFBrand.BLUE, SCFBrand.AMBER, PAPER][j]}
					return {fill = INK} if j == 2 else null)
			_l.sheet.text = "MINIMAL HUMANS™ — PRODUCT MH-001 — SHEET %d/12" % (v + 1)
		3:
			_l.mhw.position = Vector2(60 - v * 50, 120)
			_l.bar3.set_meta("seed", float(v * 31))
			_l.bar3.queue_redraw()
		4:
			_l.disc.position = Vector2(960 + (v - 1) * 120, 540)
		5:
			# A div (svg + strut) that flex centres, 900 px of left margin, scaleY(3 + v).
			var s := 3.0 + v
			var top: float = 540.0 - _l.code_h * 0.5
			_l.code.position = Vector2((1920.0 - 2400.0) * 0.5 + 900.0, 540.0 + (top - 540.0) * s)
			_l.code.scale = Vector2(1, s)
			_l.code_mh.text = "MH—%03d" % (v * 7 + 1)
			_l.code_mh.position.y = 1080 - 70 - _l.code_mh.get_text_size().y


func _frame_mh(f: float, fi: int) -> void:
	var on := func(k: int) -> bool: return f >= 48 + k * 3
	_mh.invert = 1.0 if [92, 93, 108, 109].has(fi) else 0.0
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
		return {fill = INK} if words and f >= 57 + floorf((j - 3) / 3.0) else {hide = true})
	_p.tm.visible = on.call(5)
	_p.presents.visible = on.call(6)
	_p.jp.visible = on.call(7)
	_p.strip.visible = on.call(8)
	_p.barcode.visible = on.call(8)
	_p.blurb.visible = on.call(9)
	_p.regs.visible = settled
	_p.ticker.visible = on.call(10)
	_p.ticker.update(f)


func _frame_scf(f: float) -> void:
	var morph := MK.map(f, [178, 204], [0, 1], MK.ease_in_out)
	var logo_on := f >= 204
	var on := func(k: int) -> bool: return f >= 206 + k * 3
	var nudge := func(k: int) -> bool: return f > 240 and posmod(floori((f - 240) / 12.0), 3) == k
	for i in 3:
		var c: Dictionary = _s.cols[i]
		var col: MotionShape = c.col
		col.visible = not logo_on
		if logo_on:
			continue
		var d: Dictionary = c.d
		var r: float = d.r
		var pos := Vector2(lerpf(i * 640.0, d.c.x - r, morph), lerpf(0.0, d.c.y - r, morph))
		var sz := Vector2(lerpf(640.0, r * 2.0, morph), lerpf(1080.0, r * 2.0, morph))
		col.position = pos
		col.size = sz
		col.radius = lerpf(0.0, r, morph)
		var slide := maxf(0.0, 1.0 - floorf((f - 144 - i * 4) / 2.0) * 0.18) if f < 176 else 0.0
		var letter: MotionText = c.letter
		letter.font_size = lerpf(900.0, r * 1.5, morph)
		var ts := letter.get_text_size()
		letter.position = (sz - ts) * 0.5 + Vector2(0, slide * 1100.0)
		var fade := morph < 0.2
		c.top.visible = fade
		c.bot.visible = fade
		c.top.modulate.a = 1.0 - morph * 5.0
		c.bot.modulate.a = 1.0 - morph * 5.0
		c.bot.position.y = sz.y - 40 - c.bot.get_text_size().y
	var mark: MotionSvg = _s.mark
	mark.visible = logo_on
	if logo_on:
		var M: Dictionary = SCFBrand.SCF_MARK
		mark.apply(func(i: int):
			if (M.edges as Array).has(i):
				return null if f >= 206 else {hide = true}
			var k := (M.nodes as Array).find(i)
			if k >= 0:
				return null if f >= 208 + floorf(MK.rand(k * 3) * 10.0) else {hide = true}
			return null)
	_s.rule.visible = on.call(0)
	_s.head.visible = on.call(0)
	_s.sheet.visible = on.call(0)
	var F: Dictionary = SCFBrand.SCF_FULL
	_s.full.visible = on.call(1)
	_s.full.apply(func(j: int):
		var w := 0 if (F.story as Array).has(j) else (1 if (F.context as Array).has(j) else 2)
		if not on.call(1 + w):
			return {hide = true}
		var n: bool = nudge.call(w)
		return {fill = SCFBrand.RED if n and w == 1 else INK, tx = 3.0 if n and w != 1 else 0.0})
	_s.info.visible = on.call(4)
	_s.jp.visible = on.call(5)
	_s.regs.visible = on.call(5)
	_s.strip.visible = on.call(6)
	_s.barcode.visible = on.call(6)
	_s.ticker.visible = on.call(7)
	_s.ticker.update(f)
