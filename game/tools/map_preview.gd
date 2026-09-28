extends SceneTree
## Writes a top-down hillshade of a map's terrain (cliffs in red, ramps and
## pads marked) for checking layouts without playing.
## godot --headless --path game --script res://tools/map_preview.gd -- out.png [map script]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "map.png"
	var script := args[1] if args.size() > 1 else "res://scripts/world/maps/hallowed_vale.gd"
	var map: MapDef = load(script).new()
	var t := Terrain.new()
	root.add_child(t)
	t.setup(map)
	var res := 2.0  # pixels per meter
	var n := int(map.half_size * 2.0 * res)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-1, 2, -1).normalized()
	for py in n:
		for px in n:
			var x := -map.half_size + (px + 0.5) / res
			var z := -map.half_size + (py + 0.5) / res
			var h := t.height(x, z)
			var nrm := Vector3(-t.gx, 1.0, -t.gz).normalized()
			var shade := clampf(nrm.dot(light), 0.0, 1.0)
			var base := Color(0.35, 0.4, 0.3).lerp(Color(0.8, 0.78, 0.7), clampf((h + 8.0) / 24.0, 0.0, 1.0))
			var c := base * (0.35 + 0.75 * shade)
			var steep := sqrt(t.gx * t.gx + t.gz * t.gz)
			if steep > Player.MAX_CLIMB:
				c = Color(0.75, 0.15, 0.1)
			img.set_pixel(px, py, c)
	for p in map.pads:
		_dot(img, p, map.half_size, res, Color(1, 0.9, 0.3))
	for lm in map.landmarks:
		_dot(img, lm.pos, map.half_size, res, Color(0.3, 0.6, 1.0))
	_dot(img, map.spawn, map.half_size, res, Color(1, 1, 1))
	img.save_png(out)
	print("saved ", out)
	quit()


func _dot(img: Image, p: Vector2, half: float, res: float, c: Color) -> void:
	var cx := int((p.x + half) * res)
	var cy := int((p.y + half) * res)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := clampi(cx + dx, 0, img.get_width() - 1)
			var y := clampi(cy + dy, 0, img.get_height() - 1)
			img.set_pixel(x, y, c)
