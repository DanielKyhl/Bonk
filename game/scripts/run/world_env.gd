class_name WorldEnv
extends Node3D
## Sky, sun, fog and post-processing for a map.

var sun: DirectionalLight3D


func setup(map: MapDef) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = map.sky_top
	sky_mat.sky_horizon_color = map.sky_horizon
	sky_mat.ground_horizon_color = map.sky_horizon
	sky_mat.ground_bottom_color = map.sky_horizon.darkened(0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = map.fog_color
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.05

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = map.sun_color
	sun.light_energy = map.sun_energy
	sun.rotation_degrees = Vector3(-58, 38, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.2
	add_child(sun)
