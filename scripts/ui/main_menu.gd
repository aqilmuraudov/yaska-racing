extends MenuScreen
## Main menu (0.10.2 redesign after the owner's mockup): the selected kart on
## a glowing showroom turntable on a busy Baku boulevard, the big "Yaska
## Racing" logo with a crown and a wooden-plank subtitle, a round Settings
## button top-left, title + balance pills top-right and four chunky glossy
## buttons along the bottom: Oyna, Qaraj, Mükafatlar, Ayarlar.
## Credits now live in Settings; the game modes are reached through Oyna.

var play_btn: Button
var _title: TextureRect
var garage_btn: Button
var rewards_btn: Button
var settings_btn: Button
var gear_btn: Button
var plus_btn: Button
var money_chip: PanelContainer
var title_badge: PanelContainer
var buttons: Array[Button] = []
var tiles: Array[Control] = []
var _icons: Array[TextureRect] = []
var _logo_box: Control
var _crown: TextureRect
var _t := 0.0

const TILE_W := 262.0
const TILE_H := 150.0
const GEAR_SIZE := 104.0 ## 0.11.0: 80 -> 104 px, glossy
const ICON_SIZE := 96.0
const MENU_ICONS := "res://assets/icons/menu/"


func _init() -> void:
	back_state = -1


func build() -> void:
	var racer_id := SaveManager.get_selected_kart()
	stage.build_showcase()
	stage.show_racer(racer_id)
	stage.frame_showcase()
	# The base class's left blue wash is lighter here: the boulevard is the show.
	var shade := root.get_child(0) as CanvasItem
	if shade:
		shade.modulate.a = 0.25
	var lay := Control.new()
	lay.name = "Layout"
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(lay)
	_build_logo(lay)
	_build_top_bar(lay)
	_build_bottom_row(lay)
	# Version: tiny and faint, bottom left.
	var ver := Label.new()
	ver.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0")
	ver.add_theme_font_size_override("font_size", 13)
	ver.modulate = Color(1, 1, 1, 0.45)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	if login_popup_enabled and DailyLogin.status(SaveManager.data, Progression.today()).can_claim:
		show_login.call_deferred()


