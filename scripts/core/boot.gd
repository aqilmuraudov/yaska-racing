extends Control
## First scene: shows the title card briefly, then hands over to the menu.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.NAVY_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = tr("GAME_TITLE")
	title.theme_type_variation = &"Title"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(title)
	if Game.debug_race:
		return # DebugRunner loads the race directly
	await get_tree().create_timer(0.6).timeout
	Game.goto(Game.State.MAIN_MENU)
