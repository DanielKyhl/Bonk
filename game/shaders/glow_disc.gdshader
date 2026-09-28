shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Soft glowing ground disc with slowly turning rays (auras, consecrated ground).

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float alpha = 0.6;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float ang = atan(p.y, p.x);
	float rays = 0.65 + 0.35 * sin(ang * 9.0 + TIME * 1.5);
	float body = (1.0 - smoothstep(0.55, 1.0, d)) * 0.35 * rays;
	float rim = smoothstep(0.82, 0.95, d) * (1.0 - smoothstep(0.95, 1.0, d));
	ALBEDO = color.rgb * (body + rim) * alpha;
}
