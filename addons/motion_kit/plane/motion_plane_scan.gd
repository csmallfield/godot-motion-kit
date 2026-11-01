# SPDX-License-Identifier: Apache-2.0
## A MotionPatternPlane with time displacement and slit-scan done in its
## shader: each pixel reads the plane at its own place or at a slit, and at its
## own moment, from a history of the plane's state. The checkerboard unrolls
## into 2001-style stargate walls (left and right of a vertical slit, above and
## below a horizontal one, or all four: a tunnel), shears in time, ripples, and
## splits into red, green and blue moments, all in one quad. It is the
## shader-side counterpart of MotionTimeSlices for planes: no instancing, no
## viewports, any number of "bands" (every pixel is one).
##
## Time: set `history_fn`, a pure function of the frame returning the plane's
## time-varying state as a Dictionary (keys, all optional: `offset` Vector2 =
## ground_offset, `cell` Vector2, `blur` Vector2 = motion_blur, `color_a`,
## `color_b`, `accent` Colors, `sun` float = sun size scale, `level` float),
## and call `capture(f)` in `_frame(f)`: the last `history` frames are sampled
## into a small float texture the shader interpolates. Everything else (camera,
## bends, fog, sky, ring) is shared by all times. Without `history_fn` every
## time shows the present (slit-scan of a still plane is just stretching).
##
## Space: `slit_at` is where the slit lines cross, in pixels. `scan` 0 keeps
## each pixel at its own place (pure time displacement, the delay growing with
## the distance from the slit line); 1 makes every pixel read the slit. `walls`
## 0 gives flat streaks (the slit stretched sideways, like MotionTimeSlices
## COLUMNS / ROWS with slit = 1); 1 bends them into perspective walls receding
## to `slit_at`, the delay growing toward the camera, so what crosses the slit
## now is born at the vanishing point and rushes outward.
##
##   var board := MotionPlaneScan.new()
##   board.history_fn = func(t: float) -> Dictionary: return {offset = Vector2(0, travel(t))}
##   func _frame(f): board.ground_offset.y = travel(f); board.scan = 1.0; board.walls = 1.0
##                   board.delay = 60.0; board.capture(f); board.sync_now()
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionPlaneScan
extends MotionPatternPlane

enum Axis {
	VERTICAL,    ## a vertical slit at slit_at.x: walls left and right
	HORIZONTAL,  ## a horizontal slit at slit_at.y: walls above and below
	TUNNEL,      ## both, split along the diagonals: four walls
}

const SCAN_SHADER := preload("res://addons/motion_kit/plane/motion_plane_scan.gdshader")

@export_group("Scan")
## 0 = each pixel at its own place (time displacement only), 1 = every pixel reads the slit.
@export_range(0.0, 1.0) var scan := 0.0:
	set(v): scan = v; _dirty()
@export var axis := Axis.VERTICAL:
	set(v): axis = v; _dirty()
## Where the slit lines cross (pixels); the vanishing point of the walls.
@export var slit_at := Vector2(960, 540):
	set(v): slit_at = v; _dirty()
## 0 = flat streaks, 1 = perspective walls.
@export_range(0.0, 1.0) var walls := 0.0:
	set(v): walls = v; _dirty()
## Distance from the slit (pixels) where a wall shows the slit 1:1 (vertical walls, horizontal walls).
## Half the frame makes the four TUNNEL walls tile the frame exactly.
@export var wall_ref := Vector2(960, 540):
	set(v): wall_ref = v; _dirty()
## Walls: pixels from the slit where the delay starts (the far end of the corridor); it
## grows with the log of the distance and is full at `wall_ref`.
@export var wall_near := 24.0:
	set(v): wall_near = v; _dirty()
## Flat: distance from the slit line (pixels) where the delay reaches its full share.
@export var delay_span := Vector2(960, 540):
	set(v): delay_span = v; _dirty()
@export_group("Delay")
## Frames back at the full share (keep below `history`).
@export var delay := 0.0:
	set(v): delay = v; _dirty()
## The share grows as u ^ curve (u = 0 at the slit, 1 at the span or near the camera).
@export var delay_curve := 1.0:
	set(v): delay_curve = v; _dirty()
## Quantise the delay to steps of this many frames (a stutter; 0 = smooth).
@export var delay_step := 0.0:
	set(v): delay_step = v; _dirty()
