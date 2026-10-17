# SPDX-License-Identifier: Apache-2.0
# B2 — SPECIMEN, ported from scf-intros src/intros/B2_Specimen.tsx.
# A 12 × 6 modular grid is the whole poster. Cells fill like a type-specimen
# sheet, clear to make room for each lockup, flip to colour in a diagonal
# sweep between beats, and empty out cell by cell at the end.
@tool
extends MotionComposition

const PAPER := PrintKit.PAPER
const INK := PrintKit.INK
const COLS := 12
const ROWS := 6
const CW := 160.0
const CH := 180.0
const OUT := 352
const ICONS := PrintKit.ICON_NAMES

var _built := false
var _grid: MotionCanvas
var _cells: Array = []        # {bg, icon, num}
var _p: Dictionary = {}


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


static func _cols3() -> Array:
	return [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]


## What a cell shows for a given salt: an icon, its number, a colour fill or nothing.
static func _content(r: int, c: int, salt: float) -> Dictionary:
	var x := MK.rand(r * 37 + c * 11 + salt * 101)
	if x < 0.42:
		return {kind = "icon", icon = ICONS[int(floorf(MK.rand(r * 7 + c * 3 + salt) * ICONS.size()))]}
	if x < 0.66:
		return {kind = "num", n = "%02d" % (r * COLS + c + 1)}
	if x < 0.8:
		return {kind = "fill", col = _cols3()[posmod(int(r + c + salt), 3)]}
	return {kind = "none"}


static func _in_block(r: int, c: int) -> bool:
	return r >= 1 and r <= 4 and c >= 1 and c <= 10


func _text(parent: Node, font: Font, size: float, col: Color, track := 0.0, txt := "") -> MotionText:
	var t := MotionText.new()
	t.font = font
	t.font_size = size
	t.color = col
	t.tracking = track
	t.text = txt
	parent.add_child(t)
	return t


func _build() -> void:
	_built = true
	PrintKit.rect(self, Rect2(0, 0, 1920, 1080), PAPER)
	_grid = MotionCanvas.new()
	add_child(_grid)
	_grid.draw_fn = _draw_grid
	for r in ROWS:
		for c in COLS:
			var o := Vector2(c * CW, r * CH)
			var bg := PrintKit.rect(self, Rect2(o, Vector2(CW, CH)), INK)
			var ic := PrintKit.icon("skull", 86)
			ic.position = o + (Vector2(CW, CH) - Vector2(86, 86)) * 0.5
			add_child(ic)
			var num := _text(self, PrintKit.archivo(), 96, INK, -0.04, "00")
			_cells.append({bg = bg, icon = ic, num = num, o = o})

	# beat 1: MH
	var mh := Node2D.new()
	add_child(mh)
	_p.mh = mh
	_p.mono = PrintKit.logo(mh, "mhM", 430, Vector2(CW + 22, CH + 40))
	_p.mono.apply(func(j: int): return {fill = INK} if j == 2 else null)
	var word := PrintKit.logo(mh, "mhFull", 1080, Vector2(4 * CW + 20, CH + 40))
	word.crop = Rect2(140, 0, 346, 129)
	word.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_p.word = word

	var pres := Node2D.new()
	add_child(pres)
	_p.presents = pres
	PrintKit.rect(pres, Rect2(4 * CW, 4 * CH, 4 * CW, CH), INK)
	var pt := _text(pres, SCFBrand.font("inter", 900), 84, PAPER, 0.03, "PRESENTS")
	pt.position = Vector2(4 * CW + 30, 4 * CH + (CH - pt.get_text_size().y) * 0.5)
	var arrow := Node2D.new()
	pres.add_child(arrow)
	_p.arrow = arrow
	PrintKit.rect(arrow, Rect2(8 * CW, 4 * CH, CW, CH), SCFBrand.RED)
	var ai := PrintKit.icon("arrow", 96)
	ai.position = Vector2(8 * CW, 4 * CH) + (Vector2(CW, CH) - Vector2(96, 96)) * 0.5
	arrow.add_child(ai)
	var blurb := _text(pres, PrintKit.mono_font(700), 18, INK, 0.0, "MH—001\nBERLIN DE\nFREE + OPEN\nSOURCE")
	blurb.line_height = 1.4
	blurb.position = Vector2(CW + 20, 4 * CH + 20)

	# beat 2: SCF
	_p.mark = PrintKit.logo(self, "scfMark", 600, Vector2(CW + 30, CH + 120))
	var full := PrintKit.logo(self, "scfFull", 850, Vector2(6 * CW + 10, CH + 26))
	full.crop = Rect2(108, 4, 175, 76)
	full.only = PackedInt32Array(SCFBrand.SCF_FULL.story + SCFBrand.SCF_FULL.context + SCFBrand.SCF_FULL.framework)
	_p.full = full

	var facts := Node2D.new()
	add_child(facts)
	_p.facts = facts
	_p.fact_cells = []
	var specs := [{icon = "database", label = "SQLITE"}, {num = "16", label = "QUERIES"}, {num = "1.0", label = "VERSION"}, {icon = "check", label = "OPEN"}]
	for i in 4:
		var spec: Dictionary = specs[i]
		var cell := Node2D.new()
		cell.position = Vector2((6 + i) * CW, 4 * CH)
		facts.add_child(cell)
		if i == 3:
			PrintKit.rect(cell, Rect2(0, 0, CW, CH), INK)
		var fg := PAPER if i == 3 else INK
		var label := _text(cell, PrintKit.mono_font(700), 16, fg, 0.0, spec.label)
		# flex column, centred, gap 10: a 70 px pictogram or number over the label
		var top := (CH - (70 + 10 + label.get_text_size().y)) * 0.5
		if spec.has("icon"):
			var ic := PrintKit.icon(spec.icon, 70, fg, INK if i == 3 else PAPER)
			ic.position = Vector2((CW - 70) * 0.5, top)
			cell.add_child(ic)
		else:
			var n := _text(cell, PrintKit.archivo(), 70, INK, 0.0, spec.num)
			n.line_height = 1.0
			n.position = Vector2((CW - n.get_text_size().x) * 0.5, top)
		label.position = Vector2((CW - label.get_text_size().x) * 0.5, top + 80)
		_p.fact_cells.append(cell)
	var heart := Node2D.new()
	facts.add_child(heart)
	_p.heart = heart
	PrintKit.rect(heart, Rect2(10 * CW, 4 * CH, CW, CH), SCFBrand.BLUE)
	var hi := PrintKit.icon("heart", 86, PAPER, SCFBrand.BLUE)
	hi.position = Vector2(10 * CW, 4 * CH) + (Vector2(CW, CH) - Vector2(86, 86)) * 0.5
	heart.add_child(hi)
	var head := _text(facts, PrintKit.mono_font(700), 18, INK, 0.06, "MINIMAL HUMANS PRESENTS")
	head.position = Vector2(CW + 20, CH + 18)


