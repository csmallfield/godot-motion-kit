# SPDX-License-Identifier: Apache-2.0
# C — VECTOR TRACK, ported from scf-intros/src/intros/C_VectorTrack.tsx.
# A wireframe flythrough: the M arrives extruded out of the dark, then the SCF
# constellation orbits in 3D and resolves flat. The 3D is hand-rolled
# perspective drawn in 2D, kept exactly as in the original (MK.project).
@tool
extends MotionComposition

const WIRE := Color("#47c4ff")
const BG := Color("#03060d")
const FOC := 900.0
const CX := 960.0
const CY := 540.0
const M_Z := 10600.0
const M_S := 8.0
const S2 := 16.0
const LC := Vector2(47.9, 36.0)
const D_CAM := 1800.0
const LOGO_CY := 450.0
const MH_K := 4.5
const EDGES := [[3, 12], [12, 13], [3, 5], [5, 14], [5, 12], [12, 6], [13, 11], [11, 15], [12, 7], [7, 11], [4, 9], [9, 10], [10, 6], [6, 8], [13, 8], [4, 12]]
const GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/<>#"

var _built := false
var _m_outline: PackedVector2Array
var _node_idx: Array = []
var _nodes := {}            # part index -> {x, y, r, fill, z}
var _tunnel: MotionCanvas
var _dust: MotionCanvas
var _wire_m: MotionCanvas
var _mid_fx: MotionFX
var _mono: MotionSvg
var _mono_group: CanvasGroup
var _word_clip: Control
var _word: MotionSvg
var _wipe: Node2D
var _presents: MotionText
var _mh_jp: MotionText
var _grid: MotionCanvas
var _edges_fx: MotionFX
var _edges: MotionCanvas
var _spheres: MotionCanvas
var _flat_mark: MotionSvg
var _flat_group: CanvasGroup
var _title_fx: MotionFX
var _title: MotionText
var _title_jp: MotionText
var _title_rule: ColorRect
var _hud_tl: MotionText
var _hud_tr: MotionText
var _hud_bl: MotionText
var _flash: ColorRect
var _lock_k := 1.0


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


func _cam_z(f: float) -> float:
	if f < 110:
		return MK.map(f, [0, 110], [0, 9000], MK.ease_in_out)
	return 9000.0 + MK.interp(f, [138, 168], [0, 5200], func(t: float) -> float: return t * t * t)


func _proj(p: Vector3, cam_z: float, cy := CY) -> Variant:
	return MK.project(p, cam_z, FOC, Vector2(CX, cy))


static func _scramble(text: String, f: float, at: float) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		if c == " ":
			out += " "
			continue
		var lock := at + i * 1.2 + 6.0
		if f < at + i * 0.6:
			out += " "
		elif f >= lock:
			out += c
		else:
			out += GLYPHS[int(floorf(MK.rand(i * 13 + f) * GLYPHS.length()))]
	return out


