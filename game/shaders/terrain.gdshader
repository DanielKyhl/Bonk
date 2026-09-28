shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Ground: vertex colors carry the palette (grass, dirt, rock, paths).
// Layered value noise adds patches and texture so it doesn't look flat.

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec2 p = world_pos.xz;
	float big = vnoise(p * 0.07);
	float mid = vnoise(p * 0.45 + 17.0);
	float fine = vnoise(p * 2.6 + 3.0);
	// Warm/cool drift over large patches, then medium and fine brightness breakup.
	c = mix(c, c * vec3(1.08, 1.02, 0.86), smoothstep(0.45, 0.8, big) * 0.6);
	c *= 0.82 + 0.22 * mid + 0.12 * fine;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
