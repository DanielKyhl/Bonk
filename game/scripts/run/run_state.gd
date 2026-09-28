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
signal blocked
signal revived
signal item_added(id: String)

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
## Crusader passive: Holy Aegis blocks one hit, then recharges.
var aegis_cd := 0.0
const AEGIS_TIME := 12.0
var weapons := {}   ## id -> level, in pickup order
var tomes := {}     ## id -> level
var items := {}     ## id -> stacks, in pickup order
var revives_used := 0
var blessings := {}  ## stat -> total from prayer shrines
var boss_killed := false
var boss_time := 0.0
## Kills and elites add score as you play (doubled after the boss falls);
## final_score() adds time and level.
var score := 0
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
	aegis_cd = maxf(0.0, aegis_cd - delta)
	if stats.regen > 0.0 and hp < max_hp:
		heal(stats.regen * delta)


func recompute() -> void:
	stats = Defs.BASE_STATS.duplicate()
	for id in tomes:
		var t: Dictionary = Defs.TOMES[id]
		stats[t.stat] += t.add * tomes[id]
	for id in items:
		var it: Dictionary = Defs.ITEMS[id]
		for k: String in it.stats:
			stats[k] += it.stats[k] * items[id]
	for k: String in blessings:
		stats[k] += blessings[k]
	var old_max := max_hp
	max_hp = hero.hp + stats.max_hp
	if max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	stats_changed.emit()
	hp_changed.emit(hp, max_hp)


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


func spend_gold(v: int) -> void:
	gold = maxi(0, gold - v)
	gold_changed.emit(gold)


func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)
	hp_changed.emit(hp, max_hp)


## Returns true if the hit landed (not blocked by invulnerability frames).
func take_damage(amount: float) -> bool:
	if iframes > 0.0 or dead:
		return false
	if hero_id == "crusader" and aegis_cd <= 0.0:
		aegis_cd = AEGIS_TIME
		iframes = 0.5
		blocked.emit()
		return false
	hp -= amount * (1.0 - clampf(stats.armor, 0.0, 0.8))
	iframes = 0.55
	if hp <= 0.0:
		if stats.revive > revives_used:
			revives_used += 1
			hp = max_hp * 0.5
			iframes = 2.0
			hp_changed.emit(hp, max_hp)
			revived.emit()
			return true
		hp = 0.0
		dead = true
		hp_changed.emit(hp, max_hp)
		died.emit()
		return true
	hp_changed.emit(hp, max_hp)
	return true


## Everything a boss portal carries to the next map.
func snapshot() -> Dictionary:
	return {"weapons": weapons.duplicate(), "tomes": tomes.duplicate(), "items": items.duplicate(),
			"blessings": blessings.duplicate(), "level": level, "xp": xp, "xp_next": xp_next, "gold": gold,
			"hp_frac": hp / max_hp, "kills": kills, "elites": elites, "score": final_score(), "revives_used": revives_used}


func restore(c: Dictionary) -> void:
	weapons = c.weapons
	tomes = c.tomes
	items = c.items
	blessings = c.blessings
	level = c.level
	xp = c.xp
	xp_next = c.xp_next
	gold = c.gold
	kills = c.kills
	elites = c.elites
	score = c.score
	revives_used = c.revives_used
	recompute()
	hp = max_hp * clampf(c.hp_frac, 0.3, 1.0)
	hp_changed.emit(hp, max_hp)
	xp_changed.emit(xp, xp_next, level)
	gold_changed.emit(gold)


func final_score() -> int:
	return score + int(time) * 2 + level * 20 + (5000 if boss_killed else 0)


func add_blessing(b: Dictionary) -> void:
	blessings[b.stat] = blessings.get(b.stat, 0.0) + b.add
	recompute()


func add_item(id: String) -> void:
	items[id] = items.get(id, 0) + 1
	recompute()
	item_added.emit(id)


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
