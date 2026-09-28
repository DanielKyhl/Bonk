class_name EnemyManager
extends Node3D
## All regular enemies, stored as flat arrays (no node per enemy) and drawn as
## one MultiMesh per type with baked vertex animation. Handles movement, crowd
## separation, collisions with buildings, and contact with the player.

signal killed(type: int, pos: Vector3, xp: int, elite: bool)
signal player_hit(damage: float, from: Vector3)

const MAX := 720
const HC := 2.5                   ## Spatial hash cell size.
const DRAW_RADIUS := 62.0
const STRIDE := 16                ## Floats per MultiMesh instance (transform + custom).
const SPAWN_SPEED := 2.4          ## Rise-from-the-ground animation speedup.
const DEATH_SPEED := 1.7
const SINK_TIME := 0.7

enum { RISING, ALIVE, DYING }
enum Anim { RUN, ATTACK, SPAWN, DEATH }

## Enemy types for Hallowed Vale. speed in m/s, radius/scale in m.
var types: Array[Dictionary] = [
	{"name": "Skeleton", "vat": "res://assets/vat/skeleton_minion.res", "radius": 0.5, "scale": 1.0, "speed": 6.2, "hp": 20.0, "dmg": 8.0, "xp": 1, "anim_speed": 6.5},
	{"name": "Skeleton Rogue", "vat": "res://assets/vat/skeleton_rogue.res", "radius": 0.45, "scale": 0.95, "speed": 9.6, "hp": 12.0, "dmg": 6.0, "xp": 1, "anim_speed": 9.0},
	{"name": "Skeleton Warrior", "vat": "res://assets/vat/skeleton_warrior.res", "radius": 0.95, "scale": 1.55, "speed": 4.2, "hp": 150.0, "dmg": 18.0, "xp": 6, "anim_speed": 2.6},
	{"name": "Skeleton Mage", "vat": "res://assets/vat/skeleton_mage.res", "radius": 0.5, "scale": 1.05, "speed": 4.6, "hp": 36.0, "dmg": 10.0, "xp": 3, "anim_speed": 2.8},
]

var terrain: Terrain
var player: Player
var count := 0

var px := PackedFloat32Array()
var pz := PackedFloat32Array()
var py := PackedFloat32Array()
var kx := PackedFloat32Array()
var kz := PackedFloat32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var yaw := PackedFloat32Array()
var anim_t := PackedFloat32Array()
var flash := PackedFloat32Array()
var hit_cd := PackedFloat32Array()
var speed := PackedFloat32Array()
var radius := PackedFloat32Array()
var top := PackedFloat32Array()      ## Height of the head above the feet.
var dmg := PackedFloat32Array()
var state := PackedInt32Array()
var typ := PackedInt32Array()
var anim := PackedInt32Array()
var elite := PackedInt32Array()

var _hn := 0
var _cell := PackedInt32Array()
var _head := PackedInt32Array()      ## First enemy in each hash cell, -1 if empty.
var _next := PackedInt32Array()      ## Next enemy in the same cell.
var _solid_cell := PackedByteArray() ## 1 where a hash cell touches a building.
var _frame := 0
var _mm: Array[MultiMesh] = []
var _anim_len: Array[PackedFloat32Array] = []   ## per type: seconds for each Anim
var _query := PackedInt32Array()