func _draw_grid(cv: MotionCanvas, f: float) -> void:
	var g := MK.map(f, [0, 18], [0, 1]) * (1.0 - MK.map(f, [OUT + 30, OUT + 46], [0, 1]))
	for c in COLS + 1:
		var y2 := 1080.0 * minf(1.0, g * 1.4 - c * 0.02)
		cv.line(Vector2(c * CW, 0), Vector2(c * CW, y2), INK, 2.0, 0.5)
	for r in ROWS + 1:
		var x2 := 1920.0 * minf(1.0, g * 1.4 - r * 0.04)
		cv.line(Vector2(0, r * CH), Vector2(x2, r * CH), INK, 2.0, 0.5)


func _frame(f: float) -> void:
	if not _built:
		return
	var beat := 1 if f < 160 else 2
	for r in ROWS:
		for c in COLS:
			_cell(_cells[r * COLS + c], r, c, f, beat)

	_p.mh.visible = f >= 74 and f < 136
	_p.word.apply(func(j: int): return {fill = INK} if f >= 76 + floorf((j - 3) * 0.6) else {hide = true})
	_p.presents.visible = f >= 84 and f < 136
	_p.arrow.visible = f >= 88

	var scf_on := func(k: int) -> bool: return f >= 168 + k * 3 and f < OUT + [10, 8, 6, 4, 2][k] * 1.5
	var M: Dictionary = SCFBrand.SCF_MARK
	_p.mark.visible = scf_on.call(0)
	_p.mark.apply(func(i: int):
		if (M.edges as Array).has(i):
			return null if scf_on.call(1) else {hide = true}
		var k := (M.nodes as Array).find(i)
		if k >= 0:
			if f >= 174 + floorf(MK.rand(k * 3) * 10.0) and scf_on.call(2):
				return {ty = sin(f / 14.0 + k) * 0.5 if (f > 230 and f < OUT) else 0.0}
			return {hide = true}
		return null)
	var F: Dictionary = SCFBrand.SCF_FULL
	_p.full.apply(func(j: int):
		var w := 0 if (F.story as Array).has(j) else (1 if (F.context as Array).has(j) else 2)
		return {fill = INK} if f >= 182 + w * 4 and scf_on.call(3) else {hide = true})
	_p.facts.visible = scf_on.call(4)
	for i in 4:
		_p.fact_cells[i].visible = f >= 196 + i * 3
	_p.heart.visible = f >= 208


func _cell(cell: Dictionary, r: int, c: int, f: float, beat: int) -> void:
	var bg: ColorRect = cell.bg
	var ic: MotionSvg = cell.icon
	var num: MotionText = cell.num
	bg.visible = false
	ic.visible = false
	num.visible = false
	var diag := r + c
	if f >= OUT + (16 - diag) * 1.5:
		return
	if f >= 132 + diag and f < 160 + diag:          # the colour sweep between beats
		bg.visible = true
		bg.color = _cols3()[diag % 3]
		return
	var appear := (16.0 if beat == 1 else 160.0) + MK.rand(r * 13 + c * 29) * (44.0 if beat == 1 else 30.0)
	if f < appear:
		return
	if _in_block(r, c) and f >= (62.0 + c if beat == 1 else 160.0):
		return
	var border := not _in_block(r, c)
	var settled := f > appear + 12
	var keep := MK.rand(r * 5 + c * 17 + beat) < 0.32
	if settled and (not border or not keep):
		return
	var salt := (beat * 7 + floorf(maxf(0.0, f - 90) / 40.0) * (1 if r == 0 else 0)) if settled else floorf(f / 3.0)
	var inv := settled and posmod(floori(f / 24.0), 9) == (r * 3 + c) % 9 \
		and ((beat == 1 and f > 90 and f < 130) or (beat == 2 and f > 230 and f < OUT))
	var ct := _content(r, c, salt)
	inv = inv and (ct.kind == "icon" or ct.kind == "num")
	if ct.kind == "fill":
		bg.visible = true
		bg.color = ct.col
	elif inv:
		bg.visible = true
		bg.color = INK
	var fg := PAPER if inv else INK
	if ct.kind == "icon":
		ic.visible = true
		PrintKit.set_icon(ic, ct.icon, fg, INK if inv else PAPER)
	elif ct.kind == "num":
		num.visible = true
		num.text = ct.n
		num.color = fg
		num.position = cell.o + (Vector2(CW, CH) - num.get_text_size()) * 0.5
