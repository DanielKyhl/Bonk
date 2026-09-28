class_name Chests
extends Node3D
## Chests scattered over the map at random every run (some on pillar tops).
## Walk up and press interact to open one: it costs gold, more for every
## chest you open, and gives a random item. Golden chests (dropped by elites
## and bosses) are free and never common.

signal opened(item: String, pos: Vector3)

const COUNT := 48
const SPACING := 28.0
const OPEN_RANGE := 2.8
const BASE_COST := 15
const COST_STEP := 10
const CHEST := "res://assets/kaykit/dungeon/chest.glb"
const CHEST_GOLD := "res://assets/kaykit/dungeon/chest_gold.glb"

var map: MapDef
var terrain: Terrain
var run: RunState
var player: Player
var fx: Fx
var bought := 0

## Per chest: position, golden?, minimum rarity, opened?, visual.
var pos: Array[Vector3] = []
var golden: Array[bool] = []
var min_rarity: Array[int] = []
var is_open: Array[bool] = []
var _nodes: Array[Node3D] = []
var _mesh: Mesh
var _mesh_gold: Mesh
var _glints: SpriteBatch
var _t := 0.0
var _near := -1


func setup(m: MapDef, t: Terrain, props: Props, r: RunState, p: Player, f: Fx) -> void:
	map = m
	terrain = t
	run = r
	player = p
	fx = f
	_mesh = props.merged_mesh(CHEST, true)
	_mesh_gold = props.merged_mesh(CHEST_GOLD, true)
	_glints = SpriteBatch.new()
	_glints.setup(load("res://assets/sprites/weapons_fx.png"), Vector2(4, 5), 24.0, 12.0)
	add_child(_glints)
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed
	# Sky chests: some pillars have a chest on top (jump or launch up there).
	for sp in map.pillar_spots:
		if rng.randf() < 0.35:
			var top := terrain.grid_height(sp.x, sp.y)
			_add(Vector3(sp.x, top, sp.y), false, 1)
	var lim := map.half_size - map.rim_band - 6.0
	var tries := 0
	var placed := 0
	while placed < COUNT and tries < COUNT * 40:
		tries += 1
		var q := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if q.distance_to(map.spawn) < 30.0 or terrain.in_solid(q.x, q.y, 1.5) or terrain.grid_normal_y(q.x, q.y) < 0.85:
			continue
		var crowded := false
		for c in pos:
			if Vector2(c.x, c.z).distance_to(q) < SPACING:
				crowded = true
				break
		if crowded:
			continue
		_add(Vector3(q.x, terrain.grid_height(q.x, q.y), q.y), false, 0)
		placed += 1


func cost() -> int:
	return BASE_COST + COST_STEP * bought


## Drops a free golden chest (elites, bosses).
func spawn_golden(at: Vector3, rarity := 1) -> void:
	var q := terrain.clamp_to_map(Vector2(at.x, at.z), 4.0)
	_add(Vector3(q.x, terrain.grid_height(q.x, q.y), q.y), true, rarity)
	fx.ring(pos[-1], 3.0, Color(1.0, 0.8, 0.35), 0.5, 0.15)


## The chest in reach, or -1. HUD reads this for its prompt.
func nearest() -> int:
	return _near


func _add(p: Vector3, gold: bool, rarity: int) -> void:
	pos.append(p)
	golden.append(gold)
	min_rarity.append(rarity)
	is_open.append(false)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_gold if gold else _mesh
	mi.position = p
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * 1.3
	add_child(mi)
	_nodes.append(mi)


func _process(delta: float) -> void:
	_t += delta
	var pp := player.position
	_near = -1
	var best := OPEN_RANGE * OPEN_RANGE
	_glints.begin()
	for i in pos.size():
		if is_open[i]:
			continue
		var d := Vector2(pos[i].x - pp.x, pos[i].z - pp.z).length_squared()
		if d < best and absf(pos[i].y - pp.y) < 3.0:
			best = d
			_near = i
		# A twinkle above chests within sight so they're easy to spot.
		if d < 3600.0:
			var f := int(_t * 6.0 + i * 1.7) % 12
			if f < 4:
				_glints.add(pos[i] + Vector3(0, 1.9, 0), f, 4, 0.0, 0.7 if not golden[i] else 1.0)
	_glints.commit()
	if _near >= 0 and Input.is_action_just_pressed("interact"):
		_open(_near)


func _open(i: int) -> void:
	if not golden[i]:
		var c := cost()
		if run.gold < c:
			fx.text(pos[i], "NEED %d GOLD" % c, Color(0.9, 0.3, 0.3), 10)
			return
		run.spend_gold(c)
		bought += 1
	is_open[i] = true
	_nodes[i].visible = false
	var item := Defs.roll_item(run.stats.luck, min_rarity[i])
	var col: Color = Defs.RARITIES[Defs.ITEMS[item].rarity].color
	fx.ring(pos[i], 3.5, col, 0.5, 0.18)
	fx.sparks(pos[i] + Vector3(0, 1.0, 0), col, 24)
	fx.pillar(pos[i], 0.6)
	run.add_item(item)
	opened.emit(item, pos[i])
