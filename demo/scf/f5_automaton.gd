# SPDX-License-Identifier: Apache-2.0
# F5 — AUTOMATON, ported from scf-intros src/intros/F5_Automaton.tsx.
# Signal taken somewhere generative: a field of Game-of-Life cells on black.
# The soup lives, then gets pulled into the shape of the M, layer by layer,
# and the wordmark resolves out of blocks. A rule change makes it explode into
# "seeds", and the swarm settles into the SCF mark, pixel for pixel, while the
# wordmark blocks in. It holds with a glider crossing underneath, then the
# cells die off and leave one blinking cursor.
#
# The automaton is deterministic and runs one generation per frame, cached,
# so seeking backwards replays from the cache and seeking forwards catches up.
@tool
extends MotionComposition

const DURATION := 420
const OUT := 352
const GW := 80
const GH := 45
const CELL := 24
const BG := Color("#050505")
const GREY := Color("#9a9a9a")
const SCF_W := 900.0
const SCF_K := SCF_W / 175.0

static var _frames: Array[PackedByteArray] = []
static var _st := PackedByteArray()
static var _age := PackedByteArray()
static var _m_target := PackedByteArray()
static var _s_target := PackedByteArray()

var _built := false
var _cells: MotionCells
var _wm1: MotionCanvas
var _wm2: MotionCanvas
var _presents: MotionText
var _tags: Node2D
var _tag_items: Array[Node2D] = []
var _console: Node2D
var _lines: Array[MotionText] = []
var _gen: MotionText
var _cursor: ColorRect


func _init() -> void:
	duration = DURATION
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ------------------------------------------------------------------ automaton

static func _idx(x: int, y: int) -> int:
	return posmod(y, GH) * GW + posmod(x, GW)


static func _hash(a: float, b: float) -> float:
	return MK.rand(a * 0.731 + b * 1.917 + 0.5)


static func _age_col(age: int) -> int:
	return 2 if age < 2 else (3 if age < 6 else 4)


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


static func _targets() -> void:
	if not _m_target.is_empty():
		return
	_m_target.resize(GW * GH)
	var outline: Array = JSON.parse_string(FileAccess.get_file_as_string("res://demo/scf/m_outline.json")).mOutline
	var cells := 22
	var k := 120.63 / cells
	# red layer (2 cells down-right), amber (1), cream (front): later layers overwrite
	for layer in [[2, 3], [1, 2], [0, 1]]:
		for y in cells:
			for x in cells:
				if _in_poly((x + 0.5) * k, (y + 0.5) * k, outline):
					_m_target[_idx(8 + x + layer[0], 11 + y + layer[0])] = layer[1]
	_s_target.resize(GW * GH)
	var mark: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/scf/mark_pixels_32.json"))
	for c in mark.cells:
		_s_target[_idx(5 + int(c[0]), 11 + int(c[1]))] = int(c[2])


## B3/S23 on the torus. Survivors age; cells are coloured by age.
static func _life() -> void:
	var n := GW * GH
	var alive := PackedByteArray()
	alive.resize(n)
	for i in n:
		alive[i] = 1 if _st[i] else 0
	var nx := PackedByteArray()
	nx.resize(n)
	var na := PackedByteArray()
	na.resize(n)
	for y in GH:
		var ym := posmod(y - 1, GH) * GW
		var y0 := y * GW
		var yp := posmod(y + 1, GH) * GW
		for x in GW:
			var xm := posmod(x - 1, GW)
			var xp := posmod(x + 1, GW)
			var c := alive[ym + xm] + alive[ym + x] + alive[ym + xp] + alive[y0 + xm] \
				+ alive[y0 + xp] + alive[yp + xm] + alive[yp + x] + alive[yp + xp]
			var i := y0 + x
			if (c == 2 or c == 3) if alive[i] else c == 3:
				na[i] = mini(250, _age[i] + 1) if alive[i] else 0
				nx[i] = _age_col(na[i])
	_st = nx
	_age = na


static func _pull(target: PackedByteArray, p: float, f: int) -> void:
	for i in _st.size():
		if _hash(i, f) < p:
			_st[i] = target[i]


