extends "res://tests/movement_test.gd"
## Bunny hop on a flat map: speed should climb ~12% per perfect hop up to the cap.

func _ready() -> void:
	Engine.max_fps = 60
	var map: MapDef = load("res://tests/flat_map.gd").new()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(map)
	player = load("res://scenes/actors/player.tscn").instantiate()
	player.terrain = terrain
	add_child(player)
	player.hopped.connect(func(c): if c > 0: print("  perfect hop %d -> %d km/h" % [c, _kmh()]))
	await _place(-120, 0)
	Input.action_press("move_right")
	var pressed := false
	for i in 400:
		var ha := player.height_above_ground()
		if not pressed and (player.grounded or (player.vel.y < 0.0 and ha < 1.2)):
			Input.action_press("jump")
			pressed = true
		elif pressed and not player.grounded and player.vel.y > 0.0:
			Input.action_release("jump")
			pressed = false
		await _frames(1)
	print("final %d km/h, chain %d, x=%.0f" % [_kmh(), player.best_chain, player.position.x])
	get_tree().quit()
