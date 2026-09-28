shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
// Lightning ribbons (Fx.lightning): flat vertex colors, drawn over everything
// (in the transparent pass) so a bolt is never lost behind the crowd.

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = 1.0;
}
