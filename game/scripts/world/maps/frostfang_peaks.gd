extends MapDef
## Map 2: Frostfang Peaks. A frozen range under a pale, cold sky. The spawn
## sits in a sheltered valley; around it rise the Summit (north, the longest
## slide in the game), the Draugr Hold on its cliff shelf (northwest), a
## forest of ice fangs (northeast), the frozen lake (east), Wolf Pass
## (southeast), the Barrow of Kings (south), the avalanche slopes
## (southwest) and a hunters' camp (west). The dead here are draugr.


func _init() -> void:
	id = "frostfang_peaks"
	title = "Frostfang Peaks"
	layout_seed = 2213
	half_size = 320.0
	rim_band = 50.0
	rim_height = 22.0
	spawn = Vector2(0, 40)
	rolling = Vector4(1.6, 16.0, 0.8, 9.0)

	# --- Palette: snow, blue ice and black rock under a pale sun.
	grass = Color(0.64, 0.67, 0.74)
	grass_dry = Color(0.56, 0.59, 0.67)
	dirt = Color(0.42, 0.41, 0.46)
	rock = Color(0.34, 0.37, 0.46)
	low_tint = Color(0.46, 0.56, 0.70)
	sun_color = Color(0.86, 0.92, 1.0)
	sun_energy = 0.85
	sun_elevation = 26.0
	sun_yaw = 150.0
	ambient = Color(0.48, 0.55, 0.78)
	ambient_energy = 0.8
	background = Color(0.05, 0.06, 0.09)
	prop_saturation = 0.3
	prop_value = 0.75
	prop_grade = Color(0.84, 0.92, 1.06)

	enemy_types = [
		{"name": "Draugr", "sprite": "draugr", "attack": "slash", "radius": 0.5, "scale": 1.0, "speed": 6.4, "hp": 30.0, "dmg": 10.0, "xp": 1, "anim_speed": 6.4},
		{"name": "Ice Wraith", "sprite": "ice_wraith", "attack": "slash", "radius": 0.45, "scale": 1.0, "speed": 10.2, "hp": 16.0, "dmg": 8.0, "xp": 1, "anim_speed": 8.5},
		{"name": "Draugr Warrior", "sprite": "draugr_warrior", "attack": "slash", "radius": 0.95, "scale": 1.5, "speed": 4.4, "hp": 200.0, "dmg": 22.0, "xp": 7, "anim_speed": 4.4},
		{"name": "Frost Mage", "sprite": "frost_mage", "attack": "spellcast", "radius": 0.5, "scale": 1.0, "speed": 4.8, "hp": 48.0, "dmg": 12.0, "xp": 3, "anim_speed": 4.8},
		{"name": "Skarn, the Draugr King", "sprite": "draugr_king", "attack": "spellcast", "radius": 1.6, "scale": 3.0, "speed": 5.8, "hp": 60000.0, "dmg": 40.0, "xp": 0, "anim_speed": 5.8},
	]
	boss = {
		"name": "Skarn, the Draugr King", "rises": "The frozen king wakes", "falls": "The Draugr King is shattered",
		"cleansed": "The Peaks fall silent.", "color": Color(0.5, 0.8, 1.0), "bolt_row": 2, "nova_row": 3,
	}

	_summit(Vector2(0, -225))
	_hold(Vector2(-180, -150))
	_fangs(Vector2(175, -165))
	_lake(Vector2(190, 40))
	_wolf_pass()
	_barrow(Vector2(0, 205))
	_avalanche(Vector2(-215, 175))
	_camp(Vector2(-215, 20))
	_ice_caves()
	_spawn_valley()
	kicker(0, -150, 90, 2.8, 9.0)        # off the Summit's foot
	kicker(-170, 110, 60, 2.6, 9.0)      # at the end of the avalanche run
	add_bumps(36, 24, 220, Vector2(4.0, 10.0))
	add_pads(28)
	_forests()

	boss_spots = [Vector2(0, -200), Vector2(-180, -128), Vector2(175, -165), Vector2(190, 40),
			Vector2(0, 186), Vector2(-215, 175), Vector2(-215, 44), Vector2(120, 200)]


