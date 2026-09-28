shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Consecrated ground: a hard glowing rim and turning rays filled with a
// checker dither, so it stays crisp at the low render resolution.

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float alpha = 0.6;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	if (d > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float ray = step(0.55, 0.5 + 0.5 * sin(ang * 9.0 + TIME * 1.5));
	float checker = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
	float body = step(d, 0.9) * (ray * checker * 0.5 + 0.12);
	float rim = step(0.9, d);
	ALBEDO = color.rgb * (body + rim) * alpha;
}
