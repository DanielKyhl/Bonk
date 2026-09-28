class_name SettingsPanel
extends RefCounted
## The settings controls, shared by the main menu and the pause menu:
## mouse sensitivity, volumes and fullscreen. Changes apply and save at once.


## Adds the settings rows to v.
static func build(v: Container) -> void:
	_slider(v, "Mouse sensitivity", 0.05, 1.0, Game.mouse_sensitivity, func(x: float):
		Game.mouse_sensitivity = x
		Game.set_saved("settings", "mouse_sensitivity", x)
		Game.settings_changed.emit())
	_slider(v, "Master volume", 0.0, 1.0, Game.master_volume, func(x: float):
		Game.master_volume = x
		Game.set_saved("settings", "master_volume", x)
		Game.apply_volumes())
	_slider(v, "Music", 0.0, 1.0, Game.music_volume, func(x: float):
		Game.music_volume = x
		Game.set_saved("settings", "music_volume", x)
		Game.apply_volumes())
	_slider(v, "Effects", 0.0, 1.0, Game.sfx_volume, func(x: float):
		Game.sfx_volume = x
		Game.set_saved("settings", "sfx_volume", x)
		Game.apply_volumes()
		Sound.play("gem"))
	var win := (Engine.get_main_loop() as SceneTree).root
	# Lambdas capture locals by value, so the button reaches its own label
	# through an array.
	var box: Array[Button] = [null]
	var fs := UIStyle.button(_fs_text(win), func():
		var on := win.mode != Window.MODE_FULLSCREEN
		win.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
		Game.set_saved("settings", "fullscreen", on)
		box[0].text = _fs_text(win), 320)
	box[0] = fs
	var c := CenterContainer.new()
	c.add_child(fs)
	v.add_child(c)


static func _fs_text(win: Window) -> String:
	return "Fullscreen: " + ("On" if win.mode == Window.MODE_FULLSCREEN else "Off")


static func _slider(v: Container, text: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UIStyle.label(text, UIStyle.ui_font("Bold"), 30, UIStyle.PARCH, 0)
	l.custom_minimum_size = Vector2(280, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(320, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(cb)
	row.add_child(s)
	v.add_child(row)
