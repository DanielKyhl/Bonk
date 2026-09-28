shader_type spatial;
render_mode specular_disabled;
// Buildings, trees and decoration: the model's own texture, drained of its
// cheerful colors and darkened toward the map's palette, with stepped light.

#include "res://shaders/pixel_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = true;
uniform float saturation = 0.45;
uniform float value = 0.72;
uniform vec3 grade : source_color = vec3(1.0, 0.94, 0.9);

void fragment() {
	vec3 c = albedo_color.rgb;
	if (use_texture) {
		c *= texture(albedo_tex, UV).rgb;
	}
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(vec3(l), c, saturation) * value * grade;
	ALBEDO = c;
}
