extends SceneTree
# Prints the node tree, animations and mesh stats of the given models.

func _init() -> void:
	var paths := [
		"res://assets/kaykit/heroes/Knight.glb",
		"res://assets/kaykit/skeletons/Skeleton_Minion.glb",
		"res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"res://assets/kaykit/dungeon/chest.glb",
	]
	for p in paths:
		var scene: PackedScene = load(p)
		var root := scene.instantiate()
		print("==== ", p)
		_dump(root, 0)
		var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
		if ap:
			var names := ap.get_animation_list()
			print("  animations (", names.size(), "): ", ", ".join(names))
		root.free()
	quit()

func _dump(n: Node, depth: int) -> void:
	var extra := ""
	if n is MeshInstance3D and n.mesh:
		var verts := 0
		for s in n.mesh.get_surface_count():
			verts += n.mesh.surface_get_array_len(s)
		extra = " verts=%d surfaces=%d skin=%s aabb=%s" % [verts, n.mesh.get_surface_count(), n.skin != null, n.mesh.get_aabb()]
	elif n is Skeleton3D:
		extra = " bones=%d" % n.get_bone_count()
	elif n is BoneAttachment3D:
		extra = " bone=%s" % n.bone_name
	if depth < 6:
		print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_dump(c, depth + 1)
