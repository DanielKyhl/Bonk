class_name Defs
extends RefCounted
## Game data: heroes, weapons and tomes. Balance numbers live here.

## Heroes. Only the Crusader is unlocked at the start.
const HEROES := {
	"crusader": {
		"name": "Aurelia, the Crusader",
		"title": "Crusader",
		"blurb": "A holy knight in steel and gold, sworn to burn the undead from the vale.",
		"weapon": "radiant_flail",
		"hp": 120.0,
		"run_speed": 9.5,
		"passive": "Holy Aegis: a holy shield blocks one hit, then recharges for 12 seconds.",
		"unlock": "",
	},
}

## Every hero in menu order, with what unlocks them. `stat` is a saved
## progress value (see Game.record_run) that must reach `need`. Heroes not in
## HEROES yet are shown as coming soon.
const ROSTER := [
	{"id": "crusader", "name": "Crusader", "unlock": ""},
	{"id": "dragonborn", "name": "Dragonborn", "unlock": "Slay the Lich King", "stat": "boss_kills", "need": 1},
	{"id": "stormcaller", "name": "Stormcaller", "unlock": "Reach level 30 in one run", "stat": "best_level", "need": 30},
	{"id": "werewolf", "name": "Werewolf", "unlock": "Slay 1,500 foes in one run", "stat": "best_kills", "need": 1500},
	{"id": "chainwarden", "name": "Chainwarden", "unlock": "Open 12 chests in one run", "stat": "best_chests", "need": 12},
	{"id": "frost_witch", "name": "Frost Witch", "unlock": "Survive 3 minutes of the Final Swarm", "stat": "best_swarm", "need": 180},
	{"id": "rune_golem", "name": "Rune Golem", "unlock": "Pray at 6 shrines in one run", "stat": "best_prayers", "need": 6},
	{"id": "wraith_knight", "name": "Wraith Knight", "unlock": "Slay 100 elites in all", "stat": "total_elites", "need": 100},
	{"id": "necromancer", "name": "Necromancer", "unlock": "Slay 25,000 foes in all", "stat": "total_kills", "need": 25000},
	{"id": "chronomancer", "name": "Chronomancer", "unlock": "Slay the Lich King before 8:00", "stat": "fast_boss", "need": 1},
]

## Weapons. Values are for level 1; `per_level` adds per level after 1.
## kind picks the behavior in WeaponSystem.
const WEAPONS := {
	"radiant_flail": {
		"name": "Radiant Flail", "kind": "sweep", "max": 7,
		"desc": "Sweeps a blessed flail around you, knocking enemies back.",
		"damage": 16.0, "cooldown": 1.15, "area": 3.4, "count": 1, "knock": 16.0,
		"per_level": {"damage": 5.0, "area": 0.25, "cooldown": -0.06},
		"milestones": {4: {"count": 1}, 7: {"count": 1}},
		"color": Color(1.0, 0.82, 0.4),
	},
	"holy_javelin": {
		"name": "Holy Javelin", "kind": "javelin", "max": 7,
		"desc": "Hurls piercing javelins at the nearest enemy. They fly faster the faster you run.",
		"damage": 22.0, "cooldown": 1.0, "speed": 38.0, "pierce": 2, "count": 1, "knock": 6.0,
		"per_level": {"damage": 6.0, "cooldown": -0.05},
		"milestones": {3: {"count": 1}, 5: {"pierce": 2}, 7: {"count": 1}},
		"color": Color(1.0, 0.93, 0.62),
	},
	"sacred_orbs": {
		"name": "Sacred Orbs", "kind": "orbit", "max": 7,
		"desc": "Orbs of light circle you and burn what they touch.",
		"damage": 9.0, "cooldown": 0.45, "area": 3.2, "count": 2, "knock": 5.0, "spin": 3.2,
		"per_level": {"damage": 3.0},
		"milestones": {2: {"count": 1}, 4: {"count": 1}, 6: {"count": 1}, 7: {"area": 0.8}},
		"color": Color(0.7, 0.9, 1.0),
	},
	"smite": {
		"name": "Smite", "kind": "smite", "max": 7,
		"desc": "Pillars of holy light strike enemies around you.",
		"damage": 34.0, "cooldown": 2.2, "area": 1.8, "count": 2, "knock": 8.0, "range": 18.0,
		"per_level": {"damage": 8.0, "cooldown": -0.1},
		"milestones": {3: {"count": 1}, 5: {"count": 1}, 7: {"area": 0.6}},
		"color": Color(1.0, 0.95, 0.75),
	},
	"consecration": {
		"name": "Consecration", "kind": "aura", "max": 7,
		"desc": "Holy ground follows you and scorches the undead. Grows while you're fast.",
		"damage": 7.0, "cooldown": 0.5, "area": 3.0, "count": 1, "knock": 0.0,
		"per_level": {"damage": 2.5, "area": 0.3},
		"milestones": {},
		"color": Color(1.0, 0.85, 0.45),
	},
	"throwing_axes": {
		"name": "Throwing Axes", "kind": "axes", "max": 7,
		"desc": "Axes arc high and crash down through the crowd.",
		"damage": 26.0, "cooldown": 1.5, "count": 2, "pierce": 6, "knock": 8.0,
		"per_level": {"damage": 6.0, "cooldown": -0.07},
		"milestones": {3: {"count": 1}, 6: {"count": 1}},
		"color": Color(0.85, 0.85, 0.9),
	},
}

