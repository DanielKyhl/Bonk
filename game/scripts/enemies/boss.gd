class_name Boss
extends Node3D
## The stage boss and its altar. The altar stands at one of the map's boss
## sites (picked per run) under a tall red beam. Press interact there any time
## to summon the boss; it is tuned so only a strong build can win. When
## he falls he drops legendary chests and the altar becomes a portal: step in
## to leave (and unlock the next map), or stay and fight on for more score.

signal summoned
signal defeated(pos: Vector3)
signal portal_entered

enum { WAITING, FIGHTING, DEFEATED, GONE }

const USE_RANGE := 5.0
const DISC_RADIUS := 6.0
const NOVA_EVERY := 6.0
const BOLTS_EVERY := 2.2
const SUMMON_EVERY := 14.0
const BLINK_RANGE := 34.0
const NOVA_COUNT := 16
const NOVA_SPEED := 9.0
const NOVA_DAMAGE := 18.0
const BOLT_SPEED := 17.0
const BOLT_DAMAGE := 22.0
const MAX_SHOTS := 128

var map: MapDef
var terrain: Terrain
var run: RunState
var player: Player
var enemies: EnemyManager
var fx: Fx

var state := WAITING
var altar := Vector3.ZERO
var discovered := false
var _disc: ShaderMaterial
var _beam: ShaderMaterial
var _t := 0.0
var _next_nova := 3.0
var _next_bolts := 1.5
var _next_summon := 8.0

# Projectiles: position, velocity, life, damage, sprite row.
var _sp := PackedVector3Array()
var _sv := PackedVector3Array()
var _sl := PackedFloat32Array()
var _sd := PackedFloat32Array()
var _sr := PackedInt32Array()
var _shots: SpriteBatch
var _camera: FollowCamera


