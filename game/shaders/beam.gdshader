shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Soft additive light column: fades toward the top and toward the silhouette.

uniform vec4 color : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform float strength = 0.22;

void fragment() {
	float up = 1.0 - UV.y;
	float fade = pow(1.0 - up, 1.8);
	float facing = abs(dot(NORMAL, VIEW));
	float soft = smoothstep(0.0, 0.7, facing);
	float flicker = 0.85 + 0.15 * sin(TIME * 5.0 + UV.x * 25.0);
	// Hard light bands instead of a smooth gradient.
	float v = fade * soft * flicker;
	v = floor(v * 4.0 + 0.5) / 4.0;
	ALBEDO = color.rgb * strength * v;
}
