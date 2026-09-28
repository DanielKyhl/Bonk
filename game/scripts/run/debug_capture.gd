class_name DebugCapture
extends Node
## Test helper: `godot -- --shot=out.png --frames=90` saves a screenshot after
## N frames and quits. `--shots=a.png,b.png --every=60` saves several.
## Does nothing unless those arguments are passed.

signal before_shot(index: int)

var _paths: PackedStringArray = []
var _every := 90
var _frame := 0
var _index := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_paths = PackedStringArray([a.get_slice("=", 1)])
		elif a.begins_with("--shots="):
			_paths = a.get_slice("=", 1).split(",")
		elif a.begins_with("--frames=") or a.begins_with("--every="):
			_every = int(a.get_slice("=", 1))
	set_process(not _paths.is_empty())
	process_mode = Node.PROCESS_MODE_ALWAYS


func active() -> bool:
	return not _paths.is_empty()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == _every - 2:
		before_shot.emit(_index)
	if _frame < _every:
		return
	_frame = 0
	var img := get_viewport().get_texture().get_image()
	img.save_png(_paths[_index])
	print("saved ", _paths[_index])
	_index += 1
	if _index >= _paths.size():
		get_tree().quit()
