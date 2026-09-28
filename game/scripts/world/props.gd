class_name Props
extends Node3D
## Landmarks, launch pads and scattered decoration for a map.
## Decoration is batched into MultiMeshes per model and 64 m region, so the GPU
## only draws the batches near the camera.

const REGION := 64.0
const PAD_RADIUS := 1.7

var map: MapDef
var terrain: Terrain
## Launch pad positions (world XZ), used by the player.
var pad_positions: Array[Vector2] = []

var _mesh_cache := {}
var _mat_cache := {}
var _buckets := {}          ## "path|rx|rz" -> Array[Transform3D]
var _bucket_shadow := {}    ## "path|rx|rz" -> bool
var _pad_beams: Array[MeshInstance3D] = []
var _placed: Array[Vector2] = []
var _time := 0.0


func setup(m: MapDef, t: Terrain) -> void:
	map = m
	terrain = t
	_place_landmarks()
	_place_pads()
	var rng := RandomNumberGenerator.new()
	for i in map.scatter.size():
		rng.seed = map.layout_seed * 131 + i
		_scatter(map.scatter[i], rng)
	_flush_buckets()


func _process(delta: float) -> void:
	_time += delta
	for i in _pad_beams.size():
		var b := _pad_beams[i]
		var s := 1.0 + 0.06 * sin(_time * 3.0 + i)
		b.scale = Vector3(s, 1.0 + 0.1 * sin(_time * 2.0 + i * 1.7), s)


# -----------------------------------------------------------------------------
# Meshes
# -----------------------------------------------------------------------------
## One mesh with every MeshInstance3D of a scene baked in (materials kept per surface).
func merged_mesh(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var root: Node = load(path).instantiate()
	var out := ArrayMesh.new()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _relative_xf(mi, root)
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for k in verts.size():
				verts[k] = xf * verts[k]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for k in nrm.size():
					nrm[k] = (xf.basis * nrm[k]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = nrm
			arrays[Mesh.ARRAY_TANGENT] = null
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, prop_material(mi.get_active_material(s)))
	root.free()
	_mesh_cache[path] = out
	return out


## The gritty pixel version of a model's material (shared per texture/color).
func prop_material(src: Material) -> Material:
	var tex: Texture2D = null
	var col := Color.WHITE
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
		col = (src as BaseMaterial3D).albedo_color
	var key := "%s|%s" % [tex.resource_path if tex else "", col.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/prop.gdshader")
	m.set_shader_parameter("use_texture", tex != null)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("albedo_color", col)
	m.set_shader_parameter("saturation", map.prop_saturation)
	m.set_shader_parameter("value", map.prop_value)
	m.set_shader_parameter("grade", map.prop_grade)
	_mat_cache[key] = m
	return m


func _relative_xf(n: Node3D, root: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _add_instance(path: String, pos: Vector3, yaw: float, scale: float, shadow: bool) -> void:
	var rx := int(floor((pos.x + map.half_size) / REGION))
	var rz := int(floor((pos.z + map.half_size) / REGION))
	var key := "%s|%d|%d" % [path, rx, rz]
	if not _buckets.has(key):
		_buckets[key] = []
		_bucket_shadow[key] = shadow
	_buckets[key].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos))


func _flush_buckets() -> void:
	for key: String in _buckets:
		var list: Array = _buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = merged_mesh(key.get_slice("|", 0))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _bucket_shadow[key] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_buckets.clear()


# -----------------------------------------------------------------------------
# Landmarks and pads
# -----------------------------------------------------------------------------
func _place_landmarks() -> void:
	for lm in map.landmarks:
		var node: Node3D = load(lm.scene).instantiate()
		var p: Vector2 = lm.pos
		var s: float = lm.scale
		# Sit on the lowest point under the footprint so nothing floats.
		var r := 1.0
		var sd: Dictionary = lm.solid
		if not sd.is_empty():
			r = sd.radius if sd.kind == "cyl" else (sd.size as Vector2).length() * 0.5
		var y := terrain.base_height(p.x, p.y)
		for a in 4:
			var q := p + Vector2(r * 0.8, 0).rotated(a * PI * 0.5 + 0.4)
			y = minf(y, terrain.base_height(q.x, q.y))
		node.transform = Transform3D(Basis(Vector3.UP, lm.yaw).scaled(Vector3.ONE * s), Vector3(p.x, y - 0.05, p.y))
		add_child(node)
		_placed.append(p)
		for mi: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _place_pads() -> void:
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(1.0, 0.92, 0.6)
	disc_mat.emission_enabled = true
	disc_mat.emission = Color(1.0, 0.85, 0.45)
	disc_mat.emission_energy_multiplier = 1.1
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam.gdshader")
	var disc := CylinderMesh.new()
	disc.top_radius = PAD_RADIUS * 0.8
	disc.bottom_radius = PAD_RADIUS * 0.8
	disc.height = 0.06
	var beam := CylinderMesh.new()
	beam.top_radius = PAD_RADIUS * 0.35
	beam.bottom_radius = PAD_RADIUS * 0.7
	beam.height = 9.0
	beam.cap_top = false
	beam.cap_bottom = false
	var basin: PackedScene = load("res://assets/kaykit/halloween/plaque.gltf")
	for p in map.pads:
		var y := terrain.base_height(p.x, p.y)
		var root := Node3D.new()
		root.position = Vector3(p.x, y, p.y)
		add_child(root)
		var b: Node3D = basin.instantiate()
		b.scale = Vector3.ONE * 1.8
		root.add_child(b)
		var d := MeshInstance3D.new()
		d.mesh = disc
		d.material_override = disc_mat
		d.position.y = 0.74
		root.add_child(d)
		var bm := MeshInstance3D.new()
		bm.mesh = beam
		bm.material_override = beam_mat
		bm.position.y = 5.2
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bm)
		_pad_beams.append(bm)
		pad_positions.append(p)
		_placed.append(p)


