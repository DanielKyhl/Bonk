class_name Director
extends Node
## Spawns the horde. A stage lasts 10 minutes; the spawn rate and enemy
## toughness climb with time, new enemy types join, "the dead rise" waves erupt
## around you, elites appear every minute, and when the clock runs out an
## endless final swarm begins.

signal banner(text: String, sub: String)
signal final_swarm_started

const STAGE_TIME := 600.0
const MAX_ALIVE := 420

enum { SKELETON, ROGUE, WARRIOR, MAGE }

var run: RunState
var enemies: EnemyManager
var player: Player
var terrain: Terrain
var time_left := STAGE_TIME
var final_swarm := false
var paused := false
## Offerings made at greed shrines: each adds 20% more spawns.
var greed := 0

var _acc := 0.0
var _next_wave := 75.0
var _next_elite := 60.0
var _wave := 0


func setup(r: RunState, e: EnemyManager, p: Player, t: Terrain) -> void:
	run = r
	enemies = e
	player = p
	terrain = t


func _process(delta: float) -> void:
	if paused or run.dead:
		return
	var t := run.time
	time_left = STAGE_TIME - t
	if time_left <= 0.0 and not final_swarm:
		final_swarm = true
		banner.emit("The Final Swarm", "Survive as long as you can")
		final_swarm_started.emit()
	_acc += spawn_rate(t) * delta
	while _acc >= 1.0:
		_acc -= 1.0
		if enemies.count < MAX_ALIVE:
			var p := _spawn_point(34.0)
			enemies.spawn(_pick_type(t), p.x, p.y, hp_mult(t))
	if t >= _next_wave:
		_next_wave += 90.0
		_rising_wave(t)
	if t >= _next_elite:
		_next_elite += 60.0
		var p := _spawn_point(26.0)
		var type := WARRIOR if t > 150.0 else SKELETON
		enemies.spawn(type, p.x, p.y, hp_mult(t), true, true)
		banner.emit("An elite approaches", "")


## A cursed altar's summons: n elites plus a ring of their followers.
func summon_elites(n: int) -> void:
	var t := run.time
	for k in n:
		var p := _spawn_point(18.0)
		enemies.spawn([WARRIOR, SKELETON, MAGE][k % 3] if t > 120.0 else SKELETON, p.x, p.y, hp_mult(t) * 1.2, true, true)
	for k in 24:
		var p := _spawn_point(22.0)
		enemies.spawn(_pick_type(t), p.x, p.y, hp_mult(t))


## Enemies per second at time t.
func spawn_rate(t: float) -> float:
	var m := t / 60.0
	var r := (1.3 + 0.85 * m + 0.05 * m * m) * (1.0 + 0.2 * greed)
	if final_swarm:
		r = r * 2.2 + (t - STAGE_TIME) * 0.05
	return r


func hp_mult(t: float) -> float:
	var h := 1.0 + t / 140.0
	if final_swarm:
		h += (t - STAGE_TIME) / 30.0
	return h


func _pick_type(t: float) -> int:
	var r := randf()
	if t > 180.0 and r < minf(0.04 + (t - 180.0) / 4000.0, 0.14):
		return WARRIOR
	if t > 120.0 and r < 0.22:
		return MAGE if randf() < 0.45 else ROGUE
	if t > 60.0 and r < 0.3:
		return ROGUE
	return SKELETON


## A point on a ring around the player, biased ahead when you're moving fast.
func _spawn_point(radius: float) -> Vector2:
	var p := Vector2(player.position.x, player.position.z)
	var v := Vector2(player.vel.x, player.vel.z)
	for attempt in 8:
		var a := randf() * TAU
		if v.length() > 8.0 and randf() < 0.55:
			a = v.angle() + randf_range(-1.0, 1.0)
		var q := p + Vector2(cos(a), sin(a)) * radius * randf_range(1.0, 1.15)
		q = terrain.clamp_to_map(q, 8.0)
		if not terrain.in_solid(q.x, q.y, 1.0):
			return q
	return terrain.clamp_to_map(p + Vector2(radius, 0), 8.0)


## A ring of skeletons claws out of the ground around you.
func _rising_wave(t: float) -> void:
	_wave += 1
	var n := mini(24 + _wave * 8, 72)
	var r := 13.0
	var p := Vector2(player.position.x, player.position.z)
	for k in n:
		var a := TAU * k / n
		var q := terrain.clamp_to_map(p + Vector2(cos(a), sin(a)) * r * randf_range(0.95, 1.05), 6.0)
		if terrain.in_solid(q.x, q.y, 0.5):
			continue
		var type := ROGUE if t > 150.0 and k % 4 == 0 else SKELETON
		enemies.spawn(type, q.x, q.y, hp_mult(t))
	banner.emit("The dead rise!", "Jump the ring or cut through it")
