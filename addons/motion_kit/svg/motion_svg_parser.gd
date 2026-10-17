# SPDX-License-Identifier: Apache-2.0
## SVG → MotionSvgData. Handles what Illustrator, Figma and Inkscape export for
## logos: path (every command), rect (with corner radii), circle, ellipse, line,
## polyline, polygon, nested <g> transforms, presentation attributes, style=""
## and <style> rules (.class, #id, tag). Every shape becomes absolute cubic
## contours with its transforms applied.
##
## Not supported (reported in `warnings`): <text> (outline it first), <use>,
## <image>, clip paths, masks, filters and patterns.
class_name MotionSvgParser
extends RefCounted

const KAPPA := 0.5522847498307936
const SKIP_CONTENT := ["defs", "clipPath", "mask", "symbol", "pattern", "marker", "metadata", "title", "desc", "filter"]
const SHAPES := ["path", "rect", "circle", "ellipse", "line", "polyline", "polygon"]
const UNSUPPORTED := ["text", "use", "image", "foreignObject", "switch"]
const STYLE_PROPS := ["fill", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "stroke-width",
	"opacity", "display", "visibility", "color", "stop-color"]
const INHERITED := ["fill", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "stroke-width", "visibility", "color"]


static func parse(text: String, source := "") -> MotionSvgData:
	var data := MotionSvgData.new()
	data.source = source
	if text.strip_edges().is_empty():
		data.warnings.append("empty SVG")
		return data
	var rules := _parse_css(_collect_style_text(text))
	data.defs = _collect_gradients(text)

	var xml := XMLParser.new()
	if xml.open_buffer(text.to_utf8_buffer()) != OK:
		data.warnings.append("not readable as XML")
		return data

	# Element state stack: {style, xf, groups, skip, opacity}
	var stack: Array[Dictionary] = []
	var root := {style = {fill = "#000000", "fill-rule" = "nonzero", stroke = "none", "stroke-width" = "1", visibility = "visible", color = "#000000"},
		xf = Transform2D.IDENTITY, groups = PackedStringArray(), skip = 0, opacity = 1.0}
	var have_view_box := false
	var warned := {}

	while xml.read() == OK:
		var t := xml.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var tag := _local(xml.get_node_name())
			var attrs := {}
			for a in xml.get_attribute_count():
				attrs[_local(xml.get_attribute_name(a))] = xml.get_attribute_value(a)
			var parent: Dictionary = stack.back() if stack.size() > 0 else root
			var state := {style = parent.style, xf = parent.xf, groups = parent.groups, skip = parent.skip, opacity = parent.opacity}

			if tag == "svg" and stack.is_empty():
				if attrs.has("viewBox"):
					var vb := _numbers(attrs.viewBox)
					if vb.size() == 4:
						data.view_box = Rect2(vb[0], vb[1], vb[2], vb[3])
						have_view_box = true
				if not have_view_box and attrs.has("width") and attrs.has("height"):
					data.view_box = Rect2(0, 0, _num(attrs.width), _num(attrs.height))
			if tag in SKIP_CONTENT:
				state.skip = int(parent.skip) + 1

			if int(state.skip) == 0:
				var style := _resolve_style(tag, attrs, parent.style, rules)
				state.style = style
				if attrs.has("transform"):
					state.xf = (parent.xf as Transform2D) * _parse_transform(attrs.transform)
				var op := _alpha(style.get("opacity", "1"))
				state.opacity = float(parent.opacity) * op
				if style.get("display", "") == "none":
					state.skip = int(state.skip) + 1   # a hidden group hides everything in it
				if tag == "g" and attrs.has("id"):
					var gs := PackedStringArray(parent.groups)
					gs.append(attrs.id)
					state.groups = gs
				if tag in SHAPES and style.get("display", "") != "none" and style.get("visibility", "visible") != "hidden":
					var part := _make_part(tag, attrs, state, data)
					if not part.is_empty():
						data.parts.append(part)
				elif tag in UNSUPPORTED and not warned.has(tag):
					warned[tag] = true
					data.warnings.append("<%s> is not supported and was skipped%s" % [tag, " (convert text to outlines)" if tag == "text" else ""])
			if not xml.is_empty():
				stack.push_back(state)
		elif t == XMLParser.NODE_ELEMENT_END:
			if stack.size() > 0:
				stack.pop_back()
	return data


