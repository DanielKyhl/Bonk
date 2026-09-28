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
## Pixel sprites for orbs, the flail head, projectiles and bursts
## (atlas rows: 0 orb, 1 flail, 2 javelin, 3 axe, 4 smite, 5 claw slash,
## 6 chain link, 7 ice shard, 8 soul blade, 9 soul skull, 10 dragon fire).
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
var _heal_acc := 0.0   ## Lifesteal gathered this frame, healed once per frame.
var _later: Array[Dictionary] = []   ## Delayed attacks: {at, call} (extra breaths, lashes...).
var _puffs: Array[Dictionary] = []   ## Dragon fire: {pos, vel, t, life}.
var _slashes: Array[Dictionary] = [] ## Claw marks: {dir, side, t, r}.
var _lashes: Array[Dictionary] = []  ## Chains: {dir, len, t}.
var _rifts: Array[Dictionary] = []   ## Time rifts: {pos, r, t, life, next, id}.
var _rift_mesh: Array[MeshInstance3D] = []


func setup(r: RunState, p: Player, e: EnemyManager, f: Fx, cam: FollowCamera) -> void:
	run = r
	player = p
	enemies = e
	fx = f
	camera = cam
	_sprites = SpriteBatch.new()
	_sprites.setup(load("res://assets/sprites/weapons_fx.png"), Vector2(4, 11), 24.0, 12.0, 2.0)
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
	for k in 6:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var rm := ShaderMaterial.new()
		rm.shader = am.shader
		rm.set_shader_parameter("color", Defs.WEAPONS.time_rift.color)
		mi.material_override = rm
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rift_mesh.append(mi)



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


## Applies weapon damage to enemy i (and chills it for slow_secs, or by the
## chill stat's chance). Returns true if it killed.
func hit(i: int, base: float, push: Vector2, slow_secs := 0.0) -> bool:
	var dmg: float = base * run.stats.damage
	var crit: bool = randf() < run.stats.crit
	if crit:
		dmg *= run.stats.crit_mult
	if run.stats.execute > 0.0 and enemies.elite[i] == 0 and randf() < run.stats.execute:
		dmg = maxf(dmg, enemies.hp[i])
		crit = true
	_heal_acc += dmg * run.stats.lifesteal
	if slow_secs > 0.0:
		enemies.slow(i, slow_secs)
	elif run.stats.chill > 0.0 and randf() < run.stats.chill:
		enemies.slow(i, 2.0)
	var pos := enemies.position_of(i)
	Sound.play("crit" if crit else "hit", pos)
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
			"cone":
				for k in count(id):
					_later.append({"at": _t + k * 0.22, "call": _breathe.bind(id)})
			"chain":
				for k in count(id):
					_later.append({"at": _t + k * 0.12, "call": _chain.bind(id, k)})
			"claw":
				for k in count(id):
					_later.append({"at": _t + k * 0.12, "call": _claw.bind(id, k)})
			"whip":
				for k in count(id):
					_later.append({"at": _t + k * 0.2, "call": _lash.bind(id, k)})
			"shards":
				_fire_shards(id)
			"slam":
				for k in count(id):
					_later.append({"at": _t + k * 0.35, "call": _slam.bind(id, k)})
			"boomerang":
				_throw_blades(id)
			"homing":
				_loose_skulls(id)
			"rift":
				for k in count(id):
					_open_rift(id, k)
	if not has_orbs:
		_orb_count = 0
	if not has_aura:
		_aura.visible = false
	_sprites.begin()
	_run_later()
	_run_sweeps(delta)
	_run_smites()
	_run_rifts(delta)
	_update_projectiles(delta)
	_draw_sprites(delta)
	_sprites.commit()
	if _heal_acc > 0.0:
		run.heal(_heal_acc)
		_heal_acc = 0.0


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
	i = 0
	while i < _puffs.size():
		var pf := _puffs[i]
		pf.t += delta
		if pf.t >= pf.life:
			_puffs.remove_at(i)
			continue
		i += 1
		if pf.t < 0.0:
			continue
		pf.pos += pf.vel * delta
		var f: float = pf.t / pf.life
		_sprites.add(pf.pos, mini(3, int(f * 4.0)), 10, 0.0, 2.0, clampf((1.0 - f) * 3.0, 0.0, 1.0))
	i = 0
	var up := Vector3(0, 1.1, 0)
	while i < _slashes.size():
		var sl := _slashes[i]
		sl.t += delta
		if sl.t >= 0.26:
			_slashes.remove_at(i)
			continue
		i += 1
		var d := Vector3(sl.dir.x, 0, sl.dir.y)
		var ang: float = _screen_angle(d) + PI * 0.5 * sl.side
		_sprites.add(player.position + d * sl.r * 0.5 + up, mini(3, int(sl.t / 0.16 * 4.0)), 5, ang, 2.0 * sl.r / 3.2,
				clampf((0.26 - sl.t) / 0.1, 0.0, 1.0))
	i = 0
	while i < _lashes.size():
		var la := _lashes[i]
		la.t += delta
		if la.t >= 0.3:
			_lashes.remove_at(i)
			continue
		i += 1
		var ext: float = minf(1.0, la.t / 0.08) if la.t < 0.18 else 1.0 - (la.t - 0.18) / 0.12
		var d := Vector3(la.dir.x, 0, la.dir.y)
		var ang := _screen_angle(d)
		var links := int(la.len * ext)
		for j in links:
			var sag := sin(float(j) / maxf(1.0, links) * PI) * 0.35 * (1.0 - ext * 0.6)
			_sprites.add(player.position + d * (0.8 + j) + up - Vector3(0, sag, 0), (j + int(la.t * 20.0)) % 2, 6, ang)


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
	Sound.play("swing")
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
	Sound.play("throw")
	for k in n:
		var a := (k - (n - 1) * 0.5) * 0.14
		var d := dir.rotated(a)
		var sp := wstat(id, "speed") + maxf(0.0, Vector2(player.vel.x, player.vel.z).dot(d))
		_add_proj({"kind": "javelin", "id": id, "pos": p + Vector3(0, 1.4, 0), "vel": Vector3(d.x * sp, 0, d.y * sp),
			"life": 1.1, "pierce": int(wstat(id, "pierce")), "hits": [], "dmg": wstat(id, "damage"), "knock": wstat(id, "knock")})


