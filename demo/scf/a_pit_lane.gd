# SPDX-License-Identifier: Apache-2.0
# A — PIT LANE, ported from scf-intros/src/intros/A_PitLane.tsx.
# A Wipeout team ident: hazard stripes, HUD, countdown, slams.
@tool
extends MotionComposition

const BG := Color("#060606")
const OFFWHITE := Color("#f4f1ea")
const SLAMS := [62.0, 68.0, 74.0]
const STAMP0 := 82.0
const LAND := {S = 162.0, C = 168.0, F = 174.0}
const MH_W := 1400.0
const SCF_W := 720.0
const FX_PAD := Vector2(60, 120)        # room in the lockup's FX texture for blur and the JP line above

var _built := false
var _shake: Node2D
var _floor: MotionCanvas
var _speed: MotionCanvas
var _count: Node2D
var _count_bg: ColorRect
var _count_digit: MotionText
var _count_jp: MotionText
var _chev_clip: Control
var _chev: MotionText
var _mh_fx: MotionFX
var _mh_jp: MotionText
var _mh: MotionSvg
var _slab: Control
var _slab_pres: MotionText
var _slab_jp: MotionText
var _slab_id: MotionText
var _scf_box: Node2D
var _scf: MotionSvg
var _rings: MotionCanvas
var _glint: MotionGradient
var _title: Node2D
var _words: Array[MotionText] = []
var _title_jp: MotionText
var _pills: Array[MotionPill] = []
var _haz: Array[Node2D] = []
var _haz_grad: Array[MotionGradient] = []
var _hud: Node2D
var _brackets: MotionCanvas
var _hud_tl: MotionText
var _hud_tr: MotionText
var _hud_bl: Array[MotionText] = []
var _hud_br: MotionText
var _flash: ColorRect
var _slam_flash: ColorRect
var _mh_k := 1.0
var _scf_k := 1.0


