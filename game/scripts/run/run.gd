extends Node3D
## One stage of a run: builds the map, spawns the hero and wires every system
## together (enemies, weapons, pickups, director, HUD, menus).

const MENU_SCENE := "res://scenes/menu.tscn"

var map: MapDef
var terrain: Terrain
var props: Props
var player: Player
var camera: MouseLookCamera
var enemies: EnemyManager
var run: RunState
var fx: Fx
var pickups: Pickups
var weapons: WeaponSystem
var director: Director
var chests: Chests
var shrines: Shrines
var boss: Boss
var hud: Hud
var menus: RunMenus
var view: PixelView
var world: Node3D
var _autopilot := false
var _blink := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autopilot = "--autopilot" in args
	var t0 := Time.get_ticks_msec()
	map = load(Game.map_info(Game.map_id).script).new()
	view = PixelView.new()
	add_child(view)
	world = view.world
	var env := WorldEnv.new()
	world.add_child(env)
	env.setup(map)
	terrain = Terrain.new()
	world.add_child(terrain)
	terrain.setup(map)
	props = Props.new()
	world.add_child(props)
	props.setup(map, terrain)
	var grass := Grass.new()
	world.add_child(grass)
	grass.setup(map, terrain, props.pad_positions)
	print("world built in %d ms" % (Time.get_ticks_msec() - t0))

	run = RunState.new()
	world.add_child(run)
	run.setup(Game.hero_id)

	player = load("res://scenes/actors/player.tscn").instantiate()
	player.terrain = terrain
	player.pads = props.pad_positions
	world.add_child(player)
	player.place(map.spawn)

	fx = Fx.new()
	world.add_child(fx)
	fx.setup(terrain)

	enemies = EnemyManager.new()
	world.add_child(enemies)
	enemies.setup(terrain, player)
	player.stomp_probe = enemies.stomp_probe
	player.stomp_top = enemies.stomp_top

	camera = load("res://scenes/actors/camera.tscn").instantiate()
	camera.target = player
	camera.view = view
	world.add_child(camera)
	camera.make_current()
	camera.snap()
	camera._process(0.0)

	pickups = Pickups.new()
	world.add_child(pickups)
	pickups.setup(terrain, player, run, props)

	chests = Chests.new()
	world.add_child(chests)
	chests.setup(map, terrain, props, run, player, fx)

	shrines = Shrines.new()
	world.add_child(shrines)
	shrines.setup(map, terrain, props, run, player, fx, chests.pos)

	weapons = WeaponSystem.new()
	world.add_child(weapons)
	weapons.setup(run, player, enemies, fx, camera)

	director = Director.new()
	world.add_child(director)
	director.setup(run, enemies, player, terrain)

	hud = Hud.new()
	add_child(hud)
	boss = Boss.new()
	world.add_child(boss)
	boss.setup(map, terrain, props, run, player, enemies, fx, camera)

	hud.chests = chests
	hud.boss = boss
	hud.shrines = shrines
	hud.camera = camera
	hud.terrain = terrain
	hud.map = map
	hud.setup(run, player, director, enemies, map.title)

	menus = RunMenus.new()
	add_child(menus)
	menus.setup(run)

	_connect_signals()
	_apply_stats()
	hud.banner(map.title, "Survive until the dead stop rising.")

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
		if a.begins_with("--yaw="):
			camera.yaw = deg_to_rad(float(a.get_slice("=", 1)))
			camera._target_yaw = camera.yaw
		if a.begins_with("--place="):
			var xz := a.get_slice("=", 1).split(",")
			player.place(Vector2(float(xz[0]), float(xz[1])))
			camera.snap()
			camera._process(0.0)
	if "--boss" in args:
		player.place(Vector2(boss.altar.x + 2.0, boss.altar.z + 14.0))
		camera.snap()
		camera._process(0.0)
		director.paused = true
		get_tree().create_timer(0.3).timeout.connect(boss._summon)
	if "--victory" in args:
		# Test the win flow: summon, slay, then step through the portal.
		player.place(Vector2(boss.altar.x + 2.0, boss.altar.z + 2.0))
		camera.snap()
		camera._process(0.0)
		director.paused = true
		boss._summon()
		get_tree().create_timer(0.8).timeout.connect(func(): enemies.damage(enemies.boss_index(), 1e9))
		get_tree().create_timer(2.0).timeout.connect(func(): boss.portal_entered.emit())
	if "--shrine" in args:
		var si := shrines.kind.find(Shrines.PRAYER)
		player.place(Vector2(shrines.pos[si].x + 1.0, shrines.pos[si].z))
		camera.snap()
		camera._process(0.0)
		director.paused = true
	if "--chest" in args:
		# Screenshot setup: stand next to a chest with gold and open it.
		run.add_gold(300)
		var cp: Vector3 = chests.pos[chests.pos.size() - 1]
		player.place(Vector2(cp.x + 1.6, cp.z))
		camera.snap()
		camera._process(0.0)
		get_tree().create_timer(0.4).timeout.connect(func(): chests._open(chests.nearest()))
		get_tree().create_timer(0.7).timeout.connect(func(): chests.spawn_golden(player.position + Vector3(-3, 0, 1)))
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
	run.stats_changed.connect(_apply_stats)
	run.died.connect(_on_death)
	run.revived.connect(func(): fx.ring(player.position, 6.0, Color(1.0, 0.55, 0.2), 0.6, 0.2); fx.sparks(player.position + Vector3(0, 1, 0), Color(1.0, 0.6, 0.25), 30); fx.text(player.position, "RISEN", Color(1.0, 0.6, 0.25), 20); enemies.push_away(player.position, 9.0, 30.0))
	run.blocked.connect(func(): fx.ring(player.position, 2.2, Color(1.0, 0.85, 0.45), 0.35, 0.12); fx.text(player.position, "BLOCKED", UIStyle.GOLD, 20))
	director.banner.connect(hud.banner)
	shrines.prayed.connect(_on_prayed)
	boss.summoned.connect(func(): hud.banner("Varnoth, the Lich King", "The dead king rises"))
	boss.portal_entered.connect(_on_victory)
	shrines.cursed.connect(func(): director.summon_elites(3); hud.banner("The altar wakes", "Slay its champions for golden chests"); camera.add_shake(5.0))
	shrines.greed_taken.connect(func(): director.greed += 1; hud.banner("Greed", "+25% gold, but the dead come faster"))
	menus.picked.connect(_on_pick)
	menus.resume_requested.connect(func(): get_tree().paused = false)
	menus.restart_requested.connect(_restart)
	menus.quit_requested.connect(func(): get_tree().quit())
	menus.menu_requested.connect(func(): get_tree().paused = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; get_tree().change_scene_to_file(MENU_SCENE))


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
## Movement tricks are for getting around; only weapons deal damage.
func _on_slam(pos: Vector3, power: float) -> void:
	fx.ring(pos, 2.5 + power, Color(0.85, 0.8, 0.7), 0.3, 0.08)
	fx.dust(pos, 10)
	camera.add_shake(2.5 * power)


