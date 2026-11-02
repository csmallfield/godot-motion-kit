// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: motion_flat_3d_double.gdshader with per-instance `flash` and
// `tint` (see motion_flat_3d_instanced.gdshader).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#define MK_INSTANCED
#include "res://addons/motion_kit/three/motion_flat_3d_faces.gdshaderinc"
