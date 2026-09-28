class_name WeaponSystem
extends Node3D
## Fires every weapon the hero owns. Weapon numbers come from Defs.WEAPONS;
## every hit goes through hit(), which applies damage stats and crits.

const MAX_PROJ := 64

var run: RunState
var player: Player
var enemies: EnemyManager
var fx: Fx
var camera: FollowCamera

var _cd := {}
var _t := 0.0
var _proj: Array[Dictionary] = []
## Pixel sprites for orbs, the flail head, projectiles and smite bursts
## (atlas rows: 0 orb, 1 flail, 2 javelin, 3 axe, 4 smite).
var _sprites: SpriteBatch
var _orb_count := 0
var _orb_pos: Array[Vector3] = []
var _orb_hits := {}
var _aura: MeshInstance3D
var _flail_pos := Vector3.ZERO
var _bursts: Array[Dictionary] = []
var _flail_t := -1.0
var _flail_r := 3.0
var _smites: Array[Dictionary] = []
var _sweeps_queued: Array[float] = []
var _num_at := {}   ## enemy index -> time of its last damage number


func setup(r: RunState, p: Player, e: EnemyManager, f: Fx, cam: FollowCamera) -> void:
	run = r
	player = p
	enemies = e
	fx = f
	camera = cam
	_sprites = SpriteBatch.new()
	_sprites.setup(load("res://assets/sprites/weapons_fx.png"), Vector2(4, 5), 24.0, 12.0)
	add_child(_sprites)
	_orb_pos.resize(8)

	_aura = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	_aura.mesh = q
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/glow_disc.gdshader")
	_aura.material_override = am
	_aura.visible = false
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)



# -----------------------------------------------------------------------------
# Stats
# -----------------------------------------------------------------------------
func wstat(id: String, key: String) -> float:
	var w: Dictionary = Defs.WEAPONS[id]
	var lvl: int = run.weapons.get(id, 1)
	var v := float(w.get(key, 0.0))
	v += float(w.per_level.get(key, 0.0)) * (lvl - 1)
	for m: int in w.milestones:
		if lvl >= m:
			v += float(w.milestones[m].get(key, 0.0))
	return v


func cooldown(id: String) -> float:
	return maxf(0.12, wstat(id, "cooldown") / run.stats.attack_speed)


func area(id: String) -> float:
	return wstat(id, "area") * run.stats.area


func count(id: String) -> int:
	return int(wstat(id, "count") + run.stats.count)


## Applies weapon damage to enemy i. Returns true if it killed.
func hit(i: int, base: float, push: Vector2) -> bool:
	var dmg: float = base * run.stats.damage
	var crit: bool = randf() < run.stats.crit
	if crit:
		dmg *= run.stats.crit_mult
	var pos := enemies.position_of(i)
	# At most one number per enemy every quarter second (crits always show).
	if crit or _num_at.get(i, -1.0) < _t - 0.25:
		_num_at[i] = _t
		fx.number(pos, dmg, crit)
		if _num_at.size() > 2000:
			_num_at.clear()
	fx.sparks(pos + Vector3(0, 1.1, 0), Color(1.0, 0.9, 0.6), 2)
	return enemies.damage(i, dmg, push)


# -----------------------------------------------------------------------------
# Update
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	var has_orbs := false
	var has_aura := false
	for id: String in run.weapons:
		var kind: String = Defs.WEAPONS[id].kind
		if kind == "orbit":
			has_orbs = true
			_update_orbs(id, delta)
			continue
		if kind == "aura":
			has_aura = true
		_cd[id] = _cd.get(id, 0.3) - delta
		if kind == "aura":
			_update_aura(id)
		if _cd[id] > 0.0:
			continue
		_cd[id] = cooldown(id)
		match kind:
			"sweep":
				for k in count(id):
					_sweeps_queued.append(_t + k * 0.16)
				_flail_r = area(id)
			"javelin":
				_fire_javelins(id)
			"smite":
				_queue_smites(id)
			"aura":
				_aura_tick(id)
			"axes":
				_throw_axes(id)
	if not has_orbs:
		_orb_count = 0
	if not has_aura:
		_aura.visible = false
	_sprites.begin()
	_run_sweeps(delta)
	_run_smites()
	_update_projectiles(delta)
	_draw_sprites(delta)
	_sprites.commit()


