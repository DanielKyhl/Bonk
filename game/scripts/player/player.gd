class_name Player
extends Node3D
## The hero's movement: running, bunny hops, slides, slams, stomps, slope
## landings, crest launches, launch pads. Ported from the browser
## prototype (prototype/game.js) and converted to meters (24 units = 1 m).
##
## Physics runs in fixed substeps of at most 1/120 s inside _process.

signal hopped(chain: int)
signal landed(air_time: float, impact: float)
signal slammed(pos: Vector3, power: float)
signal stomped(enemy: int, pos: Vector3, slam: bool)
signal launched(pos: Vector3)
signal air_jumped(pos: Vector3)
signal slide_started(pos: Vector3)

# --- Tuning -------------------------------------------------------------------
const GRAVITY := 91.7
const RADIUS := 0.5
const GROUND_ACCEL := 108.0
const STOP_DECEL := 117.0
const OVERSPEED_DECEL := 25.8     ## Extra speed bleeds off this fast once you stay grounded.
const BRAKE_DECEL := 100.0
const GROUND_TURN := 7.0          ## rad/s of steering when faster than run speed.
const AIR_BRAKE := 17.5
const HOP_BEFORE := 0.14          ## A jump pressed this long before landing counts as perfect...
const HOP_AFTER := 0.07           ## ...or this long after.
const SLIDE_MIN := 5.8
const SLIDE_BOOST_CD := 0.9
const SLIDE_TURN := 1.5
const SLOPE_SLIDE := 55.0         ## Downhill pull while sliding, per unit of gradient.
const SLIDE_DRAG := 0.01          ## Sliding slows by this x speed^2, so steep slides top out.
const SLOPE_RUN := 15.8
const SLAM_VEL := 70.8
const SLAM_BOOST := 2.5
const PAD_LAUNCH := 47.9
const PAD_RADIUS := 1.7
const COYOTE := 0.08
const STEP := 0.8                 ## Taller than this per substep is a wall.
const MAX_CLIMB := 1.4            ## Steeper uphill than this is a wall.
const MAX_SPEED := 36.0           ## 130 km/h: nothing goes faster.
const KMH := 3.6

# --- Stats (upgrades change these) ------------------------------------------
var run_speed := 7.6
var jump_vel := 26.7
var air_jumps := 0
## Bunny hops start modest; Tomes of Agility raise both (see run.gd).
var hop_boost := 0.03
var hop_cap := 12.0
var slide_friction := 8.0
var slide_boost := 0.6
var air_turn := 2.6
var air_accel := 45.8

# --- State ----------------------------------------------------------------------
var terrain: Terrain
var pads: Array[Vector2] = []
## Optional stomp check: func(pos: Vector3, prev_y: float) -> int (enemy index or -1).
var stomp_probe := Callable()
## Optional: returns the stomp target's top height for an index.
var stomp_top := Callable()

var vel := Vector3.ZERO
var grounded := true
var sliding := false
var slide_air := false
var slamming := false
var ground_time := 1.0
var air_time := 0.0
var last_air := 0.0
var coyote := 0.0
var chain := 0
var best_chain := 0
var best_air := 0.0
var top_speed := 0.0
var air_jumps_left := 0
var facing := Vector2(0, 1)
var wish := Vector2.ZERO
var input_locked := false
var sprite_id := "crusader"
## Camera heading (radians, 0 = looking toward -Z), set by the camera. WASD is
## turned by it so W always runs up the screen.
var view_yaw := 0.0
## When true the hero faces where the camera looks instead of where she runs.
var face_camera := false

var _t := 0.0
var _jump_buf := -1.0
var _jump_seq := 0
var _jump_seen := 0
var _slide_seq := 0
var _slide_seen := 0
var _jump_held := false
var _slide_held := false
var _slide_cd := 0.0
var _pad_cd := 0.0
var _squash := 0.0
var _land_anim := 0.0

## The hero's sprite (run.gd blinks it while invulnerable).
var model: PlayerSprite
var _shadow: MeshInstance3D


func _ready() -> void:
	model = PlayerSprite.new()
	add_child(model)
	model.top_level = true
	model.setup(self, sprite_id)
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/blob_shadow.gdshader")
	_shadow.material_override = sm
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_shadow.top_level = true


func place(p: Vector2) -> void:
	position = Vector3(p.x, terrain.height(p.x, p.y), p.y)
	vel = Vector3.ZERO
	grounded = true


func speed() -> float:
	return Vector2(vel.x, vel.z).length()


func height_above_ground() -> float:
	return maxf(0.0, position.y - terrain.height(position.x, position.z))


