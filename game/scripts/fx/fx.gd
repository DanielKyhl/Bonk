class_name Fx
extends Node3D
## Pooled visual effects: particle chips, shockwave rings, light pillars and
## floating damage numbers. Nothing is allocated during play.

const MAX_PARTS := 600
const MAX_RINGS := 28
const MAX_BEAMS := 16
const MAX_NUMBERS := 30

var terrain: Terrain

var _pp := PackedVector3Array()
var _pv := PackedVector3Array()
var _plife := PackedFloat32Array()
var _pmax := PackedFloat32Array()
var _psize := PackedFloat32Array()
var _pcol := PackedColorArray()
var _pn := 0
var _pnext := 0
var _pmm: MultiMesh

var _rings: Array[MeshInstance3D] = []
var _ring_life := PackedFloat32Array()
var _ring_max := PackedFloat32Array()
var _ring_r := PackedFloat32Array()
var _ring_next := 0

var _beams: Array[MeshInstance3D] = []
var _beam_life := PackedFloat32Array()
var _beam_next := 0

var _nums: Array[Label3D] = []
var _num_life := PackedFloat32Array()
var _num_vel := PackedVector3Array()
var _num_next := 0


func setup(t: Terrain) -> void:
	terrain = t
	_pp.resize(MAX_PARTS)
	_pv.resize(MAX_PARTS)
	_plife.resize(MAX_PARTS)
	_pmax.resize(MAX_PARTS)
	_psize.resize(MAX_PARTS)
	_pcol.resize(MAX_PARTS)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/particle.gdshader")
	box.material = pm
	_pmm = MultiMesh.new()
	_pmm.transform_format = MultiMesh.TRANSFORM_3D
	_pmm.use_custom_data = true
	_pmm.mesh = box
	_pmm.instance_count = MAX_PARTS
	_pmm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _pmm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	add_child(mmi)

	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.orientation = PlaneMesh.FACE_Y
	var ring_shader: Shader = load("res://shaders/ring.gdshader")
	for i in MAX_RINGS:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var m := ShaderMaterial.new()
		m.shader = ring_shader
		mi.material_override = m
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rings.append(mi)
	_ring_life.resize(MAX_RINGS)
	_ring_max.resize(MAX_RINGS)
	_ring_r.resize(MAX_RINGS)

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.6
	cyl.height = 14.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	var beam_shader: Shader = load("res://shaders/beam.gdshader")
	for i in MAX_BEAMS:
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		var m := ShaderMaterial.new()
		m.shader = beam_shader
		m.set_shader_parameter("strength", 0.9)
		mi.material_override = m
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_beams.append(mi)
	_beam_life.resize(MAX_BEAMS)

	# Pixel font at one font pixel per low-res pixel, so numbers are as crisp
	# as the sprites.
	var font := UIStyle.ui_font("Bold")
	for i in MAX_NUMBERS:
		var l := Label3D.new()
		l.font = font
		l.font_size = 10
		l.outline_size = 3
		l.outline_modulate = Color(0.05, 0.03, 0.05, 1.0)
		l.pixel_size = 1.0 / PixelView.PPM
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.visible = false
		add_child(l)
		_nums.append(l)
	_num_life.resize(MAX_NUMBERS)
	_num_vel.resize(MAX_NUMBERS)


# -----------------------------------------------------------------------------
# Emitters
# -----------------------------------------------------------------------------
func chips(pos: Vector3, color: Color, n: int, speed := 6.0, size := 0.14, life := 0.7, glow := 0.0) -> void:
	for k in n:
		var i := _pnext
		_pnext = (_pnext + 1) % MAX_PARTS
		_pn = mini(_pn + 1, MAX_PARTS)
		var a := randf() * TAU
		var up := randf_range(0.3, 1.0)
		var sp := randf_range(0.4, 1.0) * speed
		_pp[i] = pos
		_pv[i] = Vector3(cos(a) * sp, up * speed * 1.2, sin(a) * sp)
		_plife[i] = life * randf_range(0.7, 1.2)
		_pmax[i] = _plife[i]
		_psize[i] = size * randf_range(0.7, 1.3)
		_pcol[i] = Color(color.r, color.g, color.b, glow)


func bone_burst(pos: Vector3, big := false) -> void:
	chips(pos + Vector3(0, 1.0, 0), Color(0.93, 0.9, 0.82), 12 if big else 7, 7.0, 0.2 if big else 0.15, 0.9)
	chips(pos + Vector3(0, 1.0, 0), Color(0.85, 0.3, 0.42), 3, 5.0, 0.12, 0.6)


func sparks(pos: Vector3, color := Color(1.0, 0.85, 0.5), n := 6) -> void:
	chips(pos, color, n, 8.0, 0.09, 0.35, 2.5)


func dust(pos: Vector3, n := 6) -> void:
	chips(pos + Vector3(0, 0.15, 0), Color(0.62, 0.55, 0.42), n, 3.5, 0.18, 0.5)


