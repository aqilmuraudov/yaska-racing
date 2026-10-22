extends Node
## Persistent player settings. Every change is saved immediately and applied
## through signals so open scenes (race world, HUD, audio) can react.

signal changed(section: String, key: String)
signal graphics_changed

const SETTINGS_VERSION := 1
const DEFAULT_PATH := "user://settings.json"
const PRESET_PATH := "res://data/graphics/presets.json"
const PRESET_KEYS := ["resolution_scale", "msaa", "fxaa", "shadows", "effects_density",
	"decor_distance", "texture_detail", "ssao", "bloom", "fps_cap", "dynamic_resolution"]

var save_path := DEFAULT_PATH
var values: Dictionary = {}
var presets: Dictionary = {}
var safe_mode := false
## Dynamic resolution: current automatic scale (<= the chosen scale).
var dynamic_scale := 1.0
var _frame_ema := 0.0
var _dyn_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	presets = _load_presets()
	safe_mode = "--safe-mode" in OS.get_cmdline_user_args() or "--safe-mode" in OS.get_cmdline_args()
	load_settings()
	if safe_mode:
		apply_preset("low", false)
		values.graphics.window_mode = "windowed"
		values.graphics.vsync = true
		save_settings()
	InputActions.register_defaults(values.controls.deadzone)
	InputActions.apply_overrides(values.controls.bindings)
	apply_all()


func defaults() -> Dictionary:
	var mobile := is_mobile()
	var preset_name := "medium" if mobile else "high"
	var g: Dictionary = (presets.get(preset_name, {}) as Dictionary).duplicate()
	g.merge({
		"preset": preset_name,
		"resolution_scale": 0.8, "msaa": 0, "fxaa": true, "shadows": 1, "effects_density": 0.7,
		"decor_distance": 1, "texture_detail": 1, "ssao": false, "bloom": true, "fps_cap": 60,
		"dynamic_resolution": false, "motion_blur": false, "brightness": 1.0, "vsync": true,
		"window_mode": "windowed",
	})
	return {
		"version": SETTINGS_VERSION,
		"graphics": g,
		"audio": {"master": 0.9, "music": 0.6, "engine": 0.7, "sfx": 0.8, "ui": 0.7,
			"mute": false, "background_audio": false},
		"controls": {
			"touch_steer_mode": "buttons", # buttons | tilt
			"touch_auto_accelerate": true,
			"touch_scale": 1.0,
			"touch_opacity": 0.65,
			"touch_layout": "default", # default | swapped
			"touch_offset_x": 0.0,
			"touch_offset_y": 0.0,
			"tilt_sensitivity": 1.0,
			"deadzone": InputActions.DEFAULT_DEADZONE,
			"steer_sensitivity": 1.0,
			"vibration": true,
			"bindings": {},
		},
		"gameplay": {
			"difficulty": "medium",
			"steer_assist": false,
			"accel_assist": false,
			"camera_distance": 1, # 0 near, 1 normal, 2 far
			"speedometer": true,
			"catchup_assist": true,
			"language": "az",
		},
		"accessibility": {
			"ui_scale": 1.0,
			"camera_shake": 1.0,
			"reduced_flashing": false,
			"subtitles": true,
			"high_contrast": false,
		},
	}


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func load_settings() -> void:
	values = defaults()
	var result := SafeFile.read_json(save_path, func(d): return d.has("version") and int(d.version) <= SETTINGS_VERSION)
	if result.source == "none":
		return
	var loaded: Dictionary = result.data
	for section in values.keys():
		if typeof(values[section]) != TYPE_DICTIONARY or not loaded.has(section):
			continue
		if typeof(loaded[section]) != TYPE_DICTIONARY:
			continue
		for key in values[section].keys():
			if loaded[section].has(key):
				var dv = values[section][key]
				var lv = loaded[section][key]
				if typeof(dv) == typeof(lv):
					values[section][key] = lv
				elif typeof(dv) == TYPE_INT and typeof(lv) == TYPE_FLOAT:
					values[section][key] = int(lv)
				elif typeof(dv) == TYPE_FLOAT and typeof(lv) == TYPE_INT:
					values[section][key] = float(lv)
	_sanitize()


