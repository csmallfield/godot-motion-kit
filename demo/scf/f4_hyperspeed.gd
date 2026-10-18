# SPDX-License-Identifier: Apache-2.0
# F4 — HYPERSPEED, ported from scf-intros src/intros/F4_Hyperspeed.tsx.
# A Wipeout race start in flat colour: an octagonal tunnel of colour bands
# rushing at the camera, HUD chevrons and a speed readout. The M comes out of
# the vanishing point and brakes hard into the lockup. Boost: the tunnel
# recolours, S, C and F fly out of the distance like checkpoints and brake into
# place, the mark wires up, the wordmark skids in, and the camera dives into the C.
@tool
extends MotionComposition

const OUT := 352
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM
const N := 26
const MH_X := 210.0
const MH_Y := 330.0
const MH_W := 1500.0
const S_W := 1560.0
const S_X := 180.0
const S_Y := 290.0
const CHECK := [176, 192, 208]

static var _travel: PackedFloat64Array

var _built := false
var _bg: ColorRect
var _world: Node2D
var _tunnel_group: MotionFX
var _tunnel: MotionCanvas
var _flash: ColorRect
var _b1: Node2D
var _ghosts: Array = []         # [CanvasGroup, MotionSvg]
var _words1: MotionSvg
var _presents: MotionText
var _b2: Node2D
var _mark: MotionSvg
var _dc: Array[Vector2] = []
var _sk := 1.0
var _stamps: Array = []
var _tags: Node2D
var _tag_presents: MotionText
var _hud: Node2D
var _chev: Array[MotionCanvas] = []
var _speed: MotionText
var _kmh: MotionText
var _bar_bg: ColorRect
var _bar: ColorRect
var _jp: MotionText
var _hud_line: MotionText
var _end: ColorRect


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


static func speed_at(f: float) -> float:
	if f < 18:
		return MK.map(f, [0, 18], [0, 0.18])
	if f < 84:
		return MK.map(f, [18, 50], [0.18, 0.62])
	if f < 148:
		return MK.map(f, [84, 100], [0.62, 0.025], MK.ease_in_out)
	if f < 236:
		return MK.interp(f, [148, 160], [0.025, 0.9], MK.ease_in_quad) - MK.map(f, [168, 236], [0, 0.82], MK.ease_in_out)
	if f < OUT + 10:
		return 0.08
	return MK.interp(f, [OUT + 10, OUT + 40], [0.08, 1.2], MK.ease_in_quad)


static func _travel_at(f: float) -> float:
	if _travel.is_empty():
		_travel.resize(423)
		_travel[0] = 0.0
		for i in range(1, 423):
			_travel[i] = _travel[i - 1] + speed_at(i)
	return _travel[clampi(int(floorf(f)), 0, _travel.size() - 1)]


static func _vp(f: float) -> Vector2:
	return Vector2(960 + sin(f / 37.0) * 120, 520 + cos(f / 47.0) * 70)


func _text(parent: Node, font: Font, size: float, col: Color, s := "", track := 0.0) -> MotionText:
	var t := MotionText.new()
	t.font = font
	t.font_size = size
	t.color = col
	t.tracking = track
	t.text = s
	parent.add_child(t)
	return t


