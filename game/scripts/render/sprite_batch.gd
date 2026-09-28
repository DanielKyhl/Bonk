class_name SpriteBatch
extends MultiMeshInstance3D
## Up to MAX small pixel sprites from one atlas, refilled every frame: weapon
## orbs, projectiles and impacts. Call begin(), add() each sprite, commit().

const MAX := 256
const STRIDE := 16

var _buf := PackedFloat32Array()
var _n := 0


## grid: atlas columns and rows; anchor_px: pixel row the position refers to
## (frame_px / 2 centers the sprite on it); bias: meters pulled toward the
## camera so effects draw over nearby characters.
func setup(atlas: Texture2D, grid: Vector2, frame_px: float, anchor_px: float, bias := 0.0) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sprite.gdshader")
	mat.set_shader_parameter("atlas", atlas)
	mat.set_shader_parameter("grid", grid)
	mat.set_shader_parameter("ppm", PixelView.PPM)
	mat.set_shader_parameter("frame_px", frame_px)
	mat.set_shader_parameter("foot_px", anchor_px)
	mat.set_shader_parameter("lean", 0.5)
	mat.set_shader_parameter("bias", bias)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = q
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	_buf.resize(MAX * STRIDE)


func begin() -> void:
	_n = 0


## frame: column, row: atlas row; angle: screen rotation in radians
## (counterclockwise); alpha fades by dropping pixels.
func add(pos: Vector3, frame: int, row: int, angle := 0.0, scale := 1.0, alpha := 1.0) -> void:
	if _n >= MAX:
		return
	var o := _n * STRIDE
	var c := cos(angle) * scale
	var s := sin(angle) * scale
	_buf[o] = c
	_buf[o + 1] = -s
	_buf[o + 2] = 0.0
	_buf[o + 3] = pos.x
	_buf[o + 4] = s
	_buf[o + 5] = c
	_buf[o + 6] = 0.0
	_buf[o + 7] = pos.y
	_buf[o + 8] = 0.0
	_buf[o + 9] = 0.0
	_buf[o + 10] = scale
	_buf[o + 11] = pos.z
	_buf[o + 12] = float(frame + 16 * row + 4096)
	_buf[o + 13] = 0.0
	_buf[o + 14] = 0.0
	_buf[o + 15] = alpha
	_n += 1


func commit() -> void:
	multimesh.visible_instance_count = _n
	if _n > 0:
		multimesh.buffer = _buf