## A massif with a long, steep south face that runs down toward the valley.
func _summit(c: Vector2) -> void:
	hill(c.x, c.y, 34.0, 60, 40)
	hill(c.x - 70, c.y + 10, 20.0, 34, 28)
	hill(c.x + 75, c.y + 5, 22.0, 36, 26)
	hill(c.x, c.y + 80, 9.0, 60, 30)
	landmark(HAL + "post_skull.gltf", c.x, c.y, 0, 2.0)
	tints.append({"pos": c, "radius": 90, "color": Color(0.74, 0.76, 0.82), "strength": 0.5})
	path([spawn, Vector2(0, -60), c + Vector2(0, 100)])
	keep_clear.append([c, 90.0])


## The draugr fortress: a castle on a cliff shelf, reached by its south slope.
func _hold(c: Vector2) -> void:
	plateau(c.x, c.y, 8.0, 38, 30, 15, 1.6, 0.1, 90, 32, 45)
	landmark(MED + "buildings/building_castle_blue.gltf", c.x, c.y - 6, 0, 6.0, {"kind": "box", "size": Vector2(12.0, 12.0), "height": 14.0})
	landmark(MED + "buildings/building_tower_A_blue.gltf", c.x - 22, c.y - 10, 0, 6.0, {"kind": "cyl", "radius": 3.0, "height": 13.0})
	landmark(MED + "buildings/building_tower_B_blue.gltf", c.x + 22, c.y - 8, 30, 6.0, {"kind": "cyl", "radius": 3.4, "height": 14.0})
	for w in [[-12, 14, 0], [12, 14, 0, true], [-24, 4, 90, true], [24, 4, 90]]:
		var scene := DUN + ("wall_broken.gltf.glb" if w.size() > 3 else "wall.gltf.glb")
		landmark(scene, c.x + w[0], c.y + w[1], w[2], 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	for o in [Vector2(-8, 20), Vector2(8, 20)]:
		var p: Vector2 = c + o
		landmark(DUN + "pillar.gltf.glb", p.x, p.y, 0, 1.3, {"kind": "cyl", "radius": 1.0, "height": 5.2})
		pillar_spots.append(p)
	landmark(DUN + "banner_patternA_red.gltf.glb", c.x, c.y + 10, 0, 1.4)
	scatter.append({"scenes": bones(), "center": c, "radius": 34, "count": 24, "scale": Vector2(1.0, 1.3), "spacing": 2.5})
	tints.append({"pos": c, "radius": 44, "color": Color(0.5, 0.52, 0.58), "strength": 0.6})
	path([spawn, Vector2(-80, -30), Vector2(-150, -80), c + Vector2(0, 60)])
	keep_clear.append([c, 70.0])


## Tall spikes of ice and rock; hard to cross fast, great to weave through.
func _fangs(c: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 7
	for k in 16:
		var a := k * 2.39996
		var r := 10.0 + 12.0 * sqrt(k)
		spire(c.x + cos(a) * r, c.y + sin(a) * r, rng.randf_range(10.0, 17.0), rng.randf_range(2.0, 3.2))
	hill(c.x, c.y, 8.0, 40)
	tints.append({"pos": c, "radius": 70, "color": Color(0.62, 0.72, 0.86), "strength": 0.6})
	keep_clear.append([c, 70.0])


## A frozen lake: a wide shallow basin with a flat floor of ice.
func _lake(c: Vector2) -> void:
	plateau(c.x, c.y, -2.5, 52, 40, 20, 3.0, 0.12)
	tints.append({"pos": c, "radius": 60, "color": Color(0.48, 0.6, 0.76), "strength": 0.9})
	scatter.append({"scenes": rocks(), "center": c, "radius": 64, "count": 20, "scale": Vector2(5.0, 9.0), "spacing": 6.0})
	keep_clear.append([c, 60.0])


func _wolf_pass() -> void:
	ravine([Vector2(110, 130), Vector2(160, 150), Vector2(200, 190), Vector2(250, 205), Vector2(275, 240)], 14.0, 10.0, 1.6, 26.0)
	keep_clear.append([Vector2(190, 185), 50.0])


## A frozen graveyard on a low shelf, open to the north.
func _barrow(c: Vector2) -> void:
	plateau(c.x, c.y, 3.0, 30, 24, 0, 1.2, 0.1, -90, 16, 70)
	landmark(HAL + "crypt.gltf", c.x, c.y + 14, 180, 1.2, {"kind": "box", "size": Vector2(9.6, 7.2), "height": 9.0})
	scatter.append({"scenes": graves(), "rows": {"center": c, "radius": 20, "step": Vector2(5.0, 4.0), "yaw": 0.0}, "scale": Vector2(1.0, 1.15), "chance": 0.75})
	scatter.append({"scenes": dead_trees(), "center": c, "radius": 34, "count": 14, "scale": Vector2(1.0, 1.4), "spacing": 6.0})
	path([spawn, Vector2(0, 120), c + Vector2(0, -40)])
	keep_clear.append([c, 44.0])


## A tall slope that pours down toward the valley: the avalanche run.
func _avalanche(c: Vector2) -> void:
	hill(c.x - 50, c.y + 50, 30.0, 50, 44)
	hill(c.x, c.y, 10.0, 40, 24, deg_to_rad(-40))
	keep_clear.append([c + Vector2(-40, 40), 70.0])


func _camp(c: Vector2) -> void:
	landmark(MED + "props/tent.gltf", c.x, c.y, 20, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	landmark(MED + "props/tent.gltf", c.x + 12, c.y - 8, -40, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	landmark(MED + "props/tent.gltf", c.x - 10, c.y - 12, 70, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	scatter.append({"scenes": [MED + "props/weaponrack.gltf", MED + "props/barrel.gltf", MED + "props/resource_lumber.gltf", MED + "props/crate_A_big.gltf"],
			"center": c, "radius": 18, "count": 12, "scale": Vector2(4.0, 5.0), "spacing": 3.5})
	path([spawn, Vector2(-100, 34), c + Vector2(20, 0)])
	keep_clear.append([c, 28.0])


## Pits in the ice with a way down one side.
func _ice_caves() -> void:
	plateau(-80, -85, -6.0, 18, 14, 30, 1.4, 0.2, 90, 14)
	plateau(90, -110, -7.0, 20, 16, -20, 1.4, 0.2, 180, 16)
	plateau(110, 120, -5.0, 14, 12, 0, 1.3, 0.2, -90, 12)
	for c in [Vector2(-80, -85), Vector2(90, -110), Vector2(110, 120)]:
		keep_clear.append([c, 28.0])


func _spawn_valley() -> void:
	landmark(HAL + "plaque_candles.gltf", spawn.x, spawn.y - 8, 0, 1.2)
	scatter.append({"scenes": [HAL + "lantern_standing.gltf"], "along_paths": 20.0, "offset": 3.2, "scale": Vector2(1.3, 1.3)})
	keep_clear.append([spawn, 18.0])


func _forests() -> void:
	var edge := half_size - 8.0
	scatter.append({"scenes": pines(), "ring": Vector2(edge - 56.0, edge - 4.0), "count": 1000, "scale": Vector2(1.0, 1.8), "spacing": 5.0})
	for c in [Vector2(-110, 60), Vector2(90, -40), Vector2(-60, 140), Vector2(120, 250), Vector2(-250, -60), Vector2(250, -40)]:
		scatter.append({"scenes": pines(), "center": c, "radius": 36, "count": 60, "scale": Vector2(0.9, 1.5), "spacing": 5.5})
	scatter.append({"scenes": pines(), "center": Vector2.ZERO, "radius": 255, "count": 180, "scale": Vector2(0.8, 1.3), "spacing": 9.0})
	scatter.append({"scenes": dead_trees(), "center": Vector2.ZERO, "radius": 255, "count": 60, "scale": Vector2(0.9, 1.3), "spacing": 10.0})
	scatter.append({"scenes": rocks(), "center": Vector2.ZERO, "radius": 260, "count": 280, "scale": Vector2(4.0, 10.0), "spacing": 4.0})
	scatter.append({"scenes": bones(), "center": Vector2.ZERO, "radius": 255, "count": 80, "scale": Vector2(1.0, 1.3), "spacing": 3.0})
