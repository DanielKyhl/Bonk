class_name MouseLookCamera
extends FollowCamera
## Third-person style mouse look for the top-down pixel view. Moving the mouse
## left/right turns the camera around the player (the right stick does the
## same on a gamepad), WASD follows the camera so W always runs up the screen,
## and the hero faces where the camera looks.
##
## The cursor is captured and hidden while playing and freed whenever the game
## pauses: Esc opens the pause menu, and level-up cards need the mouse. Click
## the game to capture it again.
##
## Sprites, damage numbers and the HUD stay upright on their own: sprites and
## numbers always face the camera, and the HUD is drawn on top of the world.

## Degrees of turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.25
## Seconds the view takes to ease most of the way into a new heading, so
## turning feels floaty rather than snappy (0 = instant).
@export var rotation_smoothing := 0.12
## Degrees per second at full tilt on the gamepad's right stick.
@export var stick_turn_speed := 160.0

var _target_yaw := 0.0


func _ready() -> void:
	super()
	# Runs while paused too, to free the cursor for menus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target_yaw = yaw


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_target_yaw -= deg_to_rad((event as InputEventMouseMotion).relative.x * mouse_sensitivity)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var paused := get_tree().paused
	if paused:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and get_window().has_focus():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_target_yaw -= deg_to_rad(Input.get_axis("turn_left", "turn_right") * stick_turn_speed) * delta
	# Both angles are unwrapped, so a plain lerp never takes the long way round.
	var k := 1.0 if rotation_smoothing <= 0.0 else 1.0 - exp(-delta / rotation_smoothing)
	yaw = lerpf(yaw, _target_yaw, k)
	if target:
		target.view_yaw = yaw
		target.face_camera = true
	super(delta)


func snap() -> void:
	yaw = _target_yaw
	super()
