class_name UIStyle
extends RefCounted
## Shared fonts, colors and widget helpers for the pixel-art UI. Fonts are
## pixel fonts drawn without antialiasing, at sizes snapped to whole multiples
## of their pixel grid; panels are 9-patch pixel frames.

const INK := Color(0.05, 0.035, 0.06)
const PANEL := Color(0.07, 0.06, 0.085, 0.9)
const PANEL_LIGHT := Color(0.12, 0.1, 0.12, 0.95)
const GOLD := Color(0.96, 0.78, 0.4)
const PARCH := Color(0.93, 0.88, 0.78)
const MUTED := Color(0.62, 0.58, 0.55)
const HP := Color(0.84, 0.2, 0.22)
const XP := Color(0.42, 0.78, 0.93)
const ACCENT := Color(1.0, 0.56, 0.24)

## Pixel grid of each font (font size per art pixel row block).
const TITLE_GRID := 24
const UI_GRID := 10
const BODY_GRID := 8

static var _fonts := {}
static var _frames := {}


static func _pixel_font(path: String) -> FontFile:
	if _fonts.has(path):
		return _fonts[path]
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	_fonts[path] = f
	return f


## Blackletter pixel font for names and headings.
static func title_font() -> Font:
	return _pixel_font("res://assets/fonts/Jacquard24-Regular.ttf")


## Chunky pixel font for numbers and labels. "Regular" gives the body font
## used for longer descriptions.
static func ui_font(weight := "Bold") -> Font:
	if weight == "Regular":
		return _pixel_font("res://assets/fonts/PixelifySans.ttf")
	return _pixel_font("res://assets/fonts/Jersey10-Regular.ttf")


## Snaps a requested size to the nearest whole multiple of the font's grid.
static func snap_size(font: Font, size: int) -> int:
	var grid := UI_GRID
	if font == title_font():
		grid = TITLE_GRID
	elif font == ui_font("Regular"):
		grid = BODY_GRID
	return maxi(grid, int(round(size / float(grid))) * grid)


static func label(text: String, font: Font, size: int, color := PARCH, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = snap_size(font, size)
	ls.font_color = color
	ls.outline_size = 0 if outline <= 0 else 4 if outline <= 6 else 8
	ls.outline_color = Color(0.03, 0.02, 0.04, 1.0)
	ls.shadow_size = 0
	l.label_settings = ls
	return l


## A 9-patch pixel frame: "panel", "card", "card_hot", "button", "button_hot", "slot".
static func frame(name: String, pad := Vector4(12, 8, 12, 8)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	if not _frames.has(name):
		_frames[name] = load("res://assets/ui/%s.png" % name)
	sb.texture = _frames[name]
	sb.set_texture_margin_all(6)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## Flat pixel box (no rounding), for bars and small chips.
static func panel_style(color := PANEL, _radius := 0, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = false
	return sb


## A horizontal pixel bar with a dark frame and a lit top row on the fill.
## Returns [root, fill] so callers can set the fill width.
static func bar(width: float, height: float, fill_color: Color, bg := Color(0.04, 0.03, 0.05, 0.9)) -> Array:
	var root := Panel.new()
	root.custom_minimum_size = Vector2(width, height)
	var rs := panel_style(bg, 0, Color(0.02, 0.015, 0.03, 1.0))
	root.add_theme_stylebox_override("panel", rs)
	var fill := Panel.new()
	var fs := panel_style(fill_color)
	fs.border_width_top = 2
	fs.border_color = fill_color.lightened(0.35)
	fill.add_theme_stylebox_override("panel", fs)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(width - 4, height - 4)
	root.add_child(fill)
	return [root, fill]


static func icon(id: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## An icon drawn at a whole-number scale (icons are 26px incl. outline).
static func icon_rect(id: String, scale := 2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(26, 26) * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
