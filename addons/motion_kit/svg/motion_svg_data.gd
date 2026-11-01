# SPDX-License-Identifier: Apache-2.0
## A parsed SVG, kept as vector data: one entry per drawable element ("part").
## Made by the Motion SVG importer (Import dock → Import As → Motion SVG) or at
## runtime with MotionSvgData.from_string().
##
## Each part stores its geometry as absolute cubic contours in document units,
## with every transform already applied, so a part can be rasterized alone at
## any size and its outline drawn as a polyline.
@tool
class_name MotionSvgData
extends Resource

## The document's viewBox (x, y, w, h).
@export var view_box := Rect2(0, 0, 100, 100)
## One Dictionary per part, in document order:
##   tag: String          source element name (path, circle, ...)
##   id: String           element id, "" if none
##   classes: PackedStringArray
##   groups: PackedStringArray   ids of enclosing <g> elements, outermost first
##   fill: Color          resolved fill (alpha 0 when none)
##   stroke: Color        resolved stroke (alpha 0 when none)
##   stroke_width: float  in document units, transforms applied
##   fill_rule: String    "nonzero" or "evenodd"
##   gradient: bool       fill or stroke references a gradient; rasterized in its own colours
##   cubics: Array[PackedVector2Array]   one per subpath: p0, c1, c2, p1, c1, c2, p2, ...
##   closed: PackedByteArray             1 when the subpath was closed with Z
##   bbox: Rect2          tight bounds of the geometry
##   svg: String          the element re-emitted for the rasterizer (absolute, transformed)
@export var parts: Array[Dictionary] = []
## Raw <defs> markup (gradients) needed to rasterize parts that use them.
@export var defs := ""
## Parser warnings: unsupported elements and the like.
@export var warnings := PackedStringArray()
## Source path, for messages.
@export var source := ""


static func from_string(svg_text: String, source_path := "") -> MotionSvgData:
	return MotionSvgParser.parse(svg_text, source_path)


## Parse an .svg from disk. For tools and editor use: exported games do not
## contain the raw .svg, so load() the file imported as Motion SVG instead.
static func from_file(path: String) -> MotionSvgData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "MotionSvgData: cannot read %s" % path)
	return MotionSvgParser.parse(text, path)


## The document at `path` however it is available: the imported resource
## when the file was imported as Motion SVG (the only option in an exported
## game), else parsed from the .svg on disk (an .svg imported as a texture).
static func load_any(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func part_count() -> int:
	return parts.size()


## Indices of the parts whose id, class or enclosing group id is `name`.
func find(name: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in parts.size():
		var p: Dictionary = parts[i]
		if p.id == name or (p.classes as PackedStringArray).has(name) or (p.groups as PackedStringArray).has(name):
			out.append(i)
	return out


## Part indices sorted left to right by bounding box (reading order for letters).
func sorted_by_x(indices: PackedInt32Array = PackedInt32Array()) -> PackedInt32Array:
	var idx := Array(indices) if indices.size() > 0 else range(parts.size())
	idx.sort_custom(func(a, b): return (parts[a].bbox as Rect2).position.x < (parts[b].bbox as Rect2).position.x)
	return PackedInt32Array(idx)


## Centre of a part's bounding box, in document units.
func centre(i: int) -> Vector2:
	return (parts[i].bbox as Rect2).get_center()


## Flattened outline of part `i`: one PackedVector2Array per subpath, in document units.
## `tolerance` is the largest allowed distance from the true curve.
func outline(i: int, tolerance := 0.02) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var p: Dictionary = parts[i]
	var closed: PackedByteArray = p.closed
	var k := 0
	for c in p.cubics:
		var pts := PackedVector2Array()
		var cv: PackedVector2Array = c
		pts.append(cv[0])
		var j := 0
		while j + 3 < cv.size():
			MotionSvgParser.flatten_cubic(cv[j], cv[j + 1], cv[j + 2], cv[j + 3], tolerance, pts)
			j += 3
		if k < closed.size() and closed[k] == 1 and pts.size() > 1 and pts[0].distance_to(pts[pts.size() - 1]) > 1e-6:
			pts.append(pts[0])
		out.append(pts)
		k += 1
	return out


## Flattened outlines of `parts` (one index or an Array of them) placed in
## world space (svg units * k + tl), all in one list. `clean` drops a closing
## point that repeats the first (within 0.01) and contours of 2 points or fewer.
func contours(part_ids: Variant, k := 1.0, tl := Vector2.ZERO, tolerance := 0.25, clean := false) -> Array[PackedVector2Array]:
	var ids: Array = part_ids if part_ids is Array else [part_ids]
	var out: Array[PackedVector2Array] = []
	for i in ids:
		for c in outline(int(i), tolerance):
			var pts := PackedVector2Array()
			for p in c:
				pts.append(tl + p * k)
			if clean:
				if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
					pts.remove_at(pts.size() - 1)
				if pts.size() <= 2:
					continue
			out.append(pts)
	return out


## The whole document as one SVG string, every part in its own colours
## (for rasterizing it in one piece, as MotionPixelGrid does).
func to_svg_string(width := 0, height := 0) -> String:
	var body := PackedStringArray()
	for p in parts:
		var s: String = p.svg
		if not p.gradient:
			var f: Color = p.fill
			var st: Color = p.stroke
			s = s.replace("/>", " fill=\"#%s\" fill-opacity=\"%s\" stroke=\"#%s\" stroke-opacity=\"%s\" stroke-width=\"%s\"/>" % [
				f.to_html(false), str(f.a), st.to_html(false), str(st.a), str(p.stroke_width)])
		body.append(s)
	var vb := view_box
	var size_attr := (" width=\"%d\" height=\"%d\"" % [width, height]) if width > 0 else ""
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"%s %s %s %s\"%s preserveAspectRatio=\"none\"><defs>%s</defs>%s</svg>" % [
		str(vb.position.x), str(vb.position.y), str(vb.size.x), str(vb.size.y), size_attr, defs, "".join(body)]
