class_name MapDef
extends RefCounted
## The fixed layout of one map. The layout is identical every run; only chests,
## shrines, breakables and the boss altar are placed randomly (see PoiPlacer).
##
## Units are meters. The map spans -half_size..half_size on X and Z.
## +Z is south (toward the bottom of the screen).

var id := ""
var title := ""
var half_size := 160.0
## The edges curve up into a quarter-pipe this wide and high, then sheer cliffs.
var rim_band := 30.0
var rim_height := 10.0
## Deterministic seed for scattered decoration (same every run).
var layout_seed := 1

## Gentle rolling ground everywhere: amplitude/wavelength pairs.
var rolling := Vector4(1.0, 12.9, 0.6, 7.9)
## Gaussian hills (h > 0) and bowls (h < 0). sx/sz are widths, rot in radians.
var hills: Array[Dictionary] = []
## Flat-topped plateaus with steep sides: r0 = flat top radius, r1 = foot radius.
var mesas: Array[Dictionary] = []
## Cliff-edged plateaus (h > 0) and pits (h < 0) with rugged outlines. See plateau().
var cliffs: Array[Dictionary] = []
## Steep-walled trenches along a polyline that shallow out at both ends. See ravine().
var ravines: Array[Dictionary] = []
## Launch pads (holy springs).
var pads: Array[Vector2] = []
## Dirt paths, drawn into the ground colors.
var paths: Array[PackedVector2Array] = []
## Landmarks: {scene, pos, yaw, scale, solid: {kind: "box"/"cyl", size: Vector2 or radius, height}}
var landmarks: Array[Dictionary] = []
## Decoration scatter rules, see Props.
var scatter: Array[Dictionary] = []
## Tall pillars that sky chests can sit on.
var pillar_spots: Array[Vector2] = []
## Candidate spots for the boss altar (one is picked per run).
var boss_spots: Array[Vector2] = []
var spawn := Vector2.ZERO

## Enemies: basic, fast, tank, caster, then the boss (see EnemyManager).
## speed in m/s, radius in m; scale is the sprite's pixel scale; anim_speed
## is the speed at which the walk plays at its normal rate.
var enemy_types: Array[Dictionary] = [
	{"name": "Skeleton", "sprite": "skeleton", "attack": "slash", "radius": 0.5, "scale": 1.0, "speed": 6.2, "hp": 20.0, "dmg": 8.0, "xp": 1, "anim_speed": 6.2},
	{"name": "Ghoul", "sprite": "ghoul", "attack": "slash", "radius": 0.45, "scale": 1.0, "speed": 9.6, "hp": 12.0, "dmg": 6.0, "xp": 1, "anim_speed": 8.0},
	{"name": "Skeleton Warrior", "sprite": "skeleton_warrior", "attack": "slash", "radius": 0.95, "scale": 1.5, "speed": 4.2, "hp": 150.0, "dmg": 18.0, "xp": 6, "anim_speed": 4.2},
	{"name": "Skeleton Mage", "sprite": "skeleton_mage", "attack": "spellcast", "radius": 0.5, "scale": 1.0, "speed": 4.6, "hp": 36.0, "dmg": 10.0, "xp": 3, "anim_speed": 4.6},
	{"name": "Varnoth, the Lich King", "sprite": "lich", "attack": "spellcast", "radius": 1.6, "scale": 3.0, "speed": 5.5, "hp": 60000.0, "dmg": 35.0, "xp": 0, "anim_speed": 5.5},
]
## The boss: banner lines, colors, and which boss_fx rows its shots use.
var boss := {
	"name": "Varnoth, the Lich King", "rises": "The dead king rises", "falls": "The Lich King has fallen",
	"cleansed": "The Vale is cleansed.", "color": Color(1.0, 0.2, 0.15), "bolt_row": 0, "nova_row": 1,
}

## Ground palette.
var grass := Color(0.36, 0.50, 0.24)
var grass_dry := Color(0.55, 0.52, 0.27)
var dirt := Color(0.50, 0.38, 0.25)
var rock := Color(0.52, 0.50, 0.47)
var low_tint := Color(0.30, 0.42, 0.30)
## Regions with their own ground tint: {pos, radius, color, strength}
var tints: Array[Dictionary] = []

## Sky and light.
var sky_top := Color(0.36, 0.52, 0.72)
var sky_horizon := Color(0.80, 0.78, 0.70)
var sun_color := Color(1.0, 0.93, 0.80)
var sun_energy := 1.0
var fog_color := Color(0.74, 0.74, 0.70)
## Pixel look: ambient light, background, and how props are toned down.
var ambient := Color(0.30, 0.27, 0.40)
var ambient_energy := 1.0
var background := Color(0.05, 0.04, 0.07)
var sun_elevation := 38.0
var sun_yaw := 128.0
var prop_saturation := 0.45
var prop_value := 0.72
var prop_grade := Color(1.0, 0.94, 0.9)


const MED := "res://assets/kaykit/medieval/"
const HAL := "res://assets/kaykit/halloween/"
const DUN := "res://assets/kaykit/dungeon/"

## Places random bumps, kickers and pads keep clear of: [center, radius].
var keep_clear: Array = []


func is_clear(p: Vector2, extra := 0.0) -> bool:
	for kc in keep_clear:
		if p.distance_to(kc[0]) < kc[1] + extra:
			return false
	return true


