# SPDX-License-Identifier: Apache-2.0
# D1 — SIGNAL, ported from scf-intros/src/intros/D1_Signal.tsx.
# Static → barcode scan → the MH logo decodes out of the noise → power-off →
# a terminal renders the SCF mark pixel grid by pixel grid, the wordmark locks
# in, holds "on air", then the signal degrades in reverse and the tube switches
# off to black.
@tool
extends MotionComposition

const OUT := 352.0
const FG := Color("#f2f2f2")
const RED := Color("#ff2340")
const MH_W := 1300.0
const MARK_W := 740.0
const MARK_X := 150.0
const MARK_Y := 250.0
const WM_X := 960.0
const WM_Y := 290.0
const WM_W := 840.0
const TERM := ["> mount story_context.scf", "> verify ............ ok", "> nodes 13 · edges 16", "> render --mark"]
const BLIPS := [86, 87, 97, 108, 286, 318, 319]

var _built := false
var _shift: Node2D
var _static_a: MotionOverlay
var _nosig: Node2D
var _nosig_bar: ColorRect
var _nosig_text: MotionText
var _nosig_icon: MotionSvg
var _barcode_fx: MotionFX
var _barcode: MotionSvg
var _scan: Node2D
var _decoding: MotionText
var _mh_wrap: Node2D
var _mh_fx: MotionFX
var _mh: MotionSvg
var _pres_fx: MotionFX
var _pres_row: Node2D
var _flash1: ColorRect
var _dot1: MotionShape
var _term: Array[MotionText] = []
var _hex_clip: ColorRect
var _hex: MotionText
var _scf_wrap: Node2D
var _grids := {}
var _grid_node: MotionPixelGrid
var _vec_fx: MotionFX
var _wm_fx: MotionFX
var _flash2: ColorRect
var _dot2: MotionShape
var _onair: Node2D
var _onair_dot: MotionShape
var _onair_text: MotionText
var _bars: Array[ColorRect] = []
var _static_b: MotionOverlay
var _crt: MotionOverlay
var _mh_k := 1.0


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _text(parent: Node, family: String, weight: int, size: float, col: Color, track := 0.0, txt := "") -> MotionText:
	var t := MotionText.new()
	t.font = SCFBrand.font(family, weight)
	t.font_size = size
	t.color = col
	t.tracking = track
	t.text = txt
	parent.add_child(t)
	return t


