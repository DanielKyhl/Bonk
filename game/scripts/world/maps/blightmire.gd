extends MapDef
## Map 3: Blightmire. A rotting swamp under a sick yellow sky: low, wet ground
## broken by bogs and mud banks. Around the spawn lie the Rot Mound (north,
## the big slide), Witch's Hollow (northeast), the Heron Isles (east), the
## Sunken Abbey (south), Gallows Ridge (southwest), the Drowned Village
## (west) and Leech Creek winding through it all. The dead here are drowned
## and diseased.


func _init() -> void:
	id = "blightmire"
	title = "Blightmire"
	music = "bog"
	layout_seed = 3319
	half_size = 320.0
	rim_band = 44.0
	rim_height = 14.0
	spawn = Vector2(0, 10)
	rolling = Vector4(0.7, 14.0, 0.5, 8.0)

	# --- Palette: rot green, black mud and stagnant water under a sick sun.
	grass = Color(0.25, 0.29, 0.19)
	grass_dry = Color(0.34, 0.30, 0.20)
	dirt = Color(0.26, 0.22, 0.16)
	rock = Color(0.33, 0.35, 0.30)
	low_tint = Color(0.15, 0.21, 0.15)
	sun_color = Color(0.86, 0.9, 0.62)
	sun_energy = 0.85
	sun_elevation = 32.0
	sun_yaw = 110.0
	ambient = Color(0.42, 0.48, 0.42)
	ambient_energy = 0.8
	background = Color(0.03, 0.04, 0.03)
	prop_saturation = 0.35
	prop_value = 0.68
	prop_grade = Color(0.92, 1.0, 0.82)

	enemy_types = [
		{"name": "Bog Zombie", "sprite": "bog_zombie", "attack": "slash", "radius": 0.5, "scale": 1.0, "speed": 4.6, "hp": 34.0, "dmg": 11.0, "xp": 1, "anim_speed": 5.8},
		{"name": "Sackhead", "sprite": "sackhead", "attack": "slash", "radius": 0.45, "scale": 1.0, "speed": 8.5, "hp": 18.0, "dmg": 9.0, "xp": 1, "anim_speed": 8.5},
		{"name": "Bog Brute", "sprite": "bog_brute", "attack": "slash", "radius": 0.95, "scale": 1.5, "speed": 3.2, "hp": 240.0, "dmg": 24.0, "xp": 8, "anim_speed": 4.0},
		{"name": "Plague Witch", "sprite": "plague_witch", "attack": "spellcast", "radius": 0.5, "scale": 1.0, "speed": 3.8, "hp": 52.0, "dmg": 12.0, "xp": 3, "anim_speed": 4.8, "shot_row": 8},
		{"name": "Mother Rot, the Bog Witch", "sprite": "mother_rot", "attack": "spellcast", "radius": 1.6, "scale": 3.0, "speed": 4.5, "hp": 60000.0, "dmg": 42.0, "xp": 0, "anim_speed": 5.6},
	]
	boss = {
		"name": "Mother Rot, the Bog Witch", "rises": "The mire gives up its queen", "falls": "Mother Rot sinks into the mire",
		"cleansed": "The mire lies still.", "color": Color(0.6, 0.9, 0.2), "bolt_row": 4, "nova_row": 5,
	}

	_rot_mound(Vector2(0, -210))
	_hollow(Vector2(170, -150))
	_isles(Vector2(185, 110))
	_abbey(Vector2(50, 205))
	_gallows(Vector2(-200, 175))
	_village(Vector2(-165, -45))
	_creek()
	_stumps()
	_bogs()
	_spawn_camp()
	kicker(0, -140, 90, 2.8, 9.0)        # off the Rot Mound's foot
	kicker(-120, 120, 45, 2.6, 9.0)
	add_bumps(24, 22, 200, Vector2(2.5, 6.0))
	add_pads(28)
	_woods()

	boss_spots = [Vector2(0, -180), Vector2(170, -150), Vector2(185, 110), Vector2(50, 190),
			Vector2(-200, 175), Vector2(-150, -20), Vector2(-230, -200), Vector2(230, -10)]