## Rolling hills, kickers and small sharp bumps scattered over open ground.
func add_bumps(hills_n: int, kickers_n: int, bumps_n: int, hill_h := Vector2(3.0, 8.0)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var lim := half_size - rim_band - 10.0
	var placed := 0
	while placed < hills_n:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not is_clear(p, 10.0):
			continue
		hill(p.x, p.y, rng.randf_range(hill_h.x, hill_h.y), rng.randf_range(10.0, 22.0), rng.randf_range(8.0, 20.0), rng.randf() * PI)
		placed += 1
	placed = 0
	while placed < kickers_n:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not is_clear(p, 6.0):
			continue
		kicker(p.x, p.y, rng.randf() * 360.0, rng.randf_range(2.0, 2.8), rng.randf_range(7.0, 9.0))
		keep_clear.append([p, 12.0])
		placed += 1
	placed = 0
	while placed < bumps_n:
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not is_clear(p):
			continue
		hill(p.x, p.y, rng.randf_range(0.9, 2.4), rng.randf_range(2.6, 4.6))
		placed += 1


## Holy springs spread over the map, at least `apart` meters from each other.
func add_pads(n: int, apart := 60.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed * 3 + 1
	var lim := half_size - rim_band - 12.0
	var placed := 0
	var tries := 0
	while placed < n and tries < 5000:
		tries += 1
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if not is_clear(p, 4.0):
			continue
		var ok := true
		for q in pads:
			if p.distance_to(q) < apart:
				ok = false
				break
		if ok:
			pads.append(p)
			placed += 1


func pines() -> Array:
	return [HAL + "tree_pine_orange_large.gltf", HAL + "tree_pine_orange_medium.gltf",
			HAL + "tree_pine_yellow_large.gltf", HAL + "tree_pine_yellow_medium.gltf",
			HAL + "tree_pine_orange_small.gltf", HAL + "tree_pine_yellow_small.gltf"]


func dead_trees() -> Array:
	return [HAL + "tree_dead_large.gltf", HAL + "tree_dead_medium.gltf", HAL + "tree_dead_small.gltf", HAL + "tree_dead_large_decorated.gltf"]


func rocks() -> Array:
	return [MED + "nature/rock_single_A.gltf", MED + "nature/rock_single_B.gltf", MED + "nature/rock_single_C.gltf",
			MED + "nature/rock_single_D.gltf", MED + "nature/rock_single_E.gltf"]


func graves() -> Array:
	return [HAL + "grave_A.gltf", HAL + "grave_B.gltf", HAL + "gravestone.gltf", HAL + "gravemarker_A.gltf",
			HAL + "gravemarker_B.gltf", HAL + "grave_A_destroyed.gltf"]


func bones() -> Array:
	return [HAL + "bone_A.gltf", HAL + "bone_B.gltf", HAL + "bone_C.gltf", HAL + "skull.gltf", HAL + "ribcage.gltf"]


func pumpkins() -> Array:
	return [HAL + "pumpkin_orange.gltf", HAL + "pumpkin_yellow.gltf", HAL + "pumpkin_orange_small.gltf", HAL + "pumpkin_orange_jackolantern.gltf"]


func hill(x: float, z: float, h: float, sx: float, sz := -1.0, rot := 0.0) -> void:
	hills.append({"pos": Vector2(x, z), "h": h, "sx": sx, "sz": sx if sz < 0.0 else sz, "rot": rot})


func mesa(x: float, z: float, h: float, r0: float, r1: float) -> void:
	mesas.append({"pos": Vector2(x, z), "h": h, "r0": r0, "r1": r1})


## A raised shelf with sheer cliffs. rx/rz are the radii of its (rotated)
## outline, edge the width of the cliff face, rough how jagged the rim is.
## slope_deg (if given) turns the rim facing that direction into a natural
## ramp slope_len meters long, spread over slope_width_deg degrees.
func plateau(x: float, z: float, h: float, rx: float, rz := -1.0, rot_deg := 0.0, edge := 1.4, rough := 0.12,
		slope_deg := INF, slope_len := 16.0, slope_width_deg := 50.0) -> void:
	cliffs.append({"pos": Vector2(x, z), "h": h, "rx": rx, "rz": rx if rz < 0.0 else rz, "rot": deg_to_rad(rot_deg),
			"edge": edge, "rough": rough, "slope": slope_deg, "slope_len": slope_len, "slope_width": slope_width_deg})


## A kicker: a grassy rise that curves up to a sharp lip and drops away, so
## anything fast coming up it flies. yaw_deg is the direction you ride it.
func kicker(x: float, z: float, yaw_deg: float, h := 2.4, length := 8.0, width := 5.0) -> void:
	var d := Vector2(cos(deg_to_rad(yaw_deg)), sin(deg_to_rad(yaw_deg)))
	plateau(x + d.x, z + d.y, h, width * 0.5, 1.4, yaw_deg + 90.0, 1.0, 0.08, yaw_deg + 180.0, length, 70.0)
	cliffs[-1]["kick"] = true


## A rock spire: a small, tall plateau you can't climb.
func spire(x: float, z: float, h: float, r: float) -> void:
	var k := fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)
	plateau(x, z, h, r, r * (0.8 + 0.4 * k), k * 180.0, 0.8, 0.28)


## A trench along points (Vector2s), width wide and depth deep with steep
## walls; the floor rises back to ground level over `taper` meters at each end.
func ravine(points: Array, width: float, depth: float, edge := 1.4, taper := 16.0) -> void:
	var p := PackedVector2Array()
	for v in points:
		p.append(v)
	ravines.append({"points": p, "width": width, "depth": depth, "edge": edge, "taper": taper})


func landmark(scene: String, x: float, z: float, yaw_deg := 0.0, scale := 1.0, solid := {}) -> void:
	landmarks.append({"scene": scene, "pos": Vector2(x, z), "yaw": deg_to_rad(yaw_deg), "scale": scale, "solid": solid})


func path(points: Array) -> void:
	var p := PackedVector2Array()
	for v in points:
		p.append(v)
	paths.append(p)