func _build_logo(lay: Control) -> void:
	_logo_box = Control.new()
	_logo_box.name = "LogoBox"
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.position = Vector2(36, 92) # 0.11.0: room for the bigger gear
	_logo_box.size = Vector2(480, 250)
	lay.add_child(_logo_box)
	_title = TextureRect.new()
	_title.texture = load("res://assets/ui/yaska_racing_logo.png")
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title.size = Vector2(480, 190)
	_title.tooltip_text = tr("GAME_TITLE")
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.add_child(_title)
	_crown = TextureRect.new()
	_crown.name = "Crown"
	_crown.texture = load(MENU_ICONS + "crown.svg")
	_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crown.size = Vector2(92, 70)
	_crown.position = Vector2(300, -26)
	_crown.pivot_offset = _crown.size * 0.5
	_crown.rotation = deg_to_rad(14.0)
	_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.add_child(_crown)
	var plank := NinePatchRect.new()
	plank.name = "Plank"
	plank.texture = load(MENU_ICONS + "plank.svg")
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		plank.set_patch_margin(side, 40)
	plank.set_patch_margin(SIDE_TOP, 20)
	plank.set_patch_margin(SIDE_BOTTOM, 24)
	plank.position = Vector2(30, 182)
	plank.size = Vector2(430, 62)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.rotation = deg_to_rad(-1.5)
	_logo_box.add_child(plank)
	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = tr("GAME_SUBTITLE")
	sub.add_theme_font_override("font", UITheme.heading_font())
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", UITheme.CREAM)
	sub.add_theme_color_override("font_outline_color", Color("3a1f08"))
	sub.add_theme_constant_override("outline_size", 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.offset_bottom = -4
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(sub)
	# Fit the subtitle on the plank in every language.
	var fsz := 22
	while fsz > 15 and sub.get_theme_font("font").get_string_size(sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > plank.size.x - 56:
		fsz -= 1
	sub.add_theme_font_size_override("font_size", fsz)
	_logo_box.pivot_offset = Vector2(240, 120)
	_logo_box.scale = Vector2(0.6, 0.6)
	_logo_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_logo_box, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_logo_box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _round_style(bg: Color, radius: int, border := 4, pad := 6) -> StyleBoxFlat:
	var sb := UITheme.rounded(bg, radius, border, UITheme.INK, pad)
	sb.shadow_color = Color(UITheme.INK, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _build_top_bar(lay: Control) -> void:
	# Round gear (Settings) top-left.
	gear_btn = Button.new()
	gear_btn.name = "GearButton"
	gear_btn.tooltip_text = tr("MENU_SETTINGS")
	gear_btn.icon = UITheme.icon("gear")
	gear_btn.expand_icon = true
	gear_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_btn.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	gear_btn.size = gear_btn.custom_minimum_size
	gear_btn.add_theme_constant_override("icon_max_width", int(GEAR_SIZE * 0.5))
	# 0.11.0: bigger glossy bubble (assets/ui/btn_round_blue*.png, made by
	# ui_audit_round20/make_round_btn.py); the gear sits a bit above centre.
	var gs := StyleBoxTexture.new()
	gs.texture = load("res://assets/ui/btn_round_blue.png")
	gs.content_margin_bottom = 8
	gs.content_margin_right = 6
	var gp := gs.duplicate() as StyleBoxTexture
	gp.texture = load("res://assets/ui/btn_round_blue_pressed.png")
	gear_btn.add_theme_stylebox_override("normal", gs)
	gear_btn.add_theme_stylebox_override("hover", gs)
	gear_btn.add_theme_stylebox_override("pressed", gp)
	gear_btn.add_theme_stylebox_override("focus", _focus_ring(int(GEAR_SIZE / 2)))
	gear_btn.pressed.connect(func():
		UITheme.bounce(gear_btn, 0.12)
		Game.goto(Game.State.SETTINGS))
	lay.add_child(gear_btn)
	gear_btn.position = Vector2(0, 0)
	# Title pill + balance pill (with a green "+" to the garage), top-right.
	var top := HBoxContainer.new()
	top.name = "TopRight"
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stars := int(SaveManager.data.lifetime.get("stars", 0))
	title_badge = PanelContainer.new()
	title_badge.name = "TitlePill"
	var ts := _round_style(UITheme.VIOLET, 30, 3, 6)
	ts.border_color = Color(1, 1, 1, 0.85)
	ts.content_margin_left = 14
	ts.content_margin_right = 18
	title_badge.add_theme_stylebox_override("panel", ts)
	title_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	title_badge.add_child(th)
	var star := GameUI.icon_rect("star", 26)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(star)
	var tl := GameUI.label(tr(Progression.title_for(stars).name), 21, UITheme.TEXT, 6)
	th.add_child(tl)
	title_badge.set_meta("value", tl)
	top.add_child(title_badge)
	money_chip = PanelContainer.new()
	money_chip.name = "MoneyPill"
	var ms := _round_style(Color(UITheme.INK, 0.82), 32, 3, 4)
	ms.border_color = Color(1, 1, 1, 0.5)
	ms.content_margin_left = 8
	ms.content_margin_right = 6
	money_chip.add_theme_stylebox_override("panel", ms)
	money_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 8)
	money_chip.add_child(mh)
	mh.add_child(GameUI.icon_rect("manat", 40))
	var ml := GameUI.label(Money.format(SaveManager.get_money()), 28, UITheme.YELLOW, 8)
	mh.add_child(ml)
	money_chip.set_meta("value", ml)
	plus_btn = Button.new()
	plus_btn.name = "PlusButton"
	plus_btn.text = "+"
	plus_btn.tooltip_text = tr("MENU_GARAGE")
	plus_btn.custom_minimum_size = Vector2(48, 48)
	plus_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ps := UITheme.rounded(UITheme.LIME, 24, 3, Color.WHITE, 0)
	var pp := ps.duplicate() as StyleBoxFlat
	pp.bg_color = UITheme.LIME.darkened(0.25)
	plus_btn.add_theme_stylebox_override("normal", ps)
	plus_btn.add_theme_stylebox_override("hover", ps)
	plus_btn.add_theme_stylebox_override("pressed", pp)
	plus_btn.add_theme_stylebox_override("focus", _focus_ring(24))
	plus_btn.add_theme_font_override("font", UITheme.heading_font())
	plus_btn.add_theme_font_size_override("font_size", 38)
	plus_btn.add_theme_color_override("font_color", Color.WHITE)
	plus_btn.add_theme_color_override("font_outline_color", Color(UITheme.INK, 0.8))
	plus_btn.add_theme_constant_override("outline_size", 6)
	plus_btn.pressed.connect(func():
		UITheme.bounce(plus_btn, 0.2)
		open_garage())
	mh.add_child(plus_btn)
	top.add_child(money_chip)
	lay.add_child(top)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = 0
	top.offset_right = 0
	top.offset_top = 6
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _focus_ring(radius: int) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.set_corner_radius_all(radius + 4)
	f.set_border_width_all(4)
	f.border_color = UITheme.YELLOW
	f.set_expand_margin_all(4)
	return f


func _build_bottom_row(lay: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "BottomRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(row)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -TILE_H
	row.offset_bottom = 0
	play_btn = _tile(row, tr("MENU_PLAY"), "yellow", "menu_play", func(): Game.play_pressed()) # 0.13.0: first time -> the lesson
	garage_btn = _tile(row, tr("MENU_GARAGE"), "blue", "menu_garage", open_garage)
	rewards_btn = _tile(row, tr("MENU_REWARDS"), "violet", "menu_trophy", func(): Game.goto(Game.State.REWARDS))
	settings_btn = _tile(row, tr("MENU_SETTINGS"), "lime", "menu_gear", func(): Game.goto(Game.State.SETTINGS))
	# Pop in, staggered, with a bounce (scale only: buttons never leave the
	# screen, so layout checks hold from the first frame).
	for i in tiles.size():
		var t := tiles[i]
		t.modulate.a = 0.0
		var b := buttons[i]
		b.scale = Vector2(0.7, 0.7)
		var tw := create_tween()
		tw.tween_interval(0.12 + 0.07 * i)
		tw.tween_property(t, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## One chunky glossy button: the 3D-style icon pokes out above the top edge,
## the label sits low on the button.
func _tile(row: HBoxContainer, text: String, color: String, icon_name: String, cb: Callable) -> Button:
	var tile := Control.new()
	tile.name = "Tile_" + icon_name
	tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)
	var shadow := Panel.new()
	var shs := UITheme.rounded(Color(UITheme.INK, 0.4), 30, 0, Color.TRANSPARENT, 0)
	shadow.add_theme_stylebox_override("panel", shs)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = Vector2(6, 48)
	shadow.size = Vector2(TILE_W - 12, TILE_H - 42)
	tile.add_child(shadow)
	var b := make_button(text, cb, color == "yellow")
	b.name = "Btn_" + icon_name
	UITheme.style_button(b, color, 34)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := (b.get_theme_stylebox(st) as StyleBox).duplicate() as StyleBox
		sb.content_margin_top = 40
		sb.content_margin_bottom = 12
		b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(0, 0)
	b.position = Vector2(0, 40)
	b.size = Vector2(TILE_W, TILE_H - 44)
	b.clip_text = false
	# White label with a dark outline in the button's own hue (as in the mockup).
	var outline := {"yellow": Color("8a4b00"), "blue": Color("0c2f78"), "violet": Color("3d1680"), "lime": Color("1f5c0e")}
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", outline.get(color, UITheme.INK))
	b.add_theme_constant_override("outline_size", 10)
	tile.add_child(b)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.texture = load(MENU_ICONS + icon_name + ".svg")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(ICON_SIZE, ICON_SIZE)
	ic.position = Vector2((TILE_W - ICON_SIZE) * 0.5, 0)
	ic.pivot_offset = ic.size * 0.5
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(ic)
	b.pressed.connect(func():
		var tw := ic.create_tween()
		tw.tween_property(ic, "scale", Vector2(1.25, 1.25), 0.08)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.button_down.connect(func(): b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	b.pivot_offset = b.size * 0.5
	tiles.append(tile)
	buttons.append(b)
	_icons.append(ic)
	return b


## 7-day login bonus popup (0.9.0).
static var login_popup_enabled := true
var login_popup: Control
var login_tiles: Array = []
var login_claim_btn: Button


func show_login() -> void:
	if login_popup and is_instance_valid(login_popup):
		return
	var st := DailyLogin.status(SaveManager.data, Progression.today())
	var over := Control.new()
	over.name = "LoginPopup"
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
	panel.add_theme_stylebox_override("panel", UITheme.art_box("panel_blue", 26, 20))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var t := GameUI.label(tr("LOGIN_TITLE"), 42, UITheme.YELLOW, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(strip)
	login_tiles = []
	for d in range(1, 8):
		var big := d == 7
		var today: bool = d == int(st.day)
		var done: bool = d < int(st.day)
		var tile := PanelContainer.new()
		var bg := UITheme.YELLOW if today else (Color(UITheme.LIME, 0.35) if done else Color(UITheme.INK, 0.45))
		tile.add_theme_stylebox_override("panel", UITheme.rounded(bg, 18, 4 if today else 2, Color.WHITE if today else Color(UITheme.INK, 0.6), 8))
		tile.custom_minimum_size = Vector2(150 if big else 104, 150 if big else 132)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 2)
		tile.add_child(tv)
		var dl := GameUI.label(tr("LOGIN_DAY") % d, 18, UITheme.INK if today else UITheme.TEXT, 0 if today else 5)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(dl)
		var ic := GameUI.icon_rect("trophy" if big else "manat", 64 if big else 42)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tv.add_child(ic)
		var amt := GameUI.label("✓" if done else Money.format(DailyLogin.reward(d)), 24 if big else 18, UITheme.INK if today else UITheme.TEXT, 0 if today else 5)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(amt)
		strip.add_child(tile)
		login_tiles.append(tile)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	login_claim_btn = make_button("%s  +%s" % [tr("LOGIN_CLAIM"), Money.format(DailyLogin.reward(int(st.day)))], claim_login, true)
	login_claim_btn.custom_minimum_size = Vector2(340, UITheme.H_PRIMARY)
	UITheme.style_button(login_claim_btn, "lime", UITheme.FS_BTN_PRIMARY)
	row.add_child(login_claim_btn)
	# Rewarded-ad "double it": hook only, hidden until an ad SDK exists.
	var dbl := make_button(tr("LOGIN_DOUBLE"), func(): pass)
	dbl.name = "Double"
	dbl.visible = DailyLogin.AD_DOUBLE_ENABLED and RewardedAds.is_available()
	row.add_child(dbl)
	root.add_child(over)
	login_popup = over
	panel.pivot_offset = panel.get_combined_minimum_size() * 0.5
	UITheme.bounce(panel, 0.12)
	login_claim_btn.grab_focus.call_deferred()


func claim_login() -> int:
	var paid := DailyLogin.claim(SaveManager.data, Progression.today())
	if paid > 0:
		SaveManager.save_profile()
		AudioManager.play_ui("ui_confirm")
		money_chip.get_meta("value").text = Money.format(SaveManager.get_money())
		UITheme.bounce(money_chip, 0.2)
		UITheme.sparkle_burst(money_chip, money_chip.get_global_rect().get_center(), 12)
	if login_popup and is_instance_valid(login_popup):
		login_popup.queue_free()
	login_popup = null
	return paid


func open_garage() -> void:
	Game.open_garage(SaveManager.get_selected_kart(), Game.State.MAIN_MENU)


func _process(delta: float) -> void:
	_t += delta
	if _title:
		_title.position.y = sin(_t * 1.6) * 3.0
	if _crown:
		_crown.rotation = deg_to_rad(14.0 + sin(_t * 2.1) * 4.0)
	# Icons bob gently; Play "breathes" so it reads as the main action.
	for i in _icons.size():
		_icons[i].position.y = sin(_t * 2.0 + i * 0.9) * 3.0
	if play_btn and _t > 1.0 and play_btn.get_draw_mode() != BaseButton.DRAW_PRESSED and play_btn.get_draw_mode() != BaseButton.DRAW_HOVER_PRESSED:
		var k := 1.0 + maxf(sin(_t * 3.0), 0.0) * 0.035
		play_btn.scale = Vector2(k, k)


func first_focus() -> Control:
	return play_btn


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Settings.is_desktop():
		pass # no accidental quit from the root menu
