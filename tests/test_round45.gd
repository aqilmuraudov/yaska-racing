extends TestCase
## Round 45 (0.20.3): the owner renamed the Android package (2026-11-12:
## "yaskaracing olaraq olsun") from az.bakuturbo.game to az.yaskaracing.game,
## before the Play Store release (a published package can never change).
## Same signing key; the old app stays on the phone as a separate app, its
## saved data is copied over by tools/migrate_profile.py.

const NEW_PKG := "az.yaskaracing.game"
const OLD_PKG := "az.bakuturbo.game"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func _preset_value(text: String, key: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(key + "="):
			return line.substr(key.length() + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


func test_android_package_renamed() -> void:
	var cfg := _read("res://export_presets.cfg")
	check(cfg != "", "export presets readable")
	check_eq(_preset_value(cfg, "package/unique_name"), NEW_PKG, "new package name")
	check(not cfg.contains(OLD_PKG), "old package name gone from the presets")


func test_version_bumped() -> void:
	var cfg := _read("res://export_presets.cfg")
	check(int(_preset_value(cfg, "version/code")) >= 53, "versionCode 53+ (52 was the last az.bakuturbo.game build)")
	check_eq(_preset_value(cfg, "version/name"), str(ProjectSettings.get_setting("application/config/version")), "version name = project version")


func test_tools_use_new_package() -> void:
	check(_read("res://tools/phone_fps.py").contains("PKG = \"%s\"" % NEW_PKG), "phone FPS tool reads the new package")
	var mig := _read("res://tools/migrate_profile.py")
	check(mig.contains("OLD = \"%s\"" % OLD_PKG) and mig.contains("NEW = \"%s\"" % NEW_PKG), "migration tool copies old -> new")
	check(_read("res://scripts/core/perf_monitor.gd").contains("run-as " + NEW_PKG), "perf log hint names the new package")
