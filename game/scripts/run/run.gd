extends Node3D
## One stage of a run: builds the map, spawns the hero and wires every system
## together (enemies, weapons, pickups, director, HUD, menus).

const MAP_SCRIPT := "res://scripts/world/maps/hallowed_vale.gd"
const SHIELD_RAM_SPEED := 16.7    ## ~60 km/h

var map: MapDef
var terrain: Terrain
var props: Props
var player: Player
var camera: FollowCamera
var enemies: EnemyManager
var run: RunState
var fx: Fx
var pickups: Pickups
var weapons: WeaponSystem
var director: Director
var hud: Hud
var menus: RunMenus
var _autopilot := false
var _blink := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autopilot = "--autopilot" in args
	var t0 := Time.get_ticks_msec()
	map = load(MAP_SCRIPT).new()
	var env := WorldEnv.new()
	add_child(env)
	env.setup(map)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(map)
	props = Props.new()
	add_child(props)
	props.setup(map, terrain)
	var grass := Grass.new()
	add_child(grass)
	grass.setup(map, terrain, props.pad_positions)
	print("world built in %d ms" % (Time.get_ticks_msec() - t0))

	run = RunState.new()
	add_child(run)
	run.setup(Game.hero_id)

	player = load("res://scenes/actors/player.tscn").instantiate()
	player.terrain = terrain
	player.pads = props.pad_positions
	add_child(player)
	_dress_crusader(player.model)
	player.place(map.spawn)

	fx = Fx.new()
	add_child(fx)
	fx.setup(terrain)

	enemies = EnemyManager.new()
	add_child(enemies)
	enemies.setup(terrain, player)
	enemies.ram_speed = SHIELD_RAM_SPEED
	player.stomp_probe = enemies.stomp_probe
	player.stomp_top = enemies.stomp_top

	camera = FollowCamera.new()
	camera.fov = 42.0
	camera.target = player
	add_child(camera)
	camera.make_current()
	camera.snap()
	camera._process(0.0)

	pickups = Pickups.new()
	add_child(pickups)
	pickups.setup(terrain, player, run, props)

	weapons = WeaponSystem.new()
	add_child(weapons)
	weapons.setup(run, player, enemies, fx, camera)

	director = Director.new()
	add_child(director)
	director.setup(run, enemies, player, terrain)

	hud = Hud.new()
	add_child(hud)
	hud.setup(run, player, director, enemies, map.title)

	menus = RunMenus.new()
	add_child(menus)
	menus.setup(run)

	_connect_signals()
	_apply_stats()
	hud.banner(map.title, "Survive. Go fast. Hit hard.")

	var cap := DebugCapture.new()
	add_child(cap)
	if _autopilot:
		var ap := Autopilot.new()
		ap.player = player
		add_child(ap)
	if "--perf" in args:
		var probe := PerfProbe.new()
		probe.enemies = enemies
		probe.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(probe)
		director.paused = true
		var n := 400
		for a in args:
			if a.begins_with("--count="):
				n = int(a.get_slice("=", 1))
		for k in n:
			var a := randf() * TAU
			var r := randf_range(6.0, 40.0)
			enemies.spawn(k % 4 if k % 11 != 0 else 2, map.spawn.x + cos(a) * r, map.spawn.y + sin(a) * r, 1000.0, false)
	for a in args:
		if a.begins_with("--place="):
			var xz := a.get_slice("=", 1).split(",")
			player.place(Vector2(float(xz[0]), float(xz[1])))
			camera.snap()
			camera._process(0.0)
	if "--loadout" in args:
		for w in ["holy_javelin", "sacred_orbs", "smite"]:
			run.weapons[w] = 3
		run.tomes["might"] = 3
		run.recompute()
	if "--levelup" in args:
		run.add_xp(40.0)
		run.weapons["sacred_orbs"] = 2
		run.tomes["might"] = 1
		run.recompute()
	if "--showcase" in args:
		# Screenshot setup: a tough crowd around the player so the scene stays busy.
		director.paused = true
		for k in 150:
			var a := randf() * TAU
			var r := randf_range(5.0, 24.0)
			var type := 0 if k % 3 != 0 else (1 if k % 2 == 0 else 3)
			if k % 19 == 0:
				type = 2
			enemies.spawn(type, player.position.x + cos(a) * r, player.position.z + sin(a) * r, 60.0, false)
	if "--horde" in args:
		for k in 110:
			var a := randf() * TAU
			var r := randf_range(7.0, 26.0)
			var type := 0 if k % 3 != 0 else (1 if k % 2 == 0 else 3)
			if k % 23 == 0:
				type = 2
			enemies.spawn(type, player.position.x + cos(a) * r, player.position.z + sin(a) * r, 1.0, k % 4 == 0)


func _connect_signals() -> void:
	player.slammed.connect(_on_slam)
	player.stomped.connect(_on_stomp)
	player.landed.connect(_on_land)
	player.launched.connect(_on_launch)
	player.hopped.connect(_on_hop)
	player.air_jumped.connect(func(p): fx.ring(p, 2.2, Color(0.9, 0.95, 1.0), 0.3, 0.1))
	player.slide_started.connect(func(p): fx.dust(p, 5))
	enemies.killed.connect(_on_kill)
	enemies.player_hit.connect(_on_player_hit)
	enemies.tackled.connect(func(p): fx.sparks(p, Color(1.0, 0.9, 0.6), 6); camera.add_shake(1.5))
	run.stats_changed.connect(_apply_stats)
	run.died.connect(_on_death)
	director.banner.connect(hud.banner)
	menus.picked.connect(_on_pick)
	menus.resume_requested.connect(func(): get_tree().paused = false)
	menus.restart_requested.connect(_restart)
	menus.quit_requested.connect(func(): get_tree().quit())


