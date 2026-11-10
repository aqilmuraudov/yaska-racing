extends TestCase
## Round 33 (0.17.4, first real phone pass on the Mi 12 Lite / Snapdragon 778G):
## the learned "auto" quality cap is forgotten after an update, PerfMonitor
## only judges racing frames, and the CPU savings in the track queries give
## exactly the old answers.

const TEST_SETTINGS := "user://test_settings_r33.json"
var _orig_settings_path := ""
var _orig_settings := {}


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)


func after_each() -> void:
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	Settings.apply_graphics()


func test_auto_cap_forgotten_after_update() -> void:
	Settings.values.graphics.quality = "auto"
	Settings.apply_preset("medium", false)
	check(Settings.auto_step_down(), "medium -> low")
	check_eq(String(Settings.values.graphics.auto_cap_build), Settings.build_version(), "cap tagged with this build")
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.auto_cap), "low", "same build: cap kept")
	check_eq(String(Settings.values.graphics.preset), "low", "same build: Low kept")
	# A cap learned on an older build (0.17.3 phones were stuck on Low).
	Settings.values.graphics.auto_cap_build = "0.0.1-old"
	Settings.save_settings()
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.auto_cap), "high", "old cap forgotten")
	check_eq(String(Settings.values.graphics.preset), Settings.auto_preset(), "auto tier re-derived")
	# Caps from builds before 0.17.4 have no build tag at all.
	Settings.values.graphics.auto_cap = "low"
	Settings.values.graphics.erase("auto_cap_build")
	Settings.save_settings()
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.auto_cap), "high", "untagged cap forgotten")
	# A player's own choice is never touched.
	Settings.values.graphics.quality = "low"
	Settings.apply_preset("low", false)
	Settings.values.graphics.auto_cap = "low"
	Settings.values.graphics.auto_cap_build = "0.0.1-old"
	Settings.save_settings()
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.preset), "low", "manual Low kept")


func test_perf_monitor_waits_for_racing_frames() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/core/perf_monitor.gd")
	check(src.contains("_racing_s < FALLBACK_WINDOW + SETTLE_TIME"), "window holds racing frames only")
	check(src.contains("_racing_s = 0.0 # the preset switch"), "settle again after a step-down")
	var pm := PerfMonitor.new()
	check(PerfMonitor.SETTLE_TIME >= 2.0, "settle time")
	pm.free()


## Reference: the 0.17.3 TrackData.project() without the bounds skip.
func _project_ref(td: TrackData, pos: Vector3, hint_s: float) -> Dictionary:
	var m := td.main.closest(pos, hint_s, 45.0)
	var best := {"s": m.s, "lateral": m.lateral, "on_shortcut": -1}
	var main_excess: float = m.distance - td.main.half_width_at(m.s)
	for i in td.shortcuts.size():
		var p: TrackPath = td.shortcuts[i].path
		var c := p.closest(pos)
		var excess: float = c.distance - p.half_width_at(c.s)
		if excess < main_excess and c.distance < p.half_width_at(c.s) + td.offroad_width + 2.0:
			var span := td.main.forward_delta(td.shortcuts[i].s_from, td.shortcuts[i].s_to)
			best = {"s": td.main.wrap_s(td.shortcuts[i].s_from + span * (c.s / maxf(p.length, 0.01))), "lateral": c.lateral, "on_shortcut": i}
			main_excess = excess
	return best


func test_track_queries_unchanged() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for id in TrackList.IDS:
		var td := TrackData.load_from_file(TrackList.path(id))
		var paths: Array[TrackPath] = [td.main]
		for sc in td.shortcuts:
			paths.append(sc.path)
		var bad := 0
		for p in paths:
			var count := p.points.size()
			var step := p.length / (count if p.closed else count - 1)
			for k in 300:
				var s := rng.randf_range(-20.0, p.length + 20.0)
				var w := p.wrap_s(s)
				var i := clampi(int(w / step), 0, count - 1)
				var i2 := (i + 1) % count if p.closed else mini(i + 1, count - 1)
				var f := clampf((w - i * step) / step, 0.0, 1.0)
				if not p.position_at(s).is_equal_approx(p.points[i].lerp(p.points[i2], f)) \
						or not is_equal_approx(p.half_width_at(s), lerpf(p.half_widths[i], p.half_widths[i2], f)):
					bad += 1
		check_eq(bad, 0, "%s: position/half width as before" % id)
		var diff := 0
		var shortcut_hits := 0
		for k in 600:
			var s := rng.randf_range(0.0, td.main.length)
			var pos := td.main.position_at(s) + td.main.right_at(s) * rng.randf_range(-25.0, 25.0) + Vector3.UP * rng.randf_range(-1.0, 2.0)
			var hint := s + rng.randf_range(-10.0, 10.0)
			var a := td.project(pos, hint)
			var b := _project_ref(td, pos, hint)
			if int(a.on_shortcut) >= 0:
				shortcut_hits += 1
			if int(a.on_shortcut) != int(b.on_shortcut) or not is_equal_approx(float(a.s), float(b.s)) or not is_equal_approx(float(a.lateral), float(b.lateral)):
				diff += 1
		# Also points on every shortcut, where the skip must not fire.
		for sc in td.shortcuts:
			var p: TrackPath = sc.path
			for k in 100:
				var ps := rng.randf_range(0.0, p.length)
				var pos := p.position_at(ps) + p.right_at(ps) * rng.randf_range(-8.0, 8.0)
				var a := td.project(pos, td.main.wrap_s(sc.s_from + ps))
				var b := _project_ref(td, pos, td.main.wrap_s(sc.s_from + ps))
				if int(a.on_shortcut) >= 0:
					shortcut_hits += 1
				if int(a.on_shortcut) != int(b.on_shortcut) or not is_equal_approx(float(a.s), float(b.s)):
					diff += 1
		check_eq(diff, 0, "%s: project() identical with the bounds skip" % id)
		if not td.shortcuts.is_empty():
			check(shortcut_hits > 0, "%s: shortcuts still found (%d)" % [id, shortcut_hits])


func test_skid_marks_rebuild_per_frame() -> void:
	var marks := SkidMarks.new()
	check(SkidMarks.REBUILD_HZ <= 30.0, "rebuild capped")
	check(marks.has_method("_process"), "rebuild moved to the frame")
	marks.free()
