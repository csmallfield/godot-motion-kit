# SPDX-License-Identifier: Apache-2.0
# Full Throttle Flux graphic vocabulary: palette, type, the logo's part map and
# a set of loop-built marks (chevrons, checkers, hatching, X boxes, crosshairs,
# barcodes, rounded ribbons) drawn into a MotionCanvas. Shared by the FTF intro
# and, later, the menus, so the family keeps one look.
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
# All take a MotionCanvas and draw immediately; call them from a draw_fn.

## A row of chevrons ( >>>> ) of height h starting at `origin`, pointing along +x
## (dir = -1 points left). `phase` 0..1 marches them one slot; `on` 0..1 grows the row.
static func chevrons(c: MotionCanvas, origin: Vector2, n: int, h: float, col: Color, phase := 0.0, dir := 1.0, on := 1.0, opacity := 1.0) -> void:
	var w := h * 0.5
	var gap := h * 0.62
	var th := h * 0.24
	var shown := ceili(n * clampf(on, 0.0, 1.0))
	for i in shown:
		var x := origin.x + dir * (fposmod(float(i) + phase, float(n)) * gap)
		var p := PackedVector2Array([
			Vector2(x, origin.y - h * 0.5), Vector2(x + dir * th, origin.y - h * 0.5),
			Vector2(x + dir * (th + w), origin.y), Vector2(x + dir * th, origin.y + h * 0.5),
			Vector2(x, origin.y + h * 0.5), Vector2(x + dir * w, origin.y)])
		c.polygon(p, col, Color(0, 0, 0, 0), 0.0, opacity)


## A checker field: `cols` x `rows` cells of side `cell`, colour `col` on alternate cells.
## `on` 0..1 reveals cells in a seeded order.
static func checker(c: MotionCanvas, pos: Vector2, cols: int, rows: int, cell: float, col: Color, on := 1.0, seed_v := 1.0, opacity := 1.0) -> void:
	var k := 0
	for y in rows:
		for x in cols:
			if (x + y) % 2 == 0:
				if MK.rand(k * 3.3 + seed_v) < on:
					c.rect(Rect2(pos + Vector2(x, y) * cell, Vector2(cell, cell)), col, opacity)
				k += 1


## Diagonal hatching clipped to a convex or concave polygon `area`.
static func hatch(c: MotionCanvas, area: PackedVector2Array, spacing: float, width: float, col: Color, angle_deg := 45.0, shift := 0.0, opacity := 1.0) -> void:
	var bb := Rect2(area[0], Vector2.ZERO)
	for p in area:
		bb = bb.expand(p)
	var a := deg_to_rad(angle_deg)
	var d := Vector2(cos(a), sin(a))      # stripe direction
	var nrm := Vector2(-d.y, d.x)         # across stripes
	var centre := bb.get_center()
	var reach := bb.size.length()
	var n := ceili(reach / spacing) + 2
	for i in range(-n, n + 1):
		var o := centre + nrm * (i * spacing + fposmod(shift, spacing))
		var stripe := PackedVector2Array([
			o - d * reach - nrm * width * 0.5, o + d * reach - nrm * width * 0.5,
			o + d * reach + nrm * width * 0.5, o - d * reach + nrm * width * 0.5])
		for poly in Geometry2D.intersect_polygons(stripe, area):
			c.polygon(poly, col, Color(0, 0, 0, 0), 0.0, opacity)


static func rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A box with an X through it (the Marathon / Framework placeholder mark).
static func xbox(c: MotionCanvas, centre: Vector2, size: float, col: Color, w := 2.0, opacity := 1.0, s := 1.0) -> void:
	if s <= 0.0:
		return
	var h := size * 0.5 * s
	var r := Rect2(centre - Vector2(h, h), Vector2(h, h) * 2.0)
	c.polyline(rect_pts(r), col, w, opacity, true)
	c.line(r.position, r.end, col, w, opacity)
	c.line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), col, w, opacity)


## A plus-shaped crosshair with a ring.
static func crosshair(c: MotionCanvas, centre: Vector2, r: float, col: Color, w := 2.0, opacity := 1.0, s := 1.0) -> void:
	if s <= 0.0:
		return
	r *= s
	c.ring(centre, r, col, w, opacity)
	c.line(centre - Vector2(r * 1.6, 0), centre - Vector2(r * 0.4, 0), col, w, opacity)
	c.line(centre + Vector2(r * 0.4, 0), centre + Vector2(r * 1.6, 0), col, w, opacity)
	c.line(centre - Vector2(0, r * 1.6), centre - Vector2(0, r * 0.4), col, w, opacity)
	c.line(centre + Vector2(0, r * 0.4), centre + Vector2(0, r * 1.6), col, w, opacity)


