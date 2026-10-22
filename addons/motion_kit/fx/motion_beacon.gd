# SPDX-License-Identifier: Apache-2.0
## A rotating beacon: light beams turning about a lamp, with a lens glow and an
## anamorphic streak that flare each time a beam swings towards the viewer.
## Drawn as one additive quad over `size`, so the beams light whatever is under
## them (type, logos, a wall of hazard tape) as they sweep past.
##
## Set `angle` from the frame (MotionBeacon.spin(f, period)) for a beacon
## turning at a fixed rate. `beams` 2 is the classic rotating warning light;
## 1 a searchlight; 3–4 a lighthouse cluster. `squash` < 1 flattens the beam
## field vertically, as if the lamp threw its light onto a floor or wall.
##
## Photosensitivity: a sweep is motion, not a flash; keep the lens flare (once
## per beam per turn) under 3 a second when the flare is large.
@tool
@icon("res://addons/motion_kit/icons/fx.svg")
class_name MotionBeacon
extends Node2D

enum Blend { ADD, MIX }

## The area the light may reach (origin top-left), usually the frame.
@export var size := Vector2(1920, 1080):
	set(v): size = v; queue_redraw()
## The lamp, in this node's space.
@export var centre := Vector2(960, 540)
## Direction of the first beam, radians (0 = +x, PI/2 = down the screen).
@export var angle := 0.0
@export_range(1, 4) var beams := 2
## Half-angle of each beam in degrees, and how much of it is soft edge (0..1).
@export var beam_width := 12.0
@export_range(0.0, 1.0) var softness := 0.7
## Beam width at the lamp in px (beams start as wide as the lens, not a point).
@export var lens := 22.0
## How far the beams reach (px) and how fast they fade with distance (power).
@export var reach := 1800.0
@export var falloff := 1.4
@export var color := Color(1.0, 0.68, 0.1)
## Brightness of the beams.
@export var intensity := 0.55
## Lens glow radius (px) and brightness; it brightens as a beam faces `flare_dir`.
@export var core := 26.0
@export var core_intensity := 1.2
## The direction that counts as "towards the viewer" (radians), and how
## tightly the flare peaks around it (power of the cosine).
@export var flare_dir := PI * 0.5
@export var flare_power := 8.0
## Horizontal lens streak: half-length in px, brightness.
@export var streak := 380.0
@export var streak_intensity := 0.7
## Vertical scale of the beam field: 1 = round; 0.4 = beams thrown across a floor.
@export var squash := 1.0
## Overall level, 0 switches the beacon off (and stops drawing it).
@export var level := 1.0
@export var blend := Blend.ADD:
	set(v): blend = v; _mat = null; queue_redraw()

static var _shaders := {}
var _mat: ShaderMaterial


## Beam angle for a beacon turning once every `period` frames.
static func spin(f: float, period: float, phase := 0.0, direction := 1.0) -> float:
	return direction * TAU * f / maxf(period, 0.001) + phase


static func _shader(mode: int) -> Shader:
	if not _shaders.has(mode):
		var sh := Shader.new()
		sh.code = SHADER.replace("BLEND_MODE", "blend_add" if mode == Blend.ADD else "blend_mix")
		_shaders[mode] = sh
	return _shaders[mode]


func _frame(_f: float) -> void:
	_apply()


func _process(_d: float) -> void:
	if Engine.is_editor_hint():
		_apply()


func _apply() -> void:
	visible = level > 0.0
	if not visible:
		return
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = MotionBeacon._shader(blend)
		material = _mat
	_mat.set_shader_parameter("centre", centre)
	_mat.set_shader_parameter("angle", angle)
	_mat.set_shader_parameter("beams", beams)
	_mat.set_shader_parameter("beam_width", deg_to_rad(beam_width))
	_mat.set_shader_parameter("softness", softness)
	_mat.set_shader_parameter("lens", lens)
	_mat.set_shader_parameter("reach", reach)
	_mat.set_shader_parameter("falloff", falloff)
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("intensity", intensity * level)
	_mat.set_shader_parameter("core", core)
	_mat.set_shader_parameter("core_intensity", core_intensity * level)
	_mat.set_shader_parameter("flare_dir", flare_dir)
	_mat.set_shader_parameter("flare_power", flare_power)
	_mat.set_shader_parameter("streak", streak)
	_mat.set_shader_parameter("streak_intensity", streak_intensity * level)
	_mat.set_shader_parameter("squash", maxf(squash, 0.01))
	_mat.set_shader_parameter("additive", blend == Blend.ADD)
	queue_redraw()


func _draw() -> void:
	if _mat == null:
		_apply()
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


const SHADER := """
shader_type canvas_item;
render_mode BLEND_MODE, unshaded;

uniform vec2 centre;
uniform float angle;
uniform int beams = 2;
uniform float beam_width = 0.2;
uniform float softness = 0.7;
uniform float lens = 22.0;
uniform float reach = 1800.0;
uniform float falloff = 1.4;
uniform vec4 color : source_color = vec4(1.0, 0.68, 0.1, 1.0);
uniform float intensity = 0.55;
uniform float core = 26.0;
uniform float core_intensity = 1.2;
uniform float flare_dir = 1.5708;
uniform float flare_power = 8.0;
uniform float streak = 380.0;
uniform float streak_intensity = 0.7;
uniform float squash = 1.0;
uniform bool additive = true;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 dd = local - centre;
	vec2 d = vec2(dd.x, dd.y / squash);
	float r = length(d);
	float a = atan(d.y, d.x);
	float b = 0.0;
	float face = 0.0;
	for (int k = 0; k < 4; k++) {
		if (k >= beams) {
			break;
		}
		float ak = angle + float(k) * 6.2831853 / float(beams);
		float diff = abs(mod(a - ak + 3.14159265, 6.2831853) - 3.14159265);
		float w = beam_width + atan(lens, max(r, 1.0));
		b = max(b, 1.0 - smoothstep(w * (1.0 - softness), w, diff));
		face = max(face, pow(max(cos(ak - flare_dir), 0.0), flare_power));
	}
	float fall = pow(clamp(1.0 - r / reach, 0.0, 1.0), falloff);
	float light = b * fall * intensity;
	float rr = length(dd);
	float glow = exp(-(rr * rr) / (core * core)) * core_intensity * (0.4 + 0.6 * face);
	float halo = exp(-rr / (core * 3.0)) * 0.35 * face * core_intensity;
	float st = exp(-abs(dd.x) / max(streak, 1.0)) * exp(-(dd.y * dd.y) / 18.0) * face * streak_intensity;
	float v = light + glow + halo + st;
	vec3 c = color.rgb * v + vec3(1.0) * glow * 0.6;
	COLOR = additive ? vec4(c, 1.0) : vec4(c / max(v, 1e-4), clamp(v, 0.0, 1.0));
}
"""
