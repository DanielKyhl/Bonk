shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled;
// Pixel-art character sprites (LPC atlases, 64px frames), one quad per
// MultiMesh instance. The instance origin is the character's feet.
//
// The quad faces the camera and snaps to the low-res pixel grid, so texels
// land 1:1 on screen pixels. Its depth is that of an upright figure standing
// at the feet, so hills in front hide the lower body and sinking the feet
// below ground makes the character rise out of (or sink into) the earth.
//
// INSTANCE_CUSTOM:
//   x = frame column + 16 * first atlas row of the animation
//       (+ 4096 if the animation has a single direction)
//   y = facing yaw in world space (atan2(dir.x, dir.z))
//   z = hit flash 0..1 (+2 when chilled: frosted blue)
//   w = visibility 0..1 (dithered fade)
// The instance basis x axis length is the sprite scale; its direction in the
// basis' XY plane rotates the sprite on screen (projectiles; 0 for characters).

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 grid = vec2(9.0, 9.0);        // atlas columns, rows
uniform float ppm = 24.0;                  // low-res pixels per meter
uniform float frame_px = 64.0;
uniform float foot_px = 61.0;              // pixel row of the feet in a frame
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 flash_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float lean = 1.0;                  // 1 = upright depth, 0 = flat card
uniform float bias = 0.0;                  // meters pulled toward the camera (effects over the crowd)

varying vec2 v_uv;
varying float v_flash;
varying float v_alpha;

// 0 up (away from camera), 1 left, 2 down (toward camera), 3 right.
float dir_row(float yaw, mat4 inv_view) {
	vec2 face = vec2(sin(yaw), cos(yaw));
	vec3 r = inv_view[0].xyz;
	vec3 b = inv_view[2].xyz;             // camera back
	vec2 right = normalize(vec2(r.x, r.z));
	vec2 fwd = -normalize(vec2(b.x, b.z));
	float x = dot(face, right);
	float y = dot(face, fwd);
	if (abs(y) >= abs(x)) {
		return y > 0.0 ? 0.0 : 2.0;
	}
	return x < 0.0 ? 1.0 : 3.0;
}

void vertex() {
	float scale = length(MODEL_MATRIX[0].xyz);
	vec4 anchor = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	anchor.xy = floor(anchor.xy * ppm + 0.5) / ppm;

	float code = INSTANCE_CUSTOM.x;
	float single = step(4095.5, code);
	code -= single * 4096.0;
	float row = floor(code / 16.0 + 0.001);
	float col = code - row * 16.0;
	if (single < 0.5) {
		row += dir_row(INSTANCE_CUSTOM.y, INV_VIEW_MATRIX);
	}

	float px = frame_px * scale / ppm;
	vec2 local = vec2(VERTEX.x * px, (VERTEX.y + 0.5) * px - (frame_px - foot_px) * scale / ppm);
	vec2 ax = MODEL_MATRIX[0].xy;
	if (abs(ax.y) > 0.0001) {
		float ang = atan(ax.y, ax.x);
		float c = cos(ang);
		float sn = sin(ang);
		local = vec2(local.x * c - local.y * sn, local.x * sn + local.y * c);
	}
	// World up seen from the camera is (0, cos p, sin p): leaning the quad's
	// depth by tan(p) makes it upright without moving it on screen.
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float tan_p = up.z / max(up.y, 0.05);
	VERTEX = vec3(anchor.xy + local, anchor.z + local.y * tan_p * lean + bias);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_uv = (vec2(col, row) + UV) / grid;
	v_flash = INSTANCE_CUSTOM.z;
	v_alpha = INSTANCE_CUSTOM.w;
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

void fragment() {
	vec4 c = texture(atlas, v_uv);
	if (c.a < 0.5 || v_alpha < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	float frost = step(1.5, v_flash);
	vec3 col = c.rgb * tint;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.5, 0.2))) * vec3(0.75, 1.05, 1.45) + vec3(0.04, 0.08, 0.14), frost * 0.8);
	ALBEDO = mix(col, flash_color, (v_flash - frost * 2.0) * 0.8);
}