func _process(delta: float) -> void:
	if run.pending_levels > 0 and not menus.is_open() and not run.dead:
		get_tree().paused = true
		hud.clear_banner()
		menus.show_levelup(run.roll_choices())
		if _autopilot and not "--no-autopick" in OS.get_cmdline_user_args():
			_autopick.call_deferred()
	if Input.is_action_just_pressed("pause") and not menus.is_open() and not run.dead:
		get_tree().paused = true
		hud.clear_banner()
		menus.show_pause()
	# Blink while invulnerable after a hit.
	if run.iframes > 0.0:
		_blink += delta * 18.0
		player.model.visible = fmod(_blink, 2.0) < 1.2
	else:
		player.model.visible = true


func _autopick() -> void:
	await get_tree().create_timer(0.45, true, false, true).timeout
	if menus.is_open():
		menus._pick(randi() % 3)


# -----------------------------------------------------------------------------
# Player events
# -----------------------------------------------------------------------------
func _on_slam(pos: Vector3, power: float) -> void:
	var r: float = (3.9 + 1.9 * power) * run.stats.area
	var dmg := 18.0 * power
	for i in enemies.query(pos.x, pos.z, r):
		var d := Vector2(enemies.px[i] - pos.x, enemies.pz[i] - pos.z)
		var f: float = 1.0 - 0.5 * minf(d.length(), r) / r
		weapons.hit(i, dmg * f, d.normalized() * 27.0 * f)
	fx.ring(pos, r, Color(1.0, 0.95, 0.8), 0.4)
	fx.dust(pos, 14)
	camera.add_shake(5.0 * power)


func _on_stomp(i: int, pos: Vector3, slam: bool) -> void:
	var push := Vector2(player.vel.x, player.vel.z) * 0.3
	weapons.hit(i, 60.0 if slam else 30.0, push)
	fx.sparks(pos, Color(1.0, 0.8, 0.4), 8)
	if slam:
		_on_slam(pos, 1.0)
	if player.chain > 1:
		fx.text(pos, "STOMP ×%d" % player.chain, UIStyle.ACCENT)
	camera.add_shake(2.0)


func _on_land(air_time: float, impact: float) -> void:
	if air_time < 0.1:
		return
	fx.dust(player.position, 3 + int(minf(8.0, impact / 6.0)))
	# Crusader passive: Blessed Landings.
	if run.hero_id == "crusader" and air_time > 0.4 and not player.slamming:
		var p := player.position
		var r: float = (2.4 + impact * 0.05) * run.stats.area
		for i in enemies.query(p.x, p.z, r):
			var d := Vector2(enemies.px[i] - p.x, enemies.pz[i] - p.z)
			weapons.hit(i, 10.0 + impact * 0.35, d.normalized() * 12.0)
		fx.ring(p, r, Color(1.0, 0.86, 0.45), 0.35, 0.1)
	if air_time > 1.0:
		fx.text(player.position, "AIR %.1fs" % air_time, UIStyle.XP, 64)


func _on_launch(pos: Vector3) -> void:
	fx.ring(pos, 3.0, Color(1.0, 0.9, 0.55), 0.4)
	fx.sparks(pos + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.55), 14)
	camera.add_shake(2.0)


func _on_hop(chain: int) -> void:
	if chain >= 3:
		fx.text(player.position, "HOP ×%d" % chain, UIStyle.ACCENT, 60)


func _on_kill(type: int, pos: Vector3, xp: int, is_elite: bool) -> void:
	run.kills += 1
	fx.bone_burst(pos, type == 2 or is_elite)
	if is_elite:
		run.elites += 1
		pickups.drop(Pickups.XP_BIG, pos, xp)
		for k in 6:
			pickups.drop(Pickups.GOLD, pos, 4)
		camera.add_shake(4.0)
		return
	pickups.drop(Pickups.XP_BIG if xp >= 3 else Pickups.XP, pos, xp)
	if randf() < 0.16:
		pickups.drop(Pickups.GOLD, pos, randi_range(1, 3))
	if randf() < 0.012:
		pickups.drop(Pickups.HEAL, pos, 20.0)


func _on_player_hit(dmg: float, _from: Vector3) -> void:
	if run.take_damage(dmg):
		hud.hurt()
		camera.add_shake(4.0)
		_blink = 0.0


func _on_pick(c: Dictionary) -> void:
	run.apply_choice(c)
	if run.pending_levels <= 0:
		get_tree().paused = false


func _on_death() -> void:
	player.input_locked = true
	director.paused = true
	await get_tree().create_timer(0.8).timeout
	get_tree().paused = true
	var t := int(run.time)
	menus.show_death("You have fallen", [
		["Survived", "%d:%02d" % [t / 60, t % 60]], ["Kills", run.kills], ["Level", run.level],
		["Top speed", "%d km/h" % int(player.top_speed * Player.KMH)], ["Best hop chain", "×%d" % player.best_chain],
		["Longest air", "%.1f s" % player.best_air],
	])


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _apply_stats() -> void:
	var s := run.stats
	var h: Dictionary = run.hero
	player.run_speed = h.run_speed * s.move_speed
	player.jump_vel = 26.7 * sqrt(s.jump)
	player.hop_boost = 0.12 + 0.03 * s.hop
	player.hop_cap = 34.2 + 5.0 * s.hop


## Placeholder look for the Crusader: the KayKit knight with sword and badge shield.
func _dress_crusader(model: Node) -> void:
	for n in ["1H_Sword_Offhand", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"]:
		var node := model.find_child(n, true, false)
		if node:
			node.visible = false
