class_name Hud
extends CanvasLayer
## In-run HUD: health, XP, stage clock, gold and kills, the speedometer with
## trick chips, weapon/tome slots, banners and the hurt flash.

var run: RunState
var player: Player
var director: Director
var enemies: EnemyManager
var stage_name := ""

var _xp_fill: Panel
var _xp_root: Panel
var _lvl: Label
var _hp_fill: Panel
var _hp_root: Panel
var _hp_text: Label
var _gold: Label
var _kills: Label
var _timer: Label
var _stage: Label
var _speed: Label
var _speed_fill: Panel
var _speed_root: Panel
var _tick_run: ColorRect
var _tick_cap: ColorRect
var _chip_dmg: Label
var _chip_hop: Label
var _chip_air: Label
var _slots: HBoxContainer
var _tome_slots: HBoxContainer
var _banner: Label
var _banner_sub: Label
var _banner_t := 0.0
var _hurt: ColorRect
var _hurt_t := 0.0
var _fps: Label
var _show_fps := true
var _slot_sig := ""

const SPEED_BAR := 380.0
const SPEED_MAX := 60.0


func setup(r: RunState, p: Player, d: Director, e: EnemyManager, stage: String) -> void:
	run = r
	player = p
	director = d
	enemies = e
	stage_name = stage
	layer = 5
	_build()
	run.hp_changed.connect(func(_h, _m): _refresh_hp())
	run.xp_changed.connect(func(_x, _n, _l): _refresh_xp())
	run.gold_changed.connect(func(_g): _gold.text = "GOLD  %d" % run.gold)
	run.stats_changed.connect(_refresh_slots)
	_refresh_hp()
	_refresh_xp()
	_refresh_slots()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hurt = ColorRect.new()
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.color = Color(0.8, 0.1, 0.12, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hurt)

	# XP bar across the top.
	var xb := UIStyle.bar(100, 10, UIStyle.XP)
	_xp_root = xb[0]
	_xp_fill = xb[1]
	_xp_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_root.offset_bottom = 10
	root.add_child(_xp_root)

	# Top-left: hero, health, gold, kills.
	var tl := VBoxContainer.new()
	tl.position = Vector2(20, 22)
	tl.add_theme_constant_override("separation", 4)
	root.add_child(tl)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	tl.add_child(name_row)
	_lvl = UIStyle.label("LV 1", UIStyle.ui_font("ExtraBold"), 26, UIStyle.XP)
	name_row.add_child(_lvl)
	name_row.add_child(UIStyle.label(run.hero.title.to_upper(), UIStyle.title_font(), 22, UIStyle.GOLD))
	var hb := UIStyle.bar(330, 22, UIStyle.HP)
	_hp_root = hb[0]
	_hp_fill = hb[1]
	tl.add_child(_hp_root)
	_hp_text = UIStyle.label("", UIStyle.ui_font("Bold"), 18)
	_hp_text.position = Vector2(8, -2)
	_hp_root.add_child(_hp_text)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 18)
	tl.add_child(stats_row)
	_gold = UIStyle.label("GOLD  0", UIStyle.ui_font("Bold"), 22, UIStyle.GOLD)
	stats_row.add_child(_gold)
	_kills = UIStyle.label("KILLS  0", UIStyle.ui_font("Bold"), 22, UIStyle.PARCH)
	stats_row.add_child(_kills)

	# Top-center: stage clock.
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(-120, 18)
	tc.custom_minimum_size = Vector2(240, 0)
	tc.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(tc)
	_timer = UIStyle.label("10:00", UIStyle.title_font(), 46, UIStyle.PARCH, 8)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(_timer)
	_stage = UIStyle.label(stage_name.to_upper(), UIStyle.ui_font("SemiBold"), 18, UIStyle.MUTED)
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(_stage)

	# Banner.
	_banner = UIStyle.label("", UIStyle.title_font(), 40, UIStyle.GOLD, 10)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-500, 150)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_banner)
	_banner_sub = UIStyle.label("", UIStyle.ui_font("SemiBold"), 22, UIStyle.PARCH)
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_sub.position = Vector2(-500, 204)
	_banner_sub.custom_minimum_size = Vector2(1000, 0)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_banner_sub)

	# Bottom-center: speedometer.
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.position = Vector2(-SPEED_BAR * 0.5, -150)
	bc.custom_minimum_size = Vector2(SPEED_BAR, 0)
	bc.add_theme_constant_override("separation", 6)
	root.add_child(bc)
	var sp_row := HBoxContainer.new()
	sp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sp_row.add_theme_constant_override("separation", 8)
	bc.add_child(sp_row)
	_speed = UIStyle.label("0", UIStyle.ui_font("ExtraBold"), 64, UIStyle.PARCH, 8)
	_speed.custom_minimum_size = Vector2(110, 0)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sp_row.add_child(_speed)
	var unit := UIStyle.label("KM/H", UIStyle.ui_font("SemiBold"), 20, UIStyle.MUTED)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	sp_row.add_child(unit)
	var sb := UIStyle.bar(SPEED_BAR, 10, UIStyle.PARCH)
	_speed_root = sb[0]
	_speed_fill = sb[1]
	bc.add_child(_speed_root)
	_tick_run = ColorRect.new()
	_tick_run.color = UIStyle.MUTED
	_tick_run.size = Vector2(3, 18)
	_speed_root.add_child(_tick_run)
	_tick_cap = ColorRect.new()
	_tick_cap.color = UIStyle.ACCENT
	_tick_cap.size = Vector2(3, 18)
	_speed_root.add_child(_tick_cap)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	bc.add_child(chips)
	_chip_dmg = _chip(chips)
	_chip_hop = _chip(chips)
	_chip_air = _chip(chips)

	# Bottom-left: weapon and tome slots.
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(20, -170)
	bl.add_theme_constant_override("separation", 8)
	root.add_child(bl)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	bl.add_child(_slots)
	_tome_slots = HBoxContainer.new()
	_tome_slots.add_theme_constant_override("separation", 8)
	bl.add_child(_tome_slots)

	_fps = UIStyle.label("", UIStyle.ui_font("SemiBold"), 16, UIStyle.MUTED, 4)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.position = Vector2(-300, -34)
	root.add_child(_fps)