## One huge rotten hill: steep on every side, the best slide in the swamp.
func _rot_mound(c: Vector2) -> void:
	hill(c.x, c.y, 26.0, 26)
	hill(c.x + 50, c.y + 20, 10.0, 22)
	hill(c.x - 55, c.y + 15, 12.0, 24)
	landmark(HAL + "post_skull.gltf", c.x, c.y, 0, 2.0)
	scatter.append({"scenes": dead_trees(), "center": c, "radius": 60, "count": 20, "scale": Vector2(1.0, 1.5), "spacing": 8.0})
	path([spawn, Vector2(0, -80), c + Vector2(0, 60)])
	keep_clear.append([c, 64.0])


## A pit where the witches gather, ringed by dead trees and candles.
func _hollow(c: Vector2) -> void:
	plateau(c.x, c.y, -7.0, 28, 24, 10, 1.5, 0.18, 200, 18)
	landmark(HAL + "shrine_candles.gltf", c.x, c.y, 0, 2.0)
	for k in 8:
		var a := k * TAU / 8.0
		landmark(HAL + "skull_candle.gltf", c.x + cos(a) * 12.0, c.y + sin(a) * 12.0, 0, 1.6)
	scatter.append({"scenes": dead_trees(), "circle": {"center": c, "radius": 36}, "scale": Vector2(1.2, 1.2)})
	scatter.append({"scenes": bones(), "center": c, "radius": 24, "count": 30, "scale": Vector2(1.0, 1.3), "spacing": 2.0})
	tints.append({"pos": c, "radius": 40, "color": Color(0.2, 0.22, 0.16), "strength": 0.8})
	keep_clear.append([c, 44.0])


## Raised islands in the bog, a few with a lantern on a post.
func _isles(c: Vector2) -> void:
	hill(c.x, c.y, -3.0, 40, 30)
	for k in 6:
		var a := k * 1.1
		var p := c + Vector2(cos(a), sin(a)) * (14.0 + k * 5.0)
		plateau(p.x, p.y, 3.0, 7.0 + k * 0.7, 6.0, k * 30.0, 1.0, 0.2, k * 60.0, 8)
		if k % 2 == 0:
			landmark(HAL + "post_lantern.gltf", p.x, p.y, 0, 1.6)
	tints.append({"pos": c, "radius": 50, "color": Color(0.16, 0.22, 0.17), "strength": 0.8})
	keep_clear.append([c, 56.0])


## A drowned abbey: arches and pillars in a sunken courtyard.
func _abbey(c: Vector2) -> void:
	plateau(c.x, c.y, -4.0, 24, 20, 0, 1.4, 0.1, -90, 16)
	for w in [[-10, -8, 0], [10, -8, 0, true], [-14, 4, 90], [14, 4, 90, true]]:
		var scene := DUN + ("wall_broken.gltf.glb" if w.size() > 3 else "wall_arched.gltf.glb")
		landmark(scene, c.x + w[0], c.y + w[1], w[2], 1.3, {"kind": "box", "size": Vector2(5.2, 1.3), "height": 5.2})
	for o in [Vector2(-6, 10), Vector2(6, 10), Vector2(-6, -2), Vector2(6, -2)]:
		var p: Vector2 = c + o
		landmark(DUN + "pillar.gltf.glb", p.x, p.y, 0, 1.3, {"kind": "cyl", "radius": 1.0, "height": 5.2})
		pillar_spots.append(p)
	scatter.append({"scenes": graves(), "center": c + Vector2(0, 26), "radius": 16, "count": 14, "scale": Vector2(1.0, 1.2), "spacing": 3.0})
	path([spawn, Vector2(20, 110), c + Vector2(0, -40)])
	keep_clear.append([c, 40.0])


## A long ridge of gallows posts and hanging lanterns.
func _gallows(c: Vector2) -> void:
	hill(c.x, c.y, 13.0, 56, 14, deg_to_rad(-30))
	for k in 7:
		var t := (k - 3) * 14.0
		var p := c + Vector2(cos(deg_to_rad(-30)), sin(deg_to_rad(-30))) * t
		landmark(HAL + ("post_skull.gltf" if k % 2 == 0 else "lantern_hanging.gltf"), p.x, p.y, k * 30.0, 1.6)
	keep_clear.append([c, 40.0])


