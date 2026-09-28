class_name Pickups
extends Node3D
## XP gems, gold coins and healing orbs. Drawn as one MultiMesh per kind;
## anything inside your pickup range flies to you (always faster than you).

signal collected(kind: int, value: float, pos: Vector3)

enum { XP, XP_BIG, GOLD, HEAL }
const MAX := 500
const BASE_RANGE := 3.6
const STRIDE := 12

var terrain: Terrain
var player: Player
var run: RunState

var _pos := PackedVector3Array()
var _val := PackedFloat32Array()
var _kind := PackedInt32Array()
var _mag := PackedInt32Array()
var _vy := PackedFloat32Array()
var _n := 0
var _t := 0.0
var _mm: Array[MultiMesh] = []


func setup(t: Terrain, p: Player, r: RunState, props: Props) -> void:
	terrain = t
	player = p
	run = r
	_pos.resize(MAX)
	_val.resize(MAX)
	_kind.resize(MAX)
	_mag.resize(MAX)
	_vy.resize(MAX)
	var gem := SphereMesh.new()
	gem.radius = 0.22
	gem.height = 0.5
	gem.radial_segments = 4
	gem.rings = 2
	var big := gem.duplicate() as SphereMesh
	big.radius = 0.32
	big.height = 0.72
	var heal := SphereMesh.new()
	heal.radius = 0.28
	heal.height = 0.56
	heal.radial_segments = 8
	heal.rings = 4
	var coin := props.merged_mesh("res://assets/kaykit/dungeon/coin.gltf.glb")
	var meshes := [gem, big, coin, heal]
	var colors := [Color(0.35, 0.85, 1.0), Color(0.75, 0.45, 1.0), Color(1, 1, 1), Color(1.0, 0.3, 0.35)]
	for k in 4:
		var mesh: Mesh = meshes[k]
		if k != GOLD:
			var m := StandardMaterial3D.new()
			m.albedo_color = colors[k]
			m.emission_enabled = true
			m.emission = colors[k]
			m.emission_energy_multiplier = 1.6
			(mesh as PrimitiveMesh).material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = MAX
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
		add_child(mmi)
		_mm.append(mm)


func drop(kind: int, pos: Vector3, value: float) -> void:
	if _n >= MAX:
		# Full: fold the value into an existing pickup of the same kind.
		for i in range(_n - 1, -1, -1):
			if _kind[i] == kind:
				_val[i] += value
				return
		return
	var i := _n
	_n += 1
	_pos[i] = pos + Vector3(randf_range(-0.4, 0.4), 0.9, randf_range(-0.4, 0.4))
	_val[i] = value
	_kind[i] = kind
	_mag[i] = 0
	_vy[i] = randf_range(4.0, 7.0)


## Pull every pickup on the map to the player (magnet item / level clear).
func vacuum() -> void:
	for i in _n:
		_mag[i] = 1


func _process(delta: float) -> void:
	_t += delta
	var pp := player.position + Vector3(0, 1.0, 0)
	var rng: float = BASE_RANGE * run.stats.pickup
	var r2 := rng * rng
	var fly := 20.0 + player.speed() * 1.25
	var i := 0
	while i < _n:
		var p := _pos[i]
		var d := pp - p
		if _mag[i] == 0 and Vector2(d.x, d.z).length_squared() < r2:
			_mag[i] = 1
		if _mag[i] == 1:
			var dist := d.length()
			if dist < 0.9:
				_collect(i)
				continue
			p += d / dist * minf(dist, fly * delta)
		else:
			# Pop out, then settle and hover on the ground.
			var g := terrain.grid_height(p.x, p.z) + 0.55
			_vy[i] -= 30.0 * delta
			p.y += _vy[i] * delta
			if p.y < g:
				p.y = g
				_vy[i] = 0.0
		_pos[i] = p
		i += 1
	# One fresh buffer per kind (a buffer taken from a list would be a copy).
	for k in 4:
		var b := PackedFloat32Array()
		b.resize(MAX * STRIDE)
		var o := 0
		var s := 1.4 if k == GOLD else 1.0
		for j in _n:
			if _kind[j] != k:
				continue
			var p := _pos[j]
			var spin := _t * 2.5 + j
			var c := cos(spin) * s
			var sn := sin(spin) * s
			var bob := 0.0 if _mag[j] == 1 else sin(_t * 3.0 + j) * 0.12
			b[o] = c
			b[o + 2] = sn
			b[o + 3] = p.x
			b[o + 5] = s
			b[o + 7] = p.y + bob
			b[o + 8] = -sn
			b[o + 10] = c
			b[o + 11] = p.z
			o += STRIDE
		var cnt := o / STRIDE
		_mm[k].visible_instance_count = cnt
		if cnt > 0:
			_mm[k].buffer = b


func _collect(i: int) -> void:
	var k := _kind[i]
	var v := _val[i]
	var p := _pos[i]
	match k:
		XP, XP_BIG:
			run.add_xp(v)
		GOLD:
			run.add_gold(int(v))
		HEAL:
			run.heal(v)
	collected.emit(k, v, p)
	var j := _n - 1
	_pos[i] = _pos[j]
	_val[i] = _val[j]
	_kind[i] = _kind[j]
	_mag[i] = _mag[j]
	_vy[i] = _vy[j]
	_n -= 1
