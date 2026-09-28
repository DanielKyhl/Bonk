extends SceneTree
## Rasterizes SVG files to PNG for tools/sprites/icons.py.
## godot --headless --script raster_svg.gd -- <size> <in.svg> <out.png> [<in.svg> <out.png> ...]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var size := int(args[0])
	var i := 1
	while i + 1 < args.size():
		var svg := FileAccess.get_file_as_string(args[i])
		var img := Image.new()
		img.load_svg_from_string(svg, size / 512.0)
		img.save_png(args[i + 1])
		i += 2
	quit()
