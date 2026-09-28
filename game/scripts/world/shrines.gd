class_name Shrines
extends Node3D
## Shrines placed at random every run.
## - Prayer shrines: stand in the circle until it charges, then pick one of
##   three blessings (permanent stat boosts of random rarity).
## - Cursed altars: press interact to summon elites (each drops a golden chest).
## - Greed shrines: press interact for +25% gold, but 20% more enemies.

signal prayed(choices: Array[Dictionary])
signal cursed
signal greed_taken

enum { PRAYER, CURSED, GREED }
const COUNTS := [14, 6, 3]
const CHARGE_TIME := 4.0
const CHARGE_RADIUS := 4.0
const USE_RANGE := 3.0
const SPACING := 40.0
const COLORS := [Color(0.55, 0.8, 1.0), Color(1.0, 0.25, 0.2), Color(1.0, 0.8, 0.3)]

var map: MapDef
var terrain: Terrain
var run: RunState
var player: Player
var fx: Fx

var pos: Array[Vector3] = []
var kind: Array[int] = []
var used: Array[bool] = []
var charge := PackedFloat32Array()
var _discs: Array[ShaderMaterial] = []
var _models: Array[Node3D] = []
var _near := -1
var _inside := -1
var prayers := 0


func setup(m: MapDef, t: Terrain, props: Props, r: RunState, p: Player, f: Fx, avoid: Array[Vector3]) -> void:
	map = m
	terrain = t
	run = r
	player = p
	fx = f
	var models := [
		props.merged_mesh("res://assets/kaykit/halloween/shrine_candles.gltf", true),
		props.merged_mesh("res://assets/kaykit/halloween/plaque_candles.gltf", true),
		props.merged_mesh("res://assets/kaykit/dungeon/coin_stack_large.gltf.glb", true),
	]
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE * CHARGE_RADIUS * 2.0
	disc.orientation = PlaneMesh.FACE_Y
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed * 7 + 11
	var lim := map.half_size - map.rim_band - 8.0
	for k in 3:
		var placed := 0
		var tries := 0
		while placed < COUNTS[k] and tries < 2000:
			tries += 1
			var q := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
			if q.distance_to(map.spawn) < 40.0 or terrain.in_solid(q.x, q.y, 3.0) or terrain.grid_normal_y(q.x, q.y) < 0.9:
				continue
			var ok := true
			for c in pos:
				if Vector2(c.x, c.z).distance_to(q) < SPACING:
					ok = false
					break
			for c in avoid:
				if Vector2(c.x, c.z).distance_to(q) < 8.0:
					ok = false
					break
			if not ok:
				continue
			var at := Vector3(q.x, terrain.grid_height(q.x, q.y), q.y)
			pos.append(at)
			kind.append(k)
			used.append(false)
			charge.append(0.0)
			var mi := MeshInstance3D.new()
			mi.mesh = models[k]
			mi.position = at
			mi.rotation.y = rng.randf() * TAU
			mi.scale = Vector3.ONE * (1.8 if k == PRAYER else 1.6)
			add_child(mi)
			_models.append(mi)
			var d := MeshInstance3D.new()
			d.mesh = disc
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/rune_disc.gdshader")
			mat.set_shader_parameter("color", COLORS[k])
			mat.set_shader_parameter("progress", 0.0 if k == PRAYER else 1.0)
			d.material_override = mat
			d.position = at + Vector3(0, 0.08, 0)
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(d)
			_discs.append(mat)
			placed += 1


## Used shrines, for "Save & quit".
func save_state() -> Dictionary:
	var u := []
	for i in used.size():
		if used[i]:
			u.append(i)
	return {"used": u, "prayers": prayers}


func load_state(d: Dictionary) -> void:
	prayers = d.prayers
	for i: int in d.used:
		if i < used.size():
			used[i] = true
			_discs[i].set_shader_parameter("dim", 0.25)
			_discs[i].set_shader_parameter("progress", 0.0)


## The altar or greed shrine in reach (for the HUD prompt), or -1.
func nearest() -> int:
	return _near


## The prayer shrine you're standing in, or -1.
func praying() -> int:
	return _inside


func _process(delta: float) -> void:
	var pp := player.position
	_near = -1
	_inside = -1
	for i in pos.size():
		if used[i]:
			continue
		var d := Vector2(pos[i].x - pp.x, pos[i].z - pp.z).length()
		if absf(pos[i].y - pp.y) > 4.0:
			d = INF
		if kind[i] == PRAYER:
			if d < CHARGE_RADIUS:
				_inside = i
				charge[i] = minf(CHARGE_TIME, charge[i] + delta)
				if charge[i] >= CHARGE_TIME:
					_finish_prayer(i)
					continue
			else:
				charge[i] = maxf(0.0, charge[i] - delta * 0.5)
			_discs[i].set_shader_parameter("progress", charge[i] / CHARGE_TIME)
		elif d < USE_RANGE:
			_near = i
	if _near >= 0 and Input.is_action_just_pressed("interact"):
		_use(_near)


func _spend(i: int) -> void:
	used[i] = true
	_discs[i].set_shader_parameter("dim", 0.25)
	_discs[i].set_shader_parameter("progress", 0.0)
	fx.ring(pos[i], CHARGE_RADIUS * 1.5, COLORS[kind[i]], 0.5, 0.15)
	fx.sparks(pos[i] + Vector3(0, 1.0, 0), COLORS[kind[i]], 24)
	fx.pillar(pos[i], 0.6)


func _finish_prayer(i: int) -> void:
	_spend(i)
	prayers += 1
	prayed.emit(Defs.roll_blessings(run.stats.luck))


func _use(i: int) -> void:
	_spend(i)
	if kind[i] == CURSED:
		cursed.emit()
	else:
		run.blessings["gold"] = run.blessings.get("gold", 0.0) + 0.25
		run.recompute()
		greed_taken.emit()