# ------------------------------------------------------------------ parts

static func _make_part(tag: String, a: Dictionary, state: Dictionary, _data: MotionSvgData) -> Dictionary:
	var subs: Array = []   # each: {pts: PackedVector2Array, closed: bool}
	match tag:
		"path":
			subs = path_to_cubics(a.get("d", ""))
		"rect":
			subs = _rect(_num(a.get("x", "0")), _num(a.get("y", "0")), _num(a.get("width", "0")), _num(a.get("height", "0")),
				a.get("rx", ""), a.get("ry", ""))
		"circle":
			var r := _num(a.get("r", "0"))
			subs = _ellipse(_num(a.get("cx", "0")), _num(a.get("cy", "0")), r, r)
		"ellipse":
			subs = _ellipse(_num(a.get("cx", "0")), _num(a.get("cy", "0")), _num(a.get("rx", "0")), _num(a.get("ry", "0")))
		"line":
			var p0 := Vector2(_num(a.get("x1", "0")), _num(a.get("y1", "0")))
			var p1 := Vector2(_num(a.get("x2", "0")), _num(a.get("y2", "0")))
			subs = [{pts = PackedVector2Array([p0, p0.lerp(p1, 1.0 / 3.0), p0.lerp(p1, 2.0 / 3.0), p1]), closed = false}]
		"polyline", "polygon":
			var n := _numbers(a.get("points", ""))
			var pts := PackedVector2Array()
			var i := 0
			while i + 1 < n.size():
				var p := Vector2(n[i], n[i + 1])
				if pts.is_empty():
					pts.append(p)
				else:
					var q := pts[pts.size() - 1]
					pts.append_array([q.lerp(p, 1.0 / 3.0), q.lerp(p, 2.0 / 3.0), p])
				i += 2
			if tag == "polygon" and pts.size() > 1:
				var q := pts[pts.size() - 1]
				if q.distance_to(pts[0]) > 1e-9:
					pts.append_array([q.lerp(pts[0], 1.0 / 3.0), q.lerp(pts[0], 2.0 / 3.0), pts[0]])
			subs = [{pts = pts, closed = tag == "polygon"}]
	if subs.is_empty():
		return {}

	var xf: Transform2D = state.xf
	var cubics: Array[PackedVector2Array] = []
	var closed := PackedByteArray()
	for s in subs:
		var pts: PackedVector2Array = s.pts
		if pts.size() < 4:
			continue
		var out := PackedVector2Array()
		out.resize(pts.size())
		for j in pts.size():
			out[j] = xf * pts[j]
		cubics.append(out)
		closed.append(1 if s.closed else 0)
	if cubics.is_empty():
		return {}

	var style: Dictionary = state.style
	var op: float = state.opacity
	var fill_src: String = style.get("fill", "#000000")
	var stroke_src: String = style.get("stroke", "none")
	var gradient := fill_src.begins_with("url(") or stroke_src.begins_with("url(")
	var fill := _color(fill_src, style)
	fill.a *= _alpha(style.get("fill-opacity", "1")) * op
	var stroke := _color(stroke_src, style)
	stroke.a *= _alpha(style.get("stroke-opacity", "1")) * op
	var det := absf(xf.x.x * xf.y.y - xf.x.y * xf.y.x)
	var sw := _num(style.get("stroke-width", "1"), 1.0) * sqrt(det)
	var rule: String = style.get("fill-rule", "nonzero")

	# Tight bounds from a coarse flattening.
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)
	for cv in cubics:
		var flat := PackedVector2Array([cv[0]])
		var j := 0
		while j + 3 < cv.size():
			flatten_cubic(cv[j], cv[j + 1], cv[j + 2], cv[j + 3], 0.005, flat)
			j += 3
		for p in flat:
			bmin = bmin.min(p)
			bmax = bmax.max(p)

	var d := cubics_to_d(cubics, closed)
	var svg := "<path d=\"%s\" fill-rule=\"%s\"" % [d, rule]
	if gradient:
		svg += " fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"" % [fill_src, stroke_src, str(sw)]
		if op < 1.0:
			svg += " opacity=\"%s\"" % str(op)
	svg += "/>"

	return {
		tag = tag, id = a.get("id", ""), classes = PackedStringArray(a.get("class", "").split(" ", false)),
		groups = state.groups, fill = fill, stroke = stroke, stroke_width = sw, fill_rule = rule,
		gradient = gradient, cubics = cubics, closed = closed, bbox = Rect2(bmin, bmax - bmin), svg = svg,
	}