func _build() -> void:
	_built = true
	var bg := MotionGradient.radial(Vector2(1920, 1080), [Color("#0a1830"), BG], [0.0, 0.65])
	add_child(bg)
	var pts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://demo/scf/m_outline.json")).mOutline
	for p in pts:
		_m_outline.append(Vector2(p[0], p[1]))
	var M: Dictionary = SCFBrand.SCF_MARK
	_node_idx = [M.discS] + M.nodes + [M.discC, M.discF]
	var mark := SCFBrand.logo("scfMark")
	for i in _node_idx:
		var p: Dictionary = mark.parts[i]
		var bb: Rect2 = p.bbox
		var c := bb.get_center()
		_nodes[i] = {x = (c.x - LC.x) * S2, y = (c.y - LC.y) * S2, r = bb.size.x * 0.5 * S2, fill = p.fill, z = (MK.rand(i * 4.7) - 0.5) * 1400.0}

	_tunnel = MotionCanvas.new(); add_child(_tunnel)
	_tunnel.draw_fn = _draw_tunnel
	_dust = MotionCanvas.new(); add_child(_dust)
	_dust.draw_fn = _draw_dust
	_wire_m = MotionCanvas.new(); add_child(_wire_m)
	_wire_m.draw_fn = _draw_wire_m

	# MH lockup, in an FX group for the zoom-out blur
	_mid_fx = MotionFX.new(); add_child(_mid_fx)
	# CSS opacity on the M's wrapper is group opacity: the cream face hides the
	# shadow layers beneath it while fading. A CanvasGroup composites it as one.
	_mono_group = CanvasGroup.new(); _mid_fx.content.add_child(_mono_group)
	_mono = MotionSvg.new(); _mono.data = SCFBrand.logo("mhM"); _mono.width = 129.95 * MH_K; _mono_group.add_child(_mono)
	var full := SCFBrand.logo("mhFull")
	_lock_k = 1300.0 / full.view_box.size.x
	_word_clip = Control.new(); _word_clip.clip_contents = true; _word_clip.position = Vector2(310, 380); _word_clip.size = Vector2(0, 129 * _lock_k)
	_word_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_fx.content.add_child(_word_clip)
	_word = MotionSvg.new(); _word.data = full; _word.width = 1300
	_word.only = PackedInt32Array(SCFBrand.MH_FULL_MINIMAL + SCFBrand.MH_FULL_HUMANS)
	_word_clip.add_child(_word)
	_wipe = Node2D.new(); _mid_fx.content.add_child(_wipe)
	var glow := MotionShape.new(); glow.kind = MotionShape.Kind.RECT; glow.anchor = Vector2.ZERO; glow.size = Vector2(4, 360); glow.blur = 30; glow.color = WIRE
	_wipe.add_child(glow)
	var bar := ColorRect.new(); bar.color = Color.WHITE; bar.size = Vector2(4, 360); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.add_child(bar)
	_presents = _text(_mid_fx.content, "michroma", 400, 40, WIRE, 0.6)
	_presents.position = Vector2(310 + 145 * _lock_k, 380 + 129 * _lock_k + 36)
	_mh_jp = _text(_mid_fx.content, "jp", 400, 28, SCFBrand.AMBER, 0.4, SCFBrand.JP.mh)
	_mh_jp.position = Vector2(310 + 145 * _lock_k, 300)

	# constellation: grid and drop lines, glowing edges, spheres
	_grid = MotionCanvas.new(); add_child(_grid)
	_grid.draw_fn = _draw_grid
	_edges_fx = MotionFX.new(); _edges_fx.glow = 6.0; add_child(_edges_fx)
	_edges = MotionCanvas.new(); _edges_fx.content.add_child(_edges)
	_edges.draw_fn = _draw_edges
	_spheres = MotionCanvas.new(); add_child(_spheres)
	_spheres.draw_fn = _draw_spheres
	var flat_w := 95.79 * S2 * (FOC / D_CAM)
	_flat_group = CanvasGroup.new(); add_child(_flat_group)
	_flat_mark = MotionSvg.new(); _flat_mark.data = mark; _flat_mark.width = flat_w
	_flat_mark.position = Vector2(CX - LC.x * S2 * (FOC / D_CAM), LOGO_CY - LC.y * S2 * (FOC / D_CAM))
	_flat_mark.apply(func(i): return {fill = WIRE} if (M.edges as Array).has(i) else null)
	_flat_group.add_child(_flat_mark)

	# title (with a CSS text-shadow glow), JP line and rule
	_title_rule = ColorRect.new(); _title_rule.color = Color(WIRE, 0.6); _title_rule.position = Vector2(360, 780); _title_rule.size = Vector2(1200, 2)
	_title_rule.pivot_offset = Vector2(600, 1); _title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_rule)
	_title_fx = MotionFX.new(); _title_fx.shadow_color = WIRE; _title_fx.shadow_blur = 24.0; add_child(_title_fx)
	_title = _text(_title_fx.content, "michroma", 400, 52, Color.WHITE, 0.22)
	_title.align = HORIZONTAL_ALIGNMENT_CENTER; _title.box_width = 1920; _title.position = Vector2(0, 800)
	_title_jp = _text(self, "jp", 400, 26, SCFBrand.AMBER, 0.5, SCFBrand.JP.scf)
	_title_jp.align = HORIZONTAL_ALIGNMENT_CENTER; _title_jp.box_width = 1920; _title_jp.position = Vector2(0, 890)

	_hud_tl = _text(self, "michroma", 400, 20, WIRE, 0.3)
	_hud_tl.position = Vector2(80, 70)
	_hud_tr = _text(self, "space_mono", 400, 20, SCFBrand.AMBER)
	_hud_bl = _text(self, "jp", 400, 20, WIRE, 0.3)
	_hud_bl.modulate.a = 0.7
	_flash = ColorRect.new(); _flash.color = WIRE; _flash.size = Vector2(1920, 1080); _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


