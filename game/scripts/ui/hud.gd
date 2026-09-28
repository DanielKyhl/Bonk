class_name Hud
extends CanvasLayer
## In-run HUD: health, XP, stage clock, gold and kills, the Holy Aegis
## indicator, weapon/tome slots, banners and the hurt flash.

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
var _aegis: Label
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
	_lvl = UIStyle.label("LV 1", UIStyle.ui_font("ExtraBold"), 30, UIStyle.XP)
	name_row.add_child(_lvl)
	name_row.add_child(UIStyle.label(run.hero.title.to_upper(), UIStyle.ui_font("Bold"), 30, UIStyle.GOLD))
	var hb := UIStyle.bar(330, 26, UIStyle.HP)
	_hp_root = hb[0]
	_hp_fill = hb[1]
	tl.add_child(_hp_root)
	_hp_text = UIStyle.label("", UIStyle.ui_font("Bold"), 20)
	_hp_text.position = Vector2(8, 1)
	_hp_root.add_child(_hp_text)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 18)
	tl.add_child(stats_row)
	_gold = UIStyle.label("GOLD  0", UIStyle.ui_font("Bold"), 30, UIStyle.GOLD)
	stats_row.add_child(_gold)
	_kills = UIStyle.label("KILLS  0", UIStyle.ui_font("Bold"), 30, UIStyle.PARCH)
	stats_row.add_child(_kills)
	_aegis = UIStyle.label("", UIStyle.ui_font("Bold"), 30, UIStyle.GOLD)
	_aegis.visible = run.hero_id == "crusader"
	tl.add_child(_aegis)

	# Top-center: stage clock.
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(-120, 18)
	tc.custom_minimum_size = Vector2(240, 0)
	tc.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(tc)
	_timer = UIStyle.label("10:00", UIStyle.ui_font("Bold"), 60, UIStyle.PARCH, 8)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(_timer)
	_stage = UIStyle.label(stage_name.to_upper(), UIStyle.ui_font("Bold"), 30, UIStyle.MUTED)
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(_stage)

	# Banner.
	_banner = UIStyle.label("", UIStyle.title_font(), 72, UIStyle.GOLD, 10)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-500, 150)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_banner)
	_banner_sub = UIStyle.label("", UIStyle.ui_font("SemiBold"), 30, UIStyle.PARCH)
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_sub.position = Vector2(-500, 236)
	_banner_sub.custom_minimum_size = Vector2(1000, 0)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_banner_sub)

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

	_fps = UIStyle.label("", UIStyle.ui_font("SemiBold"), 20, UIStyle.MUTED, 4)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.custom_minimum_size = Vector2(440, 0)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.position = Vector2(-460, -34)
	root.add_child(_fps)


func banner(text: String, sub := "") -> void:
	_banner.text = text
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
	if _aegis.visible:
		var ready := run.aegis_cd <= 0.0
		_aegis.text = "AEGIS READY" if ready else "AEGIS  %ds" % ceili(run.aegis_cd)
		_aegis.label_settings.font_color = UIStyle.GOLD if ready else UIStyle.MUTED

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
	_fps.text = ("%d FPS  ·  %d enemies  ·  %d km/h" % [Engine.get_frames_per_second(), enemies.count, int(round(player.speed() * Player.KMH))]) if _show_fps else ""


func _refresh_hp() -> void:
	_hp_fill.size.x = 326.0 * clampf(run.hp / run.max_hp, 0.0, 1.0)
	_hp_text.text = "%d / %d" % [ceili(run.hp), int(run.max_hp)]


func _refresh_xp() -> void:
	_xp_fill.size.x = maxf(0.0, _xp_root.size.x - 4.0) * clampf(run.xp / run.xp_next, 0.0, 1.0)
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
		_slots.add_child(_slot_box(id, run.weapons[id], w.max, w.color))
	for id: String in run.tomes:
		var t: Dictionary = Defs.TOMES[id]
		_tome_slots.add_child(_slot_box(id, run.tomes[id], t.max, UIStyle.XP))


## An icon in a pixel frame with level pips under it.
func _slot_box(id: String, lvl: int, max_lvl: int, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.frame("slot", Vector4(6, 6, 6, 6)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UIStyle.icon_rect(id, 2))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(pips)
	for k in max_lvl:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(4, 4)
		pip.color = color if k < lvl else Color(1, 1, 1, 0.15)
		pips.add_child(pip)
	return p
