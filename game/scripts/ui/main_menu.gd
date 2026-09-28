extends Control
## Title screen, hero and map select, settings and the loading screen.
## The chosen map's terrain starts building in the background as soon as the
## menu opens, so starting a run is quick.
##
## Launched with run arguments (tests, screenshots) it goes straight into a
## run; pass --menu to stay on the menu.

const RUN_SCENE := "res://scenes/main.tscn"

var _screen: Control
var _hero_detail: VBoxContainer
var _thread: Thread
var _prebuilt_map := ""
var _embers: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and not "--menu" in args:
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sound.listener = null
	Sound.music("menu")
	for k in 70:
		_embers.append({"p": Vector2(randf() * 1600.0, randf() * 900.0), "v": randf_range(12.0, 40.0), "s": randi_range(1, 3) * 2.0})
	_prebuild(Game.map_id)
	_title()
	if "--menu" in args:
		var cap := DebugCapture.new()
		add_child(cap)
		for a in args:
			if a == "--heroes":
				_heroes()
			elif a == "--maps":
				_maps()
			elif a == "--settings":
				_settings()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _process(delta: float) -> void:
	_t += delta
	for e in _embers:
		e.p.y -= e.v * delta
		e.p.x += sin(_t * 0.7 + e.v) * 8.0 * delta
		if e.p.y < -10.0:
			e.p = Vector2(randf() * 1600.0, 910.0)
	queue_redraw()


func _draw() -> void:
	var sz := get_viewport_rect().size
	# Blood-dark sky fading to black, with a pale moon and rising embers.
	var bands := 18
	for k in bands:
		var t := float(k) / bands
		draw_rect(Rect2(0, sz.y * t, sz.x, sz.y / bands + 1.0), Color(0.16, 0.04, 0.05).lerp(Color(0.02, 0.015, 0.03), t))
	draw_circle(Vector2(sz.x * 0.78, sz.y * 0.22), 64.0, Color(0.78, 0.72, 0.62))
	draw_circle(Vector2(sz.x * 0.78 + 14, sz.y * 0.22 - 8), 58.0, Color(0.16, 0.05, 0.06))
	for e in _embers:
		var a := clampf(e.p.y / sz.y, 0.2, 1.0)
		draw_rect(Rect2(e.p, Vector2(e.s, e.s)), Color(1.0, 0.45, 0.15, a))
	# A jagged black horizon.
	var pts := PackedVector2Array([Vector2(0, sz.y)])
	for k in 33:
		var x := sz.x * k / 32.0
		pts.append(Vector2(x, sz.y * 0.8 - absf(sin(k * 1.7) * 60.0) - absf(sin(k * 0.5) * 40.0)))
	pts.append(Vector2(sz.x, sz.y))
	draw_colored_polygon(pts, Color(0.02, 0.012, 0.02))


# -----------------------------------------------------------------------------
# Screens
# -----------------------------------------------------------------------------
func _show(c: Control) -> void:
	if _screen:
		_screen.queue_free()
	_screen = c
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)


func _column(width := 520.0) -> VBoxContainer:
	var root := CenterContainer.new()
	_show(root)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	root.add_child(v)
	return v


func _heading(v: Container, text: String, size := 72) -> void:
	var l := UIStyle.label(text, UIStyle.title_font(), size, UIStyle.GOLD, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)


func _title() -> void:
	var v := _column()
	_heading(v, "Momentum", 144)
	var sub := UIStyle.label("The dead are rising. Keep moving.", UIStyle.ui_font("Bold"), 30, UIStyle.PARCH, 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	var play := UIStyle.button("Play", _heroes, 320)
	for b in [play, UIStyle.button("Settings", _settings, 320), UIStyle.button("Quit", func(): get_tree().quit(), 320)]:
		var c := CenterContainer.new()
		c.add_child(b)
		v.add_child(c)
	var best: float = Game.progress("best_score")
	if best > 0.0:
		var bl := UIStyle.label("Best score  %d" % int(best), UIStyle.ui_font("Bold"), 20, UIStyle.MUTED, 4)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bl)
	play.call_deferred("grab_focus")