## Tomes: stat upgrades offered on level-up. `add` is per level.
const TOMES := {
	"might": {"name": "Tome of Might", "desc": "+12% damage.", "max": 8, "stat": "damage", "add": 0.12},
	"haste": {"name": "Tome of Haste", "desc": "+10% attack speed.", "max": 8, "stat": "attack_speed", "add": 0.10},
	"reach": {"name": "Tome of Reach", "desc": "+12% area.", "max": 8, "stat": "area", "add": 0.12},
	"swiftness": {"name": "Tome of Swiftness", "desc": "+8% run speed.", "max": 6, "stat": "move_speed", "add": 0.08},
	"leaping": {"name": "Tome of Leaping", "desc": "+8% jump height.", "max": 5, "stat": "jump", "add": 0.04},
	"iron": {"name": "Tome of Iron", "desc": "Take 6% less damage.", "max": 5, "stat": "armor", "add": 0.06},
	"vitality": {"name": "Tome of Vitality", "desc": "+25 max health.", "max": 8, "stat": "max_hp", "add": 25.0},
	"renewal": {"name": "Tome of Renewal", "desc": "+0.6 health per second.", "max": 6, "stat": "regen", "add": 0.6},
	"attraction": {"name": "Tome of Attraction", "desc": "+30% pickup range.", "max": 5, "stat": "pickup", "add": 0.3},
	"wisdom": {"name": "Tome of Wisdom", "desc": "+10% XP.", "max": 6, "stat": "xp", "add": 0.10},
	"precision": {"name": "Tome of Precision", "desc": "+6% critical hit chance.", "max": 6, "stat": "crit", "add": 0.06},
	"multitude": {"name": "Tome of Multitude", "desc": "+1 projectile for every weapon.", "max": 2, "stat": "count", "add": 1.0},
	"bhop": {"name": "Tome of Agility", "desc": "Well-timed hops carry more speed.", "max": 4, "stat": "hop", "add": 1.0},
}

