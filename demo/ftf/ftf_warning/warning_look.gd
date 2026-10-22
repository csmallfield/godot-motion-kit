# SPDX-License-Identifier: Apache-2.0
# FTF Warning take: palette and fonts. Preloaded by the piece (no class_name,
# so it can't collide with other takes).
extends RefCounted

const YELLOW := Color("#ffd400")
const BLACK := Color("#0b0b0c")
const INK := Color("#111113")
const WHITE := Color("#f4f2ec")
const PINK := Color("#e92067")
const ORANGE := Color("#ff7a12")
const AMBER := Color("#ffa31a")
const STONE := Color("#9a9890")
const DARK := Color("#17171a")

const FONT_WARN := "res://demo/ftf/ftf_warning/assets/rubik-mono-one-ftfw.woff2"     # Latin + Cyrillic
const FONT_LABEL := "res://demo/ftf/ftf_warning/assets/russo-one-ftfw.woff2"         # Latin + Cyrillic
const FONT_STENCIL := "res://demo/ftf/ftf_warning/assets/big-shoulders-stencil-display-latin-900-normal.woff2"
const FONT_JP := "res://demo/ftf/ftf_warning/assets/noto-jp-warning-900.woff2"
const FONT_SYMBOLS := "res://demo/assets/fonts/dejavu-sans-mono-bold-symbols.ttf"   # ▲
const FONT_MONO := "res://demo/assets/fonts/space-mono-latin-700-normal.woff2"

static var _fonts := {}


## A font with the take's fallbacks (Japanese, then symbols), cached.
static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f := MotionFonts.font(path)
	if path != FONT_JP:
		var fb: Array[Font] = [MotionFonts.font(FONT_JP), MotionFonts.font(FONT_SYMBOLS)]
		for x in fb:
			if not f.fallbacks.has(x):
				f.fallbacks = f.fallbacks + [x]
	_fonts[path] = f
	return f


static func text(parent: Node, path: String, size: float, col: Color, s: String, tracking := 0.0) -> MotionText:
	var t := MotionText.new()
	t.font = font(path)
	t.font_size = size
	t.color = col
	t.tracking = tracking
	t.text = s
	parent.add_child(t)
	return t
