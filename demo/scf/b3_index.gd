# SPDX-License-Identifier: Apache-2.0
# B3 — INDEX, ported from scf-intros src/intros/B3_Index.tsx.
# A technical plate: one spot colour per beat (red, then blue), a giant
# figure number, dimension lines and leader lines that label the parts.
# All motion is stepped, like pages of a catalogue being registered.
@tool
extends MotionComposition

const PAPER := PrintKit.PAPER
const INK := PrintKit.INK
const OUT := 352
# beat 1 geometry
const MW := 380.0
const MX := 520.0
const MY := 250.0
const WX := 980.0
const WY := 262.0
const WW := 900.0
# beat 2 geometry
const SW := 640.0
const SX := 330.0
const SY := 250.0
const LABELS := [
	{key = "S", crop = [109, 4.5, 85, 26], icon = "doc", y = 200},
	{key = "C", crop = [109, 30.5, 118, 25], icon = "nodes", y = 470},
	{key = "F", crop = [111, 54.5, 171, 25], icon = "database", y = 740},
]

var _built := false
var _mk := 1.0           # px per mhM logo unit
var _n: Dictionary = {}
var _discs: Array = []   # beat-2 disc centres and radii, S C F


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


## Stepped 0..1: `steps` hard steps, `gap` frames apart, from frame a.
static func _st(f: float, a: float, steps := 3.0, gap := 2.0) -> float:
	return clampf(floorf((f - a) / gap + 1.0) / steps, 0.0, 1.0)