# -----------------------------------------------------------------------------
# Frame
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not input_locked:
		if Input.is_action_just_pressed("jump"):
			_jump_seq += 1
		if Input.is_action_just_pressed("slide"):
			_slide_seq += 1
		_jump_held = Input.is_action_pressed("jump")
		_slide_held = Input.is_action_pressed("slide")
		wish = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if wish.length() < 0.25:
			wish = Vector2.ZERO
		else:
			wish = wish.normalized().rotated(-view_yaw)
	else:
		wish = Vector2.ZERO
		_jump_held = false
		_slide_held = false
	var steps := maxi(1, ceili(delta * 120.0))
	var h := delta / steps
	for i in steps:
		_t += h
		_step(h)
	top_speed = maxf(top_speed, speed())
	_update_visuals(delta)


func _step(dt: float) -> void:
	var has_wish := wish != Vector2.ZERO
	_slide_cd -= dt
	_pad_cd -= dt
	_squash = maxf(0.0, _squash - dt * 5.0)

	if _jump_seq != _jump_seen:
		_jump_seen = _jump_seq
		_on_jump_press()
	if _slide_seq != _slide_seen:
		_slide_seen = _slide_seq
		_on_slide_press()

	if grounded:
		ground_time += dt
		var buffered := _jump_buf >= 0.0 and _t - _jump_buf <= HOP_BEFORE
		var in_window := ground_time <= HOP_AFTER and last_air >= 0.15
		if buffered:
			_do_jump(in_window)
		elif _jump_held and in_window:
			_do_jump(false)   # auto-hop keeps speed, no boost
		elif chain > 0 and ground_time > HOP_AFTER:
			chain = 0

	var g0 := terrain.height(position.x, position.z)
	var sgx := terrain.gx
	var sgz := terrain.gz

	if grounded:
		var sp := speed()
		if not sliding and _slide_held and sp > SLIDE_MIN:
			_start_slide(sp)
		if sliding:
			_move_slide(dt, has_wish, sgx, sgz)
		else:
			_move_run(dt, has_wish, sgx, sgz)
	else:
		_move_air(dt, has_wish)

	var hv := Vector2(vel.x, vel.z)
	var sp2 := hv.length()
	if sp2 > MAX_SPEED:
		hv *= MAX_SPEED / sp2
		vel.x = hv.x
		vel.z = hv.y
	if face_camera:
		facing = Vector2(-sin(view_yaw), -cos(view_yaw))
	elif sp2 > 0.8:
		facing = hv / sp2
	elif has_wish:
		facing = wish

	# Move horizontally; anything much taller than we are is a wall.
	var ox := position.x
	var oz := position.z
	var m := terrain.half - 1.0
	position.x = clampf(ox + vel.x * dt, -m, m)
	position.z = clampf(oz + vel.z * dt, -m, m)
	var g1 := terrain.height(position.x, position.z)
	if _blocked(g1, ox, oz, dt):
		position.z = oz
		if _blocked(terrain.height(position.x, position.z), ox, oz, dt):
			position.x = ox
			vel.x = 0.0
		position.z = clampf(oz + vel.z * dt, -m, m)
		if _blocked(terrain.height(position.x, position.z), ox, oz, dt):
			position.z = oz
			vel.z = 0.0
		g1 = terrain.height(position.x, position.z)
	var ngx := terrain.gx
	var ngz := terrain.gz

	if grounded:
		# Follow the ground unless it falls away faster than gravity would pull us down.
		var zb := position.y + vel.y * dt - 0.5 * GRAVITY * dt * dt
		if zb > g1 + 0.02:
			grounded = false
			position.y = zb
			vel.y -= GRAVITY * dt
			air_time = 0.0
			coyote = COYOTE
			air_jumps_left = air_jumps
			slide_air = sliding
			sliding = false
		else:
			position.y = g1
			vel.y = (g1 - g0) / dt
	else:
		var prev_y := position.y
		vel.y -= GRAVITY * dt
		position.y += vel.y * dt
		air_time += dt
		coyote -= dt
		var stomped_now := false
		if vel.y < 0.0 and stomp_probe.is_valid():
			var idx: int = stomp_probe.call(position, prev_y)
			if idx >= 0:
				_stomp(idx)
				stomped_now = true
		if not stomped_now and position.y <= g1:
			_land(g1, ngx, ngz)

	if grounded and _pad_cd <= 0.0:
		for p in pads:
			if Vector2(position.x - p.x, position.z - p.y).length_squared() < PAD_RADIUS * PAD_RADIUS:
				grounded = false
				sliding = false
				slide_air = false
				vel.y = PAD_LAUNCH
				air_time = 0.0
				coyote = 0.0
				air_jumps_left = air_jumps
				_pad_cd = 0.4
				launched.emit(position)
				break


