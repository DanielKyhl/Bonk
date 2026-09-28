shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Expanding shockwave ring on a flat quad: a hard pixel ring with a faint
// checkered fill, fading out by dropping random pixels (additive glow).

uniform vec4 color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float alpha = 1.0;
uniform float thickness = 0.14;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float edge = step(1.0 - thickness * 1.6, d) * step(d, 1.0);
	float checker = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
	float fill = step(d, 1.0) * checker * 0.22;
	float keep = step(fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453), alpha);
	ALBEDO = color.rgb * (edge * 1.3 + fill) * keep;
}