func _draw_sprites(delta: float) -> void:
	var pulse := int(_t * 8.0) % 4
	for k in _orb_count:
		_sprites.add(_orb_pos[k], (pulse + k) % 4, 0)
	if _flail_t >= 0.0:
		_sprites.add(_flail_pos, int(_t * 20.0) % 4, 1)
	var i := 0
	while i < _bursts.size():
		var b := _bursts[i]
		b.t += delta
		if b.t >= 0.24:
			_bursts.remove_at(i)
			continue
		_sprites.add(b.pos, int(b.t / 0.06), 4, 0.0, 1.6)
		i += 1


## Screen-space angle of a world direction, for pointing projectile sprites.
func _screen_angle(dir: Vector3) -> float:
	var b := camera.global_transform.basis
	return atan2(dir.dot(b.y), dir.dot(b.x))


# --- Sweep (Radiant Flail) -----------------------------------------------------
func _run_sweeps(delta: float) -> void:
	var i := 0
	while i < _sweeps_queued.size():
		if _sweeps_queued[i] <= _t:
			_sweep("radiant_flail")
			_sweeps_queued.remove_at(i)
		else:
			i += 1
	if _flail_t >= 0.0:
		_flail_t += delta
		var a := _flail_t / 0.22 * TAU
		var r := _flail_r * 0.85
		_flail_pos = player.position + Vector3(cos(a) * r, 1.1, sin(a) * r)
		if _flail_t >= 0.22:
			_flail_t = -1.0


func _sweep(id: String) -> void:
	if not run.weapons.has(id):
		return
	var r := area(id)
	var p := player.position
	fx.ring(p, r, Defs.WEAPONS[id].color, 0.3, 0.12)
	_flail_t = 0.0
	_flail_r = r
	player.model.swing()
	var knock := wstat(id, "knock")
	var dmg := wstat(id, "damage")
	for i in enemies.query(p.x, p.z, r):
		var d := Vector2(enemies.px[i] - p.x, enemies.pz[i] - p.z)
		var n := d.normalized() if d.length() > 0.01 else Vector2(1, 0)
		hit(i, dmg, n * knock)


# --- Javelins ---------------------------------------------------------------------
func _fire_javelins(id: String) -> void:
	var p := player.position
	var target := enemies.nearest(p.x, p.z, 32.0)
	var dir := player.facing
	if target >= 0:
		dir = Vector2(enemies.px[target] - p.x, enemies.pz[target] - p.z).normalized()
	var n := count(id)
	for k in n:
		var a := (k - (n - 1) * 0.5) * 0.14
		var d := dir.rotated(a)
		var sp := wstat(id, "speed") + maxf(0.0, Vector2(player.vel.x, player.vel.z).dot(d))
		_add_proj({"kind": "javelin", "id": id, "pos": p + Vector3(0, 1.4, 0), "vel": Vector3(d.x * sp, 0, d.y * sp),
			"life": 1.1, "pierce": int(wstat(id, "pierce")), "hits": [], "dmg": wstat(id, "damage"), "knock": wstat(id, "knock")})


# --- Axes -----------------------------------------------------------------------------
func _throw_axes(id: String) -> void:
	var p := player.position
	for k in count(id):
		var a := randf() * TAU
		var hv := Vector2(cos(a), sin(a)) * randf_range(5.0, 9.0) + Vector2(player.vel.x, player.vel.z) * 0.6
		_add_proj({"kind": "axe", "id": id, "pos": p + Vector3(0, 1.6, 0), "vel": Vector3(hv.x, 21.0, hv.y),
			"life": 3.0, "pierce": int(wstat(id, "pierce")), "hits": [], "dmg": wstat(id, "damage"), "knock": wstat(id, "knock")})


func _add_proj(pr: Dictionary) -> void:
	if _proj.size() >= MAX_PROJ:
		_proj.remove_at(0)
	_proj.append(pr)