# --- Axes -----------------------------------------------------------------------------
func _throw_axes(id: String) -> void:
	var p := player.position
	Sound.play("throw", null, 0.75)
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
		match pr.kind:
			"axe":
				var v: Vector3 = pr.vel
				v.y -= 45.0 * delta
				pr.vel = v
			"blade":
				_steer_blade(pr, delta)
			"skull":
				_steer_skull(pr, delta)
		var vel: Vector3 = pr.vel
		var pos: Vector3 = pr.pos + vel * delta
		var ground := enemies.terrain.grid_height(pos.x, pos.z)
		if pr.kind == "blade" or pr.kind == "skull":
			# These glide over the ground instead of flying flat into hills.
			pos.y = lerpf(pos.y, ground + 1.3, 1.0 - exp(-10.0 * delta))
		pr.pos = pos
		match pr.kind:
			"javelin":
				_sprites.add(pos, int(_t * 12.0) % 4, 2, _screen_angle(vel))
			"shard":
				_sprites.add(pos, int(_t * 12.0) % 4, 7, _screen_angle(vel))
			"blade":
				_sprites.add(pos, int(_t * 18.0) % 4, 8, 0.0, 1.5)
			"skull":
				_sprites.add(pos, int(_t * 10.0) % 4, 9)
			_:
				_sprites.add(pos, 0, 3, -_t * 14.0 * signf(vel.x + 0.01), 1.2)
		var low := pos.y - ground < 3.2
		if low and pr.kind == "skull":
			if not enemies.query(pos.x, pos.z, 0.7).is_empty():
				_burst_skull(pr, ground)
				pr.life = 0.0
		elif low:
			for e in enemies.query(pos.x, pos.z, 0.8 if pr.kind != "blade" else 1.2):
				if pr.hits.has(e):
					continue
				pr.hits.append(e)
				var push := Vector2(vel.x, vel.z).normalized() * float(pr.knock)
				hit(e, pr.dmg, push, pr.get("slow", 0.0))
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
		Sound.play("smite", pos)
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



