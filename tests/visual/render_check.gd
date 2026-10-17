# SPDX-License-Identifier: Apache-2.0
# GPU checks that need a real renderer (the headless suite has none):
#   godot --path . --rendering-driver opengl3 res://tests/visual/render_check.tscn
# Prints ok/FAIL per check and quits with the failure count.
# Expected values are the CSS ones: an edge blurred with sigma s reads
# 1 - Phi(d / s) at distance d (pixel centres sit half a pixel in), in the
# sRGB values the browser blends.
extends Node2D

var _frames := 0
var _fails := 0


func _ready() -> void:
	var bg := ColorRect.new(); bg.color = Color.BLACK; bg.size = Vector2(1920, 1080); add_child(bg)
	# 1. MotionFX.blur is CSS filter: blur(), i.e. sigma: white half-plane, sigma 8.
	var fx := MotionFX.new(); fx.size = Vector2(800, 200); fx.position = Vector2(0, 0); fx.blur = 8.0; add_child(fx)
	var r := ColorRect.new(); r.color = Color.WHITE; r.position = Vector2(-100, -100); r.size = Vector2(500, 400); fx.content.add_child(r)
	# 2. MotionShape.blur is a box-shadow radius: 16 means sigma 8.
	var sh := MotionShape.new(); sh.kind = MotionShape.Kind.RECT; sh.anchor = Vector2.ZERO; sh.position = Vector2(-400, 250); sh.size = Vector2(800, 400); sh.blur = 16.0; sh.color = Color.WHITE
	add_child(sh)
	# 3. MotionFX shadow_blur is a text-shadow / drop-shadow radius: 16 means sigma 8.
	var sfx := MotionFX.new(); sfx.size = Vector2(800, 200); sfx.position = Vector2(0, 700); sfx.shadow_color = Color.WHITE; sfx.shadow_blur = 16.0; add_child(sfx)
	var b := ColorRect.new(); b.color = Color(0, 0, 0, 1); b.position = Vector2(-100, -100); b.size = Vector2(500, 400); sfx.content.add_child(b)
	# 4. CanvasGroup gives CSS group opacity: white over red at 50% reads grey, not pink.
	var grp := CanvasGroup.new(); grp.position = Vector2(1000, 50); grp.self_modulate.a = 0.5; add_child(grp)
	var red := ColorRect.new(); red.color = Color.RED; red.size = Vector2(100, 100); grp.add_child(red)
	var wht := ColorRect.new(); wht.color = Color.WHITE; wht.size = Vector2(100, 100); grp.add_child(wht)
	# 5. Linear gradient, left to right, black to white over 512 px.
	var g := MotionGradient.linear(Vector2(512, 100), 90.0, [Color.BLACK, Color.WHITE], [0.0, 1.0]); g.position = Vector2(1200, 300); add_child(g)


func _phi(x: float) -> float:
	# Normal CDF via an erf approximation (Abramowitz-Stegun 7.1.26, |err| < 1.5e-7).
	var z := absf(x) / sqrt(2.0)
	var t := 1.0 / (1.0 + 0.3275911 * z)
	var e := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z)
	return 0.5 * (1.0 + (e if x >= 0.0 else -e))


func _check(name: String, got: float, want: float, tol := 0.03) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("  %s  %s: %.3f (want %.3f)" % ["ok  " if ok else "FAIL", name, got, want])


func _process(_d: float) -> void:
	_frames += 1
	if _frames != 4:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for d in [-8, 0, 8, 16]:
		_check("FX blur sigma 8, d=%d" % d, img.get_pixel(400 + d, 100).r, 1.0 - _phi((d + 0.5) / 8.0), 0.01)
	for d in [-8, 0, 8, 16]:
		_check("shape blur 16 (sigma 8), d=%d" % d, img.get_pixel(400 + d, 450).r, 1.0 - _phi((d + 0.5) / 8.0), 0.01)
	for d in [8, 16]:
		_check("FX shadow 16 (sigma 8), d=%d" % d, img.get_pixel(400 + d, 800).r, 1.0 - _phi((d + 0.5) / 8.0), 0.01)
	var c := img.get_pixel(1050, 100)
	_check("group opacity red channel", c.r, 0.5)
	_check("group opacity green channel", c.g, 0.5)
	_check("gradient midpoint", img.get_pixel(1456, 350).r, 0.5, 0.01)
	print("%d failed" % _fails)
	get_tree().quit(_fails)
