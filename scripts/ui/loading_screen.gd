extends Control
## Loading screen with honest progress. Stages:
##   0.00–0.10  race scene file (threaded load progress)
##   0.10–0.94  world build, one step per frame (RaceManager.build_world_staged)
##   0.94–1.00  warm-up: a few frames rendered from the race camera under this
##              screen, so shader compilation happens here and not as a stall
##              on the first race frame
## The bar eases toward the real value every frame and the racer keeps
## bouncing, so the screen never looks frozen between steps.

const FILE_SHARE := 0.10
const BUILD_SHARE := 0.84
const WARMUP_FRAMES := 4

var bar: ProgressBar
var stage_label: Label
var _target := 0.0
var _time := 0.0
var _icon: Control
var _phase := 0 # 0 request, 1 file loading, 2 building, 3 warm-up, 4 done
var _race: RaceManager
var _warm := 0
var _layer: CanvasLayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Above the race scene being built behind it (its HUD stays hidden anyway).
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(screen)
	screen.add_child(UITheme.pattern_backdrop())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.custom_minimum_size = Vector2(720, 0)
	center.add_child(v)
	# The chosen racer bounces happily while the track loads.
	_icon = RacerIcon.new()
	_icon.def = RacerRoster.get_def(String(Game.race_config.get("kart_id", SaveManager.get_selected_kart())))
	_icon.custom_minimum_size = Vector2(0, 150)
	v.add_child(_icon)
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
	bar.max_value = 1.0
	bar.add_theme_stylebox_override("background", UITheme.rounded(Color(UITheme.INK, 0.55), 16, 3, UITheme.INK, 0))
	bar.add_theme_stylebox_override("fill", UITheme.rounded(UITheme.YELLOW, 14, 3, UITheme.ORANGE, 0))
	v.add_child(bar)
	stage_label = Label.new()
	stage_label.text = tr("LOAD_STAGE_FILES")
	stage_label.theme_type_variation = &"Dim"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stage_label)
	AudioManager.stop_music(0.5)


func _track_name_key() -> String:
	if Game.race_config.get("mode", "") == "tutorial":
		return "MODE_TUTORIAL"
	return "TRACK_SEAFRONT"


## Build step name → player-facing stage text.
static func stage_key(step: String) -> String:
	if step.begins_with("track"):
		return "LOAD_STAGE_TRACK"
	if step.begins_with("decor"):
		return "LOAD_STAGE_CITY"
	if step == "racers":
		return "LOAD_STAGE_RACERS"
	return "LOAD_STAGE_FILES"


func _process(delta: float) -> void:
	_time += delta
	if _icon:
		_icon.pivot_offset = _icon.size * 0.5
		_icon.scale = Vector2.ONE * (1.0 + absf(sin(_time * 5.0)) * 0.06)
	# Ease toward the real value; never past it, never backwards.
	bar.value = minf(_target, bar.value + maxf((_target - bar.value) * (1.0 - exp(-10.0 * delta)), 0.0))
	match _phase:
		0:
			_phase = 1
			ResourceLoader.load_threaded_request(Game.RACE_SCENE, "PackedScene", true)
		1:
			var progress := []
			var status := ResourceLoader.load_threaded_get_status(Game.RACE_SCENE, progress)
			if progress.size() > 0:
				_target = maxf(_target, float(progress[0]) * FILE_SHARE)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_phase = 2
				_target = FILE_SHARE
				_start_build(ResourceLoader.load_threaded_get(Game.RACE_SCENE))
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Loading: race scene failed to load")
				_phase = 4
				Game.goto(Game.State.MAIN_MENU)
		3:
			# Frames rendered from the race camera compile its shaders here.
			_warm += 1
			_target = FILE_SHARE + BUILD_SHARE + (1.0 - FILE_SHARE - BUILD_SHARE) * float(_warm) / WARMUP_FRAMES
			if _warm >= WARMUP_FRAMES:
				_phase = 4
				_target = 1.0
				bar.value = 1.0
				Game.adopt_race(_race, self)


func _start_build(scene: PackedScene) -> void:
	_race = scene.instantiate() as RaceManager
	_race.staged_build = true
	get_tree().root.add_child(_race)
	await _race.build_world_staged(func(f: float, step: String):
		_target = FILE_SHARE + BUILD_SHARE * f
		stage_label.text = tr(stage_key(step)))
	stage_label.text = tr("LOAD_STAGE_READY")
	if DebugRunner.parse_args().has("stats"):
		print("LOAD_TIMINGS ", _race.build_timings)
	_phase = 3


## Fades out over the first race frames (called by Game.adopt_race).
func dissolve() -> void:
	set_process(false)
	var root_ctl: Control = _layer.get_child(0)
	var tw := create_tween()
	tw.tween_property(root_ctl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
