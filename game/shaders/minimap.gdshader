shader_type canvas_item;
// Round minimap: samples the map picture around the hero, turned so the
// camera's view direction is up, inside a dark pixel rim.

uniform vec2 center_uv = vec2(0.5);
uniform float radius_uv = 0.2;
uniform float yaw = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float c = cos(yaw);
	float s = sin(yaw);
	// Screen right/down to world x/z (matches the camera's yaw).
	vec2 w = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
	vec2 uv = center_uv + w * radius_uv;
	vec3 col = texture(TEXTURE, uv).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		col = vec3(0.03, 0.02, 0.04);
	}
	if (r > 0.94) {
		col = vec3(0.04, 0.03, 0.05);
	} else if (r > 0.9) {
		col = vec3(0.55, 0.43, 0.26);
	}
	COLOR = vec4(col, 0.92);
}
