// SPDX-License-Identifier: Apache-2.0
// CSS-style gradients over a rectangle (MotionGradient, blend NORMAL).
shader_type canvas_item;

#include "res://addons/motion_kit/shaders/motion_gradient.gdshaderinc"

void fragment() {
	COLOR = gradient_colour() * COLOR;   // COLOR carries modulate and parent fades
}
