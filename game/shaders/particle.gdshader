shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Particle chips: color and glow come from INSTANCE_CUSTOM (rgb, a = glow).

varying vec4 pc;

void vertex() {
	pc = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = pc.rgb;
	EMISSION = pc.rgb * pc.a;
	ROUGHNESS = 0.8;
}
