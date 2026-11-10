extends SceneTree
## Headless test runner:
##   godot --headless -s tests/run_tests.gd [-- --only=test_name_fragment]
## Exit code 0 when every check passes.

const RUN_SETTINGS := "user://test_run_settings.json"
const RUN_PROFILE := "user://test_run_profile.json"


func _init() -> void:
	# Wait one frame so autoloads are ready.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# 0.17.4: no test may write the player's real files. Several tests change
	# settings in memory without redirecting the path, and a later
	# Settings.set_value() then saved them into the owner's settings.json
	# (Quality "high" with preset "medium" after every full run). Every save
	# of this process goes to throw-away files, removed at the end.
	# (autoloads are looked up at run time: a -s script cannot name them)
	root.get_node("Settings").save_path = RUN_SETTINGS
	root.get_node("SaveManager").save_path = RUN_PROFILE
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append("res://tests/" + f)
	files.sort()
	var total_checks := 0
	var all_failures: Array[String] = []
	var methods_run := 0
	for path in files:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			all_failures.append("%s: failed to load/compile" % path)
			print("[FAIL] %s does not compile" % path)
			continue
		for m in script.get_script_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			if only != "" and not (path + ":" + mname).contains(only):
				continue
			var tc: TestCase = script.new()
			tc.tree = self
			tc._current = "%s:%s" % [path.get_file(), mname]
			await tc.before_each()
			await tc.call(mname)
			await tc.after_each()
			methods_run += 1
			total_checks += tc.checks
			var status := "PASS" if tc.failures.is_empty() else "FAIL"
			print("[%s] %s (%d checks)" % [status, tc._current, tc.checks])
			for f in tc.failures:
				print("    ✗ ", f)
			all_failures.append_array(tc.failures)
	for p in [RUN_SETTINGS, RUN_PROFILE]:
		for f in [p, p + ".tmp", p + ".bak"]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(f)
	print("")
	print("%d test methods, %d checks, %d failures" % [methods_run, total_checks, all_failures.size()])
	quit(0 if all_failures.is_empty() else 1)
