extends Node
## Top-level flow: Boot → Main Menu → Mode → Kart → Track → Loading → Race.
## Owns the race configuration handed to the race scene.

signal state_changed(new_state: State)

enum State { BOOT, MAIN_MENU, MODE_SELECT, KART_SELECT, TRACK_SELECT, LOADING, RACE, SETTINGS, CREDITS }

const SCENES := {
	State.MAIN_MENU: "res://scenes/menus/main_menu.tscn",
	State.MODE_SELECT: "res://scenes/menus/mode_select.tscn",
	State.KART_SELECT: "res://scenes/menus/racer_select.tscn", # animal + kart package
	State.TRACK_SELECT: "res://scenes/menus/track_select.tscn",
	State.LOADING: "res://scenes/menus/loading.tscn",
	State.SETTINGS: "res://scenes/menus/settings_menu.tscn",
	State.CREDITS: "res://scenes/menus/credits.tscn",
}
const RACE_SCENE := "res://scenes/race/race.tscn"

var state: State = State.BOOT
var race_config: Dictionary = {}
var _fade: ColorRect
var _fade_layer: CanvasLayer
var _changing := false
var debug_race := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.07, 0.12, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)
	race_config = default_race_config()
	# Controls under CanvasLayers do not inherit the Window theme, so the UI
	# theme is merged into the default theme every Control falls back to.
	var ui_theme := UITheme.build()
	ThemeDB.get_default_theme().merge_with(ui_theme)
	ThemeDB.get_default_theme().default_font = UITheme.body_font()
	get_tree().root.theme = ui_theme
	var dbg := DebugRunner.parse_args()
	if not dbg.is_empty():
		debug_race = dbg.has("race")
		var runner := DebugRunner.new()
		runner.name = "DebugRunner"
		add_child(runner)


func default_race_config() -> Dictionary:
	return {
		"mode": "quick",
		"track_id": "seafront_sprint",
		"kart_id": SaveManager.get_selected_kart() if SaveManager.data.size() > 0 else RacerRoster.DEFAULT_ID,
		"paint": 0,
		"difficulty": Settings.get_value("gameplay", "difficulty", "medium"),
		"laps": 3,
		"ai_count": 5,
		"items": true,
		"seed": 0,
		"debug_autopilot": false,
	}


func goto(new_state: State) -> void:
	if _changing:
		return
	var path: String = SCENES.get(new_state, "")
	if path.is_empty():
		push_error("Game.goto: no scene for state %s" % new_state)
		return
	_change_scene(path, new_state)


func start_loading_race() -> void:
	race_config.event_instance_id = _make_instance_id()
	if int(race_config.seed) == 0:
		race_config.active_seed = randi()
	else:
		race_config.active_seed = int(race_config.seed)
	goto(State.LOADING)


## Called by the loading screen once the race scene resource is available.
func enter_race(scene: PackedScene) -> void:
	state = State.RACE
	get_tree().paused = false
	get_tree().change_scene_to_packed(scene)
	state_changed.emit(state)


## Called by the loading screen after a staged build: the race (already in the
## tree behind the loading screen) becomes the current scene and starts, while
## the loading screen dissolves over its first frames.
func adopt_race(race: Node, loading: Node) -> void:
	state = State.RACE
	get_tree().paused = false
	get_tree().current_scene = race
	race.begin()
	state_changed.emit(state)
	loading.dissolve()


func restart_race() -> void:
	# Fresh event id so a restarted race is a new reward event.
	start_loading_race()


func quit_game() -> void:
	SaveManager.save_profile()
	get_tree().quit()


func _change_scene(path: String, new_state: State) -> void:
	_changing = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.15)
	await tw.finished
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Game: failed to change scene to %s (%s)" % [path, error_string(err)])
	state = new_state
	state_changed.emit(state)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.2)
	await tw2.finished
	_changing = false


## Boot hand-over: the splash stays on top (same picture, same colour) while
## the main menu builds its 3D stage and renders its first frames, then
## dissolves into it. Startup is one continuous picture: no black frame, no
## second title card, no fade through dark.
func leave_splash(scene: PackedScene) -> void:
	_changing = true
	var cover := ColorRect.new()
	cover.color = UITheme.BLUE_DEEP
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/splash/splash.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(pic)
	_fade_layer.add_child(cover)
	get_tree().change_scene_to_packed(scene)
	state = State.MAIN_MENU
	state_changed.emit(state)
	# A few rendered frames: the menu stage shaders compile under the cover.
	for i in 3:
		await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(cover, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	cover.queue_free()
	_changing = false


func fade_in_from_black() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _make_instance_id() -> String:
	return "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# Android may kill a backgrounded process without further notice.
			SaveManager.save_profile()
			Settings.save_settings()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_request()


## Android back button: pause a race, navigate back in menus, and only
## leave the app from the main menu.
func _on_back_request() -> void:
	var scene := get_tree().current_scene
	if scene is RaceManager:
		var race := scene as RaceManager
		if not race.paused:
			race.set_paused(true)
		elif race.hud and race.hud.pause_menu.settings_overlay:
			race.hud.pause_menu.settings_overlay.go_back()
		else:
			race.set_paused(false)
	elif state == State.MAIN_MENU:
		quit_game()
	elif scene != null and scene.has_method("go_back"):
		scene.go_back()
