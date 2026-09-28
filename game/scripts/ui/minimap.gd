class_name Minimap
extends Control
## Round minimap in the corner: the terrain around the hero, turned with the
## camera so up is where you're looking, with chests, golden chests and holy
## springs marked. Golden chests beyond the edge stick to the rim.

const SIZE := 240.0
const RADIUS := 120.0          ## Meters from the hero to the rim.
const RES := 2.0               ## Meters per texel of the map picture.

var terrain: Terrain
var map: MapDef
var player: Player
var camera: FollowCamera
var chests: Chests
var _rect: TextureRect
var _mat: ShaderMaterial

static var _tex_cache := {}


func setup(t: Terrain, m: MapDef, p: Player, cam: FollowCamera, c: Chests) -> void:
	terrain = t
	map = m
	player = p
	camera = cam
	chests = c
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = TextureRect.new()
	_rect.texture = _map_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.size = Vector2(SIZE, SIZE)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/minimap.gdshader")
	_mat.set_shader_parameter("radius_uv", RADIUS / (map.half_size * 2.0))
	_rect.material = _mat
	add_child(_rect)
	# Icons draw on a child so they sit above the picture.
	var icons := Control.new()
	icons.size = Vector2(SIZE, SIZE)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.draw.connect(_draw_icons.bind(icons))
	add_child(icons)
	set_process(true)


func _process(_delta: float) -> void:
	var span := map.half_size * 2.0
	_mat.set_shader_parameter("center_uv", Vector2((player.position.x + map.half_size) / span, (player.position.z + map.half_size) / span))
	_mat.set_shader_parameter("yaw", camera.yaw)
	(get_child(1) as Control).queue_redraw()


## Screen offset (-1..1 inside the rim) of a world point relative to the hero.
func _project(q: Vector3) -> Vector2:
	var y := camera.yaw
	var d := Vector2(q.x - player.position.x, q.z - player.position.z)
	var right := Vector2(cos(y), -sin(y))
	var fwd := Vector2(-sin(y), -cos(y))
	return Vector2(d.dot(right), -d.dot(fwd)) / RADIUS


func _draw_icons(c: Control) -> void:
	var mid := Vector2(SIZE, SIZE) * 0.5
	var r := SIZE * 0.5 - 6.0
	for p in map.pads:
		var s := _project(Vector3(p.x, 0, p.y))
		if s.length() <= 1.0:
			c.draw_rect(Rect2(mid + s * r - Vector2(2, 2), Vector2(4, 4)), Color(0.5, 0.85, 1.0))
	for i in chests.pos.size():
		if chests.is_open[i]:
			continue
		var s := _project(chests.pos[i])
		var gold: bool = chests.golden[i]
		if s.length() > 1.0:
			if not gold:
				continue
			s = s.normalized()
		var at := mid + s * r
		if gold:
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)]), Color(1.0, 0.8, 0.25))
		else:
			c.draw_rect(Rect2(at - Vector2(4, 3), Vector2(8, 6)), Color(0.05, 0.03, 0.02))
			c.draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 4)), Color(0.85, 0.6, 0.3))
	# The hero: an arrow pointing up (the way the camera looks).
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -8), mid + Vector2(6, 6), mid + Vector2(0, 3), mid + Vector2(-6, 6)]), Color(0.95, 0.9, 0.8))


## A small picture of the whole map: ground colors with hill shading and
## cliffs drawn dark. Built once per map.
func _map_texture() -> Texture2D:
	var key := "%s|%d" % [map.title, map.layout_seed]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := int(map.half_size * 2.0 / RES)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-1, 1.5, -1).normalized()
	for iz in n:
		for ix in n:
			var x := -map.half_size + (ix + 0.5) * RES
			var z := -map.half_size + (iz + 0.5) * RES
			var h := terrain.grid_height(x, z)
			var hx := terrain.grid_height(x + RES, z) - h
			var hz := terrain.grid_height(x, z + RES) - h
			var nrm := Vector3(-hx, RES, -hz).normalized()
			var c := terrain.color_at(x, z)
			var shade := 0.55 + 0.6 * clampf(nrm.dot(light), 0.0, 1.0)
			c = c * shade
			if nrm.y < 0.55:
				c = Color(0.08, 0.06, 0.08)
			if terrain.in_solid(x, z, 0.0):
				c = Color(0.55, 0.5, 0.45)
			img.set_pixel(ix, iz, c)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex
