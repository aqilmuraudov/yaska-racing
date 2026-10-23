class_name PauseMenu
extends Control
## Pause overlay: Resume / Restart / Settings / Quit. Works while the tree is
## paused and is fully navigable with keyboard, controller and touch.

var race: RaceManager
var panel: PanelContainer
var resume_btn: Button
var settings_overlay: Node


func setup(p_race: RaceManager) -> void:
	race = p_race
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := Label.new()
	title.name = "Title"
	title.text = tr("PAUSE_TITLE")
	title.theme_type_variation = &"Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	resume_btn = _btn(v, "PAUSE_RESUME", func(): race.set_paused(false), "yellow", "play")
	resume_btn.custom_minimum_size = Vector2(0, 84)
	_btn(v, "PAUSE_RESTART", func():
		open(false)
		race.restart(), "blue", "restore")
	_btn(v, "PAUSE_SETTINGS", _open_settings, "blue", "gear")
	_btn(v, "PAUSE_QUIT", func(): race.quit_to_menu(), "coral", "back")
	# Language can change inside the Settings overlay: relabel at once.
	Settings.changed.connect(func(section, key):
		if section == "gameplay" and key == "language" and is_instance_valid(title):
			title.text = tr("PAUSE_TITLE")
			for b in v.get_children():
				if b is Button and b.has_meta("key"):
					b.text = tr(b.get_meta("key")))


func _btn(parent: Control, key: String, cb: Callable, color := "blue", icon_name := "") -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.set_meta("key", key)
	b.custom_minimum_size = Vector2(0, 70)
	UITheme.style_button(b, color, 30 if color == "yellow" else 26)
	if icon_name != "":
		b.icon = UITheme.icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_confirm")
		cb.call())
	parent.add_child(b)
	return b


func open(on: bool) -> void:
	visible = on
	if on:
		AudioManager.play_ui("ui_open")
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2.ONE * 0.9
		panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		resume_btn.call_deferred("grab_focus")
	elif settings_overlay:
		settings_overlay.queue_free()
		settings_overlay = null


func _open_settings() -> void:
	var scene: PackedScene = load("res://scenes/menus/settings_menu.tscn")
	settings_overlay = scene.instantiate()
	settings_overlay.set("overlay_mode", true)
	settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_overlay)
	panel.visible = false
	settings_overlay.tree_exited.connect(func():
		settings_overlay = null
		if is_inside_tree():
			panel.visible = true
			resume_btn.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if not visible or settings_overlay != null:
		return
	if event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed("ui_cancel"):
		race.set_paused(false)
		get_viewport().set_input_as_handled()