# --- Delayed attacks -------------------------------------------------------------------
func _run_later() -> void:
	var i := 0
	while i < _later.size():
		if _later[i].at <= _t:
			var c: Callable = _later[i].call
			_later.remove_at(i)
			c.call()
		else:
			i += 1


## Direction to the nearest enemy within r, or where the hero faces.
func _aim(r: float) -> Vector2:
	var p := player.position
	var e := enemies.nearest(p.x, p.z, r)
	if e >= 0:
		var d := Vector2(enemies.px[e] - p.x, enemies.pz[e] - p.z)
		if d.length() > 0.01:
			return d.normalized()
	return player.facing


## Hits every enemy within r of the player and inside the arc around dir.
func _hit_arc(id: String, dir: Vector2, r: float, half_angle: float) -> void:
	var p := player.position
	var dmg := wstat(id, "damage")
	var knock := wstat(id, "knock")
	for e in enemies.query(p.x, p.z, r):
		var d := Vector2(enemies.px[e] - p.x, enemies.pz[e] - p.z)
		if d.length() > 1.0 and absf(dir.angle_to(d)) > half_angle:
			continue
		hit(e, dmg, d.normalized() * knock)


# --- Dragon Breath ---------------------------------------------------------------------
func _breathe(id: String) -> void:
	var p := player.position
	var r: float = wstat(id, "range") * run.stats.area
	var dir := _aim(r * 1.6)
	var half := deg_to_rad(wstat(id, "angle")) * 0.5
	_hit_arc(id, dir, r, half)
	player.model.swing()
	Sound.play("fire")
	var o := p + Vector3(dir.x * 0.6, 1.5, dir.y * 0.6)
	for k in 9:
		var v: Vector2 = dir.rotated(randf_range(-half, half) * 0.8) * r / 0.42 * randf_range(0.75, 1.0)
		_puffs.append({"pos": o, "vel": Vector3(v.x, randf_range(-0.6, 1.2), v.y), "t": -k * 0.02, "life": 0.42})


# --- Chain Lightning -------------------------------------------------------------------
func _chain(id: String, k: int) -> void:
	var p := player.position
	var r := wstat(id, "range")
	var cur := -1
	if k == 0:
		cur = enemies.nearest(p.x, p.z, r)
	else:
		var near := enemies.query(p.x, p.z, r)
		if not near.is_empty():
			cur = near[randi() % near.size()]
	if cur < 0:
		return
	var color: Color = Defs.WEAPONS[id].color
	var jr: float = wstat(id, "jump_range") * run.stats.area
	var dmg := wstat(id, "damage")
	var knock := wstat(id, "knock")
	var done := {}
	var pts := PackedVector3Array([p + Vector3(0, 1.8, 0)])
	for j in int(wstat(id, "jumps")) + 1:
		done[cur] = true
		var ep := enemies.position_of(cur) + Vector3(0, 1.1, 0)
		var from := pts[pts.size() - 1]
		pts.append(ep)
		hit(cur, dmg, Vector2(ep.x - from.x, ep.z - from.z).normalized() * knock)
		fx.sparks(ep, color, 4)
		var best := -1
		var bd := INF
		for e in enemies.query(ep.x, ep.z, jr):
			if done.has(e):
				continue
			var dd := Vector2(enemies.px[e] - ep.x, enemies.pz[e] - ep.z).length_squared()
			if dd < bd:
				bd = dd
				best = e
		if best < 0:
			break
		cur = best
	fx.lightning(pts, color)
	player.model.swing()
	Sound.play("zap", pts[1])


# --- Rending Claws ---------------------------------------------------------------------
func _claw(id: String, k: int) -> void:
	var r := area(id)
	var dir := _aim(r * 1.8)
	_hit_arc(id, dir, r, deg_to_rad(wstat(id, "angle")) * 0.5)
	_slashes.append({"dir": dir, "side": 1.0 if k % 2 == 0 else -1.0, "t": 0.0, "r": r})
	player.model.swing()
	Sound.play("claw")


