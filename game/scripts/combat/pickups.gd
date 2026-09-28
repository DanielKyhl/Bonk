class_name Pickups
extends Node3D
## XP soul shards, gold coins and healing hearts, drawn as pixel sprites in one
## MultiMesh; anything inside your pickup range flies to you (always faster
## than you).

signal collected(kind: int, value: float, pos: Vector3)

enum { XP, XP_BIG, GOLD, HEAL }
const MAX := 500
const BASE_RANGE := 3.6
const STRIDE := 16
const FPS := 7.0

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
var _mm: MultiMesh


func setup(t: Terrain, p: Player, r: RunState, _props: Props) -> void:
	terrain = t
	player = p
	run = r
	_pos.resize(MAX)
	_val.resize(MAX)
	_kind.resize(MAX)
	_mag.resize(MAX)
	_vy.resize(MAX)
	# Atlas rows: shard, big shard, coin, heart; four frames each.
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sprite.gdshader")
	mat.set_shader_parameter("atlas", load("res://assets/sprites/pickups.png"))
	mat.set_shader_parameter("grid", Vector2(4, 4))
	mat.set_shader_parameter("ppm", PixelView.PPM)
	mat.set_shader_parameter("frame_px", 16.0)
	mat.set_shader_parameter("foot_px", 15.0)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	add_child(mmi)


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
			var g := terrain.grid_height(p.x, p.z) + 0.25
			_vy[i] -= 30.0 * delta
			p.y += _vy[i] * delta
			if p.y < g:
				p.y = g
				_vy[i] = 0.0
		_pos[i] = p
		i += 1
	var buf := PackedFloat32Array()
	buf.resize(MAX * STRIDE)
	var o := 0
	for j in _n:
		var p := _pos[j]
		var bob := 0.0 if _mag[j] == 1 else maxf(0.0, sin(_t * 3.0 + j)) * 0.18
		buf[o] = 1.0
		buf[o + 3] = p.x
		buf[o + 5] = 1.0
		buf[o + 7] = p.y + bob
		buf[o + 10] = 1.0
		buf[o + 11] = p.z
		buf[o + 12] = float(int(_t * FPS + j) % 4 + 16 * _kind[j] + 4096)
		buf[o + 15] = 1.0
		o += STRIDE
	_mm.visible_instance_count = _n
	if _n > 0:
		_mm.buffer = buf


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
