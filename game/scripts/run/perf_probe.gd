class_name PerfProbe
extends Node
## Test helper (`-- --perf`): prints frame and script timings every 2 seconds,
## then quits after 20 seconds.

var _t := 0.0
var _acc := 0.0
var _frames := 0
var _proc := 0.0
var enemies: EnemyManager


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	_frames += 1
	_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if _acc >= 2.0:
		print("fps %.1f | process %.2f ms/frame | enemies %d | draw calls %d" % [_frames / _acc, _proc / _frames, enemies.count if enemies else -1, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		print("  ", Prof.report(_frames))
		_acc = 0.0
		_frames = 0
		_proc = 0.0
	if _t > 20.0:
		get_tree().quit()