func _text(parent: Node, font: Font, size: float, col: Color, txt := "", track := 0.0) -> MotionText:
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
	_mk = MW / SCFBrand.logo("mhM").view_box.size.x
	var mark := SCFBrand.logo("scfMark")
	var sk := SW / mark.view_box.size.x
	var M: Dictionary = SCFBrand.SCF_MARK
	for d in [M.discS, M.discC, M.discF]:
		var bb: Rect2 = mark.parts[d].bbox
		_discs.append({c = Vector2(SX, SY) + bb.get_center() * sk, r = bb.size.x * 0.5 * sk, d = "%.1f" % bb.size.x, pivot = bb.get_center()})

	_n.fig = PrintKit.big("01", 900, SCFBrand.RED)
	_n.fig.modulate.a = 0.16
	add_child(_n.fig)
	_n.rule = PrintKit.rect(self, Rect2(80, 120, 0, 10), INK)
	_n.head = PrintKit.micro_at(self, "", 80, 76)
	_n.plate = PrintKit.micro_right(self, "", 80, 76)

	# Dashed guides sit under the logos; dimension arrows, centre marks and
	# leader lines are drawn over them (the order of the original's <svg>s).
	_n.under = MotionCanvas.new()
	add_child(_n.under)
	_n.under.draw_fn = _draw_guides

	# beat 1
	var b1 := Node2D.new()
	add_child(b1)
	_n.b1 = b1
	_n.mono = PrintKit.logo(b1, "mhM", MW, Vector2(MX, MY))
	var word := PrintKit.logo(b1, "mhFull", WW, Vector2(WX, WY))
	word.crop = Rect2(140, 0, 346, 129)
	word.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_n.word = word
	var wk := WW / 346.0
	_n.index = []
	var full := SCFBrand.logo("mhFull")
	var parts: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
	for n in parts.size():
		var j: int = parts[n]
		var b: Rect2 = full.parts[j].bbox
		var t := _text(b1, PrintKit.mono_font(700), 15, SCFBrand.RED, "%02d" % (n + 1))
		t.align = HORIZONTAL_ALIGNMENT_CENTER
		t.box_width = 24
		t.position = Vector2(WX + (b.position.x - 140 + b.size.x / 2) * wk - 12, WY + (-36.0 if b.position.y < 60 else 360.0))
		_n.index.append({t = t, j = j})
	_n.dim_h = _text(b1, PrintKit.mono_font(700), 18, SCFBrand.RED, "120.6")
	_n.dim_v = _text(b1, PrintKit.mono_font(700), 18, SCFBrand.RED, "120.6")
	var pres := Node2D.new()
	pres.position = Vector2(WX, 800)
	b1.add_child(pres)
	_n.pres = pres
	_n.pres_arrow = PrintKit.icon("arrow", 84, SCFBrand.RED)
	_n.pres_arrow.position = Vector2(0, 10)        # 84 px centred on the 104 px line
	pres.add_child(_n.pres_arrow)
	var pt := _text(pres, PrintKit.archivo(), 104, INK, "PRESENTS", -0.03)
	pt.line_height = 1.0
	pt.position = Vector2(84 + 24, 0)
	_n.blurb = PrintKit.micro_at(b1, "A FREE + OPEN SOURCE STUDIO · BERLIN", WX, 940)

	# beat 2
	var b2 := Node2D.new()
	add_child(b2)
	_n.b2 = b2
	_n.mark = PrintKit.logo(b2, "scfMark", SW, Vector2(SX, SY))
	b2.move_child(_n.mark, 0)
	_n.labels = []
	var F: Dictionary = SCFBrand.SCF_FULL
	var words := [F.story, F.context, F.framework]
	for n in 3:
		var L: Dictionary = LABELS[n]
		var row := Node2D.new()
		row.position = Vector2(1180, L.y)
		b2.add_child(row)
		var box := MotionShape.new()
		box.kind = MotionShape.Kind.RECT
		box.anchor = Vector2.ZERO
		box.size = Vector2(110, 110)
		box.color = INK if n == 1 else Color(INK, 0.0)
		box.border_width = 3
		box.border_color = INK
		row.add_child(box)
		var ic := PrintKit.icon(L.icon, 70, PAPER if n == 1 else INK, INK if n == 1 else PAPER)
		ic.position = Vector2(20, 20)
		row.add_child(ic)
		# the column: a line of mono type over the word, centred on the 110 px box
		var cap := _text(row, PrintKit.mono_font(700), 18, SCFBrand.BLUE, "%s — 0%d · Ø %s" % [L.key, n + 1, _discs[n].d])
		var crop: Array = L.crop
		var lw := float(crop[2]) / float(crop[3]) * 80.0
		var col_h := cap.get_text_size().y + 80.0 + PrintKit.STRUT_GAP
		var top := (110.0 - col_h) * 0.5
		cap.position = Vector2(136, top)
		var clip := Control.new()      # overflow: hidden on the cropped svg
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.position = Vector2(136, top + cap.get_text_size().y)
		clip.size = Vector2(lw, 80)
		row.add_child(clip)
		var w := MotionSvg.new()
		w.data = SCFBrand.logo("scfFull")
		w.width = lw
		w.crop = Rect2(crop[0], crop[1], crop[2], crop[3])
		w.only = PackedInt32Array(words[n])
		w.apply(func(_i): return {fill = INK})
		clip.add_child(w)
		_n.labels.append(row)

	var foot := Node2D.new()
	foot.position = Vector2(80, 930)
	b2.add_child(foot)
	_n.foot = foot
	var m0 := PrintKit.micro_at(foot, "MINIMAL HUMANS PRESENTS", 0, 0)
	var row_h := 30.0
	var my := (row_h - m0.get_text_size().y) * 0.5
	m0.position.y = my
	var x := m0.get_text_size().x + 40
	_n.foot_groups = []
	var groups := [["database", "SQLITE"], ["check", "OPEN FORMAT"], ["heart", "1.0"]]
	for i in 3:
		var g := Node2D.new()
		g.position = Vector2(x, 0)
		foot.add_child(g)
		var gi := PrintKit.icon(groups[i][0], 30, SCFBrand.BLUE if i == 2 else INK)
		g.add_child(gi)
		var gt := PrintKit.micro_at(g, groups[i][1], 40, my)
		x += 40 + gt.get_text_size().x + 40
		_n.foot_groups.append(g)

	_n.over = MotionCanvas.new()
	add_child(_n.over)
	_n.over.draw_fn = _draw_lines
	_n.bar = PrintKit.rect(self, Rect2(0, 0, 0, 1080), INK)


# ------------------------------------------------------------------ lines

func _arrow_head(cv: MotionCanvas, p: Vector2, dir: float, vertical: bool, col: Color) -> void:
	var pts := PackedVector2Array([p, p + Vector2(-7, 14 * dir), p + Vector2(7, 14 * dir)]) if vertical \
		else PackedVector2Array([p, p + Vector2(14 * dir, -7), p + Vector2(14 * dir, 7)])
	cv.polygon(pts, col, Color(0, 0, 0, 0))


