# SPDX-License-Identifier: Apache-2.0
## Loads font files (ttf, otf, woff, woff2) at runtime, cached, set up for
## motion work: optional multichannel SDF (sharp while scaling up, but small
## sizes can show corner artifacts, so it is off by default), no
## hinting and sub-pixel positioning so spacing matches browser rendering.
##
## Fallbacks (faces tried for characters the font lacks, e.g. Japanese inside
## Latin text) are part of the request: `font(path, false, [jp])` returns a
## font of its own for that combination. Don't assign `.fallbacks` on a font
## from here: the font is shared by everything that asked for the same file,
## so another caller's fallbacks would silently change (and depend on load order).
class_name MotionFonts
extends RefCounted

static var _cache := {}


## The font at `path`, cached per (path, msdf, fallbacks). `fallbacks` is a
## list of Fonts tried in order for missing glyphs (cached by identity: pass
## the same Font objects to share the result).
static func font(path: String, msdf := false, fallbacks: Array = []) -> FontFile:
	var key := "%s|%s" % [path, msdf]
	if not fallbacks.is_empty():
		var ids := PackedStringArray()
		for fb in fallbacks:
			ids.append(str((fb as Object).get_instance_id()))
		var fkey := key + "|" + ",".join(ids)
		if _cache.has(fkey):
			return _cache[fkey]
		var v := font(path, msdf).duplicate() as FontFile
		var list: Array[Font] = []
		for fb in fallbacks:
			list.append(fb as Font)
		v.fallbacks = list
		_cache[fkey] = v
		return v
	if _cache.has(key):
		return _cache[key]
	var f: FontFile
	if ResourceLoader.exists(path):
		# Imported font (the normal case, and the only one in an exported game).
		f = (load(path) as FontFile).duplicate(true)
	else:
		f = FontFile.new()
		var err := f.load_dynamic_font(path)
		assert(err == OK, "MotionFonts: cannot load %s" % path)
	f.multichannel_signed_distance_field = msdf
	f.msdf_pixel_range = 16
	f.msdf_size = 64
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.generate_mipmaps = true
	_cache[key] = f
	return f


## Snap a pixel size to a geometric ladder of sizes `ladder` apart (1.06: about
## 6% steps) so text zooming with the camera reuses glyph rasters instead of
## rasterising every size. `floor_steps` snaps down instead of to the nearest.
static func ladder_size(px: float, ladder: float, floor_steps := false) -> float:
	var steps := log(px) / log(ladder)
	return pow(ladder, floorf(steps) if floor_steps else roundf(steps))


## Draw `text` so it appears `size` units tall under the canvas transform `xf`
## (a zooming camera or map), rasterised at its on-screen size snapped to a
## `ladder` (see ladder_size) and scaled to fit, so it stays sharp at any zoom
## without a glyph cache per frame. Skipped below `min_px` on screen.
## `align`/`width` are draw_string's; `anchor` shifts the text left by that
## fraction of its width (0.5 centres it on `pos` without a width).
## `screen_scale` > 0 gives the on-screen scale directly (else measured from xf).
## Leaves the canvas transform at `xf`.
static func draw_screen_text(c: CanvasItem, xf: Transform2D, font: Font, pos: Vector2, text: String,
		size: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, ladder := 1.06, min_px := 0.0,
		width := -1.0, anchor := 0.0, screen_scale := 0.0) -> void:
	var k := screen_scale if screen_scale > 0.0 else maxf(xf.x.length(), xf.y.length())
	var want := size * k
	if want < min_px:
		return
	var px := clampi(int(round(ladder_size(want, ladder))), 1, 1024)
	var s := float(px) / size
	var at := Vector2.ZERO
	if anchor != 0.0:
		at.x = -font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * anchor
	c.draw_set_transform_matrix(xf * Transform2D(0.0, pos) * Transform2D.IDENTITY.scaled(Vector2.ONE / s))
	c.draw_string(font, at, text, align, width * s if width > 0.0 else -1.0, px, col)
	c.draw_set_transform_matrix(xf)
