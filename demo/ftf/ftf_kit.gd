# SPDX-License-Identifier: Apache-2.0
# Full Throttle Flux graphic vocabulary: palette, type and the logo's part map.
# The loop-built marks (chevrons, checkers, hatching, X boxes, crosshairs,
# barcodes, rounded ribbons) now live in the kit as MotionMarks and MotionPath;
# the old names below forward to them. Shared by the FTF intro and the takes,
# so the family keeps one look.
# The FTF and Minimal Humans logos are Minimal Humans trademarks; they are not
# covered by the repository's Apache-2.0 grant.
class_name FTFKit
extends RefCounted

# ---- palette: the logo's pink and white, plus acid accents
const PINK := Color("#e92067")
const WHITE := Color("#ffffff")
const INK := Color("#0a0a0d")
const LIME := Color("#d7ff1f")
const LILAC := Color("#a98bff")
const CYAN := Color("#19c3e6")
const ORANGE := Color("#ff6a13")
const CREAM := Color("#f2eee6")
const STONE := Color("#bab9ad")
const GREY := Color("#2a2a31")

# ---- Minimal Humans brand colours (as in SCFBrand)
const MH_CREAM := Color("#ece5da")
const MH_AMBER := Color("#f4af3f")
const MH_RED := Color("#ef393b")
const MH_BLUE := Color("#1b6393")
const MH_INK := Color("#111111")

const BPM := 150.0
const BEAT := 12.0          # frames per beat at 150 bpm, 30 fps
const BAR := 48.0

const LOGO := "res://demo/ftf/assets/ftf_logo.svg"
const JP_FONT := "res://demo/ftf/assets/noto-jp-ftf-900.woff2"

# ---- FTF logo part map (document order, checked with MotionSvgData)
const PLATE := 0                       # white rounded plate
const RIM := 1                         # pink outline ring
const FLUX_TOP := [2, 3, 4, 5, 6]      # F, L, U (left), U (right), X: pink upper halves
const FLUX_BOWL := 7                   # U's pink inner bowl
const TAB := 8                         # pink tab under FLUX (with the checker field)
const FLUX_BOT := [9, 10, 11, 12]      # F, L, U, X: white lower halves
const WORD := [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]   # F u l l T h r o t t l e
const SMALL := [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40]  # FULLTHROTTLEFLUX
const CHECKS := [44, 43, 42, 41]       # white checker squares, left to right

static var _fonts := {}


static func font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var files := {
		wide = "res://demo/assets/fonts/unbounded-latin-900-normal.woff2",
		wide7 = "res://demo/assets/fonts/unbounded-latin-700-normal.woff2",
		ext = "res://demo/assets/fonts/michroma-latin-400-normal.woff2",
		mono = "res://demo/assets/fonts/space-mono-latin-700-normal.woff2",
		mono4 = "res://demo/assets/fonts/jetbrains-mono-latin-400-normal.woff2",
		heavy = "res://demo/assets/fonts/outfit-latin-900-normal.woff2",
		block = "res://demo/assets/fonts/archivo-black-latin-400-normal.woff2",
		tall = "res://demo/assets/fonts/big-shoulders-display-latin-900-normal.woff2",
		jp = JP_FONT,
	}
	var f := MotionFonts.font(files[key])
	if key != "jp":
		var jp := MotionFonts.font(JP_FONT)
		if not f.fallbacks.has(jp):
			f.fallbacks = [jp]
	_fonts[key] = f
	return f


static func text(parent: Node, key: String, size: float, col: Color, s: String, tracking := 0.0) -> MotionText:
	var t := MotionText.new()
	t.font = font(key)
	t.font_size = size
	t.color = col
	t.tracking = tracking
	t.text = s
	parent.add_child(t)
	return t


## A pivot node at `centre` holding `item` centred on it (item offset by -half size).
static func centred(parent: Node, item: Node2D, centre: Vector2, half: Vector2) -> Node2D:
	var p := Node2D.new()
	p.position = centre
	parent.add_child(p)
	if item.get_parent():
		item.get_parent().remove_child(item)
	p.add_child(item)
	item.position = -half
	return p


