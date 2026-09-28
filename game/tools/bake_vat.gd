extends SceneTree
## Bakes enemy animations into vertex animation textures (see VatData).
## Run: godot --path . --rendering-driver opengl3 --script res://tools/bake_vat.gd

const SK := "res://assets/kaykit/skeletons/"
const SKW := "res://assets/kaykit/skeletons/weapons/"

## Each job: source model, output, [name, source animation, frames, loop], extra
## rigid meshes to attach to bones.
var jobs := [
	{"src": SK + "Skeleton_Minion.glb", "out": "res://assets/vat/skeleton_minion.res",
		"anims": [["run", "Running_C", 16, true], ["attack", "1H_Melee_Attack_Chop", 12, true], ["spawn", "Spawn_Ground_Skeletons", 18, false], ["death", "Death_C_Skeletons", 16, false]],
		"attach": []},
	{"src": SK + "Skeleton_Rogue.glb", "out": "res://assets/vat/skeleton_rogue.res",
		"anims": [["run", "Running_A", 14, true], ["attack", "Dualwield_Melee_Attack_Stab", 12, true], ["spawn", "Spawn_Ground_Skeletons", 18, false], ["death", "Death_C_Skeletons", 16, false]],
		"attach": [[SKW + "Skeleton_Blade.gltf", "handslot.r"]]},
	{"src": SK + "Skeleton_Warrior.glb", "out": "res://assets/vat/skeleton_warrior.res",
		"anims": [["run", "Walking_D_Skeletons", 16, true], ["attack", "1H_Melee_Attack_Chop", 12, true], ["spawn", "Spawn_Ground_Skeletons", 18, false], ["death", "Death_C_Skeletons", 16, false]],
		"attach": [[SKW + "Skeleton_Axe.gltf", "handslot.r"], [SKW + "Skeleton_Shield_Large_A.gltf", "handslot.l"]]},
	{"src": SK + "Skeleton_Mage.glb", "out": "res://assets/vat/skeleton_mage.res",
		"anims": [["run", "Walking_D_Skeletons", 16, true], ["attack", "Spellcast_Shoot", 12, true], ["spawn", "Spawn_Ground_Skeletons", 18, false], ["death", "Death_C_Skeletons", 16, false]],
		"attach": [[SKW + "Skeleton_Staff.gltf", "handslot.r"]]},
]


var _frame := 0


# Bake on the first processed frame so the models are inside the tree and
# their AnimationPlayers are live.
func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	for job in jobs:
		_bake(job)
	return true


