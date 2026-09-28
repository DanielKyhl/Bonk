shader_type spatial;
render_mode specular_disabled;
// Ground: vertex colors carry the palette (grass, dirt, rock, paths). Detail
// is computed on a coarse world grid and posterized, so at the low render
// resolution it reads as hand-placed pixel clusters rather than smooth noise.
// Steep faces get rock strata.

#include "res://shaders/pixel_light.gdshaderinc"

uniform float cells = 8.0;   // detail cells per meter (3 low-res pixels each)
uniform float detail = 1.0;

varying vec3 world_pos;
varying vec3 world_nrm;

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
	world_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec2 cell = floor(world_pos.xz * cells) / cells;
	float big = vnoise(cell * 0.05);
	float mid = vnoise(cell * 0.32 + 17.0);
	float grain = hash(cell * 1.37);
	float steep = 1.0 - normalize(world_nrm).y;
	float tone = 0.86 + (0.16 * mid + 0.08 * big) * detail;
	// Sparse light and dark specks: pebbles, tufts, holes.
	tone += grain > 0.975 ? 0.16 : (grain < 0.03 ? -0.14 : 0.0);
	if (steep > 0.45) {
		// Cliff faces: horizontal strata that wobble a little.
		float yq = floor(world_pos.y * cells) / cells;
		float s = fract(yq * 0.75 + vnoise(vec2(world_pos.x + world_pos.z, 0.0) * 0.4) * 0.5);
		tone *= s < 0.2 ? 0.62 : (s > 0.86 ? 1.15 : 0.92);
	}
	// Posterize with an ordered dither on the detail grid, like hand-dithered
	// pixel shading between tones.
	ivec2 bi = ivec2(mod(floor(world_pos.xz * cells), 4.0));
	float bm[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	tone = floor(tone * 6.0 + (bm[bi.x + bi.y * 4] + 0.5) / 16.0) / 6.0;
	ALBEDO = c * tone;
}
