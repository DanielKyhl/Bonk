class_name Fx
extends Node3D
## Pooled visual effects: particle chips, shockwave rings, light pillars,
## lightning and floating damage numbers.

const MAX_PARTS := 600
const MAX_RINGS := 28
const MAX_BEAMS := 16
const MAX_NUMBERS := 30
const MAX_BOLTS := 12
const BOLT_LIFE := 0.2

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

## Lightning: each bolt is a jagged polyline drawn as camera-facing ribbons.
var _bolt_mesh: ImmediateMesh
var _bolt_pts: Array[PackedVector3Array] = []
var _bolt_life := PackedFloat32Array()
var _bolt_col := PackedColorArray()


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

	_bolt_mesh = ImmediateMesh.new()
	var bolts := MeshInstance3D.new()
	bolts.mesh = _bolt_mesh
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/bolt.gdshader")
	bolts.material_override = bm
	bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolts.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	add_child(bolts)

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
		# Blended, so the outline reliably draws under the digits (with alpha
		# cut both go through the opaque pass in no set order).
		l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
		l.render_priority = 2
		l.outline_render_priority = 1
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


## A lightning bolt through the given points (jagged between each pair).
func lightning(points: PackedVector3Array, color := Color(0.6, 0.8, 1.0)) -> void:
	if points.size() < 2:
		return
	if _bolt_pts.size() >= MAX_BOLTS:
		_bolt_pts.remove_at(0)
		_bolt_life.remove_at(0)
		_bolt_col.remove_at(0)
	_bolt_pts.append(_jag(points))
	_bolt_life.append(BOLT_LIFE)
	_bolt_col.append(color)


func _jag(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array([points[0]])
	for k in points.size() - 1:
		var a := points[k]
		var b := points[k + 1]
		var n := maxi(2, int(a.distance_to(b) / 1.1))
		var side := (b - a).cross(Vector3.UP).normalized()
		for j in range(1, n):
			var q := a.lerp(b, float(j) / n)
			out.append(q + side * randf_range(-0.45, 0.45) + Vector3(0, randf_range(-0.3, 0.3), 0))
		out.append(b)
	return out


func _draw_bolts(delta: float) -> void:
	_bolt_mesh.clear_surfaces()
	var k := 0
	while k < _bolt_pts.size():
		_bolt_life[k] -= delta
		if _bolt_life[k] <= 0.0:
			_bolt_pts.remove_at(k)
			_bolt_life.remove_at(k)
			_bolt_col.remove_at(k)
			continue
		# Re-jag halfway so the bolt flickers.
		if _bolt_life[k] < BOLT_LIFE * 0.5 and _bolt_life[k] + delta >= BOLT_LIFE * 0.5:
			var pts := _bolt_pts[k]
			for j in range(1, pts.size() - 1):
				pts[j] += Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))
			_bolt_pts[k] = pts
		k += 1
	if _bolt_pts.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var back := cam.global_transform.basis.z
	_bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in _bolt_pts.size():
		var pts := _bolt_pts[b]
		var col := _bolt_col[b]
		_ribbon(pts, back, 0.3, col, Vector3.ZERO)
		_ribbon(pts, back, 0.11, col.lerp(Color(1, 1, 1), 0.75), back * 0.2)
	_bolt_mesh.surface_end()


func _ribbon(pts: PackedVector3Array, back: Vector3, width: float, col: Color, lift: Vector3) -> void:
	for j in pts.size() - 1:
		var a := pts[j] + lift
		var b := pts[j + 1] + lift
		var side := (b - a).cross(back).normalized() * width * 0.5
		_bolt_mesh.surface_set_color(col)
		_bolt_mesh.surface_add_vertex(a - side)
		_bolt_mesh.surface_add_vertex(a + side)
		_bolt_mesh.surface_add_vertex(b + side)
		_bolt_mesh.surface_add_vertex(a - side)
		_bolt_mesh.surface_add_vertex(b + side)
		_bolt_mesh.surface_add_vertex(b - side)


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

	_draw_bolts(delta)

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
