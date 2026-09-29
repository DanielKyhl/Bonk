extends Node
## Global state: input bindings, run settings and saved progress.

const SAVE_PATH := "user://save.cfg"

## Emitted when a setting that live objects read changes (mouse sensitivity).
signal settings_changed

## Selected hero and map for the next run.
var hero_id := "crusader"
## Debug (--unlock-all): every hero counts as unlocked.
var unlock_all := false
var map_id := "hallowed_vale"
## Stage of the current run: 1 on a fresh run, +1 for every boss portal
## taken. Later stages are much tougher (see stage_hp_mult) and the
## difficulty clock carries on across them (Director.danger_time).
var stage := 1
## A build carried through a boss portal (RunState.snapshot()), or empty.
var carry := {}
## A run saved with "Save & quit", being continued (run.gd applies it), or {}.
var resume := {}
## Settings (saved).
var mouse_sensitivity := 0.25
var master_volume := 0.8
var music_volume := 0.7
var sfx_volume := 0.8
## Seed for the random parts of a run (chest, shrine and boss placement).
var run_seed := 0

## The maps in order. Beating a map's boss and taking the portal unlocks the
## next one; unlocked maps can be picked from the main menu.
const MAPS := [
	{"id": "hallowed_vale", "name": "Hallowed Vale", "script": "res://scripts/world/maps/hallowed_vale.gd"},
	{"id": "frostfang_peaks", "name": "Frostfang Peaks", "script": "res://scripts/world/maps/frostfang_peaks.gd"},
	{"id": "blightmire", "name": "Blightmire", "script": "res://scripts/world/maps/blightmire.gd"},
	{"id": "ashen_forge", "name": "Ashen Forge", "script": ""},
	{"id": "dragons_spine", "name": "Dragon's Spine", "script": ""},
]

var _save := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_save.load(SAVE_PATH)
	run_seed = randi()
	mouse_sensitivity = get_saved("settings", "mouse_sensitivity", 0.25)
	master_volume = get_saved("settings", "master_volume", 0.8)
	music_volume = get_saved("settings", "music_volume", 0.7)
	sfx_volume = get_saved("settings", "sfx_volume", 0.8)
	unlock_all = "--unlock-all" in OS.get_cmdline_user_args()
	hero_id = get_saved("settings", "hero", "crusader")
	if not Defs.HEROES.has(hero_id) or not is_hero_unlocked(hero_id):
		hero_id = "crusader"
	map_id = get_saved("settings", "map", "hallowed_vale")
	if not is_map_unlocked(map_id):
		map_id = MAPS[0].id
	_setup_audio()
	if get_saved("settings", "fullscreen", false):
		get_window().mode = Window.MODE_FULLSCREEN


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var w := get_window()
		var full := w.mode != Window.MODE_FULLSCREEN
		w.mode = Window.MODE_FULLSCREEN if full else Window.MODE_WINDOWED
		set_saved("settings", "fullscreen", full)


# -----------------------------------------------------------------------------
# Input: keyboard + gamepad, set up in code so every binding lives in one place.
# -----------------------------------------------------------------------------
func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("jump", [KEY_SPACE, KEY_J], [JOY_BUTTON_A], [])
	_bind("slide", [KEY_SHIFT, KEY_C, KEY_K], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("interact", [KEY_E], [JOY_BUTTON_X], [])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_bind("pick_1", [KEY_1], [], [])
	_bind("pick_2", [KEY_2], [], [])
	_bind("pick_3", [KEY_3], [], [])
	_bind("reroll", [KEY_R], [JOY_BUTTON_Y], [])
	_bind("skip", [KEY_Q], [], [])
	_bind("banish", [KEY_B], [], [])
	_bind("toggle_fps", [KEY_F], [], [])
	_bind("fullscreen", [KEY_F11], [], [])
	_bind("turn_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("turn_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])


func _bind(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)


# -----------------------------------------------------------------------------
# Saved progress
# -----------------------------------------------------------------------------
## Extra enemy health, enemy damage and chest prices for the current stage,
## on top of the difficulty clock carrying on from the stages before.
func stage_hp_mult() -> float:
	return pow(1.5, stage - 1)


func stage_dmg_mult() -> float:
	return pow(1.35, stage - 1)


func stage_price_mult() -> float:
	return pow(1.6, stage - 1)


## The map after `id` in unlock order, or {} for the last one.
func next_map(id: String) -> Dictionary:
	for k in MAPS.size() - 1:
		if MAPS[k].id == id:
			return MAPS[k + 1]
	return {}


func map_info(id: String) -> Dictionary:
	for m in MAPS:
		if m.id == id:
			return m
	return MAPS[0]


func progress(stat: String) -> float:
	return get_saved("progress", stat, 0.0)


func is_hero_unlocked(id: String) -> bool:
	if unlock_all:
		return true
	for h in Defs.ROSTER:
		if h.id == id:
			return h.unlock == "" or progress(h.stat) >= h.need
	return false


## Folds a finished run into the saved progress (bests and totals). Returns
## the names of heroes this run unlocked.
func record_run(r: RunState, swarm_time: float, chests_opened: int, prayers: int, boss_time: float) -> Array[String]:
	var before := {}
	for h in Defs.ROSTER:
		before[h.id] = is_hero_unlocked(h.id)
	_best("best_level", r.level)
	_best("best_kills", r.kills)
	_best("best_chests", chests_opened)
	_best("best_swarm", swarm_time)
	_best("best_prayers", prayers)
	set_saved("progress", "total_elites", progress("total_elites") + r.elites)
	set_saved("progress", "total_kills", progress("total_kills") + r.kills)
	if r.boss_killed:
		set_saved("progress", "boss_kills", progress("boss_kills") + 1)
		if boss_time < 480.0:
			set_saved("progress", "fast_boss", 1.0)
	_best("best_score", r.final_score())
	var out: Array[String] = []
	for h in Defs.ROSTER:
		if not before[h.id] and is_hero_unlocked(h.id):
			out.append(h.name)
	return out


func _best(stat: String, v: float) -> void:
	if v > progress(stat):
		set_saved("progress", stat, v)


## Master plus Music and SFX buses; the settings sliders drive their volumes.
func _setup_audio() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	apply_volumes()


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


func is_map_unlocked(id: String) -> bool:
	return id == MAPS[0].id or get_saved("unlocks", id, false)


## Unlocks the map after `id`; returns its name ("" if it was the last one).
func unlock_next_map(id: String) -> String:
	for k in MAPS.size() - 1:
		if MAPS[k].id == id:
			set_saved("unlocks", MAPS[k + 1].id, true)
			return MAPS[k + 1].name
	return ""


## A run saved with "Save & quit" waits in the save file until continued.
func has_saved_run() -> bool:
	return _save.has_section_key("run", "state")


func saved_run() -> Dictionary:
	return get_saved("run", "state", {})


func save_run(state: Dictionary) -> void:
	set_saved("run", "state", state)


func clear_saved_run() -> void:
	if _save.has_section("run"):
		_save.erase_section("run")
		_save.save(SAVE_PATH)


## Sets up the next scene load to continue the saved run.
func continue_run() -> void:
	var s := saved_run()
	hero_id = s.hero
	map_id = s.map
	stage = s.stage
	run_seed = s.seed
	carry = {}
	resume = s


func get_saved(section: String, key: String, default: Variant = null) -> Variant:
	return _save.get_value(section, key, default)


func set_saved(section: String, key: String, value: Variant) -> void:
	_save.set_value(section, key, value)
	_save.save(SAVE_PATH)
