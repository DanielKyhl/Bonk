class_name MapDef
extends RefCounted
## The fixed layout of one map. The layout is identical every run; only chests,
## shrines, breakables and the boss altar are placed randomly (see PoiPlacer).
##
## Units are meters. The map spans -half_size..half_size on X and Z.
## +Z is south (toward the bottom of the screen).

var title := ""
var half_size := 160.0
## Deterministic seed for scattered decoration (same every run).
var layout_seed := 1

## Gentle rolling ground everywhere: amplitude/wavelength pairs.
var rolling := Vector4(1.0, 12.9, 0.6, 7.9)
## Gaussian hills (h > 0) and bowls (h < 0). sx/sz are widths, rot in radians.
var hills: Array[Dictionary] = []
## Flat-topped plateaus with steep sides: r0 = flat top radius, r1 = foot radius.
var mesas: Array[Dictionary] = []
## Wooden ramps: base at pos, rising along yaw direction.
var ramps: Array[Dictionary] = []
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


func hill(x: float, z: float, h: float, sx: float, sz := -1.0, rot := 0.0) -> void:
	hills.append({"pos": Vector2(x, z), "h": h, "sx": sx, "sz": sx if sz < 0.0 else sz, "rot": rot})


func mesa(x: float, z: float, h: float, r0: float, r1: float) -> void:
	mesas.append({"pos": Vector2(x, z), "h": h, "r0": r0, "r1": r1})


func ramp(x: float, z: float, yaw_deg: float, length := 8.0, width := 4.0, height := 2.6) -> void:
	ramps.append({"pos": Vector2(x, z), "yaw": deg_to_rad(yaw_deg), "length": length, "width": width, "height": height})


func landmark(scene: String, x: float, z: float, yaw_deg := 0.0, scale := 1.0, solid := {}) -> void:
	landmarks.append({"scene": scene, "pos": Vector2(x, z), "yaw": deg_to_rad(yaw_deg), "scale": scale, "solid": solid})


func path(points: Array) -> void:
	var p := PackedVector2Array()
	for v in points:
		p.append(v)
	paths.append(p)