func _on_stomp(_i: int, pos: Vector3, _slam: bool) -> void:
	fx.dust(pos, 6)
	camera.add_shake(1.0)


func _on_land(air_time: float, impact: float) -> void:
	if air_time < 0.1:
		return
	fx.dust(player.position, 3 + int(minf(8.0, impact / 6.0)))


func _on_launch(pos: Vector3) -> void:
	fx.ring(pos, 3.0, Color(1.0, 0.9, 0.55), 0.4)
	fx.sparks(pos + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.55), 14)
	camera.add_shake(2.0)


func _on_hop(_chain: int) -> void:
	pass


func _on_kill(type: int, pos: Vector3, xp: int, is_elite: bool) -> void:
	run.kills += 1
	run.score += 25 if is_elite else (2 if run.boss_killed else 1)
	if type == EnemyManager.BOSS:
		_on_boss_down(pos)
		return
	fx.bone_burst(pos, type == 2 or is_elite)
	if is_elite:
		run.elites += 1
		pickups.drop(Pickups.XP_BIG, pos, xp)
		for k in 6:
			pickups.drop(Pickups.GOLD, pos, 4)
		chests.spawn_golden(pos)
		camera.add_shake(4.0)
		return
	pickups.drop(Pickups.XP_BIG if xp >= 3 else Pickups.XP, pos, xp)
	if run.stats.heart_drop > 0.0 and randf() < run.stats.heart_drop:
		pickups.drop(Pickups.HEAL, pos, 20.0)
	if randf() < 0.16:
		pickups.drop(Pickups.GOLD, pos, randi_range(1, 3))
	if randf() < 0.012:
		pickups.drop(Pickups.HEAL, pos, 20.0)


