# SPDX-License-Identifier: Apache-2.0
## A 3D world inside a composition. The stage renders its own World3D in an
## internal SubViewport and draws the result as part of the 2D piece, so type,
## shapes and effects can sit over (or under) real 3D. Everything in the world,
## the camera included, is set from the frame number like any other node:
## put nodes with `_frame(f)` under `world` and the composition reaches them.
##
##   var stage := MotionStage3D.new()
##   add_child(stage)
##   stage.world.add_child(my_track)
##   # in _frame(f):
##   stage.set_camera(MotionStage3D.path_frame(curve, s_at(f), 1.6), 62.0)
##
## Look: `environment` is a regular Environment (background, fog, glow).
## `unlit()` makes the kit's flat emissive material (vertex colour x energy,
## a light-chase threshold on UV2.x, environment fog), which renders cheaply
## and looks the same in Forward+ and Compatibility.
## `to_screen()` projects a world point into the composition's pixels, so 2D
## callouts can be pinned to 3D objects.
@tool
@icon("res://addons/motion_kit/icons/composition.svg")
class_name MotionStage3D
extends Node2D

const UNLIT := preload("res://addons/motion_kit/three/motion_unlit_3d.gdshader")

## Output size in the composition's pixels.
@export var size := Vector2(1920, 1080):
	set(v): size = v; _resize()
## Internal resolution multiplier (0.5 renders a quarter of the pixels).
@export_range(0.25, 2.0, 0.25) var render_scale := 1.0:
	set(v): render_scale = v; _resize()
## Multisample anti-aliasing for the 3D render.
@export var msaa := Viewport.MSAA_4X:
	set(v): msaa = v; if viewport: viewport.msaa_3d = v
## Transparent background: the 2D drawn before the stage shows through where
## nothing 3D was drawn (set the environment background to BG_CLEAR_COLOR too).
@export var transparent := false:
	set(v): transparent = v; if viewport: viewport.transparent_bg = v

## The internal render target.
var viewport: SubViewport
## Root of the 3D content.
var world: Node3D
var camera: Camera3D
var environment: Environment

var _view: Sprite2D


func _init() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = msaa
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport, false, Node.INTERNAL_MODE_FRONT)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = environment
	viewport.add_child(we)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.1
	camera.far = 4000.0
	viewport.add_child(camera)
	_view = Sprite2D.new()
	_view.centered = false
	_view.texture = viewport.get_texture()
	add_child(_view, false, Node.INTERNAL_MODE_FRONT)
	_resize()


func _ready() -> void:
	# Adopt 3D children authored under this node in a scene (not in the editor,
	# where nodes moved into an internal viewport would not be saved).
	if not Engine.is_editor_hint():
		for c in get_children():
			if c is Node3D:
				c.reparent(world, false)
	_resize()


func _resize() -> void:
	if not viewport:
		return
	var px := (size * render_scale).round()
	viewport.size = Vector2i(maxi(1, int(px.x)), maxi(1, int(px.y)))
	_view.scale = Vector2.ONE / render_scale


## Place the camera. `fov` is the vertical field of view in degrees.
func set_camera(xform: Transform3D, fov := 60.0) -> void:
	camera.transform = xform
	camera.fov = fov


## A camera transform at `from` looking at `to`, rolled by `roll` radians.
static func look(from: Vector3, to: Vector3, up := Vector3.UP, roll := 0.0) -> Transform3D:
	var b := Basis.looking_at(to - from, up)
	if roll != 0.0:
		b = b * Basis(Vector3.FORWARD, roll)
	return Transform3D(b, from)


## The frame of `curve` at distance `s`: origin on the curve (raised `height`
## along its up vector, moved `side` to the right), -Z along the direction of
## travel, Y the curve's up vector with its tilt applied (banking). Pure: the
## same s always gives the same transform.
static func path_frame(curve: Curve3D, s: float, height := 0.0, side := 0.0) -> Transform3D:
	var len := curve.get_baked_length()
	var s0 := clampf(s, 0.0, len)
	var p := curve.sample_baked(s0, true)
	var ahead := curve.sample_baked(minf(s0 + 0.5, len), true)
	var behind := curve.sample_baked(maxf(s0 - 0.5, 0.0), true)
	var fwd := (ahead - behind).normalized()
	if fwd == Vector3.ZERO:
		fwd = Vector3.FORWARD
	var up := curve.sample_baked_up_vector(s0, true)
	var b := Basis.looking_at(fwd, up)
	# beyond the ends, carry on straight
	var over := s - s0
	return Transform3D(b, p + fwd * over + b.y * height + b.x * side)


## A camera riding `curve`: at distance s, `height` above it, looking at the
## point `look_ahead` metres further on (also raised by `look_height`).
static func ride(curve: Curve3D, s: float, height := 1.5, look_ahead := 20.0, look_height := 1.0, side := 0.0) -> Transform3D:
	var here := path_frame(curve, s, height, side)
	var there := path_frame(curve, s + look_ahead, look_height, side)
	return Transform3D(Basis.looking_at(there.origin - here.origin, here.basis.y), here.origin)


## Blend two camera transforms (position lerp, rotation slerp).
static func blend(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	return Transform3D(Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), t)),
		a.origin.lerp(b.origin, t))


## Where a world point lands in the composition's pixels (the camera must
## already be placed for this frame).
func to_screen(p: Vector3) -> Vector2:
	return position + camera.unproject_position(p) / render_scale


## True when the point is in front of the camera.
func in_front(p: Vector3) -> bool:
	return not camera.is_position_behind(p)


## The kit's flat 3D material: vertex colour x tint x energy, on/off by UV2.x
## against `lit_to` (see motion_unlit_3d.gdshader).
static func unlit(tint := Color.WHITE, energy := 1.0, dim := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = UNLIT
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("dim", dim)
	return m


## Night look in one call: background, exponential fog and glow.
func night(sky: Color, fog: Color, fog_density := 0.006, glow := 0.9) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = sky
	environment.fog_enabled = fog_density > 0.0
	environment.fog_light_color = fog
	environment.fog_density = fog_density
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = glow > 0.0
	environment.glow_intensity = glow
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
