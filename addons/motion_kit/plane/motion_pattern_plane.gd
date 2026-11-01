# SPDX-License-Identifier: Apache-2.0
## An infinite patterned ground plane (checker, stripes, grid, dots or a
## texture) seen through a pinhole camera, ray-cast per pixel in one quad,
## with a sky, an OutRun-style banded sun and an optional patterned ceiling.
## OutRun roads, demoscene checkerboards, op-art floors, Tron grids.
##
## Camera space: x right, y up, z forward; the camera sits at the origin
## `height` above the ground. `ground_offset` (lateral, travel) scrolls the
## pattern, so flying forward is just `ground_offset.y = distance(f)`.
## The ground can bend: `curve` (the road turns: lateral shift curve * z^2),
## `channel` (the sides curl up: y += channel * x^2, a half-pipe that becomes a
## tube), `hill` (the ground ahead folds up into a wall: y += hill * z^2) and
## `wave` (a sideways ripple). Every ray is intersected analytically and the
## pattern is box-filtered, so there is no moire at the horizon.
##
## `clip` keeps only surfaces whose forward distance lies in [x, y): draw the
## plane twice, a full layer behind and a `clip.y = D` layer with
## `draw_sky = false` in front, and anything drawn between them at distance D
## (a sign, a logo) is hidden where it goes below the ground: it rises out of
## the floor. Give the front layer `clip = (-1e9, D)` and no ceiling. `project()`, `ground_point()` and `draw_checker_quad()` use the
## same camera and bends, so 2D nodes and canvas-drawn boxes sit on the plane.
##
##   var floor := MotionPatternPlane.new()
##   floor.color_a = Color.WHITE; floor.color_b = Color.BLACK
##   func _frame(f): floor.ground_offset.y = f * 1.5; floor.curve = 0.0004 * sin(f / 40.0)
@tool
@icon("res://addons/motion_kit/icons/shape.svg")
class_name MotionPatternPlane
extends Node2D

enum Pattern { CHECKER, STRIPES, GRID, DOTS, TEXTURE }

const SHADER := preload("res://addons/motion_kit/plane/motion_pattern_plane.gdshader")

@export var size := Vector2(1920, 1080):
	set(v): size = v; _dirty()
@export_group("Camera")
## Vertical field of view in degrees (sets `focal` from `size.y`).
@export_range(10.0, 160.0) var fov := 70.0:
	set(v): fov = v; _dirty()
## Principal point as a fraction of the size (0.5, 0.5 = centred).
@export var principal := Vector2(0.5, 0.5):
	set(v): principal = v; _dirty()
@export var pitch := 0.0:   ## degrees, positive looks up
	set(v): pitch = v; _dirty()
@export var yaw := 0.0:     ## degrees, positive turns right
	set(v): yaw = v; _dirty()
@export var roll := 0.0:    ## degrees, positive rolls clockwise on screen
	set(v): roll = v; _dirty()
@export var height := 2.0:
	set(v): height = v; _dirty()
## Lateral offset and travel distance of the pattern, in world units.
@export var ground_offset := Vector2.ZERO:
	set(v): ground_offset = v; _dirty()
@export_group("Bends")
@export var curve := 0.0:
	set(v): curve = v; _dirty()
@export var channel := 0.0:
	set(v): channel = v; _dirty()
@export var hill := 0.0:
	set(v): hill = v; _dirty()
## Sideways ripple: amplitude (units), frequency (radians per unit of z), phase.
@export var wave := Vector3(0.0, 0.2, 0.0):
	set(v): wave = v; _dirty()
@export_group("Pattern")
@export var pattern := Pattern.CHECKER:
	set(v): pattern = v; _dirty()
## Cell size in world units. Animate it to pulse the pattern about the camera;
## `cell_scroll` is the size the offsets scroll at, so travel speed is unchanged.
@export var cell := Vector2(2.0, 2.0):
	set(v): cell = v; _dirty()