func _build() -> void:
	_built = true
	_bg = PrintKit.rect(self, Rect2(0, 0, 1920, 1080), INK)
	_world = Node2D.new()
	add_child(_world)
	# The <svg>: a 1920 x 1080 box that clips its polygons, with group opacity.
	# (A CanvasGroup neither clips nor copes with the near octagons' huge bounds.)
	_tunnel_group = MotionFX.new()
	_world.add_child(_tunnel_group)
	_tunnel = MotionCanvas.new()
	_tunnel_group.content.add_child(_tunnel)
	_tunnel.draw_fn = _draw_tunnel
	_flash = PrintKit.rect(self, Rect2(0, 0, 1920, 1080), CREAM)

	# beat 1: the M and three motion ghosts from the vanishing point
	_b1 = Node2D.new()
	add_child(_b1)
	for gi in 4:
		var g := CanvasGroup.new()
		_b1.add_child(g)
		var m := MotionSvg.new()
		m.data = SCFBrand.logo("mhFull")
		m.width = MH_W
		m.only = PackedInt32Array(SCFBrand.MH_FULL_M)
		g.add_child(m)
		_ghosts.append([g, m])
	_words1 = MotionSvg.new()
	_words1.data = SCFBrand.logo("mhFull")
	_words1.width = MH_W
	_words1.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_words1.position = Vector2(MH_X, MH_Y)
	_b1.add_child(_words1)
	_presents = _text(_b1, PrintKit.mono_font(700), 30, SCFBrand.AMBER, "PRESENTS ▸▸▸", 0.5)
	_presents.position = Vector2(MH_X + 380, MH_Y + 420)

	# beat 2: checkpoints
	_b2 = Node2D.new()
	add_child(_b2)
	var full := SCFBrand.logo("scfFull")
	_sk = S_W / full.view_box.size.x
	var F: Dictionary = SCFBrand.SCF_FULL
	for i in [F.discS, F.discC, F.discF]:
		_dc.append(Vector2(S_X, S_Y) + (full.parts[i].bbox as Rect2).get_center() * _sk)
	_mark = MotionSvg.new()
	_mark.data = full
	_mark.width = S_W
	_mark.position = Vector2(S_X, S_Y)
	_b2.add_child(_mark)
	for d in 3:
		var stamp := Node2D.new()
		stamp.position = _dc[d] + Vector2(-90, 110)
		_b2.add_child(stamp)
		var t := MotionText.new()
		t.font = PrintKit.mono_font(700)
		t.font_size = 24
		t.color = INK
		t.text = "%s ✓ 00:0%d.%d" % ["SCF"[d], 4 + d, int(floorf(MK.rand(d) * 90 + 10))]
		t.position = Vector2(10, 4)
		PrintKit.rect(stamp, Rect2(Vector2.ZERO, t.get_text_size() + Vector2(20, 8)), [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED][d])
		stamp.add_child(t)
		_stamps.append(stamp)
	# OPEN FORMAT / 1.0 / LAP: flex, gap 14, centred, each span skewX(-12deg)
	_tags = Node2D.new()
	_tags.position = Vector2(S_X + 110 * _sk, S_Y + 90 * _sk)
	_b2.add_child(_tags)
	var spans := []
	var h := 0.0
	for k in 3:
		var t := MotionText.new()
		t.font = PrintKit.mono_font(700) if k == 2 else SCFBrand.font("outfit", 800)
		t.font_size = 26
		t.tracking = 0.1
		t.color = INK if k == 2 else CREAM
		t.text = ["OPEN FORMAT", "1.0", "LAP 01 · 00:08.40"][k]
		var sz := t.get_text_size() + Vector2(32, 12)
		spans.append([t, sz])
		h = maxf(h, sz.y)
	var x := 0.0
	for k in 3:
		var t: MotionText = spans[k][0]
		var sz: Vector2 = spans[k][1]
		var span := Node2D.new()
		var c := Vector2(x, (h - sz.y) * 0.5) + sz * 0.5
		span.transform = Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(-12.0)), 1), c) * Transform2D(0.0, -sz * 0.5)
		_tags.add_child(span)
		if k < 2:
			PrintKit.rect(span, Rect2(Vector2.ZERO, sz), [INK, SCFBrand.RED][k])
		t.position = Vector2(16, 6)
		span.add_child(t)
		x += sz.x + 14
	_tag_presents = _text(_b2, SCFBrand.font("outfit", 800), 28, INK, "MINIMAL HUMANS PRESENTS", 0.32)
	_tag_presents.position = Vector2(S_X + 110 * _sk, S_Y - 62)

	# HUD
	_hud = Node2D.new()
	add_child(_hud)
	for spec in [[60.0, -1.0], [1500.0, 1.0]]:
		var ch := MotionCanvas.new()
		ch.position = Vector2(spec[0], 505)
		var flip: float = spec[1]
		if flip < 0:
			ch.transform = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(spec[0] + 326, 505))
		_hud.add_child(ch)
		ch.draw_fn = func(c: MotionCanvas, f: float) -> void:
			for i in 6:
				var o := 1.0 if posmod(floori(f / 2.0) + i, 6) < 3 else 0.18
				var ox := i * 56.0
				c.polygon(PackedVector2Array([Vector2(ox, 0), Vector2(ox + 22, 0), Vector2(ox + 46, 35), Vector2(ox + 22, 70), Vector2(ox, 70), Vector2(ox + 24, 35)]), c.get_meta("col", SCFBrand.AMBER), Color(0, 0, 0, 0), 1.0, o)
		_chev.append(ch)
	_speed = _text(_hud, PrintKit.mono_font(700), 64, CREAM, "000", 0.04)
	_kmh = _text(_hud, PrintKit.mono_font(700), 26, CREAM, "KM/H", 0.04)
	_bar_bg = PrintKit.rect(_hud, Rect2(60, 1080 - 30 - 8, 420, 8), Color(1, 1, 1, 0.15))
	_bar = PrintKit.rect(_hud, Rect2(60, 1080 - 30 - 8, 0, 8), SCFBrand.AMBER)
	_jp = _text(_hud, SCFBrand.font("jp", 900), 30, CREAM)
	_jp.align = HORIZONTAL_ALIGNMENT_RIGHT
	_jp.position = Vector2(1920 - 60, 46)
	_hud_line = _text(_hud, PrintKit.mono_font(700), 22, SCFBrand.AMBER, "", 0.2)
	_hud_line.align = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_line.position = Vector2(1920 - 60, 90)
	_end = PrintKit.rect(self, Rect2(0, 0, 1920, 1080), INK)


