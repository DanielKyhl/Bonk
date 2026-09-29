class_name Defs
extends RefCounted
## Game data: heroes, weapons and tomes. Balance numbers live here.

## Heroes. Only the Crusader is unlocked at the start; see ROSTER for the
## rest. `stats` adds to the base stats for the whole run (the passive).
const HEROES := {
	"crusader": {
		"name": "Aurelia, the Crusader",
		"title": "Crusader",
		"blurb": "A holy knight in steel and gold, sworn to burn the undead from the vale.",
		"weapon": "radiant_flail",
		"hp": 120.0,
		"run_speed": 7.6,
		"passive": "Holy Aegis: a holy shield blocks one hit, then recharges for 12 seconds.",
		"stats": {},
	},
	"dragonborn": {
		"name": "Kaerr, the Dragonborn",
		"title": "Dragonborn",
		"blurb": "Last of a line of dragon-blooded kings. Scaled, horned and full of fire.",
		"weapon": "dragon_breath",
		"hp": 150.0,
		"run_speed": 7.4,
		"passive": "Dragon Scales: take 15% less damage.",
		"stats": {"armor": 0.15},
	},
	"stormcaller": {
		"name": "Ysolde, the Stormcaller",
		"title": "Stormcaller",
		"blurb": "A sky-witch of the northern cliffs who speaks to the thunder.",
		"weapon": "chain_lightning",
		"hp": 95.0,
		"run_speed": 7.8,
		"passive": "Tempest: +15% attack speed.",
		"stats": {"attack_speed": 0.15},
	},
	"werewolf": {
		"name": "Vargr, the Werewolf",
		"title": "Werewolf",
		"blurb": "Cursed under a red moon. What is left of the man only wants to hunt.",
		"weapon": "rending_claws",
		"hp": 130.0,
		"run_speed": 8.2,
		"passive": "Bloodlust: heal 3% of the damage you deal (at most 3% of max health a second).",
		"stats": {"lifesteal": 0.03},
	},
	"chainwarden": {
		"name": "Harrow, the Chainwarden",
		"title": "Chainwarden",
		"blurb": "Jailer of the deep oubliettes, still wearing the chains of the damned.",
		"weapon": "warden_chains",
		"hp": 160.0,
		"run_speed": 7.2,
		"passive": "Iron Hide: enemies that hit you take 25 damage.",
		"stats": {"thorns": 25.0},
	},
	"frost_witch": {
		"name": "Elsin, the Frost Witch",
		"title": "Frost Witch",
		"blurb": "She froze her own heart to outlive the plague. It worked.",
		"weapon": "frost_shards",
		"hp": 90.0,
		"run_speed": 7.7,
		"passive": "Rime: every hit has a 30% chance to chill, slowing the foe for 2 seconds.",
		"stats": {"chill": 0.3},
	},
	"rune_golem": {
		"name": "Oszric, the Rune Golem",
		"title": "Rune Golem",
		"blurb": "A war-engine of carved stone, woken by runes older than the church.",
		"weapon": "rune_slam",
		"hp": 200.0,
		"run_speed": 6.7,
		"passive": "Stoneborn: take 10% less damage and +20% area.",
		"stats": {"armor": 0.1, "area": 0.2},
	},
	"wraith_knight": {
		"name": "Morvane, the Wraith Knight",
		"title": "Wraith Knight",
		"blurb": "A fallen paladin who refused to stay dead. His blade is his soul.",
		"weapon": "soul_blade",
		"hp": 120.0,
		"run_speed": 7.7,
		"passive": "Undying: rise once from death with half your health.",
		"stats": {"revive": 1.0},
	},
	"necromancer": {
		"name": "Othric, the Necromancer",
		"title": "Necromancer",
		"blurb": "He robs the graves the others guard, and the dead obey him.",
		"weapon": "soul_skulls",
		"hp": 100.0,
		"run_speed": 7.5,
		"passive": "Grave Harvest: +15% XP and +20% pickup range.",
		"stats": {"xp": 0.15, "pickup": 0.2},
	},
	"chronomancer": {
		"name": "Tessaly, the Chronomancer",
		"title": "Chronomancer",
		"blurb": "A heretic scholar who stole a minute from God and keeps spending it.",
		"weapon": "time_rift",
		"hp": 100.0,
		"run_speed": 7.7,
		"passive": "Borrowed Time: +10% attack speed; hits have a 15% chance to slow.",
		"stats": {"attack_speed": 0.1, "chill": 0.15},
	},
}