# -----------------------------------------------------------------------------
# Scatter
# -----------------------------------------------------------------------------
func _scatter(rule: Dictionary, rng: RandomNumberGenerator) -> void:
	var scenes: Array = rule.scenes
	var sc: Vector2 = rule.get("scale", Vector2.ONE)
	if rule.has("rows"):
		var rw: Dictionary = rule.rows
		var c: Vector2 = rw.center
		var step: Vector2 = rw.step
		var x: float = c.x - rw.radius
		while x <= c.x + rw.radius:
			var z: float = c.y - rw.radius
			while z <= c.y + rw.radius:
				var p := Vector2(x + rng.randf_range(-0.6, 0.6), z + rng.randf_range(-0.5, 0.5))
				if p.distance_to(c) < rw.radius and rng.randf() < rule.get("chance", 1.0) and _free(p, 1.5, false):
					var path: String = scenes[rng.randi() % scenes.size()]
					_put(path, p, deg_to_rad(rw.yaw + rng.randf_range(-12, 12)), rng.randf_range(sc.x, sc.y), false, 0.0)
				z += step.y
			x += step.x
		return
	if rule.has("along_paths"):
		var every: float = rule.along_paths
		var off: float = rule.get("offset", 3.0)
		var side := 1.0
		for poly in map.paths:
			var carry := every * 0.5
			for k in poly.size() - 1:
				var a: Vector2 = poly[k]
				var b: Vector2 = poly[k + 1]
				var seg := b - a
				var seg_len := seg.length()
				var dir := seg / seg_len
				var t := carry
				while t < seg_len:
					var p := a + dir * t + Vector2(-dir.y, dir.x) * off * side
					side = -side
					if _free(p, 1.0, false):
						_put(scenes[0], p, rng.randf() * TAU, sc.x, false, 0.0)
					t += every
				carry = t - seg_len
		return
	if rule.has("circle"):
		var cr: Dictionary = rule.circle
		var c: Vector2 = cr.center
		var radius: float = cr.radius
		var seg_len := 4.0 * sc.x
		var n := int(TAU * radius / seg_len)
		var gap: Array = cr.get("gap_deg", [])
		for i in n:
			var ang := TAU * (i + 0.5) / n
			var deg := rad_to_deg(ang)
			if gap.size() == 2 and deg > gap[0] and deg < gap[1]:
				continue
			var p := c + Vector2(cos(ang), sin(ang)) * radius
			if terrain.in_solid(p.x, p.y, 1.0):
				continue
			# Fence runs along the tangent; the model's long side is local X.
			var path: String = scenes[0] if rng.randf() < 0.75 else scenes[scenes.size() - 1]
			_put(path, p, -ang + PI * 0.5, sc.x, false, 0.0)
		return

	var count: int = rule.count
	var spacing: float = rule.get("spacing", 3.0)
	var greens_scale: float = rule.get("greens_scale", 1.0)
	var tries := count * 12
	var grid := {}
	var placed := 0
	while placed < count and tries > 0:
		tries -= 1
		var p: Vector2
		if rule.has("ring"):
			var ring: Vector2 = rule.ring
			p = Vector2(rng.randf_range(-ring.y, ring.y), rng.randf_range(-ring.y, ring.y))
			var m := maxf(absf(p.x), absf(p.y))
			if m < ring.x or m > ring.y:
				continue
		else:
			var c: Vector2 = rule.center
			var ang := rng.randf() * TAU
			p = c + Vector2(cos(ang), sin(ang)) * sqrt(rng.randf()) * rule.radius
			if absf(p.x) > map.half_size - 10.0 or absf(p.y) > map.half_size - 10.0:
				continue
		if not _free(p, 2.5, true) or _crowded(grid, p, spacing):
			continue
		var path: String = scenes[rng.randi() % scenes.size()]
		var s := rng.randf_range(sc.x, sc.y)
		if path.contains("/medieval/nature/tree"):
			s *= greens_scale
		var big := path.contains("tree") or s > 5.0
		_put(path, p, rng.randf() * TAU, s, big, 0.15)
		placed += 1


func _put(path: String, p: Vector2, yaw: float, s: float, shadow: bool, sink: float) -> void:
	var y := terrain.base_grid_height(p.x, p.y)
	_add_instance(path, Vector3(p.x, y - sink * s, p.y), yaw, s, shadow)


## True when a spot is clear of landmarks, pads, ramps, paths and spawn.
func _free(p: Vector2, margin: float, avoid_paths: bool) -> bool:
	if p.distance_to(map.spawn) < 12.0:
		return false
	if terrain.in_solid(p.x, p.y, margin):
		return false
	# Nothing grows out of cliff faces.
	if terrain.grid_normal_y(p.x, p.y) < 0.72:
		return false
	if avoid_paths and terrain.path_mask(p.x, p.y) > 0.25:
		return false
	for q in pad_positions:
		if p.distance_to(q) < PAD_RADIUS + margin + 1.0:
			return false
	for rp in map.ramps:
		var mid: Vector2 = rp.pos + Vector2(cos(rp.yaw), sin(rp.yaw)) * rp.length * 0.5
		if p.distance_to(mid) < rp.length * 0.6 + margin:
			return false
	return true


func _crowded(grid: Dictionary, p: Vector2, spacing: float) -> bool:
	var cx := int(floor(p.x / spacing))
	var cz := int(floor(p.y / spacing))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := Vector2i(cx + dx, cz + dz)
			if grid.has(k) and (grid[k] as Vector2).distance_to(p) < spacing:
				return true
	grid[Vector2i(cx, cz)] = p
	return false