# ---------------------------------------------------------------- drawing

func _draw_tunnel(c: MotionCanvas, f: float) -> void:
	var cam := _cam_z(f)
	var N := 8
	var R := 900.0
	var SP := 320.0
	var first := int(floorf(cam / SP))
	var prev: Array = []
	for k in range(first, first + 22):
		var z := k * SP
		var pts: Array = []
		var ok := true
		for j in N:
			var a := (float(j) / N) * TAU + PI / N
			var p: Variant = _proj(Vector3(cos(a) * R * 1.5, sin(a) * R, z), cam)
			pts.append(p)
			if p == null:
				ok = false
		var dz := z - cam
		var fade := clampf(1.0 - dz / 7000.0, 0.0, 1.0) * minf(1.0, dz / 300.0)
		if ok:
			var poly := PackedVector2Array()
			for p in pts:
				poly.append(Vector2(p.x, p.y))
			c.polyline(poly, SCFBrand.AMBER if k % 4 == 0 else WIRE, 2.5 if k % 4 == 0 else 1.5, fade, true)
			if not prev.is_empty():
				for j in N:
					if prev[j] != null:
						c.line(Vector2(prev[j].x, prev[j].y), Vector2(pts[j].x, pts[j].y), WIRE, 1.0, fade * 0.6)
		prev = pts


func _draw_dust(c: MotionCanvas, f: float) -> void:
	for i in 140:
		var z := fposmod(fposmod(MK.rand(i * 2.3) * 4000.0 - f * 22.0, 4000.0) + 4000.0, 4000.0) + 60.0
		var x := (MK.rand(i * 5.1) - 0.5) * 6000.0
		var y := (MK.rand(i * 7.9) - 0.5) * 3400.0
		var p: Variant = _proj(Vector3(x, y, z), 0.0)
		if p == null:
			continue
		c.circle(Vector2(p.x, p.y), minf(3.5, 900.0 / z), SCFBrand.AMBER if i % 9 == 0 else WIRE, minf(1.0, (4000.0 - z) / 2000.0) * 0.8)


func _draw_wire_m(c: MotionCanvas, f: float) -> void:
	var cam := _cam_z(f)
	var ang := MK.map(f, [30, 112], [1.1, 0], MK.ease_in_out)
	var tilt := MK.map(f, [30, 112], [-0.35, 0], MK.ease_in_out)
	var depth := MK.map(f, [100, 118], [46, 0], MK.ease_out)
	var layers := 8
	var C0 := 60.3
	var P := func(pt: Vector2, d: float) -> Variant:
		var v := Vector3((pt.x - C0) * M_S, (pt.y - C0) * M_S, d * depth)
		v = MK.rot_x(MK.rot_y(v, ang), tilt)
		return _proj(Vector3(v.x, v.y, M_Z + v.z), cam)
	for d in layers:
		var poly := PackedVector2Array()
		var ok := true
		for pt in _m_outline:
			var p: Variant = P.call(pt, d)
			if p == null:
				ok = false
				break
			poly.append(Vector2(p.x, p.y))
		if not ok:
			continue
		var fill := Color(WIRE, 0x14 / 255.0) if d == 0 else Color(0, 0, 0, 0)
		var stroke := Color.WHITE if d == 0 else (SCFBrand.RED if d == layers - 1 else WIRE)
		c.polygon(poly, fill, stroke, 3.0 if d == 0 else 1.4, 1.0 - d * 0.08)
	for i in range(0, _m_outline.size(), 12):
		var a: Variant = P.call(_m_outline[i], 0)
		var b: Variant = P.call(_m_outline[i], layers - 1)
		if a != null and b != null:
			c.line(Vector2(a.x, a.y), Vector2(b.x, b.y), WIRE, 1.2, 0.7)


# Constellation transform: rotate about Y then X, project around LOGO_CY.
func _tr(v: Vector3, th: float, tx: float) -> Dictionary:
	var w := MK.rot_x(MK.rot_y(v, th), tx)
	var dz := D_CAM + w.z
	return {s = Vector2(CX + (w.x * FOC) / dz, LOGO_CY + (w.y * FOC) / dz), k = FOC / dz, dz = dz}