func _bake(job: Dictionary) -> void:
	var inst: Node3D = load(job.src).instantiate()
	root.add_child(inst)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)

	# Gather geometry: skinned meshes, rigid bone attachments and extra props.
	var parts := []   # {verts, normals, uvs, indices, bones, weights, stride, binds: [bone, bind], rigid_bone, rigid_xf}
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		var arrays := mi.mesh.surface_get_arrays(0)
		var part := {"verts": arrays[Mesh.ARRAY_VERTEX], "normals": arrays[Mesh.ARRAY_NORMAL], "uvs": arrays[Mesh.ARRAY_TEX_UV], "indices": arrays[Mesh.ARRAY_INDEX]}
		if mi.skin:
			var binds := []
			for b in mi.skin.get_bind_count():
				var bone := mi.skin.get_bind_bone(b)
				if bone < 0:
					bone = skel.find_bone(mi.skin.get_bind_name(b))
				binds.append([bone, mi.skin.get_bind_pose(b)])
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			part.bones = bones
			part.weights = arrays[Mesh.ARRAY_WEIGHTS]
			part.stride = bones.size() / part.verts.size()
			part.binds = binds
		else:
			var att := mi.get_parent()
			while att and not att is BoneAttachment3D:
				att = att.get_parent()
			if att == null:
				continue
			part.rigid_bone = skel.find_bone((att as BoneAttachment3D).bone_name)
			part.rigid_xf = _rel(mi, att)
		parts.append(part)
	for extra in job.attach:
		var prop: Node3D = load(extra[0]).instantiate()
		for mi: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			var arrays := mi.mesh.surface_get_arrays(0)
			parts.append({"verts": arrays[Mesh.ARRAY_VERTEX], "normals": arrays[Mesh.ARRAY_NORMAL], "uvs": arrays[Mesh.ARRAY_TEX_UV],
				"indices": arrays[Mesh.ARRAY_INDEX], "rigid_bone": skel.find_bone(extra[1]), "rigid_xf": mi.transform})
		prop.free()

	var vcount := 0
	for p in parts:
		vcount += p.verts.size()
	var rows := 0
	for a in job.anims:
		rows += a[2]
	var pos_img := Image.create(vcount, rows, false, Image.FORMAT_RGBAH)
	var nrm_img := Image.create(vcount, rows, false, Image.FORMAT_RGBA8)
	var anims := {}
	var row := 0
	var max_h := 0.0
	var skel_xf := _rel(skel, inst)
	for a in job.anims:
		var anim := ap.get_animation(a[1])
		var frames: int = a[2]
		var loop: bool = a[3]
		anims[a[0]] = Vector4(row, frames, frames / anim.length if loop else (frames - 1) / anim.length, 1.0 if loop else 0.0)
		ap.play(a[1])
		for f in frames:
			var t := anim.length * f / (frames if loop else frames - 1)
			ap.seek(t, true)
			var glob := _bone_globals(skel)
			var col := 0
			for p in parts:
				var verts: PackedVector3Array = p.verts
				var nrms: PackedVector3Array = p.normals
				if p.has("binds"):
					var mats := []
					for bd in p.binds:
						mats.append(skel_xf * glob[bd[0]] * (bd[1] as Transform3D))
					var bones: PackedInt32Array = p.bones
					var weights: PackedFloat32Array = p.weights
					var stride: int = p.stride
					for v in verts.size():
						var pos := Vector3.ZERO
						var nrm := Vector3.ZERO
						for k in stride:
							var w := weights[v * stride + k]
							if w <= 0.0:
								continue
							var m: Transform3D = mats[bones[v * stride + k]]
							pos += (m * verts[v]) * w
							nrm += (m.basis * nrms[v]) * w
						_write(pos_img, nrm_img, col, row + f, pos, nrm)
						max_h = maxf(max_h, pos.y)
						col += 1
				else:
					var m: Transform3D = skel_xf * glob[p.rigid_bone] * (p.rigid_xf as Transform3D)
					for v in verts.size():
						var pos := m * verts[v]
						_write(pos_img, nrm_img, col, row + f, pos, m.basis * nrms[v])
						col += 1
		row += frames
	# Sanity check: mean vertex movement between two run frames.
	var moved := 0.0
	var run_rows: Vector4 = anims["run"]
	var r2 := int(run_rows.x + run_rows.y / 2)
	for x in range(0, vcount, 7):
		var a0 := pos_img.get_pixel(x, int(run_rows.x))
		var a1 := pos_img.get_pixel(x, r2)
		moved += Vector3(a0.r - a1.r, a0.g - a1.g, a0.b - a1.b).length()
	print("  mean movement across run cycle: %.3f m" % (moved / (vcount / 7.0)))

	# One merged surface; UV2.x = texture column.
	var mv := PackedVector3Array()
	var mn := PackedVector3Array()
	var muv := PackedVector2Array()
	var muv2 := PackedVector2Array()
	var mi_idx := PackedInt32Array()
	var base := 0
	for p in parts:
		var verts: PackedVector3Array = p.verts
		for v in verts.size():
			var c := pos_img.get_pixel(base + v, 0)
			mv.append(Vector3(c.r, c.g, c.b))
			var nc := nrm_img.get_pixel(base + v, 0)
			mn.append(Vector3(nc.r, nc.g, nc.b) * 2.0 - Vector3.ONE)
			muv2.append(Vector2(base + v, 0))
		muv.append_array(p.uvs)
		for i: int in p.indices:
			mi_idx.append(base + i)
		base += verts.size()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mv
	arrays[Mesh.ARRAY_NORMAL] = mn
	arrays[Mesh.ARRAY_TEX_UV] = muv
	arrays[Mesh.ARRAY_TEX_UV2] = muv2
	arrays[Mesh.ARRAY_INDEX] = mi_idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 4, 4))

	var data := VatData.new()
	data.mesh = mesh
	data.positions = pos_img
	data.normals = nrm_img
	data.anims = anims
	data.height = max_h
	var err := ResourceSaver.save(data, job.out, ResourceSaver.FLAG_COMPRESS)
	print("baked %s: %d verts, %d rows, height %.2f, anims %s -> %s (err %d)" % [job.src.get_file(), vcount, rows, max_h, anims, job.out, err])
	inst.queue_free()


func _write(pos_img: Image, nrm_img: Image, x: int, y: int, pos: Vector3, nrm: Vector3) -> void:
	pos_img.set_pixel(x, y, Color(pos.x, pos.y, pos.z, 1.0))
	var n := nrm.normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
	nrm_img.set_pixel(x, y, Color(n.x, n.y, n.z, 1.0))


## Transform of `n` relative to ancestor `top`, from local transforms.
func _rel(n: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p := n
	while p and p != top:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Global (skeleton-space) transform of every bone from the current local poses.
func _bone_globals(skel: Skeleton3D) -> Array:
	var n := skel.get_bone_count()
	var out := []
	out.resize(n)
	var done := []
	done.resize(n)
	done.fill(false)
	for i in n:
		_bone_global(skel, i, out, done)
	return out


func _bone_global(skel: Skeleton3D, i: int, out: Array, done: Array) -> Transform3D:
	if done[i]:
		return out[i]
	var local := skel.get_bone_pose(i)
	var parent := skel.get_bone_parent(i)
	var g := local if parent < 0 else _bone_global(skel, parent, out, done) * local
	out[i] = g
	done[i] = true
	return g