func _on_boss_down(pos: Vector3) -> void:
	run.boss_killed = true
	run.boss_time = run.time
	boss.on_defeated(pos)
	fx.bone_burst(pos, true)
	fx.ring(pos, 16.0, Color(0.6, 0.9, 1.0), 0.9, 0.2)
	camera.add_shake(10.0)
	chests.spawn_golden(pos + Vector3(-3, 0, 2), 3)
	chests.spawn_golden(pos + Vector3(3, 0, 2), 3)
	chests.spawn_golden(pos + Vector3(0, 0, -3), 2)
	for k in 12:
		pickups.drop(Pickups.XP_BIG, pos, 40.0)
		pickups.drop(Pickups.GOLD, pos, 10)
	hud.banner("The Lich King has fallen", "Take the portal at his altar to leave, or stay and fight on for glory")


func _on_victory() -> void:
	player.input_locked = true
	director.paused = true
	var next := Game.unlock_next_map(map.id)
	get_tree().paused = true
	hud.clear_banner()
	var t := int(run.time)
	var rows := [
		["Score", run.final_score()], ["Time", "%d:%02d" % [t / 60, t % 60]], ["Kills", run.kills],
		["Level", run.level], ["Elites slain", run.elites], ["Items", run.items.size()],
	]
	var sub := "The Vale is cleansed." + ("  %s is now open." % next if next != "" else "")
	var heroes := _record()
	if not heroes.is_empty():
		sub += "\nNew hero: " + ", ".join(heroes)
	menus.show_death("Victory", rows, sub)


## Saves this run's progress; returns heroes it unlocked.
func _record() -> Array[String]:
	return Game.record_run(run, maxf(0.0, run.time - Director.STAGE_TIME), chests.opened_count, shrines.prayers, run.boss_time)


func _on_player_hit(dmg: float, _from: Vector3, enemy: int) -> void:
	if run.stats.thorns > 0.0 and enemy >= 0 and enemies.is_alive(enemy):
		enemies.damage(enemy, run.stats.thorns * run.stats.damage)
	if run.take_damage(dmg):
		hud.hurt()
		camera.add_shake(4.0)
		_blink = 0.0


func _on_prayed(choices: Array[Dictionary]) -> void:
	get_tree().paused = true
	hud.clear_banner()
	menus.show_levelup(choices, "Blessing")


func _on_pick(c: Dictionary) -> void:
	if c.kind == "blessing":
		run.add_blessing(c)
	else:
		run.apply_choice(c)
	if run.pending_levels <= 0:
		get_tree().paused = false


func _on_death() -> void:
	player.input_locked = true
	director.paused = true
	await get_tree().create_timer(0.8).timeout
	get_tree().paused = true
	var t := int(run.time)
	var heroes := _record()
	menus.show_death("You have fallen", [
		["Score", run.final_score()], ["Survived", "%d:%02d" % [t / 60, t % 60]], ["Kills", run.kills], ["Level", run.level],
		["Elites slain", run.elites], ["Gold", run.gold],
	], "New hero: " + ", ".join(heroes) if not heroes.is_empty() else "")


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _apply_stats() -> void:
	var s := run.stats
	var h: Dictionary = run.hero
	player.run_speed = h.run_speed * s.move_speed
	player.jump_vel = 26.7 * sqrt(s.jump)
	player.hop_boost = 0.10 + 0.03 * s.hop
	player.hop_cap = 27.8 + 4.0 * s.hop
	player.air_jumps = int(s.air_jump)
