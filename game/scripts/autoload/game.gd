extends Node
## Global state: input bindings, run settings and saved progress.

const SAVE_PATH := "user://save.cfg"

## Selected hero id for the next run.
var hero_id := "crusader"
## Seed for the random parts of a run (chest, shrine and boss placement).
var run_seed := 0

var _save := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_save.load(SAVE_PATH)
	run_seed = randi()
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
func get_saved(section: String, key: String, default: Variant = null) -> Variant:
	return _save.get_value(section, key, default)


func set_saved(section: String, key: String, value: Variant) -> void:
	_save.set_value(section, key, value)
	_save.save(SAVE_PATH)