func _draw_tunnel(c: MotionCanvas, f: float) -> void:
	var boost := f >= 148
	var pal := [SCFBrand.BLUE, CREAM, SCFBrand.AMBER, CREAM, SCFBrand.RED, CREAM, INK, CREAM] if boost \
		else [INK, SCFBrand.RED, INK, Color("#1d1d1d"), SCFBrand.AMBER, INK, Color("#1d1d1d"), CREAM]
	var tr := _travel_at(f)
	var vp := _vp(f)
	var rings := []
	for k in N:
		var raw := fposmod(k - tr, float(N))
		rings.append({k = int(round(k - floorf((k - tr) / N) * N)), z = 0.35 + raw})
	rings.sort_custom(func(a, b): return a.z < b.z)
	for r in rings:
		var s: float = 900.0 / r.z
		var t := minf(1.0, r.z / 6.0)
		var cx := lerpf(960, vp.x, t)
		var cy := lerpf(540, vp.y, t)
		var pts := PackedVector2Array()
		for i in 8:
			var a := PI / 8 + i * PI / 4
			pts.append(Vector2(cx + cos(a) * s * 1.25, cy + sin(a) * s))
		c.polygon(pts, pal[posmod(r.k, pal.size())], Color(0, 0, 0, 0))


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var sp := func(at: float, d: float, k: float) -> float: return SCFBrand.sp(f, at, d, k)
	var fi := int(floorf(f))
	var o := f - OUT
	var boost := f >= 148
	var vp := _vp(f)
	var roll := sin(f / 45.0) * 7
	var spd := speed_at(f)
	var jolt := MK.shakes(f, [96, 150] + CHECK.map(func(c): return c + 6), 16, 8)
	_bg.color = CREAM if boost else INK

	# tunnel: rotate(roll) scale(1.12) translate(jolt) about the centre
	var c := Vector2(960, 540)
	_world.transform = Transform2D(0.0, c) * Transform2D(deg_to_rad(roll), Vector2.ZERO) \
		* Transform2D(Vector2(1.12, 0), Vector2(0, 1.12), Vector2.ZERO) * Transform2D(0.0, jolt - c)
	var o1 := MK.map(f, [0, 10], [0, 1]) * (1 - 0.72 * MK.map(f, [92, 110], [0, 1]))
	var o2 := MK.map(f, [148, 152], [0, 1]) * (1 - 0.8 * MK.map(f, [232, 256], [0, 1])) + 0.8 * MK.map(o, [6, 20], [0, 1])
	_tunnel_group.modulate.a = o2 if boost else o1
	_tunnel.queue_redraw()
	_flash.visible = f >= 148 and f < 156
	_flash.color = CREAM if fi % 2 else SCFBrand.AMBER
	_flash.modulate.a = MK.map(f, [148, 156], [1, 0])

	# beat 1
	_b1.visible = f >= 52 and f < 150
	if _b1.visible:
		_b1.position = jolt
		var brake: float = sp.call(92, 9, 160)
		var lags := [0.18, 0.12, 0.06, 0.0]
		for gi in 4:
			var g: CanvasGroup = _ghosts[gi][0]
			var t := clampf(MK.interp(f - lags[gi] * 40, [52, 92], [0, 1], func(u: float) -> float: return u * u * u), 0.0, 1.0)
			g.visible = not (gi < 3 and (t >= 1.0 or f >= 98))
			var s := lerpf(0.03, 1, t) * (1.0 + (1.0 - brake) * 0.14 if f >= 92 else 1.0)
			g.position = Vector2(lerpf(vp.x - 60, MH_X, t), lerpf(vp.y - 64, MH_Y, t))
			g.scale = Vector2.ONE * s
			g.self_modulate.a = 0.25 + gi * 0.12 if gi < 3 else 1.0
		_words1.visible = f >= 100
		var words: Array = SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS
		_words1.apply(func(i: int):
			var s: float = sp.call(100 + words.find(i) * 1.6, 12, 170)
			return {tx = (1 - s) * 900, sx = 1 + (1 - s) * 1.6, fill = CREAM})
		_presents.modulate.a = MK.map(f, [120, 126], [0, 1]) * (1.0 if (fi % 4 < 3 or f > 132) else 0.0)

	# beat 2
	_b2.visible = boost
	if boost:
		if o > 8:
			var dive := MK.interp(o, [8, 40], [1, 70], func(t: float) -> float: return t * t * t)
			_b2.transform = Transform2D(Vector2(dive, 0), Vector2(0, dive), _dc[1] - _dc[1] * dive)
		else:
			_b2.transform = Transform2D(0.0, jolt)
		_frame_mark(f, vp, sp)
		for d in 3:
			_stamps[d].visible = f >= CHECK[d] and f < CHECK[d] + 26 and posmod(fi - CHECK[d], 4) < 3
		var fade := 1 - MK.map(o, [0, 6], [0, 1])
		_tags.modulate.a = MK.map(f, [262, 270], [0, 1]) * fade
		_tag_presents.modulate.a = MK.map(f, [258, 266], [0, 1]) * fade

	# HUD
	_hud.visible = f < OUT + 4
	if _hud.visible:
		for ch in _chev:
			ch.visible = spd > 0.3
			ch.set_meta("col", SCFBrand.RED if boost else SCFBrand.AMBER)
			ch.queue_redraw()
		var col := INK if boost else CREAM
		_speed.color = col
		_kmh.color = col
		_speed.text = "%03d" % int(round(spd * 1100))
		# the line box is the 64 px text's; KM/H shares its baseline, 12 px after it
		_speed.position = Vector2(60, 1080 - 50 - _speed.get_text_size().y)
		_kmh.position = _speed.position + Vector2(_speed.get_text_size().x + 12, _speed.get_baseline() - _kmh.get_baseline())
		_bar_bg.color = Color(0, 0, 0, 0.15) if boost else Color(1, 1, 1, 0.15)
		_bar.color = SCFBrand.RED if boost else SCFBrand.AMBER
		_bar.size.x = 420 * minf(1.0, spd)
		_jp.color = col
		_jp.text = SCFBrand.JP.scf.substr(0, 6) if boost else SCFBrand.JP.mh
		_hud_line.color = SCFBrand.RED if boost else SCFBrand.AMBER
		_hud_line.text = "BOOST ▲ SCF-1.0" if boost else "MH-001 ▸ LAUNCH"
	_end.visible = o > 34
	_end.modulate.a = MK.map(o, [34, 44], [0, 1])