## A sunken village of rotting houses on the low ground.
func _village(c: Vector2) -> void:
	hill(c.x, c.y, -2.5, 40, 30)
	landmark(MED + "buildings/building_home_A_blue.gltf", c.x - 14, c.y - 10, 30, 6.5, {"kind": "box", "size": Vector2(5.0, 5.4), "height": 6.0})
	landmark(MED + "buildings/building_home_B_blue.gltf", c.x + 10, c.y - 14, -20, 6.5, {"kind": "box", "size": Vector2(5.6, 7.0), "height": 8.0})
	landmark(MED + "buildings/building_tavern_blue.gltf", c.x - 4, c.y + 16, 60, 6.5, {"kind": "box", "size": Vector2(7.6, 8.6), "height": 9.0})
	landmark(MED + "buildings/building_destroyed.gltf", c.x + 20, c.y + 8, 70, 5.0)
	landmark(MED + "buildings/building_destroyed.gltf", c.x - 24, c.y + 6, -30, 5.0)
	scatter.append({"scenes": pumpkins() + [MED + "props/barrel.gltf", MED + "props/sack.gltf"], "center": c, "radius": 26, "count": 24, "scale": Vector2(1.0, 1.4), "spacing": 3.0})
	scatter.append({"scenes": [HAL + "fence_broken.gltf", HAL + "fence_seperate_broken.gltf"], "center": c, "radius": 30, "count": 12, "scale": Vector2(1.0, 1.0), "spacing": 5.0})
	path([spawn, Vector2(-80, -10), c + Vector2(30, 0)])
	keep_clear.append([c, 36.0])


func _creek() -> void:
	ravine([Vector2(-290, 60), Vector2(-220, 40), Vector2(-150, 70), Vector2(-90, 50), Vector2(-40, 90),
			Vector2(20, 120), Vector2(90, 140), Vector2(130, 190), Vector2(160, 280)], 10.0, 6.0, 1.4, 24.0)


## The rotted stumps of trees that were once giants.
func _stumps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 3
	var lim := half_size - rim_band - 20.0
	var placed := 0
	while placed < 18:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not is_clear(p, 12.0):
			continue
		plateau(p.x, p.y, rng.randf_range(3.5, 6.0), rng.randf_range(3.0, 4.5), -1.0, rng.randf() * 180.0, 0.8, 0.3)
		keep_clear.append([p, 10.0])
		placed += 1


## Stagnant pools everywhere.
func _bogs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 9
	var lim := half_size - rim_band - 15.0
	var placed := 0
	while placed < 40:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not is_clear(p, 8.0):
			continue
		hill(p.x, p.y, rng.randf_range(-3.0, -1.8), rng.randf_range(10.0, 20.0), rng.randf_range(8.0, 16.0), rng.randf() * PI)
		placed += 1


func _spawn_camp() -> void:
	landmark(HAL + "plaque_candles.gltf", spawn.x, spawn.y - 8, 0, 1.2)
	scatter.append({"scenes": [HAL + "lantern_standing.gltf"], "along_paths": 18.0, "offset": 3.2, "scale": Vector2(1.3, 1.3)})
	keep_clear.append([spawn, 18.0])


func _woods() -> void:
	var edge := half_size - 8.0
	scatter.append({"scenes": dead_trees(), "ring": Vector2(edge - 50.0, edge - 4.0), "count": 900, "scale": Vector2(1.2, 2.0), "spacing": 5.0})
	for c in [Vector2(100, -40), Vector2(-100, 100), Vector2(-60, -120), Vector2(230, -80), Vector2(-240, -150), Vector2(140, 240)]:
		scatter.append({"scenes": dead_trees(), "center": c, "radius": 36, "count": 50, "scale": Vector2(1.0, 1.6), "spacing": 5.0})
	scatter.append({"scenes": dead_trees(), "center": Vector2.ZERO, "radius": 255, "count": 200, "scale": Vector2(0.9, 1.4), "spacing": 8.0})
	scatter.append({"scenes": rocks(), "center": Vector2.ZERO, "radius": 260, "count": 160, "scale": Vector2(4.0, 8.0), "spacing": 4.0})
	scatter.append({"scenes": bones(), "center": Vector2.ZERO, "radius": 255, "count": 140, "scale": Vector2(1.0, 1.3), "spacing": 3.0})
	scatter.append({"scenes": graves(), "center": Vector2.ZERO, "radius": 250, "count": 50, "scale": Vector2(1.0, 1.2), "spacing": 6.0})
