extends Control
## First scene. Continues the engine boot splash with the very same picture on
## the same background colour (assets/splash/splash.png, project.godot
## boot_splash/*), loads the main menu on a thread with a small progress bar,
## then lets Game dissolve the splash into the first rendered menu frame.

const SPLASH := "res://assets/splash/splash.png"
const MIN_TIME := 0.35 ## avoid a one-frame logo flash on fast devices

var bar: ProgressBar
var _time := 0.0
var _requested := false
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BLUE_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(splash_rect())
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(320, 16)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-160, -70)
	bar.size = Vector2(320, 16)
	bar.add_theme_stylebox_override("background", UITheme.rounded(Color(UITheme.INK, 0.45), 8, 0, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", UITheme.rounded(UITheme.YELLOW, 8, 0, Color.TRANSPARENT, 0))
	add_child(bar)
	if Game.debug_race:
		set_process(false)
		return # DebugRunner loads the race directly


## The splash picture fitted like the engine boot splash (keep aspect, centred).
static func splash_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(SPLASH)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _process(delta: float) -> void:
	_time += delta
	if _done:
		return
	var path: String = Game.SCENES[Game.State.MAIN_MENU]
	if not _requested:
		_requested = true
		ResourceLoader.load_threaded_request(path, "PackedScene", true)
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	if progress.size() > 0:
		bar.value = maxf(bar.value, float(progress[0]))
	if status == ResourceLoader.THREAD_LOAD_LOADED and _time >= MIN_TIME:
		_done = true
		bar.value = 1.0
		Game.leave_splash(ResourceLoader.load_threaded_get(path))
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		push_error("Boot: main menu failed to load")
		Game.goto(Game.State.MAIN_MENU)
