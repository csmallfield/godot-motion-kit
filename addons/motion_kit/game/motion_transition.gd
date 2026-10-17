# SPDX-License-Identifier: Apache-2.0
## Scene transitions (autoload "MotionTransition", added by the plugin).
##
##   await MotionTransition.change_scene("res://race.tscn", "circle")
##   await MotionTransition.cover("bars"); ...; await MotionTransition.uncover("bars")
##
## Styles: "circle" (from `origin`, or the centre), "bars", "clock", "fade",
## "glitch" (slices and RGB split of the outgoing picture), "crt" (tube off/on).
## Runs while the tree is paused and ignores Engine.time_scale.
extends CanvasLayer

signal covered
signal finished

const SCREEN_FX := preload("res://addons/motion_kit/shaders/motion_screen_fx.gdshader")

## Frames per phase at 30 fps (cover and uncover each take this long).
var frames := 18.0
var colour := Color("#111111")
## Bar colours for "bars", cycled.
var bar_colours: Array[Color] = [Color("#1b6393"), Color("#f4af3f"), Color("#ef393b"), Color("#111111")]
var busy := false

var _stage: Node2D
var _circle: MotionShape
var _arc: MotionShape
var _bars: Array[MotionShape] = []
var _fade: ColorRect
var _screen: ColorRect
var _screen_mat: ShaderMaterial


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = Node2D.new()
	add_child(_stage)
	_circle = MotionShape.new()
	_stage.add_child(_circle)
	_arc = MotionShape.new()
	_arc.kind = MotionShape.Kind.ARC
	_stage.add_child(_arc)
	for i in 7:
		var b := MotionShape.new()
		b.kind = MotionShape.Kind.RECT
		b.anchor = Vector2(0, 0)
		_stage.add_child(b)
		_bars.append(b)
	_fade = ColorRect.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_fade)
	_screen = ColorRect.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = SCREEN_FX
	_screen.material = _screen_mat
	_stage.add_child(_screen)
	_hide_all()


## Cover, change scene (path or PackedScene) while covered, uncover.
func change_scene(scene: Variant, style := "circle", origin := Vector2(-1, -1)) -> void:
	if busy:
		return
	await cover(style, origin)
	if scene is PackedScene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(str(scene))
	await get_tree().process_frame
	await get_tree().process_frame
	await uncover(style, origin)


func cover(style := "circle", origin := Vector2(-1, -1)) -> void:
	busy = true
	await _run(style, origin, false)
	covered.emit()


func uncover(style := "circle", origin := Vector2(-1, -1)) -> void:
	await _run(style, origin, true)
	_hide_all()
	busy = false
	finished.emit()


func _hide_all() -> void:
	for c in _stage.get_children():
		c.visible = false


func _run(style: String, origin: Vector2, reverse: bool) -> void:
	var size := get_viewport().get_visible_rect().size
	_hide_all()
	var elapsed := 0.0
	while true:
		var f := elapsed * 30.0
		var t := MK.map(f, [0, frames], [0, 1], MK.ease_in_out)
		var k := 1.0 - t if reverse else t
		_draw_style(style, k, f, size, origin, reverse)
		if f >= frames:
			break
		await get_tree().process_frame
		var d := get_process_delta_time()
		elapsed += d / Engine.time_scale if Engine.time_scale > 0.0 else d


func _draw_style(style: String, k: float, f: float, size: Vector2, origin: Vector2, reverse: bool) -> void:
	var c := origin if origin.x >= 0.0 else size * 0.5
	match style:
		"circle":
			var far := maxf(maxf(c.length(), (c - Vector2(size.x, 0)).length()), maxf((c - Vector2(0, size.y)).length(), (c - size).length()))
			_circle.visible = k > 0.0
			_circle.position = c
			_circle.size = Vector2.ONE * far * 2.0 * k
			_circle.color = colour
		"clock":
			var far := size.length()
			_arc.visible = k > 0.0
			_arc.position = size * 0.5
			_arc.size = Vector2.ONE * far
			_arc.thickness = far * 0.5
			_arc.sweep_from = 0.0
			_arc.sweep_to = k
			_arc.color = colour
		"bars":
			var n := _bars.size()
			var w := size.x / n
			for i in n:
				var b := _bars[i]
				# staggered drop; uncovering lifts them away in the same order
				var stagger := float(i) / n * 0.45
				var p := clampf((k - stagger) / 0.55, 0.0, 1.0) if not reverse else clampf((k - (0.45 - stagger)) / 0.55, 0.0, 1.0)
				p = MK.ease_in_out.call(p)
				b.visible = p > 0.0
				b.size = Vector2(w + 1.0, size.y * p)
				b.position = Vector2(i * w, 0.0 if not reverse else size.y * (1.0 - p))
				b.color = bar_colours[i % bar_colours.size()]
		"fade":
			_fade.visible = k > 0.0
			_fade.size = size
			_fade.color = Color(colour, k)
		"glitch":
			_screen.visible = k > 0.0
			_screen.size = size
			_screen_mat.set_shader_parameter("mode", 0)
			_screen_mat.set_shader_parameter("t", k)
			_screen_mat.set_shader_parameter("cover_color", colour)
			var offs := PackedFloat32Array()
			offs.resize(32)
			for i in 18:
				var r := MK.rand(97.0 + i * 13.0 + floorf(f / 2.0) * 7.0)
				var big := 1.0 if r > 0.8 else (0.35 if r > 0.55 else 0.05)
				offs[i] = (r - 0.5) * 2.0 * 0.14 * k * big
			_screen_mat.set_shader_parameter("slice_offsets", offs)
			_screen_mat.set_shader_parameter("split", 0.012 * k)
		"crt":
			_screen.visible = k > 0.0
			_screen.size = size
			_screen_mat.set_shader_parameter("mode", 1)
			var off := MK.crt_off(k * 20.0, 0.0)
			_screen_mat.set_shader_parameter("squash", off.scale)
			_screen_mat.set_shader_parameter("bright", off.bright)
