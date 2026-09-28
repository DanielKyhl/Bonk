shader_type canvas_item;
// Final pass over the upscaled pixel image: a cold crush in the shadows, a
// touch of contrast and a heavy vignette so the edges of the view close in.

uniform float vignette = 0.5;
uniform vec3 shadow_tint : source_color = vec3(0.10, 0.07, 0.16);
uniform float contrast = 1.04;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, c * 0.7 + shadow_tint, (1.0 - smoothstep(0.0, 0.3, l)) * 0.25);
	c = (c - 0.5) * contrast + 0.5;
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float v = 1.0 - smoothstep(0.35, 0.85, length(d)) * vignette;
	COLOR = vec4(max(c, 0.0) * v, 1.0);
}