func _dim(cv: MotionCanvas, a: Vector2, b: Vector2, t: float, col: Color, vertical: bool) -> void:
	if t <= 0.0:
		return
	cv.line(a, a.lerp(b, t), col, 2.0)
	_arrow_head(cv, a, 1.0, vertical, col)
	if t >= 1.0:
		_arrow_head(cv, b, -1.0, vertical, col)


func _guides(cv: MotionCanvas, c: Vector2, t: float) -> void:
	if t <= 0.0:
		return
	cv.dashed(c - Vector2(2000 * t, 0), c + Vector2(2000 * t, 0), INK, 1.0, 6, 8, 0.35)
	cv.dashed(c - Vector2(0, 1200 * t), c + Vector2(0, 1200 * t), INK, 1.0, 6, 8, 0.35)


func _draw_guides(cv: MotionCanvas, f: float) -> void:
	if f < 140:
		_guides(cv, Vector2(MX, MY) + Vector2(60.3, 60.3) * _mk, MK.map(f, [10, 26], [0, 1]))
	elif f >= 150:
		_guides(cv, _discs[1].c, MK.map(f, [150, 166], [0, 1]) * (1.0 - MK.map(f - OUT, [24, 34], [0, 1])))


func _draw_lines(cv: MotionCanvas, f: float) -> void:
	var beat2 := f >= 140
	var o := f - OUT
	if not beat2:
		var red := SCFBrand.RED
		_dim(cv, Vector2(MX, MY - 40), Vector2(MX + 120.6 * _mk, MY - 40), _st(f, 30, 4), red, false)
		_dim(cv, Vector2(MX - 40, MY), Vector2(MX - 40, MY + 120.6 * _mk), _st(f, 36, 4), red, true)
		return
	if f < 150:
		return
	var blue := SCFBrand.BLUE
	var hold2 := f > 236 and f < OUT
	# centre marks and diameters across the three discs
	for n in 3:
		if f < 176 + n * 3 or o > 14:
			continue
		var p: Vector2 = _discs[n].c
		var r: float = _discs[n].r
		var rot := deg_to_rad((f - 236) * 0.6) if hold2 else 0.0
		var ex := Vector2(r + 16, 0).rotated(rot)
		var ey := Vector2(0, r + 16).rotated(rot)
		cv.line(p - ex, p + ex, blue, 2.0)
		cv.line(p - ey, p + ey, blue, 2.0)
	# leader lines out to the labels
	for n in 3:
		var t := _leader_t(f, n)
		if t <= 0.0:
			continue
		var route := _route(n)
		var pts := PackedVector2Array([route[0]])
		var total := 0.0
		for i in range(1, route.size()):
			total += route[i - 1].distance_to(route[i])
		var left := total * t
		for i in range(1, route.size()):
			if left <= 0.0:
				break
			var seg := route[i - 1].distance_to(route[i])
			pts.append(route[i - 1].lerp(route[i], minf(1.0, left / seg)))
			left -= seg
		cv.circle(route[0], 7, INK)
		if hold2:
			cv.dashed_polyline(pts, INK, 2.0, 10, 6, -f)
		else:
			cv.polyline(pts, INK, 2.0)


func _leader_t(f: float, n: int) -> float:
	var o := f - OUT
	var t_in := _st(f, 184 + n * 8, 4)
	var t_out := maxf(0.0, 1.0 - floorf((o - n * 3) / 2.0 + 1.0) / 4.0) if o > n * 3 else 1.0
	return minf(t_in, t_out)


