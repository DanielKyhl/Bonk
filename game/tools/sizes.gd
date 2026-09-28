extends SceneTree
# Prints the combined AABB size of every model under the env asset folders.

func _init() -> void:
	for dir in ["res://assets/kaykit/dungeon", "res://assets/kaykit/halloween", "res://assets/kaykit/medieval/nature", "res://assets/kaykit/medieval/props", "res://assets/kaykit/medieval/buildings"]:
		var da := DirAccess.open(dir)
		for f in da.get_files():
			if not (f.ends_with(".glb") or f.ends_with(".gltf")):
				continue
			var root: Node = load(dir + "/" + f).instantiate()
			var box := AABB()
			var first := true
			var n_mesh := 0
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				n_mesh += 1
				var t: Transform3D = _xf(mi, root)
				var b: AABB = t * mi.mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
			print("%-60s size=(%.2f, %.2f, %.2f) min_y=%.2f meshes=%d" % [f, box.size.x, box.size.y, box.size.z, box.position.y, n_mesh])
			root.free()
	quit()

func _xf(n: Node3D, root: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			t = p.transform * t
		p = p.get_parent()
	return t
