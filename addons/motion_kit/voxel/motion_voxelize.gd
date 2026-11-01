# SPDX-License-Identifier: Apache-2.0
## Voxelise a mask onto a grid of cells: sample an SVG (any of its parts), an
## Image or an analytic function at `cols` × `rows` cells, each supersampled,
## and keep per cell how much of it is covered and which part covers it. Turn
## the filled cells into targets (cell + height) for MotionBlockPlan, which
## moves existing blocks onto them.
##
##   var vox := MotionVoxelize.from_svg(logo_data, 72, 20)          # whole document
##   var tg := vox.targets(func(part: int, cover: float, cell: Vector2i) -> float:
##       return 1.6 if part in LETTERS else 0.3)                    # height per cell (<= 0: skip)
##   print(vox.ascii())
##
## Cells are row-major, row 0 at the top of the mask (SVG y down). `world(cell,
## origin)` places a cell on a ground grid where +y is north (row 0 is the
## northmost row), the convention of MotionExtrude scenes.
##
## Sampling happens once (at build); everything here is deterministic.
@tool
class_name MotionVoxelize
extends RefCounted

var cols := 0
var rows := 0
## The mask area sampled, in source units (SVG document units, image pixels, or 0..1 for a function).
var rect := Rect2()
## Fraction of each cell's samples covered by any sampled part (0..1).
var cover := PackedFloat32Array()
## The part covering most of each cell's samples (topmost in document order at each sample); -1 when empty.
var part := PackedInt32Array()
## Coverage at or above this marks a cell filled.
var threshold := 0.45


## Sample SVG parts (default: every part with a fill) over `area` (default: the
## viewBox) with `ss` × `ss` samples per cell. Fill rules (nonzero / evenodd)
## are honoured, so counters stay open; later parts cover earlier ones.
## `offsets` (part → Vector2, source units) shifts parts before sampling: pull
## a logo's stacked layers apart so each shows as its own band of cells.
static func from_svg(data: MotionSvgData, c: int, r: int, parts: Array = [], area := Rect2(), ss := 3, thresh := 0.45, offsets := {}) -> MotionVoxelize:
	var v := MotionVoxelize.new()
	v._setup(c, r, area if area.has_area() else data.view_box, thresh)
	var idx: Array = parts if not parts.is_empty() else range(data.parts.size())
	# Flatten each part once: contours + bbox + rule.
	var shapes: Array = []
	for i in idx:
		var p: Dictionary = data.parts[i]
		if (p.fill as Color).a <= 0.0 and not p.get("gradient", false):
			continue
		var bb: Rect2 = p.bbox
		var tol := maxf(0.05, minf(v.rect.size.x / c, v.rect.size.y / r) * 0.05)
		var off: Vector2 = offsets.get(int(i), Vector2.ZERO)
		shapes.append({part = int(i), bbox = bb.grow(tol), off = off, contours = data.outline(i, tol), evenodd = p.get("fill_rule", "nonzero") == "evenodd"})
	v._sample(ss, func(pt: Vector2) -> int:
		for k in range(shapes.size() - 1, -1, -1):
			var s: Dictionary = shapes[k]
			var q: Vector2 = pt - (s.off as Vector2)
			if not (s.bbox as Rect2).has_point(q):
				continue
			if inside(s.contours, q, s.evenodd):
				return s.part
		return -1)
	return v


## Sample an Image: a cell sample is filled where the pixel's alpha (or
## luminance, `use_luma`) is above 0.5. Grab a CanvasItem mask once with a
## SubViewport's `get_texture().get_image()` and pass it here. Part is 0.
static func from_image(img: Image, c: int, r: int, area := Rect2(), ss := 3, thresh := 0.45, use_luma := false) -> MotionVoxelize:
	var v := MotionVoxelize.new()
	v._setup(c, r, area if area.has_area() else Rect2(Vector2.ZERO, img.get_size()), thresh)
	var w := img.get_width()
	var h := img.get_height()
	v._sample(ss, func(pt: Vector2) -> int:
		var x := clampi(int(pt.x), 0, w - 1)
		var y := clampi(int(pt.y), 0, h - 1)
		var col := img.get_pixel(x, y)
		var val := col.get_luminance() * col.a if use_luma else col.a
		return 0 if val > 0.5 else -1)
	return v


