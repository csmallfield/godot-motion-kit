# SPDX-License-Identifier: Apache-2.0
# F1 — STROBE, ported from scf-intros src/intros/F1_Strobe.tsx.
# Supergraphic pushed to a rave flyer: giant type marquees in three rows, the
# whole palette cutting on every beat (120 bpm, 15 frames a beat), the M
# slamming through it. Then the rows tilt into STORY / CONTEXT / FRAMEWORK
# bands, the three discs stamp onto them, and everything strips away to the
# clean lockup on cream. Holds, unbuilds, three strobe frames, black.
@tool
extends MotionComposition

const BEAT := 15
const SCF_T0 := 204
const OUT := 352
const INK := SCFBrand.INK
const CREAM := SCFBrand.CREAM

var _built := false
var _bg: ColorRect
var _line: ColorRect
var _strobe: Node2D          # translated by the slams
var _squash: Node2D          # scaleY about the centre
var _rows: Array = []
var _m_pivot: Node2D
var _m_fx: MotionFX
var _m: MotionSvg
var _micro: Dictionary = {}
var _lock: Node2D
var _rule: ColorRect
var _lock_pivot: Node2D
var _presents: MotionText
var _flash: ColorRect
var _bands: Node2D
var _band: Array = []
var _scf_layer: Node2D
var _ticker: Control
var _ticker_text: MotionText
var _scf: SCFLockup
var _end: ColorRect


func _init() -> void:
	duration = 420
	fps = 30


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


static func _pal() -> Array:
	var B := SCFBrand
	return [[INK, CREAM], [B.AMBER, INK], [B.BLUE, CREAM], [B.RED, CREAM], [CREAM, INK], [INK, B.AMBER], [B.BLUE, B.AMBER], [B.AMBER, B.RED]]