## Items come from chests and stack without limit; each stack adds `stats`.
## rarity: 0 common, 1 uncommon, 2 rare, 3 legendary.
const ITEMS := {
	# Common
	"iron_ration": {"name": "Iron Ration", "rarity": 0, "desc": "+15 max health.", "stats": {"max_hp": 15.0}},
	"whetstone": {"name": "Whetstone", "rarity": 0, "desc": "+8% damage.", "stats": {"damage": 0.08}},
	"pilgrim_boots": {"name": "Pilgrim's Boots", "rarity": 0, "desc": "+6% run speed.", "stats": {"move_speed": 0.06}},
	"sand_glass": {"name": "Sand Glass", "rarity": 0, "desc": "+7% attack speed.", "stats": {"attack_speed": 0.07}},
	"lodestone": {"name": "Lodestone", "rarity": 0, "desc": "+25% pickup range.", "stats": {"pickup": 0.25}},
	"horseshoe": {"name": "Rusty Horseshoe", "rarity": 0, "desc": "+4% crit chance and better chests.", "stats": {"crit": 0.04, "luck": 0.1}},
	"bone_charm": {"name": "Bone Charm", "rarity": 0, "desc": "+7% XP.", "stats": {"xp": 0.07}},
	"tithe_purse": {"name": "Tithe Purse", "rarity": 0, "desc": "+15% gold.", "stats": {"gold": 0.15}},
	# Uncommon
	"tabard": {"name": "Blessed Tabard", "rarity": 1, "desc": "Take 7% less damage.", "stats": {"armor": 0.07}},
	"war_horn": {"name": "War Horn", "rarity": 1, "desc": "+12% area.", "stats": {"area": 0.12}},
	"holy_water": {"name": "Holy Water", "rarity": 1, "desc": "+0.8 health per second.", "stats": {"regen": 0.8}},
	"spiked_pauldron": {"name": "Spiked Pauldron", "rarity": 1, "desc": "Enemies that hit you take 40 damage.", "stats": {"thorns": 40.0}},
	"angel_feather": {"name": "Angel Feather", "rarity": 1, "desc": "One more jump in mid-air.", "stats": {"air_jump": 1.0}},
	"heart_jar": {"name": "Heart in a Jar", "rarity": 1, "desc": "Kills have a 2% chance to drop a heart.", "stats": {"heart_drop": 0.02}},
	"cleric_beads": {"name": "Cleric's Beads", "rarity": 1, "desc": "+3% crit chance and +15% crit damage.", "stats": {"crit": 0.03, "crit_mult": 0.15}},
	# Rare
	"vampire_fang": {"name": "Vampire Fang", "rarity": 2, "desc": "Heal 2% of the damage you deal.", "stats": {"lifesteal": 0.02}},
	"crown_thorns": {"name": "Crown of Thorns", "rarity": 2, "desc": "+35% crit damage.", "stats": {"crit_mult": 0.35}},
	"saints_finger": {"name": "Saint's Finger", "rarity": 2, "desc": "+12% damage and +10% attack speed.", "stats": {"damage": 0.12, "attack_speed": 0.10}},
	"reaper_sigil": {"name": "Reaper's Sigil", "rarity": 2, "desc": "Hits have a 2% chance to slay outright (not elites or bosses).", "stats": {"execute": 0.02}},
	"endless_quiver": {"name": "Endless Quiver", "rarity": 2, "desc": "+1 projectile for every weapon.", "stats": {"count": 1.0}},
	# Legendary
	"phoenix_ash": {"name": "Phoenix Ash", "rarity": 3, "desc": "When you fall, rise again with half your health (once per ash).", "stats": {"revive": 1.0}},
	"holy_grail": {"name": "Holy Grail", "rarity": 3, "desc": "+50 max health and +2 health per second.", "stats": {"max_hp": 50.0, "regen": 2.0}},
	"dawn_blade": {"name": "Blade of Dawn", "rarity": 3, "desc": "+30% damage and +20% area.", "stats": {"damage": 0.30, "area": 0.20}},
}

const RARITIES := [
	{"name": "Common", "color": Color(0.8, 0.78, 0.74), "weight": 62.0},
	{"name": "Uncommon", "color": Color(0.45, 0.85, 0.45), "weight": 27.0},
	{"name": "Rare", "color": Color(0.45, 0.65, 1.0), "weight": 9.0},
	{"name": "Legendary", "color": Color(1.0, 0.62, 0.2), "weight": 2.0},
]