func setup(m: MapDef, t: Terrain, props: Props, r: RunState, p: Player, e: EnemyManager, f: Fx, cam: FollowCamera) -> void:
	map = m
	terrain = t
	run = r
	player = p
	enemies = e
	fx = f
	_camera = cam
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed * 13 + 5
	var spot: Vector2 = map.boss_spots[rng.randi() % map.boss_spots.size()]
	altar = Vector3(spot.x, terrain.grid_height(spot.x, spot.y), spot.y)
	var model := MeshInstance3D.new()
	model.mesh = props.merged_mesh("res://assets/kaykit/halloween/shrine.gltf", true)
	model.position = altar
	model.scale = Vector3.ONE * 2.6
	add_child(model)
	for k in 6:
		var a := k * TAU / 6.0
		var c := MeshInstance3D.new()
		c.mesh = props.merged_mesh("res://assets/kaykit/halloween/skull_candle.gltf", true)
		var q := Vector2(spot.x + cos(a) * 5.0, spot.y + sin(a) * 5.0)
		c.position = Vector3(q.x, terrain.grid_height(q.x, q.y), q.y)
		c.scale = Vector3.ONE * 1.6
		add_child(c)
	var disc := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2.ONE * DISC_RADIUS * 2.0
	dq.orientation = PlaneMesh.FACE_Y
	disc.mesh = dq
	_disc = ShaderMaterial.new()
	_disc.shader = preload("res://shaders/rune_disc.gdshader")
	_disc.set_shader_parameter("color", map.boss.color)
	disc.material_override = _disc
	disc.position = altar + Vector3(0, 0.1, 0)
	add_child(disc)
	# A tall beam so the altar can be spotted from a distance.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 1.6
	cyl.height = 70.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	_beam = ShaderMaterial.new()
	_beam.shader = preload("res://shaders/beam.gdshader")
	_beam.set_shader_parameter("color", map.boss.color)
	_beam.set_shader_parameter("strength", 0.5)
	beam.material_override = _beam
	beam.position = altar + Vector3(0, 35.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_shots = SpriteBatch.new()
	_shots.setup(load("res://assets/sprites/boss_fx.png"), Vector2(4, 9), 24.0, 12.0)
	add_child(_shots)


## True when the player stands at the altar (to summon or use the portal).
func in_reach() -> bool:
	return (state == WAITING or state == DEFEATED) and Vector2(player.position.x - altar.x, player.position.z - altar.z).length() < USE_RANGE


func boss_index() -> int:
	return enemies.boss_index() if state == FIGHTING else -1


func _process(delta: float) -> void:
	_t += delta
	if not discovered and Vector2(player.position.x - altar.x, player.position.z - altar.z).length() < 90.0:
		discovered = true
	if in_reach() and Input.is_action_just_pressed("interact"):
		if state == WAITING:
			_summon()
		else:
			state = GONE
			portal_entered.emit()
	if state == FIGHTING:
		_fight(delta)
	_update_shots(delta)


func _summon() -> void:
	state = FIGHTING
	discovered = true
	_disc.set_shader_parameter("dim", 0.3)
	enemies.spawn(EnemyManager.BOSS, altar.x, altar.z - 4.0, Game.stage_hp_mult(), true, false, Game.stage_dmg_mult())
	fx.ring(altar, 14.0, map.boss.color, 0.8, 0.2)
	fx.pillar(altar, 1.0)
	_camera.add_shake(8.0)
	_next_nova = _t + 4.0
	_next_bolts = _t + 2.5
	_next_summon = _t + 9.0
	summoned.emit()


## Called by the run when the boss dies.
func on_defeated(pos: Vector3) -> void:
	state = DEFEATED
	_sp.clear()
	_sv.clear()
	_sl.clear()
	_sd.clear()
	_sr.clear()
	_show_portal()
	defeated.emit(pos)


func _show_portal() -> void:
	_disc.set_shader_parameter("color", Color(0.6, 0.9, 1.0))
	_disc.set_shader_parameter("dim", 1.0)
	_beam.set_shader_parameter("color", Color(0.6, 0.9, 1.0))


## For "Save & quit". A fight in progress is not kept: the boss waits again.
func save_state() -> Dictionary:
	return {"defeated": state == DEFEATED, "discovered": discovered}


func load_state(d: Dictionary) -> void:
	discovered = d.discovered
	if d.defeated:
		state = DEFEATED
		_show_portal()


func _fight(_delta: float) -> void:
	var i := enemies.boss_index()
	if i < 0:
		return
	var b := enemies.position_of(i)
	var enraged := enemies.hp[i] < enemies.max_hp[i] * 0.5
	var pace := 0.65 if enraged else 1.0
	var pp := player.position
	var d := Vector2(pp.x - b.x, pp.z - b.z)
	# Too far away: he steps out of the shadows right behind you.
	if d.length() > BLINK_RANGE:
		var back := Vector2(-player.facing.x, -player.facing.y) * 12.0
		var q := terrain.clamp_to_map(Vector2(pp.x, pp.z) + back, 6.0)
		fx.ring(b, 4.0, Color(0.6, 0.2, 0.9), 0.4, 0.15)
		Sound.play("blink")
		enemies.px[i] = q.x
		enemies.pz[i] = q.y
		fx.ring(Vector3(q.x, terrain.grid_height(q.x, q.y), q.y), 4.0, Color(0.6, 0.2, 0.9), 0.4, 0.15)
	var head := b + Vector3(0, 4.0, 0)
	if _t >= _next_nova:
		_next_nova = _t + NOVA_EVERY * pace
		var n := NOVA_COUNT + (8 if enraged else 0)
		Sound.play("nova", b)
		var off := randf() * TAU
		for k in n:
			var a := off + TAU * k / n
			_shoot(b + Vector3(0, 1.2, 0), Vector3(cos(a), 0, sin(a)) * NOVA_SPEED, NOVA_DAMAGE * Game.stage_dmg_mult(), map.boss.nova_row, 6.0)
	if _t >= _next_bolts:
		_next_bolts = _t + BOLTS_EVERY * pace
		var aim := (pp + Vector3(0, 1.0, 0) - head).normalized()
		Sound.play("bolt", head)
		for k in (5 if enraged else 3):
			var spread := (k - (2 if enraged else 1)) * 0.16
			_shoot(head, aim.rotated(Vector3.UP, spread) * BOLT_SPEED, BOLT_DAMAGE * Game.stage_dmg_mult(), map.boss.bolt_row, 4.0)
	if _t >= _next_summon:
		_next_summon = _t + SUMMON_EVERY * pace
		for k in 10:
			var a := TAU * k / 10.0
			var q := terrain.clamp_to_map(Vector2(pp.x + cos(a) * 9.0, pp.z + sin(a) * 9.0), 4.0)
			enemies.spawn(0, q.x, q.y, (1.0 + run.time / 140.0) * Game.stage_hp_mult(), true, false, Game.stage_dmg_mult())


func _shoot(from: Vector3, vel: Vector3, dmg: float, row: int, life: float) -> void:
	if _sp.size() >= MAX_SHOTS:
		return
	_sp.append(from)
	_sv.append(vel)
	_sl.append(life)
	_sd.append(dmg)
	_sr.append(row)


func _update_shots(delta: float) -> void:
	_shots.begin()
	var pp := player.position + Vector3(0, 1.0, 0)
	var k := 0
	while k < _sp.size():
		_sl[k] -= delta
		var p := _sp[k] + _sv[k] * delta
		# Stay a little above the ground.
		p.y = maxf(p.y, terrain.grid_height(p.x, p.z) + 0.8)
		_sp[k] = p
		var hit := Vector2(p.x - pp.x, p.z - pp.z).length() < 0.9 and absf(p.y - pp.y) < 1.6
		if hit:
			enemies.player_hit.emit(_sd[k], p, -1)
		if hit or _sl[k] <= 0.0:
			_sp.remove_at(k)
			_sv.remove_at(k)
			_sl.remove_at(k)
			_sd.remove_at(k)
			_sr.remove_at(k)
			continue
		var b := _camera.global_transform.basis
		var ang := atan2(_sv[k].dot(b.y), _sv[k].dot(b.x)) if _sr[k] == map.boss.bolt_row else 0.0
		_shots.add(p, int(_t * 10.0 + k) % 4, _sr[k], ang, 1.3)
		k += 1
	_shots.commit()