func setup(t: Terrain, p: Player) -> void:
	terrain = t
	player = p
	# Resize the members directly (a loop over copies would resize the copies).
	px.resize(MAX); pz.resize(MAX); py.resize(MAX); kx.resize(MAX); kz.resize(MAX)
	hp.resize(MAX); max_hp.resize(MAX); yaw.resize(MAX); anim_t.resize(MAX); flash.resize(MAX)
	hit_cd.resize(MAX); speed.resize(MAX); radius.resize(MAX); top.resize(MAX); dmg.resize(MAX)
	state.resize(MAX); typ.resize(MAX); anim.resize(MAX); elite.resize(MAX)
	_cell.resize(MAX); _next.resize(MAX)
	_hn = int(ceil(2.0 * terrain.half / HC))
	_head.resize(_hn * _hn)
	_head.fill(-1)
	_solid_cell.resize(_hn * _hn)
	for cz in _hn:
		for cx in _hn:
			var x := -terrain.half + (cx + 0.5) * HC
			var z := -terrain.half + (cz + 0.5) * HC
			_solid_cell[cz * _hn + cx] = 1 if terrain.in_solid(x, z, HC + 1.0) else 0
	_query.resize(MAX)
	var albedo: Texture2D = load("res://assets/kaykit/skeletons/skeleton_texture.png")
	var shader: Shader = load("res://shaders/vat.gdshader")
	for td in types:
		var data: VatData = load(td.vat)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("pos_tex", ImageTexture.create_from_image(data.positions))
		mat.set_shader_parameter("nrm_tex", ImageTexture.create_from_image(data.normals))
		mat.set_shader_parameter("albedo_tex", albedo)
		var lens := PackedFloat32Array()
		for i in 4:
			var key: String = ["run", "attack", "spawn", "death"][i]
			var a: Vector4 = data.anims[key]
			mat.set_shader_parameter("anim%d" % i, a)
			lens.append(a.y / a.z)
		_anim_len.append(lens)
		var mesh := data.mesh.duplicate() as ArrayMesh
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = MAX
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
		add_child(mmi)
		_mm.append(mm)


# -----------------------------------------------------------------------------
# Spawning and damage
# -----------------------------------------------------------------------------
func spawn(t: int, x: float, z: float, hp_mult := 1.0, rise := true, is_elite := false) -> int:
	if count >= MAX:
		return -1
	var i := count
	count += 1
	var td: Dictionary = types[t]
	var s: float = td.scale * (1.35 if is_elite else 1.0)
	var p := terrain.clamp_to_map(Vector2(x, z), 4.0)
	px[i] = p.x
	pz[i] = p.y
	py[i] = terrain.grid_height(p.x, p.y)
	kx[i] = 0.0
	kz[i] = 0.0
	max_hp[i] = td.hp * hp_mult * (6.0 if is_elite else 1.0)
	hp[i] = max_hp[i]
	yaw[i] = atan2(player.position.x - p.x, player.position.z - p.y)
	anim_t[i] = 0.0
	flash[i] = 0.0
	hit_cd[i] = 0.0
	speed[i] = td.speed * randf_range(0.92, 1.08) * (0.9 if is_elite else 1.0)
	radius[i] = td.radius * (1.35 if is_elite else 1.0)
	top[i] = 2.1 * s
	dmg[i] = td.dmg * (1.5 if is_elite else 1.0)
	state[i] = RISING if rise else ALIVE
	anim[i] = Anim.SPAWN if rise else Anim.RUN
	typ[i] = t
	elite[i] = 1 if is_elite else 0
	return i


## Deals damage with a knockback push (m/s). Returns true if it killed.
func damage(i: int, amount: float, push := Vector2.ZERO) -> bool:
	if state[i] == DYING:
		return false
	hp[i] -= amount
	flash[i] = 1.0
	var w := 0.5 / radius[i]
	kx[i] += push.x * w
	kz[i] += push.y * w
	if hp[i] <= 0.0:
		state[i] = DYING
		anim[i] = Anim.DEATH
		anim_t[i] = 0.0
		var td: Dictionary = types[typ[i]]
		killed.emit(typ[i], Vector3(px[i], py[i], pz[i]), td.xp * (8 if elite[i] == 1 else 1), elite[i] == 1)
		return true
	return false


func is_alive(i: int) -> bool:
	return i < count and state[i] != DYING


func position_of(i: int) -> Vector3:
	return Vector3(px[i], py[i], pz[i])