func _rect(parent: Node, col: Color, r := Rect2(0, 0, 1920, 1080)) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _build() -> void:
	_built = true
	_rect(self, Color.BLACK)
	_shift = Node2D.new(); add_child(_shift)

	_static_a = MotionOverlay.new(); _shift.add_child(_static_a)

	# NO SIGNAL: a black band across the frame with the eye icon and the words.
	_nosig = Node2D.new(); _shift.add_child(_nosig)
	_nosig_bar = _rect(_nosig, Color.BLACK)
	_nosig_icon = SCFIcons.make("eye", 54, FG, Color.BLACK); _nosig.add_child(_nosig_icon)
	_nosig_text = _text(_nosig, "space_mono", 700, 60, FG, 0.2, "NO SIGNAL")

	# Barcode scan
	_barcode_fx = MotionFX.new(); _shift.add_child(_barcode_fx)
	_barcode = MotionSvg.new()
	_barcode.data = SCFBrand.logo("mhShort")
	_barcode.width = 1600
	_barcode.stretch_h = 720
	_barcode.crop = Rect2(142.5, 115.3, 103.6, 19.4)
	_barcode.only = PackedInt32Array(SCFBrand.MH_SHORT_CODE)
	_barcode.position = Vector2(160, 120)
	_barcode.apply(func(_i): return {fill = FG})
	_barcode_fx.content.add_child(_barcode)
	_scan = Node2D.new(); _shift.add_child(_scan)
	# glow: box-shadow 0 0 30px and 0 0 80px in the line's colour
	for b in [80.0, 30.0]:
		var g := MotionShape.new()
		g.kind = MotionShape.Kind.RECT
		g.anchor = Vector2.ZERO
		g.size = Vector2(1680, 6)
		g.blur = b
		g.color = RED
		_scan.add_child(g)
	var line := _rect(_scan, RED, Rect2(0, 0, 1680, 6))
	line.name = "Line"
	_decoding = _text(_shift, "space_mono", 700, 30, FG, 0.1)

	# MH decode, inside a wrapper that does the CRT power-off
	_mh_wrap = Node2D.new(); _shift.add_child(_mh_wrap)
	_mh_fx = MotionFX.new(); _mh_wrap.add_child(_mh_fx)
	_mh = MotionSvg.new()
	_mh.data = SCFBrand.logo("mhShort")
	_mh.width = MH_W
	_mh.position = Vector2(960 - MH_W / 2.0, 220)
	_mh_fx.content.add_child(_mh)
	_mh_k = MH_W / _mh.data.view_box.size.x
	_pres_fx = MotionFX.new(); _mh_wrap.add_child(_pres_fx)
	_pres_row = Node2D.new(); _pres_fx.content.add_child(_pres_row)
	var pres := MotionText.new()
	pres.font = SCFBrand.font("shoulders", 900); pres.font_size = 150; pres.line_height = 0.9; pres.tracking = 0.02
	pres.color = FG; pres.text = "PRESENTS"
	_pres_row.add_child(pres)
	var arrow := SCFIcons.make("arrow", 110, SCFBrand.RED, Color.BLACK)
	arrow.position = Vector2(pres.get_text_size().x + 34, (pres.get_text_size().y - 110) / 2.0)
	_pres_row.add_child(arrow)
	_pres_row.position = Vector2(960 - MH_W / 2.0 + 145 * _mh_k, 220 + 136 * _mh_k + 30)
	_flash1 = _rect(_mh_wrap, Color.WHITE)
	_dot1 = _dot(_shift)

	# Terminal and hex flood
	for i in TERM.size():
		var t := _text(_shift, "space_mono", 400, 40, FG)
		t.position = Vector2(120, 140 + i * 64)
		t.line_height = 1.6
		_term.append(t)
	_hex_clip = _rect(_shift, Color.BLACK)
	_hex_clip.clip_contents = true
	_hex = MotionText.new()
	_hex.font = SCFBrand.font("space_mono", 400); _hex.font_size = 22; _hex.line_height = 30.0 / 22.0
	_hex.color = Color(FG, 0.8)
	var rows := PackedStringArray()
	for r in 80:
		var cols := PackedStringArray()
		for c in 22:
			cols.append("%04x" % int(floorf(MK.rand(r * 31 + c * 7) * 65535.0)))
		rows.append(" ".join(cols))
	_hex.text = "\n".join(rows)
	_hex_clip.add_child(_hex)

	# SCF: pixel grids, vector mark, wordmark
	_scf_wrap = Node2D.new(); _shift.add_child(_scf_wrap)
	var pal: Array[Color] = [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED, SCFBrand.CREAM, SCFBrand.BLACK]
	var mark := SCFBrand.logo("scfMark")
	for g in ["16", "32", "64"]:
		_grids[g] = MotionPixelGrid.cells_from_svg(mark, int(g), pal)
	_grid_node = MotionPixelGrid.new()
	_grid_node.width = MARK_W
	_grid_node.position = Vector2(MARK_X, MARK_Y)
	_grid_node.recolor = {SCFBrand.BLACK: Color("#3a3a3a")}
	_scf_wrap.add_child(_grid_node)
	_vec_fx = MotionFX.new(); _scf_wrap.add_child(_vec_fx)
	var vmark := MotionSvg.new()
	vmark.data = mark; vmark.width = MARK_W; vmark.position = Vector2(MARK_X, MARK_Y)
	vmark.apply(func(i): return {fill = Color("#bdbdbd")} if SCFBrand.SCF_MARK_EDGES.has(i) else null)
	_vec_fx.content.add_child(vmark)
	_wm_fx = MotionFX.new(); _scf_wrap.add_child(_wm_fx)
	var wm := MotionSvg.new()
	wm.data = SCFBrand.logo("scfFull"); wm.width = WM_W
	wm.crop = Rect2(108, 4, 175, 76)
	var M: Dictionary = SCFBrand.SCF_FULL
	wm.only = PackedInt32Array(M.story + M.context + M.framework)
	wm.position = Vector2(WM_X, WM_Y)
	wm.apply(func(_i): return {fill = FG})
	_wm_fx.content.add_child(wm)
	var row := Node2D.new(); row.position = Vector2(WM_X + 6, WM_Y + 400); _wm_fx.content.add_child(row)
	var x := 0.0
	for item in [["database", "SQLITE"], ["nodes", "16 QUERIES"], ["check", "OPEN FORMAT 1.0"]]:
		var ic := SCFIcons.make(item[0], 30, SCFBrand.AMBER, Color.BLACK)
		row.add_child(ic)
		var t := _text(row, "space_mono", 700, 22, FG, 0.1, item[1])
		var lh := t.get_text_size().y
		var hh := maxf(30.0, lh)
		ic.position = Vector2(x, (hh - 30) / 2.0)
		x += 30 + 30
		t.position = Vector2(x, (hh - lh) / 2.0)
		x += t.get_text_size().x + 30
	_flash2 = _rect(_scf_wrap, Color.WHITE)
	_dot2 = _dot(_shift)

	# On-air furniture
	_onair = Node2D.new(); _shift.add_child(_onair)
	_onair_dot = MotionShape.circle(18, SCFBrand.RED); _onair.add_child(_onair_dot)
	_onair_text = _text(_onair, "space_mono", 700, 22, FG, 0.12)
	var bl := _text(_onair, "space_mono", 700, 22, FG, 0.12, "MINIMAL HUMANS PRESENTS")
	bl.position = Vector2(80, 1080 - 56 - bl.get_text_size().y)
	var br := _text(_onair, "space_mono", 700, 22, FG, 0.12, "SCF/1.0 — SIGNAL LOCKED ")
	var sq := _text(_onair, "space_mono", 700, 22, SCFBrand.AMBER, 0.12, "■")
	var bw := br.get_text_size().x + sq.get_text_size().x
	br.position = Vector2(1920 - 80 - bw, 1080 - 56 - br.get_text_size().y)
	sq.position = br.position + Vector2(br.get_text_size().x, 0)
	for i in 5:
		var b := _rect(_onair, FG, Rect2(1920 - 80 - (5 * 10 + 4 * 6) + i * 16, 56 + 40 - (12 + i * 7), 10, 12 + i * 7))
		_bars.append(b)

	_static_b = MotionOverlay.new(); _shift.add_child(_static_b)
	_crt = MotionOverlay.new(); _crt.kind = MotionOverlay.Kind.CRT; add_child(_crt)