## Adds amplitude * sin(2 pi (waves * u - phase)) to the share: a time ripple.
@export var ripple := Vector3(0.0, 1.0, 0.0):
	set(v): ripple = v; _dirty()
## RGB time split: green lags `split` frames more than red, blue twice as much (0 = off; costs 3x).
@export var split := 0.0:
	set(v): split = v; _dirty()
## Walls: how much the parts whose source leaves the frame go to `gap_color`.
@export_range(0.0, 1.0) var gap := 1.0:
	set(v): gap = v; _dirty()
@export var gap_color := Color.BLACK:
	set(v): gap_color = v; _dirty()
## Frames of history kept (the longest delay the shader can show).
@export_range(2, 1024) var history := 96

## (frame: float) -> Dictionary of the plane's state at that frame. Must be pure.
var history_fn: Callable

var _hist_img: Image
var _hist_tex: ImageTexture
var _hist_len := 0


## Sample the state history for frame f (call it in `_frame`, before `sync_now()`).
func capture(f: float) -> void:
	if not history_fn.is_valid():
		_hist_len = 0
		_dirty()
		return
	var n := maxi(2, history)
	if _hist_img == null or _hist_img.get_width() != n:
		_hist_img = Image.create(n, 5, false, Image.FORMAT_RGBAF)
		_hist_tex = null
	for i in n:
		var d: Dictionary = history_fn.call(f - i)
		var off: Vector2 = d.get("offset", ground_offset)
		var c: Vector2 = d.get("cell", cell)
		var b: Vector2 = d.get("blur", motion_blur)
		var sun: float = d.get("sun", 1.0)
		var lv: float = d.get("level", 1.0)
		_hist_img.set_pixel(i, 0, Color(off.x, off.y, c.x, c.y))
		_hist_img.set_pixel(i, 1, Color(b.x, b.y, sun, lv))
		_hist_img.set_pixel(i, 2, d.get("color_a", color_a))
		_hist_img.set_pixel(i, 3, d.get("color_b", color_b))
		_hist_img.set_pixel(i, 4, d.get("accent", accent_color))
	if _hist_tex == null:
		_hist_tex = ImageTexture.create_from_image(_hist_img)
	else:
		_hist_tex.update(_hist_img)
	_hist_len = n
	_dirty()


## The frames back a pixel reads (the shader's delay function), for placing
## things in step with the scan (e.g. a 2D layer that should streak the same way).
func delay_at(px: Vector2) -> float:
	var s := px - slit_at
	var vert := axis == Axis.VERTICAL
	if axis == Axis.TUNNEL:
		vert = absf(s.x) / maxf(wall_ref.x, 1.0) > absf(s.y) / maxf(wall_ref.y, 1.0)
	var a := maxf(absf(s.x if vert else s.y), 1e-3)
	var u_flat := clampf(a / maxf(delay_span.x if vert else delay_span.y, 1.0), 0.0, 1.0)
	var ref := wall_ref.x if vert else wall_ref.y
	var u_wall := clampf(log(a / wall_near) / log(maxf(ref / wall_near, 1.001)), 0.0, 1.0)
	var u := lerpf(u_flat, u_wall, walls)
	var back := delay * (pow(u, delay_curve) + ripple.x * sin(TAU * (ripple.y * u - ripple.z)))
	if delay_step > 0.0:
		back = floorf(back / delay_step + 0.5) * delay_step
	return maxf(back, 0.0)


func _sync() -> void:
	if _mat == null:
		return
	if _mat.shader != SCAN_SHADER:
		_mat.shader = SCAN_SHADER
	super._sync()
	var m := _mat
	m.set_shader_parameter("history_len", _hist_len)
	if _hist_tex:
		m.set_shader_parameter("history", _hist_tex)
	m.set_shader_parameter("scan", scan)
	m.set_shader_parameter("scan_axis", int(axis))
	m.set_shader_parameter("slit_at", slit_at)
	m.set_shader_parameter("walls", walls)
	m.set_shader_parameter("wall_ref", wall_ref)
	m.set_shader_parameter("wall_near", wall_near)
	m.set_shader_parameter("delay_span", delay_span)
	m.set_shader_parameter("delay", delay)
	m.set_shader_parameter("delay_curve", delay_curve)
	m.set_shader_parameter("delay_step", delay_step)
	m.set_shader_parameter("ripple", ripple)
	m.set_shader_parameter("split", split)
	m.set_shader_parameter("gap", gap)
	m.set_shader_parameter("gap_color", gap_color)
