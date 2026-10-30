class_name RacerSelect
extends MenuScreen
## Racer selection: each animal and its kart are one package. Selecting a
## card updates the 3D preview (one model at a time), names, colour theme,
## five stat bars, speciality text and the handling used in the race.

## One readable colour per stat (bars also show a number, never colour-only).
const STAT_COLORS := [Color("ff5f6d"), Color("ff8a1f"), Color("17b9c9"), Color("8b5cf6"), Color("ffc21a")]
const STAT_KEYS := [["top_speed", "STAT_TOP"], ["acceleration", "STAT_ACCEL"], ["handling", "STAT_HANDLING"], ["drift", "STAT_DRIFT"], ["boost", "STAT_BOOST"]]

var defs: Array[RacerDefinition] = []
var current := 0
var cards: Array[Button] = []
var name_label: Label
var kart_label: Label
var pers_label: Label
var spec_label: Label
var stat_rows := {}
var start_btn: Button
var setup_btn: Button
var garage_btn: Button
var buy_btn: Button
var shop_dialog: Control ## buy confirm / not enough money overlay
var shop_kind := "" ## "confirm" | "funds" | "" (closed)
var money_chip: PanelContainer
## Hero view orbit (0.8.0): drag left/right turns the kart, up/down tilts the
## camera, pinch / wheel zooms; all clamped, easing back after a pause.
const PITCH_MIN := -0.10
const PITCH_MAX := 0.55
const ZOOM_MIN := 0.7
const ZOOM_MAX := 1.35
var view_pitch := 0.0
var view_zoom := 1.0
var _view_hold := 0.0
var _base_cam := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _pinch_dist := 0.0
var info_panel: PanelContainer
var paint_row: GridContainer
var paint_note: Label
var _dragging := false


func _init() -> void:
	back_state = Game.State.CITY_SELECT if picks_city() else Game.State.MODE_SELECT
	screen_title_key = "RACER_TITLE"


## 0.11.1: plain Yarış / Rekord come here from "Şəhəri seç".
static func picks_city() -> bool:
	return String(Game.race_config.get("series", "")) == "" and String(Game.race_config.get("mode", "")) in ["quick", "time_trial"]


const PANEL_W := 600.0
## A 600 px swipe turns the kart about 180°: it follows the finger.
const ORBIT_RAD_PER_PX := 0.0052
const CARD := Vector2(76, 100)

var hero_name: Label
var city_btn: Button ## 0.11.1 selected city chip (quick / time trial)
var hero_kart: Label