@export var cell_scroll := Vector2(2.0, 2.0):
	set(v): cell_scroll = v; _dirty()
@export var pattern_shift := Vector2.ZERO:   ## in cells
	set(v): pattern_shift = v; _dirty()
## Analytic motion blur: how far the pattern moves while the shutter is open,
## in cells (x lateral, y travel). The box filter widens by it, so fast travel
## smears the pattern along the motion instead of strobing (a 180 degree
## shutter is half the per-frame movement: `motion_blur_for()`).
@export var motion_blur := Vector2.ZERO:
	set(v): motion_blur = v; _dirty()
@export var color_a := Color.WHITE:
	set(v): color_a = v; _dirty()
@export var color_b := Color.BLACK:
	set(v): color_b = v; _dirty()
@export var line_width := 0.08:   ## GRID line width / DOTS radius, as a fraction of a cell
	set(v): line_width = v; _dirty()
@export var texture: Texture2D:
	set(v): texture = v; _dirty()
@export var accent_color := Color(1, 1, 1, 0):
	set(v): accent_color = v; _dirty()
## A coloured lane every n cells (0 = none), `accent_width` cells wide.
@export var accent_every := 0.0:
	set(v): accent_every = v; _dirty()
@export var accent_width := 1.0:
	set(v): accent_width = v; _dirty()
@export_group("Fog")
@export var fog_color := Color.BLACK:
	set(v): fog_color = v; _dirty()
## Distance where fog starts and where it is total.
@export var fog_range := Vector2(40.0, 300.0):
	set(v): fog_range = v; _dirty()
@export_group("Ceiling")
@export var ceiling := false:
	set(v): ceiling = v; _dirty()
@export var ceiling_height := 12.0:
	set(v): ceiling_height = v; _dirty()
@export var ceiling_a := Color.WHITE:
	set(v): ceiling_a = v; _dirty()
@export var ceiling_b := Color.BLACK:
	set(v): ceiling_b = v; _dirty()
@export_range(0.0, 1.0) var ceiling_alpha := 1.0:
	set(v): ceiling_alpha = v; _dirty()
@export_group("Sky")
@export var draw_sky := true:
	set(v): draw_sky = v; _dirty()
@export var sky_top := Color.BLACK:
	set(v): sky_top = v; _dirty()
@export var sky_horizon := Color(0.2, 0.0, 0.2):
	set(v): sky_horizon = v; _dirty()
## Sine of the elevation where the sky reaches `sky_top`.
@export var sky_spread := 0.5:
	set(v): sky_spread = v; _dirty()
## Sun: direction in world space (elevation in degrees, azimuth in degrees),
## angular radius in degrees (0 = none).
@export var sun_elevation := 6.0:
	set(v): sun_elevation = v; _dirty()
@export var sun_azimuth := 0.0:
	set(v): sun_azimuth = v; _dirty()
@export var sun_size := 0.0:
	set(v): sun_size = v; _dirty()
@export var sun_top := Color(1.0, 0.9, 0.3):
	set(v): sun_top = v; _dirty()
@export var sun_bottom := Color(1.0, 0.1, 0.5):
	set(v): sun_bottom = v; _dirty()
## Bands cut across the sun: count, scroll (0..1 cycles), top of the banded area (-1..1).
@export var sun_bands := Vector3(7.0, 0.0, 0.25):
	set(v): sun_bands = v; _dirty()
@export var sun_glow := 0.3:
	set(v): sun_glow = v; _dirty()
@export_group("Layer")
## Forward-distance window of surfaces drawn: [x, y). See the class notes.
@export var clip := Vector2(-1e9, 1e9):
	set(v): clip = v; _dirty()
@export_group("Ring")
## A ring on the ground: centre (camera-relative x, z), radius (< 0 = off), width.
@export var ring := Vector4(0, 0, -1, 2):
	set(v): ring = v; _dirty()
@export var ring_color := Color(1, 1, 1, 0):
	set(v): ring_color = v; _dirty()
