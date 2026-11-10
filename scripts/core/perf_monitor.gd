class_name PerfMonitor
extends Node
## Frame-time monitoring for real devices (child of Game, always running).
##
## * Steady-30 fallback: during a race with the 60 FPS cap, if more than
##   FALLBACK_SHARE of the frames in the last FALLBACK_WINDOW seconds took
##   longer than 20 ms (the device cannot hold 60), the cap drops to 30 for
##   the rest of the session: an even 30 feels smoother than a jittery 40-55.
##   It never climbs back by itself (no oscillation); changing the frame-rate
##   setting resets it. Setting: graphics.fps_fallback.
## * Performance overlay (developer tab): FPS, 1 % low, CPU/GPU ms, share of
##   slow frames, display refresh rate, cap, draw calls, memory, fallback.
## * While the overlay is on, one CSV line per second goes to
##   user://logs/perf_<time>.csv, so a 10-15 minute session on a phone shows
##   sustained (thermal) performance: pull it with
##   adb shell run-as az.bakuturbo.game cat files/logs/perf_....csv

const FALLBACK_WINDOW := 4.0
const FALLBACK_SHARE := 0.25
const SLOW_FRAME := 1.0 / 50.0

var fallback_active := false
var _times: Array[float] = [] # recent frame deltas (seconds)
var _sum := 0.0
var _layer: CanvasLayer
var _label: Label
var _log: FileAccess
var _log_timer := 0.0
var _gpu_on := false
var _last_cap := -1
## 0.17.4: seconds of uninterrupted racing. The window must hold racing frames
## only: before, the countdown / first-frame shader hitches filled it and the
## step-down fired 0.3 s into the race.
var _racing_s := 0.0
const SETTLE_TIME := 2.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(func(section, key):
		if section == "graphics" and key in ["fps_cap", "fps_fallback", "preset", "*"]:
			_reset_fallback())


func _reset_fallback() -> void:
	if fallback_active:
		fallback_active = false
		Engine.max_fps = int(Settings.get_value("graphics", "fps_cap", 60))
	_times.clear()
	_sum = 0.0


func _process(delta: float) -> void:
	_times.append(delta)
	_sum += delta
	while _sum > FALLBACK_WINDOW and _times.size() > 1:
		_sum -= _times.pop_front()
	_govern()
	var overlay := bool(Settings.get_value("graphics", "dev_overlay", false))
	if overlay != (_layer != null):
		_set_overlay(overlay)
	if overlay:
		_update_overlay(delta)


func _in_race() -> bool:
	var race := get_tree().current_scene as RaceManager
	return race != null and not race.paused and race.state in [RaceManager.RaceState.RACING, RaceManager.RaceState.FINISHING]


func _govern() -> void:
	if fallback_active or not bool(Settings.get_value("graphics", "fps_fallback", true)):
		return
	if not _in_race():
		_racing_s = 0.0
		return
	_racing_s += _times.back() if not _times.is_empty() else 0.0
	if int(Settings.get_value("graphics", "fps_cap", 60)) != 60 or _racing_s < FALLBACK_WINDOW + SETTLE_TIME:
		return
	if _sum < FALLBACK_WINDOW * 0.95:
		return
	if slow_share() > FALLBACK_SHARE:
		# 0.10.2: on "auto" first drop one picture tier (kept for later
		# sessions); only on Low does the steady-30 cap kick in.
		if Settings.is_mobile() and String(Settings.get_value("graphics", "quality", "auto")) == "auto" and Settings.auto_step_down():
			print("PerfMonitor: slow frames, auto quality now %s" % Settings.values.graphics.preset)
			_times.clear()
			_sum = 0.0
			_racing_s = 0.0 # the preset switch hitches (textures, shadows, pipelines)
			return
		fallback_active = true
		Engine.max_fps = 30
		print("PerfMonitor: %.0f%% of frames over 20 ms for %.0f s, steady 30 FPS for this session" % [slow_share() * 100.0, FALLBACK_WINDOW])


## Share of recent frames slower than 20 ms.
func slow_share() -> float:
	if _times.is_empty():
		return 0.0
	var n := 0
	for t in _times:
		if t > SLOW_FRAME:
			n += 1
	return float(n) / _times.size()


## FPS of the slowest 1 % of recent frames.
func one_percent_low() -> float:
	if _times.is_empty():
		return 0.0
	var s := _times.duplicate()
	s.sort()
	var worst: float = s[clampi(int(s.size() * 0.99), 0, s.size() - 1)]
	return 1.0 / maxf(worst, 0.0001)


func _set_overlay(on: bool) -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, on)
	_gpu_on = on
	if on:
		_layer = CanvasLayer.new()
		_layer.layer = 120
		add_child(_layer)
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 16)
		_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
		_label.add_theme_constant_override("outline_size", 6)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.position = Vector2(250, 4)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_label)
		DirAccess.make_dir_recursive_absolute("user://logs")
		_log = FileAccess.open("user://logs/perf_%d.csv" % int(Time.get_unix_time_from_system()), FileAccess.WRITE)
		if _log:
			_log.store_line("t_s,scene,fps,low1_fps,cpu_ms,gpu_ms,slow_share,cap,refresh_hz,draws,prims,mem_mb,fallback")
	else:
		if _layer:
			_layer.queue_free()
		_layer = null
		_label = null
		if _log:
			_log.close()
		_log = null


func _update_overlay(delta: float) -> void:
	var vp := get_viewport().get_viewport_rid()
	var cpu := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp) if _gpu_on else 0.0
	var fps := Engine.get_frames_per_second()
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var hz := Settings.display_refresh_rate()
	_label.text = "FPS %d  1%%low %.0f  CPU %.1f ms  GPU %.1f ms  >20ms %.0f%%  %.0f Hz cap %d  draws %d  mem %.0f MB%s" % [
		fps, one_percent_low(), cpu, gpu, slow_share() * 100.0, hz, Engine.max_fps, draws, mem, "  [steady 30]" if fallback_active else ""]
	_log_timer += delta
	if _log and _log_timer >= 1.0:
		_log_timer = 0.0
		var scn := get_tree().current_scene
		_log.store_line("%.1f,%s,%d,%.1f,%.2f,%.2f,%.3f,%d,%.0f,%d,%d,%.1f,%d" % [Time.get_ticks_msec() / 1000.0, scn.name if scn else "-", fps, one_percent_low(), cpu, gpu, slow_share(), Engine.max_fps, hz, draws, prims, mem, int(fallback_active)])
		_log.flush()