func ring(pos: Vector3, radius: float, color := Color(1.0, 0.88, 0.55), life := 0.35, thickness := 0.14) -> void:
	var i := _ring_next
	_ring_next = (_ring_next + 1) % MAX_RINGS
	var mi := _rings[i]
	mi.visible = true
	mi.global_position = pos + Vector3(0, 0.12, 0)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("thickness", thickness)
	_ring_life[i] = life
	_ring_max[i] = life
	_ring_r[i] = radius
	mi.scale = Vector3.ONE * 0.2


func pillar(pos: Vector3, life := 0.4) -> void:
	var i := _beam_next
	_beam_next = (_beam_next + 1) % MAX_BEAMS
	var mi := _beams[i]
	mi.visible = true
	mi.global_position = pos + Vector3(0, 7.0, 0)
	mi.scale = Vector3(1, 1, 1)
	_beam_life[i] = life


func number(pos: Vector3, value: float, crit := false, color := Color(1, 1, 1)) -> void:
	var i := _num_next
	_num_next = (_num_next + 1) % MAX_NUMBERS
	var l := _nums[i]
	l.visible = true
	l.text = str(int(round(value)))
	l.modulate = Color(1.0, 0.82, 0.3) if crit else color
	l.font_size = 20 if crit else 10
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 2.2, randf_range(-0.2, 0.2))
	_num_life[i] = 0.6
	_num_vel[i] = Vector3(randf_range(-1, 1), 5.5, 0)


func text(pos: Vector3, s: String, color: Color, size := 20) -> void:
	var i := _num_next
	_num_next = (_num_next + 1) % MAX_NUMBERS
	var l := _nums[i]
	l.visible = true
	l.text = s
	l.modulate = color
	l.font_size = UIStyle.snap_size(UIStyle.ui_font("Bold"), size) if size >= 10 else 10
	l.global_position = pos + Vector3(0, 3.0, 0)
	_num_life[i] = 1.0
	_num_vel[i] = Vector3(0, 3.5, 0)


# -----------------------------------------------------------------------------
# Update
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	var damp := exp(-2.5 * delta)
	var buf := PackedFloat32Array()
	buf.resize(MAX_PARTS * 16)
	var n := 0
	for i in MAX_PARTS:
		if _plife[i] <= 0.0:
			continue
		_plife[i] -= delta
		var v := _pv[i]
		v.y -= 22.0 * delta
		v.x *= damp
		v.z *= damp
		var p := _pp[i] + v * delta
		var g := terrain.grid_height(p.x, p.z)
		if p.y < g + _psize[i] * 0.5:
			p.y = g + _psize[i] * 0.5
			v.y *= -0.35
			v.x *= 0.6
			v.z *= 0.6
		_pp[i] = p
		_pv[i] = v
		var f := clampf(_plife[i] / _pmax[i] * 2.0, 0.0, 1.0)
		var s := _psize[i] * f
		var o := n * 16
		var spin := _plife[i] * 9.0 + i
		var c := cos(spin) * s
		var sn := sin(spin) * s
		buf[o] = c
		buf[o + 1] = -sn
		buf[o + 3] = p.x
		buf[o + 4] = sn
		buf[o + 5] = c
		buf[o + 7] = p.y
		buf[o + 10] = s
		buf[o + 11] = p.z
		var col := _pcol[i]
		buf[o + 12] = col.r
		buf[o + 13] = col.g
		buf[o + 14] = col.b
		buf[o + 15] = col.a
		n += 1
	_pmm.visible_instance_count = n
	if n > 0:
		_pmm.buffer = buf

	for i in MAX_RINGS:
		if _ring_life[i] <= 0.0:
			continue
		_ring_life[i] -= delta
		var mi := _rings[i]
		if _ring_life[i] <= 0.0:
			mi.visible = false
			continue
		var t := 1.0 - _ring_life[i] / _ring_max[i]
		var r := _ring_r[i] * (0.25 + 0.75 * (1.0 - pow(1.0 - t, 3.0)))
		mi.scale = Vector3(r, 1.0, r)
		(mi.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0 - t * t)

	for i in MAX_BEAMS:
		if _beam_life[i] <= 0.0:
			continue
		_beam_life[i] -= delta
		var mi := _beams[i]
		if _beam_life[i] <= 0.0:
			mi.visible = false
			continue
		var w := clampf(_beam_life[i] / 0.4, 0.0, 1.0)
		mi.scale = Vector3(w, 1.0, w)

	for i in MAX_NUMBERS:
		if _num_life[i] <= 0.0:
			continue
		_num_life[i] -= delta
		var l := _nums[i]
		if _num_life[i] <= 0.0:
			l.visible = false
			continue
		var nv := _num_vel[i]
		nv.y -= 9.0 * delta
		_num_vel[i] = nv
		l.global_position += nv * delta
		l.modulate.a = clampf(_num_life[i] * 3.0, 0.0, 1.0)
		l.outline_modulate.a = l.modulate.a * 0.9
