class_name Grass
extends Node3D
## Procedural grass tufts, tinted to the ground and swaying in the wind.
## Batched per 32 m region so off-screen tufts cost nothing.

const REGION := 32.0
const SPACING := 1.8

var terrain: Terrain
var map: MapDef


## title|seed -> MultiMeshes, so a restart on the same map reuses them.
static var _cache := {}


func setup(m: MapDef, t: Terrain, pads: Array[Vector2]) -> void:
	map = m
	terrain = t
	var key := "%s|%d" % [m.title, m.layout_seed]
	if not _cache.has(key):
		_cache[key] = _build(pads)
	for mm: MultiMesh in _cache[key]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _build(pads: Array[Vector2]) -> Array[MultiMesh]:
	var mesh := _tuft_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = map.layout_seed * 7 + 3
	# Pads, looked up by 8 m cell instead of checking every pad per tuft.
	var pad_cells := {}
	for q in pads:
		pad_cells[Vector2i(int(floor(q.x / 8.0)), int(floor(q.y / 8.0)))] = q
	var buckets := {}
	var edge := map.half_size - 8.0
	var x := -edge
	while x < edge:
		var z := -edge
		while z < edge:
			var p := Vector2(x + rng.randf_range(-0.6, 0.6), z + rng.randf_range(-0.6, 0.6))
			z += SPACING
			if terrain.path_mask(p.x, p.y) > 0.35 or terrain.grid_normal_y(p.x, p.y) < 0.8:
				continue
			if terrain.in_solid(p.x, p.y, 0.6) or p.distance_to(map.spawn) < 3.0:
				continue
			var pc := Vector2i(int(floor(p.x / 8.0)), int(floor(p.y / 8.0)))
			var near_pad := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var q: Variant = pad_cells.get(pc + Vector2i(dx, dz))
					if q != null and p.distance_squared_to(q) < 7.0:
						near_pad = true
			if near_pad:
				continue
			var bk := Vector2i(int(floor((p.x + map.half_size) / REGION)), int(floor((p.y + map.half_size) / REGION)))
			if not buckets.has(bk):
				buckets[bk] = PackedFloat32Array()
			var s := rng.randf_range(0.7, 1.35)
			var sy := s * rng.randf_range(0.8, 1.2)
			var a := rng.randf() * TAU
			var c := terrain.color_at(p.x, p.y)
			var ca := cos(a) * s
			var sa := sin(a) * s
			buckets[bk].append_array([ca, 0.0, sa, p.x, 0.0, sy, 0.0, terrain.base_grid_height(p.x, p.y) - 0.03,
					-sa, 0.0, ca, p.y, c.r, c.g, c.b, 1.0])
		x += SPACING
	var out: Array[MultiMesh] = []
	for bk in buckets:
		var buf: PackedFloat32Array = buckets[bk]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = buf.size() / 16
		mm.buffer = buf
		out.append(mm)
	return out


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := 9
	for b in blades:
		var ang := TAU * b / blades + randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x) * 0.06
		var h := randf_range(0.35, 0.62)
		var lean := dir * randf_range(0.1, 0.24)
		var base := dir * 0.05
		st.set_normal(Vector3.UP)
		st.set_color(Color(0.55, 0.55, 0.55))
		st.add_vertex(base - side)
		st.set_color(Color(0.55, 0.55, 0.55))
		st.add_vertex(base + side)
		st.set_color(Color(1.3, 1.28, 1.05))
		st.add_vertex(base + lean + Vector3(0, h, 0))
	return st.commit()
