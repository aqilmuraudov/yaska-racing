extends Control
## Loading screen: threaded load of the race scene with progress and tips.

var bar: ProgressBar
var _started := false
var _min_time := 0.6
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size = Vector2(720, 0)
	center.add_child(v)
	var title := Label.new()
	title.text = tr(_track_name_key())
	title.theme_type_variation = &"Heading"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var tip := Label.new()
	tip.text = tr("LOADING_TIP_%d" % (randi() % 5 + 1))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 26)
	v.add_child(tip)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(720, 28)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UITheme.rounded(Color(1, 1, 1, 0.1), 14, 0, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", UITheme.rounded(UITheme.TURQUOISE, 14, 0, Color.TRANSPARENT, 0))
	v.add_child(bar)
	var l := Label.new()
	l.text = tr("LOADING")
	l.theme_type_variation = &"Dim"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	AudioManager.stop_music(0.5)


func _track_name_key() -> String:
	if Game.race_config.get("mode", "") == "tutorial":
		return "MODE_TUTORIAL"
	return "TRACK_SEAFRONT"


func _process(delta: float) -> void:
	_time += delta
	if not _started:
		_started = true
		ResourceLoader.load_threaded_request(Game.RACE_SCENE, "PackedScene", true)
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(Game.RACE_SCENE, progress)
	if progress.size() > 0:
		bar.value = float(progress[0]) * 100.0 * 0.8
	if status == ResourceLoader.THREAD_LOAD_LOADED and _time >= _min_time:
		bar.value = 90.0
		var scene: PackedScene = ResourceLoader.load_threaded_get(Game.RACE_SCENE)
		set_process(false)
		# Track generation happens in the race scene's _ready.
		await get_tree().process_frame
		Game.enter_race(scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Loading: race scene failed to load")
		set_process(false)
		Game.goto(Game.State.MAIN_MENU)