func save_settings() -> void:
	values.version = SETTINGS_VERSION
	SafeFile.write_json(save_path, values)


func restore_defaults() -> void:
	values = defaults()
	save_settings()
	InputActions.register_defaults(values.controls.deadzone)
	apply_all()
	for section in values.keys():
		changed.emit(section, "*")


func get_value(section: String, key: String, fallback = null):
	if values.has(section) and values[section].has(key):
		return values[section][key]
	return fallback


func set_value(section: String, key: String, value, persist := true) -> void:
	if not values.has(section):
		return
	values[section][key] = value
	if section == "graphics" and key in PRESET_KEYS:
		values.graphics.preset = "custom"
	_sanitize()
	if persist:
		save_settings()
	_apply_key(section, key)
	changed.emit(section, key)


func apply_preset(preset_name: String, persist := true) -> void:
	if not presets.has(preset_name):
		return
	for key in PRESET_KEYS:
		if presets[preset_name].has(key):
			values.graphics[key] = presets[preset_name][key]
	values.graphics.preset = preset_name
	_sanitize()
	if persist:
		save_settings()
	apply_graphics()
	changed.emit("graphics", "preset")


func _sanitize() -> void:
	var g: Dictionary = values.graphics
	g.resolution_scale = clampf(float(g.resolution_scale), 0.5, 1.0)
	g.msaa = clampi(int(g.msaa), 0, 2)
	g.shadows = clampi(int(g.shadows), 0, 3)
	g.effects_density = clampf(float(g.effects_density), 0.0, 1.0)
	g.decor_distance = clampi(int(g.decor_distance), 0, 2)
	g.texture_detail = clampi(int(g.texture_detail), 0, 2)
	g.brightness = clampf(float(g.brightness), 0.6, 1.5)
	if int(g.fps_cap) not in [30, 60, 90, 120, 0]:
		g.fps_cap = 60
	var a: Dictionary = values.accessibility
	a.ui_scale = clampf(float(a.ui_scale), 0.8, 1.4)
	a.camera_shake = clampf(float(a.camera_shake), 0.0, 1.0)
	var c: Dictionary = values.controls
	c.touch_scale = clampf(float(c.touch_scale), 0.7, 1.5)
	c.touch_opacity = clampf(float(c.touch_opacity), 0.2, 1.0)
	c.deadzone = clampf(float(c.deadzone), 0.05, 0.6)
	c.steer_sensitivity = clampf(float(c.steer_sensitivity), 0.5, 1.5)
	c.touch_offset_x = clampf(float(c.touch_offset_x), -0.1, 0.1)
	c.touch_offset_y = clampf(float(c.touch_offset_y), -0.1, 0.1)
	if values.gameplay.difficulty not in ["easy", "medium", "hard"]:
		values.gameplay.difficulty = "medium"
	if values.gameplay.language not in ["az", "en"]:
		values.gameplay.language = "az"


func _load_presets() -> Dictionary:
	var text := FileAccess.get_file_as_string(PRESET_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Settings: cannot parse %s" % PRESET_PATH)
		return {}
	parsed.erase("_doc")
	return parsed


# --- Applying ---------------------------------------------------------------

func apply_all() -> void:
	apply_graphics()
	_apply_language()
	_apply_ui_scale()
	InputActions.set_deadzone(values.controls.deadzone)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").apply_volumes()


func _apply_key(section: String, key: String) -> void:
	match section:
		"graphics":
			apply_graphics()
		"audio":
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").apply_volumes()
		"gameplay":
			if key == "language":
				_apply_language()
		"accessibility":
			if key == "ui_scale":
				_apply_ui_scale()
		"controls":
			if key == "deadzone":
				InputActions.set_deadzone(values.controls.deadzone)
			elif key == "bindings":
				InputActions.register_defaults(values.controls.deadzone)
				InputActions.apply_overrides(values.controls.bindings)


## Viewport-level graphics. World-level settings (shadows, glow, decor,
## particles) are applied by WorldGraphics in the race scene on graphics_changed.
func apply_graphics() -> void:
	var g: Dictionary = values.graphics
	var vp := get_tree().root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if float(g.resolution_scale) >= 0.99 else _upscale_mode()
	vp.scaling_3d_scale = clampf(float(g.resolution_scale) * dynamic_scale, 0.5, 1.0)
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(g.msaa)]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if g.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.texture_mipmap_bias = [0.75, 0.0, -0.25][int(g.texture_detail)]
	Engine.max_fps = int(g.fps_cap)
	if is_desktop():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g.vsync else DisplayServer.VSYNC_DISABLED)
		var want_full: bool = g.window_mode == "fullscreen"
		var is_full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if want_full != is_full and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	graphics_changed.emit()