## Sample a function over 0..1 × 0..1 (y down): `fn(uv: Vector2) -> int` returns
## a part id (>= 0) or -1 for empty.
static func from_fn(fn: Callable, c: int, r: int, ss := 3, thresh := 0.45) -> MotionVoxelize:
	var v := MotionVoxelize.new()
	v._setup(c, r, Rect2(0, 0, 1, 1), thresh)
	v._sample(ss, fn)
	return v


func _setup(c: int, r: int, area: Rect2, thresh: float) -> void:
	cols = c
	rows = r
	rect = area
	threshold = thresh
	cover.resize(c * r)
	part.resize(c * r)


func _sample(ss: int, hit: Callable) -> void:
	var cw := rect.size.x / cols
	var ch := rect.size.y / rows
	var n := float(ss * ss)
	for r in rows:
		for c in cols:
			var counts := {}
			var any := 0
			for sy in ss:
				for sx in ss:
					var pt := rect.position + Vector2((c + (sx + 0.5) / ss) * cw, (r + (sy + 0.5) / ss) * ch)
					var p: int = hit.call(pt)
					if p >= 0:
						any += 1
						counts[p] = int(counts.get(p, 0)) + 1
			var best := -1
			var bn := 0
			for k in counts:
				if int(counts[k]) > bn or (int(counts[k]) == bn and int(k) > best):
					bn = counts[k]
					best = k
			cover[r * cols + c] = any / n
			part[r * cols + c] = best


## Point in a multi-contour shape (nonzero winding, or even-odd).
static func inside(contours: Array, pt: Vector2, evenodd := false) -> bool:
	var wn := 0
	var crossings := 0
	for cv in contours:
		var poly: PackedVector2Array = cv
		var n := poly.size()
		if n < 3:
			continue
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			if a.y <= pt.y:
				if b.y > pt.y and (b - a).cross(pt - a) > 0.0:
					wn += 1
					crossings += 1
			elif b.y <= pt.y and (b - a).cross(pt - a) < 0.0:
				wn -= 1
				crossings += 1
	return (crossings % 2) == 1 if evenodd else wn != 0


func filled(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols and r < rows and cover[r * cols + c] >= threshold


func part_at(c: int, r: int) -> int:
	return part[r * cols + c] if filled(c, r) else -1


## Every filled cell as a target. `height_fn(part, cover, cell) -> float` sets
## its height (default 1); a height <= 0 drops the cell. Returns an Array of
## {cell: Vector2i, h: float, part: int}, in row order.
func targets(height_fn := Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rows:
		for c in cols:
			if not filled(c, r):
				continue
			var p := part[r * cols + c]
			var h := 1.0
			if height_fn.is_valid():
				h = height_fn.call(p, cover[r * cols + c], Vector2i(c, r))
			if h > 0.0:
				out.append({cell = Vector2i(c, r), h = h, part = p})
	return out


## A cell's south-west corner on a ground grid whose south-west cell is at
## `origin` (row 0 is the northmost row: y = origin.y + rows - 1 - r).
func world(cell: Vector2i, origin := Vector2.ZERO) -> Vector2:
	return origin + Vector2(cell.x, rows - 1 - cell.y)


## Filled cells as text (part ids as letters), for checking a resolution.
func ascii(chars := "#ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz") -> String:
	var s := ""
	for r in rows:
		for c in cols:
			var p := part_at(c, r)
			s += "." if p < 0 else chars[p % chars.length()]
		s += "\n"
	return s
