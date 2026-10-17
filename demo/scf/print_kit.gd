# SPDX-License-Identifier: Apache-2.0
# The B ("Print") intros' shared pieces, ported from scf-intros src/lib/print.tsx:
# registration marks, micro and big type, the colour strip, barcodes, the
# pictogram set and the scrolling ticker band.
class_name PrintKit
extends RefCounted

const PAPER := Color("#ece5da")
const INK := Color("#0d0d0d")

## An inline <svg> inside a <div> sits on the text baseline, so the div is
## taller than the svg by the strut below the baseline: the default font's
## descent plus half its line gap (Times New Roman, Liberation Serif on Linux,
## 16 px: 3 + 1 px). It shifts anything centred on that div.
const STRUT_GAP := 4.0

static var _fonts := {}
static var _icons := {}


# ------------------------------------------------------------------ type

## Space Mono 700, uppercase, line-height 1.3, letter-spacing 0.06em (Micro).
## For `right:`-anchored text set align RIGHT and place the node at the right edge.
static func micro(text: String, size := 16.0, c := INK) -> MotionText:
	var t := MotionText.new()
	t.font = mono_font(700)
	t.font_size = size
	t.color = c
	t.line_height = 1.3
	t.tracking = 0.06
	t.uppercase = true
	t.text = text
	return t


## Archivo Black, line-height 0.82, letter-spacing -0.04em (Big).
static func big(text: String, size: float, c: Color) -> MotionText:
	var t := MotionText.new()
	t.font = archivo()
	t.font_size = size
	t.color = c
	t.line_height = 0.82
	t.tracking = -0.04
	t.text = text
	return t


## Space Mono with the browser's monospace fallback for symbols it lacks (■).
static func mono_font(weight := 700) -> Font:
	var key := "mono%d" % weight
	if not _fonts.has(key):
		var f := MotionFonts.font("res://demo/assets/fonts/space-mono-latin-%d-normal.woff2" % weight)
		# Chromium's synthetic bold for a face without a bold: the outline grows
		# by size / 32 px; Godot's embolden grows it by embolden * size / 16.
		var wqy := FontVariation.new()
		wqy.base_font = MotionFonts.font("res://demo/assets/fonts/wqy-zenhei-mono-subset.ttf")
		wqy.variation_embolden = 0.5 if weight >= 600 else 0.0
		f.fallbacks = [MotionFonts.font("res://demo/assets/fonts/dejavu-sans-mono-bold-symbols.ttf"), wqy]
		_fonts[key] = f
	return _fonts[key]


## Archivo Black with the browser's sans-serif fallback for ✱ (DejaVu Sans).
static func archivo() -> Font:
	if not _fonts.has("archivo"):
		var f := MotionFonts.font("res://demo/assets/fonts/archivo-black-latin-400-normal.woff2")
		f.fallbacks = [MotionFonts.font("res://demo/assets/fonts/dejavu-sans-symbols.ttf")]
		_fonts["archivo"] = f
	return _fonts["archivo"]


# ------------------------------------------------------------------ layout helpers