static func pill(parent: Node, s: String, bg: Color, fg: Color, size := 24.0, key := "mono") -> MotionPill:
	var p := MotionPill.new()
	p.font = font(key)
	p.font_size = size
	p.tracking = 0.08
	p.padding = Vector2(16, 5)
	p.background = bg
	p.text_color = fg
	p.text = s
	parent.add_child(p)
	return p


# ---------------------------------------------------------------- drawn marks
# The marks and path helpers moved to the kit (MotionMarks, MotionPath); these
# forward to them so older pieces keep working.

## Deprecated: use MotionMarks.chevrons.
static func chevrons(c: MotionCanvas, origin: Vector2, n: int, h: float, col: Color, phase := 0.0, dir := 1.0, on := 1.0, opacity := 1.0) -> void:
	MotionMarks.chevrons(c, origin, n, h, col, phase, dir, on, opacity)


## Deprecated: use MotionMarks.checker.
static func checker(c: MotionCanvas, pos: Vector2, cols: int, rows: int, cell: float, col: Color, on := 1.0, seed_v := 1.0, opacity := 1.0) -> void:
	MotionMarks.checker(c, pos, cols, rows, cell, col, on, seed_v, opacity)


## Deprecated: use MotionMarks.hatch.
static func hatch(c: MotionCanvas, area: PackedVector2Array, spacing: float, width: float, col: Color, angle_deg := 45.0, shift := 0.0, opacity := 1.0) -> void:
	MotionMarks.hatch(c, area, spacing, width, col, angle_deg, shift, opacity)


## Deprecated: use MotionPoly.rect.
static func rect_pts(r: Rect2) -> PackedVector2Array:
	return MotionPoly.rect(r)


## Deprecated: use MotionMarks.xbox.
static func xbox(c: MotionCanvas, centre: Vector2, size: float, col: Color, w := 2.0, opacity := 1.0, s := 1.0) -> void:
	MotionMarks.xbox(c, centre, size, col, w, opacity, s)


## Deprecated: use MotionMarks.crosshair.
static func crosshair(c: MotionCanvas, centre: Vector2, r: float, col: Color, w := 2.0, opacity := 1.0, s := 1.0) -> void:
	MotionMarks.crosshair(c, centre, r, col, w, opacity, s)


## Deprecated: use MotionMarks.plus.
static func plus(c: MotionCanvas, centre: Vector2, r: float, col: Color, w := 2.0, opacity := 1.0) -> void:
	MotionMarks.plus(c, centre, r, col, w, opacity)


## Deprecated: use MotionMarks.barcode.
static func barcode(c: MotionCanvas, r: Rect2, col: Color, seed_v := 1.0, on := 1.0, opacity := 1.0, vertical := false) -> void:
	MotionMarks.barcode(c, r, col, seed_v, on, opacity, vertical)


## Deprecated: use MotionPath.rounded(pts, r, seg, false).
static func rounded_path(pts: PackedVector2Array, r: float, seg := 8) -> PackedVector2Array:
	return MotionPath.rounded(pts, r, seg, false)


## Deprecated: use MotionPath.polyline_length.
static func path_length(pts: PackedVector2Array) -> float:
	return MotionPath.polyline_length(pts)


## Deprecated: use MotionPath.slice_fraction.
static func sub_path(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	return MotionPath.slice_fraction(pts, a, b)


## Deprecated: use MotionMarks.ribbon.
static func ribbon(c: MotionCanvas, pts: PackedVector2Array, width: float, col: Color, a := 0.0, b := 1.0, round_ends := true, opacity := 1.0) -> void:
	MotionMarks.ribbon(c, pts, width, col, a, b, round_ends, opacity)


## Deprecated: use MotionMarks.stripe_bundle.
static func stripe_bundle(c: MotionCanvas, pts: PackedVector2Array, widths: Array, cols: Array, gap: float, a := 0.0, b := 1.0, opacity := 1.0) -> void:
	MotionMarks.stripe_bundle(c, pts, widths, cols, gap, a, b, opacity)


## Deprecated: use MotionPath.offset.
static func offset_path(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	return MotionPath.offset(pts, d)