## Prayer shrine blessings: pick one of three. Each rolls a rarity that
## multiplies `add` (see BLESSING_MULT). fmt shows the value on the card.
const BLESSINGS := [
	{"stat": "damage", "add": 0.06, "name": "Wrath", "fmt": "+%d%% damage", "pct": true, "icon": "might"},
	{"stat": "attack_speed", "add": 0.05, "name": "Zeal", "fmt": "+%d%% attack speed", "pct": true, "icon": "haste"},
	{"stat": "max_hp", "add": 12.0, "name": "Fortitude", "fmt": "+%d max health", "pct": false, "icon": "vitality"},
	{"stat": "area", "add": 0.06, "name": "Radiance", "fmt": "+%d%% area", "pct": true, "icon": "reach"},
	{"stat": "move_speed", "add": 0.04, "name": "Haste", "fmt": "+%d%% run speed", "pct": true, "icon": "swiftness"},
	{"stat": "crit", "add": 0.03, "name": "Precision", "fmt": "+%d%% crit chance", "pct": true, "icon": "precision"},
	{"stat": "regen", "add": 0.4, "name": "Renewal", "fmt": "+%.1f health per second", "pct": false, "icon": "renewal"},
	{"stat": "pickup", "add": 0.15, "name": "Attraction", "fmt": "+%d%% pickup range", "pct": true, "icon": "attraction"},
	{"stat": "xp", "add": 0.05, "name": "Wisdom", "fmt": "+%d%% XP", "pct": true, "icon": "wisdom"},
	{"stat": "armor", "add": 0.03, "name": "Resolve", "fmt": "Take %d%% less damage", "pct": true, "icon": "iron"},
	{"stat": "luck", "add": 0.08, "name": "Fortune", "fmt": "+%d%% luck (better chests)", "pct": true, "icon": "horseshoe"},
]
const BLESSING_MULT := [1.0, 1.6, 2.4, 4.0]


## Three different blessings with rolled rarities.
static func roll_blessings(luck: float) -> Array[Dictionary]:
	var pool := range(BLESSINGS.size())
	pool.shuffle()
	var out: Array[Dictionary] = []
	for k in 3:
		var b: Dictionary = BLESSINGS[pool[k]]
		var rarity := roll_rarity(luck)
		var v: float = b.add * BLESSING_MULT[rarity]
		out.append({"kind": "blessing", "id": b.icon, "stat": b.stat, "add": v, "name": b.name, "rarity": rarity,
				"desc": b.fmt % (v * 100.0 if b.pct else v)})
	return out


static func roll_rarity(luck: float, min_rarity := 0) -> int:
	var weights := []
	var total := 0.0
	for r in RARITIES.size():
		var w: float = RARITIES[r].weight * (1.0 + luck * r) if r >= min_rarity else 0.0
		weights.append(w)
		total += w
	var x := randf() * total
	for r in weights.size():
		x -= weights[r]
		if x <= 0.0:
			return r
	return min_rarity


## Base values for every stat; tomes and items add to these.
const BASE_STATS := {
	"damage": 1.0, "attack_speed": 1.0, "area": 1.0, "move_speed": 1.0, "jump": 1.0,
	"max_hp": 0.0, "regen": 0.0, "pickup": 1.0, "xp": 1.0,
	"crit": 0.05, "crit_mult": 1.8, "count": 0.0, "hop": 0.0, "armor": 0.0, "luck": 0.0,
	"gold": 1.0, "thorns": 0.0, "lifesteal": 0.0, "heart_drop": 0.0, "execute": 0.0,
	"revive": 0.0, "air_jump": 0.0,
}


## Picks an item id. luck shifts weight toward rarer items; min_rarity
## (golden chests) skips the lower tiers.
static func roll_item(luck: float, min_rarity := 0) -> String:
	var rarity := roll_rarity(luck, min_rarity)
	var pool := []
	for id in ITEMS:
		if ITEMS[id].rarity == rarity:
			pool.append(id)
	return pool[randi() % pool.size()]


## XP needed to go from `level` to the next.
static func xp_needed(level: int) -> int:
	return int(round(5.0 + level * 4.0 + pow(level, 1.55) * 1.2))
