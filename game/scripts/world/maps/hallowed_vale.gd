extends MapDef
## Map 1: Hallowed Vale. A big, dying valley at dusk, 640 m across. The
## spawn crossroads sits in the middle; around it lie the Cathedral Crag
## (north), the Bone Badlands (northeast), the sunken Graveyard (east), the
## Quarry (southeast), the Keep on its cliff (south), Watch Hill (southwest),
## Windmill Ridge and the hamlet (west), the Scar ravine and the Hermit Hills
## (northwest). Steep hills, barrow mounds and the curved edges are where you
## build speed; there are no ramps.

const MED := "res://assets/kaykit/medieval/"
const HAL := "res://assets/kaykit/halloween/"
const DUN := "res://assets/kaykit/dungeon/"

## Places that random bumps, pads and forests keep clear of: [center, radius].
var _keep_clear: Array = []


func _init() -> void:
	title = "Hallowed Vale"
	layout_seed = 1107
	half_size = 320.0
	rim_band = 44.0
	rim_height = 16.0
	spawn = Vector2(0, 20)

	# --- Palette: dead grass, black mud and cold stone under a blood-red dusk.
	grass = Color(0.27, 0.31, 0.25)
	grass_dry = Color(0.37, 0.36, 0.30)
	dirt = Color(0.29, 0.25, 0.23)
	rock = Color(0.42, 0.42, 0.46)
	low_tint = Color(0.20, 0.23, 0.21)
	sun_color = Color(0.96, 0.74, 0.64)
	sun_energy = 1.05
	sun_elevation = 34.0
	sun_yaw = 128.0
	ambient = Color(0.52, 0.54, 0.74)
	ambient_energy = 0.9
	background = Color(0.04, 0.03, 0.05)
	prop_saturation = 0.4
	prop_value = 0.7
	prop_grade = Color(1.0, 0.92, 0.88)

	_cathedral(Vector2(0, -196))
	_badlands(Vector2(180, -180))
	_graveyard(Vector2(205, 10))
	_quarry(Vector2(175, 185))
	_keep(Vector2(-20, 205))
	_watch_hill(Vector2(-210, 160))
	_hamlet(Vector2(-200, -10), Vector2(-170, 62))
	_scar()
	_hermit_hills(Vector2(-210, -225))
	_barrows(Vector2(85, -85))
	_tor(Vector2(-70, -95))
	_sunken_chapel(Vector2(-95, -175))
	_hanged_wood(Vector2(95, 110))
	_bog(Vector2(60, 170))
	_battlefield(Vector2(-95, 45))
	_crossroads()
	_bumps()
	_pads()
	_forests()

	boss_spots = [Vector2(0, -170), Vector2(205, 10), Vector2(-20, 200), Vector2(-178, 70),
			Vector2(180, -165), Vector2(175, 190), Vector2(-212, 162), Vector2(-215, -228)]