static func cubics_to_d(cubics: Array, closed: PackedByteArray) -> String:
	var parts := PackedStringArray()
	for k in cubics.size():
		var cv: PackedVector2Array = cubics[k]
		parts.append("M%s %s" % [_f(cv[0].x), _f(cv[0].y)])
		var j := 1
		while j + 2 < cv.size():
			parts.append("C%s %s %s %s %s %s" % [_f(cv[j].x), _f(cv[j].y), _f(cv[j + 1].x), _f(cv[j + 1].y), _f(cv[j + 2].x), _f(cv[j + 2].y)])
			j += 3
		if k < closed.size() and closed[k] == 1:
			parts.append("Z")
	return "".join(parts)


static func _f(v: float) -> String:
	return String.num(v, 4)


# ------------------------------------------------------------------ shapes

static func _rect(x: float, y: float, w: float, h: float, rxs: String, rys: String) -> Array:
	if w <= 0.0 or h <= 0.0:
		return []
	var rx := _num(rxs, -1.0)
	var ry := _num(rys, -1.0)
	if rx < 0.0 and ry < 0.0:
		rx = 0.0; ry = 0.0
	elif rx < 0.0:
		rx = ry
	elif ry < 0.0:
		ry = rx
	rx = minf(rx, w / 2.0)
	ry = minf(ry, h / 2.0)
	var pts := PackedVector2Array()
	var line := func(p: Vector2) -> void:
		var q := pts[pts.size() - 1]
		pts.append_array([q.lerp(p, 1.0 / 3.0), q.lerp(p, 2.0 / 3.0), p])
	if rx == 0.0 or ry == 0.0:
		pts.append(Vector2(x, y))
		line.call(Vector2(x + w, y))
		line.call(Vector2(x + w, y + h))
		line.call(Vector2(x, y + h))
		line.call(Vector2(x, y))
		return [{pts = pts, closed = true}]
	var kx := rx * KAPPA
	var ky := ry * KAPPA
	pts.append(Vector2(x + rx, y))
	line.call(Vector2(x + w - rx, y))
	pts.append_array([Vector2(x + w - rx + kx, y), Vector2(x + w, y + ry - ky), Vector2(x + w, y + ry)])
	line.call(Vector2(x + w, y + h - ry))
	pts.append_array([Vector2(x + w, y + h - ry + ky), Vector2(x + w - rx + kx, y + h), Vector2(x + w - rx, y + h)])
	line.call(Vector2(x + rx, y + h))
	pts.append_array([Vector2(x + rx - kx, y + h), Vector2(x, y + h - ry + ky), Vector2(x, y + h - ry)])
	line.call(Vector2(x, y + ry))
	pts.append_array([Vector2(x, y + ry - ky), Vector2(x + rx - kx, y), Vector2(x + rx, y)])
	return [{pts = pts, closed = true}]


