class_name Grass
extends Node3D
## Procedural grass tufts, tinted to the ground and swaying in the wind.
## Batched per 32 m region so off-screen tufts cost nothing.

const REGION := 32.0
const SPACING := 1.5

var terrain: Terrain
var map: MapDef


func setup(m: MapDef, t: Terrain, pads: Array[Vector2]) -> void:
	map = m
	terrain = t
	var mesh := _tuft_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = map.layout_seed * 7 + 3
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
			var near_pad := false
			for q in pads:
				if p.distance_squared_to(q) < 7.0:
					near_pad = true
					break
			if near_pad:
				continue
			var key := Vector2i(int(floor((p.x + map.half_size) / REGION)), int(floor((p.y + map.half_size) / REGION)))
			if not buckets.has(key):
				buckets[key] = []
			var s := rng.randf_range(0.7, 1.35)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(p.x, terrain.base_grid_height(p.x, p.y) - 0.03, p.y))
			var c := terrain.color_at(p.x, p.y)
			buckets[key].append([xf, c])
		x += SPACING
	for key in buckets:
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_custom_data(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


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
