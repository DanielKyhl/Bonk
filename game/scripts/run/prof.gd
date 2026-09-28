class_name Prof
extends RefCounted
## Tiny accumulating profiler for test runs: Prof.add("name", usec).

static var totals := {}
static var frames := 0


static func add(key: String, usec: int) -> void:
	totals[key] = totals.get(key, 0) + usec


static func report(n: int) -> String:
	var parts := []
	for k in totals:
		parts.append("%s %.2f" % [k, totals[k] / 1000.0 / n])
	totals.clear()
	return " | ".join(parts)