# -----------------------------------------------------------------------------
# Regions
# -----------------------------------------------------------------------------
## Two cliff tiers with the church on top; slopes lead up the south side and a
## long hill below them runs down toward the crossroads.
func _cathedral(c: Vector2) -> void:
	plateau(c.x, c.y, 5.0, 50, 42, 10, 1.6, 0.14, 90, 34)
	plateau(c.x, c.y - 4, 5.0, 22, 18, 0, 1.3, 0.1, 90, 16)
	hill(c.x, c.y + 60, 10.0, 44, 30)                        # Pilgrim's Slope
	var top := c + Vector2(0, -4)
	landmark(MED + "buildings/building_church_blue.gltf", top.x, top.y, 180, 7.0, {"kind": "box", "size": Vector2(7.0, 7.6), "height": 11.0})
	for o in [Vector2(-12, 13), Vector2(12, 13), Vector2(-13, -11), Vector2(13, -11)]:
		var p: Vector2 = top + o
		landmark(DUN + "pillar.gltf.glb", p.x, p.y, 0, 1.3, {"kind": "cyl", "radius": 1.0, "height": 5.2})
		pillar_spots.append(p)
	landmark(DUN + "wall_broken.gltf.glb", top.x - 9, top.y + 17, 10, 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	landmark(DUN + "wall_arched.gltf.glb", top.x + 10, top.y + 18, -12, 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	landmark(DUN + "rubble_large.gltf.glb", top.x - 16, top.y, 80, 1.0)
	tints.append({"pos": c, "radius": 56, "color": Color(0.36, 0.35, 0.33), "strength": 0.5})
	path([spawn, Vector2(0, -60), Vector2(-4, -110), c + Vector2(0, 40)])
	_keep_clear.append([c, 64.0])


## Thin rock spines, spires, dead trees and bones.
func _badlands(c: Vector2) -> void:
	plateau(c.x + 25, c.y + 25, 6.0, 40, 4, 35, 2.4, 0.22)
	plateau(c.x - 30, c.y - 30, 5.0, 30, 3.5, -20, 2.2, 0.25)
	plateau(c.x + 50, c.y - 40, 5.5, 26, 3.5, 60, 2.4, 0.2)
	plateau(c.x - 45, c.y + 40, 4.5, 22, 3, 80, 2.2, 0.25)
	for sp in [Vector3(-10, 10, 10.0), Vector3(12, -12, 8.0), Vector3(-40, -5, 9.0), Vector3(40, 30, 7.0),
			Vector3(5, 55, 8.5), Vector3(60, 0, 9.5), Vector3(-20, -55, 7.5), Vector3(30, -60, 8.0)]:
		spire(c.x + sp.x, c.y + sp.y, sp.z, 2.8)
	hill(c.x, c.y, 6.0, 40)
	tints.append({"pos": c, "radius": 80, "color": Color(0.34, 0.26, 0.22), "strength": 0.5})
	scatter.append({"scenes": _dead(), "center": c, "radius": 70, "count": 40, "scale": Vector2(1.0, 1.5), "spacing": 7.0})
	scatter.append({"scenes": _bones(), "center": c, "radius": 70, "count": 40, "scale": Vector2(1.0, 1.4), "spacing": 3.0})
	path([spawn, Vector2(60, -40), Vector2(120, -120), c + Vector2(-30, 30)])
	_keep_clear.append([c, 80.0])


## A pit sunk between cliffs; the west side slopes down to the gate.
func _graveyard(c: Vector2) -> void:
	plateau(c.x, c.y, -7.0, 30, 28, 0, 1.6, 0.12, 180, 20)
	landmark(HAL + "crypt.gltf", c.x + 40, c.y, -90, 1.2, {"kind": "box", "size": Vector2(9.6, 7.2), "height": 9.0})
	landmark(HAL + "arch.gltf", c.x - 42, c.y, 90, 1.3)
	for o in [Vector2(-24, -24), Vector2(22, 26), Vector2(26, -22)]:
		var p: Vector2 = c + o
		landmark(HAL + "pillar.gltf", p.x, p.y, 0, 1.2, {"kind": "cyl", "radius": 0.7, "height": 5.3})
		pillar_spots.append(p)
	scatter.append({"scenes": _graves(), "rows": {"center": c, "radius": 26, "step": Vector2(5.0, 4.0), "yaw": -90.0}, "scale": Vector2(1.0, 1.15), "chance": 0.7})
	scatter.append({"scenes": _dead(), "center": c, "radius": 40, "count": 16, "scale": Vector2(1.0, 1.4), "spacing": 6.0})
	scatter.append({"scenes": _bones(), "center": c, "radius": 34, "count": 26, "scale": Vector2(1.0, 1.3), "spacing": 2.0})
	scatter.append({"scenes": [HAL + "fence.gltf", HAL + "fence_broken.gltf"], "circle": {"center": c, "radius": 37, "gap_deg": [168.0, 192.0]}, "scale": Vector2(1.0, 1.0)})
	tints.append({"pos": c, "radius": 44, "color": Color(0.20, 0.21, 0.19), "strength": 0.8})
	path([spawn, Vector2(80, 14), c + Vector2(-50, 0)])
	_keep_clear.append([c, 50.0])


## An open-cut pit full of boulders and bumps, with a camp on its rim.
func _quarry(c: Vector2) -> void:
	plateau(c.x, c.y, -5.0, 36, 28, 20, 1.4, 0.2, 225, 24)
	for k in 10:
		var a := k * 2.4
		hill(c.x + cos(a) * 16.0, c.y + sin(a) * 12.0, 1.8 + fmod(k * 0.7, 1.2), 3.2)
	for sp in [Vector3(-40, 30, 8.0), Vector3(45, -25, 9.0), Vector3(30, 40, 7.0)]:
		spire(c.x + sp.x, c.y + sp.y, sp.z, 2.6)
	var camp := c + Vector2(-44, -30)
	landmark(MED + "props/tent.gltf", camp.x, camp.y, 20, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	landmark(MED + "props/tent.gltf", camp.x + 12, camp.y - 8, -40, 7.0, {"kind": "box", "size": Vector2(3.6, 3.6), "height": 3.6})
	landmark(DUN + "crates_stacked.gltf.glb", camp.x + 6, camp.y + 6, 15, 1.2, {"kind": "box", "size": Vector2(2.5, 2.7), "height": 2.6})
	scatter.append({"scenes": _rocks(), "center": c, "radius": 44, "count": 40, "scale": Vector2(7.0, 13.0), "spacing": 5.0})
	tints.append({"pos": c, "radius": 50, "color": Color(0.40, 0.35, 0.30), "strength": 0.6})
	path([spawn, Vector2(60, 80), c + Vector2(-50, -40)])
	_keep_clear.append([c, 56.0])


## A sheer plateau; a long slope climbs its north side to the ruined keep.
func _keep(c: Vector2) -> void:
	plateau(c.x, c.y, 7.0, 32, 28, 0, 1.6, 0.05, -90, 30, 40)
	var t := c + Vector2(-10, 0)
	landmark(MED + "buildings/building_tower_A_blue.gltf", t.x - 16, t.y - 12, 0, 6.0, {"kind": "cyl", "radius": 3.0, "height": 13.0})
	landmark(MED + "buildings/building_tower_B_blue.gltf", t.x + 17, t.y + 14, 45, 6.0, {"kind": "cyl", "radius": 3.4, "height": 14.0})
	# Walls leave an opening on the north side where the slope arrives.
	for w in [[-10, -10, 0], [12, -10, 0, true], [16, -4, 90], [16, 8, 90, true], [-8, 14, 0, true], [10, 14, 0], [-14, -5, 90], [-14, 10, 90, true]]:
		var scene := DUN + ("wall_broken.gltf.glb" if w.size() > 3 else "wall.gltf.glb")
		landmark(scene, t.x + w[0], t.y + w[1], w[2], 1.2, {"kind": "box", "size": Vector2(4.8, 1.2), "height": 4.8})
	for o in [Vector2(-7, -5), Vector2(7, -5), Vector2(-7, 7), Vector2(7, 7)]:
		var p: Vector2 = t + o
		landmark(DUN + "pillar.gltf.glb", p.x, p.y, 0, 1.3, {"kind": "cyl", "radius": 1.0, "height": 5.2})
		pillar_spots.append(p)
	landmark(MED + "buildings/building_destroyed.gltf", t.x - 14, t.y + 19, 30, 5.0)
	landmark(DUN + "banner_patternA_red.gltf.glb", t.x, t.y - 11, 0, 1.2)
	scatter.append({"scenes": _dead(), "center": c, "radius": 38, "count": 10, "scale": Vector2(1.0, 1.3), "spacing": 8.0})
	scatter.append({"scenes": _bones(), "center": c, "radius": 30, "count": 16, "scale": Vector2(1.0, 1.3), "spacing": 2.0})
	tints.append({"pos": c, "radius": 36, "color": Color(0.34, 0.32, 0.31), "strength": 0.6})
	path([spawn, Vector2(-8, 90), c + Vector2(0, -60)])
	_keep_clear.append([c, 64.0])


## Three stacked terraces; the top one needs a jump.
func _watch_hill(c: Vector2) -> void:
	plateau(c.x, c.y, 3.2, 30, 22, 50, 1.2, 0.18, 0, 16)
	plateau(c.x - 4, c.y + 2, 3.2, 15, 12, 20, 1.0, 0.2, 180, 10)
	plateau(c.x - 6, c.y + 4, 3.0, 7, 6, 0, 0.9, 0.15)
	landmark(HAL + "post_lantern.gltf", c.x - 6, c.y + 4, 0, 1.6)
	scatter.append({"scenes": _pines(), "center": c + Vector2(20, 30), "radius": 26, "count": 30, "scale": Vector2(0.9, 1.4), "spacing": 6.0})
	_keep_clear.append([c, 40.0])


## A long steep ridge with the windmill on top and a hamlet at its foot.
func _hamlet(ridge: Vector2, h: Vector2) -> void:
	hill(ridge.x, ridge.y, 14.0, 70, 16, deg_to_rad(20))
	landmark(MED + "buildings/building_windmill_blue.gltf", ridge.x, ridge.y - 4, 20, 7.0, {"kind": "box", "size": Vector2(5.0, 5.0), "height": 10.0})
	landmark(MED + "buildings/building_home_A_blue.gltf", h.x - 14, h.y - 30, 30, 6.5, {"kind": "box", "size": Vector2(5.0, 5.4), "height": 6.0})
	landmark(MED + "buildings/building_home_B_blue.gltf", h.x, h.y - 22, -20, 6.5, {"kind": "box", "size": Vector2(5.6, 7.0), "height": 8.0})
	landmark(MED + "buildings/building_tavern_blue.gltf", h.x - 26, h.y - 18, 60, 6.5, {"kind": "box", "size": Vector2(7.6, 8.6), "height": 9.0})
	landmark(MED + "buildings/building_home_A_blue.gltf", h.x + 16, h.y - 6, -60, 6.5, {"kind": "box", "size": Vector2(5.0, 5.4), "height": 6.0})
	landmark(MED + "buildings/building_well_blue.gltf", h.x - 8, h.y - 40, 0, 5.0, {"kind": "cyl", "radius": 1.6, "height": 4.0})
	landmark(MED + "buildings/building_destroyed.gltf", h.x + 6, h.y + 10, 70, 5.0)
	scatter.append({"scenes": _pumpkins(), "center": h + Vector2(-8, -20), "radius": 22, "count": 20, "scale": Vector2(0.9, 1.3), "spacing": 2.5})
	scatter.append({"scenes": [MED + "props/barrel.gltf", MED + "props/sack.gltf", MED + "props/crate_A_big.gltf", MED + "props/wheelbarrow.gltf"],
			"center": h + Vector2(-6, -20), "radius": 20, "count": 14, "scale": Vector2(4.0, 5.0), "spacing": 3.0})
	path([spawn, Vector2(-70, 24), Vector2(-130, 30), h + Vector2(-8, -30)])
	_keep_clear.append([h + Vector2(-8, -20), 36.0])
	_keep_clear.append([ridge, 30.0])


## A long ravine across the northwest, shallow at both ends for sliding in.
func _scar() -> void:
	ravine([Vector2(-292, -118), Vector2(-240, -92), Vector2(-182, -116), Vector2(-124, -86), Vector2(-86, -44)], 12.0, 9.0, 1.6, 26.0)
	scatter.append({"scenes": _rocks(), "center": Vector2(-180, -100), "radius": 60, "count": 30, "scale": Vector2(5.0, 10.0), "spacing": 5.0})


## Round hills with a halfpipe between two of them.
func _hermit_hills(c: Vector2) -> void:
	hill(c.x, c.y, 11.0, 16)
	hill(c.x + 50, c.y - 14, 9.0, 13)
	hill(c.x + 24, c.y - 6, -4.0, 9)
	hill(c.x - 20, c.y + 40, 8.0, 12)
	landmark(HAL + "shrine_candles.gltf", c.x + 24, c.y - 6, 0, 1.6)
	scatter.append({"scenes": _pines(), "center": c + Vector2(10, 30), "radius": 40, "count": 50, "scale": Vector2(0.9, 1.4), "spacing": 6.0})
	_keep_clear.append([c + Vector2(24, 0), 44.0])


## Barrow mounds: steep round burial hills, great for slides and crest jumps.
func _barrows(c: Vector2) -> void:
	for k in 14:
		var a := k * 2.39996
		var r := 8.0 + 4.2 * sqrt(k) * 3.0
		var p := c + Vector2(cos(a), sin(a)) * r
		hill(p.x, p.y, 5.5 + fmod(k * 1.3, 2.5), 6.0 + fmod(k * 0.9, 2.0))
		if k % 3 == 0:
			landmark(HAL + "gravestone.gltf", p.x, p.y, k * 40.0, 1.4)
	tints.append({"pos": c, "radius": 50, "color": Color(0.30, 0.31, 0.27), "strength": 0.4})
	_keep_clear.append([c, 56.0])


## The Tor: one big steep hill with a long run-out, the best slide on the map.
func _tor(c: Vector2) -> void:
	hill(c.x, c.y, 24.0, 22)
	hill(c.x + 30, c.y + 30, 6.0, 20, 40, deg_to_rad(40))
	landmark(HAL + "post_skull.gltf", c.x, c.y, 0, 1.6)
	_keep_clear.append([c, 50.0])


## A pit with a ruined chapel inside.
func _sunken_chapel(c: Vector2) -> void:
	plateau(c.x, c.y, -6.0, 20, 16, 30, 1.4, 0.15, 90, 14)
	landmark(DUN + "wall_arched.gltf.glb", c.x, c.y - 4, 0, 1.4, {"kind": "box", "size": Vector2(5.6, 1.4), "height": 5.6})
	landmark(DUN + "wall_broken.gltf.glb", c.x - 6, c.y + 2, 90, 1.4, {"kind": "box", "size": Vector2(5.6, 1.4), "height": 5.6})
	landmark(HAL + "coffin_decorated.gltf", c.x + 3, c.y + 3, 30, 1.4)
	scatter.append({"scenes": _graves(), "center": c, "radius": 14, "count": 10, "scale": Vector2(1.0, 1.2), "spacing": 3.0})
	_keep_clear.append([c, 32.0])


func _hanged_wood(c: Vector2) -> void:
	scatter.append({"scenes": _dead(), "center": c, "radius": 44, "count": 70, "scale": Vector2(1.0, 1.6), "spacing": 4.5})
	scatter.append({"scenes": [HAL + "lantern_hanging.gltf", HAL + "post_skull.gltf"], "center": c, "radius": 40, "count": 12, "scale": Vector2(1.3, 1.5), "spacing": 8.0})
	tints.append({"pos": c, "radius": 50, "color": Color(0.24, 0.24, 0.22), "strength": 0.6})


func _bog(c: Vector2) -> void:
	for k in 7:
		var a := k * 0.9
		hill(c.x + cos(a) * 26.0, c.y + sin(a) * 18.0, -2.5, 10.0)
	tints.append({"pos": c, "radius": 48, "color": Color(0.18, 0.21, 0.18), "strength": 0.8})
	scatter.append({"scenes": _dead(), "center": c, "radius": 40, "count": 16, "scale": Vector2(0.9, 1.2), "spacing": 6.0})


func _battlefield(c: Vector2) -> void:
	scatter.append({"scenes": _bones() + [DUN + "sword_shield.gltf.glb"], "center": c, "radius": 40, "count": 60, "scale": Vector2(1.0, 1.5), "spacing": 2.5})
	scatter.append({"scenes": [MED + "props/flag_red.gltf", MED + "props/weaponrack.gltf"], "center": c, "radius": 34, "count": 8, "scale": Vector2(4.0, 5.0), "spacing": 8.0})
	tints.append({"pos": c, "radius": 44, "color": Color(0.33, 0.27, 0.24), "strength": 0.5})


func _crossroads() -> void:
	landmark(HAL + "plaque_candles.gltf", spawn.x, spawn.y - 8, 0, 1.2)
	scatter.append({"scenes": [HAL + "lantern_standing.gltf"], "along_paths": 18.0, "offset": 3.2, "scale": Vector2(1.3, 1.3)})
	_keep_clear.append([spawn, 16.0])


# -----------------------------------------------------------------------------
# Everywhere
# -----------------------------------------------------------------------------
func _clear(p: Vector2, extra := 0.0) -> bool:
	for kc in _keep_clear:
		if p.distance_to(kc[0]) < kc[1] + extra:
			return false
	return true


## Rolling hills and small sharp bumps that launch you when you're fast.
func _bumps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var lim := half_size - rim_band - 10.0
	var placed := 0
	while placed < 40:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not _clear(p, 10.0):
			continue
		hill(p.x, p.y, rng.randf_range(3.0, 8.0), rng.randf_range(10.0, 22.0), rng.randf_range(8.0, 20.0), rng.randf() * PI)
		placed += 1
	# Kickers: a few placed for good lines, the rest scattered.
	kicker(158, 10, 0, 2.6, 9.0)       # into the graveyard pit
	kicker(-70, -60, 90, 2.8, 9.0)     # at the foot of the Tor
	kicker(0, -120, 90, 2.4)           # down Pilgrim's Slope
	kicker(-20, 150, -90, 2.6)         # below the keep
	placed = 0
	while placed < 26:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not _clear(p, 6.0):
			continue
		kicker(p.x, p.y, rng.randf() * 360.0, rng.randf_range(2.0, 2.8), rng.randf_range(7.0, 9.0))
		_keep_clear.append([p, 12.0])
		placed += 1
	placed = 0
	while placed < 260:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not _clear(p):
			continue
		hill(p.x, p.y, rng.randf_range(0.9, 2.4), rng.randf_range(2.6, 4.6))
		placed += 1


## Holy springs: launch pads spread over the whole map.
func _pads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed * 3 + 1
	var lim := half_size - rim_band - 12.0
	var placed := 0
	while placed < 30:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not _clear(p, 4.0):
			continue
		var ok := true
		for q in pads:
			if p.distance_to(q) < 60.0:
				ok = false
				break
		if ok:
			pads.append(p)
			placed += 1


func _forests() -> void:
	var edge := half_size - 8.0
	# A dense forest along the cliffs keeps the edge readable.
	scatter.append({"scenes": _pines(), "ring": Vector2(edge - 50.0, edge - 4.0), "count": 1100, "scale": Vector2(1.0, 1.7), "spacing": 5.0})
	for c in [Vector2(130, -40), Vector2(-150, -170), Vector2(-240, 60), Vector2(140, 250), Vector2(-120, 240), Vector2(250, -60), Vector2(60, -230)]:
		scatter.append({"scenes": _pines(), "center": c, "radius": 34, "count": 55, "scale": Vector2(0.9, 1.4), "spacing": 6.0})
	scatter.append({"scenes": _pines(), "center": Vector2.ZERO, "radius": 260, "count": 160, "scale": Vector2(0.7, 1.2), "spacing": 10.0})
	scatter.append({"scenes": _dead(), "center": Vector2.ZERO, "radius": 260, "count": 90, "scale": Vector2(0.9, 1.3), "spacing": 10.0})
	scatter.append({"scenes": _rocks(), "center": Vector2.ZERO, "radius": 265, "count": 260, "scale": Vector2(4.0, 9.0), "spacing": 4.0})
	scatter.append({"scenes": _bones(), "center": Vector2.ZERO, "radius": 260, "count": 120, "scale": Vector2(1.0, 1.3), "spacing": 3.0})


func _pines() -> Array:
	return [HAL + "tree_pine_orange_large.gltf", HAL + "tree_pine_orange_medium.gltf",
			HAL + "tree_pine_yellow_large.gltf", HAL + "tree_pine_yellow_medium.gltf",
			HAL + "tree_pine_orange_small.gltf", HAL + "tree_pine_yellow_small.gltf"]


func _dead() -> Array:
	return [HAL + "tree_dead_large.gltf", HAL + "tree_dead_medium.gltf", HAL + "tree_dead_small.gltf", HAL + "tree_dead_large_decorated.gltf"]


func _rocks() -> Array:
	return [MED + "nature/rock_single_A.gltf", MED + "nature/rock_single_B.gltf", MED + "nature/rock_single_C.gltf",
			MED + "nature/rock_single_D.gltf", MED + "nature/rock_single_E.gltf"]


func _graves() -> Array:
	return [HAL + "grave_A.gltf", HAL + "grave_B.gltf", HAL + "gravestone.gltf", HAL + "gravemarker_A.gltf",
			HAL + "gravemarker_B.gltf", HAL + "grave_A_destroyed.gltf"]


func _bones() -> Array:
	return [HAL + "bone_A.gltf", HAL + "bone_B.gltf", HAL + "bone_C.gltf", HAL + "skull.gltf", HAL + "ribcage.gltf"]


func _pumpkins() -> Array:
	return [HAL + "pumpkin_orange.gltf", HAL + "pumpkin_yellow.gltf", HAL + "pumpkin_orange_small.gltf", HAL + "pumpkin_orange_jackolantern.gltf"]
