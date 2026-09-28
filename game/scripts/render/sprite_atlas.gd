class_name SpriteAtlas
extends RefCounted
## One character's sprite atlas (see SpriteMeta) and the material that draws it.

const FRAME := 64

var id := ""
var texture: Texture2D
var cols := 9
var rows := 9
var anims := {}   ## name -> [first row, frames, directions]

static var _cache := {}


static func get_atlas(atlas_id: String) -> SpriteAtlas:
	if _cache.has(atlas_id):
		return _cache[atlas_id]
	var a := SpriteAtlas.new()
	var meta: Dictionary = SpriteMeta.ATLASES[atlas_id]
	a.id = atlas_id
	a.texture = load("res://assets/sprites/%s.png" % atlas_id)
	a.cols = meta.cols
	a.rows = meta.rows
	a.anims = meta.anims
	_cache[atlas_id] = a
	return a


func has(anim: String) -> bool:
	return anims.has(anim)


func frames(anim: String) -> int:
	return anims[anim][1]


## Packs animation + frame for INSTANCE_CUSTOM.x of the sprite shader.
func code(anim: String, frame: int) -> float:
	var a: Array = anims[anim]
	var c := float(clampi(frame, 0, a[1] - 1) + 16 * int(a[0]))
	if int(a[2]) == 1:
		c += 4096.0
	return c


func material(tint := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sprite.gdshader")
	m.set_shader_parameter("atlas", texture)
	m.set_shader_parameter("grid", Vector2(cols, rows))
	m.set_shader_parameter("ppm", PixelView.PPM)
	m.set_shader_parameter("tint", tint)
	return m


## A MultiMesh of camera-facing quads using this atlas.
func multimesh(count: int, tint := Color.WHITE) -> MultiMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = material(tint)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = count
	mm.visible_instance_count = 0
	return mm
