class_name MapDef
extends RefCounted
## The fixed layout of one map. The layout is identical every run; only chests,
## shrines, breakables and the boss altar are placed randomly (see PoiPlacer).
##
## Units are meters. The map spans -half_size..half_size on X and Z.
## +Z is south (toward the bottom of the screen).

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
