# SPDX-License-Identifier: Apache-2.0
## Loads font files (ttf, otf, woff, woff2) at runtime, cached, set up for
## motion work: optional multichannel SDF (sharp while scaling up, but small
## sizes can show corner artifacts, so it is off by default), no
## hinting and sub-pixel positioning so spacing matches browser rendering.
class_name MotionFonts
extends RefCounted

static var _cache := {}


static func font(path: String, msdf := false) -> FontFile:
	var key := "%s|%s" % [path, msdf]
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
