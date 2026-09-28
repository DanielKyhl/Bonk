class_name Hud
extends CanvasLayer
## In-run HUD: health, XP, stage clock, gold and kills, the Holy Aegis
## indicator, weapon/tome slots, banners and the hurt flash.

var run: RunState
var player: Player
var director: Director
var enemies: EnemyManager
var chests: Chests
var shrines: Shrines
var boss: Boss
var camera: FollowCamera
var terrain: Terrain
var map: MapDef
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
var _items_row: HBoxContainer
var _prompt: Label
var _item_card: PanelContainer
var _item_icon: TextureRect
var _item_name: Label
var _item_rarity: Label
var _item_desc: Label
var _item_t := 0.0
var _boss_box: VBoxContainer
var _boss_fill: Panel


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
	run.item_added.connect(show_item)
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
	_stage = UIStyle.label(stage_name.to_upper() + ("   STAGE %d" % Game.stage if Game.stage > 1 else ""), UIStyle.ui_font("Bold"), 30, UIStyle.MUTED)
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
	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 4)
	bl.add_child(_items_row)

	# Boss health, under the clock.
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-320, 150)
	_boss_box.custom_minimum_size = Vector2(640, 0)
	_boss_box.visible = false
	root.add_child(_boss_box)
	var bn := UIStyle.label(map.boss.name if map else "", UIStyle.title_font(), 48, UIStyle.PARCH, 8)
	bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bn)
	var bb := UIStyle.bar(640, 22, Color(0.6, 0.15, 0.7))
	_boss_fill = bb[1]
	_boss_box.add_child(bb[0])

	# Interact prompt (chests, shrines) above the bottom edge.
	_prompt = UIStyle.label("", UIStyle.ui_font("Bold"), 30, UIStyle.GOLD, 8)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-400, -150)
	_prompt.custom_minimum_size = Vector2(800, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)

	# Item card: shows what a chest gave you.
	_item_card = PanelContainer.new()
	_item_card.add_theme_stylebox_override("panel", UIStyle.frame("card_hot", Vector4(16, 12, 16, 12)))
	_item_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_item_card.position = Vector2(-440, -90)
	_item_card.custom_minimum_size = Vector2(420, 0)
	_item_card.modulate.a = 0.0
	root.add_child(_item_card)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 14)
	_item_card.add_child(ih)
	_item_icon = UIStyle.icon_rect("whetstone", 3)
	ih.add_child(_item_icon)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(iv)
	_item_rarity = UIStyle.label("", UIStyle.ui_font("Bold"), 20, UIStyle.MUTED, 0)
	iv.add_child(_item_rarity)
	_item_name = UIStyle.label("", UIStyle.title_font(), 48, UIStyle.PARCH, 8)
	iv.add_child(_item_name)
	_item_desc = UIStyle.label("", UIStyle.ui_font("Regular"), 16, Color(0.8, 0.77, 0.72), 0)
	_item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_item_desc.custom_minimum_size = Vector2(290, 0)
	iv.add_child(_item_desc)

	if terrain and map and camera and chests:
		var mm := Minimap.new()
		mm.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mm.position = Vector2(-Minimap.SIZE - 20, 20)
		root.add_child(mm)
		mm.setup(terrain, map, player, camera, chests, shrines, boss)

	_fps = UIStyle.label("", UIStyle.ui_font("SemiBold"), 20, UIStyle.MUTED, 4)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.custom_minimum_size = Vector2(440, 0)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.position = Vector2(-460, -34)
	root.add_child(_fps)


## Pops up the card for an item you just got.
func show_item(id: String) -> void:
	var it: Dictionary = Defs.ITEMS[id]
	var rar: Dictionary = Defs.RARITIES[it.rarity]
	_item_icon.texture = UIStyle.icon(id)
	_item_name.text = it.name
	_item_rarity.text = rar.name.to_upper() + ("   x%d" % run.items[id] if run.items[id] > 1 else "")
	_item_rarity.label_settings.font_color = rar.color
	_item_desc.text = it.desc
	_item_t = 4.0
	_refresh_slots()


