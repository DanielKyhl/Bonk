class_name Defs
extends RefCounted
## Game data: heroes, weapons and tomes. Balance numbers live here.

## Heroes. Only the Crusader is unlocked at the start.
const HEROES := {
	"crusader": {
		"name": "Aurelia, the Crusader",
		"title": "Crusader",
		"blurb": "A holy knight in steel and gold, sworn to burn the undead from the vale.",
		"model": "res://assets/kaykit/heroes/Knight.glb",
		"weapon": "radiant_flail",
		"hp": 120.0,
		"run_speed": 9.5,
		"passive": "Holy Aegis: a holy shield blocks one hit, then recharges for 12 seconds.",
		"unlock": "",
	},
}

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

## Base values for every stat; tomes and items add to these.
const BASE_STATS := {
	"damage": 1.0, "attack_speed": 1.0, "area": 1.0, "move_speed": 1.0, "jump": 1.0,
	"max_hp": 0.0, "regen": 0.0, "pickup": 1.0, "xp": 1.0,
	"crit": 0.05, "crit_mult": 1.8, "count": 0.0, "hop": 0.0, "armor": 0.0, "luck": 0.0,
	"gold": 1.0,
}


## XP needed to go from `level` to the next.
static func xp_needed(level: int) -> int:
	return int(round(5.0 + level * 4.0 + pow(level, 1.55) * 1.2))