## Pattern displacement at the ring, in cells (a shockwave through the floor).
@export var ring_push := 0.0:
	set(v): ring_push = v; _dirty()
@export_group("")
## Multiplies the colour: 0 is black (fade out without transparency).
@export var level := 1.0:
	set(v): level = v; _dirty()
@export_range(0.0, 1.0) var opacity := 1.0:
	set(v): opacity = v; _dirty()

var _mat: ShaderMaterial
var _queued := false


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_sync()


func _validate_property(property: Dictionary) -> void:
	if property.name == "material":
		property.usage = PROPERTY_USAGE_NONE


func _dirty() -> void:
	# Many properties change per frame: push the uniforms once, before drawing.
	if not _queued and is_inside_tree():
		_queued = true
		_sync.call_deferred()
	elif not is_inside_tree():
		_sync()


## Copy every setting from another plane (a front layer mirrors the back one).
func copy_from(o: MotionPatternPlane) -> void:
	for p in ["size", "fov", "principal", "pitch", "yaw", "roll", "height", "ground_offset", "curve", "channel", "hill",
			"wave", "pattern", "cell", "cell_scroll", "pattern_shift", "motion_blur", "color_a", "color_b", "line_width", "texture",
			"accent_color", "accent_every", "accent_width", "fog_color", "fog_range", "ceiling", "ceiling_height",
			"ceiling_a", "ceiling_b", "ceiling_alpha", "sky_top", "sky_horizon", "sky_spread", "sun_elevation",
			"sun_azimuth", "sun_size", "sun_top", "sun_bottom", "sun_bands", "sun_glow", "ring", "ring_color",
			"ring_push", "level", "opacity"]:
		set(p, o.get(p))


## The motion blur for a per-frame movement of the offsets (world units) with
## a shutter of `shutter` (0.5 = 180 degrees).
func motion_blur_for(per_frame: Vector2, shutter := 0.5) -> Vector2:
	return (per_frame / cell_scroll).abs() * shutter


func focal() -> float:
	return size.y * 0.5 / tan(deg_to_rad(fov) * 0.5)


func centre() -> Vector2:
	return size * principal


func sync_now() -> void:
	_sync()