func _heroes() -> void:
	var v := _column(1300)
	_heading(v, "Choose your hero")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	row.add_child(grid)
	_hero_detail = VBoxContainer.new()
	_hero_detail.custom_minimum_size = Vector2(420, 0)
	_hero_detail.add_theme_constant_override("separation", 8)
	row.add_child(_hero_detail)
	var first: Button = null
	for h in Defs.ROSTER:
		var b := _hero_card(h)
		grid.add_child(b)
		if h.id == Game.hero_id:
			first = b
	_hero_info(Game.hero_id)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 20)
	nav.add_child(UIStyle.button("Back", _title, 240))
	nav.add_child(UIStyle.button("Next", _maps, 240))
	v.add_child(nav)
	if first:
		first.call_deferred("grab_focus")


func _hero_card(h: Dictionary) -> Button:
	var playable := Defs.HEROES.has(h.id) and Game.is_hero_unlocked(h.id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(160, 200)
	b.add_theme_stylebox_override("normal", UIStyle.frame("card_hot" if h.id == Game.hero_id else "card"))
	b.add_theme_stylebox_override("hover", UIStyle.frame("card_hot"))
	b.add_theme_stylebox_override("focus", UIStyle.frame("card_hot"))
	b.add_theme_stylebox_override("pressed", UIStyle.frame("card_hot"))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(128, 128)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = _portrait(h.id if SpriteMeta.ATLASES.has(h.id) else "crusader")
	if not playable:
		pic.modulate = Color(0, 0, 0, 0.85)
	v.add_child(pic)
	var n := UIStyle.label(h.name if playable else "???", UIStyle.ui_font("Bold"), 20, UIStyle.PARCH if playable else UIStyle.MUTED, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	b.focus_entered.connect(_hero_info.bind(h.id))
	b.mouse_entered.connect(_hero_info.bind(h.id))
	b.pressed.connect(func():
		if playable:
			Game.hero_id = h.id
			Game.set_saved("settings", "hero", h.id)
			_maps())
	return b


## The hero's front-facing standing frame, cut from its atlas.
func _portrait(id: String) -> Texture2D:
	var img: Image = (load("res://assets/sprites/%s.png" % id) as Texture2D).get_image()
	var walk: Array = SpriteMeta.ATLASES[id].anims.walk
	var frame := img.get_region(Rect2i(0, (int(walk[0]) + 2) * 64, 64, 64))
	return ImageTexture.create_from_image(frame)


func _hero_info(id: String) -> void:
	if _hero_detail == null:
		return
	for c in _hero_detail.get_children():
		c.queue_free()
	var entry: Dictionary = {}
	for h in Defs.ROSTER:
		if h.id == id:
			entry = h
	var unlocked := Game.is_hero_unlocked(id)
	if Defs.HEROES.has(id) and unlocked:
		var hd: Dictionary = Defs.HEROES[id]
		_hero_detail.add_child(UIStyle.label(hd.name, UIStyle.title_font(), 48, UIStyle.GOLD, 8))
		var blurb := UIStyle.label(hd.blurb, UIStyle.ui_font("Regular"), 16, UIStyle.PARCH, 0)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
		_hero_detail.add_child(blurb)
		var wrow := HBoxContainer.new()
		wrow.add_theme_constant_override("separation", 10)
		wrow.add_child(UIStyle.icon_rect(hd.weapon, 2))
		var w: Dictionary = Defs.WEAPONS[hd.weapon]
		var wl := UIStyle.label("Starts with  " + w.name, UIStyle.ui_font("Bold"), 20, UIStyle.PARCH, 0)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wrow.add_child(wl)
		_hero_detail.add_child(wrow)
		var pas := UIStyle.label(hd.passive, UIStyle.ui_font("Regular"), 16, UIStyle.XP, 0)
		pas.autowrap_mode = TextServer.AUTOWRAP_WORD
		_hero_detail.add_child(pas)
		_hero_detail.add_child(UIStyle.label("Health %d    Speed %.1f" % [hd.hp, hd.run_speed], UIStyle.ui_font("Bold"), 20, UIStyle.MUTED, 0))
	else:
		_hero_detail.add_child(UIStyle.label(entry.get("name", "???") if unlocked else "Locked", UIStyle.title_font(), 48, UIStyle.MUTED, 8))
		var how := "Coming soon." if unlocked else "Unlock: %s." % entry.get("unlock", "")
		if not unlocked and entry.has("stat"):
			how += "\nBest so far: %s / %s" % [_num(Game.progress(entry.stat)), _num(entry.need)]
		var l := UIStyle.label(how, UIStyle.ui_font("Regular"), 16, UIStyle.PARCH, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_hero_detail.add_child(l)


func _num(v: float) -> String:
	return str(int(v))


func _maps() -> void:
	var v := _column(1300)
	_heading(v, "Choose where to descend")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var focus: Button = null
	for k in Game.MAPS.size():
		var m: Dictionary = Game.MAPS[k]
		var open := Game.is_map_unlocked(m.id)
		var built: bool = m.script != ""
		var b := Button.new()
		b.custom_minimum_size = Vector2(236, 240)
		b.add_theme_stylebox_override("normal", UIStyle.frame("card_hot" if m.id == Game.map_id else "card"))
		for st in ["hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(st, UIStyle.frame("card_hot"))
		var c := VBoxContainer.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 14
		c.offset_right = -14
		c.offset_top = 16
		c.alignment = BoxContainer.ALIGNMENT_BEGIN
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
		c.add_child(UIStyle.label("%d" % (k + 1), UIStyle.ui_font("Bold"), 30, UIStyle.MUTED, 0))
		var n := UIStyle.label(m.name if open else "???", UIStyle.title_font(), 48, UIStyle.PARCH if open else UIStyle.MUTED, 8)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD
		c.add_child(n)
		var status := "Unlocked" if open and built else ("Coming soon" if open else "Beat the boss of %s" % Game.MAPS[k - 1].name)
		var sl := UIStyle.label(status, UIStyle.ui_font("Regular"), 16, UIStyle.XP if open and built else UIStyle.MUTED, 0)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD
		c.add_child(sl)
		b.disabled = not (open and built)
		b.pressed.connect(func():
			Game.map_id = m.id
			Game.set_saved("settings", "map", m.id)
			_start())
		row.add_child(b)
		if m.id == Game.map_id or focus == null and not b.disabled:
			focus = b
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 20)
	nav.add_child(UIStyle.button("Back", _heroes, 240))
	v.add_child(nav)
	if focus:
		focus.call_deferred("grab_focus")


func _settings() -> void:
	var v := _column(640)
	_heading(v, "Settings")
	_slider(v, "Mouse sensitivity", 0.05, 1.0, Game.mouse_sensitivity, func(x: float):
		Game.mouse_sensitivity = x
		Game.set_saved("settings", "mouse_sensitivity", x))
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
	var fs := CheckButton.new()
	fs.text = "Fullscreen (F11)"
	fs.add_theme_font_override("font", UIStyle.ui_font("Bold"))
	fs.add_theme_font_size_override("font_size", 30)
	fs.button_pressed = get_window().mode == Window.MODE_FULLSCREEN
	fs.toggled.connect(func(on: bool):
		get_window().mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
		Game.set_saved("settings", "fullscreen", on))
	v.add_child(fs)
	var c := CenterContainer.new()
	var back := UIStyle.button("Back", _title, 240)
	c.add_child(back)
	v.add_child(c)
	back.call_deferred("grab_focus")


func _slider(v: Container, text: String, lo: float, hi: float, value: float, cb: Callable) -> void:
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


# -----------------------------------------------------------------------------
# Starting a run
# -----------------------------------------------------------------------------
func _prebuild(map_id: String) -> void:
	var info := Game.map_info(map_id)
	if info.script == "" or _prebuilt_map == map_id:
		return
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_prebuilt_map = map_id
	var map: MapDef = load(info.script).new()
	_thread = Thread.new()
	_thread.start(Terrain.prebuild.bind(map))


func _start() -> void:
	var v := _column()
	_heading(v, "Descending into", 48)
	_heading(v, Game.map_info(Game.map_id).name, 96)
	_prebuild(Game.map_id)
	# Let the loading screen draw, then wait for the terrain and switch.
	await get_tree().process_frame
	await get_tree().process_frame
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	Game.run_seed = randi()
	Game.stage = 1
	Game.carry = {}
	get_tree().change_scene_to_file(RUN_SCENE)
