class_name FollowCamera
extends Camera3D
## Fixed-angle overhead camera: leads in the direction of travel, rises with
## big jumps and pulls back as you speed up.

@export var pitch_deg := 52.0
@export var base_distance := 19.0
@export var fast_distance := 24.0

var target: Player
var shake := 0.0
var _look := Vector3.ZERO
var _dist := 25.0
var _snap := true


func _process(delta: float) -> void:
	if target == null:
		return
	var t := target
	var sp := t.speed()
	var ground := t.terrain.height(t.position.x, t.position.z)
	var goal := Vector3(t.position.x + t.vel.x * 0.16, lerpf(ground, t.position.y, 0.55) + 1.0, t.position.z + t.vel.z * 0.16)
	var want_dist := lerpf(base_distance, fast_distance, clampf((sp - 13.0) / 45.0, 0.0, 1.0))
	if _snap:
		_look = goal
		_dist = want_dist
		_snap = false
	_look = _look.lerp(goal, 1.0 - exp(-7.0 * delta))
	_dist = lerpf(_dist, want_dist, 1.0 - exp(-2.5 * delta))
	var p := deg_to_rad(pitch_deg)
	var offset := Vector3(0.0, sin(p), cos(p)) * _dist
	shake = maxf(0.0, shake - delta * 18.0)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.08
	global_position = _look + offset + jitter
	look_at(_look + jitter, Vector3.UP)


func add_shake(amount: float) -> void:
	shake = minf(12.0, shake + amount)


func snap() -> void:
	_snap = true
