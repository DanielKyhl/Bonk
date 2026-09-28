shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Crowd enemies: animation frames are baked into textures (see VatData).
// INSTANCE_CUSTOM: x = animation (0 run, 1 attack, 2 spawn, 3 death),
// y = seconds into that animation, z = hit flash 0..1, w = sink into ground (m).

uniform sampler2D pos_tex : filter_nearest, repeat_disable;
uniform sampler2D nrm_tex : filter_nearest, repeat_disable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 anim0;   // first row, frames, fps, loop
uniform vec4 anim1;
uniform vec4 anim2;
uniform vec4 anim3;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(0.0);

varying float v_flash;

vec4 pick(float id) {
	return id < 0.5 ? anim0 : (id < 1.5 ? anim1 : (id < 2.5 ? anim2 : anim3));
}

void vertex() {
	vec4 a = pick(INSTANCE_CUSTOM.x);
	float f = max(INSTANCE_CUSTOM.y, 0.0) * a.z;
	float fl = floor(f);
	float fr = f - fl;
	float f0;
	float f1;
	if (a.w > 0.5) {
		f0 = mod(fl, a.y);
		f1 = mod(fl + 1.0, a.y);
	} else {
		f0 = min(fl, a.y - 1.0);
		f1 = min(fl + 1.0, a.y - 1.0);
	}
	int col = int(UV2.x + 0.5);
	ivec2 t0 = ivec2(col, int(a.x + f0));
	ivec2 t1 = ivec2(col, int(a.x + f1));
	VERTEX = mix(texelFetch(pos_tex, t0, 0).xyz, texelFetch(pos_tex, t1, 0).xyz, fr);
	vec3 n0 = texelFetch(nrm_tex, t0, 0).xyz * 2.0 - 1.0;
	vec3 n1 = texelFetch(nrm_tex, t1, 0).xyz * 2.0 - 1.0;
	NORMAL = normalize(mix(n0, n1, fr));
	VERTEX.y -= INSTANCE_CUSTOM.w;
	v_flash = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * tint;
	ALBEDO = mix(c, vec3(1.0, 0.93, 0.8), v_flash * 0.5);
	EMISSION = glow;
	ROUGHNESS = 0.85;
}