static func _step(f: int) -> void:
	if f == 0:
		_st = PackedByteArray()
		_st.resize(GW * GH)
		_age = PackedByteArray()
		_age.resize(GW * GH)
		for i in _st.size():
			if _hash(i, 1) < 0.32:
				_st[i] = 2
	if f < 40:
		if f % 2 == 0:
			_life()
	elif f < 100:
		_life()
		_pull(_m_target, MK.map(f, [40, 96], [0.02, 1], func(t: float) -> float: return t * t), f)
	elif f < 140:
		_st = _m_target.duplicate()
	elif f < 168:
		# the organism bursts: every cell of the M flies outward, colours cycling
		_st = PackedByteArray()
		_st.resize(GW * GH)
		var t := float(f - 140)
		for i in _m_target.size():
			if not _m_target[i]:
				continue
			var x := i % GW
			var y := i / GW
			var a := atan2(y - 22.0, x - 19.0) + (_hash(i, 5) - 0.5) * 0.9
			var d := (0.2 + 0.9 * _hash(i, 6)) * pow(t, 1.22)
			# Math.round: halves round up
			_st[_idx(int(floorf(x + cos(a) * d + 0.5)), int(floorf(y + sin(a) * d + 0.5)))] = posmod(f / 2 + i, 3) + 2
	elif f < 232:
		_life()
		_pull(_s_target, MK.map(f, [168, 228], [0.03, 1], func(t: float) -> float: return t * t), f + 7)
	elif f < OUT:
		_st = _s_target.duplicate()
		# a glider crossing the bottom rows
		var g := (f - 232) / 4
		var gx := g % (GW + 6) - 3
		var shapes := [[[1, 0], [2, 1], [0, 2], [1, 2], [2, 2]], [[0, 1], [2, 1], [1, 2], [2, 2], [1, 3]],
			[[2, 1], [0, 2], [2, 2], [1, 3], [2, 3]], [[0, 1], [2, 2], [3, 2], [1, 3], [2, 3]]]
		for c in shapes[g % 4]:
			var x: int = gx + c[0]
			if x >= 0 and x < GW:
				_st[_idx(x, 38 + c[1])] = 3
	else:
		if f % 2 == 0:
			_life()
		var p := MK.map(f, [OUT, OUT + 40], [0.04, 0.6])
		for i in _st.size():
			if _hash(i, f + 99) < p:
				_st[i] = 0


## The cells at frame f (clamped to the last frame).
static func state_at(f: int) -> PackedByteArray:
	_targets()
	f = clampi(f, 0, DURATION - 1)
	while _frames.size() <= f:
		_step(_frames.size())
		_frames.append(_st.duplicate())
	return _frames[f]


# ------------------------------------------------------------------ build

func _text(parent: Node, size: float, col: Color, s := "", track := 0.0) -> MotionText:
	var t := MotionText.new()
	t.font = PrintKit.mono_font(700)
	t.font_size = size
	t.color = col
	t.tracking = track
	t.text = s
	parent.add_child(t)
	return t


## Block dissolve: CELL px squares of the children appear in a random order as
## the canvas's `t` meta goes 0 -> 1 (an SVG clipPath of rects over a foreignObject).
func _blocks(pos: Vector2, w: float, h: float, seed: float) -> MotionCanvas:
	var c := MotionCanvas.new()
	c.position = pos
	c.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var cols := int(ceilf(w / CELL))
	var rows := int(ceilf(h / CELL))
	# An empty clip mask clips nothing, so the canvas hides until a block shows.
	var first := 1.0
	for i in cols * rows:
		first = minf(first, MK.rand(i * 3.3 + seed))
	c.set_meta("first", first)
	c.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		var t: float = cv.get_meta("t", 0.0)
		if t >= 1.0:
			cv.rect(Rect2(-200, -200, w + 400, h + 400), Color.WHITE)
			return
		for i in cols * rows:
			if MK.rand(i * 3.3 + seed) < t:
				cv.rect(Rect2((i % cols) * CELL, (i / cols) * CELL, CELL, CELL), Color.WHITE)
	add_child(c)
	return c


