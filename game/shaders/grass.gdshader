shader_type spatial;
render_mode specular_disabled, cull_disabled;
// Grass tufts: per-instance tint (INSTANCE_CUSTOM.rgb) matches the ground under
// them; blades darken at the base and bleach at the tips; wind sways the tips.

#include "res://shaders/pixel_light.gdshaderinc"

uniform float wind_strength = 0.1;
varying vec3 tint;
varying float tip;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	tip = clamp(h / 0.45, 0.0, 1.0);
	float sway = sin(TIME * 1.6 + wp.x * 0.31 + wp.z * 0.19) * 0.65 + sin(TIME * 2.7 + wp.x * 0.83 - wp.z * 0.4) * 0.35;
	VERTEX.x += sway * wind_strength * h * h * 5.0;
	VERTEX.z += sway * wind_strength * h * h * 2.0;
	tint = INSTANCE_CUSTOM.rgb;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 dead = mix(tint, vec3(dot(tint, vec3(0.33))), 0.5) * vec3(1.5, 1.4, 1.1);
	ALBEDO = tip > 0.6 ? dead : (tip > 0.25 ? tint : tint * 0.7);
	// Light both sides of the blade like the ground under it.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