## Adaptive render scale: drops in 5 % steps when frames run long and
## recovers slowly when there is headroom. Never exceeds the chosen scale.
func _process(delta: float) -> void:
	var g: Dictionary = values.get("graphics", {})
	if g.is_empty() or not bool(g.get("dynamic_resolution", false)) or unsupported_reason("dynamic_resolution") != "":
		if dynamic_scale != 1.0:
			dynamic_scale = 1.0
			apply_graphics()
		return
	var target := 1.0 / maxf(float(g.fps_cap if int(g.fps_cap) > 0 else 60), 30.0)
	_frame_ema = lerpf(_frame_ema, delta, 0.1)
	_dyn_timer += delta
	if _dyn_timer < 0.5:
		return
	_dyn_timer = 0.0
	var old := dynamic_scale
	if _frame_ema > target * 1.12:
		dynamic_scale = maxf(dynamic_scale - 0.05, 0.5 / maxf(float(g.resolution_scale), 0.5))
	elif _frame_ema < target * 0.85:
		dynamic_scale = minf(dynamic_scale + 0.025, 1.0)
	if not is_equal_approx(old, dynamic_scale):
		get_tree().root.scaling_3d_scale = clampf(float(g.resolution_scale) * dynamic_scale, 0.5, 1.0)


func _upscale_mode() -> Viewport.Scaling3DMode:
	# FSR 1.0 sharpens the upscale but Godot only offers it on Forward+;
	# the Mobile renderer (Android) uses bilinear scaling.
	if rendering_method() == "forward_plus":
		return Viewport.SCALING_3D_MODE_FSR
	return Viewport.SCALING_3D_MODE_BILINEAR


static func is_desktop() -> bool:
	return OS.has_feature("pc") and not is_mobile()


static func rendering_method() -> String:
	return RenderingServer.get_current_rendering_method()


## Returns "" when the option works here, otherwise a translation key that
## explains why the option is disabled.
func unsupported_reason(option: String) -> String:
	var method := rendering_method()
	match option:
		"ssao":
			if method != "forward_plus":
				return "SET_REASON_SSAO_RENDERER"
		"msaa":
			if method == "gl_compatibility":
				return "SET_REASON_RENDERER"
		"window_mode", "vsync":
			if not is_desktop():
				return "SET_REASON_DESKTOP_ONLY"
		"dynamic_resolution":
			if method == "gl_compatibility":
				return "SET_REASON_RENDERER"
	return ""


func _apply_language() -> void:
	TranslationServer.set_locale(values.gameplay.language)


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = float(values.accessibility.ui_scale)


func save_bindings_from_inputmap() -> void:
	var out := {}
	for action in InputActions.GAMEPLAY_ACTIONS:
		var list: Array = []
		for ev in InputMap.action_get_events(action):
			var d := InputActions.event_to_descriptor(ev)
			if not d.is_empty():
				list.append(d)
		out[String(action)] = list
	values.controls.bindings = out
	save_settings()
	changed.emit("controls", "bindings_saved")


func reset_bindings() -> void:
	values.controls.bindings = {}
	save_settings()
	InputActions.register_defaults(values.controls.deadzone)
	changed.emit("controls", "bindings")
