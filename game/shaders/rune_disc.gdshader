shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A glowing rune circle with turning spokes and pulsing fill, drawn with hard
// edges so it reads as pixel art at the low render size. progress (0..1)
// lights the outer ring clockwise from the top, for charging shrines.

uniform vec3 color : source_color = vec3(1.0, 0.82, 0.42);
uniform float progress = 1.0;
uniform float dim = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float around = fract((a + 1.5707963) / 6.2831853 + 1.0);
	float ring = step(0.8, r) * step(r, 0.94);
	float lit = step(around, progress);
	float inner = step(0.44, r) * step(r, 0.54);
	float spokes = step(0.9, cos(a * 4.0 + TIME * 0.9)) * step(0.54, r) * step(r, 0.8);
	float wave = step(0.55, 0.5 + 0.5 * sin(TIME * 3.2 - r * 7.0));
	vec3 water = mix(color * 0.3, color * 0.55, wave) * dim;
	vec3 c = mix(water, color * 1.15 * dim, clamp(inner + spokes, 0.0, 1.0));
	c = mix(c, mix(color * 0.35, color * 1.3, lit), ring);
	ALBEDO = c;
}
