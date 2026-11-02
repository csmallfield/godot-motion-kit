# SPDX-License-Identifier: Apache-2.0
## Tunables for MotionGait, as a Resource so a character's walk can be saved,
## shared and tweaked in the inspector. Distances in metres, times in seconds.
@tool
class_name MotionGaitSettings
extends Resource

@export_group("Feet")
## Half the distance between the feet, across the facing direction.
@export var hip_width := 0.06
## How far a planted foot may fall behind its home before it steps, at
## `reference_speed`. Scales with speed by `stride_speed_scale`.
@export var stride := 0.22
## 0 = the same stride at any speed, 1 = stride proportional to speed.
@export_range(0.0, 1.0) var stride_speed_scale := 0.45
## Speed the stride and step time are tuned for.
@export var reference_speed := 4.0
## Step duration standing still and at reference speed (and above).
@export var step_time := 0.2
@export var step_time_fast := 0.14
## Peak foot lift during a step.
@export var lift := 0.05
## Lift curve exponent (below 1: a quick lift and a long hang, above 1: a skim).
@export var lift_shape := 0.8
## Seconds of velocity ahead of the body each foot's home sits (and where a
## step aims, so the foot lands ahead of the body, not under it).
@export var lead := 0.06
@export_group("Settling")
## Standing still, feet further than this from home take a settling step.
@export var settle_distance := 0.03
## Seconds of standing still before settling steps.
@export var settle_delay := 0.12

@export_group("Body")
## Body dip on each plant (metres), and how fast it springs back.
@export var plant_dip := 0.012
@export var dip_stiffness := 260.0
@export var dip_damping := 18.0
## Rise of the body while a foot is in the air (metres at full lift).
@export var step_rise := 0.008
## Lean from acceleration (radians per m/s²) and from speed (radians per m/s),
## and its spring.
@export var lean_accel := 0.012
@export var lean_speed := 0.015
@export var lean_max := 0.22
@export var lean_stiffness := 120.0
@export var lean_damping := 14.0
