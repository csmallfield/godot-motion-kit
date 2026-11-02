// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: the cutout shader for one character (MotionFlat3D.actor):
// `flash`, `tint` and `opacity` are plain uniforms on a material the
// character owns, shared by all its parts and views, so a rig of any size
// takes no room in the global instance-uniform buffer.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 flash : source_color = vec4(0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;

#include "res://addons/motion_kit/three/motion_cutout_3d.gdshaderinc"