static func rect(parent: Node, r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func add(parent: Node, n: Node2D) -> Node2D:
	parent.add_child(n)
	return n


static func logo(parent: Node, key: String, width: float, pos: Vector2) -> MotionSvg:
	var s := MotionSvg.new()
	s.data = SCFBrand.logo(key)
	s.width = width
	s.position = pos
	parent.add_child(s)
	return s


static func vjp(parent: Node, text: String, size: float, col: Color, track: float, right: float, top: float) -> MotionText:
	var t := MotionText.new()
	t.font = SCFBrand.font("jp", 900)
	t.font_size = size
	t.color = col
	t.tracking = track
	t.vertical = true
	t.box_width = 1080.0 - top          # an abs-positioned box with only `top` set
	t.text = text
	t.position = Vector2(1920.0 - right - t.get_text_size().x, top)
	parent.add_child(t)
	return t


## `right:`-anchored micro type: right-aligned lines ending at the edge.
static func micro_right(parent: Node, text: String, right: float, y: float, c := INK, size := 16.0) -> MotionText:
	var t := micro(text, size, c)
	t.align = HORIZONTAL_ALIGNMENT_RIGHT
	t.position = Vector2(1920.0 - right, y)
	parent.add_child(t)
	return t


static func micro_at(parent: Node, text: String, x: float, y: float, c := INK, size := 16.0) -> MotionText:
	var t := micro(text, size, c)
	t.position = Vector2(x, y)
	parent.add_child(t)
	return t


static func regs(parent: Node) -> Node2D:
	var g := Node2D.new()
	for p in [Vector2(50, 50), Vector2(1870, 50), Vector2(50, 1030), Vector2(1870, 1030)]:
		g.add_child(reg(p.x, p.y))
	parent.add_child(g)
	return g


## The scfMark disc i of a mark drawn at (x, y), w wide: centre and radius.
static func scf_disc(i: int, x: float, y: float, w: float) -> Dictionary:
	var d := SCFBrand.logo("scfMark")
	var k := w / d.view_box.size.x
	var bb: Rect2 = d.parts[i].bbox
	return {c = Vector2(x, y) + bb.get_center() * k, r = bb.size.x * 0.5 * k}


# ------------------------------------------------------------------ marks

## Registration mark centred on its position: a 14 px ring and a 60 px cross,
## 2 px strokes, scaled by `s`. Rotate the returned node for the spinning ones.
static func reg(x: float, y: float, c := INK, s := 1.0) -> MotionCanvas:
	var m := MotionCanvas.new()
	m.position = Vector2(x, y)
	m.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		cv.ring(Vector2.ZERO, 14.0 * s, c, 2.0 * s)
		cv.line(Vector2(-30, 0) * s, Vector2(30, 0) * s, c, 2.0 * s)
		cv.line(Vector2(0, -30) * s, Vector2(0, 30) * s, c, 2.0 * s)
	m.queue_redraw()
	return m


## Five 34 px swatches with 2 px ink borders, side by side. Remotion's CSS makes
## every box border-box, so the border is inside the 34 px.
static func strip(x: float, y: float, s := 34.0) -> MotionCanvas:
	var m := MotionCanvas.new()
	m.position = Vector2(x, y)
	m.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		var cols := [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED, INK, PAPER]
		for i in cols.size():
			var r := Rect2(i * s, 0, s, s)
			cv.rect(r, cols[i])
			cv.rect(r, INK, 1.0, 2.0)
	m.queue_redraw()
	return m


## Barcode of w × h px: bars of 2, 4, 6 or 8 px from MK.rand(seed + i), every
## other one inked, clipped to w (the <svg> clips). Change the seed with set_meta("seed", n).
static func barcode(x: float, y: float, w: float, h: float, seed: float, c := INK) -> MotionCanvas:
	var m := MotionCanvas.new()
	m.position = Vector2(x, y)
	m.set_meta("seed", seed)
	m.draw_fn = func(cv: MotionCanvas, _f: float) -> void:
		var sd: float = cv.get_meta("seed")
		var px := 0.0
		var i := 0
		while px < w:
			var bw := 2.0 + floorf(MK.rand(sd + i) * 4.0) * 2.0
			if i % 2 == 0:
				cv.rect(Rect2(px, 0, minf(bw, w - px), h), c)
			px += bw
			i += 1
	m.queue_redraw()
	return m


# ------------------------------------------------------------------ icons
# Bold flat pictograms on a 24-unit grid; `bg` parts punch the holes.

const ICON_NAMES := ["skull", "heart", "arrow", "database", "star", "eye", "bolt", "plus", "smile", "film", "nodes", "doc", "check", "target"]
const _C := "#ff0000"
const _BG := "#00ff00"


static func _star8() -> String:
	var pts := PackedStringArray()
	for i in 16:
		var a := float(i) / 16.0 * TAU - PI / 2.0
		var r := 4.2 if i % 2 else 11.0
		pts.append("%.2f,%.2f" % [12.0 + cos(a) * r, 12.0 + sin(a) * r])
	return " ".join(pts)


static func _icon_body(name: String) -> String:
	var c := _C
	var bg := _BG
	match name:
		"skull":
			var s := '<path d="M12 1.5C6.2 1.5 2.5 5.6 2.5 10.6c0 3 1.4 5.1 3.3 6.4V20.5a1 1 0 0 0 1 1h10.4a1 1 0 0 0 1-1V17c1.9-1.3 3.3-3.4 3.3-6.4 0-5-3.7-9.1-9.5-9.1z" fill="%s"/>' % c
			s += '<circle cx="8.3" cy="11" r="2.6" fill="%s"/><circle cx="15.7" cy="11" r="2.6" fill="%s"/>' % [bg, bg]
			s += '<polygon points="12,13.6 10.6,16.4 13.4,16.4" fill="%s"/>' % bg
			for x in [9.3, 11.5, 13.7]:
				s += '<rect x="%s" y="18.4" width="1" height="3.2" fill="%s"/>' % [x, bg]
			return s
		"heart":
			return '<path d="M12 21.5s-8-4.9-10-9.8C.5 7.9 2.8 3.8 6.8 3.8c2.2 0 4 1.2 5.2 3.1 1.2-1.9 3-3.1 5.2-3.1 4 0 6.3 4.1 4.8 7.9-2 4.9-10 9.8-10 9.8z" fill="%s"/>' % c
		"arrow":
			return '<polygon points="1.5,8.5 12.5,8.5 12.5,3 22.5,12 12.5,21 12.5,15.5 1.5,15.5" fill="%s"/>' % c
		"arrowDown":
			return '<polygon points="8.5,1.5 15.5,1.5 15.5,12.5 21,12.5 12,22.5 3,12.5 8.5,12.5" fill="%s"/>' % c
		"database":
			var s := '<path d="M3.5 5v14c0 1.9 3.8 3.4 8.5 3.4s8.5-1.5 8.5-3.4V5" fill="%s"/>' % c
			s += '<ellipse cx="12" cy="5" rx="8.5" ry="3.3" fill="%s"/>' % c
			s += '<ellipse cx="12" cy="5" rx="5.6" ry="1.6" fill="%s"/>' % bg
			s += '<path d="M3.5 10.2c0 1.9 3.8 3.4 8.5 3.4s8.5-1.5 8.5-3.4M3.5 15.2c0 1.9 3.8 3.4 8.5 3.4s8.5-1.5 8.5-3.4" fill="none" stroke="%s" stroke-width="1.4"/>' % bg
			return s
		"star":
			return '<polygon points="%s" fill="%s"/>' % [_star8(), c]
		"eye":
			var s := '<path d="M1 12s4-7.5 11-7.5S23 12 23 12s-4 7.5-11 7.5S1 12 1 12z" fill="%s"/>' % c
			return s + '<circle cx="12" cy="12" r="4.4" fill="%s"/><circle cx="12" cy="12" r="2.2" fill="%s"/>' % [bg, c]
		"bolt":
			return '<polygon points="14,1 4,13.5 11,13.5 9,23 20,9.5 13,9.5" fill="%s"/>' % c
		"plus":
			return '<path d="M9 2h6v7h7v6h-7v7H9v-7H2V9h7z" fill="%s"/>' % c
		"smile":
			var s := '<circle cx="12" cy="12" r="10.5" fill="%s"/>' % c
			s += '<circle cx="8.4" cy="9.4" r="1.6" fill="%s"/><circle cx="15.6" cy="9.4" r="1.6" fill="%s"/>' % [bg, bg]
			return s + '<path d="M6.8 13.5c1.2 2.6 3.1 3.9 5.2 3.9s4-1.3 5.2-3.9" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % bg
		"film":
			var s := '<rect x="2" y="3" width="20" height="18" rx="1.5" fill="%s"/>' % c
			for y in [5.5, 10.2, 14.9]:
				s += '<rect x="3.4" y="%s" width="2.2" height="2.6" fill="%s"/><rect x="18.4" y="%s" width="2.2" height="2.6" fill="%s"/>' % [y, bg, y, bg]
			return s + '<rect x="7.6" y="5.5" width="8.8" height="13" fill="%s"/>' % bg
		"nodes":
			var s := '<path d="M6 7 L12 15 L18 7" fill="none" stroke="%s" stroke-width="2.2"/>' % c
			return s + '<circle cx="6" cy="7" r="4.4" fill="%s"/><circle cx="18" cy="7" r="4.4" fill="%s"/><circle cx="12" cy="16.5" r="5.2" fill="%s"/>' % [c, c, c]
		"doc":
			var s := '<path d="M4 1.5h11l5 5V22.5H4z" fill="%s"/>' % c
			s += '<path d="M15 1.5v5h5" fill="%s"/>' % bg
			for y in [10, 13.5, 17]:
				s += '<rect x="7" y="%s" width="10" height="1.6" fill="%s"/>' % [y, bg]
			return s
		"check":
			return '<polygon points="2,12.5 5.5,9 9.5,13 18.5,4 22,7.5 9.5,20" fill="%s"/>' % c
		"cross":
			return '<polygon points="5,2 12,9 19,2 22,5 15,12 22,19 19,22 12,15 5,22 2,19 9,12 2,5" fill="%s"/>' % c
		"target":
			return '<circle cx="12" cy="12" r="10.5" fill="%s"/><circle cx="12" cy="12" r="7" fill="%s"/><circle cx="12" cy="12" r="3.5" fill="%s"/>' % [c, bg, c]
	push_warning("PrintKit: unknown icon %s" % name)
	return ""


static func icon_data(name: String) -> MotionSvgData:
	if not _icons.has(name):
		_icons[name] = MotionSvgData.from_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">%s</svg>' % _icon_body(name))
	return _icons[name]


## A pictogram `size` px square (top-left at the node origin).
static func icon(name: String, size: float, c := INK, bg := PAPER) -> MotionSvg:
	var s := MotionSvg.new()
	s.width = size
	set_icon(s, name, c, bg)
	return s


## Swap an icon node's pictogram and colours.
static func set_icon(s: MotionSvg, name: String, c := INK, bg := PAPER) -> void:
	var d := icon_data(name)
	if s.data != d:
		s.data = d
	var red := Color(_C)
	s.apply(func(i: int) -> Dictionary:
		var p: Dictionary = d.parts[i]
		var col: Color = p.fill if (p.fill as Color).a > 0.0 else p.stroke
		return {fill = c if Color(col.r, col.g, col.b).is_equal_approx(red) else bg})


# ------------------------------------------------------------------ ticker

## A 54 px band across the frame with text scrolling in it (Ticker).
## Call update(f) from _frame.
class Ticker:
	extends Control
	var speed := 14.0
	var _text: MotionText

	func _init(y: float, words: String, bg: Color, fg: Color, spd := 14.0) -> void:
		speed = spd
		position = Vector2(0, y)
		size = Vector2(1920, 54)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var band := ColorRect.new()
		band.color = bg
		band.size = size
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(band)
		_text = MotionText.new()
		_text.font = PrintKit.archivo()
		_text.font_size = 40
		_text.line_height = 54.0 / 40.0
		_text.color = fg
		# white-space: nowrap collapses the runs of spaces around the ✱
		_text.text = (words + " ✱ ").repeat(12)
		add_child(_text)

	func update(f: float) -> void:
		_text.position.x = -fmod(f * speed, 900.0)   # JS % keeps the dividend's sign
