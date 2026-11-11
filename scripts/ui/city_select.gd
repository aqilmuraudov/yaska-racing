extends MenuScreen
## 0.11.1 "Şəhəri seç": the normal Yarış / Rekord flow asks for the city
## first. Big picture cards (render of the track, name, lap length, best
## lap, city trophies, a mini map); "Yeni!" on a city never raced. One tap
## picks the city and goes on to kart select. The last city is pre-selected
## and stays in sync with Race Setup (Settings gameplay.track).
## 0.20.0 (owner 2026-11-11): two steps - "Şəhəri seç" shows the cities (Bakı,
## Qarabağ; TrackList.REGIONS), a tap opens "Xəritəni seç" with that city's
## maps; Geri / Esc goes back to the cities.

const TrackPreview := preload("res://scripts/ui/track_select.gd").TrackPreview

var cards := {} ## track id -> Button, maps of the open city (tests)
var region_cards := {} ## region -> Button (tests)
var region := "" ## open city, "" = the city step
var row: HBoxContainer
var new_badges := {} ## id -> Control
var selected := ""
## 0.15.2 (owner): the time of day is picked here, every time, with three big
## buttons under the cities (was only in Race setup).
const TOD_BAR_H := 96.0
var tod_buttons := {} ## id -> Button (tests)


func _init() -> void:
	back_state = Game.State.MODE_SELECT
	screen_title_key = "CITY_TITLE"


func build() -> void:
	if stage and stage.turntable:
		stage.turntable.visible = false
		stage.auto_rotate = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.BLUE_DEEP, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	root.move_child(dim, 0)
	selected = TrackList.valid(String(Settings.get_value("gameplay", "track", "")))
	Game.race_config.track_id = selected
	row = HBoxContainer.new()
	row.name = "Cities"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -TOD_BAR_H - 10.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UITheme.GAP_L + 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(row)
	_build_tod_bar()
	body.resized.connect(_fit)
	show_regions()


## Step 1: the cities.
func show_regions() -> void:
	region = ""
	_clear_row()
	for r in TrackList.REGIONS:
		var b := _make_region_card(String(r))
		row.add_child(b)
		region_cards[r] = b
	if title_label:
		title_label.text = tr("CITY_TITLE")
	_highlight_region(TrackList.region_of(selected))
	_fit.call_deferred()


## Step 2: the maps of one city.
func open_region(r: String) -> void:
	region = r if r in TrackList.REGIONS else String(TrackList.REGIONS[0])
	_clear_row()
	for id in TrackList.region_tracks(region):
		var b := _make_card(String(id))
		row.add_child(b)
		cards[id] = b
	if title_label:
		title_label.text = "%s · %s" % [tr(TrackList.region_key(region)), tr("MAP_TITLE")]
	if not cards.has(selected):
		selected = String(TrackList.region_tracks(region)[0])
	_style_selected()
	_fit.call_deferred()
	var f := first_focus()
	if f and is_inside_tree():
		f.grab_focus.call_deferred()


func _clear_row() -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	cards.clear()
	region_cards.clear()
	new_badges.clear()


func _fit() -> void:
	var avail := body.size
	if avail.x <= 0.0 or row == null:
		return
	var btns := row.get_children()
	if btns.is_empty():
		return
	var gap := float(row.get_theme_constant("separation"))
	# 0.20.0: 1-3 cards per step; a single map card stays a sensible size.
	var n := maxf(float(btns.size()), 2.0)
	var w := clampf((avail.x - gap * (n - 1.0) - 24.0) / n, 250.0, 600.0)
	var h := clampf(avail.y - TOD_BAR_H - 22.0, 280.0, w * 1.02)
	for c: Control in btns:
		c.custom_minimum_size = Vector2(w, h)
		var pic: Control = c.find_child("Pic", true, false)
		pic.custom_minimum_size = Vector2(0, clampf(h * 0.6, 150.0, w * 0.78))


## Back from the maps goes to the cities, from the cities to the mode menu.
func go_back() -> void:
	if region != "":
		AudioManager.play_ui("ui_back")
		show_regions()
		var f := first_focus()
		if f:
			f.grab_focus.call_deferred()
		return
	super.go_back()