func _chip(parent: Control) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL, 4))
	parent.add_child(p)
	var l := UIStyle.label("", UIStyle.ui_font("Bold"), 18, UIStyle.MUTED, 0)
	p.add_child(l)
	return l


func banner(text: String, sub := "") -> void:
	_banner.text = text.to_upper()
	_banner_sub.text = sub
	_banner_t = 3.0


func clear_banner() -> void:
	_banner_t = 0.0
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0


func hurt() -> void:
	_hurt_t = 0.35


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fps"):
		_show_fps = not _show_fps
	var sp := player.speed()
	_speed.text = str(int(round(sp * Player.KMH)))
	var hot := sp >= player.hop_cap * 0.97
	_speed.label_settings.font_color = UIStyle.ACCENT if hot else UIStyle.PARCH
	_speed_fill.size.x = SPEED_BAR * clampf(sp / SPEED_MAX, 0.0, 1.0)
	(_speed_fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = UIStyle.ACCENT if hot else UIStyle.PARCH
	_tick_run.position = Vector2(SPEED_BAR * player.run_speed / SPEED_MAX - 1, -4)
	_tick_cap.position = Vector2(SPEED_BAR * minf(player.hop_cap, SPEED_MAX) / SPEED_MAX - 1, -4)
	var m := run.momentum_mult(sp)
	_set_chip(_chip_dmg, "DMG ×%.1f" % m, m >= 1.25)
	_set_chip(_chip_hop, "HOP ×%d" % player.chain, player.chain > 0)
	var airborne := not player.grounded and player.air_time > 0.25
	_set_chip(_chip_air, "AIR %.1fs" % (player.air_time if airborne else player.last_air), airborne)

	var tl := maxf(director.time_left, 0.0)
	if director.final_swarm:
		var over := run.time - Director.STAGE_TIME
		_timer.text = "+%d:%02d" % [int(over) / 60, int(over) % 60]
		_timer.label_settings.font_color = UIStyle.HP
	else:
		_timer.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60]
	_kills.text = "KILLS  %d" % run.kills

	if _banner_t > 0.0:
		_banner_t -= delta
		var a := clampf(_banner_t * 1.5, 0.0, 1.0)
		_banner.modulate.a = a
		_banner_sub.modulate.a = a
	_hurt_t = maxf(0.0, _hurt_t - delta)
	var low := 0.18 + 0.08 * sin(run.time * 6.0) if run.hp < run.max_hp * 0.3 else 0.0
	_hurt.color.a = maxf(_hurt_t * 1.1, low * 0.6)
	_fps.text = ("%d FPS  ·  %d enemies  ·  render %d%%" % [Engine.get_frames_per_second(), enemies.count, int(Game.render_scale * 100)]) if _show_fps else ""


func _set_chip(l: Label, text: String, on: bool) -> void:
	l.text = text
	l.label_settings.font_color = UIStyle.INK if on else UIStyle.MUTED
	var sb := (l.get_parent() as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color = UIStyle.ACCENT if on else UIStyle.PANEL


func _refresh_hp() -> void:
	_hp_fill.size.x = 330.0 * clampf(run.hp / run.max_hp, 0.0, 1.0)
	_hp_text.text = "%d / %d" % [ceili(run.hp), int(run.max_hp)]


func _refresh_xp() -> void:
	_xp_fill.size.x = _xp_root.size.x * clampf(run.xp / run.xp_next, 0.0, 1.0)
	_lvl.text = "LV %d" % run.level


func _refresh_slots() -> void:
	var sig := str(run.weapons) + str(run.tomes)
	if sig == _slot_sig:
		return
	_slot_sig = sig
	for c in _slots.get_children():
		c.queue_free()
	for c in _tome_slots.get_children():
		c.queue_free()
	for id: String in run.weapons:
		var w: Dictionary = Defs.WEAPONS[id]
		_slots.add_child(_slot_box(w.name, run.weapons[id], w.max, w.color, 92))
	for id: String in run.tomes:
		var t: Dictionary = Defs.TOMES[id]
		_tome_slots.add_child(_slot_box(t.name.replace("Tome of ", ""), run.tomes[id], t.max, UIStyle.XP, 92))


func _slot_box(title: String, lvl: int, max_lvl: int, color: Color, w: float) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 0)
	p.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL, 5, Color(color, 0.7)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var n := UIStyle.label(title, UIStyle.ui_font("Bold"), 15, UIStyle.PARCH, 0)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	n.custom_minimum_size = Vector2(w - 20, 0)
	v.add_child(n)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	v.add_child(pips)
	for k in max_lvl:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(8, 5)
		pip.color = color if k < lvl else Color(1, 1, 1, 0.15)
		pips.add_child(pip)
	return p