func _init() -> void:
	duration = 300
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
	_rect(self, BG)
	_shake = Node2D.new(); add_child(_shake)

	_floor = MotionCanvas.new(); _shake.add_child(_floor)
	_floor.draw_fn = func(c: MotionCanvas, f: float) -> void:
		var vp := Vector2(960, 560)
		for i in 25:
			c.line(vp, Vector2(-1400 + i * 196, 1080), SCFBrand.AMBER, 1.5, 0.5)
		for i in 14:
			var z := (i + fmod(f * 0.25, 1.0)) / 14.0
			var y := vp.y + (1080.0 - vp.y) * pow(z, 2.4)
			c.line(Vector2(0, y), Vector2(1920, y), SCFBrand.AMBER, 1.0 + z * 2.0, 0.15 + z * 0.6)
	_speed = MotionCanvas.new(); _shake.add_child(_speed)
	_speed.draw_fn = func(c: MotionCanvas, f: float) -> void:
		for i in 70:
			var y := MK.rand(i * 3.1) * 1080.0
			var len := 200.0 + MK.rand(i * 7.7) * 900.0
			var sp := 90.0 + MK.rand(i * 1.3) * 140.0
			var x := fposmod(fposmod(MK.rand(i * 5.9) * 3200.0 - f * sp, 3200.0) + 3200.0, 3200.0) - 600.0
			c.line(Vector2(x, y), Vector2(x + len, y), SCFBrand.AMBER if i % 7 == 0 else Color.WHITE, 4.0 if i % 5 == 0 else 1.5, 0.25 + MK.rand(i) * 0.6)

	# countdown
	_count = Node2D.new(); _shake.add_child(_count)
	_count_bg = _rect(_count, SCFBrand.AMBER)
	_count_digit = _text(_count, "unbounded", 900, 640, SCFBrand.AMBER)
	_count_digit.line_height = 1.0
	_count_jp = _text(_count, "jp", 900, 44, SCFBrand.CREAM, 0.4)

	# chevrons
	_chev_clip = Control.new(); _chev_clip.clip_contents = true; _chev_clip.position = Vector2(0, 440); _chev_clip.size = Vector2(1920, 200)
	_chev_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake.add_child(_chev_clip)
	_chev = _text(_chev_clip, "unbounded", 900, 200, SCFBrand.RED, 0.0, "›".repeat(24))
	_chev.line_height = 1.0

	# MH lockup, inside an FX group for its exit blur
	_mh_fx = MotionFX.new(); _mh_fx.size = Vector2(1920, 720); _shake.add_child(_mh_fx)
	var box := Node2D.new(); box.position = FX_PAD; _mh_fx.content.add_child(box)
	_mh = MotionSvg.new(); _mh.data = SCFBrand.logo("mhFull"); _mh.width = MH_W; box.add_child(_mh)
	_mh_k = MH_W / _mh.data.view_box.size.x
	_mh_jp = _text(box, "jp", 900, 30, SCFBrand.AMBER, 0.32, SCFBrand.JP.mh)
	_mh_jp.position = Vector2(145 * _mh_k, -64)
	_slab = Control.new(); _slab.clip_contents = true; _slab.position = Vector2(145 * _mh_k, 129 * _mh_k + 34); _slab.size = Vector2(0, 84)
	_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_slab)
	_rect(_slab, SCFBrand.RED, Rect2(0, 0, 860, 84))
	_slab_pres = _text(_slab, "unbounded", 900, 52, BG, 0.22, "PRESENTS")
	_slab_jp = _text(_slab, "jp", 900, 52, BG, 0.0, SCFBrand.JP.presents)
	_slab_id = _text(_slab, "space_mono", 700, 20, BG, 0.0, "MH/01")

	# SCF lockup. In the original, the shake group's CSS transform makes an
	# isolated stacking context, so the overlay glint only blends with what is
	# inside it; a MotionFX group gives the same transparent backdrop.
	var scf_group := MotionFX.new(); _shake.add_child(scf_group)
	_scf_box = Node2D.new(); _scf_box.position = Vector2(960 - SCF_W / 2.0, 150); scf_group.content.add_child(_scf_box)
	_scf = MotionSvg.new(); _scf.data = SCFBrand.logo("scfMark"); _scf.width = SCF_W; _scf_box.add_child(_scf)
	_scf_k = SCF_W / _scf.data.view_box.size.x
	_rings = MotionCanvas.new(); _scf_box.add_child(_rings)
	_glint = MotionGradient.linear(Vector2(SCF_W, SCF_W * _scf.data.view_box.size.y / _scf.data.view_box.size.x + 5.0), 105.0,
		[Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), Color(0, 0, 0, 0)], [0.0, 0.5, 1.0])
	_glint.blend = MotionGradient.Blend.OVERLAY
	_scf_box.add_child(_glint)

	# SCF title
	_title = Node2D.new(); _shake.add_child(_title)
	for w in ["STORY", "CONTEXT", "FRAMEWORK"]:
		var t := _text(_title, "unbounded", 900, 70, SCFBrand.AMBER if w == "CONTEXT" else OFFWHITE, 0.02, w)
		_words.append(t)
	_title_jp = _text(_title, "jp", 900, 30, SCFBrand.RED, 0.34)
	_title_jp.align = HORIZONTAL_ALIGNMENT_CENTER
	_title_jp.box_width = 1920
	var tags := ["SCF 1.0", "OPEN FORMAT", "CLASS: STORY DATA"]
	for i in tags.size():
		var p := MotionPill.new()
		p.font = SCFBrand.font("space_mono", 700)
		p.font_size = 22
		p.tracking = 0.12
		p.text = tags[i]
		p.padding = Vector2(16, 6)
		p.corner_radius = 0.0
		p.border_width = 3.0
		p.border_color = SCFBrand.AMBER
		p.background = SCFBrand.AMBER if i == 0 else Color(0, 0, 0, 0)
		p.text_color = BG if i == 0 else SCFBrand.AMBER
		_title.add_child(p)
		_pills.append(p)

	# hazard bands: 54 px of stripes between 3 px black borders
	for top in [0.0, 1026.0]:
		var band := Node2D.new(); band.position = Vector2(0, top); _shake.add_child(band)
		var g := MotionGradient.stripes(Vector2(1920, 54), -45.0, [SCFBrand.AMBER, SCFBrand.AMBER, Color("#0a0a0a"), Color("#0a0a0a")], [0.0, 34.0, 34.0, 68.0])
		g.position = Vector2(0, 3)
		band.add_child(g)
		_rect(band, Color("#0a0a0a"), Rect2(0, 0, 1920, 3))
		_rect(band, Color("#0a0a0a"), Rect2(0, 57, 1920, 3))
		_haz.append(band)
		_haz_grad.append(g)

	# HUD (not shaken)
	_hud = Node2D.new(); add_child(_hud)
	_brackets = MotionCanvas.new(); _hud.add_child(_brackets)
	_brackets.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		var L := 76.0   # 70 px box + 6 px border
		var T := 6.0
		for corner in [Vector2(60, 84), Vector2(1920 - 60 - L, 84), Vector2(60, 1080 - 84 - L), Vector2(1920 - 60 - L, 1080 - 84 - L)]:
			var right: bool = corner.x > 960
			var bottom: bool = corner.y > 540
			c.rect(Rect2(corner + Vector2(L - T if right else 0.0, 0), Vector2(T, L)), SCFBrand.AMBER)
			c.rect(Rect2(corner + Vector2(0, L - T if bottom else 0.0), Vector2(L, T)), SCFBrand.AMBER)
	_hud_tl = _text(_hud, "space_mono", 700, 22, SCFBrand.AMBER, 0.12)
	_hud_tr = _text(_hud, "space_mono", 700, 22, SCFBrand.AMBER, 0.12)
	for spec in [[OFFWHITE, "VEL "], [SCFBrand.AMBER, "0000"], [OFFWHITE, " KM/H"]]:
		_hud_bl.append(_text(_hud, "space_mono", 700, 30, spec[0], 0.12, spec[1]))
	_hud_br = _text(_hud, "space_mono", 700, 22, SCFBrand.AMBER, 0.12)
	_flash = _rect(self, Color.WHITE)
	_slam_flash = _rect(self, Color(SCFBrand.AMBER, 0.25))