func _con(f: float) -> Dictionary:
	var res := MK.map(f, [200, 252], [0, 1], MK.ease_in_out)
	var th := lerpf(1.5, 0.0, res) + sin(f / 26.0) * 0.06 * (1.0 - res)
	var tx := lerpf(0.42, 0.0, res)
	var pts := {}
	for i in _node_idx:
		var n: Dictionary = _nodes[i]
		pts[i] = _tr(Vector3(n.x, n.y, n.z * (1.0 - res)), th, tx)
	return {res = res, th = th, tx = tx, pts = pts}


func _fog(dz: float) -> float:
	return maxf(0.35, minf(1.0, 1.6 - dz / 2200.0))


func _appear(f: float, i: int) -> float:
	return MK.prog(f, 170.0 + _node_idx.find(i) * 2.0, 12)


func _draw_grid(c: MotionCanvas, f: float) -> void:
	if f < 168:
		return
	var C := _con(f)
	var grid_o := MK.prog(f, 168, 16) * (1.0 - MK.prog(f, 236, 18))
	for i in range(-6, 7):
		var a: Dictionary = _tr(Vector3(i * 220, 520, -1320), C.th, C.tx)
		var b: Dictionary = _tr(Vector3(i * 220, 520, 1320), C.th, C.tx)
		var cc: Dictionary = _tr(Vector3(-1320, 520, i * 220), C.th, C.tx)
		var d: Dictionary = _tr(Vector3(1320, 520, i * 220), C.th, C.tx)
		c.line(a.s, b.s, WIRE, 1.2, 0.5 * grid_o)
		c.line(cc.s, d.s, SCFBrand.AMBER if i == 0 else WIRE, 1.2, 0.5 * grid_o)
	for i in _node_idx:
		var n: Dictionary = _nodes[i]
		var top: Dictionary = C.pts[i]
		var foot: Dictionary = _tr(Vector3(n.x, 520, n.z * (1.0 - C.res)), C.th, C.tx)
		c.dashed(top.s, foot.s, SCFBrand.AMBER, 1.0, 4.0, 6.0, _appear(f, i) * grid_o * 0.7)


func _draw_edges(c: MotionCanvas, f: float) -> void:
	if f < 168:
		return
	var C := _con(f)
	for k in EDGES.size():
		var e: Array = EDGES[k]
		var t := MK.prog(f, 178 + k * 2.0, 14)
		var A: Dictionary = C.pts[e[0]]
		var B: Dictionary = C.pts[e[1]]
		var op := t * (1.0 - MK.prog(f, 252, 10)) * _fog((A.dz + B.dz) * 0.5)
		if op > 0.0:
			c.line(A.s, (A.s as Vector2).lerp(B.s, t), WIRE, 3.0, op)


func _draw_spheres(c: MotionCanvas, f: float) -> void:
	if f < 168:
		return
	var C := _con(f)
	var order := _node_idx.duplicate()
	order.sort_custom(func(a, b): return C.pts[a].k < C.pts[b].k)
	for i in order:
		var p: Dictionary = C.pts[i]
		var n: Dictionary = _nodes[i]
		var o := _appear(f, i)
		var g := o * (1.0 - MK.prog(f, 254, 8)) * _fog(p.dz)   # the node group's opacity
		if g <= 0.0 or o <= 0.0:
			continue
		var R: float = n.r * p.k * o                             # translate, then scale(o)
		var centre: Vector2 = p.s
		var fill: Color = n.fill
		c.circle(centre, R, fill, g)
		# Wireframe rings over the fill. Their colour is pre-mixed with the fill so
		# the group's opacity composites as one layer (as the SVG <g opacity> does).
		var ea: float = 0.75 * (1.0 - C.res)
		if ea > 0.0:
			# Target (group composite): g*rc + (1-g)*bg. Drawn at alpha g over the fill
			# (itself at g), colour rc - (1-g)*fill gives g*rc + (1-g)^2*bg: exact up to
			# a small term in the (dark) background.
			var rc := fill.lerp(SCFBrand.CREAM, ea)
			var ring_col := Color(maxf(0.0, rc.r - (1.0 - g) * fill.r), maxf(0.0, rc.g - (1.0 - g) * fill.g), maxf(0.0, rc.b - (1.0 - g) * fill.b))
			var eq: float = absf(sin(C.tx + 0.25)) * R
			var mer: float = absf(cos(C.th)) * R
			c.ellipse(centre, R, eq, ring_col, 1.6 * o, g)
			c.ellipse(centre, mer, R, ring_col, 1.6 * o, g)
		c.ring(centre, R + 6.0 * o, WIRE, 2.0 * o, g * 0.6)


