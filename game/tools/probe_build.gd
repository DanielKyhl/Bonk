extends SceneTree
## Times building the world twice (the second build uses the caches).
func _init():
	for run in 2:
		var t0 := Time.get_ticks_msec()
		var map: MapDef = load("res://scripts/world/maps/hallowed_vale.gd").new()
		var t := Terrain.new()
		root.add_child(t)
		t.setup(map)
		var t1 := Time.get_ticks_msec()
		var p := Props.new()
		root.add_child(p)
		p.setup(map, t)
		var t2 := Time.get_ticks_msec()
		var g := Grass.new()
		root.add_child(g)
		g.setup(map, t, p.pad_positions)
		var t3 := Time.get_ticks_msec()
		print("build %d: terrain %d ms, props %d ms, grass %d ms" % [run + 1, t1 - t0, t2 - t1, t3 - t2])
		t.free()
		p.free()
		g.free()
	quit()