static func _ellipse(cx: float, cy: float, rx: float, ry: float) -> Array:
	if rx <= 0.0 or ry <= 0.0:
		return []
	var kx := rx * KAPPA
	var ky := ry * KAPPA
	var pts := PackedVector2Array([
		Vector2(cx + rx, cy),
		Vector2(cx + rx, cy + ky), Vector2(cx + kx, cy + ry), Vector2(cx, cy + ry),
		Vector2(cx - kx, cy + ry), Vector2(cx - rx, cy + ky), Vector2(cx - rx, cy),
		Vector2(cx - rx, cy - ky), Vector2(cx - kx, cy - ry), Vector2(cx, cy - ry),
		Vector2(cx + kx, cy - ry), Vector2(cx + rx, cy - ky), Vector2(cx + rx, cy),
	])
	return [{pts = pts, closed = true}]


# ------------------------------------------------------------------ path data

## Parse SVG path data into subpaths of absolute cubic segments.
static func path_to_cubics(d: String) -> Array:
	var sc := _Scanner.new(d)
	var subs: Array = []
	var pts := PackedVector2Array()
	var closed := false
	var cur := Vector2.ZERO
	var start := Vector2.ZERO
	var last_c := Vector2.ZERO     # last cubic control point, for S
	var last_q := Vector2.ZERO     # last quadratic control point, for T
	var prev := ""
	var cmd := ""

	while true:
		sc.skip_sep()
		if sc.at_end():
			break
		var ch := sc.peek()
		if _is_cmd(ch):
			cmd = ch
			sc.pos += 1
		elif cmd == "":
			break   # malformed: numbers before any command
		elif cmd == "M":
			cmd = "L"
		elif cmd == "m":
			cmd = "l"
		var rel := cmd == cmd.to_lower() and cmd != "Z" and cmd != "z"
		var up := cmd.to_upper()
		var o := cur if rel else Vector2.ZERO

		if up == "Z":
			if pts.size() > 0:
				if cur.distance_to(start) > 1e-9:
					pts.append_array([cur.lerp(start, 1.0 / 3.0), cur.lerp(start, 2.0 / 3.0), start])
				subs.append({pts = pts, closed = true})
				pts = PackedVector2Array()
			cur = start
			last_c = cur
			last_q = cur
			prev = up
			cmd = ""
			# After Z, numbers without a command are malformed; a new command must follow.
			continue

		if up == "M":
			var p := o + Vector2(sc.number(), sc.number())
			if pts.size() > 3:
				subs.append({pts = pts, closed = false})
			pts = PackedVector2Array([p])
			cur = p
			start = p
			last_c = cur
			last_q = cur
			prev = up
			continue

		if pts.is_empty():
			pts.append(cur)   # drawing after Z without M starts at the subpath start
			start = cur

		match up:
			"L":
				var p := o + Vector2(sc.number(), sc.number())
				pts.append_array([cur.lerp(p, 1.0 / 3.0), cur.lerp(p, 2.0 / 3.0), p])
				cur = p
			"H":
				var x := sc.number() + (cur.x if rel else 0.0)
				var p := Vector2(x, cur.y)
				pts.append_array([cur.lerp(p, 1.0 / 3.0), cur.lerp(p, 2.0 / 3.0), p])
				cur = p
			"V":
				var y := sc.number() + (cur.y if rel else 0.0)
				var p := Vector2(cur.x, y)
				pts.append_array([cur.lerp(p, 1.0 / 3.0), cur.lerp(p, 2.0 / 3.0), p])
				cur = p
			"C":
				var c1 := o + Vector2(sc.number(), sc.number())
				var c2 := o + Vector2(sc.number(), sc.number())
				var p := o + Vector2(sc.number(), sc.number())
				pts.append_array([c1, c2, p])
				last_c = c2
				cur = p
			"S":
				var c1 := cur * 2.0 - last_c if prev in ["C", "S"] else cur
				var c2 := o + Vector2(sc.number(), sc.number())
				var p := o + Vector2(sc.number(), sc.number())
				pts.append_array([c1, c2, p])
				last_c = c2
				cur = p
			"Q":
				var q := o + Vector2(sc.number(), sc.number())
				var p := o + Vector2(sc.number(), sc.number())
				pts.append_array([cur + (q - cur) * (2.0 / 3.0), p + (q - p) * (2.0 / 3.0), p])
				last_q = q
				cur = p
			"T":
				var q := cur * 2.0 - last_q if prev in ["Q", "T"] else cur
				var p := o + Vector2(sc.number(), sc.number())
				pts.append_array([cur + (q - cur) * (2.0 / 3.0), p + (q - p) * (2.0 / 3.0), p])
				last_q = q
				cur = p
			"A":
				var rx := absf(sc.number())
				var ry := absf(sc.number())
				var phi := sc.number()
				var large := sc.flag()
				var sweep := sc.flag()
				var p := o + Vector2(sc.number(), sc.number())
				pts.append_array(arc_to_cubics(cur, rx, ry, phi, large, sweep, p))
				cur = p
			_:
				break
		if sc.failed:
			break
		if up != "C" and up != "S":
			last_c = cur
		if up != "Q" and up != "T":
			last_q = cur
		prev = up
	if pts.size() > 3:
		subs.append({pts = pts, closed = closed})
	return subs


