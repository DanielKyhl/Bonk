shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Expanding shockwave ring on a flat quad (additive glow).

uniform vec4 color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float alpha = 1.0;
uniform float thickness = 0.14;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(1.0 - thickness * 2.2, 1.0 - thickness, d) * (1.0 - smoothstep(0.97, 1.0, d));
	float fill = (1.0 - smoothstep(0.0, 1.0, d)) * 0.22;
	ALBEDO = color.rgb * (edge * 1.6 + fill) * alpha;
}
