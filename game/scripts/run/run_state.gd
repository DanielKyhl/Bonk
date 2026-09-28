class_name RunState
extends Node
## Everything about the current run that isn't physics: health, XP, levels,
## gold, owned weapons/tomes/items, and the stats they add up to.

signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: float, needed: float, level: int)
signal gold_changed(gold: int)
signal leveled_up(level: int)
signal stats_changed
signal died

const MAX_WEAPONS := 4
const MAX_TOMES := 4

var hero_id := "crusader"
var hero: Dictionary
var hp := 100.0
var max_hp := 100.0
var level := 1
var xp := 0.0
var xp_next := 10.0
var pending_levels := 0
var gold := 0
var kills := 0
var elites := 0
var time := 0.0
var iframes := 0.0
var dead := false
var weapons := {}   ## id -> level, in pickup order
var tomes := {}     ## id -> level
var items := {}     ## id -> stacks
var stats := {}


func setup(id: String) -> void:
	hero_id = id
	hero = Defs.HEROES[id]
	weapons[hero.weapon] = 1
	xp_next = Defs.xp_needed(1)
	recompute()
	hp = max_hp


func _process(delta: float) -> void:
	if dead:
		return
	time += delta
	iframes = maxf(0.0, iframes - delta)
	if stats.regen > 0.0 and hp < max_hp:
		heal(stats.regen * delta)


func recompute() -> void:
	stats = Defs.BASE_STATS.duplicate()
	for id in tomes:
		var t: Dictionary = Defs.TOMES[id]
		stats[t.stat] += t.add * tomes[id]
	var old_max := max_hp
	max_hp = hero.hp + stats.max_hp
	if max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	stats_changed.emit()
	hp_changed.emit(hp, max_hp)


## Damage multiplier from speed: the core rule of the game.
func momentum_mult(speed: float) -> float:
	return 1.0 + stats.momentum * maxf(0.0, speed - 12.5) / 12.5


func add_xp(v: float) -> void:
	xp += v * stats.xp
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = Defs.xp_needed(level)
		pending_levels += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_next, level)


func add_gold(v: int) -> void:
	gold += int(round(v * stats.gold))
	gold_changed.emit(gold)


func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)
	hp_changed.emit(hp, max_hp)


## Returns true if the hit landed (not blocked by invulnerability frames).
func take_damage(amount: float) -> bool:
	if iframes > 0.0 or dead:
		return false
	hp -= amount * (1.0 - clampf(stats.armor, 0.0, 0.8))
	iframes = 0.55
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit()
	return true


# -----------------------------------------------------------------------------
# Level-up choices
# -----------------------------------------------------------------------------
## Up to 3 random offers: new weapons, weapon upgrades, new tomes, tome upgrades.
func roll_choices() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for id in weapons:
		if weapons[id] < Defs.WEAPONS[id].max:
			pool.append({"kind": "weapon", "id": id, "weight": 3.0})
	if weapons.size() < MAX_WEAPONS:
		for id in Defs.WEAPONS:
			if not weapons.has(id):
				pool.append({"kind": "weapon", "id": id, "weight": 1.4})
	for id in tomes:
		if tomes[id] < Defs.TOMES[id].max:
			pool.append({"kind": "tome", "id": id, "weight": 2.2})
	if tomes.size() < MAX_TOMES:
		for id in Defs.TOMES:
			if not tomes.has(id):
				pool.append({"kind": "tome", "id": id, "weight": 1.0})
	var out: Array[Dictionary] = []
	while out.size() < 3 and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += c.weight
		var r := randf() * total
		for k in pool.size():
			r -= pool[k].weight
			if r <= 0.0:
				out.append(pool[k])
				pool.remove_at(k)
				break
	if out.is_empty():
		out.append({"kind": "heal", "id": "heal"})
	return out


func apply_choice(c: Dictionary) -> void:
	match c.kind:
		"weapon":
			weapons[c.id] = weapons.get(c.id, 0) + 1
		"tome":
			tomes[c.id] = tomes.get(c.id, 0) + 1
			recompute()
		"heal":
			heal(max_hp * 0.4)
	pending_levels = maxi(0, pending_levels - 1)
	stats_changed.emit()
