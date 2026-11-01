# SPDX-License-Identifier: Apache-2.0
# Minimal Humans / SCF brand values and logo part maps, ported from the
# scf-intros Remotion project (src/lib/brand.ts, Logo.tsx).
# The logos are Minimal Humans trademarks; they are not covered by the
# repository's Apache-2.0 grant.
class_name SCFBrand
extends RefCounted

const BLUE := Color("#1b6393")
const AMBER := Color("#f4af3f")
const RED := Color("#ef393b")
const CREAM := Color("#ece5da")
const INK := Color("#111111")
const BLACK := Color("#010101")

# Japanese secondary type (brand.ts JP), Wipeout/Designers Republic style.
const JP := {
	"mh": "ミニマル・ヒューマンズ", "scf": "ストーリー・コンテキスト・フレームワーク", "presents": "提供",
	"story": "物語文脈", "boot": "起動", "ready": "準備完了", "warning": "警告", "decoding": "解読中", "signal": "信号",
}

const W := 1920.0
const H := 1080.0
const FPS := 30.0

const LOGO_FILES := {
	mhM = "res://demo/assets/logos/mh_logoM.svg",
	mhFull = "res://demo/assets/logos/mh_logoFull_standard.svg",
	mhShort = "res://demo/assets/logos/mh_logoShort.svg",
	scfMark = "res://demo/assets/logos/scf_logoBig_noCloud.svg",
	scfCloud = "res://demo/assets/logos/scf_logoBig_cloud.svg",
	scfFull = "res://demo/assets/logos/scf_logoFull_white.svg",
}

# Part indices (Logo.tsx IDX). The parser keeps document order, which the
# SVG tests check against the Remotion decomposition.
const MH_FULL_M := [0, 1, 2]
const MH_FULL_MINIMAL := [3, 4, 5, 6, 7, 8, 9]
const MH_FULL_HUMANS := [10, 11, 12, 13, 14, 15]
const MH_SHORT_M := [0, 1, 2]
const MH_SHORT_WORDS := [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const MH_SHORT_CODE := [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
const SCF_MARK_EDGES := [0, 1, 2]
const SCF_MARK := {
	edges = [0, 1, 2], discS = 3, discC = 12, discF = 13,
	nodes = [4, 5, 6, 7, 8, 9, 10, 11, 14, 15],
	S = [16, 17], C = [18, 19], F = [20, 21],
}
const SCF_FULL := {
	cloud = 0,
	story = [1, 2, 3, 4, 5], context = [6, 7, 8, 9, 10, 11, 12], framework = [13, 14, 15, 16, 17, 18, 19, 20, 21],
	edges = [22, 23, 24], discS = 25, discC = 34, discF = 35,
	nodes = [26, 27, 28, 29, 30, 31, 32, 33, 36, 37],
	S = [38, 39], C = [40, 41], F = [42, 43],
}

static var _logos := {}
static var _fonts := {}


static func logo(key: String) -> MotionSvgData:
	if not _logos.has(key):
		_logos[key] = MotionSvgData.load_any(LOGO_FILES[key])
	return _logos[key]


## Font by family and weight, e.g. font("outfit", 800).
static func font(family: String, weight := 400) -> FontFile:
	var files := {
		"outfit": "outfit-latin-%d-normal.woff2", "space_mono": "space-mono-latin-%d-normal.woff2",
		"shoulders": "big-shoulders-display-latin-%d-normal.woff2", "inter": "inter-latin-%d-normal.woff2",
		"unbounded": "unbounded-latin-%d-normal.woff2", "mono": "jetbrains-mono-latin-%d-normal.woff2",
		"archivo": "archivo-black-latin-%d-normal.woff2", "michroma": "michroma-latin-%d-normal.woff2",
	}
	if family == "jp":
		return MotionFonts.font("res://demo/assets/fonts/noto-jp-%s.woff2" % ("Black" if weight >= 700 else "Regular"))
	# Japanese characters inside latin text fall back to the Noto JP subset, as in the browser.
	var jp := MotionFonts.font("res://demo/assets/fonts/noto-jp-%s.woff2" % ("Black" if weight >= 700 else "Regular"))
	return MotionFonts.font("res://demo/assets/fonts/" + (files[family] as String) % weight, false, [jp])


## Remotion springAt(f, fps)(at, damping, stiffness, mass).
static func sp(f: float, at: float, damping := 10.0, stiffness := 140.0, mass := 1.0) -> float:
	return MK.spring(f, at, damping, stiffness, mass, FPS)


## A circle that grows from (x, y) until it covers the frame (super.tsx CircleWipe).
static func circle_wipe(shape: MotionShape, f: float, at: float, x: float, y: float, col: Color, dur := 12.0, reverse := false) -> void:
	var t := MK.map(f, [at, at + dur], [0, 1], MK.ease_in_out)
	if reverse:
		t = 1.0 - t
	shape.visible = t > 0.0
	shape.position = Vector2(x, y)
	shape.size = Vector2(4800, 4800) * t
	shape.color = col


## A CSS-positioned disc: left/top box of side `d`, scaled about its centre.
static func disc(shape: MotionShape, left: float, top: float, d: float, col: Color, s: float) -> void:
	shape.position = Vector2(left + d * 0.5, top + d * 0.5)
	shape.size = Vector2(d, d)
	shape.color = col
	shape.scale = Vector2.ONE * maxf(0.0, s)
	shape.visible = s > 0.0
