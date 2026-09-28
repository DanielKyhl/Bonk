extends Node
## Headless movement checks: godot --headless --path . res://tests/movement_test.tscn
## Drives the real input actions and prints measured results.

var terrain: Terrain
var player: Player
var results := {}


func _ready() -> void:
	Engine.max_fps = 60
	var map: MapDef = load("res://scripts/world/maps/hallowed_vale.gd").new()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(map)
	player = load("res://scenes/actors/player.tscn").instantiate()
	player.terrain = terrain
	for p in map.pads:
		player.pads.append(p)
	add_child(player)
	await _run_tests()
	for k in results:
		print("%-14s %s" % [k, results[k]])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "slide"]:
		Input.action_release(a)


func _place(x: float, z: float, vx := 0.0, vz := 0.0) -> void:
	_release_all()
	await _frames(2)
	player.place(Vector2(x, z))
	player.vel = Vector3(vx, 0, vz)
	player.chain = 0
	player.best_chain = 0
	player.sliding = false
	player.slamming = false
	player.ground_time = 1.0
	player.last_air = 0.0


func _kmh() -> int:
	return int(player.speed() * Player.KMH)


func _run_tests() -> void:
	# Plain running on flat-ish ground.
	await _place(0, 20)
	Input.action_press("move_right")
	await _frames(120)
	results["run"] = "%d km/h" % _kmh()

	# Perfect bunny hops for ~4 s.
	await _place(-100, 20)
	Input.action_press("move_right")
	var pressed := false
	var best := 0.0
	for i in 240:
		var ha := player.height_above_ground()
		if not pressed and (player.grounded or (player.vel.y < 0.0 and ha < 1.2)):
			Input.action_press("jump")
			pressed = true
		elif pressed and not player.grounded and player.vel.y > 0.0:
			Input.action_release("jump")
			pressed = false
		best = maxf(best, player.speed())
		await _frames(1)
	results["bhop"] = "%d km/h, chain %d" % [int(best * Player.KMH), player.best_chain]

	# Slide down Cathedral Hill (summit at 0, -86), heading south.
	await _place(0, -80, 0, 8)
	Input.action_press("move_down")
	Input.action_press("slide")
	var top := 0.0
	for i in 90:
		top = maxf(top, player.speed())
		await _frames(1)
	results["slide hill"] = "%d km/h" % int(top * Player.KMH)
	await _place(0, -80, 0, 8)
	Input.action_press("move_down")
	top = 0.0
	for i in 90:
		top = maxf(top, player.speed())
		await _frames(1)
	results["run hill"] = "%d km/h" % int(top * Player.KMH)

	# Ramp at (14, 22) pointing east: run off it fast.
	await _place(4, 22, 30, 0)
	Input.action_press("move_right")
	var max_h := 0.0
	var max_air := 0.0
	for i in 90:
		max_h = maxf(max_h, player.height_above_ground())
		max_air = maxf(max_air, player.air_time)
		await _frames(1)
	results["ramp"] = "%.1f m high, %.2f s air" % [max_h, max_air]

	# Slam from 8 m up while moving: should slide out faster.
	await _place(40, 20, 12.5, 0)
	player.grounded = false
	player.position.y += 8.0
	player.air_time = 0.5
	Input.action_press("move_right")
	Input.action_press("slide")
	await _frames(3)
	var slamming := player.slamming
	var landed := false
	for i in 60:
		await _frames(1)
		if player.grounded:
			landed = true
			break
	results["slam"] = "slamming %s, landed %s, sliding %s, %d km/h" % [slamming, landed, player.sliding, _kmh()]

	# Launch pad (holy spring at -18, -16).
	await _place(-18, -12, 0, -6)
	Input.action_press("move_up")
	max_h = 0.0
	for i in 120:
		max_h = maxf(max_h, player.height_above_ground())
		await _frames(1)
	results["pad"] = "%.1f m high" % max_h

	# Plateau walls: running at the keep plateau side should stop you (no ramp there).
	await _place(-10, 128, 0, -12.5)
	Input.action_press("move_up")
	await _frames(120)
	results["plateau wall"] = "stopped at z=%.1f, y=%.1f (edge ~z=123)" % [player.position.z, player.position.y]
	_release_all()
