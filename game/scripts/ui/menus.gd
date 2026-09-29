class_name RunMenus
extends CanvasLayer
## Overlays that pause the run: level-up cards, the pause menu (with settings)
## and the death screen.
## Keys 1-3 pick a card; mouse and gamepad work through normal button focus.

signal picked(choice: Dictionary)
signal resume_requested
signal restart_requested
signal quit_requested
signal menu_requested
signal onward_requested
signal save_requested

var run: RunState
var _root: Control
var _choices: Array[Dictionary] = []
var _open_at := 0.0
var _mode := ""
## Level-up extras (not on shrine blessings): reroll, skip, banish.
var _extras := false
var _banishing := false
var _hint: Label
var _banish_btn: Button
var _cards: Array[Button] = []


func setup(r: RunState) -> void:
	run = r
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()


func _backdrop(alpha := 0.62) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.035, alpha)
	_root.add_child(dim)


func _center_box(width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	return v


# -----------------------------------------------------------------------------
# Level up
# -----------------------------------------------------------------------------
func show_levelup(choices: Array[Dictionary], heading := "") -> void:
	_clear()
	_mode = "levelup"
	_choices = choices
	_root.visible = true
	_open_at = Time.get_ticks_msec() / 1000.0
	_backdrop(0.55)
	var v := _center_box(1100)
	var title := UIStyle.label(heading if heading != "" else "Level %d" % run.level, UIStyle.title_font(), 72, UIStyle.GOLD, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_extras = heading == ""
	_banishing = false
	_hint = UIStyle.label("", UIStyle.ui_font("SemiBold"), 20, UIStyle.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	_cards.clear()
	for i in choices.size():
		var card := _card(i, choices[i])
		_cards.append(card)
		row.add_child(card)
	if _extras:
		var bar := HBoxContainer.new()
		bar.alignment = BoxContainer.ALIGNMENT_CENTER
		bar.add_theme_constant_override("separation", 22)
		v.add_child(bar)
		bar.add_child(_extra_button("Reroll (R)", run.rerolls, _reroll))
		bar.add_child(_extra_button("Skip (Q)", run.skips, _skip))
		_banish_btn = _extra_button("Banish (B)", run.banishes, _toggle_banish)
		bar.add_child(_banish_btn)
	_show_mode()


func _extra_button(text: String, left: int, cb: Callable) -> Button:
	var b := UIStyle.button("%s   %d left" % [text, left], cb, 330)
	b.disabled = left <= 0
	return b


## Hint line and card tint for picking vs. banishing.
func _show_mode() -> void:
	if _banishing:
		_hint.text = "Banish which?  1, 2, 3 or click.  It won't be offered again this run.  (B to cancel)"
		_hint.label_settings.font_color = UIStyle.HP
	else:
		_hint.text = "Choose one:  1, 2, 3 or click"
		_hint.label_settings.font_color = UIStyle.MUTED
	for c in _cards:
		c.modulate = Color(1.0, 0.55, 0.5) if _banishing else Color.WHITE


func _ready_for_input() -> bool:
	# Ignore input in the first moments so a mashed key doesn't choose for you.
	return Time.get_ticks_msec() / 1000.0 - _open_at >= 0.35


func _reroll() -> void:
	if not _extras or run.rerolls <= 0 or not _ready_for_input():
		return
	run.rerolls -= 1
	show_levelup(run.roll_choices())


func _skip() -> void:
	if not _extras or run.skips <= 0 or not _ready_for_input():
		return
	run.skips -= 1
	_close()
	picked.emit({"kind": "skip", "id": "skip"})


func _toggle_banish() -> void:
	if not _extras or run.banishes <= 0:
		return
	_banishing = not _banishing
	_show_mode()


## Banishes card i and deals a new card in its place.
func _banish(i: int) -> void:
	var c := _choices[i]
	if c.kind != "weapon" and c.kind != "tome":
		return
	run.banish(c)
	var kept: Array[Dictionary] = []
	for k in _choices.size():
		if k != i:
			kept.append(_choices[k])
	var fresh: Dictionary = {}
	for f in run.roll_choices():
		var dup := false
		for o in kept:
			if o.kind == f.kind and o.id == f.id:
				dup = true
		if not dup and f.kind != "heal":
			fresh = f
			break
	var next: Array[Dictionary] = []
	for k in _choices.size():
		if k != i:
			next.append(_choices[k])
		elif not fresh.is_empty():
			next.append(fresh)
	if next.is_empty():
		next.append({"kind": "heal", "id": "heal"})
	Sound.play("curse", null, 1.6, -8.0)
	show_levelup(next)


func _card(i: int, c: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(330, 400)
	b.focus_mode = Control.FOCUS_ALL
	var normal := UIStyle.frame("card")
	var hover := UIStyle.frame("card_hot")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func(): _pick(i))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var tag := ""
	var name := ""
	var desc := ""
	var lvl := 0
	var max_lvl := 0
	var color := UIStyle.GOLD
	var detail := ""
	match c.kind:
		"weapon":
			var w: Dictionary = Defs.WEAPONS[c.id]
			lvl = run.weapons.get(c.id, 0)
			max_lvl = w.max
			name = w.name
			desc = w.desc
			color = w.color
			tag = "NEW WEAPON" if lvl == 0 else "WEAPON  ·  LV %d → %d" % [lvl, lvl + 1]
			if lvl > 0:
				detail = _weapon_delta(w, lvl + 1)
		"tome":
			var t: Dictionary = Defs.TOMES[c.id]
			lvl = run.tomes.get(c.id, 0)
			max_lvl = t.max
			name = t.name
			desc = t.desc
			color = UIStyle.XP
			tag = "NEW TOME" if lvl == 0 else "TOME  ·  LV %d → %d" % [lvl, lvl + 1]
		"blessing":
			var rar: Dictionary = Defs.RARITIES[c.rarity]
			name = c.name
			desc = c.desc
			color = rar.color
			tag = "BLESSING  ·  " + rar.name.to_upper()
		_:
			name = "Second Wind"
			desc = "Heal 40% of your health."
			tag = "BLESSING"
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var ic := UIStyle.icon_rect(c.id if c.kind != "heal" else "vitality", 3)
	top.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	tv.add_child(UIStyle.label("%d" % (i + 1), UIStyle.ui_font("ExtraBold"), 20, UIStyle.MUTED, 0))
	tv.add_child(UIStyle.label(tag, UIStyle.ui_font("Bold"), 20, color, 0))
	var n := UIStyle.label(name, UIStyle.title_font(), 48, UIStyle.PARCH, 8)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(n)
	var d := UIStyle.label(desc, UIStyle.ui_font("Regular"), 16, Color(0.8, 0.77, 0.72), 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(d)
	if detail != "":
		var dl := UIStyle.label(detail, UIStyle.ui_font("SemiBold"), 20, UIStyle.GOLD, 0)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(dl)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 5)
	v.add_child(pips)
	for k in max_lvl:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(20, 6)
		pip.color = color if k < lvl else (Color(color, 0.55) if k == lvl else Color(1, 1, 1, 0.14))
		pips.add_child(pip)
	return b


## What "+1 count" means for each weapon kind.
const COUNT_NAMES := {
	"javelin": "projectile", "axes": "projectile", "smite": "strike", "orbit": "orb",
	"cone": "breath", "chain": "bolt", "claw": "slash", "whip": "lash", "shards": "shard",
	"slam": "aftershock", "boomerang": "blade", "homing": "skull", "rift": "rift",
}


func _weapon_delta(w: Dictionary, new_lvl: int) -> String:
	var parts := []
	for key: String in w.per_level:
		var v: float = w.per_level[key]
		match key:
			"damage": parts.append("+%d damage" % int(v))
			"area": parts.append("+%d%% area" % int(round(v / float(w.get("area", 1.0)) * 100.0)))
			"cooldown": parts.append("%d%% faster" % int(round(-v / float(w.cooldown) * 100.0)))
			"range": parts.append("+%d%% range" % int(round(v / float(w.range) * 100.0)))
	if w.milestones.has(new_lvl):
		for key: String in w.milestones[new_lvl]:
			var m: float = w.milestones[new_lvl][key]
			match key:
				"count": parts.append("+%d %s" % [int(m), COUNT_NAMES.get(w.kind, "swing")])
				"pierce": parts.append("+%d pierce" % int(m))
				"area", "width": parts.append("bigger area")
				"jumps": parts.append("+%d jumps" % int(m))
				"angle": parts.append("wider cone")
				"duration": parts.append("lasts longer")
	return ", ".join(parts)


func _pick(i: int) -> void:
	if _mode != "levelup" or i >= _choices.size() or not _ready_for_input():
		return
	if _banishing:
		_banish(i)
		return
	var c := _choices[i]
	_close()
	picked.emit(c)


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if _mode == "levelup":
		for k in 3:
			if event.is_action_pressed("pick_%d" % (k + 1)):
				_pick(k)
				get_viewport().set_input_as_handled()
				return
		for a in [["reroll", _reroll], ["skip", _skip], ["banish", _toggle_banish]]:
			if _extras and event.is_action_pressed(a[0]):
				(a[1] as Callable).call()
				get_viewport().set_input_as_handled()
				return
	if _mode == "pause" and event.is_action_pressed("pause"):
		_close()
		resume_requested.emit()
		get_viewport().set_input_as_handled()
	elif _mode == "settings" and event.is_action_pressed("pause"):
		show_pause()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Hand gamepad focus to the first card once the pick delay has passed.
	if _mode == "levelup" and _root.visible and get_viewport().gui_get_focus_owner() == null:
		if Time.get_ticks_msec() / 1000.0 - _open_at > 0.4:
			var b := _root.find_children("*", "Button", true, false)
			if b.size() > 0:
				(b[0] as Button).grab_focus()


func _close() -> void:
	_root.visible = false
	_mode = ""
	_clear()


# -----------------------------------------------------------------------------
# Pause and death
# -----------------------------------------------------------------------------
func show_pause() -> void:
	_clear()
	_mode = "pause"
	_root.visible = true
	_backdrop(0.6)
	var v := _center_box(420)
	var t := UIStyle.label("Paused", UIStyle.title_font(), 72, UIStyle.GOLD, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := _button("Resume", func(): _close(); resume_requested.emit())
	v.add_child(resume)
	v.add_child(_button("Settings", show_settings))
	v.add_child(_button("Save & quit", func(): save_requested.emit()))
	v.add_child(_button("Restart run", func(): _close(); restart_requested.emit()))
	v.add_child(_button("Main menu", func(): menu_requested.emit()))
	v.add_child(_button("Quit game", func(): quit_requested.emit()))
	resume.call_deferred("grab_focus")


func show_settings() -> void:
	_clear()
	_mode = "settings"
	_root.visible = true
	_backdrop(0.6)
	var v := _center_box(640)
	var t := UIStyle.label("Settings", UIStyle.title_font(), 72, UIStyle.GOLD, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	SettingsPanel.build(v)
	var c := CenterContainer.new()
	var back := _button("Back", show_pause)
	c.add_child(back)
	v.add_child(c)
	back.call_deferred("grab_focus")


func show_death(title: String, rows: Array, sub := "", onward := "") -> void:
	_clear()
	_mode = "death"
	_root.visible = true
	_backdrop(0.7)
	var v := _center_box(760)
	var t := UIStyle.label(title, UIStyle.title_font(), 72, UIStyle.GOLD if title == "Victory" else UIStyle.HP, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var st := UIStyle.label(sub, UIStyle.ui_font("Bold"), 30, UIStyle.PARCH, 6)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(st)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 14)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	for r in rows:
		var cell := VBoxContainer.new()
		cell.add_child(UIStyle.label(str(r[0]).to_upper(), UIStyle.ui_font("SemiBold"), 20, UIStyle.MUTED, 0))
		cell.add_child(UIStyle.label(str(r[1]), UIStyle.ui_font("ExtraBold"), 40, UIStyle.PARCH, 0))
		grid.add_child(cell)
	var bc := HBoxContainer.new()
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	bc.add_theme_constant_override("separation", 20)
	v.add_child(bc)
	var b: Button
	if onward != "":
		b = UIStyle.button("Onward to " + onward, func(): _close(); onward_requested.emit(), 420)
	else:
		b = _button("Run again", func(): _close(); restart_requested.emit())
	bc.add_child(b)
	bc.add_child(_button("Main menu", func(): menu_requested.emit()))
	b.call_deferred("grab_focus")


func _button(text: String, cb: Callable) -> Button:
	return UIStyle.button(text, cb)