func _dot(parent: Node) -> MotionShape:
	var d := MotionShape.circle(20, Color.WHITE)
	d.position = Vector2(960, 540)
	parent.add_child(d)
	var glow := MotionShape.circle(100, Color(1, 1, 1, 0.25))
	d.add_child(glow)
	return d


func _crt_wrap(node: Node2D, f: float, at: float, active: bool, flash: ColorRect, dot: MotionShape) -> void:
	var c := MK.crt_off(f, at)
	if active:
		var s: Vector2 = c.scale
		node.scale = s
		node.position = Vector2(960, 540) * (Vector2.ONE - s)
		var k := 1.0 + float(c.bright) * 4.0
		node.modulate = Color(k, k, k)
		flash.visible = true
		flash.color = Color(1, 1, 1, c.bright)
	else:
		node.scale = Vector2.ONE
		node.position = Vector2.ZERO
		node.modulate = Color.WHITE
		flash.visible = false
	dot.visible = float(c.dot) > 0.0
	dot.modulate.a = c.dot


func _frame(f: float) -> void:
	if not _built:
		return
	var fi := int(floorf(f))
	var blip := BLIPS.has(fi)
	_shift.position.x = (MK.rand(fi) - 0.5) * (40.0 if f > 250 else 120.0) if blip else 0.0

	var decay := maxf(1.0 - MK.prog(f, 64, 44), 0.7 if (blip and f < 120) else 0.0)
	var colour := f >= 104
	var o := f - OUT
	var vec_decay := maxf(maxf(1.0 - MK.prog(f, 212, 18), 0.25 if (f > 250 and blip) else 0.0), MK.map(o, [0, 16], [0, 1]))
	var wm_decay := maxf(maxf(1.0 - MK.prog(f, 222, 22), 0.3 if (f > 250 and blip) else 0.0), MK.map(o, [0, 12], [0, 1]))
	var grid := ""
	if f < 184: grid = ""
	elif f < 194: grid = "16"
	elif f < 204: grid = "32"
	elif f < 212: grid = "64"
	elif o < 18: grid = ""
	elif o < 22: grid = "64"
	elif o < 26: grid = "32"
	else: grid = "16"
	var on_air := f >= 246 and o < 6

	# static + NO SIGNAL
	_static_a.visible = f < 26 or [44, 45, 131, 150].has(fi)
	_static_a.opacity = 0.9 if f < 24 else 0.6
	_nosig.visible = f < 24
	if _nosig.visible:
		var th := _nosig_text.get_text_size()
		var h := maxf(54.0, th.y)
		var total := 54.0 + 28.0 + th.x
		_nosig_bar.position = Vector2(0, 470)
		_nosig_bar.size = Vector2(1920, h + 28)
		_nosig_icon.position = Vector2(960 - total / 2.0, 470 + 14 + (h - 54) / 2.0)
		_nosig_text.position = Vector2(960 - total / 2.0 + 54 + 28, 470 + 14 + (h - th.y) / 2.0)
		_nosig.modulate.a = 1.0 if fi % 6 < 4 else 0.0

	# barcode scan
	var scan_on := f >= 24 and f < 58
	_barcode_fx.visible = scan_on
	_barcode_fx.set_slices(40, 8, 7, 3)
	_scan.visible = scan_on
	_scan.position = Vector2(120, 120 + fmod((f - 24) * 46.0, 820.0))
	_decoding.visible = scan_on
	if scan_on:
		var nb := int(floorf(MK.map(f, [24, 56], [0, 16])))
		_decoding.text = "DECODING MH-001 " + "█".repeat(nb) + "░".repeat(16 - nb)
		_decoding.position = Vector2(160, 1080 - 90 - _decoding.get_text_size().y)

	# MH decode
	_mh_wrap.visible = f >= 58 and f < 150
	_mh_fx.set_slices(decay * 260, decay * 26, 18, 7)
	_mh.apply(func(_i): return null if colour else {fill = FG})
	_pres_fx.visible = f >= 108
	var pd := maxf(1.0 - MK.prog(f, 108, 12), 0.0)
	_pres_fx.set_slices(pd * 300, pd * 20, 8, 11)
	_crt_wrap(_mh_wrap, f, 132, f >= 132, _flash1, _dot1)

	# terminal + hex flood
	var cur_line := mini(3, int(floorf((f - 150) / 6.0)))
	for i in TERM.size():
		var t := _term[i]
		t.visible = f >= 150 and f < 188
		t.text = MK.typed(TERM[i], f, 150 + i * 6, 120) + ("▮" if i == cur_line and fi % 8 < 4 else "")
	var hh := MK.map(f, [168, 182], [0, 1080])
	_hex_clip.visible = f >= 168 and f < 190
	_hex_clip.position = Vector2(0, 1080 - hh)
	_hex_clip.size = Vector2(1920, hh)
	_hex.position = Vector2(0, -(f - 168) * 60.0)

	# SCF
	_grid_node.visible = grid != ""
	if grid != "":
		_grid_node.set_grid(_grids[grid])
		_grid_node.gap = 0.5 if grid == "64" else 2.0
		var g := grid
		_grid_node.show_fn = func(i: int) -> bool:
			if o < 0.0:
				return g != "16" or f >= 184.0 + MK.rand(i * 3.3) * 10.0
			return o < 26.0 or f < OUT + 26.0 + MK.rand(i * 5.1) * 10.0
		_grid_node.queue_redraw()
	_vec_fx.visible = f >= 212 and o < 18
	_vec_fx.set_slices(vec_decay * 140, vec_decay * 18, 18, 19)
	_wm_fx.visible = f >= 222 and o < 12
	_wm_fx.set_slices(wm_decay * 220, wm_decay * 22, 9, 23)
	_crt_wrap(_scf_wrap, f, OUT + 38, o >= 38, _flash2, _dot2)

	# on-air furniture
	_onair.visible = on_air
	if on_air:
		_onair_dot.position = Vector2(80 + 9, 60 + 13)
		_onair_dot.modulate.a = 1.0 if fi % 30 < 18 else 0.2
		_onair_text.text = "ON AIR · " + MK.timecode(f - 246)
		_onair_text.position = Vector2(80 + 18 + 16, 60 + 13 - _onair_text.get_text_size().y / 2.0)
		for i in 5:
			_bars[i].color = FG if i < 4 + (1 if fi % 40 < 30 else 0) else Color("#444444")

	_static_b.visible = o >= 16 and o < 34
	_static_b.opacity = MK.interp(o, [16, 24, 34], [0, 0.5, 0])