func _frame_mark(f: float, vp: Vector2, sp: Callable) -> void:
	var F: Dictionary = SCFBrand.SCF_FULL
	var disc_i := [F.discS, F.discC, F.discF]
	var words: Array = F.story + F.context + F.framework
	var skid: float = sp.call(236, 12, 120)
	_mark.apply(func(i: int):
		if i == F.cloud:
			return {hide = true}
		var d := disc_i.find(i)
		if d < 0:
			d = 0 if (F.S as Array).has(i) else (1 if (F.C as Array).has(i) else (2 if (F.F as Array).has(i) else -1))
		if d >= 0:
			var t0: float = CHECK[d] - 22
			if f < t0:
				return {hide = true}
			var t := minf(1.0, MK.interp(f, [t0, CHECK[d]], [0, 1], func(u: float) -> float: return u * u * u))
			var br: float = sp.call(CHECK[d], 8, 200)
			var pv := vp - Vector2(S_X, S_Y)
			var target: Vector2 = _dc[d]
			var off := (target - Vector2(S_X, S_Y))
			return {tx = lerpf(pv.x - off.x, 0, t) / _sk, ty = lerpf(pv.y - off.y, 0, t) / _sk,
				s = lerpf(0.02, 1, t) * (1.0 + (1.0 - br) * 0.25 if f >= CHECK[d] else 1.0), pivot = off / _sk}
		if (F.edges as Array).has(i):
			var s := MK.map(f, [222, 232], [0, 1])
			return {hide = true} if s <= 0.01 else {s = s, pivot = Vector2(52.8, 43.4)}
		var k := (F.nodes as Array).find(i)
		if k >= 0:
			var s: float = sp.call(224 + k * 1.3, 7, 220)
			return {hide = true} if s <= 0.01 else {s = s}
		if words.has(i):
			if f < 234:
				return {hide = true}
			var s := minf(1.0, skid)
			return {tx = (1 - s) * 200, sx = 1 + (1 - s) * 0.8, fill = INK}
		return null)
