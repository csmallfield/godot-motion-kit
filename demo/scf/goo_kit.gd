# SPDX-License-Identifier: Apache-2.0
# Shared pieces for the goo intros (G1–G5), ported from scf-intros src/lib/goo.tsx.
class_name GooKit
extends RefCounted

## The three monogram layers, back to front: red, amber, cream (offsets in M units).
const M_LAYER_OFF := [Vector2(9.3, 8.3), Vector2(4.7, 4.2), Vector2(0, 0)]
static var M_LAYER_COL: Array[Color] = [SCFBrand.RED, SCFBrand.AMBER, SCFBrand.CREAM]
## mhM viewBox width / cream layer width.
const M_VIEW := 129.95 / 120.63
static var DISC_COLS: Array[Color] = [SCFBrand.BLUE, SCFBrand.AMBER, SCFBrand.RED]

static var _outline: Array = []


## Metaballs (the <Goo> component): discs blurred by `sigma`, alpha * sharp -
## sharp * 0.42, flooded with `col`. A MotionFX padded past the frame by three
## sigma so blobs just off screen still bleed in, as the filter region allows.
## Returns {fx, cv, blobs}; set blobs to an Array of Vector3(x, y, r) and call
## cv.queue_redraw(). Extra drawing (the goo's children) goes in cv's children.
static func goo(parent: Node, col: Color, sigma := 16.0, sharp := 26.0, size := Vector2(1920, 1080)) -> Dictionary:
	var pad := ceilf(sigma * 3.0) + 8.0
	var fx := MotionFX.new()
	fx.size = size + Vector2(pad, pad) * 2.0
	fx.position = -Vector2(pad, pad)
	fx.blur = sigma
	fx.alpha_matrix = Vector2(sharp, -sharp * 0.42)
	fx.flood_color = filter_colour(col)
	parent.add_child(fx)
	var cv := MotionCanvas.new()
	cv.position = Vector2(pad, pad)
	fx.content.add_child(cv)
	var g := {fx = fx, cv = cv, blobs = []}
	cv.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		for b: Vector3 in g.blobs:
			if b.z > 0.5:
				c.circle(Vector2(b.x, b.y), b.z, Color.BLACK)
	return g


## Chromium runs SVG filters in linearRGB with 8 bits a channel, so a flood
## colour comes back through that round trip: dark tones shift (#111111 comes
## out #0d0d0d), light ones barely move.
static func filter_colour(c: Color) -> Color:
	var lin := c.srgb_to_linear()
	return Color(roundf(lin.r * 255) / 255, roundf(lin.g * 255) / 255, roundf(lin.b * 255) / 255, c.a).linear_to_srgb()


static func set_blobs(g: Dictionary, blobs: Array) -> void:
	g.blobs = blobs
	(g.cv as MotionCanvas).queue_redraw()


static func in_poly(x: float, y: float, P: Array) -> bool:
	var c := false
	var j := P.size() - 1
	for i in P.size():
		var xi: float = P[i][0]
		var yi: float = P[i][1]
		var xj: float = P[j][0]
		var yj: float = P[j][1]
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
			c = not c
		j = i
	return c


static func m_outline() -> Array:
	if _outline.is_empty():
		_outline = JSON.parse_string(FileAccess.get_file_as_string("res://demo/scf/m_outline.json")).mOutline
	return _outline


## Grid points inside the M (its own units, 0–120.6), every `step`.
static func m_points(step := 8.5) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var y := step / 2.0
	while y < 120.6:
		var x := step / 2.0
		while x < 120.6:
			if in_poly(x, y, m_outline()):
				out.append(Vector2(x, y))
			x += step
		y += step
	return out


## Where the SCF lockup's parts land for a placement: discs and nodes as
## {x, y, r, col}, plus the part index lists.
static func scf_geom(s_w: float, s_x: float, s_y: float) -> Dictionary:
	var L := SCFBrand.logo("scfFull")
	var k := s_w / L.view_box.size.x
	var F: Dictionary = SCFBrand.SCF_FULL
	var at := func(i: int) -> Dictionary:
		var bb: Rect2 = L.parts[i].bbox
		var c := bb.get_center()
		return {x = s_x + c.x * k, y = s_y + c.y * k, r = bb.size.x * 0.5 * k, col = L.parts[i].fill}
	var nodes := []
	for i in F.nodes:
		nodes.append(at.call(i))
	return {
		S_K = k, S_X = s_x, S_Y = s_y, S_W = s_w,
		discs = [at.call(F.discS), at.call(F.discC), at.call(F.discF)],
		nodes = nodes,
		words = F.story + F.context + F.framework,
		letters = [F.S, F.C, F.F],
	}


## Gravity drop and jelly landing for one logo part.
static func jelly(r: float, h: float, pivot: Vector2, drop_frames := 9.0) -> Dictionary:
	if r < 0.0:
		return {hide = true}
	var fall := minf(1.0, r / drop_frames)
	var t := r - drop_frames
	var sq := 0.42 * exp(-t / 4.5) * cos(t * 0.95) if t > 0.0 else 0.0
	return {ty = -(1.0 - fall * fall) * h, sy = 1.0 - sq, sx = 1.0 + sq * 0.7, pivot = pivot}


## Damped wobble 0 -> overshoot -> 1 after `at`.
static func wob(f: float, at: float, k := 0.9, d := 5.0) -> float:
	var t := f - at
	if t < 0.0:
		return 0.0
	return 1.0 - exp(-t / d) * cos(t * k)


## The crisp mhM monogram in a div that scales about its bottom centre (an
## inline <svg> adds the strut gap under it). Returns the pivot node.
static func m_mono(parent: Node, x: float, y: float, w: float) -> Node2D:
	var mono := MotionSvg.new()
	mono.data = SCFBrand.logo("mhM")
	mono.width = w
	var div := Vector2(mono.width, mono.get_size().y + PrintKit.STRUT_GAP)
	var pivot := Node2D.new()
	pivot.position = Vector2(x, y) + Vector2(div.x * 0.5, div.y)
	parent.add_child(pivot)
	mono.position = -Vector2(div.x * 0.5, div.y)
	pivot.add_child(mono)
	return pivot