func _build() -> void:
	_built = true
	PrintKit.rect(self, Rect2(0, 0, 1920, 1080), BG)
	_cells = MotionCells.new()
	_cells.columns = GW
	_cells.rows = GH
	_cells.cell_size = Vector2(CELL, CELL)
	_cells.inset = 1.5
	_cells.grid_color = Color(1, 1, 1, 0.035)
	_cells.palette = PackedColorArray([Color.TRANSPARENT, SCFBrand.CREAM, SCFBrand.AMBER, SCFBrand.RED, SCFBrand.BLUE, Color("#3c3c3c")])
	add_child(_cells)

	# MH wordmark blocks in beside the pixel M
	_wm1 = _blocks(Vector2(34 * CELL, 15 * CELL), 1000, 380, 3)
	var w1 := MotionSvg.new()
	w1.data = SCFBrand.logo("mhFull")
	w1.width = 1000
	w1.crop = Rect2(140, 0, 345.7, 128.89)
	w1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	for i in w1.only:
		w1.set_part(i, {fill = SCFBrand.CREAM})
	_wm1.add_child(w1)
	_presents = _text(self, 40, SCFBrand.AMBER, "", 0.5)
	_presents.position = Vector2(35 * CELL, 31 * CELL)

	# SCF wordmark blocks in beside the pixel mark
	_wm2 = _blocks(Vector2(40 * CELL, 14 * CELL), SCF_W, 82.12 * SCF_K, 7)
	var w2 := MotionSvg.new()
	w2.data = SCFBrand.logo("scfFull")
	w2.width = SCF_W
	w2.crop = Rect2(105, 0, 175, 82.12)
	var F: Dictionary = SCFBrand.SCF_FULL
	w2.only = PackedInt32Array(F.story + F.context + F.framework)
	for i in w2.only:
		w2.set_part(i, {fill = SCFBrand.CREAM})
	_wm2.add_child(w2)

	# OPEN FORMAT / 1.0 / MINIMAL HUMANS: flex, gap 16, padding 4px 12px
	_tags = Node2D.new()
	_tags.position = Vector2(41 * CELL, 32 * CELL)
	add_child(_tags)
	var x := 0.0
	for k in 3:
		var item := Node2D.new()
		item.position = Vector2(x, 0)
		_tags.add_child(item)
		var t := MotionText.new()
		t.font = PrintKit.mono_font(700)
		t.font_size = 26
		t.tracking = 0.12
		t.color = BG if k == 2 else SCFBrand.CREAM
		t.text = ["OPEN FORMAT", "1.0", "MINIMAL HUMANS"][k]
		var sz := t.get_text_size() + Vector2(24, 8)
		PrintKit.rect(item, Rect2(Vector2.ZERO, sz), [SCFBrand.BLUE, SCFBrand.RED, SCFBrand.AMBER][k])
		t.position = Vector2(12, 4)
		item.add_child(t)
		_tag_items.append(item)
		x += sz.x + 16

	# console lines
	_console = Node2D.new()
	_console.position = Vector2(2 * CELL + 4, 2 * CELL)
	add_child(_console)
	for k in 3:
		var t := _text(_console, 22, GREY)
		t.line_height = CELL * 1.25 / 22.0
		t.position = Vector2(0, k * CELL * 1.25)
		_lines.append(t)
	_gen = _text(self, 22, GREY)
	_gen.align = HORIZONTAL_ALIGNMENT_RIGHT
	_gen.position = Vector2(1920 - 2 * CELL, 2 * CELL)
	_cursor = PrintKit.rect(self, Rect2(40 * CELL, 22 * CELL, CELL - 3, CELL - 3), SCFBrand.AMBER)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var fi := int(floorf(f))
	var st := state_at(fi)
	var o := f - OUT
	_cells.cells = st
	_cells.visible = f < OUT + 44

	var wm1 := MK.map(f, [102, 122], [0, 1]) * (1.0 - MK.map(f, [140, 146], [0, 1]))
	var wm2 := MK.map(f, [236, 258], [0, 1]) * (1.0 - MK.map(o, [0, 18], [0, 1]))
	for pair in [[_wm1, wm1], [_wm2, wm2]]:
		var c: MotionCanvas = pair[0]
		c.visible = pair[1] > c.get_meta("first")
		c.set_meta("t", pair[1])
		c.queue_redraw()

	_presents.visible = f >= 118 and f < 142
	var n := maxi(0, floori((f - 118) * 1.2))
	_presents.text = "PRESENTS".substr(0, n) + "█"
	_presents.visible_chars = mini(n, 8) + (1 if fi % 8 < 5 else 0)

	_tags.visible = f >= 262 and o < 10
	for k in 3:
		_tag_items[k].visible = f >= 262 + k * 5

	var early := f < 140
	var texts := ["> seed 0x4D48 · rule B3/S23", "> attract --target m.mask", "> ok · 1 organism · MINIMAL HUMANS"] if early \
		else ["> burst · 528 cells", "> attract --target scf.mark", "> ok · story_context.scf · 1.0"]
	var at := [6, 44, 100] if early else [142, 170, 230]
	_console.visible = o < 30
	var row := 0
	for k in 3:
		# Lines not started yet are absent, so later lines move up into their place.
		if f >= at[k]:
			_lines[row].text = texts[k]
			_lines[row].visible_chars = maxi(0, floori((f - at[k]) * 2.4))
			row += 1
	for k in range(row, 3):
		_lines[k].text = ""
	var alive := 0
	for v in st:
		if v:
			alive += 1
	_gen.text = "GEN %04d · %d ALIVE" % [fi, alive]
	_cursor.visible = f >= OUT + 46 and fi % 16 < 9
