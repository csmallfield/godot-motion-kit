# SPDX-License-Identifier: Apache-2.0
# The bold flat pictograms from scf-intros (src/lib/print.tsx Icon), on a
# 24-unit grid. Built as SVG text and drawn through MotionSvg, so they are
# vector at any size. `bg` punches the holes.
class_name SCFIcons
extends RefCounted

static var _cache := {}


static func svg(name: String, c: Color, bg: Color) -> String:
	var C := "#" + c.to_html(false)
	var G := "#" + bg.to_html(false)
	var body := ""
	match name:
		"arrow":
			body = "<polygon points='1.5,8.5 12.5,8.5 12.5,3 22.5,12 12.5,21 12.5,15.5 1.5,15.5' fill='%s'/>" % C
		"eye":
			body = "<path d='M1 12s4-7.5 11-7.5S23 12 23 12s-4 7.5-11 7.5S1 12 1 12z' fill='%s'/><circle cx='12' cy='12' r='4.4' fill='%s'/><circle cx='12' cy='12' r='2.2' fill='%s'/>" % [C, G, C]
		"database":
			body = ("<path d='M3.5 5v14c0 1.9 3.8 3.4 8.5 3.4s8.5-1.5 8.5-3.4V5' fill='%s'/><ellipse cx='12' cy='5' rx='8.5' ry='3.3' fill='%s'/>"
				+ "<ellipse cx='12' cy='5' rx='5.6' ry='1.6' fill='%s'/><path d='M3.5 10.2c0 1.9 3.8 3.4 8.5 3.4s8.5-1.5 8.5-3.4M3.5 15.2c0 1.9 3.8 3.4 8.5 3.4s8.5-1.5 8.5-3.4' fill='none' stroke='%s' stroke-width='1.4'/>") % [C, C, G, G]
		"nodes":
			body = ("<path d='M6 7 L12 15 L18 7' fill='none' stroke='%s' stroke-width='2.2'/><circle cx='6' cy='7' r='4.4' fill='%s'/>"
				+ "<circle cx='18' cy='7' r='4.4' fill='%s'/><circle cx='12' cy='16.5' r='5.2' fill='%s'/>") % [C, C, C, C]
		"check":
			body = "<polygon points='2,12.5 5.5,9 9.5,13 18.5,4 22,7.5 9.5,20' fill='%s'/>" % C
		"cross":
			body = "<polygon points='5,2 12,9 19,2 22,5 15,12 22,19 19,22 12,15 5,22 2,19 9,12 2,5' fill='%s'/>" % C
		"bolt":
			body = "<polygon points='14,1 4,13.5 11,13.5 9,23 20,9.5 13,9.5' fill='%s'/>" % C
		"plus":
			body = "<path d='M9 2h6v7h7v6h-7v7H9v-7H2V9h7z' fill='%s'/>" % C
		_:
			push_warning("SCFIcons: unknown icon %s" % name)
	return "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>%s</svg>" % body.replace("'", "\"")


## A MotionSvg showing the icon at `size` pixels.
static func make(name: String, size: float, c: Color, bg: Color) -> MotionSvg:
	var key := "%s|%s|%s" % [name, c.to_html(), bg.to_html()]
	if not _cache.has(key):
		_cache[key] = MotionSvgData.from_string(svg(name, c, bg))
	var s := MotionSvg.new()
	s.data = _cache[key]
	s.width = size
	return s