func _blocked(g1: float, ox: float, oz: float, dt: float) -> bool:
	var rise := g1 - position.y
	if rise > STEP:
		return true
	if grounded and rise > 0.0:
		var run := Vector2(position.x - ox, position.z - oz).length()
		return run > 0.0001 and rise / run > MAX_CLIMB
	return false


# -----------------------------------------------------------------------------
# Actions
# -----------------------------------------------------------------------------
func _on_jump_press() -> void:
	if grounded:
		_jump_buf = _t
		return
	if coyote > 0.0 and not slamming:
		# Jumping right after the ground drops away (a crest or a cliff lip) stacks on your rise.
		vel.y = maxf(vel.y, 0.0) + jump_vel
		coyote = 0.0
		_jump_buf = -1.0
		hopped.emit(-1)
		return
	var h_above := maxf(0.0, position.y - terrain.height(position.x, position.z))
	var t_land := (vel.y + sqrt(vel.y * vel.y + 2.0 * GRAVITY * h_above)) / GRAVITY
	if t_land > HOP_BEFORE and air_jumps_left > 0:
		_air_jump()
	else:
		_jump_buf = _t


func _on_slide_press() -> void:
	if grounded or slamming:
		return
	if position.y - terrain.height(position.x, position.z) > 0.9:
		slamming = true
		vel.y = -SLAM_VEL


func _do_jump(perfect: bool) -> void:
	vel.y = jump_vel + maxf(0.0, vel.y) * 0.7   # jumping on an upslope carries its rise
	grounded = false
	sliding = false
	slide_air = false
	air_time = 0.0
	coyote = 0.0
	_jump_buf = -1.0
	air_jumps_left = air_jumps
	if perfect:
		chain += 1
		var sp := speed()
		if sp > 2.5 and sp < hop_cap:
			_set_speed(minf(hop_cap, sp * (1.0 + hop_boost)))
		best_chain = maxi(best_chain, chain)
		hopped.emit(chain)
	else:
		hopped.emit(0)


func _air_jump() -> void:
	air_jumps_left -= 1
	vel.y = jump_vel * 0.92
	slamming = false
	_jump_buf = -1.0
	if wish != Vector2.ZERO:
		var hv := Vector2(vel.x, vel.z)
		var sp := hv.length()
		if sp > 0.1:
			hv = _rotate_toward(hv / sp, wish, 1.3) * sp
		if sp < run_speed:
			hv = wish * run_speed
		vel.x = hv.x
		vel.z = hv.y
	air_jumped.emit(position)


func _start_slide(sp: float) -> void:
	sliding = true
	if _slide_cd <= 0.0 and sp < hop_cap:
		_set_speed(minf(hop_cap, sp + slide_boost))
		_slide_cd = SLIDE_BOOST_CD
		slide_started.emit(position)


func _land(g1: float, ngx: float, ngz: float) -> void:
	var impact := -vel.y
	# Keep the part of the velocity that runs along the surface: landing on a
	# downslope turns fall speed into ground speed, an upslope eats it.
	var nl := sqrt(ngx * ngx + ngz * ngz + 1.0)
	var nx := -ngx / nl
	var nz := -ngz / nl
	var ny := 1.0 / nl
	var vn := vel.x * nx + vel.z * nz + vel.y * ny
	if vn < 0.0:
		vel.x -= vn * nx
		vel.z -= vn * nz
	if speed() > MAX_SPEED:
		_set_speed(MAX_SPEED)
	position.y = g1
	grounded = true
	slide_air = false
	vel.y = ngx * vel.x + ngz * vel.z
	var t := air_time
	if t >= 0.1:
		ground_time = 0.0
		last_air = t
	best_air = maxf(best_air, t)
	if slamming:
		_slam_impact(impact)
	elif t >= 0.1:
		_squash = minf(1.0, impact / 60.0)
		_land_anim = 0.25
	if _slide_held and speed() > SLIDE_MIN:
		sliding = true
	landed.emit(t, impact)