func _route(n: int) -> PackedVector2Array:
	var p: Vector2 = _discs[n].c
	var r: float = _discs[n].r
	var ly: float = LABELS[n].y + 45
	match n:
		0:
			return PackedVector2Array([Vector2(p.x, p.y - r), Vector2(p.x, ly), Vector2(1160, ly)])
		1:
			return PackedVector2Array([Vector2(p.x - 10, p.y + r), Vector2(p.x - 10, 790), Vector2(1100, 790), Vector2(1100, ly), Vector2(1160, ly)])
	return PackedVector2Array([p + Vector2(r, r) * 0.7, Vector2(1040, ly), Vector2(1160, ly)])


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var beat2 := f >= 140
	var spot := SCFBrand.BLUE if beat2 else SCFBrand.RED
	var o := f - OUT
	var hold2 := f > 236 and f < OUT

	var fig: MotionText = _n.fig
	fig.color = spot
	if not beat2:
		fig.visible = f >= 2
		fig.text = "01"
		fig.position = Vector2(-40 - (1 - _st(f, 2)) * 500, 330)
	else:
		fig.visible = f >= 150 and o < 40
		fig.text = "02"
		fig.position = Vector2(-40 - (1 - _st(f, 150)) * 500 - ((o - 30) * 120 if o > 30 else 0.0), 330)

	var rw := maxf(0.0, 1.0 - floorf((o - 34) / 2.0) / 4.0) if (beat2 and o > 34) else _st(f, 4, 4)
	_n.rule.size.x = rw * 1760
	var heads := (o < 32 if beat2 else true) and f > 8
	_n.head.visible = heads
	_n.plate.visible = heads
	_n.head.text = "FIG. 02 — STORY CONTEXT FRAMEWORK" if beat2 else "FIG. 01 — MINIMAL HUMANS"
	_n.plate.text = "PLATE 02 / 02" if beat2 else "PLATE 01 / 02"

	_n.b1.visible = not beat2
	_n.b2.visible = beat2 and f >= 150
	if not beat2:
		_n.mono.visible = f >= 20
		var s := _st(f, 20)
		_n.mono.apply(func(j: int):
			var d := {s = s, pivot = Vector2(60, 64)}
			if j == 2:
				d.fill = INK
			return d)
		_n.word.apply(func(j: int): return {fill = INK} if f >= 48 + (j - 3) * 2 else {hide = true})
		for e in _n.index:
			e.t.visible = f >= 48 + (e.j - 3) * 2
		var dh: MotionText = _n.dim_h
		var dv: MotionText = _n.dim_v
		dh.visible = _st(f, 30, 4) >= 1.0
		dv.visible = _st(f, 36, 4) >= 1.0
		# labels: 120 px boxes centred (horizontal) or left (vertical) on the midpoint
		var mid_h := Vector2(MX + 120.6 * _mk * 0.5, MY - 40)
		dh.position = Vector2(mid_h.x - 60 + (120 - dh.get_text_size().x) * 0.5, mid_h.y - 34)
		var mid_v := Vector2(MX - 40, MY + 120.6 * _mk * 0.5)
		dv.position = Vector2(mid_v.x - 84, mid_v.y - 12)
		_n.pres.visible = f >= 84
		_n.blurb.visible = f >= 92
	else:
		var M: Dictionary = SCFBrand.SCF_MARK
		var order_of := func(i: int) -> int:
			if i == M.discS or (M.S as Array).has(i): return 0
			if i == M.discC or (M.C as Array).has(i): return 1
			if i == M.discF or (M.F as Array).has(i): return 2
			return -1
		_n.mark.apply(func(i: int):
			var ord: int = order_of.call(i)
			if ord >= 0:
				var s_in := _st(f, 156 + ord * 4)
				var s_out := maxf(0.0, 1.0 - floorf((o - 18 - ord * 3) / 2.0 + 1.0) / 3.0) if o > 18 + ord * 3 else 1.0
				var s := minf(s_in, s_out)
				return {hide = true} if s <= 0.0 else {s = s, pivot = _discs[ord].pivot}
			if (M.edges as Array).has(i):
				return null if f >= 170 and o < 16 else {hide = true}
			var k := (M.nodes as Array).find(i)
			if k >= 0:
				if f >= 172 + (k % 5) * 2 and o < 6 + (k % 5) * 2:
					return {ty = sin(f / 15.0 + k) * 0.4 if hold2 else 0.0}
				return {hide = true}
			return null)
		for n in 3:
			_n.labels[n].visible = _leader_t(f, n) >= 1.0
		_n.foot.visible = f >= 214 and o < 10
		for i in 3:
			_n.foot_groups[i].visible = f >= 216 + i * 3
	_n.under.queue_redraw()
	_n.over.queue_redraw()

	var bar_in := mini(4, floori((f - 128) / 2.0) + 1) if (f >= 128 and f < 140) else 0
	var bar_out := 4 - mini(4, floori((f - 140) / 2.0) + 1) if (f >= 140 and f < 150) else 0
	var bars := bar_in if bar_in > 0 else bar_out
	_n.bar.visible = bars > 0
	_n.bar.size.x = bars * 480.0