func build() -> void:
	defs = RacerRoster.all()
	current = maxi(RacerRoster.IDS.find(SaveManager.get_selected_kart()), 0)
	_frame_preview()
	get_viewport().size_changed.connect(_frame_preview)
	# Fixed 3/4 front view facing the camera for every racer (drag to turn;
	# it eases back after a moment).
	stage.auto_rotate = false
	stage.face_angle = PI - 0.6
	stage.idle_motion = true
	_add_orbit_pad.call_deferred()
	# Left: the selected racer is the hero — big 3D preview with name overlay.
	var hero := VBoxContainer.new()
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hero.position = Vector2(8, 0)
	hero.add_theme_constant_override("separation", -4)
	body.add_child(hero)
	hero_name = Label.new()
	hero_name.theme_type_variation = &"Heading"
	hero_name.add_theme_font_size_override("font_size", 64)
	hero_name.add_theme_constant_override("outline_size", 14)
	hero_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(hero_name)
	hero_kart = Label.new()
	hero_kart.add_theme_font_override("font", UITheme.bold_font())
	hero_kart.add_theme_font_size_override("font_size", UITheme.FS_H2)
	hero_kart.add_theme_constant_override("outline_size", 8)
	hero_kart.add_theme_color_override("font_outline_color", UITheme.INK)
	hero_kart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(hero_kart)
	# Right: one panel — character picker on top, the chosen racer's kart
	# info and stats below it, Start pinned at the bottom.
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.art_box("panel_blue", 20, 14))
	info_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	info_panel.offset_left = -PANEL_W
	info_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	body.add_child(info_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UITheme.GAP_M)
	info_panel.add_child(outer)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(grid)
	for i in defs.size():
		var d := defs[i]
		var b := Button.new()
		b.custom_minimum_size = CARD
		b.focus_mode = Control.FOCUS_ALL
		b.clip_contents = true
		b.tooltip_text = d.display_name
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -4)
		b.add_child(v)
		var icon := RacerIcon.new()
		icon.def = d
		icon.custom_minimum_size = Vector2(0, 70)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
		var nl := Label.new()
		nl.text = d.display_name
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_override("font", UITheme.heading_font())
		nl.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
		nl.add_theme_constant_override("outline_size", 5)
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.name = "Name"
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		# Locked (not owned) karts: dark portrait + lock price tag (0.9.0).
		var tag := GameUI.badge("", Color(UITheme.INK, 0.85), 14, UITheme.YELLOW)
		tag.name = "Lock"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		tag.position.y = 26
		b.add_child(tag)
		var idx := i
		b.pressed.connect(func(): _select(idx))
		b.focus_entered.connect(func(): _select(idx))
		grid.add_child(b)
		cards.append(b)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	outer.add_child(sep)
	# Details (fit without scrolling at 720 base height; scroll only as a
	# fallback, without a chevron overlay so nothing is ever covered).
	var info_scroll := ScrollContainer.new()
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(info_scroll)
	TouchScroll.attach(info_scroll)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.add_child(iv)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", UITheme.GAP_M)
	iv.add_child(head_row)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head_row.add_child(names)
	name_label = Label.new()
	name_label.theme_type_variation = &"Heading"
	name_label.add_theme_font_size_override("font_size", UITheme.FS_H1)
	name_label.visible = false # the big hero name on the left shows it
	names.add_child(name_label)
	kart_label = Label.new()
	kart_label.add_theme_font_override("font", UITheme.bold_font())
	kart_label.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	kart_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(kart_label)
	# Kart paints: unlocked with collected stars (cosmetic only).
	var paint_box := VBoxContainer.new()
	paint_box.add_theme_constant_override("separation", 0)
	head_row.add_child(paint_box)
	paint_row = GridContainer.new()
	paint_row.columns = 6 # 12 paints in two rows
	paint_row.add_theme_constant_override("h_separation", 5)
	paint_row.add_theme_constant_override("v_separation", 5)
	paint_box.add_child(paint_row)
	paint_note = Label.new()
	paint_note.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	paint_note.add_theme_color_override("font_color", UITheme.YELLOW)
	paint_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	paint_box.add_child(paint_note)
	pers_label = Label.new()
	pers_label.theme_type_variation = &"Dim"
	pers_label.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	pers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pers_label.visible = false # 0.8.3: secondary text dropped
	iv.add_child(pers_label)
	for sk in STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := Label.new()
		l.text = tr(sk[1])
		l.custom_minimum_size = Vector2(170, 0)
		l.add_theme_font_size_override("font_size", UITheme.FS_BODY - 1)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		var bar := StatBar10.new()
		bar.color = STAT_COLORS[STAT_KEYS.find(sk)]
		bar.custom_minimum_size = Vector2(0, 22)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var num := Label.new()
		num.custom_minimum_size = Vector2(64, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.add_theme_font_override("font", UITheme.bold_font())
		num.add_theme_font_size_override("font_size", UITheme.FS_BODY - 1)
		row.add_child(num)
		stat_rows[sk[0]] = [bar, num]
		iv.add_child(row)
	var spec_row := HBoxContainer.new()
	spec_row.add_theme_constant_override("separation", 8)
	iv.add_child(spec_row)
	var sh := Label.new()
	sh.text = tr("RACER_SPECIALTY") + ":"
	sh.add_theme_font_override("font", UITheme.bold_font())
	sh.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	sh.add_theme_color_override("font_color", UITheme.YELLOW)
	sh.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sh.visible = false # 0.8.3: the specialty line speaks for itself
	spec_row.add_child(sh)
	spec_label = Label.new()
	spec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec_label.add_theme_font_size_override("font_size", UITheme.FS_CAPTION + 1)
	spec_label.add_theme_color_override("font_color", UITheme.YELLOW)
	spec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spec_row.add_child(spec_label)
	start_btn = make_button(tr("MENU_START_RACE"), _start, true)
	start_btn.icon = UITheme.icon("play")
	start_btn.expand_icon = false
	start_btn.add_theme_constant_override("icon_max_width", 34)
	start_btn.custom_minimum_size = Vector2(0, UITheme.H_PRIMARY)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	outer.add_child(actions)
	actions.add_child(start_btn)
	buy_btn = make_button(tr("SHOP_BUY"), open_buy, true)
	buy_btn.icon = UITheme.icon("manat")
	buy_btn.expand_icon = false
	buy_btn.add_theme_constant_override("icon_max_width", 34)
	buy_btn.custom_minimum_size = Vector2(0, UITheme.H_PRIMARY)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(buy_btn, "lime", UITheme.FS_BTN_PRIMARY)
	actions.add_child(buy_btn)
	# Race setup (track, laps, rivals): a gear beside Start, one row.
	# Secondary actions under the primary one: labelled icon buttons at the
	# standard touch height (H_BTN = 72 base units, ≈ 48 dp+ on phones).
	var actions2 := HBoxContainer.new()
	actions2.add_theme_constant_override("separation", 10)
	outer.add_child(actions2)
	garage_btn = make_button(tr("MENU_GARAGE"), _garage)
	garage_btn.icon = UITheme.icon("garage")
	garage_btn.expand_icon = false
	garage_btn.add_theme_constant_override("icon_max_width", 34)
	garage_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	garage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(garage_btn, "orange", UITheme.FS_BTN)
	actions2.add_child(garage_btn)
	setup_btn = make_button(tr("RACE_SETUP_SHORT"), _setup)
	setup_btn.icon = UITheme.icon("gear")
	setup_btn.expand_icon = false
	setup_btn.add_theme_constant_override("icon_max_width", 34)
	setup_btn.tooltip_text = tr("TRACK_TITLE")
	setup_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	setup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(setup_btn, "blue", UITheme.FS_BTN)
	actions2.add_child(setup_btn)
	# Cup races have fixed settings: no race setup page.
	setup_btn.visible = String(Game.race_config.get("series", "")) == ""
	# 0.11.1: which city is about to load; tap to change it.
	if picks_city():
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(sp)
		city_btn = Button.new()
		city_btn.name = "CityButton"
		city_btn.flat = true
		city_btn.focus_mode = Control.FOCUS_ALL
		var chip := CityCards.mini_chip(String(Game.race_config.track_id), 44, 24)
		city_btn.add_child(chip)
		city_btn.custom_minimum_size = chip.get_combined_minimum_size()
		chip.resized.connect(func(): city_btn.custom_minimum_size = chip.get_combined_minimum_size())
		city_btn.pressed.connect(func():
			AudioManager.play_ui("ui_confirm")
			_commit_if_owned()
			Game.goto(Game.State.CITY_SELECT))
		header.add_child(city_btn)
	money_chip = GameUI.money_chip(SaveManager.get_money(), 28)
	header.add_child(money_chip)
	_select(current, true)


func is_owned(i: int) -> bool:
	return SaveManager.is_kart_owned(defs[i].id)


func _refresh_locks() -> void:
	for k in cards.size():
		var owned := is_owned(k)
		var tag: PanelContainer = cards[k].get_node("Lock")
		tag.visible = not owned
		tag.get_meta("value").text = Money.format(KartShop.price(defs[k].id))
		var icon: Control = cards[k].get_child(0).get_child(0)
		icon.modulate = Color.WHITE if owned else Color(0.35, 0.35, 0.45)
	var locked := not is_owned(current)
	start_btn.visible = not locked
	buy_btn.visible = locked
	buy_btn.text = "%s  %s" % [tr("SHOP_BUY"), Money.format(KartShop.price(defs[current].id))]
	garage_btn.disabled = locked
	garage_btn.modulate.a = 0.5 if locked else 1.0
	if money_chip:
		money_chip.get_meta("value").text = Money.format(SaveManager.get_money())


## "Al" pressed: confirm, or show how much is missing.
func open_buy() -> void:
	var d := defs[current]
	close_shop()
	var miss := KartShop.missing(d.id, SaveManager.get_money())
	shop_kind = "funds" if miss > 0 else "confirm"
	AudioManager.play_ui("ui_back" if miss > 0 else "ui_confirm")
	var over := Control.new()
	over.name = "ShopDialog"
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	UITheme.pop_in(panel)
	panel.add_theme_stylebox_override("panel", UITheme.art_box("panel_blue", 28, 22))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var por := GameUI.portrait(d.id, 120, UITheme.YELLOW)
	por.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(por)
	var title := GameUI.label(tr("SHOP_CONFIRM") % d.kart_name if miss == 0 else tr("SHOP_NO_MONEY"), 36, UITheme.YELLOW if miss == 0 else UITheme.CORAL, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 12)
	v.add_child(chips)
	if miss == 0:
		chips.add_child(GameUI.money_chip(KartShop.price(d.id), 40))
	else:
		var ml := GameUI.label(tr("SHOP_MISSING") % Money.format(miss), 28, UITheme.TEXT, 8)
		ml.name = "Missing"
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ml)
		v.move_child(ml, chips.get_index())
		chips.add_child(GameUI.money_chip(SaveManager.get_money(), 28))
		chips.add_child(GameUI.label("/", 28, UITheme.TEXT_DIM, 0))
		chips.add_child(GameUI.money_chip(KartShop.price(d.id), 28))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	if miss == 0:
		var ok := make_button(tr("SHOP_BUY"), confirm_buy, true)
		ok.name = "Confirm"
		ok.custom_minimum_size = Vector2(0, UITheme.H_BTN)
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(ok, "lime", UITheme.FS_BTN)
		row.add_child(ok)
		var no := make_button(tr("SHOP_CANCEL"), close_shop)
		no.custom_minimum_size = Vector2(0, UITheme.H_BTN)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(no, "blue", UITheme.FS_BTN)
		row.add_child(no)
		ok.grab_focus.call_deferred()
	else:
		var close := make_button(tr("SHOP_OK"), close_shop)
		close.custom_minimum_size = Vector2(0, UITheme.H_BTN)
		close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(close, "yellow", UITheme.FS_BTN)
		row.add_child(close)
		close.grab_focus.call_deferred()
	root.add_child(over)
	shop_dialog = over
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	UITheme.bounce(panel, 0.12)