## A small "+" registration mark.
static func plus(c: MotionCanvas, centre: Vector2, r: float, col: Color, w := 2.0, opacity := 1.0) -> void:
	c.line(centre - Vector2(r, 0), centre + Vector2(r, 0), col, w, opacity)
	c.line(centre - Vector2(0, r), centre + Vector2(0, r), col, w, opacity)


## A seeded barcode filling `r`; `on` 0..1 wipes it in from the left.
static func barcode(c: MotionCanvas, r: Rect2, col: Color, seed_v := 1.0, on := 1.0, opacity := 1.0, vertical := false) -> void:
	var x := 0.0
	var k := 0
	var length := r.size.y if vertical else r.size.x
	while x < length * clampf(on, 0.0, 1.0):
		var w := 2.0 + floorf(MK.rand(k * 1.7 + seed_v) * 4.0) * 2.0
		var gap := 2.0 + floorf(MK.rand(k * 2.9 + seed_v + 5.0) * 3.0) * 2.0
		if vertical:
			c.rect(Rect2(r.position + Vector2(0, x), Vector2(r.size.x, minf(w, length - x))), col, opacity)
		else:
			c.rect(Rect2(r.position + Vector2(x, 0), Vector2(minf(w, length - x), r.size.y)), col, opacity)
		x += w + gap
		k += 1


## A path through `pts` with circular arcs of radius `r` at each corner (sampled).
static func rounded_path(pts: PackedVector2Array, r: float, seg := 8) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var b := pts[i]
		var cc := pts[i + 1]
		var d1 := (a - b).normalized()
		var d2 := (cc - b).normalized()
		var ang := d1.angle_to(d2)
		var t := minf(r / tan(absf(ang) * 0.5), minf(a.distance_to(b), b.distance_to(cc)) * 0.5)
		var p1 := b + d1 * t
		var p2 := b + d2 * t
		# quadratic bezier through the corner approximates the arc well enough
		for k in seg + 1:
			var u := float(k) / seg
			out.append(p1.lerp(b, u).lerp(b.lerp(p2, u), u))
	out.append(pts[pts.size() - 1])
	return out


static func path_length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


## The part of `pts` between arc lengths a and b (fractions 0..1 of the whole).
static func sub_path(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var total := path_length(pts)
	var la := clampf(a, 0.0, 1.0) * total
	var lb := clampf(b, 0.0, 1.0) * total
	var out := PackedVector2Array()
	if lb <= la:
		return out
	var acc := 0.0
	for i in range(1, pts.size()):
		var p := pts[i - 1]
		var q := pts[i]
		var seg := p.distance_to(q)
		if seg <= 0.0:
			continue
		var s0 := acc
		var s1 := acc + seg
		if s1 >= la and s0 <= lb:
			var u0 := clampf((la - s0) / seg, 0.0, 1.0)
			var u1 := clampf((lb - s0) / seg, 0.0, 1.0)
			if out.is_empty():
				out.append(p.lerp(q, u0))
			out.append(p.lerp(q, u1))
		acc = s1
	return out


## A thick ribbon along `pts` (already rounded), from fraction a to b, with round
## joins and either round or square ends.
static func ribbon(c: MotionCanvas, pts: PackedVector2Array, width: float, col: Color, a := 0.0, b := 1.0, round_ends := true, opacity := 1.0) -> void:
	var sp := sub_path(pts, a, b)
	if sp.size() < 2:
		return
	var end_mode := Geometry2D.END_ROUND if round_ends else Geometry2D.END_BUTT
	for poly in Geometry2D.offset_polyline(sp, width * 0.5, Geometry2D.JOIN_ROUND, end_mode):
		c.polygon(poly, col, Color(0, 0, 0, 0), 0.0, opacity)


## A band of parallel ribbons following one path (livery stripes). `cols` from the
## inside of the bends outwards; `gap` between bands.
static func stripe_bundle(c: MotionCanvas, pts: PackedVector2Array, widths: Array, cols: Array, gap: float, a := 0.0, b := 1.0, opacity := 1.0) -> void:
	var total := 0.0
	for w in widths:
		total += float(w) + gap
	total -= gap
	var off := -total * 0.5
	for i in widths.size():
		var w: float = widths[i]
		var line := offset_path(pts, off + w * 0.5)
		ribbon(c, line, w, cols[i], a, b, false, opacity)
		off += w + gap


## A copy of an open path shifted sideways by d (positive = left of travel).
static func offset_path(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var t := Vector2.ZERO
		if i > 0:
			t += (pts[i] - pts[i - 1]).normalized()
		if i < n - 1:
			t += (pts[i + 1] - pts[i]).normalized()
		t = t.normalized()
		var nrm := Vector2(t.y, -t.x)
		# keep the band width constant through corners
		var k := 1.0
		if i > 0 and i < n - 1:
			var d1 := (pts[i] - pts[i - 1]).normalized()
			k = 1.0 / maxf(0.35, nrm.dot(Vector2(d1.y, -d1.x)))
		out.append(pts[i] + nrm * d * k)
	return out
