extends MapDef
## Fixed layout for the movement tests, independent of the real maps: a slide
## hill, a crest kicker, a launch pad and a cliff plateau on flat ground.

func _init() -> void:
	title = "Test"
	layout_seed = 1
	spawn = Vector2(0, 20)
	rolling = Vector4(0.0, 12.9, 0.0, 7.9)
	hill(0, -86, 13.0, 26, 22)
	kicker(12, 22, 0)
	pads.append(Vector2(-18, -16))
	plateau(-10, 96, 6.5, 26, 24, 0, 1.6, 0.05)