func confirm_buy() -> void:
	var d := defs[current]
	var r := SaveManager.buy_kart(d.id)
	close_shop()
	if r == "ok":
		AudioManager.play_ui("ui_confirm")
		stage.celebrate()
		UITheme.sparkle_burst(cards[current], cards[current].get_global_rect().get_center(), 14)
		_select(current, true)
	elif r == "funds":
		open_buy()


func close_shop() -> void:
	if shop_dialog and is_instance_valid(shop_dialog):
		shop_dialog.queue_free()
		root.remove_child(shop_dialog)
	shop_dialog = null
	shop_kind = ""


func _select(i: int, force := false) -> void:
	if i == current and not force:
		return
	current = i
	var d := defs[i]
	for k in cards.size():
		var on := k == i
		var sb := UITheme.art_box("panel_card_selected" if on else "panel_card", 10, 6)
		cards[k].add_theme_stylebox_override("normal", sb)
		cards[k].add_theme_stylebox_override("hover", sb)
		cards[k].add_theme_stylebox_override("pressed", UITheme.art_box("panel_card_selected", 10, 6))
		cards[k].add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var nl: Label = cards[k].find_child("Name", true, false)
		if nl:
			nl.add_theme_color_override("font_color", UITheme.INK if on else UITheme.TEXT)
			nl.add_theme_constant_override("outline_size", 0 if on else 8)
		cards[k].scale = Vector2.ONE
	if not force:
		UITheme.sparkle_burst(cards[i], cards[i].get_global_rect().get_center(), 8)
		stage.celebrate()
	cards[i].pivot_offset = cards[i].size * 0.5
	var tw := create_tween()
	cards[i].scale = Vector2.ONE * 1.1
	tw.tween_property(cards[i], "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hero_name.text = d.display_name
	hero_name.add_theme_color_override("font_color", d.accent.lightened(0.35))
	hero_kart.text = d.kart_name
	UITheme.bounce(hero_name, 0.12)
	name_label.text = d.display_name
	name_label.add_theme_color_override("font_color", d.accent.lightened(0.45))
	UITheme.bounce(name_label, 0.12)
	kart_label.text = "%s: %s" % [tr("RACER_KART"), d.kart_name]
	pers_label.text = tr(d.personality_key)
	spec_label.text = tr(d.specialty_key)
	var r := d.ratings()
	for key in stat_rows.keys():
		var pair: Array = stat_rows[key]
		pair[0].value = int(r[key])
		pair[1].text = "%d/10" % int(r[key])
	stage.show_racer(d.id)
	_build_paints(d)
	_refresh_locks()
	AudioManager.play_ui("ui_select" if not force else "ui_move")


func _build_paints(d: RacerDefinition) -> void:
	for c in paint_row.get_children():
		c.queue_free()
	var stars := SaveManager.get_stars()
	var chosen := SaveManager.get_paint(d.id)
	for i in KartPaints.count():
		var sw := PaintSwatch.new()
		sw.color = KartPaints.color_of(d, i)
		sw.locked = not SaveManager.is_paint_unlocked(d.id, i)
		sw.cost = KartPaints.cost(i)
		sw.selected = i == chosen
		sw.custom_minimum_size = Vector2(40, 40)
		sw.focus_mode = Control.FOCUS_NONE
		var idx := i
		sw.pressed.connect(func(): _choose_paint(d, idx, sw))
		paint_row.add_child(sw)
	paint_note.text = "%s: %d" % [tr("RESULTS_STARS"), stars]


func _choose_paint(d: RacerDefinition, i: int, sw: Control) -> void:
	UITheme.bounce(sw, 0.12)
	if not SaveManager.is_paint_unlocked(d.id, i):
		AudioManager.play_ui("ui_back")
		paint_note.text = tr("RACER_PAINT_LOCKED") % [KartPaints.cost(i), SaveManager.get_stars()]
		return
	AudioManager.play_ui("ui_confirm")
	SaveManager.set_paint(d.id, i)
	stage.show_racer(d.id, false, i)
	_build_paints(d)


func _commit() -> void:
	var d := defs[current]
	if not is_owned(current):
		return
	SaveManager.set_selected_kart(d.id)
	Game.race_config.kart_id = d.id
	Game.race_config.paint = SaveManager.get_paint(d.id)


func _start() -> void:
	if not is_owned(current):
		open_buy()
		return
	_commit()
	if Game.race_config.mode == "time_trial":
		Game.race_config.ai_count = 0
		Game.race_config.items = false
	if String(Game.race_config.get("series", "")) == "cup_new":
		# Bakı Kuboku: the kart picked here drives all three races.
		var cup := BakuCup.start(SaveManager.data, String(Game.race_config.kart_id), randi_range(1, 1 << 30))
		SaveManager.save_profile()
		BakuCup.apply_config(Game.race_config, cup)
	Game.start_loading_race()


func _commit_if_owned() -> void:
	if is_owned(current):
		_commit()


func _setup() -> void:
	if not is_owned(current):
		current = maxi(RacerRoster.IDS.find(SaveManager.get_selected_kart()), 0)
	_commit()
	Game.goto(Game.State.TRACK_SELECT)


func _garage() -> void:
	if not is_owned(current):
		return
	_commit()
	Game.garage_back = Game.State.KART_SELECT
	Game.goto(Game.State.GARAGE)


func first_focus() -> Control:
	return cards[current] if not cards.is_empty() else null


var orbit_pad: OrbitPad


## Touch area over the hero kart; added last so it is above every full-screen
## container (see OrbitPad for the 0.8.0 root cause).
func _add_orbit_pad() -> void:
	orbit_pad = OrbitPad.make(PANEL_W + 40.0)
	root.add_child(orbit_pad)
	orbit_pad.orbit.connect(orbit_view)
	orbit_pad.zoom.connect(zoom_view)
	orbit_pad.held.connect(func(on: bool):
		_dragging = on
		stage.held = on)


## One drag step: x turns the kart, y tilts the camera (clamped).
func orbit_view(rel: Vector2) -> void:
	stage.drag(rel.x * ORBIT_RAD_PER_PX)
	view_pitch = clampf(view_pitch + rel.y * 0.004, PITCH_MIN, PITCH_MAX)
	_view_hold = 2.5
	_apply_view()


func zoom_view(factor: float) -> void:
	view_zoom = clampf(view_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_view_hold = 2.5
	_apply_view()


func _process(delta: float) -> void:
	if stage == null or stage.camera == null:
		return
	_view_hold = maxf(_view_hold - delta, 0.0)
	if _view_hold <= 0.0 and not _dragging and (absf(view_pitch) > 0.001 or absf(view_zoom - 1.0) > 0.001):
		var k := 1.0 - exp(-2.5 * delta)
		view_pitch = lerpf(view_pitch, 0.0, k)
		view_zoom = lerpf(view_zoom, 1.0, k)
		_apply_view()


func _apply_view() -> void:
	if stage == null or stage.camera == null:
		return
	var off := _base_cam - _cam_target
	off = off.rotated(Vector3.RIGHT, -view_pitch) * view_zoom
	var pos := _cam_target + off
	pos.y = maxf(pos.y, 0.35)
	stage.camera.position = pos
	stage.camera.look_at_from_position(pos, _cam_target)


class PaintSwatch:
	extends BaseButton
	## Round colour swatch; locked swatches show the star cost.
	var color := Color.WHITE
	var locked := false
	var selected := false
	var cost := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		if selected:
			draw_circle(c, r + 4.0, UITheme.YELLOW)
		draw_circle(c, r, UITheme.INK)
		draw_circle(c, r - 3.0, color.darkened(0.45) if locked else color)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.3))
		if locked:
			var f := UITheme.bold_font()
			var t := str(cost)
			var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			draw_string_outline(f, c + Vector2(-ts.x * 0.5, 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UITheme.INK)
			draw_string(f, c + Vector2(-ts.x * 0.5, 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UITheme.YELLOW)


class StatBar10:
	extends Control
	## Ten segments + number label beside it (readable without colour).
	var value := 5:
		set(v):
			value = v
			queue_redraw()
	var color := UITheme.TURQUOISE:
		set(v):
			color = v
			queue_redraw()

	func _draw() -> void:
		var n := 10
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		for i in n:
			var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y))
			var on := i < value
			draw_style_box(UITheme.rounded(UITheme.INK if on else Color(UITheme.INK, 0.35), 6, 0, Color.TRANSPARENT, 0), r.grow(1.5))
			draw_style_box(UITheme.rounded(color if on else Color(1, 1, 1, 0.16), 5, 0, Color.TRANSPARENT, 0), r)
			if on:
				draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.3)), Color(1, 1, 1, 0.35))


## Close, large preview of the selected racer, framed in the free space
## between the card grid and the info panel. Wide phones (20:9) get the
## closest shot; narrower 16:9 / 4:3 screens pull back so the kart never
## slides under the side panels.
func _frame_preview() -> void:
	if stage == null or stage.camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var t := clampf((aspect - 1.33) / (2.22 - 1.33), 0.0, 1.0)
	var dist := lerpf(8.4, 4.4, t)
	var height := lerpf(2.2, 1.35, t)
	# Free-space centre relative to screen centre (panel PANEL_W on the right).
	var free_center := (vp.x - PANEL_W) * 0.5
	var shift := (vp.x * 0.5 - free_center) / vp.x # >0: free space left of centre
	var x := shift * dist * 0.8
	stage.camera.fov = 40.0
	_base_cam = Vector3(x, height, dist)
	_cam_target = Vector3(x, 0.62, 0)
	_apply_view()