static func _is_cmd(c: String) -> bool:
	return c in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]


## Endpoint-parameterised elliptical arc → cubic segments (c1, c2, p per segment).
static func arc_to_cubics(p0: Vector2, rx: float, ry: float, phi_deg: float, large: bool, sweep: bool, p1: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if p0.distance_to(p1) < 1e-9:
		return out
	if rx < 1e-9 or ry < 1e-9:
		out.append_array([p0.lerp(p1, 1.0 / 3.0), p0.lerp(p1, 2.0 / 3.0), p1])
		return out
	var phi := deg_to_rad(phi_deg)
	var cp := cos(phi)
	var sp := sin(phi)
	var dx := (p0.x - p1.x) / 2.0
	var dy := (p0.y - p1.y) / 2.0
	var x1 := cp * dx + sp * dy
	var y1 := -sp * dx + cp * dy
	var lam := (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
	if lam > 1.0:
		var s := sqrt(lam)
		rx *= s
		ry *= s
	var num := rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
	var den := rx * rx * y1 * y1 + ry * ry * x1 * x1
	var co := sqrt(maxf(0.0, num / den)) if den > 0.0 else 0.0
	if large == sweep:
		co = -co
	var cxp := co * rx * y1 / ry
	var cyp := -co * ry * x1 / rx
	var cx := cp * cxp - sp * cyp + (p0.x + p1.x) / 2.0
	var cy := sp * cxp + cp * cyp + (p0.y + p1.y) / 2.0
	var ang := func(ux: float, uy: float, vx: float, vy: float) -> float:
		return atan2(ux * vy - uy * vx, ux * vx + uy * vy)
	var t1: float = ang.call(1.0, 0.0, (x1 - cxp) / rx, (y1 - cyp) / ry)
	var dt: float = ang.call((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
	if not sweep and dt > 0.0:
		dt -= TAU
	elif sweep and dt < 0.0:
		dt += TAU
	var segs := int(ceil(absf(dt) / (PI / 2.0) - 1e-9))
	segs = maxi(segs, 1)
	var delta := dt / segs
	var k := 4.0 / 3.0 * tan(delta / 4.0)
	var pt := func(t: float) -> Vector2:
		return Vector2(cx + rx * cos(t) * cp - ry * sin(t) * sp, cy + rx * cos(t) * sp + ry * sin(t) * cp)
	var dpt := func(t: float) -> Vector2:
		return Vector2(-rx * sin(t) * cp - ry * cos(t) * sp, -rx * sin(t) * sp + ry * cos(t) * cp)
	var theta := t1
	for i in segs:
		var ta := theta
		var tb := theta + delta
		var a: Vector2 = pt.call(ta)
		var b: Vector2 = pt.call(tb) if i < segs - 1 else p1
		out.append_array([a + dpt.call(ta) * k, b - dpt.call(tb) * k, b])
		theta = tb
	return out


## Adaptive flattening: appends points along the cubic (not p0, always p3) until
## every chord is within `tol` of the curve.
static func flatten_cubic(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, tol: float, out: PackedVector2Array, depth := 0) -> void:
	var d := p3 - p0
	var len2 := d.length_squared()
	var flat: float
	if len2 < 1e-12:
		flat = maxf(p0.distance_to(c1), p0.distance_to(c2))
	else:
		var inv := 1.0 / sqrt(len2)
		flat = maxf(absf(d.cross(c1 - p0)) * inv, absf(d.cross(c2 - p0)) * inv)
	if flat <= tol or depth >= 14:
		out.append(p3)
		return
	var p01 := p0.lerp(c1, 0.5)
	var p12 := c1.lerp(c2, 0.5)
	var p23 := c2.lerp(p3, 0.5)
	var a := p01.lerp(p12, 0.5)
	var b := p12.lerp(p23, 0.5)
	var m := a.lerp(b, 0.5)
	flatten_cubic(p0, p01, a, m, tol, out, depth + 1)
	flatten_cubic(m, b, p23, p3, tol, out, depth + 1)


# ------------------------------------------------------------------ style

static func _collect_style_text(text: String) -> String:
	var re := RegEx.create_from_string("(?s)<style[^>]*>(.*?)</style>")
	var out := ""
	for m in re.search_all(text):
		out += m.get_string(1).replace("<![CDATA[", "").replace("]]>", "") + "\n"
	return out


## Gradient definitions, re-serialised from the XML stream (a regex cannot
## match the nesting of <stop/> children reliably).
static func _collect_gradients(text: String) -> String:
	var xml := XMLParser.new()
	if xml.open_buffer(text.to_utf8_buffer()) != OK:
		return ""
	var out := ""
	var depth := 0   # > 0 while inside a gradient element
	while xml.read() == OK:
		var t := xml.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var tag := _local(xml.get_node_name())
			if depth == 0 and tag != "linearGradient" and tag != "radialGradient":
				continue
			var el := "<" + tag
			for i in xml.get_attribute_count():
				el += " %s=\"%s\"" % [_local(xml.get_attribute_name(i)), xml.get_attribute_value(i).xml_escape(true)]
			if xml.is_empty():
				out += el + "/>"
			else:
				out += el + ">"
				depth += 1
		elif t == XMLParser.NODE_ELEMENT_END and depth > 0:
			out += "</%s>" % _local(xml.get_node_name())
			depth -= 1
	return out


## CSS rules as [{sel_kind: 0 tag | 1 class | 2 id, name, decls: Dictionary, order}]
static func _parse_css(css: String) -> Array:
	var rules: Array = []
	css = RegEx.create_from_string("(?s)/\\*.*?\\*/").sub(css, "", true)
	var re := RegEx.create_from_string("([^{}]+)\\{([^}]*)\\}")
	var order := 0
	for m in re.search_all(css):
		var decls := _parse_decls(m.get_string(2))
		for sel in m.get_string(1).split(","):
			sel = sel.strip_edges()
			if sel == "":
				continue
			var kind := 0
			var name := sel
			if sel.begins_with("."):
				kind = 1; name = sel.substr(1)
			elif sel.begins_with("#"):
				kind = 2; name = sel.substr(1)
			elif " " in sel or ">" in sel or ":" in sel or "[" in sel:
				continue   # descendant/pseudo selectors: out of scope
			rules.append({kind = kind, name = name, decls = decls, order = order})
			order += 1
	return rules


static func _parse_decls(s: String) -> Dictionary:
	var out := {}
	for d in s.split(";"):
		var i := d.find(":")
		if i < 0:
			continue
		out[d.substr(0, i).strip_edges()] = d.substr(i + 1).strip_edges().replace("!important", "").strip_edges()
	return out


static func _resolve_style(tag: String, a: Dictionary, parent: Dictionary, rules: Array) -> Dictionary:
	var s := {}
	for k in INHERITED:
		if parent.has(k):
			s[k] = parent[k]
	# Presentation attributes are the weakest author styles...
	for k in STYLE_PROPS:
		if a.has(k):
			s[k] = a[k]
	# ...then stylesheet rules by specificity (tag < class < id), source order within...
	var classes := PackedStringArray(a.get("class", "").split(" ", false))
	for kind in [0, 1, 2]:
		for r in rules:
			if r.kind != kind:
				continue
			var hit: bool = (kind == 0 and r.name == tag) or (kind == 1 and classes.has(r.name)) or (kind == 2 and r.name == a.get("id", ""))
			if hit:
				s.merge(r.decls, true)
	# ...then the style attribute.
	if a.has("style"):
		s.merge(_parse_decls(a.style), true)
	if s.get("fill", "") == "inherit":
		s.fill = parent.get("fill", "#000000")
	return s


# CSS colour keywords that Godot's (X11) colour table defines differently.
const CSS_NAMES := {
	"green": Color("#008000"), "gray": Color("#808080"), "grey": Color("#808080"),
	"maroon": Color("#800000"), "purple": Color("#800080"), "darkgray": Color("#a9a9a9"),
	"darkgrey": Color("#a9a9a9"), "lightgray": Color("#d3d3d3"), "lightgrey": Color("#d3d3d3"),
}


static func _color(src: String, style: Dictionary) -> Color:
	src = src.strip_edges()
	if src == "" or src == "none" or src == "transparent":
		return Color(0, 0, 0, 0)
	if src.begins_with("url("):
		return Color(1, 1, 1, 1)
	if src == "currentColor":
		src = style.get("color", "#000000")
	if src.begins_with("rgb"):
		# rgb(255, 0, 0) · rgb(100% 0% 0%) · rgba(255,0,0,0.5) · rgb(255 0 0 / 50%)
		var inner := src.substr(src.find("(") + 1).trim_suffix(")")
		var alpha_part := ""
		if "/" in inner:
			alpha_part = inner.get_slice("/", 1)
			inner = inner.get_slice("/", 0)
		var comps := inner.replace(",", " ").split(" ", false)
		if comps.size() >= 3:
			var ch := PackedFloat64Array()
			for i in 3:
				var c: String = comps[i]
				ch.append(_num(c) / (100.0 if c.ends_with("%") else 255.0))
			if alpha_part == "" and comps.size() > 3:
				alpha_part = comps[3]
			var a := _alpha(alpha_part) if alpha_part != "" else 1.0
			return Color(ch[0], ch[1], ch[2], a)
	if src.begins_with("#"):
		return Color.html(src)
	var key := src.to_lower()
	if CSS_NAMES.has(key):
		return CSS_NAMES[key]
	return Color.from_string(key, Color.BLACK)


## An opacity value: "0.5" or "50%".
static func _alpha(v: Variant) -> float:
	var t := str(v).strip_edges()
	if t.is_empty():
		return 1.0
	var n := _num(t, 1.0)
	return clampf(n / 100.0 if t.ends_with("%") else n, 0.0, 1.0)


# ------------------------------------------------------------------ transforms and numbers

static func _parse_transform(s: String) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var re := RegEx.create_from_string("(matrix|translate|scale|rotate|skewX|skewY)\\s*\\(([^)]*)\\)")
	for m in re.search_all(s):
		var n := _numbers(m.get_string(2))
		var t := Transform2D.IDENTITY
		match m.get_string(1):
			"matrix":
				if n.size() == 6:
					t = Transform2D(Vector2(n[0], n[1]), Vector2(n[2], n[3]), Vector2(n[4], n[5]))
			"translate":
				if n.size() >= 1:
					t = Transform2D(0.0, Vector2(n[0], n[1] if n.size() > 1 else 0.0))
			"scale":
				if n.is_empty():
					continue
				var sx: float = n[0]
				var sy: float = n[1] if n.size() > 1 else sx
				t = Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)
			"rotate":
				if n.is_empty():
					continue
				var r := deg_to_rad(n[0])
				t = Transform2D(r, Vector2.ZERO)
				if n.size() == 3:
					var c := Vector2(n[1], n[2])
					t = Transform2D(0.0, c) * t * Transform2D(0.0, -c)
			"skewX":
				if n.is_empty():
					continue
				t = Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(n[0])), 1), Vector2.ZERO)
			"skewY":
				if n.is_empty():
					continue
				t = Transform2D(Vector2(1, tan(deg_to_rad(n[0]))), Vector2(0, 1), Vector2.ZERO)
		xf = xf * t
	return xf