## Fills and returns a list of enemy indices within r of (x, z) (alive or rising).
func query(x: float, z: float, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := clampi(int((x - r + terrain.half) / HC), 0, _hn - 1)
	var x1 := clampi(int((x + r + terrain.half) / HC), 0, _hn - 1)
	var z0 := clampi(int((z - r + terrain.half) / HC), 0, _hn - 1)
	var z1 := clampi(int((z + r + terrain.half) / HC), 0, _hn - 1)
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			var i := _head[cz * _hn + cx]
			while i >= 0:
				if i < count and state[i] != DYING:
					var dx := px[i] - x
					var dz := pz[i] - z
					var rr := r + radius[i]
					if dx * dx + dz * dz <= rr * rr:
						out.append(i)
				i = _next[i]
	return out


## Nearest living enemy within max_r, or -1.
func nearest(x: float, z: float, max_r: float) -> int:
	var best := -1
	var bd := max_r * max_r
	for i in count:
		if state[i] == DYING:
			continue
		var d := (px[i] - x) * (px[i] - x) + (pz[i] - z) * (pz[i] - z)
		if d < bd:
			bd = d
			best = i
	return best


## Player stomp check: returns the enemy whose head the player just dropped onto.
func stomp_probe(pos: Vector3, prev_y: float) -> int:
	for i in query(pos.x, pos.z, 0.5):
		if state[i] != ALIVE:
			continue
		var head := py[i] + top[i]
		if prev_y >= head - 0.05 and pos.y <= head:
			return i
	return -1


func stomp_top(i: int) -> float:
	return py[i] + top[i]


# -----------------------------------------------------------------------------
# Update
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if player == null:
		return
	var ppos := player.position
	var __t := Time.get_ticks_usec()
	var decay := exp(-6.0 * delta)
	var i := 0
	while i < count:
		var st := state[i]
		var t := typ[i]
		var td: Dictionary = types[t]
		flash[i] = maxf(0.0, flash[i] - delta * 9.0)
		hit_cd[i] -= delta
		if st == DYING:
			anim_t[i] += delta * DEATH_SPEED
			if anim_t[i] > _anim_len[t][Anim.DEATH] + SINK_TIME * DEATH_SPEED:
				_remove(i)
				continue
		elif st == RISING:
			anim_t[i] += delta * SPAWN_SPEED
			if anim_t[i] >= _anim_len[t][Anim.SPAWN]:
				state[i] = ALIVE
				anim[i] = Anim.RUN
				anim_t[i] = randf() * 2.0
		else:
			var dx := ppos.x - px[i]
			var dz := ppos.z - pz[i]
			var d := sqrt(dx * dx + dz * dz) + 0.0001
			var reach := radius[i] + Player.RADIUS + 1.1
			var sp := speed[i]
			if d < reach:
				sp = 0.0
				if anim[i] != Anim.ATTACK:
					anim[i] = Anim.ATTACK
					anim_t[i] = 0.0
			elif anim[i] == Anim.ATTACK and d > reach + 0.8:
				anim[i] = Anim.RUN
			px[i] += (dx / d * sp + kx[i]) * delta
			pz[i] += (dz / d * sp + kz[i]) * delta
			# The player's body blocks: nobody stands inside the hero.
			var body := radius[i] + Player.RADIUS + 0.3
			if d < body and player.height_above_ground() < top[i]:
				px[i] = ppos.x - dx / d * body
				pz[i] = ppos.z - dz / d * body
			yaw[i] = lerp_angle(yaw[i], atan2(dx, dz), 1.0 - exp(-8.0 * delta))
			anim_t[i] += delta * (1.0 if anim[i] == Anim.ATTACK else sp / td.anim_speed)
		kx[i] *= decay
		kz[i] *= decay
		i += 1

	_frame += 1
	_rebuild_hash()
	_separate()
	_collide_world()
	_contact_player()
	_draw()
	Prof.add("enemies", Time.get_ticks_usec() - __t)


func _remove(i: int) -> void:
	var j := count - 1
	if i != j:
		px[i] = px[j]; pz[i] = pz[j]; py[i] = py[j]; kx[i] = kx[j]; kz[i] = kz[j]
		hp[i] = hp[j]; max_hp[i] = max_hp[j]; yaw[i] = yaw[j]; anim_t[i] = anim_t[j]
		flash[i] = flash[j]; hit_cd[i] = hit_cd[j]; speed[i] = speed[j]; radius[i] = radius[j]
		top[i] = top[j]; dmg[i] = dmg[j]; state[i] = state[j]; typ[i] = typ[j]
		anim[i] = anim[j]; elite[i] = elite[j]
	count -= 1


func _rebuild_hash() -> void:
	_head.fill(-1)
	var h := terrain.half
	for i in count:
		var c := clampi(int((pz[i] + h) / HC), 0, _hn - 1) * _hn + clampi(int((px[i] + h) / HC), 0, _hn - 1)
		_cell[i] = c
		_next[i] = _head[c]
		_head[c] = i


## Pushes overlapping enemies apart. Half the crowd is handled each frame, and
## each enemy looks at a limited number of neighbors, to keep big hordes cheap.
func _separate() -> void:
	var parity := _frame & 1
	for i in count:
		if (i & 1) != parity or state[i] == DYING:
			continue
		var c := _cell[i]
		var cx := c % _hn
		var cz := c / _hn
		var xi := px[i]
		var zi := pz[i]
		var ri := radius[i]
		var ox := 0.0
		var oz := 0.0
		var checks := 0
		for zz in range(maxi(0, cz - 1), mini(_hn - 1, cz + 1) + 1):
			for xx in range(maxi(0, cx - 1), mini(_hn - 1, cx + 1) + 1):
				var j := _head[zz * _hn + xx]
				while j >= 0 and checks < 10:
					if j != i and state[j] != DYING:
						var dx := xi - px[j]
						var dz := zi - pz[j]
						var rr := ri + radius[j]
						var d2 := dx * dx + dz * dz
						if d2 < rr * rr and d2 > 0.000001:
							var d := sqrt(d2)
							# Lighter enemies get pushed more; doubled because each is visited every other frame.
							var push := (rr - d) / d * radius[j] / rr
							ox += dx * push
							oz += dz * push
							checks += 1
					j = _next[j]
		px[i] = xi + ox
		pz[i] = zi + oz


func _collide_world() -> void:
	var h := terrain.half
	var m := h - 3.0
	for i in count:
		var x := px[i]
		var z := pz[i]
		if _solid_cell[_cell[i]] == 1:
			var p := terrain.push_out(Vector2(x, z), radius[i])
			x = p.x
			z = p.y
		x = clampf(x, -m, m)
		z = clampf(z, -m, m)
		px[i] = x
		pz[i] = z
		py[i] = terrain.grid_height(x, z)


func _contact_player() -> void:
	var p := player
	var ha := p.height_above_ground()
	for i in query(p.position.x, p.position.z, Player.RADIUS):
		if state[i] != ALIVE or ha > top[i] * 0.85:
			continue
		player_hit.emit(dmg[i], Vector3(px[i], py[i], pz[i]))


func _draw() -> void:
	var cx := player.position.x
	var cz := player.position.z
	var r2 := DRAW_RADIUS * DRAW_RADIUS
	var lists: Array[PackedInt32Array] = []
	for t in types.size():
		lists.append(PackedInt32Array())
	for i in count:
		var dx := px[i] - cx
		var dz := pz[i] - cz
		if dx * dx + dz * dz <= r2:
			lists[typ[i]].append(i)
	for t in types.size():
		var list := lists[t]
		var n := list.size()
		_mm[t].visible_instance_count = n
		if n == 0:
			continue
		var base_s: float = types[t].scale
		var b := PackedFloat32Array()
		b.resize(MAX * STRIDE)
		var o := 0
		for i in list:
			var s := base_s * (1.35 if elite[i] == 1 else 1.0)
			var c := cos(yaw[i]) * s
			var sn := sin(yaw[i]) * s
			var sink := 0.0
			if state[i] == DYING:
				var over := anim_t[i] - _anim_len[t][Anim.DEATH]
				if over > 0.0:
					sink = over / (SINK_TIME * DEATH_SPEED) * 1.2
			b[o] = c
			b[o + 2] = sn
			b[o + 3] = px[i]
			b[o + 5] = s
			b[o + 7] = py[i]
			b[o + 8] = -sn
			b[o + 10] = c
			b[o + 11] = pz[i]
			b[o + 12] = float(anim[i])
			b[o + 13] = anim_t[i]
			b[o + 14] = flash[i]
			b[o + 15] = sink
			o += STRIDE
		_mm[t].buffer = b
