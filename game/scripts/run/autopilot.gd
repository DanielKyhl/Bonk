class_name Autopilot
extends Node
## Test helper (`-- --autopilot`): steers in slow circles, bunny hops with good
## timing and slides now and then, by pressing the real input actions.

var player: Player
var _t := 0.0
var _jumping := false


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var ang := _t * 0.35
	var dir := Vector2(cos(ang), sin(ang))
	_axis("move_left", "move_right", dir.x)
	_axis("move_up", "move_down", dir.y)
	var ha := player.height_above_ground()
	if _jumping and not player.grounded and player.vel.y > 0.0:
		Input.action_release("jump")
		_jumping = false
	var hop_phase := fmod(_t, 12.0) < 8.0
	if hop_phase and not _jumping and (player.grounded or (player.vel.y < 0.0 and ha < 1.2)):
		Input.action_press("jump")
		_jumping = true
	if not hop_phase and player.grounded:
		Input.action_press("slide")
	else:
		Input.action_release("slide")


func _axis(neg: String, pos: String, v: float) -> void:
	if v > 0.2:
		Input.action_press(pos, v)
		Input.action_release(neg)
	elif v < -0.2:
		Input.action_press(neg, -v)
		Input.action_release(pos)
	else:
		Input.action_release(pos)
		Input.action_release(neg)