func _slam_impact(impact: float) -> void:
	slamming = false
	var power := clampf(impact / 62.0, 0.6, 2.2)
	var hv := Vector2(vel.x, vel.z)
	var sp := hv.length()
	var dir := Vector2.ZERO
	if sp > 1.6:
		dir = hv / sp
	elif wish != Vector2.ZERO:
		dir = wish
		sp = 0.0
	if dir != Vector2.ZERO:
		var cap := hop_cap + 2.0
		var ns := minf(cap, sp + SLAM_BOOST) if sp < cap else sp
		vel.x = dir.x * ns
		vel.z = dir.y * ns
		sliding = true
	_squash = 1.0
	slammed.emit(position, power)


func _stomp(idx: int) -> void:
	var top: float = stomp_top.call(idx) if stomp_top.is_valid() else position.y
	var was_slam := slamming
	slamming = false
	slide_air = false
	position.y = top
	vel.y = jump_vel * (1.05 if _jump_held else 0.82)
	air_time = 0.0
	coyote = 0.0
	air_jumps_left = air_jumps
	chain += 1
	best_chain = maxi(best_chain, chain)
	var sp := speed()
	if sp > 2.5 and sp < hop_cap:
		_set_speed(minf(hop_cap, sp * (1.0 + hop_boost)))
	stomped.emit(idx, position, was_slam)


# -----------------------------------------------------------------------------
# Horizontal movement
# -----------------------------------------------------------------------------
func _move_run(dt: float, has_wish: bool, sgx: float, sgz: float) -> void:
	var hv := Vector2(vel.x, vel.z)
	var sp := hv.length()
	var grace := ground_time <= HOP_AFTER   # just landed: keep every bit of speed
	if has_wish:
		if sp <= run_speed + 0.05:
			hv = hv.move_toward(wish * run_speed, GROUND_ACCEL * dt)
		else:
			# Carrying momentum: steer, and let the extra speed bleed off slowly.
			var d := hv / sp
			if d.dot(wish) < -0.3:
				sp = maxf(0.0, sp - BRAKE_DECEL * dt)
			elif not grace:
				sp = maxf(run_speed, sp - OVERSPEED_DECEL * dt)
			hv = _rotate_toward(d, wish, GROUND_TURN * dt) * sp
	elif not grace or sp <= run_speed:
		var dec := (OVERSPEED_DECEL * 1.8 if sp > run_speed else STOP_DECEL) * dt
		hv = Vector2.ZERO if sp <= dec else hv - hv / sp * dec
	vel.x = hv.x - sgx * SLOPE_RUN * dt
	vel.z = hv.y - sgz * SLOPE_RUN * dt


func _move_slide(dt: float, has_wish: bool, sgx: float, sgz: float) -> void:
	var hv := Vector2(vel.x, vel.z)
	var sp := hv.length()
	if sp > 0.05:
		var d := hv / sp
		if has_wish:
			d = _rotate_toward(d, wish, SLIDE_TURN * dt)
		sp = maxf(0.0, sp - (slide_friction + SLIDE_DRAG * sp * sp) * dt)
		hv = d * sp
	vel.x = hv.x - sgx * SLOPE_SLIDE * dt
	vel.z = hv.y - sgz * SLOPE_SLIDE * dt
	if not _slide_held or speed() < 3.75:
		sliding = false


func _move_air(dt: float, has_wish: bool) -> void:
	if not has_wish:
		return
	var hv := Vector2(vel.x, vel.z)
	var sp := hv.length()
	if sp < run_speed * 0.9:
		hv = hv.move_toward(wish * run_speed, air_accel * dt)
	else:
		var d := hv / sp
		if d.dot(wish) < -0.5:
			sp = maxf(run_speed * 0.9, sp - AIR_BRAKE * dt)
		hv = _rotate_toward(d, wish, air_turn * dt) * sp
	vel.x = hv.x
	vel.z = hv.y


func _set_speed(ns: float) -> void:
	var hv := Vector2(vel.x, vel.z)
	var sp := hv.length()
	if sp > 0.001:
		hv *= ns / sp
		vel.x = hv.x
		vel.z = hv.y


func _rotate_toward(d: Vector2, target: Vector2, max_ang: float) -> Vector2:
	var a := clampf(d.angle_to(target), -max_ang, max_ang)
	return d.rotated(a)


# -----------------------------------------------------------------------------
# Visuals
# -----------------------------------------------------------------------------
func _update_visuals(_delta: float) -> void:
	var gy := terrain.height(position.x, position.z)
	var ha := maxf(0.0, position.y - gy)
	_shadow.global_position = Vector3(position.x, gy + 0.06, position.z)
	var s := 1.0 / (1.0 + ha / 6.0)
	_shadow.scale = Vector3(s, 1.0, s)
	(_shadow.material_override as ShaderMaterial).set_shader_parameter("strength", 0.3 + 0.35 * s)
