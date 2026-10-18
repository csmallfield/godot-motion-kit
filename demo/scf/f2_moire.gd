# SPDX-License-Identifier: Apache-2.0
# F2 — MOIRÉ, ported from scf-intros src/intros/F2_Moire.tsx.
# Op-art: two sets of rings drift across each other and the interference does
# the drawing; the M is there only because its fill runs a different way. It
# locks solid, the wordmark combs in, the rings rush out to black. Three ring
# targets slide in, beat against each other and thicken into the S, C and F
# discs; the mark wires up, the wordmark combs in, it holds, and the discs come
# apart back into rings that expand out of frame.
@tool
extends MotionComposition

const OUT := 352
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const M_W := 470.0
const M_X := 250.0
const M_Y := 300.0
const S_W := 1560.0
const S_X := 180.0
const S_Y := 300.0

var _built := false
var _bg: ColorRect
var _b1: MotionFX
var _rush: Node2D
var _rush_top: Node2D
var _r1: MotionGradient
var _r2: MotionGradient
var _mclip: Polygon2D
var _mfill: ColorRect
var _bars: MotionCanvas
var _msolid: ColorRect
var _m: MotionSvg
var _comb1: Comb
var _word1: MotionSvg
var _presents: MotionText
var _b2: Node2D
var _drift: Array[MotionGradient] = []
var _expand: Node2D
var _targets: Array[MotionGradient] = []
var _targets_iso: Array[MotionGradient] = []
var _expand_fx: MotionFX
var _expand_iso: Node2D
var _ds: Array = []
var _mark: MotionSvg
var _comb2: Comb
var _word2: MotionSvg
var _tags: Node2D
var _tag_presents: MotionText
var _sk := 1.0


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