## Every hero in menu order, with what unlocks them. `stat` is a saved
## progress value (see Game.record_run) that must reach `need`. A hero's signature
## weapon joins everyone's level-up pool once that hero is unlocked.
const ROSTER := [
	{"id": "crusader", "name": "Crusader", "unlock": ""},
	{"id": "dragonborn", "name": "Dragonborn", "unlock": "Slay a map's boss", "stat": "boss_kills", "need": 1},
	{"id": "stormcaller", "name": "Stormcaller", "unlock": "Reach level 30 in one run", "stat": "best_level", "need": 30},
	{"id": "werewolf", "name": "Werewolf", "unlock": "Slay 1,500 foes in one run", "stat": "best_kills", "need": 1500},
	{"id": "chainwarden", "name": "Chainwarden", "unlock": "Open 12 chests in one run", "stat": "best_chests", "need": 12},
	{"id": "frost_witch", "name": "Frost Witch", "unlock": "Survive 3 minutes of the Final Swarm", "stat": "best_swarm", "need": 180},
	{"id": "rune_golem", "name": "Rune Golem", "unlock": "Pray at 6 shrines in one run", "stat": "best_prayers", "need": 6},
	{"id": "wraith_knight", "name": "Wraith Knight", "unlock": "Slay 100 elites in all", "stat": "total_elites", "need": 100},
	{"id": "necromancer", "name": "Necromancer", "unlock": "Slay 25,000 foes in all", "stat": "total_kills", "need": 25000},
	{"id": "chronomancer", "name": "Chronomancer", "unlock": "Slay a boss before 8:00", "stat": "fast_boss", "need": 1},
]

