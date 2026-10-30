extends MenuScreen
## Bakı Kuboku standings and podium (0.10.0).
##
## Between races: the points table animates from the old totals to the new
## ones (bars grow, "+10" pops, rows slide to their new places) and a card
## shows what the next race changes, with one big start button.
## After race 3: a trophy, a three-step podium and the prize.

const ROW_H := 62.0
const ROW_GAP := 6.0

var cup: Dictionary = {}
var rows := {} ## racer id -> row Control
var bars := {} ## racer id -> ProgressBar
var pts_labels := {} ## racer id -> Label
var place_labels := {} ## racer id -> Label
var table: Control
var start_btn: Button
var reset_btn: Button
var podium_box: Control
var prize_chip: PanelContainer
var view := "" ## "standings" | "podium"
var _reset_armed := false
var _anim: Tween


func _init() -> void:
	back_state = Game.State.MODE_SELECT
	screen_title_key = "MODE_CUP"


func build() -> void:
	if stage and stage.turntable:
		stage.turntable.visible = false
		stage.auto_rotate = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.BLUE_DEEP, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	root.move_child(dim, 0)
	cup = BakuCup.current(SaveManager.data)
	if cup.is_empty():
		Game.goto.call_deferred(Game.State.MODE_SELECT)
		return
	if BakuCup.is_complete(cup):
		_build_podium()
	else:
		_build_standings()


static func racer_name(id: String, is_player: bool) -> String:
	var n := RacerRoster.get_def(id).display_name
	return "%s %s" % [n, TranslationServer.translate("RACER_YOU_SUFFIX")] if is_player else n


# --- Standings -----------------------------------------------------------------

func _build_standings() -> void:
	view = "standings"
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", UITheme.GAP_L)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	# Left: the points table
	var left := GameUI.card()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	var done := int(cup.race)
	var head := GameUI.label(tr("CUP_STANDINGS_AFTER") % [done, BakuCup.RACES] if done > 0 else tr("CUP_STANDINGS_START"), 28, UITheme.YELLOW, 8)
	lv.add_child(head)
	table = Control.new()
	table.custom_minimum_size = Vector2(0, (ROW_H + ROW_GAP) * (BakuCup.OPPONENTS + 1))
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_child(table)
	var prev := BakuCup.standings(cup, true)
	var now := BakuCup.standings(cup)
	var max_pts := float(BakuCup.POINTS[0] * BakuCup.RACES)
	var gained := {}
	for r in cup.get("last", []):
		gained[String(r.id)] = int(r.points)
	for r in prev:
		var id := String(r.id)
		var row := _row(id, bool(r.is_player), int(r.place), int(r.points), max_pts)
		row.position = Vector2(0, (int(r.place) - 1) * (ROW_H + ROW_GAP))
		table.add_child(row)
		rows[id] = row
	table.resized.connect(func():
		for id in rows:
			rows[id].size.x = table.size.x)
	# Right: next race card
	var right := GameUI.card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", UITheme.GAP_M)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(rv)
	var steps := HBoxContainer.new()
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 10)
	rv.add_child(steps)
	for i in BakuCup.RACES:
		var dot := GameUI.badge(str(i + 1), UITheme.LIME if i < done else (UITheme.YELLOW if i == done else Color(UITheme.INK, 0.6)), 26,
			UITheme.NAVY_DEEP if i <= done else UITheme.TEXT)
		dot.custom_minimum_size = Vector2(54, 46)
		steps.add_child(dot)
	var title := GameUI.label(tr("CUP_NEXT_RACE") % [done + 1, BakuCup.RACES] if done < BakuCup.RACES - 1 else tr("CUP_FINAL_RACE"), 34, UITheme.TEXT, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(title)
	var icons := ["mode_quick", "play", "star", "tod_sunset"]
	var texts := BakuCup.stage_text(done)
	for i in texts.size():
		var chip := GameUI.chip(icons[i], String(texts[i]), 22, Color(UITheme.INK, 0.6), UITheme.TEXT)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rv.add_child(chip)
	var you := GameUI.label(tr("CUP_YOU_PLACE") % BakuCup.player_place(cup), 22, UITheme.YELLOW, 6, false)
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you.visible = done > 0
	rv.add_child(you)
	start_btn = make_button(tr("CUP_START_RACE"), _start_next, true)
	start_btn.name = "StartRace"
	start_btn.icon = UITheme.icon("play")
	start_btn.expand_icon = false
	start_btn.add_theme_constant_override("icon_max_width", 34)
	start_btn.custom_minimum_size = Vector2(0, UITheme.H_PRIMARY)
	rv.add_child(start_btn)
	reset_btn = make_button(tr("CUP_RESET"), _on_reset)
	reset_btn.name = "ResetCup"
	UITheme.style_button(reset_btn, "coral", UITheme.FS_BTN_SMALL)
	reset_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN_SMALL)
	rv.add_child(reset_btn)
	_animate(prev, now, gained)