# --- Warden's Chains -------------------------------------------------------------------
func _lash(id: String, k: int) -> void:
	var p := player.position
	var length := area(id)
	var w := wstat(id, "width")
	var dir := _aim(length * 1.2)
	if k % 2 == 1:
		dir = -dir
	var c := p + Vector3(dir.x, 0, dir.y) * length * 0.5
	var dmg := wstat(id, "damage")
	var knock := wstat(id, "knock")
	for e in enemies.query(c.x, c.z, length * 0.5 + w):
		var d := Vector2(enemies.px[e] - p.x, enemies.pz[e] - p.z)
		var along := d.dot(dir)
		if along < -0.5 or along > length + 0.5 or absf(d.cross(dir)) > w:
			continue
		hit(e, dmg, d.normalized() * knock)
	_lashes.append({"dir": dir, "len": length, "t": 0.0})
	player.model.swing()
	Sound.play("chain")


# --- Frost Shards ------------------------------------------------------------------------
func _fire_shards(id: String) -> void:
	var p := player.position
	var dir := _aim(30.0)
	var n := count(id)
	var sp := wstat(id, "speed")
	for k in n:
		var d := dir.rotated((k - (n - 1) * 0.5) * 0.17)
		_add_proj({"kind": "shard", "id": id, "pos": p + Vector3(0, 1.3, 0), "vel": Vector3(d.x * sp, 0, d.y * sp),
			"life": 0.9, "pierce": int(wstat(id, "pierce")), "hits": [], "dmg": wstat(id, "damage"),
			"knock": wstat(id, "knock"), "slow": wstat(id, "slow")})
	player.model.swing()
	Sound.play("ice")


# --- Rune Slam ---------------------------------------------------------------------------
func _slam(id: String, k: int) -> void:
	var p := player.position
	var r := area(id) * (1.0 + 0.3 * k)
	var at := Vector3(p.x, enemies.terrain.grid_height(p.x, p.z), p.z)
	var color: Color = Defs.WEAPONS[id].color
	fx.ring(at, r, color, 0.45, 0.22)
	fx.ring(at, r * 0.55, Color(1.0, 0.85, 0.55), 0.3, 0.3)
	fx.chips(at + Vector3(0, 0.3, 0), Color(0.46, 0.41, 0.37), 16, 9.0, 0.22, 0.8)
	fx.sparks(at + Vector3(0, 0.5, 0), color, 10)
	camera.add_shake(2.0)
	Sound.play("slam", null, 1.0 if k == 0 else 1.15, 0.0 if k == 0 else -4.0)
	var dmg := wstat(id, "damage") * (0.6 if k > 0 else 1.0)
	var knock := wstat(id, "knock")
	for e in enemies.query(p.x, p.z, r):
		var d := Vector2(enemies.px[e] - p.x, enemies.pz[e] - p.z)
		hit(e, dmg, (d.normalized() if d.length() > 0.01 else Vector2(1, 0)) * knock)
	player.model.swing()


# --- Soul Blade --------------------------------------------------------------------------
func _throw_blades(id: String) -> void:
	var p := player.position
	var r := wstat(id, "range")
	var dir := _aim(r)
	var n := count(id)
	var sp := wstat(id, "speed")
	for k in n:
		var d := dir.rotated(TAU * k / n)
		_add_proj({"kind": "blade", "id": id, "pos": p + Vector3(0, 1.3, 0), "vel": Vector3(d.x * sp, 0, d.y * sp),
			"life": 5.0, "pierce": 1000, "hits": [], "dmg": wstat(id, "damage"), "knock": wstat(id, "knock"),
			"out": true, "dist": 0.0, "range": r * sqrt(run.stats.area), "speed": sp})
	player.model.swing()
	Sound.play("soul")


func _steer_blade(pr: Dictionary, delta: float) -> void:
	if pr.out:
		pr.dist += pr.speed * delta
		if pr.dist >= pr.range:
			pr.out = false
			pr.hits = []
		return
	var to: Vector3 = player.position + Vector3(0, 1.3, 0) - pr.pos
	to.y = 0.0
	if to.length() < 1.2:
		pr.life = 0.0
		return
	# Coming back it must outrun even a sliding hero.
	pr.vel = to.normalized() * (pr.speed * 1.15 + player.speed())