func _update_projectiles(delta: float) -> void:
	var i := 0
	while i < _proj.size():
		var pr := _proj[i]
		pr.life -= delta
		var vel: Vector3 = pr.vel
		if pr.kind == "axe":
			vel.y -= 45.0 * delta
			pr.vel = vel
		var pos: Vector3 = pr.pos + vel * delta
		pr.pos = pos
		if pr.kind == "javelin":
			_sprites.add(pos, int(_t * 12.0) % 4, 2, _screen_angle(vel))
		else:
			_sprites.add(pos, 0, 3, -_t * 14.0 * signf(vel.x + 0.01), 1.2)
		var ground := enemies.terrain.grid_height(pos.x, pos.z)
		var low := pos.y - ground < 3.2
		if low:
			for e in enemies.query(pos.x, pos.z, 0.8):
				if pr.hits.has(e):
					continue
				pr.hits.append(e)
				var push := Vector2(vel.x, vel.z).normalized() * float(pr.knock)
				hit(e, pr.dmg, push)
				pr.pierce -= 1
				if pr.pierce < 0:
					pr.life = 0.0
					break
		if pr.kind == "axe" and pos.y < ground:
			fx.dust(Vector3(pos.x, ground, pos.z), 5)
			pr.life = 0.0
		if pr.life <= 0.0:
			_proj.remove_at(i)
			continue
		i += 1


# --- Orbs -------------------------------------------------------------------------------
func _update_orbs(id: String, delta: float) -> void:
	var n := mini(count(id), _orb_pos.size())
	var r := area(id)
	var spin := wstat(id, "spin")
	var dmg := wstat(id, "damage")
	var hit_cd := cooldown(id)
	var p := player.position
	_orb_count = n
	for k in n:
		var a := _t * spin + TAU * k / n
		var op := p + Vector3(cos(a) * r, 1.2 + sin(_t * 3.0 + k) * 0.2, sin(a) * r)
		_orb_pos[k] = op
		for e in enemies.query(op.x, op.z, 0.55):
			var key := e * 16 + k
			if _orb_hits.get(key, -1.0) > _t:
				continue
			_orb_hits[key] = _t + hit_cd
			var push := Vector2(enemies.px[e] - p.x, enemies.pz[e] - p.z).normalized() * wstat(id, "knock")
			hit(e, dmg, push)
	if _orb_hits.size() > 4000:
		_orb_hits.clear()


# --- Smite ------------------------------------------------------------------------------
func _queue_smites(id: String) -> void:
	var p := player.position
	var candidates := enemies.query(p.x, p.z, wstat(id, "range"))
	var n := count(id)
	for k in n:
		var target := Vector3.ZERO
		if candidates.size() > 0:
			var e := candidates[randi() % candidates.size()]
			target = enemies.position_of(e)
		else:
			var a := randf() * TAU
			target = p + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 10.0)
			target.y = enemies.terrain.grid_height(target.x, target.z)
		_smites.append({"at": _t + 0.18 + k * 0.08, "pos": target, "id": id})
		fx.ring(target, area(id) * 1.1, Color(1.0, 0.95, 0.7), 0.25, 0.06)


func _run_smites() -> void:
	var i := 0
	while i < _smites.size():
		var s := _smites[i]
		if s.at > _t:
			i += 1
			continue
		var pos: Vector3 = s.pos
		var r := area(s.id)
		fx.pillar(pos)
		fx.ring(pos, r * 1.4, Color(1.0, 0.92, 0.65), 0.35)
		_bursts.append({"pos": pos + Vector3(0, 1.0, 0), "t": 0.0})
		fx.sparks(pos + Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.75), 10)
		for e in enemies.query(pos.x, pos.z, r):
			var push := Vector2(enemies.px[e] - pos.x, enemies.pz[e] - pos.z).normalized() * wstat(s.id, "knock")
			hit(e, wstat(s.id, "damage"), push)
		_smites.remove_at(i)


# --- Aura (Consecration) ------------------------------------------------------------
func _aura_radius(id: String) -> float:
	return area(id) * (1.0 + clampf((player.speed() - 12.5) / 40.0, 0.0, 0.7))


func _update_aura(id: String) -> void:
	_aura.visible = true
	var r := _aura_radius(id)
	var p := player.position
	var g := enemies.terrain.grid_height(p.x, p.z)
	_aura.global_position = Vector3(p.x, g + 0.1, p.z)
	_aura.scale = Vector3(r, 1.0, r)


func _aura_tick(id: String) -> void:
	var p := player.position
	for e in enemies.query(p.x, p.z, _aura_radius(id)):
		hit(e, wstat(id, "damage"), Vector2.ZERO)