static func _numbers(s: String) -> PackedFloat64Array:
	var sc := _Scanner.new(s)
	var out := PackedFloat64Array()
	while true:
		sc.skip_sep()
		if sc.at_end():
			break
		var c := sc.peek()
		if not (c.is_valid_int() or c in ["-", "+", "."]):
			sc.pos += 1
			continue
		var v := sc.number()
		if sc.failed:
			break
		out.append(v)
	return out


static func _num(s: Variant, fallback := 0.0) -> float:
	var t := str(s).strip_edges()
	if t == "":
		return fallback
	var n := _numbers(t)
	if n.is_empty():
		return fallback
	return n[0]


static func _local(name: String) -> String:
	var i := name.find(":")
	return name if i < 0 else name.substr(i + 1)


## Tokenizer for SVG number lists: handles "1.03-.83", ".5.5", "1e-3", and
## compact arc flags ("a1 1 0 011 2").
class _Scanner:
	extends RefCounted
	var s: String
	var pos := 0
	var failed := false

	func _init(text: String) -> void:
		s = text

	func at_end() -> bool:
		return pos >= s.length()

	func peek() -> String:
		return s[pos]

	func skip_sep() -> void:
		while pos < s.length():
			var c := s.unicode_at(pos)
			if c == 32 or c == 44 or c == 9 or c == 10 or c == 13:
				pos += 1
			else:
				break

	func flag() -> bool:
		skip_sep()
		if pos < s.length() and (s[pos] == "0" or s[pos] == "1"):
			var v := s[pos] == "1"
			pos += 1
			return v
		failed = true
		return false

	func number() -> float:
		skip_sep()
		var n := s.length()
		var b := pos
		if pos < n and (s[pos] == "-" or s[pos] == "+"):
			pos += 1
		var digits := false
		while pos < n and s.unicode_at(pos) >= 48 and s.unicode_at(pos) <= 57:
			pos += 1
			digits = true
		if pos < n and s[pos] == ".":
			pos += 1
			while pos < n and s.unicode_at(pos) >= 48 and s.unicode_at(pos) <= 57:
				pos += 1
				digits = true
		if digits and pos < n and (s[pos] == "e" or s[pos] == "E"):
			var save := pos
			pos += 1
			if pos < n and (s[pos] == "-" or s[pos] == "+"):
				pos += 1
			var ed := false
			while pos < n and s.unicode_at(pos) >= 48 and s.unicode_at(pos) <= 57:
				pos += 1
				ed = true
			if not ed:
				pos = save
		if not digits:
			pos = b
			failed = true
			return 0.0
		return s.substr(b, pos - b).to_float()
