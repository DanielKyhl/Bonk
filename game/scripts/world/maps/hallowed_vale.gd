extends MapDef
## Map 1: Hallowed Vale. A dying valley at dusk: a hilltop cathedral, a
## graveyard bowl, a windmill hamlet, a ruined keep on a plateau and a quarry
## full of kickers.

const MED := "res://assets/kaykit/medieval/"
const HAL := "res://assets/kaykit/halloween/"
const DUN := "res://assets/kaykit/dungeon/"


func _init() -> void:
	title = "Hallowed Vale"
	layout_seed = 1107
	spawn = Vector2(0, 8)

	# --- Palette: dead grass, black mud and cold stone under a blood-red dusk.
	grass = Color(0.27, 0.31, 0.25)
	grass_dry = Color(0.37, 0.36, 0.30)
	dirt = Color(0.29, 0.25, 0.23)
	rock = Color(0.42, 0.42, 0.46)
	low_tint = Color(0.20, 0.23, 0.21)
	sun_color = Color(0.96, 0.74, 0.64)
	sun_energy = 1.05
	sun_elevation = 40.0
	sun_yaw = 128.0
	ambient = Color(0.52, 0.54, 0.74)
	ambient_energy = 0.9
	background = Color(0.04, 0.03, 0.05)
	prop_saturation = 0.4
	prop_value = 0.7
	prop_grade = Color(1.0, 0.92, 0.88)

	# --- Landforms -----------------------------------------------------------
	# Cathedral Crag: two cliff tiers, climbed by natural slopes on the south.
	hill(0, -86, 4.0, 26, 22)
	plateau(0, -86, 4.0, 30, 26, 10, 1.5, 0.15, 90, 20)
	plateau(0, -88, 4.0, 15, 13, 0, 1.2, 0.1, 90, 12)
	hill(-96, -8, 9.0, 46, 12, deg_to_rad(20))   # Windmill Ridge
	# Graveyard Pit: sunk between cliffs, the west side slopes down to the gate.
	plateau(96, 4, -6.0, 22, 22, 0, 1.6, 0.12, 180, 16)
	hill(-102, -96, 8.0, 14)              # Hermit hills
	hill(-72, -112, 7.0, 12)
	hill(-86, -104, -3.0, 8)              # little halfpipe between them
	hill(62, -70, 5.0, 16, 11, deg_to_rad(-30))
	hill(-60, 60, 5.5, 15)
	hill(40, 40, 3.0, 10)
	hill(120, -60, 7.0, 16)
	hill(-30, -40, 4.0, 12)
	# The Keep: a sheer plateau; a long slope climbs its north side.
	plateau(-10, 96, 6.5, 26, 24, 0, 1.6, 0.05, -90, 22, 40)
	# Watch Hill: two jumpable terraces in the southwest.
	plateau(-108, 72, 3.0, 22, 17, 50, 1.2, 0.18, 0, 14)
	plateau(-112, 74, 3.0, 11, 9, 20, 1.0, 0.2)
	# The Scar: a ravine across the west, shallow at both ends.
	ravine([Vector2(-138, -52), Vector2(-104, -42), Vector2(-74, -54), Vector2(-48, -40), Vector2(-34, -18)], 9.0, 7.0, 1.6, 18.0)
	# Bone Ridges: thin rock spines in the northeast badlands.
	plateau(112, -84, 5.5, 26, 3.5, 35, 2.4, 0.22)
	plateau(84, -112, 4.5, 18, 3.0, -20, 2.2, 0.25)
	for sp in [Vector3(58, -58, 9.0), Vector3(71, -47, 7.0), Vector3(46, -80, 10.0), Vector3(132, -104, 8.0),
			Vector3(104, 112, 8.0), Vector3(-128, -128, 9.0), Vector3(-46, 42, 6.0), Vector3(130, 60, 7.5)]:
		spire(sp.x, sp.y, sp.z, 2.6)

	# Kickers: small sharp bumps that launch you when you're fast.
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var placed := 0
	while placed < 80:
		var p := Vector2(rng.randf_range(-130, 130), rng.randf_range(-130, 130))
		if p.distance_to(spawn) < 14 or p.distance_to(Vector2(-10, 96)) < 34 or p.distance_to(Vector2(96, 4)) < 28:
			continue
		if p.distance_to(Vector2(-108, 72)) < 26 or (p.x < -30 and p.y > -62 and p.y < -12 and p.x > -140):
			continue
		if p.distance_to(Vector2(0, -86)) < 16:
			continue
		# The quarry in the southeast gets extra bumps.
		var quarry := p.distance_to(Vector2(85, 90)) < 40
		if not quarry and rng.randf() < 0.35:
			continue
		hill(p.x, p.y, rng.randf_range(0.9, 2.2), rng.randf_range(2.6, 4.4))
		placed += 1

	# --- Ramps ---------------------------------------------------------------
	# Up onto the keep's east and west cliffs (the north side is a slope).
	ramp(33, 98, 180, 16.0, 5.0, 6.6)
	ramp(-53, 100, 0, 16.0, 5.0, 6.6)
	# Kickers around the map.
	ramp(14, 22, 0)
	ramp(-24, 34, 120)
	ramp(64, 6, 0, 8.0, 4.0, 2.2)          # launches you over the graveyard fence
	ramp(-58, -30, 200)
	ramp(30, -44, 300)
	ramp(78, 70, 45)
	ramp(104, 104, 225)
	ramp(-40, -96, 20)
	ramp(-120, 20, 90)

	# --- Holy springs (launch pads) -------------------------------------------
	for p in [Vector2(-18, -16), Vector2(22, -58), Vector2(-30, -70), Vector2(96, -32),
			Vector2(102, 40), Vector2(70, 96), Vector2(114, 122), Vector2(-20, 102),
			Vector2(-60, 40), Vector2(-112, -58), Vector2(60, -112), Vector2(-92, 104),
			Vector2(-134, 28), Vector2(8, 132)]:
		pads.append(p)

	# --- Paths ---------------------------------------------------------------
	path([Vector2(0, 8), Vector2(2, -30), Vector2(-3, -52), Vector2(0, -70)])
	path([Vector2(0, 8), Vector2(34, 6), Vector2(70, 4)])
	path([Vector2(0, 8), Vector2(-36, 2), Vector2(-64, 14), Vector2(-80, 24)])
	path([Vector2(0, 8), Vector2(-5, 36), Vector2(-10, 60)])
	path([Vector2(0, 8), Vector2(40, 46), Vector2(80, 82)])
	path([Vector2(0, 8), Vector2(40, -40), Vector2(70, -84)])

	# --- Landmarks -----------------------------------------------------------
	# Cathedral Hill: the church and a ruined colonnade.
	landmark(MED + "buildings/building_church_blue.gltf", 0, -87, 180, 7.0, {"kind": "box", "size": Vector2(7.0, 7.6), "height": 11.0})
	for p in [Vector2(-12, -74), Vector2(12, -74), Vector2(-13, -98), Vector2(13, -98)]:
		landmark(DUN + "pillar.gltf.glb", p.x, p.y, 0, 1.3, {"kind": "cyl", "radius": 1.0, "height": 5.2})
		pillar_spots.append(p)
	landmark(DUN + "wall_broken.gltf.glb", -9, -70, 10, 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	landmark(DUN + "wall_arched.gltf.glb", 10, -69, -12, 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	landmark(DUN + "rubble_large.gltf.glb", -16, -86, 80, 1.0)

	# Graveyard bowl: crypt on the east rim, arch gate on the west.
	landmark(HAL + "crypt.gltf", 124, 4, -90, 1.2, {"kind": "box", "size": Vector2(9.6, 7.2), "height": 9.0})
	landmark(HAL + "arch.gltf", 72, 4, 90, 1.3)
	for p in [Vector2(80, -18), Vector2(112, 26)]:
		landmark(HAL + "pillar.gltf", p.x, p.y, 0, 1.2, {"kind": "cyl", "radius": 0.7, "height": 5.3})
		pillar_spots.append(p)

	# Windmill Ridge and the hamlet below it.
	landmark(MED + "buildings/building_windmill_blue.gltf", -96, -10, 20, 7.0, {"kind": "box", "size": Vector2(5.0, 5.0), "height": 10.0})
	landmark(MED + "buildings/building_home_A_blue.gltf", -84, 32, 30, 6.5, {"kind": "box", "size": Vector2(5.0, 5.4), "height": 6.0})
	landmark(MED + "buildings/building_home_B_blue.gltf", -70, 40, -20, 6.5, {"kind": "box", "size": Vector2(5.6, 7.0), "height": 8.0})
	landmark(MED + "buildings/building_tavern_blue.gltf", -96, 44, 60, 6.5, {"kind": "box", "size": Vector2(7.6, 8.6), "height": 9.0})
	landmark(MED + "buildings/building_well_blue.gltf", -78, 22, 0, 5.0, {"kind": "cyl", "radius": 1.6, "height": 4.0})

	# The Keep: towers, broken walls and a pillared courtyard on the plateau.
	landmark(MED + "buildings/building_tower_A_blue.gltf", -26, 84, 0, 6.0, {"kind": "cyl", "radius": 3.0, "height": 13.0})
	landmark(MED + "buildings/building_tower_B_blue.gltf", 7, 110, 45, 6.0, {"kind": "cyl", "radius": 3.4, "height": 14.0})
	# Walls leave openings on the north, east and west sides where the ramps land.
	for w in [[-20, 86, 0], [2, 86, 0, true], [6, 92, 90], [6, 104, 90, true], [-18, 110, 0, true], [0, 110, 0], [-24, 91, 90], [-24, 106, 90, true]]:
		var scene := DUN + ("wall_broken.gltf.glb" if w.size() > 3 else "wall.gltf.glb")
		landmark(scene, w[0], w[1], w[2], 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	for p in [Vector2(-17, 91), Vector2(-3, 91), Vector2(-17, 103), Vector2(-3, 103)]:
		landmark(DUN + "pillar.gltf.glb", p.x, p.y, 0, 1.3, {"kind": "cyl", "radius": 1.0, "height": 5.2})
		pillar_spots.append(p)
	landmark(MED + "buildings/building_destroyed.gltf", -24, 115, 30, 5.0)
	landmark(DUN + "banner_patternA_red.gltf.glb", -10, 85, 0, 1.2)

	# Quarry camp in the southeast.
	landmark(MED + "props/tent.gltf", 96, 76, 20, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	landmark(MED + "props/tent.gltf", 108, 88, -40, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	landmark(DUN + "crates_stacked.gltf.glb", 100, 70, 15, 1.2, {"kind": "box", "size": Vector2(2.5, 2.7), "height": 2.6})

	# Spawn crossroads.
	landmark(HAL + "plaque_candles.gltf", 0, 0, 0, 1.2)

	boss_spots = [Vector2(0, -66), Vector2(96, 4), Vector2(-10, 97), Vector2(-82, 28)]

	# --- Decoration scatter (same every run) ----------------------------------
	var pines := [HAL + "tree_pine_orange_large.gltf", HAL + "tree_pine_orange_medium.gltf",
			HAL + "tree_pine_yellow_large.gltf", HAL + "tree_pine_yellow_medium.gltf",
			HAL + "tree_pine_orange_small.gltf", HAL + "tree_pine_yellow_small.gltf"]
	var dead := [HAL + "tree_dead_large.gltf", HAL + "tree_dead_medium.gltf", HAL + "tree_dead_small.gltf", HAL + "tree_dead_large_decorated.gltf"]
	var rocks := [MED + "nature/rock_single_A.gltf", MED + "nature/rock_single_B.gltf", MED + "nature/rock_single_C.gltf",
			MED + "nature/rock_single_D.gltf", MED + "nature/rock_single_E.gltf"]
	var graves := [HAL + "grave_A.gltf", HAL + "grave_B.gltf", HAL + "gravestone.gltf", HAL + "gravemarker_A.gltf",
			HAL + "gravemarker_B.gltf", HAL + "grave_A_destroyed.gltf"]
	var bones := [HAL + "bone_A.gltf", HAL + "bone_B.gltf", HAL + "bone_C.gltf", HAL + "skull.gltf", HAL + "ribcage.gltf"]
	var pumpkins := [HAL + "pumpkin_orange.gltf", HAL + "pumpkin_yellow.gltf", HAL + "pumpkin_orange_small.gltf", HAL + "pumpkin_orange_jackolantern.gltf"]

	# A dense forest ring along the cliffs keeps the edge readable.
	scatter.append({"scenes": pines, "ring": Vector2(128, 156), "count": 330, "scale": Vector2(1.0, 1.6), "spacing": 5.0})
	scatter.append({"scenes": pines, "center": Vector2(80, -100), "radius": 38, "count": 60, "scale": Vector2(0.9, 1.4), "spacing": 6.0})
	scatter.append({"scenes": pines, "center": Vector2(-104, 112), "radius": 30, "count": 45, "scale": Vector2(0.9, 1.4), "spacing": 6.0})
	scatter.append({"scenes": pines, "center": Vector2(-130, -40), "radius": 20, "count": 22, "scale": Vector2(0.9, 1.3), "spacing": 6.0})
	scatter.append({"scenes": pines, "center": Vector2(0, 0), "radius": 125, "count": 60, "scale": Vector2(0.7, 1.2), "spacing": 10.0})
	scatter.append({"scenes": dead, "center": Vector2(0, 0), "radius": 125, "count": 25, "scale": Vector2(0.9, 1.3), "spacing": 10.0})
	scatter.append({"scenes": graves, "rows": {"center": Vector2(96, 4), "radius": 20, "step": Vector2(5.0, 4.0), "yaw": -90.0}, "scale": Vector2(1.0, 1.15), "chance": 0.7})
	scatter.append({"scenes": dead, "center": Vector2(96, 4), "radius": 30, "count": 14, "scale": Vector2(1.0, 1.4), "spacing": 6.0})
	scatter.append({"scenes": dead, "center": Vector2(-10, 96), "radius": 34, "count": 8, "scale": Vector2(1.0, 1.3), "spacing": 8.0})
	scatter.append({"scenes": rocks, "center": Vector2(85, 90), "radius": 38, "count": 36, "scale": Vector2(7.0, 13.0), "spacing": 5.0})
	scatter.append({"scenes": rocks, "center": Vector2(0, 0), "radius": 130, "count": 90, "scale": Vector2(4.0, 9.0), "spacing": 4.0})
	scatter.append({"scenes": bones, "center": Vector2(96, 4), "radius": 34, "count": 26, "scale": Vector2(1.0, 1.3), "spacing": 2.0})
	scatter.append({"scenes": bones, "center": Vector2(-10, 96), "radius": 26, "count": 14, "scale": Vector2(1.0, 1.3), "spacing": 2.0})
	scatter.append({"scenes": pumpkins, "center": Vector2(-82, 34), "radius": 18, "count": 16, "scale": Vector2(0.9, 1.3), "spacing": 2.5})
	scatter.append({"scenes": [HAL + "lantern_standing.gltf"], "along_paths": 16.0, "offset": 3.2, "scale": Vector2(1.3, 1.3)})
	scatter.append({"scenes": [HAL + "fence.gltf", HAL + "fence_broken.gltf"], "circle": {"center": Vector2(96, 4), "radius": 31, "gap_deg": [170.0, 190.0]}, "scale": Vector2(1.0, 1.0)})

	tints = [
		{"pos": Vector2(96, 4), "radius": 34, "color": Color(0.20, 0.21, 0.19), "strength": 0.8},
		{"pos": Vector2(-10, 96), "radius": 30, "color": Color(0.34, 0.32, 0.31), "strength": 0.6},
		{"pos": Vector2(85, 90), "radius": 40, "color": Color(0.40, 0.35, 0.30), "strength": 0.6},
		{"pos": Vector2(80, -100), "radius": 40, "color": Color(0.33, 0.24, 0.21), "strength": 0.5},
	]
