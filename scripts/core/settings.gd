extends Node
## Persistent player settings. Every change is saved immediately and applied
## through signals so open scenes (race world, HUD, audio) can react.

signal changed(section: String, key: String)
signal graphics_changed

const SETTINGS_VERSION := 5
const DEFAULT_PATH := "user://settings.json"
const PRESET_PATH := "res://data/graphics/presets.json"
const BUTTON_SCALES := [0.85, 1.0, 1.2]
const PRESET_KEYS := ["resolution_scale", "msaa", "fxaa", "shadows", "effects_density",
	"decor_distance", "texture_detail", "ssao", "bloom", "fps_cap", "dynamic_resolution", "render_height"]

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
	var preset_name := auto_preset()
	var g: Dictionary = (presets.get(preset_name, {}) as Dictionary).duplicate()
	g.merge({
		"preset": preset_name,
		"resolution_scale": 0.8, "render_height": 864, "msaa": 0, "fxaa": true, "shadows": 1, "effects_density": 0.7,
		"decor_distance": 1, "texture_detail": 1, "ssao": false, "bloom": true, "fps_cap": 60,
		"dynamic_resolution": false, "motion_blur": false, "brightness": 1.0, "vsync": true,
		"fps_fallback": true, # steady 30 when 60 cannot be held (PerfMonitor)
		"window_mode": "windowed", "dev_overlay": false, "tilt_debug": false,
		# Player-facing picture choice (auto|low|medium|high) and 30 FPS saver;
		# they drive the detailed keys above via the presets.
		"quality": "auto", "battery_saver": false, "auto_cap": "high",
		"speed_effects": true, # speed lines + boost FOV kick (0.9.1)
	})
	return {
		"version": SETTINGS_VERSION,
		"graphics": g,
		# Player-facing: three switches. The levels are fixed mix values
		# (developer panel only); switches never overwrite them.
		"audio": {"master_on": true, "music_on": true, "sfx_on": true, "voices_on": true,
			"master": 0.9, "music": 0.6, "engine": 0.7, "sfx": 0.8, "ui": 0.7,
			"mute": false, "background_audio": false},
		"controls": {
			"touch_steer_mode": "buttons", # buttons | tilt
			"kids_auto": false, # 0.9.5 Kids controls: the kart drives itself
			"touch_auto_accelerate": true,
			"touch_scale": 1.0, # derived from button_size
			"button_size": 1, # 0 small, 1 medium, 2 large
			"touch_opacity": 0.65,
			"touch_layout": "default", # default | swapped
			"touch_offset_x": 0.0,
			"touch_offset_y": 0.0,
			"tilt_sensitivity": 1.0, # legacy (v1), migrated into steer_level
			"tilt_neutral_deg": 0.0,
			"steer_level": 1, # 0 low, 1 normal, 2 high (buttons and tilt)
			"deadzone": InputActions.DEFAULT_DEADZONE,
			"steer_sensitivity": 1.0, # legacy (v1), migrated into steer_level
			"vibration": true,
			# Drift boosts fire when DRIFT is released while charged (no
			# separate timing button, no overheating). Keyboard/pad BOOST
			# timing presses keep working either way.
			"easy_drift": true,
			"bindings": {},
		},
		"gameplay": {
			"difficulty": "medium",
			"steer_assist": false, # off: the player always has full control (0.7.0)
			"accel_assist": false,
			"camera_distance": 1, # 0 near, 1 normal, 2 far
			"camera_mode": 0, # 0 chase, 1 drone (top-down), 2 right side, 3 left side, 4 cinematic
			"speedometer": true,
			"catchup_assist": true,
			"language": "az",
			"time_of_day": "day", # 0.10.1 Race setup: day / sunset / night
			"track": "seafront_sprint", # 0.11.0 last picked track
		},
		"accessibility": {
			"ui_scale": 1.0,
			"camera_shake": 0.6, # 0 off, 0.6 gentle, 1.0 full
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
	var from_version := int(loaded.get("version", 1))
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
	if from_version < 2:
		_migrate_v1(loaded)
	if from_version < 3:
		_migrate_v2()
	if from_version < 4:
		_migrate_v3()
	if from_version < 5:
		_migrate_v4()
	_sanitize()


## v1 → v2: volumes/mute become switches, the free sensitivity and button
## scale become three levels. Old numeric values are kept, nothing is reset.
func _migrate_v1(loaded: Dictionary) -> void:
	var a: Dictionary = values.audio
	a.master_on = not bool(a.mute) and float(a.master) > 0.01
	a.music_on = float(a.music) > 0.01
	a.sfx_on = float(a.sfx) > 0.01 or float(a.engine) > 0.01
	a.mute = false
	for k in ["master", "music", "sfx", "engine", "ui"]:
		if float(a[k]) <= 0.01:
			a[k] = float(defaults().audio[k]) # level kept for when the switch is on
	var c: Dictionary = values.controls
	var lc: Dictionary = loaded.get("controls", {}) if typeof(loaded.get("controls")) == TYPE_DICTIONARY else {}
	var sens := float(lc.get("tilt_sensitivity", 1.0)) if String(c.touch_steer_mode) == "tilt" else float(c.steer_sensitivity)
	c.steer_level = 0 if sens < 0.85 else (2 if sens > 1.15 else 1)
	var ts := float(c.touch_scale)
	c.button_size = 0 if ts < 0.92 else (2 if ts > 1.1 else 1)


## v2 → v3: steering help and camera shake were developer-only options, so
## their stored values are the old defaults, not player choices; they move to
## the new child-friendly defaults. Easy drift is new (default on).
## v3 → v4: steering help was forced on by v3 and hidden from Settings in
## 0.6.2, so players could not turn it off and it steered the kart by itself
## (centre pull + edge correction). It is now off for everyone.
func _migrate_v3() -> void:
	values.gameplay.steer_assist = false


## v4 → v5 (0.11.2): presets gained `render_height` (phone 3D height cap).
## Only that new key is filled from the stored preset; every other stored
## value (frame rate, texture detail, ...) is the player's and is kept.
func _migrate_v4() -> void:
	var g: Dictionary = values.graphics
	var preset_name := String(g.get("preset", "medium"))
	if presets.has(preset_name) and presets[preset_name].has("render_height"):
		g.render_height = int(presets[preset_name].render_height)


func _migrate_v2() -> void:
	values.gameplay.steer_assist = true
	if float(values.accessibility.camera_shake) >= 0.99:
		values.accessibility.camera_shake = 0.6


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


const QUALITY_LEVELS := ["auto", "low", "medium", "high"]
const TIERS := ["low", "medium", "high"]
## GPUs that get the Low tier on "auto" (older / entry-level mobile parts).
const WEAK_GPU_HINTS := ["Adreno (TM) 3", "Adreno (TM) 4", "Adreno (TM) 50", "Adreno (TM) 51", "Adreno (TM) 52",
	"Adreno (TM) 60", "Adreno (TM) 61", "Mali-4", "Mali-T", "Mali-G31", "Mali-G51", "Mali-G52", "Mali-G57",
	"PowerVR", "IMG", "llvmpipe", "SwiftShader"]
## GPUs strong enough for High on "auto".
const STRONG_GPU_HINTS := ["Adreno (TM) 73", "Adreno (TM) 74", "Adreno (TM) 75", "Adreno (TM) 8",
	"Immortalis", "Mali-G715", "Mali-G720", "Mali-G925", "Xclipse"]


## 0.10.2 automatic tier. Desktop: High. Mobile: chosen from the GPU name
## and core count, then lowered for good by PerfMonitor (auto_step_down)
## when a race cannot hold its frame rate; the learned cap is saved.
func auto_preset(gpu := "", cores := -1, mobile := -1) -> String:
	var is_mob := is_mobile() if mobile < 0 else mobile == 1
	if gpu == "":
		gpu = RenderingServer.get_video_adapter_name()
	if cores < 0:
		cores = OS.get_processor_count()
	var tier := "high"
	if is_mob:
		tier = "medium"
		for h in STRONG_GPU_HINTS:
			if gpu.contains(h):
				tier = "high"
		for h in WEAK_GPU_HINTS:
			if gpu.contains(h):
				tier = "low"
		if cores > 0 and cores <= 4:
			tier = "low"
	var cap := String(values.get("graphics", {}).get("auto_cap", "high")) if not values.is_empty() else "high"
	if TIERS.find(cap) >= 0 and TIERS.find(tier) > TIERS.find(cap):
		tier = cap
	return tier


## Called by PerfMonitor on "auto" when a race runs slow: one tier down,
## remembered for later sessions. Returns false when already on Low.
func auto_step_down() -> bool:
	var cur := String(values.graphics.get("preset", "medium"))
	var i := TIERS.find(cur)
	if i <= 0:
		return false
	values.graphics.auto_cap = TIERS[i - 1]
	apply_preset(TIERS[i - 1], false)
	save_settings()
	apply_graphics()
	changed.emit("graphics", "preset")
	return true


## One simple picture-quality choice for players. "auto" uses the device
## default preset; the battery saver then caps the frame rate at 30.
func set_quality(level: String) -> void:
	if level not in QUALITY_LEVELS:
		level = "auto"
	var preset_name := level
	if level == "auto":
		preset_name = auto_preset()
	apply_preset(preset_name, false)
	values.graphics.quality = level
	if bool(values.graphics.get("battery_saver", false)):
		values.graphics.fps_cap = 30
	save_settings()
	apply_graphics()
	changed.emit("graphics", "quality")


func set_battery_saver(on: bool) -> void:
	values.graphics.battery_saver = on
	values.graphics.fps_cap = 30 if on else 60
	_sanitize()
	save_settings()
	apply_graphics()
	changed.emit("graphics", "battery_saver")


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
	g.render_height = clampi(int(g.get("render_height", 0)), 0, 2160)
	g.msaa = clampi(int(g.msaa), 0, 2)
	g.shadows = clampi(int(g.shadows), 0, 3)
	g.effects_density = clampf(float(g.effects_density), 0.0, 1.0)
	g.decor_distance = clampi(int(g.decor_distance), 0, 2)
	g.texture_detail = clampi(int(g.texture_detail), 0, 2)
	g.brightness = clampf(float(g.brightness), 0.6, 1.5)
	g.fps_cap = int(g.fps_cap)
	if g.fps_cap not in fps_options():
		g.fps_cap = 60
	if String(g.get("quality", "auto")) not in QUALITY_LEVELS:
		g.quality = "auto"
	g.battery_saver = bool(g.get("battery_saver", false))
	var a: Dictionary = values.accessibility
	a.ui_scale = clampf(float(a.ui_scale), 0.8, 1.4)
	a.camera_shake = clampf(float(a.camera_shake), 0.0, 1.0)
	var c: Dictionary = values.controls
	c.button_size = clampi(int(c.button_size), 0, 2)
	c.touch_scale = BUTTON_SCALES[c.button_size]
	c.steer_level = clampi(int(c.steer_level), 0, 2)
	c.tilt_neutral_deg = clampf(float(c.tilt_neutral_deg), -45.0, 45.0)
	if c.touch_steer_mode not in ["buttons", "tilt"]:
		c.touch_steer_mode = "buttons"
	c.touch_opacity = clampf(float(c.touch_opacity), 0.2, 1.0)
	c.deadzone = clampf(float(c.deadzone), 0.05, 0.6)
	c.steer_sensitivity = clampf(float(c.steer_sensitivity), 0.5, 1.5)
	c.touch_offset_x = clampf(float(c.touch_offset_x), -0.1, 0.1)
	c.touch_offset_y = clampf(float(c.touch_offset_y), -0.1, 0.1)
	if values.gameplay.difficulty not in ["easy", "medium", "hard"]:
		values.gameplay.difficulty = "medium"
	values.gameplay.camera_mode = clampi(int(values.gameplay.get("camera_mode", 0)), 0, 4) # 4 = cinematic (0.10.2)
	if values.gameplay.language not in ["az", "en"]:
		values.gameplay.language = "az"
	if not TrackList.is_valid(String(values.gameplay.get("track", ""))):
		values.gameplay.track = "seafront_sprint"
	if String(values.gameplay.get("time_of_day", "")) not in ["day", "sunset", "night"]:
		values.gameplay.time_of_day = "day"


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
	var base := base_render_scale()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if base * dynamic_scale >= 0.99 else _upscale_mode()
	vp.scaling_3d_scale = clampf(base * dynamic_scale, 0.5, 1.0)
	vp.fsr_sharpness = FSR_SHARPNESS
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(g.msaa)]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if g.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	# Texture quality: asset tier (TextureLibrary: 256 / 512 / 1024 px sets),
	# mip bias and anisotropic filtering.
	var tq := int(g.texture_detail)
	vp.texture_mipmap_bias = [0.5, 0.0, -0.25][tq]
	vp.anisotropic_filtering_level = [Viewport.ANISOTROPY_DISABLED, Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X][tq]
	TextureLibrary.set_tier(tq)
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
		dynamic_scale = maxf(dynamic_scale - 0.05, 0.5 / maxf(base_render_scale(), 0.5))
	elif _frame_ema < target * 0.85:
		dynamic_scale = minf(dynamic_scale + 0.025, 1.0)
	if not is_equal_approx(old, dynamic_scale):
		var vp := get_tree().root
		var sc := clampf(base_render_scale() * dynamic_scale, 0.5, 1.0)
		vp.scaling_3d_scale = sc
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if sc >= 0.99 else _upscale_mode()


## FSR 1.0 sharpens the upscale but Godot 4.4 only offers it on Forward+
## ("FSR1 is only available when using the Forward+ renderer", checked
## 0.11.2 on the Mobile renderer); phones use bilinear scaling.
const FSR_SHARPNESS := 0.2


func _upscale_mode() -> Viewport.Scaling3DMode:
	if rendering_method() == "forward_plus":
		return Viewport.SCALING_3D_MODE_FSR
	return Viewport.SCALING_3D_MODE_BILINEAR


## 0.11.2: 3D render scale before the adaptive (dynamic) factor. On phones the
## preset's `render_height` caps the 3D height in pixels, so a 1440p phone does
## not render 78 % more pixels than a 1080p one at the same preset; the HUD
## stays at native resolution. Desktop keeps the plain fraction.
func base_render_scale() -> float:
	var g: Dictionary = values.get("graphics", {})
	var short_px := 0
	if is_mobile() and is_inside_tree():
		var sz := get_tree().root.size
		short_px = mini(sz.x, sz.y)
	return render_scale_for(float(g.get("resolution_scale", 1.0)), int(g.get("render_height", 0)), short_px)


static func render_scale_for(fraction: float, render_height: int, screen_short_px: int) -> float:
	var sc := clampf(fraction, 0.5, 1.0)
	if render_height > 0 and screen_short_px > 0:
		sc = minf(sc, float(render_height) / float(screen_short_px))
	return clampf(sc, 0.5, 1.0)


## Frame-rate caps offered to the player. A cap is a ceiling, not a promise:
## the simulation always ticks at 60 Hz with interpolation, so the cap never
## changes driving, timers or sensor filtering. Desktop builds also keep
## "unlimited" (0) for development.
static func fps_options() -> Array:
	if is_mobile():
		return [30, 60, 90, 120]
	return [30, 60, 90, 120, 0]


## Display refresh rate in Hz, or 0 when the platform cannot tell.
static func display_refresh_rate() -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
	return maxf(DisplayServer.screen_get_refresh_rate(), 0.0)


## With vsync (always on for Android) a cap above the panel's current refresh
## rate cannot be reached, so such caps are shown disabled.
static func fps_supported(cap: int) -> bool:
	if cap <= 60:
		return true
	var hz := display_refresh_rate()
	if hz <= 0.0:
		return not is_mobile()
	if is_desktop() and not bool(Settings.values.get("graphics", {}).get("vsync", true)):
		return true
	return cap <= int(round(hz)) + 1


static func has_touch() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available() or DebugRunner.parse_args().has("touch")


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
		"tilt":
			if not is_mobile() and not DebugRunner.parse_args().has("fake-tilt"):
				return "SET_REASON_NO_SENSOR"
		"vibration":
			if not is_mobile():
				return "SET_REASON_DESKTOP_ONLY"
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