func banner(text: String, sub := "") -> void:
	_banner.text = text
	_banner_sub.text = sub
	_banner_t = 3.0


func clear_banner() -> void:
	_prompt.text = ""
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
	if _item_t > 0.0:
		_item_t -= delta
		_item_card.modulate.a = clampf(_item_t * 2.0, 0.0, 1.0)
	_update_prompt()
	_update_boss()
	_hurt_t = maxf(0.0, _hurt_t - delta)
	var low := 0.18 + 0.08 * sin(run.time * 6.0) if run.hp < run.max_hp * 0.3 else 0.0
	_hurt.color.a = maxf(_hurt_t * 1.1, low * 0.6)
	_fps.text = ("%d FPS  ·  %d enemies  ·  %d km/h" % [Engine.get_frames_per_second(), enemies.count, int(round(player.speed() * Player.KMH))]) if _show_fps else ""


func _update_boss() -> void:
	var i := boss.boss_index() if boss else -1
	_boss_box.visible = i >= 0
	if i >= 0:
		_boss_fill.size.x = 636.0 * clampf(enemies.hp[i] / enemies.max_hp[i], 0.0, 1.0)


func _update_prompt() -> void:
	if boss and boss.in_reach():
		var summon := boss.state == Boss.WAITING
		_prompt.text = ("E   SUMMON " + map.boss.name.get_slice(",", 0).to_upper()) if summon else "E   ENTER THE PORTAL"
		_prompt.label_settings.font_color = UIStyle.HP if summon else UIStyle.XP
		return
	if shrines and shrines.praying() >= 0:
		var k := shrines.praying()
		_prompt.text = "PRAYING   %d%%" % int(shrines.charge[k] / Shrines.CHARGE_TIME * 100.0)
		_prompt.label_settings.font_color = Shrines.COLORS[Shrines.PRAYER]
		return
	if shrines and shrines.nearest() >= 0:
		var k := shrines.nearest()
		var cursed := shrines.kind[k] == Shrines.CURSED
		_prompt.text = "E   WAKE THE CURSED ALTAR" if cursed else "E   MAKE AN OFFERING TO GREED"
		_prompt.label_settings.font_color = Shrines.COLORS[shrines.kind[k]]
		return
	var i := chests.nearest() if chests else -1
	if i < 0:
		_prompt.text = ""
		return
	if chests.golden[i]:
		_prompt.text = "E   OPEN GOLDEN CHEST"
		_prompt.label_settings.font_color = UIStyle.GOLD
	else:
		var c := chests.cost()
		_prompt.text = "E   OPEN CHEST   %d GOLD" % c
		_prompt.label_settings.font_color = UIStyle.GOLD if run.gold >= c else UIStyle.HP


func _refresh_hp() -> void:
	_hp_fill.size.x = 326.0 * clampf(run.hp / run.max_hp, 0.0, 1.0)
	_hp_text.text = "%d / %d" % [ceili(run.hp), int(run.max_hp)]


func _refresh_xp() -> void:
	_xp_fill.size.x = maxf(0.0, _xp_root.size.x - 4.0) * clampf(run.xp / run.xp_next, 0.0, 1.0)
	_lvl.text = "LV %d" % run.level


func _refresh_slots() -> void:
	var sig := str(run.weapons) + str(run.tomes) + str(run.items)
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
	for c in _items_row.get_children():
		c.queue_free()
	for id: String in run.items:
		var box := Control.new()
		box.custom_minimum_size = Vector2(34, 34)
		var ic := UIStyle.icon_rect(id, 1)
		ic.position = Vector2(4, 0)
		box.add_child(ic)
		if run.items[id] > 1:
			var n := UIStyle.label(str(run.items[id]), UIStyle.ui_font("Bold"), 20, UIStyle.PARCH, 4)
			n.position = Vector2(20, 12)
			box.add_child(n)
		_items_row.add_child(box)


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