func _sync() -> void:
	_queued = false
	if not _mat:
		return
	var sd := Vector3(sin(deg_to_rad(sun_azimuth)) * cos(deg_to_rad(sun_elevation)), sin(deg_to_rad(sun_elevation)),
		cos(deg_to_rad(sun_azimuth)) * cos(deg_to_rad(sun_elevation)))
	var m := _mat
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("centre", centre())
	m.set_shader_parameter("focal", focal())
	m.set_shader_parameter("cam_rot", Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("ground_offset", ground_offset)
	m.set_shader_parameter("curve", curve)
	m.set_shader_parameter("channel", channel)
	m.set_shader_parameter("hill", hill)
	m.set_shader_parameter("wave", wave)
	m.set_shader_parameter("pattern", int(pattern))
	m.set_shader_parameter("cell", cell)
	m.set_shader_parameter("cell_scroll", cell_scroll)
	m.set_shader_parameter("pattern_shift", pattern_shift)
	m.set_shader_parameter("motion_blur", motion_blur)
	m.set_shader_parameter("color_a", color_a)
	m.set_shader_parameter("color_b", color_b)
	m.set_shader_parameter("line_width", line_width)
	if texture:
		m.set_shader_parameter("pattern_texture", texture)
	m.set_shader_parameter("accent_color", accent_color)
	m.set_shader_parameter("accent_every", accent_every)
	m.set_shader_parameter("accent_width", accent_width)
	m.set_shader_parameter("fog_color", fog_color)
	m.set_shader_parameter("fog_range", fog_range)
	m.set_shader_parameter("ceiling", ceiling)
	m.set_shader_parameter("ceiling_height", ceiling_height)
	m.set_shader_parameter("ceiling_a", ceiling_a)
	m.set_shader_parameter("ceiling_b", ceiling_b)
	m.set_shader_parameter("ceiling_alpha", ceiling_alpha)
	m.set_shader_parameter("draw_sky", draw_sky)
	m.set_shader_parameter("sky_top", sky_top)
	m.set_shader_parameter("sky_horizon", sky_horizon)
	m.set_shader_parameter("sky_spread", sky_spread)
	m.set_shader_parameter("sun_dir", sd)
	m.set_shader_parameter("sun_size", deg_to_rad(sun_size))
	m.set_shader_parameter("sun_top", sun_top)
	m.set_shader_parameter("sun_bottom", sun_bottom)
	m.set_shader_parameter("sun_bands", sun_bands)
	m.set_shader_parameter("sun_glow", sun_glow)
	m.set_shader_parameter("clip", clip)
	m.set_shader_parameter("ring", ring)
	m.set_shader_parameter("ring_color", ring_color)
	m.set_shader_parameter("ring_push", ring_push)
	m.set_shader_parameter("level", level)
	m.set_shader_parameter("opacity", opacity)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


# ------------------------------------------------------------------ geometry
# The same camera and bends as the shader, for things that sit on the plane.

## World (camera-relative, unrotated) direction -> camera space.
func to_camera(p: Vector3) -> Vector3:
	var cy := cos(deg_to_rad(yaw))
	var sy := sin(deg_to_rad(yaw))
	p = Vector3(p.x * cy - p.z * sy, p.y, p.x * sy + p.z * cy)
	var cp := cos(deg_to_rad(pitch))
	var sp := sin(deg_to_rad(pitch))
	p = Vector3(p.x, p.y * cp - p.z * sp, p.y * sp + p.z * cp)
	var cr := cos(deg_to_rad(roll))
	var sr := sin(deg_to_rad(roll))
	return Vector3(p.x * cr + p.y * sr, -p.x * sr + p.y * cr, p.z)


## Camera-relative world point -> (screen x, screen y, camera depth). Depth <= 0
## means behind the camera; the screen position is then meaningless.
func project(p: Vector3) -> Vector3:
	var c := to_camera(p)
	if c.z <= 1e-4:
		return Vector3(0, 0, c.z)
	var f := focal()
	var cc := centre()
	return Vector3(cc.x + f * c.x / c.z, cc.y - f * c.y / c.z, c.z)


## Screen pixels per world unit for something facing the camera at depth z.
func scale_at(depth: float) -> float:
	return focal() / maxf(depth, 1e-4)


## Height of the ground at a camera-relative point.
func ground_y(x: float, z: float) -> float:
	return -height + channel * x * x + hill * z * z


## The camera-relative point on the ground for a pattern-space position:
## lateral `gx` (pattern x, before the road curve) at forward distance `z`,
## `up` above the ground. Follows `curve`, `channel` and `hill` (not `wave`).
func ground_point(gx: float, z: float, up := 0.0) -> Vector3:
	var x := gx + curve * z * z
	return Vector3(x, ground_y(x, z) + up, z)


## The camera-relative forward distance of an absolute travel position.
func rel_z(world_z: float) -> float:
	return world_z - ground_offset.y


## Fog amount (0..1) at a distance, as the shader computes it.
func fog_at(dist: float) -> float:
	return smoothstep(fog_range.x, fog_range.y, dist)


## Draw a planar quad of camera-relative corners (a, b, c, d in order, a->b
## along the columns, a->d along the rows) as a checkerboard into a canvas,
## projected vertex by vertex so it stays perspective-correct. `tint` 0..1
## mixes toward the fog colour by distance. Cells smaller than `min_px` on
## screen fall back to one flat polygon in the average colour.
func draw_checker_quad(c: MotionCanvas, a: Vector3, b: Vector3, cc: Vector3, d: Vector3, cols: int, rows: int,
		col_a: Color, col_b: Color, min_px := 5.0, near := 0.6) -> void:
	if maxf(maxf(a.z, b.z), maxf(cc.z, d.z)) <= near:
		return
	# clip the quad against the near plane along its rows (a->d, b->c share z
	# for vertical faces; for receding faces clip by columns)
	var dist := (a + cc) * 0.5
	var fog := fog_at(dist.length())
	var fa := col_a.lerp(fog_color, fog)
	var fb := col_b.lerp(fog_color, fog)
	var pa := project(a)
	var pb := project(b)
	var pc := project(cc)
	var pd := project(d)
	var all_front := pa.z > near and pb.z > near and pc.z > near and pd.z > near
	if not all_front:
		# A receding face crossing the near plane: shorten it along a->b (and
		# d->c) to where it reaches the plane. Clip by camera depth, which is
		# affine in world position, so this is exact for any camera pitch, yaw
		# or roll. (Clipping by world z looped forever with a rotated camera.)
		var nz := near + 0.05
		var aa := a
		var bb := b
		var c2 := cc
		var dd := d
		var ka := 0.0
		var kb := 0.0
		if pa.z < nz and pb.z > nz:
			ka = (nz - pa.z) / (pb.z - pa.z)
		elif pb.z < nz and pa.z > nz:
			kb = (nz - pb.z) / (pa.z - pb.z)
		else:
			return
		var kd := 0.0
		var kc := 0.0
		if pd.z < nz and pc.z > nz:
			kd = (nz - pd.z) / (pc.z - pd.z)
		elif pc.z < nz and pd.z > nz:
			kc = (nz - pc.z) / (pd.z - pc.z)
		elif minf(pd.z, pc.z) < nz:
			return
		aa = a.lerp(b, ka)
		bb = b.lerp(a, kb)
		dd = d.lerp(cc, kd)
		c2 = cc.lerp(d, kc)
		cols = maxi(1, int(round(cols * (1.0 - maxf(maxf(ka, kb), maxf(kc, kd))))))
		# Every corner is now at or beyond the plane, so this recursion
		# takes the all-front path; the depth guard only absorbs rounding.
		if minf(minf(project(aa).z, project(bb).z), minf(project(c2).z, project(dd).z)) < near:
			return
		draw_checker_quad(c, aa, bb, c2, dd, cols, rows, col_a, col_b, min_px, near)
		return
	var poly := PackedVector2Array([Vector2(pa.x, pa.y), Vector2(pb.x, pb.y), Vector2(pc.x, pc.y), Vector2(pd.x, pd.y)])
	var w_px := maxf(Vector2(pa.x, pa.y).distance_to(Vector2(pb.x, pb.y)), Vector2(pd.x, pd.y).distance_to(Vector2(pc.x, pc.y)))
	var h_px := maxf(Vector2(pa.x, pa.y).distance_to(Vector2(pd.x, pd.y)), Vector2(pb.x, pb.y).distance_to(Vector2(pc.x, pc.y)))
	if w_px < 0.5 or h_px < 0.5:
		return
	var cell_px := minf(w_px / cols, h_px / rows)
	# Projected planar faces in front of the camera are convex: draw them
	# directly (no triangulation check, which costs more than the draw).
	if cell_px < min_px:
		c.draw_colored_polygon(poly, fa.lerp(fb, 0.5))
		return
	c.draw_colored_polygon(poly, fa)
	# project the grid once, then fill the B cells
	var grid := PackedVector2Array()
	grid.resize((cols + 1) * (rows + 1))
	for j in rows + 1:
		var v := float(j) / rows
		var left := a.lerp(d, v)
		var right := b.lerp(cc, v)
		for i in cols + 1:
			var q := project(left.lerp(right, float(i) / cols))
			grid[j * (cols + 1) + i] = Vector2(q.x, q.y)
	for j in rows:
		for i in cols:
			if (i + j) % 2 == 1:
				continue
			var k0 := j * (cols + 1) + i
			c.draw_colored_polygon(PackedVector2Array([grid[k0], grid[k0 + 1], grid[k0 + cols + 2], grid[k0 + cols + 1]]), fb)