func _make_region_card(r: String) -> Button:
	var data := SaveManager.data
	var ids: Array = TrackList.region_tracks(r)
	var b := Button.new()
	b.name = "Region_" + r
	b.focus_mode = Control.FOCUS_ALL
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 10)
	b.add_child(v)
	# Picture: the city's maps side by side (one map fills the picture).
	var pic := HBoxContainer.new()
	pic.name = "Pic"
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_theme_constant_override("separation", 4)
	pic.custom_minimum_size = Vector2(0, 260)
	v.add_child(pic)
	for id in ids:
		var img := TextureRect.new()
		img.name = "Image" if pic.get_child_count() == 0 else "Image_" + String(id)
		img.texture = CityCards.thumb(String(id))
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(img)
	var fresh := false
	for id in ids:
		fresh = fresh or CityCards.is_new(data, String(id))
	if fresh:
		var nb := GameUI.badge(tr("CITY_NEW"), UITheme.POMEGRANATE, 30, Color.WHITE)
		nb.name = "NewBadge"
		nb.top_level = false
		b.add_child(nb)
		nb.position = Vector2(26, 28)
		nb.rotation = deg_to_rad(-8.0)
		new_badges[r] = nb
	var t := GameUI.label(tr(TrackList.region_key(r)), UITheme.FS_H1 + 8, UITheme.GOLD, 10)
	t.name = "Name"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chips)
	var maps_text := tr("REGION_MAP_ONE") if ids.size() == 1 else tr("REGION_MAPS") % ids.size()
	var c1 := GameUI.chip("lap_flag", maps_text, 24, Color(UITheme.INK, 0.72), Color.WHITE)
	c1.name = "Maps"
	chips.add_child(c1)
	var tro := Vector2i.ZERO
	for id in ids:
		tro += CityCards.trophies(data, String(id))
	var c3 := GameUI.chip("trophy", "%d/%d" % [tro.x, tro.y], 24, Color(UITheme.INK, 0.72), UITheme.YELLOW)
	c3.name = "Trophies"
	chips.add_child(c3)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var go := GameUI.chip("play", tr("REGION_OPEN"), 30, UITheme.LIME.darkened(0.15), Color.WHITE)
	go.name = "Go"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_confirm")
		open_region(r))
	b.focus_entered.connect(func():
		AudioManager.play_ui("ui_move")
		_highlight_region(r))
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		create_tween().tween_property(b, "scale", Vector2.ONE * 0.95, 0.06))
	b.button_up.connect(func():
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


func _highlight_region(r: String) -> void:
	for k in region_cards:
		var c: Button = region_cards[k]
		var sel: bool = k == r
		var sb := UITheme.art_box("panel_card_selected" if sel else "panel_card", 26, 18)
		for st in ["normal", "hover", "focus", "pressed"]:
			c.add_theme_stylebox_override(st, sb if st != "pressed" else UITheme.art_box("panel_card_selected", 26, 18))
		c.find_child("Go", true, false).modulate = Color.WHITE if sel else Color(0.9, 0.9, 0.9)


func _make_card(id: String) -> Button:
	var data := SaveManager.data
	var b := Button.new()
	b.name = "City_" + id
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = false
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 10)
	b.add_child(v)
	# Picture with the mini map in a corner.
	var pic := Control.new()
	pic.name = "Pic"
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.custom_minimum_size = Vector2(0, 260)
	v.add_child(pic)
	var img := TextureRect.new()
	img.name = "Image"
	img.texture = CityCards.thumb(id)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(img)
	var map_bg := PanelContainer.new()
	map_bg.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.INK, 0.62), 16, 3, Color(1, 1, 1, 0.5), 0))
	map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_bg.anchor_left = 1.0
	map_bg.anchor_right = 1.0
	map_bg.anchor_top = 1.0
	map_bg.anchor_bottom = 1.0
	map_bg.offset_left = -150
	map_bg.offset_top = -104
	map_bg.offset_right = -8
	map_bg.offset_bottom = -8
	pic.add_child(map_bg)
	var mm := TrackPreview.new()
	mm.name = "MiniMap"
	mm.track = CityCards.track_data(id)
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_bg.add_child(mm)
	if CityCards.is_new(data, id):
		var nb := GameUI.badge(tr("CITY_NEW"), UITheme.POMEGRANATE, 30, Color.WHITE)
		nb.name = "NewBadge"
		nb.position = Vector2(10, 12)
		nb.rotation = deg_to_rad(-8.0)
		pic.add_child(nb)
		new_badges[id] = nb
		var tw := nb.create_tween().set_loops()
		nb.pivot_offset = Vector2(50, 22)
		tw.tween_property(nb, "scale", Vector2.ONE * 1.1, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(nb, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	# Name
	var t := GameUI.label(tr(TrackList.city_key(id)), UITheme.FS_H1 + 4, UITheme.GOLD, 10)
	t.name = "Name"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	# Chips: lap length, best lap, trophies.
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chips)
	var c1 := GameUI.chip("lap_flag", CityCards.length_text(id), 22, Color(UITheme.INK, 0.72), Color.WHITE)
	c1.name = "Length"
	chips.add_child(c1)
	var best := CityCards.best_lap_text(data, id)
	var c2 := GameUI.chip("mode_time", best if best != "" else "—", 22, Color(UITheme.INK, 0.72), Color("9ff3ff"))
	c2.name = "Best"
	chips.add_child(c2)
	var tro := CityCards.trophies(data, id)
	var c3 := GameUI.chip("trophy", "%d/%d" % [tro.x, tro.y], 22, Color(UITheme.INK, 0.72), UITheme.YELLOW)
	c3.name = "Trophies"
	chips.add_child(c3)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var go := GameUI.chip("play", tr("CITY_GO"), 30, UITheme.LIME.darkened(0.15), Color.WHITE)
	go.name = "Go"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	b.pressed.connect(func(): choose(id))
	b.focus_entered.connect(func():
		AudioManager.play_ui("ui_move")
		_highlight(id))
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		create_tween().tween_property(b, "scale", Vector2.ONE * 0.95, 0.06))
	b.button_up.connect(func():
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


func _build_tod_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TimeOfDay"
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -TOD_BAR_H
	bar.offset_bottom = 0.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	body.add_child(bar)
	for id in TimeOfDay.IDS:
		var b := Button.new()
		b.name = "Tod_" + id
		b.text = tr(TimeOfDay.NAME_KEYS[id])
		b.icon = UITheme.icon(TimeOfDay.ICONS[id])
		b.add_theme_constant_override("icon_max_width", 56)
		b.custom_minimum_size = Vector2(250, TOD_BAR_H)
		b.focus_mode = Control.FOCUS_ALL
		var tid: String = id
		b.pressed.connect(func(): pick_tod(tid))
		bar.add_child(b)
		tod_buttons[id] = b
	_style_tod()


func pick_tod(id: String) -> void:
	Settings.set_value("gameplay", "time_of_day", TimeOfDay.valid(id))
	Game.race_config.time_of_day = TimeOfDay.valid(id)
	AudioManager.play_ui("ui_move")
	_style_tod()
	UITheme.bounce(tod_buttons[TimeOfDay.valid(id)])


func _style_tod() -> void:
	var cur := TimeOfDay.selected()
	for id in tod_buttons:
		UITheme.style_button(tod_buttons[id], "yellow" if id == cur else "blue", UITheme.FS_BTN_PRIMARY)


## Picks the city, remembers it and starts the race with the garage kart.
func choose(id: String, go := true) -> void:
	selected = TrackList.valid(id)
	Settings.set_value("gameplay", "track", selected)
	Game.race_config.track_id = selected
	Game.race_config.time_of_day = TimeOfDay.selected()
	AudioManager.play_ui("ui_confirm")
	_style_selected()
	if go:
		Game.start_race_with_selected()


func _highlight(id: String) -> void:
	for k in cards:
		var c: Button = cards[k]
		var sel: bool = k == id
		var sb := UITheme.art_box("panel_card_selected" if sel else "panel_card", 26, 18)
		for st in ["normal", "hover", "focus", "pressed"]:
			c.add_theme_stylebox_override(st, sb if st != "pressed" else UITheme.art_box("panel_card_selected", 26, 18))
		c.find_child("Go", true, false).modulate = Color.WHITE if sel else Color(0.9, 0.9, 0.9)
		c.find_child("Image", true, false).modulate = Color.WHITE if sel else Color(0.9, 0.91, 0.95)


func _style_selected() -> void:
	_highlight(selected)


func first_focus() -> Control:
	if region == "":
		return region_cards.get(TrackList.region_of(selected))
	return cards.get(selected)