func _row(id: String, is_player: bool, place: int, points: int, max_pts: float) -> Control:
	var p := PanelContainer.new()
	var bg := Color(UITheme.YELLOW, 0.28) if is_player else Color(UITheme.INK, 0.5)
	p.add_theme_stylebox_override("panel", UITheme.rounded(bg, 18, 3 if is_player else 0, UITheme.YELLOW, 6))
	p.size = Vector2(maxf(table.size.x, 400.0), ROW_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	var pl := GameUI.label(str(place), 30, GameUI.medal_color(place) if place <= 3 else UITheme.TEXT, 8)
	pl.custom_minimum_size = Vector2(36, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(pl)
	place_labels[id] = pl
	hb.add_child(GameUI.portrait(id, 50, UITheme.YELLOW if is_player else Color.WHITE))
	var nm := GameUI.label(racer_name(id, is_player), 24, UITheme.TEXT, 6)
	nm.custom_minimum_size = Vector2(150, 0)
	nm.clip_text = true
	hb.add_child(nm)
	var bar := GameUI.bar(points, max_pts, UITheme.YELLOW if is_player else UITheme.TURQUOISE, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(bar)
	bars[id] = bar
	var pts := GameUI.label(str(points), 30, UITheme.TEXT, 8)
	pts.custom_minimum_size = Vector2(52, 0)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(pts)
	pts_labels[id] = pts
	var gain := GameUI.badge("", Color(UITheme.LIME, 0.95), 20, UITheme.NAVY_DEEP)
	gain.name = "Gain"
	gain.custom_minimum_size = Vector2(56, 0)
	gain.modulate.a = 0.0
	hb.add_child(gain)
	p.set_meta("gain", gain)
	return p


## Old totals → new totals, then the rows slide to their new places.
func _animate(prev: Array, now: Array, gained: Dictionary) -> void:
	_anim = create_tween()
	_anim.tween_interval(0.45)
	_anim.set_parallel(true)
	for r in now:
		var id := String(r.id)
		var g := int(gained.get(id, 0))
		var bar: ProgressBar = bars[id]
		_anim.tween_property(bar, "value", float(r.points), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var lbl: Label = pts_labels[id]
		var from := int(r.points) - g
		_anim.tween_method(func(v: float): lbl.text = str(int(round(v))), float(from), float(r.points), 0.8)
		var gain: PanelContainer = rows[id].get_meta("gain")
		gain.get_meta("value").text = "+%d" % g
		if g > 0:
			_anim.tween_property(gain, "modulate:a", 1.0, 0.25)
	_anim.set_parallel(false)
	_anim.tween_interval(0.25)
	_anim.set_parallel(true)
	for r in now:
		var id := String(r.id)
		_anim.tween_property(rows[id], "position:y", (int(r.place) - 1) * (ROW_H + ROW_GAP), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.set_parallel(false)
	_anim.tween_callback(func():
		for r in now:
			var pl: Label = place_labels[String(r.id)]
			pl.text = str(r.place)
			pl.add_theme_color_override("font_color", GameUI.medal_color(int(r.place)) if int(r.place) <= 3 else UITheme.TEXT)
		if is_instance_valid(rows.get(String(cup.kart_id))):
			UITheme.bounce(rows[String(cup.kart_id)], 0.04))


## Jumps to the end state of the animation (tests, screenshots).
func finish_animation() -> void:
	if _anim and _anim.is_valid():
		_anim.custom_step(10.0)


func _start_next() -> void:
	AudioManager.play_ui("ui_confirm")
	BakuCup.apply_config(Game.race_config, cup)
	Game.race_config.paint = SaveManager.get_paint(String(cup.kart_id))
	Game.start_loading_race()


func _on_reset() -> void:
	if not _reset_armed:
		# Second tap confirms; the button says so.
		_reset_armed = true
		reset_btn.text = tr("CUP_RESET_CONFIRM")
		AudioManager.play_ui("ui_move")
		return
	AudioManager.play_ui("ui_back")
	BakuCup.close(SaveManager.data)
	SaveManager.save_profile()
	Game.goto(Game.State.MODE_SELECT)


# --- Podium -------------------------------------------------------------------

func _build_podium() -> void:
	view = "podium"
	var st := BakuCup.standings(cup)
	var place := int(cup.get("final_place", BakuCup.player_place(cup)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", UITheme.GAP_L + 10)
	body.add_child(h)
	# Centre: trophy + podium
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 6)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.size_flags_stretch_ratio = 1.6
	h.add_child(cv)
	var trophy := GameUI.icon_rect("trophy", 168)
	trophy.name = "Trophy"
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(trophy)
	var msg := GameUI.label(tr("CUP_WIN") if place == 1 else tr("CUP_DONE_PLACE") % ResultsScreen.place_text(place), 40,
		GameUI.medal_color(place) if place <= 3 else UITheme.TEXT, 10)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(msg)
	podium_box = HBoxContainer.new()
	podium_box.alignment = BoxContainer.ALIGNMENT_CENTER
	podium_box.add_theme_constant_override("separation", 10)
	cv.add_child(podium_box)
	var heights := {1: 150.0, 2: 108.0, 3: 76.0}
	for p in [2, 1, 3]:
		if p > st.size():
			continue
		var r: Dictionary = st[p - 1]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", 4)
		col.custom_minimum_size = Vector2(170, 0)
		podium_box.add_child(col)
		var por := GameUI.portrait(String(r.id), 84.0 if p == 1 else 70.0, UITheme.YELLOW if r.is_player else Color.WHITE)
		por.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(por)
		var nm := GameUI.label(racer_name(String(r.id), bool(r.is_player)), 21, UITheme.YELLOW if r.is_player else UITheme.TEXT, 6)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		var block := PanelContainer.new()
		block.custom_minimum_size = Vector2(160, heights[p])
		block.add_theme_stylebox_override("panel", UITheme.rounded(GameUI.medal_color(p).darkened(0.1), 14, 4, UITheme.INK, 6))
		col.add_child(block)
		var bv := VBoxContainer.new()
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		block.add_child(bv)
		var medal := GameUI.medal(p, 54)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(medal)
		var pts := GameUI.label(tr("CUP_POINTS") % int(r.points), 22, UITheme.NAVY_DEEP, 0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(pts)
	# Right: prize + the rest + buttons
	var right := GameUI.card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", UITheme.GAP_M)
	right.add_child(rv)
	var ph := GameUI.label(tr("CUP_PRIZE"), 26, UITheme.TEXT_DIM, 6)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(ph)
	prize_chip = GameUI.money_chip(int(cup.get("prize", 0)), 40)
	prize_chip.name = "Prize"
	prize_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rv.add_child(prize_chip)
	for i in range(3, st.size()):
		var r: Dictionary = st[i]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		rv.add_child(line)
		line.add_child(GameUI.label(str(r.place), 22, UITheme.TEXT, 6))
		line.add_child(GameUI.portrait(String(r.id), 36))
		var n := GameUI.label(racer_name(String(r.id), bool(r.is_player)), 20, UITheme.YELLOW if r.is_player else UITheme.TEXT, 6)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(n)
		line.add_child(GameUI.label(str(r.points), 22, UITheme.TEXT, 6))
	var again := make_button(tr("CUP_NEW"), _new_cup, true)
	again.name = "NewCup"
	again.icon = UITheme.icon("trophy")
	again.expand_icon = false
	again.add_theme_constant_override("icon_max_width", 34)
	again.custom_minimum_size = Vector2(0, UITheme.H_PRIMARY)
	rv.add_child(again)
	var menu := make_button(tr("RESULTS_MENU"), _to_menu)
	menu.name = "Menu"
	UITheme.style_button(menu, "blue", UITheme.FS_BTN)
	menu.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	rv.add_child(menu)
	start_btn = again
	# Trophy pop + sparkles
	trophy.pivot_offset = Vector2(84, 84)
	trophy.scale = Vector2.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(trophy, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): UITheme.sparkle_burst(trophy, trophy.get_global_rect().get_center(), 12, UITheme.YELLOW))
	_anim = tw


func _new_cup() -> void:
	AudioManager.play_ui("ui_confirm")
	BakuCup.close(SaveManager.data)
	SaveManager.save_profile()
	Game.reset_series()
	Game.race_config.mode = "quick"
	Game.race_config.series = "cup_new"
	Game.goto(Game.State.KART_SELECT)


func _to_menu() -> void:
	AudioManager.play_ui("ui_back")
	BakuCup.close(SaveManager.data)
	SaveManager.save_profile()
	Game.goto(Game.State.MAIN_MENU)


func first_focus() -> Control:
	return start_btn
