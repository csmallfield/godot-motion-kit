# SPDX-License-Identifier: Apache-2.0
# Regression check for MotionSvg's raster cache:
#   godot --path . --rendering-driver opengl3 res://tests/visual/svg_cache_check.tscn
# Four parts of the SCF mark seen at 13x (F4's dive) need near-4096 px rasters
# that together exceed the cache budget. The cache used to free a texture the
# frame still drew (the canvas holds only its RID), which blacked out the whole
# frame. Prints ok/FAIL and quits with the failure count.
extends Node2D

var _frames := 0


func _ready() -> void:
	MotionSvg.cache_budget = 16 * 1024 * 1024   # force evictions within the frame
	var bg := ColorRect.new(); bg.color = Color(0.3, 0.3, 0.3); bg.size = Vector2(1920, 1080); add_child(bg)
	var full := SCFBrand.logo("scfFull")
	var F: Dictionary = SCFBrand.SCF_FULL
	var s := MotionSvg.new(); s.data = full; s.width = 1560; s.position = Vector2(180, 290)
	s.only = PackedInt32Array(F.edges + [F.discS])
	var dc := Vector2(180, 290) + (full.parts[F.discC].bbox as Rect2).get_center() * (1560.0 / full.view_box.size.x)
	var root := Node2D.new()
	root.transform = Transform2D(Vector2(13.3, 0), Vector2(0, 13.3), dc - dc * 13.3)
	add_child(root)
	root.add_child(s)


func _process(_d: float) -> void:
	_frames += 1
	if _frames != 4:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var got := img.get_pixel(1800, 600).r
	var ok := absf(got - 0.3) < 0.02
	print("  %s  background clear of the mark stays visible: %.3f (want 0.300)" % ["ok  " if ok else "FAIL", got])
	print("%d failed" % (0 if ok else 1))
	get_tree().quit(0 if ok else 1)
