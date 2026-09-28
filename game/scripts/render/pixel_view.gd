class_name PixelView
extends CanvasLayer
## Renders the 3D world into a low-resolution SubViewport and blows it up by a
## whole number with nearest filtering, so the whole world reads as pixel art.
## The camera snaps to the low-res pixel grid (no shimmering) and the image is
## shifted by the leftover fraction on screen, so motion stays smooth.
## Put 3D nodes under `world`; HUD and menus stay outside at full resolution.

const PPM := 24.0         ## Low-res pixels per meter (a 64px sprite is 2.7 m).
const TARGET_H := 450.0   ## Roughly this many pixel rows fill the screen.

var viewport: SubViewport
var world: Node3D
var pixel_scale := 2      ## Screen pixels per low-res pixel.
var _rect: TextureRect
var _shift := Vector2.ZERO


func _init() -> void:
	layer = -10
	viewport = SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	_rect = TextureRect.new()
	_rect.texture = viewport.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://shaders/pixel_upscale.gdshader")
	_rect.material = grade
	add_child(_rect)


func _ready() -> void:
	get_tree().root.size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	var win := Vector2(get_tree().root.size)
	pixel_scale = maxi(1, roundi(win.y / TARGET_H))
	# Two spare pixels on each side hide the edges when the image shifts.
	var w := int(ceil(win.x / pixel_scale)) + 4
	var h := int(ceil(win.y / pixel_scale)) + 4
	w += w % 2
	h += h % 2
	viewport.size = Vector2i(w, h)
	_place()


## Low-res pixel size of the rendered image (margins included).
func size() -> Vector2i:
	return viewport.size


## Height of the rendered image in meters, for an orthographic camera.
func ortho_size() -> float:
	return viewport.size.y / PPM


## The camera calls this with its sub-pixel remainder (in low-res pixels,
## +x right, +y up) after snapping itself to the grid.
func set_shift(frac: Vector2) -> void:
	_shift = frac
	_place()


func _place() -> void:
	var win := Vector2(get_tree().root.size) if is_inside_tree() else Vector2(1600, 900)
	var s := float(pixel_scale)
	var full := Vector2(viewport.size) * s
	var pos := ((win - full) * 0.5).floor()
	pos += Vector2(-_shift.x, _shift.y) * s
	pos = pos.round()
	# The root viewport stretches canvas items; undo it so our pixels land on
	# whole screen pixels.
	var k := get_tree().root.get_final_transform().x.x if is_inside_tree() else 1.0
	k = maxf(k, 0.0001)
	var xf := get_tree().root.get_final_transform() if is_inside_tree() else Transform2D.IDENTITY
	var inv := xf.affine_inverse()
	_rect.position = inv * pos
	_rect.size = full / k
