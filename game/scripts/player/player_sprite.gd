class_name PlayerSprite
extends MultiMeshInstance3D
## Draws the hero as a pixel-art sprite at the player's feet and picks the
## animation frame from what the player is doing.

var player: Player
var atlas: SpriteAtlas
var flash := 0.0
var _t := 0.0
var _attack_t := -1.0
var _buf := PackedFloat32Array()


func setup(p: Player, atlas_id: String) -> void:
	player = p
	atlas = SpriteAtlas.get_atlas(atlas_id)
	multimesh = atlas.multimesh(1)
	multimesh.visible_instance_count = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	_buf.resize(16)


## Plays the attack swing once (weapons call this when they fire).
func swing() -> void:
	if _attack_t < 0.0:
		_attack_t = 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	var sp := player.speed()
	var anim := "walk"
	var frame := 0
	flash = maxf(0.0, flash - delta * 6.0)
	if _attack_t >= 0.0 and atlas.has("slash"):
		_attack_t += delta * 16.0
		if _attack_t >= atlas.frames("slash"):
			_attack_t = -1.0
		else:
			anim = "slash"
			frame = int(_attack_t)
	if anim == "walk":
		if player.sliding or player.slide_air or player.slamming:
			frame = 4
		elif not player.grounded:
			frame = 2
		elif sp > 1.0:
			# The walk cycle is frames 1-8 (two steps); stride about 2.6 m.
			_t += delta * clampf(sp / 2.6 * 8.0 / 2.0, 6.0, 22.0)
			frame = 1 + int(_t) % 8
		else:
			_t = 0.0
	var f := player.facing
	# The node follows the player (for culling); the instance sits at its origin.
	global_position = player.global_position
	_buf[0] = 1.0; _buf[1] = 0.0; _buf[2] = 0.0; _buf[3] = 0.0
	_buf[4] = 0.0; _buf[5] = 1.0; _buf[6] = 0.0; _buf[7] = 0.0
	_buf[8] = 0.0; _buf[9] = 0.0; _buf[10] = 1.0; _buf[11] = 0.0
	_buf[12] = atlas.code(anim, frame)
	_buf[13] = atan2(f.x, f.y)
	_buf[14] = flash
	_buf[15] = 1.0
	multimesh.buffer = _buf
