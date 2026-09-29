class_name PortalArrow
extends Control
## After the boss falls: an arrow circling the hero that points at the portal,
## with the distance, so it's easy to find. Hidden once the portal is close.

const RADIUS := 150.0        ## Screen pixels from the hero to the arrow.
const HIDE_WITHIN := 16.0    ## Meters: close enough to see the portal itself.
const COLOR := Color(0.6, 0.9, 1.0)

var boss: Boss
var player: Player
var camera: FollowCamera

var _dir := Vector2.RIGHT     ## On screen, toward the portal.
var _t := 0.0
var _label: Label


func _ready() -> void:
	# In the tree already, so set offsets too (anchors alone keep a 0x0 rect).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UIStyle.label("", UIStyle.ui_font("Bold"), 20, COLOR, 6)
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	_t += delta
	var d := Vector2.ZERO
	var show := boss != null and player != null and camera != null and boss.state == Boss.DEFEATED
	if show:
		d = Vector2(boss.altar.x - player.position.x, boss.altar.z - player.position.z)
		show = d.length() > HIDE_WITHIN
	visible = show
	if not show:
		return
	# Turn the world direction into the camera's screen frame (y grows down).
	var b := camera.global_transform.basis
	var right := Vector2(b.x.x, b.x.z).normalized()
	var fwd := -Vector2(b.z.x, b.z.z).normalized()
	_dir = Vector2(d.dot(right), -d.dot(fwd)).normalized()
	_label.text = "PORTAL  %d m" % int(d.length())
	var c := _hero()
	_label.position = c + _dir * (RADIUS + 60.0) - _label.size / 2.0
	queue_redraw()


## Roughly where the hero stands on screen (the camera keeps them centered).
func _hero() -> Vector2:
	return size / 2.0 + Vector2(0, -24)


func _draw() -> void:
	var c := _hero()
	var side := _dir.orthogonal()
	var bob := sin(_t * 6.0) * 6.0
	var base := c + _dir * (RADIUS + bob)
	var tip := base + _dir * 34.0
	var pts := PackedVector2Array([tip, base + side * 22.0, base + _dir * 10.0, base - side * 22.0])
	var col := COLOR
	col.a = 0.75 + 0.25 * sin(_t * 6.0)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.02, 0.03, 0.05), 6.0)
	draw_colored_polygon(pts, col)