# ---------------------------------------------------------------- frame

func _frame(f: float) -> void:
	if not _built:
		return
	var cam := _cam_z(f)
	var flat := MK.prog(f, 112, 10)
	var slide := MK.map(f, [122, 138], [0, 1], MK.ease_in_out)
	var out := MK.interp(f, [138, 160], [0, 1], MK.ease_in_quad)
	var flash := 1.0 - (f - 160) / 4.0 if (f >= 160 and f < 164) else 0.0

	_tunnel.visible = f < 170
	_tunnel.modulate.a = MK.map(f, [0, 12], [0, 1]) * (1.0 - MK.map(f, [96, 112], [0, 0.75])) + MK.map(f, [136, 150], [0, 0.75])
	_dust.modulate.a = 0.9
	_wire_m.visible = f >= 24 and f < 120

	# MH lockup: the M alone at screen centre, then room is made for the wordmark
	_mid_fx.visible = f >= 108 and f < 164
	var s := 1.0 + out * 3.0
	_mid_fx.scale = Vector2(s, s)
	_mid_fx.position = Vector2(960, 540) * (1.0 - s)
	_mid_fx.modulate.a = 1.0 - out
	_mid_fx.blur = out * 10.0
	var mx := lerpf(CX - 60.3 * MH_K, 310, slide)
	var my := lerpf(CY - 60.3 * MH_K, 380, slide)
	var ms := lerpf(1.0, _lock_k / MH_K, slide)
	_mono.position = Vector2(mx, my)
	_mono.scale = Vector2(ms, ms)
	_mono_group.self_modulate.a = flat
	var reveal := MK.map(f, [124, 136], [0, 1])
	_word_clip.visible = f >= 124
	_word_clip.size.x = 1300.0 * reveal
	_wipe.visible = f >= 124 and f < 137
	_wipe.position = Vector2(310 + reveal * 1300.0, 370)
	_presents.text = _scramble("PRESENTS", f, 128)
	_mh_jp.modulate.a = MK.prog(f, 130, 8)

	# constellation and the flat mark it resolves into
	var con := f >= 168
	_grid.visible = con
	_edges_fx.visible = con
	_spheres.visible = con
	_flat_group.visible = f >= 250
	_flat_group.self_modulate.a = MK.prog(f, 250, 8)

	var titles := f >= 236
	_title_fx.visible = titles
	_title_jp.visible = titles
	_title_rule.visible = titles
	_title.text = _scramble("STORY CONTEXT FRAMEWORK", f, 244)
	_title_jp.modulate.a = MK.prog(f, 268, 10)
	_title_rule.scale = Vector2(MK.prog(f, 240, 16), 1)

	# HUD
	var hud_o := MK.prog(f, 4, 10)
	_hud_tl.modulate.a = hud_o
	_hud_tr.modulate.a = hud_o
	_hud_tl.text = "TRACK 01 — MINIMAL HUMANS" if f < 164 else "TRACK 02 — STORY CONTEXT FRAMEWORK"
	if f < 164:
		_hud_tr.text = "DIST %04dm" % maxi(0, int(round((M_Z - 1600.0 - cam) / 10.0)))
	else:
		_hud_tr.text = "NODES %02d · EDGES %02d" % [mini(13, int(floorf(MK.map(f, [172, 200], [0, 13])))), mini(16, int(floorf(MK.map(f, [186, 220], [0, 16]))))]
	_hud_tr.position = Vector2(1920 - 80 - _hud_tr.get_text_size().x, 70)
	_hud_bl.text = SCFBrand.JP.boot if f < 164 else SCFBrand.JP.story
	_hud_bl.position = Vector2(80, 1080 - 60 - _hud_bl.get_text_size().y)
	_flash.visible = flash > 0.0
	_flash.modulate.a = flash
