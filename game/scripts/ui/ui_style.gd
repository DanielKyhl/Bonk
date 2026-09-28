class_name UIStyle
extends RefCounted
## Shared fonts, colors and widget helpers for the UI.

const INK := Color(0.055, 0.075, 0.085)
const PANEL := Color(0.06, 0.085, 0.095, 0.82)
const PANEL_LIGHT := Color(0.12, 0.15, 0.16, 0.92)
const GOLD := Color(0.93, 0.77, 0.36)
const PARCH := Color(0.95, 0.92, 0.84)
const MUTED := Color(0.66, 0.69, 0.64)
const HP := Color(0.86, 0.27, 0.31)
const XP := Color(0.37, 0.83, 0.95)
const ACCENT := Color(1.0, 0.56, 0.24)

static var _title: Font
static var _ui := {}


static func title_font() -> Font:
	if _title == null:
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Cinzel.ttf")
		fv.variation_opentype = {"wght": 700}
		_title = fv
	return _title


static func ui_font(weight := "Bold") -> Font:
	if not _ui.has(weight):
		_ui[weight] = load("res://assets/fonts/BarlowCondensed-%s.ttf" % weight)
	return _ui[weight]


static func label(text: String, font: Font, size: int, color := PARCH, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0.03, 0.04, 0.05, 0.85)
	ls.shadow_size = 0
	l.label_settings = ls
	return l


static func panel_style(color := PANEL, radius := 6, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## A horizontal bar: returns [root, fill] so callers can set the fill width.
static func bar(width: float, height: float, fill_color: Color, bg := Color(0.03, 0.04, 0.05, 0.75)) -> Array:
	var root := Panel.new()
	root.custom_minimum_size = Vector2(width, height)
	root.add_theme_stylebox_override("panel", panel_style(bg, 3))
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", panel_style(fill_color, 3))
	fill.position = Vector2.ZERO
	fill.size = Vector2(width, height)
	root.add_child(fill)
	return [root, fill]
