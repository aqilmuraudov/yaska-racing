class_name Prof
## TEMP profiling (0.17.4 phone pass): per-script _physics_process time.
static var on := false
static var acc := {}


static func add(key: StringName, t0: int) -> void:
	acc[key] = int(acc.get(key, 0)) + Time.get_ticks_usec() - t0
