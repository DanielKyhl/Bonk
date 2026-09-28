class_name WorldEnv
extends Node3D
## Light and atmosphere for a map: a low, harsh sun, a cold ambient fill and a
## dark void past the edges. No distance fog; the orthographic camera sits far
## away, so depth fog would just wash everything out.

var sun: DirectionalLight3D


func setup(map: MapDef) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = map.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = map.ambient
	env.ambient_light_energy = map.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.glow_enabled = false
	env.glow_intensity = 0.25
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.4

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = map.sun_color
	sun.light_energy = map.sun_energy
	sun.rotation_degrees = Vector3(-map.sun_elevation, map.sun_yaw, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 0.0
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 2.0
	add_child(sun)
