# SPDX-License-Identifier: Apache-2.0
## A sky for MotionStage3D worlds: a gradient with a banded OutRun sun fixed
## in the world, drawn on a big sphere that follows the camera. Same controls
## as MotionPatternPlane's sky and sun, so a 3D take and a pattern-plane take
## can share one look (and a sun direction).
##
##   var sky := MotionSkyDome3D.new()
##   stage.world.add_child(sky)
##   sky.sun_size = 10.0
##   sky.fog_to(stage.environment)      # fog colour = horizon colour
##   # in _frame(f), after placing the camera:
##   sky.follow(stage.camera)
##   sky.sun_elevation = lerpf(3.0, -12.0, sink)
##
## Directions: azimuth 0 looks down -Z (Godot's forward), positive turns
## right (towards +X); elevation is degrees above the horizon.
## The dome's radius must stay inside the camera's far plane (stage cameras
## use 4000). Below the horizon it shows the horizon colour; the ground hides
## it anyway, and `horizon_cut` sinks the sun behind the horizon line.
@tool
@icon("res://addons/motion_kit/icons/three.svg")
class_name MotionSkyDome3D
extends MeshInstance3D

const SHADER := preload("res://addons/motion_kit/three/motion_sky_dome_3d.gdshader")

@export var radius := 3500.0:
	set(v): radius = v; _mesh()
@export var sky_top := Color.BLACK:
	set(v): sky_top = v; _param("sky_top", v)
@export var sky_horizon := Color(0.2, 0.0, 0.2):
	set(v): sky_horizon = v; _param("sky_horizon", v)
## Elevation (sine) where the sky reaches sky_top.
@export var sky_spread := 0.5:
	set(v): sky_spread = v; _param("sky_spread", v)
## Gradient exponent: above 1 keeps the horizon glow low.
@export var sky_curve := 1.0:
	set(v): sky_curve = v; _param("sky_curve", v)
@export var sun_elevation := 4.0:
	set(v): sun_elevation = v; _sun()
@export var sun_azimuth := 0.0:
	set(v): sun_azimuth = v; _sun()
## Angular radius in degrees; 0 hides the sun.
@export var sun_size := 0.0:
	set(v): sun_size = v; _param("sun_size", deg_to_rad(v))
@export var sun_top := Color(1.0, 0.9, 0.3):
	set(v): sun_top = v; _param("sun_top", v)
@export var sun_bottom := Color(1.0, 0.1, 0.5):
	set(v): sun_bottom = v; _param("sun_bottom", v)
## Band count, scroll, top of the banded area (-1 bottom .. 1 top of the disc).
@export var sun_bands := Vector3(7.0, 0.0, 0.25):
	set(v): sun_bands = v; _param("sun_bands", v)
@export var sun_glow := 0.3:
	set(v): sun_glow = v; _param("sun_glow", v)
## Above 1 feeds the environment's glow.
@export var sun_energy := 1.0:
	set(v): sun_energy = v; _param("sun_energy", v)
## 1 hides the part of the sun below the horizon (a sinking sun).
@export var horizon_cut := 1.0:
	set(v): horizon_cut = v; _param("horizon_cut", v)
## Multiplies everything (fade the sky to black).
@export var level := 1.0:
	set(v): level = v; _param("level", v)

var _mat: ShaderMaterial


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = -100
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	_mesh()
	for p in ["sky_top", "sky_horizon", "sky_spread", "sky_curve", "sun_top", "sun_bottom", "sun_bands", "sun_glow", "sun_energy", "horizon_cut", "level"]:
		_param(p, get(p))
	_param("sun_size", deg_to_rad(sun_size))
	_sun()


func _param(p: String, v: Variant) -> void:
	if _mat:
		_mat.set_shader_parameter(p, v)


func _mesh() -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 64
	s.rings = 32
	mesh = s


func _sun() -> void:
	if _mat:
		_mat.set_shader_parameter("sun_dir", sun_direction())


## Unit vector towards the sun (use it for a floor's sheen_dir).
func sun_direction() -> Vector3:
	var el := deg_to_rad(sun_elevation)
	var az := deg_to_rad(sun_azimuth)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


## Centre the dome on the camera (call after placing it each frame).
func follow(cam: Node3D) -> void:
	position = cam.global_position if cam.is_inside_tree() else cam.position


## Make the environment's fog the horizon colour, so fogged ground meets the
## sky without a seam.
func fog_to(env: Environment) -> void:
	env.fog_light_color = sky_horizon