## Weapons. Values are for level 1; `per_level` adds per level after 1.
## kind picks the behavior in WeaponSystem. `hero` marks a signature weapon:
## it is only offered once that hero is unlocked.
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
	# Hero signature weapons.
	"dragon_breath": {
		"name": "Dragon Breath", "kind": "cone", "max": 7, "hero": "dragonborn",
		"desc": "Breathes a cone of fire at the nearest foe.",
		"damage": 15.0, "cooldown": 1.3, "range": 7.0, "angle": 70.0, "count": 1, "knock": 7.0,
		"per_level": {"damage": 5.0, "range": 0.4, "cooldown": -0.05},
		"milestones": {4: {"count": 1}, 7: {"angle": 40.0}},
		"color": Color(1.0, 0.55, 0.2),
	},
	"chain_lightning": {
		"name": "Chain Lightning", "kind": "chain", "max": 7, "hero": "stormcaller",
		"desc": "Lightning strikes a foe and leaps to the ones near it.",
		"damage": 20.0, "cooldown": 1.2, "range": 16.0, "jumps": 4, "jump_range": 7.0, "count": 1, "knock": 3.0,
		"per_level": {"damage": 5.0, "cooldown": -0.05},
		"milestones": {3: {"jumps": 2}, 5: {"count": 1}, 7: {"jumps": 3}},
		"color": Color(0.42, 0.62, 1.0),
	},
	"rending_claws": {
		"name": "Rending Claws", "kind": "claw", "max": 7, "hero": "werewolf",
		"desc": "Rakes everything in front of you, left and right.",
		"damage": 12.0, "cooldown": 0.5, "area": 3.2, "angle": 130.0, "count": 1, "knock": 5.0,
		"per_level": {"damage": 3.5, "area": 0.15, "cooldown": -0.02},
		"milestones": {3: {"count": 1}, 6: {"count": 1}},
		"color": Color(0.9, 0.3, 0.3),
	},
	"warden_chains": {
		"name": "Warden's Chains", "kind": "whip", "max": 7, "hero": "chainwarden",
		"desc": "Lashes a long chain through the crowd, one side then the other.",
		"damage": 18.0, "cooldown": 1.0, "area": 7.0, "width": 1.5, "count": 1, "knock": 10.0,
		"per_level": {"damage": 5.0, "area": 0.4, "cooldown": -0.04},
		"milestones": {2: {"count": 1}, 5: {"count": 1}, 7: {"width": 0.6}},
		"color": Color(0.75, 0.75, 0.8),
	},
	"frost_shards": {
		"name": "Frost Shards", "kind": "shards", "max": 7, "hero": "frost_witch",
		"desc": "A fan of ice shards that pierce and slow what they hit.",
		"damage": 14.0, "cooldown": 1.1, "speed": 30.0, "pierce": 1, "count": 3, "knock": 3.0, "slow": 1.5,
		"per_level": {"damage": 4.0, "cooldown": -0.04},
		"milestones": {3: {"count": 1}, 5: {"pierce": 1}, 7: {"count": 2}},
		"color": Color(0.6, 0.85, 1.0),
	},
	"rune_slam": {
		"name": "Rune Slam", "kind": "slam", "max": 7, "hero": "rune_golem",
		"desc": "Smashes the ground, crushing and hurling back everything around you.",
		"damage": 40.0, "cooldown": 2.6, "area": 5.0, "count": 1, "knock": 24.0,
		"per_level": {"damage": 10.0, "area": 0.3, "cooldown": -0.1},
		"milestones": {4: {"count": 1}, 7: {"count": 1}},
		"color": Color(1.0, 0.6, 0.3),
	},
	"soul_blade": {
		"name": "Soul Blade", "kind": "boomerang", "max": 7, "hero": "wraith_knight",
		"desc": "A ghostly sword flies out through the crowd and returns to your hand.",
		"damage": 26.0, "cooldown": 1.6, "range": 14.0, "speed": 26.0, "count": 1, "knock": 6.0,
		"per_level": {"damage": 7.0, "cooldown": -0.06},
		"milestones": {3: {"count": 1}, 6: {"count": 1}},
		"color": Color(0.5, 0.95, 0.85),
	},
	"soul_skulls": {
		"name": "Soul Skulls", "kind": "homing", "max": 7, "hero": "necromancer",
		"desc": "Screaming skulls hunt down foes and burst on contact.",
		"damage": 16.0, "cooldown": 1.4, "speed": 14.0, "area": 1.8, "count": 2, "knock": 5.0,
		"per_level": {"damage": 5.0, "cooldown": -0.05},
		"milestones": {3: {"count": 1}, 5: {"area": 0.6}, 7: {"count": 2}},
		"color": Color(0.75, 0.6, 1.0),
	},
	"time_rift": {
		"name": "Time Rift", "kind": "rift", "max": 7, "hero": "chronomancer",
		"desc": "Tears open a rift that slows and grinds down everything inside.",
		"damage": 7.0, "cooldown": 3.0, "area": 4.0, "range": 16.0, "duration": 3.0, "count": 1, "knock": 0.0,
		"per_level": {"damage": 2.5, "area": 0.25, "cooldown": -0.1},
		"milestones": {4: {"count": 1}, 7: {"duration": 1.5}},
		"color": Color(0.75, 0.5, 1.0),
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
	"renewal": {"name": "Tome of Renewal", "desc": "+0.3 health per second.", "max": 6, "stat": "regen", "add": 0.3},
	"attraction": {"name": "Tome of Attraction", "desc": "+30% pickup range.", "max": 5, "stat": "pickup", "add": 0.3},
	"wisdom": {"name": "Tome of Wisdom", "desc": "+10% XP.", "max": 6, "stat": "xp", "add": 0.10},
	"precision": {"name": "Tome of Precision", "desc": "+6% critical hit chance.", "max": 6, "stat": "crit", "add": 0.06},
	"multitude": {"name": "Tome of Multitude", "desc": "+1 projectile for every weapon.", "max": 2, "stat": "count", "add": 1.0},
	"bhop": {"name": "Tome of Agility", "desc": "Well-timed hops gain more speed, and hop faster.", "max": 4, "stat": "hop", "add": 1.0},
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
	"holy_water": {"name": "Holy Water", "rarity": 1, "desc": "+0.4 health per second.", "stats": {"regen": 0.4}},
	"spiked_pauldron": {"name": "Spiked Pauldron", "rarity": 1, "desc": "Enemies that hit you take 40 damage.", "stats": {"thorns": 40.0}},
	"angel_feather": {"name": "Angel Feather", "rarity": 1, "desc": "One more jump in mid-air.", "stats": {"air_jump": 1.0}},
	"heart_jar": {"name": "Heart in a Jar", "rarity": 1, "desc": "Kills have a 2% chance to drop a heart.", "stats": {"heart_drop": 0.02}},
	"cleric_beads": {"name": "Cleric's Beads", "rarity": 1, "desc": "+3% crit chance and +15% crit damage.", "stats": {"crit": 0.03, "crit_mult": 0.15}},
	# Rare
	"vampire_fang": {"name": "Vampire Fang", "rarity": 2, "desc": "Heal 2% of the damage you deal (at most 3% of your max health a second).", "stats": {"lifesteal": 0.02}},
	"crown_thorns": {"name": "Crown of Thorns", "rarity": 2, "desc": "+35% crit damage.", "stats": {"crit_mult": 0.35}},
	"saints_finger": {"name": "Saint's Finger", "rarity": 2, "desc": "+12% damage and +10% attack speed.", "stats": {"damage": 0.12, "attack_speed": 0.10}},
	"reaper_sigil": {"name": "Reaper's Sigil", "rarity": 2, "desc": "Hits have a 2% chance to slay outright (not elites or bosses).", "stats": {"execute": 0.02}},
	"endless_quiver": {"name": "Endless Quiver", "rarity": 2, "desc": "+1 projectile for every weapon.", "stats": {"count": 1.0}},
	# Legendary
	"phoenix_ash": {"name": "Phoenix Ash", "rarity": 3, "desc": "When you fall, rise again with half your health (once per ash).", "stats": {"revive": 1.0}},
	"holy_grail": {"name": "Holy Grail", "rarity": 3, "desc": "+50 max health and +1 health per second.", "stats": {"max_hp": 50.0, "regen": 1.0}},
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
	{"stat": "regen", "add": 0.2, "name": "Renewal", "fmt": "+%.1f health per second", "pct": false, "icon": "renewal"},
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
	"revive": 0.0, "air_jump": 0.0, "chill": 0.0,
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
