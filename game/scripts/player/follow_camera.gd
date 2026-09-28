class_name FollowCamera
extends Camera3D
## Orthographic camera for the pixel-art view. Looks down at the player from a
## fixed pitch, snaps to the low-res pixel grid so the world never shimmers,
## and hands the leftover sub-pixel offset to PixelView so scrolling stays
## smooth. `yaw` turns the view around the player (0 looks toward -Z).

@export var pitch_deg := 50.0
## How quickly the view catches up with the player (higher = tighter).
@export var follow_speed := 6.0
@export var distance := 80.0    ## Only keeps the terrain in front of the near plane.

var target: Player
var view: PixelView
var yaw := 0.0
var shake := 0.0
var _focus := Vector3.ZERO
var _snap := true


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 1.0
	far = 260.0


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := _goal()
	if _snap:
		_focus = goal
		_snap = false
	_focus = _focus.lerp(goal, 1.0 - exp(-follow_speed * delta))
	shake = maxf(0.0, shake - delta * 18.0)
	var b := Basis.from_euler(Vector3(-deg_to_rad(pitch_deg), yaw, 0.0))
	var focus := _focus + (b.x * randf_range(-1, 1) + b.y * randf_range(-1, 1)) * shake * 0.03
	# Snap the focus to whole low-res pixels along the screen axes.
	var ppm := PixelView.PPM
	var fr := focus.dot(b.x) * ppm
	var fu := focus.dot(b.y) * ppm
	var sr := roundf(fr)
	var su := roundf(fu)
	var snapped := focus + b.x * ((sr - fr) / ppm) + b.y * ((su - fu) / ppm)
	global_transform = Transform3D(b, snapped + b.z * distance)
	if view:
		size = view.ortho_size()
		view.set_shift(Vector2(fr - sr, fu - su))


func _goal() -> Vector3:
	var t := target
	var ground := t.terrain.height(t.position.x, t.position.z)
	return Vector3(t.position.x, lerpf(ground, t.position.y, 0.6) + 0.8, t.position.z)


func add_shake(amount: float) -> void:
	shake = minf(12.0, shake + amount)


func snap() -> void:
	_snap = true
