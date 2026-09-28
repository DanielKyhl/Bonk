shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Hard-edged pixel shadow straight under a character, so height is easy to read.

uniform float strength = 0.6;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	if (d > 1.0) {
		discard;
	}
	ALBEDO = vec3(0.02, 0.015, 0.03);
	ALPHA = strength;
}