# --- Soul Skulls -------------------------------------------------------------------------
func _loose_skulls(id: String) -> void:
	var p := player.position
	var n := count(id)
	var sp := wstat(id, "speed")
	var off := randf() * TAU
	for k in n:
		var a := off + TAU * k / n
		_add_proj({"kind": "skull", "id": id, "pos": p + Vector3(0, 1.6, 0), "vel": Vector3(cos(a), 0, sin(a)) * sp * 0.7,
			"life": 3.0, "pierce": 0, "hits": [], "dmg": wstat(id, "damage"), "knock": wstat(id, "knock"),
			"target": -1, "retarget": 0.0, "speed": sp})
	player.model.swing()
	Sound.play("skull")


func _steer_skull(pr: Dictionary, delta: float) -> void:
	pr.retarget -= delta
	if pr.retarget <= 0.0 or not enemies.is_alive(pr.target):
		pr.retarget = 0.25
		pr.target = enemies.nearest(pr.pos.x, pr.pos.z, 24.0)
	var want: Vector3 = pr.vel.normalized() * pr.speed
	if pr.target >= 0:
		var to: Vector3 = enemies.position_of(pr.target) - pr.pos
		to.y = 0.0
		want = to.normalized() * pr.speed
	pr.vel = (pr.vel as Vector3).move_toward(want, 38.0 * delta)


func _burst_skull(pr: Dictionary, ground: float) -> void:
	var pos: Vector3 = pr.pos
	var r: float = wstat(pr.id, "area") * run.stats.area
	var color: Color = Defs.WEAPONS[pr.id].color
	for e in enemies.query(pos.x, pos.z, r):
		var d := Vector2(enemies.px[e] - pos.x, enemies.pz[e] - pos.z)
		hit(e, pr.dmg, (d.normalized() if d.length() > 0.01 else Vector2(1, 0)) * float(pr.knock))
	fx.ring(Vector3(pos.x, ground, pos.z), r, color, 0.3, 0.16)
	fx.sparks(pos, color, 8)


# --- Time Rift ---------------------------------------------------------------------------
func _open_rift(id: String, k: int) -> void:
	var p := player.position
	var r := area(id)
	var near := enemies.query(p.x, p.z, wstat(id, "range"))
	var at := Vector3.ZERO
	if near.is_empty():
		var a := randf() * TAU
		var q := Vector2(p.x + cos(a) * 6.0, p.z + sin(a) * 6.0)
		at = Vector3(q.x, enemies.terrain.grid_height(q.x, q.y), q.y)
	else:
		# The busiest of a few random spots.
		var best := -1
		for tries in 5:
			var e := near[randi() % near.size()]
			var n := enemies.query(enemies.px[e], enemies.pz[e], r).size()
			if n > best:
				best = n
				at = enemies.position_of(e)
	if _rifts.size() >= _rift_mesh.size():
		_rifts.remove_at(0)
	_rifts.append({"pos": at, "r": r, "t": 0.0, "life": wstat(id, "duration"), "next": 0.1 + k * 0.05, "id": id})
	fx.ring(at, r * 1.2, Defs.WEAPONS[id].color, 0.4, 0.18)
	player.model.swing()
	Sound.play("rift", at)


func _run_rifts(delta: float) -> void:
	var i := 0
	while i < _rifts.size():
		var rf := _rifts[i]
		rf.t += delta
		if rf.t >= rf.life:
			_rifts.remove_at(i)
			continue
		if rf.t >= rf.next:
			rf.next += 0.4
			var c: Vector3 = rf.pos
			for e in enemies.query(c.x, c.z, rf.r):
				# A gentle pull toward the middle.
				var d := Vector2(c.x - enemies.px[e], c.z - enemies.pz[e])
				hit(e, wstat(rf.id, "damage"), d.normalized() * 3.0 if d.length() > 0.3 else Vector2.ZERO, 0.6)
			fx.sparks(c + Vector3(randf_range(-1, 1), 0.4, randf_range(-1, 1)), Defs.WEAPONS[rf.id].color, 3)
		i += 1
	for k in _rift_mesh.size():
		var mi := _rift_mesh[k]
		mi.visible = k < _rifts.size()
		if not mi.visible:
			continue
		var rf := _rifts[k]
		mi.global_position = rf.pos + Vector3(0, 0.14, 0)
		mi.scale = Vector3(rf.r, 1.0, rf.r)
		var fade := clampf(minf(rf.t / 0.15, (rf.life - rf.t) / 0.3), 0.0, 1.0)
		(mi.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.7 * fade)