func _frame(f: float) -> void:
	if not _built:
		return
	var fi := int(floorf(f))
	var out1 := MK.interp(f, [128, 140], [0, 1], MK.ease_in_quad)
	var sh := MK.shakes(f, SLAMS + [LAND.S, LAND.C, LAND.F, 120.0], 22, 9)
	_shake.position = sh
	var vel := int(round(MK.map(f, [44, 76], [0, 987]) + (round(MK.rand(MK.step(f, 3)) * 9.0) if f > 76 else 0.0)))
	var count := 3 - int(floorf((f - 20) / 8.0)) if (f >= 20 and f < 44) else 0

	_floor.modulate.a = MK.map(f, [44, 70], [0, 0.28]) * (1.0 if (f < 128 or f > 150) else 0.2)
	_speed.modulate.a = MK.map(f, [40, 50], [0, 1]) * (1.0 - MK.map(f, [96, 120], [0, 0.8])) + ((1.0 - MK.map(f, [160, 185], [0, 1])) if (f > 140 and f < 185) else 0.0)

	# countdown
	_count.visible = count > 0
	if count > 0:
		_count_bg.visible = count == 2
		_count_digit.text = str(count)
		_count_digit.color = BG if count == 2 else (SCFBrand.RED if count == 1 else SCFBrand.AMBER)
		var ds := _count_digit.get_text_size()
		var s := 1.15 - fmod(f - 20, 8.0) * 0.02
		_count_digit.scale = Vector2(s, s)
		_count_digit.position = Vector2(960, 540) - ds * 0.5 * s
		_count_jp.text = SCFBrand.JP.ready if count == 1 else SCFBrand.JP.boot
		_count_jp.color = BG if count == 2 else SCFBrand.CREAM
		var js := _count_jp.get_text_size()
		_count_jp.position = Vector2(960 - js.x * 0.5, 1080 - 210 - js.y)

	# chevrons
	_chev_clip.visible = f >= 44 and f < 62
	_chev.position.x = -fmod((f - 44) * 160.0, 400.0)

	# MH lockup
	_mh_fx.visible = f >= 54 and f < 142
	var sx := 1.0 + out1 * 2.2
	_mh_fx.position = Vector2(260 - out1 * 900 - FX_PAD.x * sx, 290 - FX_PAD.y)
	_mh_fx.scale = Vector2(sx, 1)
	_mh_fx.blur = out1 * 18.0
	_mh_fx.modulate.a = 1.0 - out1 * 0.6
	_mh_jp.modulate.a = (float(fi % 2) if f < 99 else 1.0) if f > 96 else 0.0
	_mh.apply(func(i: int) -> Variant:
		var li := SCFBrand.MH_FULL_M.find(i)
		if li >= 0:
			var at: float = SLAMS[li]
			if f < at - 10:
				return {hide = true}
			var t := MK.interp(f, [at - 10, at], [0, 1], func(x: float) -> float: return x * x * x)
			var d := {tx = (1.0 - t) * 760.0}
			if t < 1.0:
				d.blur = Vector2(26, 0)
				d.blur_region = Rect2(-0.5, -0.1, 2.0, 1.2)
			if f >= at and f < at + 2:
				d.fill = Color.WHITE
			return d
		var at := STAMP0 + (i - 3) * 2.2
		if f < at:
			return {hide = true}
		var t := MK.prog(f, at, 5)
		var d := {s = lerpf(2.4, 1.0, t)}
		if f < at + 2:
			d.fill = Color.WHITE
		return d)
	# PRESENTS slab: flex row; MH/01 pushed right by margin-left: auto
	var sw := MK.map(f, [108, 116], [0, 860])
	_slab.size.x = sw
	var lh := 84.0
	_slab_pres.position = Vector2(28, (lh - _slab_pres.get_text_size().y) * 0.5)
	var after_pres := 28 + _slab_pres.get_text_size().x
	_slab_jp.position = Vector2(after_pres + 40, (lh - _slab_jp.get_text_size().y) * 0.5)
	var after_jp := after_pres + 40 + _slab_jp.get_text_size().x
	var idw := _slab_id.get_text_size().x
	_slab_id.position = Vector2(maxf(sw - 22 - idw, after_jp), (lh - _slab_id.get_text_size().y) * 0.5)

	# SCF lockup
	_scf_box.visible = f >= 140
	var M: Dictionary = SCFBrand.SCF_MARK
	var data := _scf.data
	_scf.apply(func(i: int) -> Variant:
		var d := ""
		if i == M.discS or (M.S as Array).has(i): d = "S"
		elif i == M.discC or (M.C as Array).has(i): d = "C"
		elif i == M.discF or (M.F as Array).has(i): d = "F"
		if d != "":
			var bb: Rect2 = data.parts[M["disc" + d]].bbox
			var at: float = LAND[d]
			if f < at - 22:
				return {hide = true}
			var t := MK.map(f, [at - 22, at], [0, 1], MK.ease_out)
			var tx := (1.0 - t) * 190.0
			var o := {tx = tx, rot = rad_to_deg(tx / (bb.size.x * 0.5)), pivot = bb.get_center()}
			if t < 0.85:
				o.blur = Vector2(3, 0)
				o.blur_region = Rect2(-0.5, -0.1, 2.0, 1.2)
			return o
		if (M.edges as Array).has(i):
			if f < 180:
				return {hide = true}
			var on := f > 194 or [181, 182, 185, 188, 189, 192].has(fi)
			return {fill = SCFBrand.AMBER if f < 196 else SCFBrand.CREAM} if on else {hide = true}
		var k := (M.nodes as Array).find(i)
		var s := MK.spring(f, 188 + k * 2.0, 9, 180)
		return {hide = true} if s <= 0.001 else {s = s})
	_rings.draw_fn = func(c: MotionCanvas, ff: float) -> void:
		for d in ["S", "C", "F"]:
			var bb: Rect2 = data.parts[M["disc" + d]].bbox
			var t := MK.prog(ff, LAND[d], 14)
			if t <= 0.0 or t >= 1.0:
				continue
			c.ring(bb.get_center() * _scf_k, bb.size.x * 0.5 * _scf_k * (1.0 + t * 0.9), SCFBrand.AMBER, 10.0 * (1.0 - t))
	_glint.visible = f > 236 and f < 262
	if _glint.visible:
		var p := MK.map(f, [236, 262], [-30, 110]) / 100.0
		_glint.positions = PackedFloat32Array([p - 0.12, p, p + 0.12])

	# SCF title: a centred flex row of words, then the typed JP line, then the tags
	_title.visible = f >= 196
	if _title.visible:
		var gap := 34.0
		var widths := 0.0
		for w in _words:
			widths += w.get_text_size().x
		var x := 960.0 - (widths + gap * (_words.size() - 1)) * 0.5
		var row_h := _words[0].get_text_size().y
		for i in _words.size():
			var w := _words[i]
			var sz := w.get_text_size()
			var at := 198.0 + i * 6.0
			var t := MK.map(MK.step(f, 2), [at, at + 10], [0, 1], MK.ease_out)
			w.visible = t > 0.0
			var c := Vector2(x + sz.x * 0.5, 716 + row_h * 0.5)
			var skew := tan(deg_to_rad((1.0 - t) * -25.0))
			var tx := (1.0 - t) * (900.0 if i % 2 == 1 else -900.0)
			# translateX then skewX about the span's centre (CSS transform-origin)
			w.transform = Transform2D(Vector2(1, 0), Vector2(skew, 1), c + Vector2(tx, 0)) * Transform2D(0.0, -c + Vector2(x, 716))
			x += sz.x + gap
		_title_jp.text = MK.typed(SCFBrand.JP.scf, f, 214, 40)
		var jp_y := 716 + row_h + 18
		_title_jp.position = Vector2(0, jp_y)
		var jp_h := _title_jp.get_text_size().y
		if jp_h <= 0.0:
			_title_jp.text = " "
			jp_h = _title_jp.get_text_size().y
			_title_jp.text = ""
		var pill_y := jp_y + jp_h + 28
		var total := 0.0
		for p in _pills:
			total += p.get_box_size().x
		total += 18.0 * (_pills.size() - 1)
		var px := 960.0 - total * 0.5
		for i in _pills.size():
			var p := _pills[i]
			var bs := p.get_box_size()
			p.position = Vector2(px + bs.x * 0.5, pill_y + bs.y * 0.5)
			px += bs.x + 18.0
			p.visible = f > 226 and f > 226 + i * 3

	# hazard bands
	var t0 := MK.prog(f, 12, 10) * (1.0 - MK.prog(f, 136, 6)) + MK.prog(f, 196, 10)
	var t1 := MK.prog(f, 15, 10) * (1.0 - MK.prog(f, 136, 6)) + MK.prog(f, 199, 10)
	_haz[0].position.x = (1.0 - t0) * 2000.0 * -1.0
	_haz[1].position.x = (1.0 - t1) * 2000.0
	_haz_grad[0].shift = Vector2(f * 6.0, 0)
	_haz_grad[1].shift = Vector2(-f * 6.0, 0)

	# HUD
	_brackets.visible = f > 6 and not (f > 8 and f < 11)
	var hud_on := f > 10
	for n in [_hud_tl, _hud_tr, _hud_br]:
		n.visible = hud_on
	for n in _hud_bl:
		n.visible = hud_on
	_hud_tl.text = "MH-IDENT/01 · " + SCFBrand.JP.boot
	_hud_tl.position = Vector2(150, 100)
	_hud_tr.text = "SECTOR %s · %s" % ["01" if f < 140 else "02", "MINIMAL HUMANS" if f < 140 else "SCF"]
	_hud_tr.position = Vector2(1920 - 150 - _hud_tr.get_text_size().x, 100)
	_hud_bl[1].text = "%04d" % maxi(0, vel)
	var bx := 150.0
	for n in _hud_bl:
		n.position = Vector2(bx, 1080 - 100 - n.get_text_size().y)
		bx += n.get_text_size().x
	_hud_br.text = ("LAP 1/2" if f < 140 else "LAP 2/2") + " · " + SCFBrand.JP.warning
	_hud_br.position = Vector2(1920 - 150 - _hud_br.get_text_size().x, 1080 - 100 - _hud_br.get_text_size().y)
	_flash.visible = f >= 140 and f < 143
	_slam_flash.visible = SLAMS.has(float(fi)) and is_equal_approx(f, float(fi))
