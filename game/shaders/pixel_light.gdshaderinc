// Stepped lighting shared by the world shaders: sunlight falls into a few hard
// bands (lit, half-lit, shadow) instead of smooth shading, like hand-shaded
// pixel art. Shadows from the sun are part of the same bands.
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = ndl > 0.5 ? 1.0 : (ndl > 0.16 ? 0.55 : 0.2);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