static func _rect(parent: Node, r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func _mono_font() -> Font:
	return PrintKit.mono_font(700)


static var _outfit_fb: Font

## Outfit 900 with the browser's fallback for ●: fontconfig hands Chromium
## Carlito (Bold, for weight 900), whose dot is much smaller than Inter's.
static func _outfit() -> Font:
	if not _outfit_fb:
		var f := MotionFonts.font("res://demo/assets/fonts/outfit-latin-900-normal.woff2")
		f.fallbacks = [MotionFonts.font("res://demo/assets/fonts/carlito-bold-symbols.ttf")]
		_outfit_fb = f
	return _outfit_fb


# ------------------------------------------------------------------ marquee rows

## A strip of repeated giant words (Row): an overflow-hidden band 2720 px wide
## (left/right -400) holding ten spans, each followed by a 0.35em margin.
class Row:
	extends ColorRect
	var size_px := 430.0
	var words: Node2D
	var _texts: Array[MotionText] = []
	var _tw := 0.0
	var _skew := 0.0

	func _init(text: String, y: float, h: float, px: float, bg := Color(0, 0, 0, 0), skew_deg := 0.0) -> void:
		size_px = px
		position = Vector2(-400, y)
		size = Vector2(2720, h)
		color = bg if bg.a > 0.0 else Color(1, 1, 1, 1)
		# overflow: hidden. The mask follows rotation and scale (clip_contents would not).
		clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW if bg.a > 0.0 else CanvasItem.CLIP_CHILDREN_ONLY
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		words = Node2D.new()
		add_child(words)
		var x := 0.0
		for i in 10:
			var t := MotionText.new()
			t.font = SCFBrand.font("outfit", 900)
			t.font_size = px
			t.line_height = 1.0
			t.tracking = -0.04
			t.text = text
			t.position = Vector2(x, 0)
			words.add_child(t)
			_texts.append(t)
			x += t.get_text_size().x + px * 0.35
		_tw = x
		_skew = tan(deg_to_rad(skew_deg))

	func set_fg(c: Color) -> void:
		for t in _texts:
			t.color = c

	## Place the text div at `x` (row coordinates) with CSS skewX about its centre.
	func set_x(x: float) -> void:
		var top := (size.y - size_px * 0.86) / 2.0 - size_px * 0.1
		var c := Vector2(_tw * 0.5, size_px * 0.5)
		words.transform = Transform2D(0.0, Vector2(x, top) + c) * Transform2D(Vector2(1, 0), Vector2(_skew, 1), Vector2.ZERO) * Transform2D(0.0, -c)


# ------------------------------------------------------------------ build

func _build() -> void:
	_built = true
	_bg = _rect(self, Rect2(0, 0, 1920, 1080), INK)
	_line = _rect(self, Rect2(0, 538, 1920, 4), CREAM)
	_line.pivot_offset = Vector2(960, 2)

	_strobe = Node2D.new()
	add_child(_strobe)
	_squash = Node2D.new()
	_strobe.add_child(_squash)
	for spec in [["MINIMAL", -20.0, 0.0], ["HUMANS", 350.0, -8.0], ["MINIMAL", 720.0, 0.0]]:
		var r := Row.new(spec[0], spec[1], 380, 430, Color(0, 0, 0, 0), spec[2])
		_squash.add_child(r)
		_rows.append(r)

	# The M: a drop-shadowed group, scaled and turned about its div's centre
	_m_pivot = Node2D.new()
	_strobe.add_child(_m_pivot)
	_m_fx = MotionFX.new()
	_m_fx.size = Vector2(840, 840)    # room for the spread layers and the shadow (CSS doesn't clip)
	_m_fx.shadow_color = INK
	_m_pivot.add_child(_m_fx)
	_m = MotionSvg.new()
	_m.data = SCFBrand.logo("mhM")
	_m.width = 660
	_m.position = Vector2(60, 60)
	_m_fx.content.add_child(_m)
	var div := Vector2(660, _m.get_size().y + PrintKit.STRUT_GAP)
	_m_pivot.position = Vector2(960 - 330, 540 - 330) + div * 0.5
	_m_fx.position = -div * 0.5 - Vector2(60, 60)

	# micro type
	var mt := MotionText.new()
	mt.font = _mono_font(); mt.font_size = 22; mt.tracking = 0.12
	mt.position = Vector2(48, 40)
	_strobe.add_child(mt)
	_micro.counter = mt
	var jp := MotionText.new()
	jp.font = SCFBrand.font("jp", 900); jp.font_size = 26; jp.text = SCFBrand.JP.mh
	jp.align = HORIZONTAL_ALIGNMENT_RIGHT
	jp.position = Vector2(1920 - 48, 36)
	_strobe.add_child(jp)
	_micro.jp = jp
	var bars := MotionCanvas.new()
	_strobe.add_child(bars)
	_micro.bars = bars
	bars.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		var x := 48.0
		for i in 34:
			var w := 6.0 if MK.rand(i * 3.1) > 0.6 else 2.0
			c.rect(Rect2(x, 1080 - 40 - 34, w, 34), _micro.fg)
			x += w + 4
	var bpm := MotionText.new()
	bpm.font = _mono_font(); bpm.font_size = 22; bpm.tracking = 0.12; bpm.text = "120 BPM — ▲▲▲"
	bpm.align = HORIZONTAL_ALIGNMENT_RIGHT
	bpm.position = Vector2(1920 - 48, 1080 - 40 - bpm.get_text_size().y)
	_strobe.add_child(bpm)
	_micro.bpm = bpm
	_micro.fg = CREAM

	# the MH lockup the rows squash into
	_lock = Node2D.new()          # no background of its own: the rows run on under it until 112
	add_child(_lock)
	_rule = _rect(_lock, Rect2(0, 620, 1920, 14), INK)
	_rule.pivot_offset = Vector2(960, 7)
	var full := MotionSvg.new()
	full.data = SCFBrand.logo("mhFull")
	full.width = 1360
	full.apply(func(i: int): return null if (SCFBrand.MH_FULL_M as Array).has(i) else {fill = INK})
	var origin := Vector2(680, (full.get_size().y + PrintKit.STRUT_GAP) * 0.6)   # transform-origin 50% 60%
	_lock_pivot = Node2D.new()
	_lock_pivot.position = Vector2(960 - 680, 300) + origin
	_lock.add_child(_lock_pivot)
	full.position = -origin
	_lock_pivot.add_child(full)
	_presents = MotionText.new()
	_presents.font = SCFBrand.font("outfit", 900); _presents.font_size = 64
	_presents.color = SCFBrand.RED; _presents.text = "PRESENTS"
	_presents.align = HORIZONTAL_ALIGNMENT_CENTER; _presents.box_width = 1920
	_presents.position = Vector2(0, 660)
	_lock.add_child(_presents)

	_flash = _rect(self, Rect2(0, 0, 1920, 1080), INK)

	# STORY / CONTEXT / FRAMEWORK bands, tilted and enlarged about the centre
	_bands = Node2D.new()
	_bands.transform = Transform2D(0.0, Vector2(960, 540)) * Transform2D(deg_to_rad(-11.0), Vector2.ZERO) \
		* Transform2D(Vector2(1.25, 0), Vector2(0, 1.25), Vector2.ZERO) * Transform2D(0.0, Vector2(-960, -540))
	add_child(_bands)
	var band_cols := [SCFBrand.RED, SCFBrand.BLUE, SCFBrand.AMBER]
	var disc_cols := [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]
	var words := ["STORY", "CONTEXT", "FRAMEWORK"]
	for k in 3:
		var b := Node2D.new()
		_bands.add_child(b)
		var row := Row.new(words[k], 0, 300, 300, band_cols[k])
		row.set_fg(INK if k == 2 else CREAM)
		b.add_child(row)
		# the disc that stamps onto the band: 420 px, a 14 px ink border inside it
		var disc := Node2D.new()
		disc.position = Vector2(1200 - k * 260 + 210, -60 + 210)
		disc.rotation_degrees = 11.0
		b.add_child(disc)
		var d := MotionShape.circle(420, disc_cols[k])
		d.border_width = 14
		d.border_color = INK
		disc.add_child(d)
		var letter := MotionText.new()
		letter.font = SCFBrand.font("outfit", 900)
		letter.font_size = 300
		letter.line_height = 1.0
		letter.color = CREAM
		letter.stroke_width = 10
		letter.stroke_color = INK
		letter.text = "SCF"[k]
		# flex-centred in the 392 px content box with margin-top -30
		letter.position = Vector2(-210 + 14 + (392 - letter.get_text_size().x) * 0.5, -210 + 14 + (392 - 270) * 0.5 - 30)
		disc.add_child(letter)
		_band.append({node = b, row = row, disc = disc})

	# the SCF lockup with a ticker along the bottom
	_scf_layer = Node2D.new()
	add_child(_scf_layer)
	_ticker = Control.new()
	_ticker.clip_contents = true
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker.position = Vector2(0, 1080 - 64)
	_ticker.size = Vector2(1920, 64)
	_scf_layer.add_child(_ticker)
	_rect(_ticker, Rect2(0, 0, 1920, 64), INK)
	_ticker_text = MotionText.new()
	_ticker_text.font = _outfit()
	_ticker_text.font_size = 34
	_ticker_text.tracking = 0.12
	_ticker_text.color = CREAM
	var s := ""
	var dots := {}
	for i in 8:
		for j in 3:
			s += ["STORY CONTEXT FRAMEWORK ", "OPEN FORMAT ", "MINIMAL HUMANS "][j]
			dots[s.length()] = [[SCFBrand.RED, SCFBrand.AMBER, SCFBrand.BLUE], [SCFBrand.AMBER, SCFBrand.BLUE, SCFBrand.RED], [SCFBrand.BLUE, SCFBrand.RED, SCFBrand.AMBER]][j][i % 3]
			s += "● "
	_ticker_text.text = s.strip_edges(false, true)
	_ticker_text.apply(func(i: int): return {color = dots[i]} if dots.has(i) else null)
	_ticker_text.position = Vector2(0, 12)
	_ticker.add_child(_ticker_text)
	_scf = SCFLockup.new()
	_scf.t0 = SCF_T0
	_scf.out_at = OUT
	_scf.y = 300
	_scf.letter_col = INK
	_scf.presents_col = INK
	_scf.rule_col = SCFBrand.RED
	_scf.tags = PackedStringArray(SCFLockup.TAGS_FEATURE)
	_scf_layer.add_child(_scf)

	_end = _rect(self, Rect2(0, 0, 1920, 1080), INK)


# ------------------------------------------------------------------ frame

func _frame(f: float) -> void:
	if not _built:
		return
	var fi := int(floorf(f))
	var beat := fi / BEAT
	var sub := fi % BEAT
	var pal: Array = _pal()[beat % 8]
	var off := sub < 2 and f >= 30 and f < 112 and beat % 2 == 1
	var bg: Color = pal[1] if off else pal[0]
	var fg: Color = pal[0] if off else pal[1]
	var lock := f >= 104

	_bg.color = CREAM if (lock or f >= 150) else bg
	_line.visible = f < 8
	_line.scale.x = MK.map(f, [0, 7], [0, 1])

	# beat 1
	var strobe1 := f >= 8 and f < 112
	_strobe.visible = strobe1
	if strobe1:
		_strobe.position = MK.shakes(f, [56, 60, 101], 26, 9)
		var squash := MK.map(f, [96, 112], [1, 0.035], MK.ease_in_back)
		_squash.transform = Transform2D(Vector2(1, 0), Vector2(0, squash), Vector2(0, 540 - 540 * squash))
		var xs := MK.step(f, 2)
		var xs_rows := [-xs * 24 - 200, xs * 30 - 2600, -xs * 18 - 900]
		for i in 3:
			_rows[i].set_fg(fg)
			_rows[i].set_x(xs_rows[i])
		var mono := SCFBrand.sp(f, 56, 9, 170)
		_m_pivot.visible = f >= 56 and f < 104
		_m_pivot.scale = Vector2.ONE * ((1 - mono) * 2.4 + 1)
		_m_pivot.rotation_degrees = (1 - mono) * -18
		_m_fx.shadow_offset = Vector2.ZERO if off else Vector2(18, 18)
		var spread := maxf(0.0, 1.0 - MK.map(f, [56, 80], [0, 1]))
		_m.apply(func(i: int): return {tx = (2 - i) * spread * 22.0, ty = (2 - i) * spread * 22.0})
		_micro.fg = fg
		_micro.counter.color = fg
		_micro.counter.text = "MH/001 · %03d" % (beat + 1)
		_micro.jp.color = fg
		_micro.bpm.color = fg
		_micro.bars.queue_redraw()

	_lock.visible = lock and f < 150
	if _lock.visible:
		_rule.scale.x = MK.map(f, [104, 116], [1, 0.62])
		_lock_pivot.scale = Vector2.ONE * SCFBrand.sp(f, 104, 11, 150)
		_presents.tracking = MK.map(f, [112, 130], [1.4, 0.5])
		_presents.modulate.a = MK.map(f, [112, 120], [0, 1])

	_flash.visible = f >= 138 and f < 152
	_flash.color = INK if fi % 2 == 0 else CREAM

	# beat 2: bands
	_bands.visible = f >= 150 and f < SCF_T0 + 6
	if _bands.visible:
		var stamp := [164, 174, 184]
		for k in 3:
			var b: Dictionary = _band[k]
			var band_in := MK.map(f, [150 + k * 4, 162 + k * 4], [0, 1])
			var band_out := MK.map(f, [SCF_T0 - 10 + k * 3, SCF_T0 + 2 + k * 3], [0, 1], MK.ease_in_back)
			var tx := (1 - band_in) * (2400.0 if k % 2 else -2400.0)
			var sy := 1.0 - band_out
			var top := 70.0 + k * 330
			# translateX then scaleY about the band's centre (960, top + 150)
			b.node.transform = Transform2D(Vector2(1, 0), Vector2(0, sy), Vector2(tx, top + 150 - 150 * sy))
			b.row.set_x((1.0 if k % 2 else -1.0) * MK.step(f, 2) * 14 - 300 - k * 500)
			b.disc.visible = f >= stamp[k] - 2
			b.disc.scale = Vector2.ONE * maxf(0.0, SCFBrand.sp(f, stamp[k] - 2, 9, 220))

	_scf_layer.visible = f >= SCF_T0 - 4
	if _scf_layer.visible:
		_ticker.position.y = 1080 - 64 + (1 - MK.map(f, [SCF_T0 + 60, SCF_T0 + 72], [0, 1])) * 64 + MK.map(f, [OUT + 2, OUT + 12], [0, 64])
		_ticker_text.position.x = -MK.step(f, 2) * 6

	_end.visible = f >= OUT + 46
	if _end.visible:
		_end.color = [SCFBrand.RED, CREAM, SCFBrand.BLUE, INK, SCFBrand.AMBER, INK][fi - OUT - 46] if fi < OUT + 52 else INK