static func _rect(parent: Node, r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


## A comb mask (repeating-linear-gradient(0deg, #000 0 h, transparent h pitch)
## as mask-image): teeth h px tall grow up from the bottom of each `pitch` band,
## counted from the box's bottom edge. Children show only through the teeth.
## (Drawn as plain rects: clip_children takes no mask from a shader-drawn node.)
class Comb:
	extends MotionCanvas
	var box := Vector2.ZERO
	var pitch := 14.0
	var t := 0.0

	func _init(sz: Vector2, p: float) -> void:
		box = sz
		pitch = p
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		draw_fn = func(c: MotionCanvas, _f: float) -> void:
			if t >= 1.0:
				c.rect(Rect2(Vector2.ZERO, box), Color.WHITE)
				return
			var h := clampf(t * pitch, 0.0, pitch)
			if h <= 0.0:
				return
			# Teeth under a pixel tall draw one pixel high with their height as
			# coverage, as the browser's rasterized mask does.
			var col := Color(1, 1, 1, minf(1.0, h))
			var hh := maxf(h, 1.0)
			var y := box.y
			while y > 0.0:
				c.rect(Rect2(0, maxf(0.0, y - hh), box.x, minf(hh, y)), col)
				y -= pitch

	func set_t(v: float) -> void:
		t = v
		queue_redraw()


func _build() -> void:
	_built = true
	_bg = _rect(self, Rect2(0, 0, 1920, 1080), CREAM)

	# ---- beat 1: one transformed (so isolated) group, as in the original
	_b1 = MotionFX.new()
	add_child(_b1)
	_rush = Node2D.new()
	_b1.content.add_child(_rush)
	_r1 = MotionGradient.rings(Vector2(1920, 1080), Vector2.ZERO, INK, 9, 22, 1, 8)
	_rush.add_child(_r1)
	_r2 = MotionGradient.rings(Vector2(1920, 1080), Vector2.ZERO, SCFBrand.RED, 9, 23, 90, 6)
	_r2.blend = MotionGradient.Blend.MULTIPLY
	_rush.add_child(_r2)
	# Everything above the multiply layer is normal-blend, so it composites the
	# same drawn after the isolated group; and clip_children loses texture and
	# modulate alpha inside a transparent SubViewport (Compatibility renderer).
	_rush_top = Node2D.new()
	add_child(_rush_top)
	# the M: cut from bars instead of rings, so only the interference draws it
	var mk := M_W / 120.63
	var poly := PackedVector2Array()
	var pts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://demo/scf/m_outline.json")).mOutline
	for p in pts:
		poly.append(Vector2(M_X + p[0] * mk, M_Y + p[1] * mk))
	_mclip = Polygon2D.new()
	_mclip.polygon = poly
	_mclip.antialiased = true
	_mclip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_rush_top.add_child(_mclip)
	_mfill = _rect(_mclip, Rect2(0, 0, 1920, 1080), CREAM)
	_bars = MotionCanvas.new()
	_mclip.add_child(_bars)
	_bars.draw_fn = func(c: MotionCanvas, f: float) -> void:
		for i in 70:
			c.rect(Rect2(M_X - 40 + i * 18 + fmod(f * 1.5, 18.0), 0, 9, 1080), SCFBrand.BLUE if i % 7 == 3 else INK)
	_msolid = _rect(_mclip, Rect2(0, 0, 1920, 1080), CREAM)
	_m = MotionSvg.new()
	_m.data = SCFBrand.logo("mhM")
	_m.width = M_W
	_m.position = Vector2(M_X, M_Y)
	_rush_top.add_child(_m)
	var wh := 1000.0 * 128.89 / 345.7
	_comb1 = Comb.new(Vector2(1000, wh + PrintKit.STRUT_GAP), 14)
	_comb1.position = Vector2(790, 300 + (470 - wh) / 2.0)
	_rush_top.add_child(_comb1)
	_word1 = MotionSvg.new()
	_word1.data = SCFBrand.logo("mhFull")
	_word1.width = 1000
	_word1.crop = Rect2(140, 0, 345.7, 128.89)
	_word1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_word1.apply(func(_i): return {fill = INK})
	_comb1.add_child(_word1)
	_presents = MotionText.new()
	_presents.font = SCFBrand.font("outfit", 900)
	_presents.font_size = 40
	_presents.tracking = 0.6
	_presents.color = SCFBrand.RED
	_presents.text = "PRESENTS"
	_presents.position = Vector2(800, 840)
	add_child(_presents)

	# ---- beat 2
	_b2 = Node2D.new()
	add_child(_b2)
	for spec in [[26.0, Vector2(960, 540)], [27.0, Vector2(1040, 600)]]:
		var g := MotionGradient.rings(Vector2(1920, 1080), spec[1], CREAM, 3, spec[0], 90, 6)
		_b2.add_child(g)
		_drift.append(g)
	_expand = Node2D.new()
	_b2.add_child(_expand)
	# Once the group scales (o > 22) its CSS transform makes it an isolated
	# stacking context: the targets then screen against each other only. A
	# second set inside a MotionFX reproduces that phase.
	_expand_fx = MotionFX.new()
	_b2.add_child(_expand_fx)
	_expand_iso = Node2D.new()
	_expand_fx.content.add_child(_expand_iso)
	var full := SCFBrand.logo("scfFull")
	_sk = S_W / full.view_box.size.x
	var F: Dictionary = SCFBrand.SCF_FULL
	for i in [F.discS, F.discC, F.discF]:
		var bb: Rect2 = full.parts[i].bbox
		_ds.append({c = Vector2(S_X, S_Y) + bb.get_center() * _sk, r = bb.size.x * 0.5 * _sk})
	var cols := [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]
	for k in 3:
		var t := MotionGradient.rings(Vector2(1920, 1080), _ds[k].c, cols[k], 8, 26, 60, 4)
		t.blend = MotionGradient.Blend.SCREEN
		_expand.add_child(t)
		_targets.append(t)
		var ti := MotionGradient.rings(Vector2(1920, 1080), _ds[k].c, cols[k], 8, 26, 60, 4)
		ti.blend = MotionGradient.Blend.SCREEN
		_expand_iso.add_child(ti)
		_targets_iso.append(ti)
	_mark = MotionSvg.new()
	_mark.data = full
	_mark.width = S_W
	_mark.position = Vector2(S_X, S_Y)
	_b2.add_child(_mark)
	_comb2 = Comb.new(Vector2(S_W, _mark.get_size().y + PrintKit.STRUT_GAP), 12)
	_comb2.position = Vector2(S_X, S_Y)
	_b2.add_child(_comb2)
	_word2 = MotionSvg.new()
	_word2.data = full
	_word2.width = S_W
	_word2.only = PackedInt32Array(F.story + F.context + F.framework)
	_word2.apply(func(_i): return {fill = CREAM})
	_comb2.add_child(_word2)

	# OPEN FORMAT — 1.0: flex row, gap 22, centred on the line
	_tags = Node2D.new()
	_tags.position = Vector2(S_X + 110 * _sk, S_Y + 90 * _sk)
	_b2.add_child(_tags)
	var t1 := _tag_text("OPEN FORMAT", CREAM)
	_tags.add_child(t1)
	var lh := t1.get_text_size().y
	var x := t1.get_text_size().x + 22
	_rect(_tags, Rect2(x, (lh - 4) / 2.0, 40, 4), SCFBrand.RED)
	var t2 := _tag_text("1.0", SCFBrand.AMBER)
	t2.position = Vector2(x + 40 + 22, 0)
	_tags.add_child(t2)
	_tag_presents = _tag_text("MINIMAL HUMANS PRESENTS", CREAM)
	_tag_presents.position = Vector2(S_X + 110 * _sk, S_Y - 60)
	_b2.add_child(_tag_presents)


static func _tag_text(s: String, col: Color) -> MotionText:
	var t := MotionText.new()
	t.font = SCFBrand.font("outfit", 800)
	t.font_size = 28
	t.tracking = 0.32
	t.color = col
	t.text = s
	return t


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var b1 := f < 158
	_bg.color = CREAM if b1 else INK
	_b1.visible = b1
	_rush_top.visible = b1
	_b2.visible = not b1
	_presents.visible = f >= 118 and f < 158
	_presents.modulate.a = MK.map(f, [118, 128], [0, 1]) * (1 - MK.map(f, [146, 152], [0, 1]))

	if b1:
		var grow := MK.map(f, [0, 22], [0, 1], MK.ease_in_out)
		var drift := MK.map(f, [14, 96], [0, 1], MK.ease_in_out)
		var a1 := Vector2(960 + sin(f / 26.0) * 70, 540 + cos(f / 31.0) * 40)
		var a2 := Vector2(lerpf(1500, 980, drift) + cos(f / 19.0) * 50, lerpf(260, 560, drift))
		var calm := 1.0 - 0.8 * MK.map(f, [100, 118], [0, 1]) + 0.8 * MK.map(f, [142, 150], [0, 1])
		var rush := MK.interp(f, [146, 160], [1, 9], MK.ease_in_quad)
		_rush.transform = Transform2D(Vector2(rush, 0), Vector2(0, rush), a1 - a1 * rush)
		_rush_top.transform = _rush.transform
		_r1.ring_center = a1
		_r1.ring_count = int(round(90 * grow)) + 1
		_r1.opacity = calm
		_r2.visible = f >= 14
		_r2.ring_center = a2
		_r2.opacity = MK.map(f, [14, 30], [0, 1]) * calm
		var m_show := MK.map(f, [44, 60], [0, 1])
		_mclip.visible = m_show > 0.0
		_mfill.modulate.a = m_show
		_bars.modulate.a = m_show
		_bars.queue_redraw()
		_msolid.modulate.a = MK.map(f, [98, 110], [0, 1])
		_m.visible = f >= 98
		var layers: float = sp.call(100, 10, 160)
		_m.apply(func(i: int): return {tx = (2 - i) * layers * 9.0, ty = (2 - i) * layers * 9.0, o = 1.0 if i == 2 else layers})
		_comb1.visible = MK.interp(f, [112, 134], [0, 1]) > 0.0    # no teeth: hide it (an empty clip mask clips nothing)
		_comb1.set_t(MK.interp(f, [112, 134], [0, 1]))
		return

	var o := f - OUT
	var undo := func(k: int) -> float: return MK.map(o, [8 + k * 4, 30 + k * 4], [0, 1], MK.ease_in_out)
	_drift[0].ring_center = Vector2(960 + sin(f / 40.0) * 120, 540)
	_drift[0].opacity = 0.08 + 0.06 * MK.map(f, [158, 180], [1, 0])
	_drift[1].ring_center = Vector2(1040 + cos(f / 33.0) * 120, 600)
	_drift[1].opacity = 0.08
	var expand := MK.interp(o, [22, 60], [1, 6], MK.ease_in_quad) if o > 22 else 1.0
	var pc: Vector2 = _ds[1].c
	_expand.transform = Transform2D(Vector2(expand, 0), Vector2(0, expand), pc - pc * expand)
	_expand_iso.transform = _expand.transform
	_expand.visible = o <= 22
	_expand_fx.visible = o > 22
	for k in 3:
		var s: float = sp.call(166 + k * 8, 13, 70)
		var t: float = MK.map(f, [196 + k * 6, 226 + k * 6], [0, 1], MK.ease_in_out) * (1.0 - undo.call(k))
		var off := Vector2((1 - s) * [-1400.0, 0.0, 1400.0][k], (1 - s) * [0.0, 900.0, 0.0][k])
		var gap := lerpf(26, 20, t)
		for g in [_targets[k], _targets_iso[k]]:
			g.ring_center = _ds[k].c + off
			g.ring_gap = gap
			g.ring_count = int(ceilf(lerpf(60, _ds[k].r / gap + 1, t)))
			g.ring_width = lerpf(8, gap + 1, t)
			g.ring_clip = lerpf(1600, _ds[k].r, t)

	_mark.visible = f >= 226
	if _mark.visible:
		var F: Dictionary = SCFBrand.SCF_FULL
		_mark.apply(func(i: int):
			if i == F.cloud or (F.story as Array).has(i) or (F.context as Array).has(i) or (F.framework as Array).has(i):
				return {hide = true}
			if i == F.discS or i == F.discC or i == F.discF:
				return {hide = true}
			var di := 0 if (F.S as Array).has(i) else (1 if (F.C as Array).has(i) else (2 if (F.F as Array).has(i) else -1))
			if di >= 0:
				var s: float = sp.call(226 + di * 4, 9, 200) * (1.0 - undo.call(di))
				return {hide = true} if s <= 0.01 else {s = s}
			if (F.edges as Array).has(i):
				var s := MK.map(f, [232, 244], [0, 1]) * (1 - MK.map(o, [0, 8], [0, 1]))
				return {hide = true} if s <= 0.01 else {s = s, pivot = Vector2(52.8, 43.4), fill = CREAM}
			var k := (F.nodes as Array).find(i)
			if k >= 0:
				var s: float = sp.call(236 + k * 1.5, 7, 220) * (1 - MK.map(o, [k * 0.8, k * 0.8 + 6], [0, 1], MK.ease_in_back))
				return {hide = true} if s <= 0.01 else {s = s}
			return null)
	var wm2 := MK.interp(f, [244, 268], [0, 1]) * (1 - MK.map(o, [0, 14], [0, 1]))
	_comb2.visible = f >= 244 and wm2 > 0.0
	_comb2.set_t(wm2)
	var tag_o := MK.map(f, [272, 284], [0, 1]) * (1 - MK.map(o, [0, 8], [0, 1]))
	_tags.modulate.a = tag_o
	_tag_presents.modulate.a = tag_o * 0.75
