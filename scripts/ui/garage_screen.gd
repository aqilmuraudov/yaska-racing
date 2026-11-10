class_name GarageScreen
extends MenuScreen
## Garage & tuning (0.8.0), opened from racer select. The selected racer's
## kart turns on the left (drag); the right panel lists paint and the
## upgrades bought with manat: top speed, engine, brakes, steering, tyres and
## the Nitro add-on. Each row shows the level, a stat preview bar (current
## and, highlighted, the next level) and the next price.

const PANEL_W := 640.0
const ROWS := [
	["speed", "GARAGE_SPEED", "GARAGE_SPEED_DESC", "top_speed", Color("ff5f6d")],
	["engine", "GARAGE_ENGINE", "GARAGE_ENGINE_DESC", "acceleration", Color("ffb21f")],
	["brakes", "GARAGE_BRAKES", "GARAGE_BRAKES_DESC", "", Color("8b5cf6")],
	["steering", "GARAGE_STEERING", "GARAGE_STEERING_DESC", "handling", Color("17b9c9")],
	["tyres", "GARAGE_TYRES", "GARAGE_TYRES_DESC", "drift", Color("6fcf3c")],
	["nitro", "GARAGE_NITRO", "GARAGE_NITRO_DESC", "", Color("e8334f")],
]

var racer_id := ""
var def: RacerDefinition
var balance_label: Label
var note_label: Label
var paint_row: HBoxContainer
var parts_grid: GridContainer
var rows := {} ## cat -> {"level": Label, "bar": PreviewBar, "buy": Button}
var done_btn: Button
## 0.11.0 "Yeni maşın" card: buy the next locked kart right here.
var new_kart_box: VBoxContainer
var new_kart_id := ""
var new_kart_btn: Button
var shop_dialog: Control
var _dragging := false
## 0.15.2 (owner): the panel has two big tabs - "Maşınlar" (pick / buy a
## kart) and "Tüninq" (paint, upgrades, parts) - instead of one long list.
static var tab := 0
var tab_buttons: Array[Button] = []
var tab_pages: Array[Control] = []


func _init() -> void:
	back_state = Game.State.KART_SELECT
	screen_title_key = "GARAGE_TITLE"


func build() -> void:
	back_state = Game.garage_back
	racer_id = String(Game.race_config.get("kart_id", SaveManager.get_selected_kart()))
	if not RacerRoster.is_valid(racer_id):
		racer_id = SaveManager.get_selected_kart()
	def = RacerRoster.get_def(racer_id)
	stage.auto_rotate = false
	stage.face_angle = PI - 0.6
	stage.idle_motion = true
	stage.show_racer(racer_id, true)
	_add_orbit_pad.call_deferred()
	_frame()
	get_viewport().size_changed.connect(_frame)
	var bal := HBoxContainer.new()
	bal.add_theme_constant_override("separation", 8)
	bal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bal.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(bal)
	var icon := TextureRect.new()
	icon.texture = UITheme.icon("manat")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	bal.add_child(icon)
	balance_label = Label.new()
	balance_label.add_theme_font_override("font", UITheme.heading_font())
	balance_label.add_theme_font_size_override("font_size", 34)
	balance_label.add_theme_color_override("font_color", UITheme.YELLOW)
	balance_label.add_theme_constant_override("outline_size", 10)
	balance_label.add_theme_color_override("font_outline_color", UITheme.INK)
	bal.add_child(balance_label)

	var hero := Label.new()
	hero.text = "%s · %s" % [def.display_name, def.kart_name]
	hero.theme_type_variation = &"Heading"
	hero.add_theme_font_size_override("font_size", 40)
	hero.add_theme_constant_override("outline_size", 12)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.position = Vector2(8, 0)
	body.add_child(hero)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W
	body.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var tabs := HBoxContainer.new()
	tabs.name = "GarageTabs"
	tabs.add_theme_constant_override("separation", 10)
	outer.add_child(tabs)
	for t in [["GARAGE_TAB_KARTS", "racer_yaska"], ["GARAGE_TAB_TUNING", "garage"]]:
		var tb := Button.new()
		tb.text = tr(t[0])
		tb.icon = UITheme.icon(t[1])
		tb.add_theme_constant_override("icon_max_width", 40)
		tb.custom_minimum_size = Vector2(0, UITheme.H_PRIMARY)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.clip_text = true
		tb.focus_mode = Control.FOCUS_ALL
		var i := tab_buttons.size()
		tb.pressed.connect(func(): show_tab(i))
		tabs.add_child(tb)
		tab_buttons.append(tb)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	TouchScroll.attach(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	var kv := VBoxContainer.new()
	kv.name = "KartsPage"
	kv.add_theme_constant_override("separation", 10)
	pages.add_child(kv)
	new_kart_box = VBoxContainer.new()
	new_kart_box.name = "NewKart"
	kv.add_child(new_kart_box)
	_build_my_karts(kv)
	_build_new_kart()
	var v := VBoxContainer.new()
	v.name = "TuningPage"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	pages.add_child(v)
	tab_pages = [kv, v]
	# Paint
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	v.add_child(ph)
	ph.add_child(GameUI.label(tr("GARAGE_PAINT"), UITheme.FS_H2, UITheme.TEXT, 6))
	ph.add_child(GameUI.money_chip(KartTuning.PAINT_COST, 18))
	paint_row = HBoxContainer.new()
	paint_row.add_theme_constant_override("separation", 6)
	v.add_child(paint_row)
	for r in ROWS:
		v.add_child(_make_row(r))
	# Kart parts (moved here from Rewards in 0.8.3): tap to fit / remove.
	v.add_child(GameUI.label(tr("REWARDS_PARTS"), UITheme.FS_H2, UITheme.TEXT, 6))
	parts_grid = GridContainer.new()
	parts_grid.columns = 3
	parts_grid.add_theme_constant_override("h_separation", 6)
	parts_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(parts_grid)
	note_label = Label.new()
	note_label.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	note_label.add_theme_color_override("font_color", UITheme.YELLOW)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(note_label)
	done_btn = make_button(tr("GARAGE_DONE"), go_back, true)
	done_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	UITheme.style_button(done_btn, "yellow", UITheme.FS_BTN)
	outer.add_child(done_btn)
	refresh()
	_build_parts()
	show_tab(tab)


func show_tab(i: int) -> void:
	tab = clampi(i, 0, 1)
	for k in tab_pages.size():
		tab_pages[k].visible = k == tab
		UITheme.style_button(tab_buttons[k], "yellow" if k == tab else "blue", UITheme.FS_BTN_PRIMARY)


func _make_row(r: Array) -> Control:
	var cat: String = r[0]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.NAVY_LIGHT, 0.45), 16, 0, Color.TRANSPARENT, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	h.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	var name_l := Label.new()
	name_l.text = tr(r[1])
	name_l.add_theme_font_override("font", UITheme.bold_font())
	name_l.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var lvl := Label.new()
	lvl.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	lvl.theme_type_variation = &"Dim"
	top.add_child(lvl)
	var bar := PreviewBar.new()
	bar.color = r[4]
	bar.custom_minimum_size = Vector2(0, 18)
	left.add_child(bar)
	# 0.8.3: no description line; the name, level and bar say it all.
	box.tooltip_text = tr(r[2])
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(170, UITheme.H_BTN_SMALL)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(buy, "lime", UITheme.FS_BTN_SMALL)
	buy.icon = UITheme.icon("manat")
	buy.expand_icon = false
	buy.add_theme_constant_override("icon_max_width", 26)
	buy.pressed.connect(func(): buy_upgrade(cat))
	h.add_child(buy)
	rows[cat] = {"level": lvl, "bar": bar, "buy": buy, "stat": r[3]}
	return box


func buy_upgrade(cat: String) -> bool:
	if SaveManager.buy_upgrade(racer_id, cat):
		AudioManager.play_ui("ui_confirm")
		note_label.text = tr("GARAGE_BOUGHT")
		UITheme.bounce(rows[cat].buy, 0.12)
		UITheme.sparkle_burst(rows[cat].buy, rows[cat].buy.get_global_rect().get_center(), 7)
		if stage:
			stage.celebrate()
		refresh()
		return true
	AudioManager.play_ui("ui_back")
	note_label.text = tr("GARAGE_NOT_ENOUGH")
	return false


func _on_paint(i: int, sw: Control) -> void:
	UITheme.bounce(sw, 0.12)
	if not SaveManager.is_paint_unlocked(racer_id, i):
		if not SaveManager.buy_paint(racer_id, i):
			AudioManager.play_ui("ui_back")
			note_label.text = tr("GARAGE_NOT_ENOUGH")
			return
		note_label.text = tr("GARAGE_BOUGHT")
	else:
		SaveManager.set_paint(racer_id, i)
	AudioManager.play_ui("ui_confirm")
	Game.race_config.paint = SaveManager.get_paint(racer_id)
	stage.show_racer(racer_id, false, SaveManager.get_paint(racer_id))
	refresh()


func refresh() -> void:
	balance_label.text = Money.format(SaveManager.get_money())
	var lv := SaveManager.tuning_levels(racer_id)
	var ratings := def.ratings()
	for cat in rows.keys():
		var row: Dictionary = rows[cat]
		var l := int(lv[cat])
		var mx := KartTuning.max_for(cat)
		var cost := KartTuning.next_cost(cat, l)
		if cat == "nitro":
			row.level.text = tr("GARAGE_LEVEL") % [l, mx] if l > 0 else "—"
			row.bar.base = 0.0
			row.bar.value = 10.0 * l / mx
			row.bar.next = 10.0 * mini(l + 1, mx) / mx
		else:
			row.level.text = tr("GARAGE_LEVEL") % [l, mx]
			var base := float(ratings.get(row.stat, 5)) if row.stat != "" else 5.0
			row.bar.base = base
			row.bar.value = KartTuning.preview(int(base), l)
			row.bar.next = KartTuning.preview(int(base), mini(l + 1, mx))
		var b: Button = row.buy
		if cost < 0:
			b.text = tr("GARAGE_MAX")
			b.disabled = true
			b.icon = null
		else:
			b.text = (tr("GARAGE_NITRO_FIT") + " " if cat == "nitro" and l == 0 else "") + Money.format(cost)
			b.disabled = false
			b.modulate = Color.WHITE if SaveManager.get_money() >= cost else Color(1, 1, 1, 0.6)
	for c in paint_row.get_children():
		paint_row.remove_child(c)
		c.queue_free()
	var chosen := SaveManager.get_paint(racer_id)
	for i in KartPaints.count():
		var sw := RacerSelect.PaintSwatch.new()
		sw.color = KartPaints.color_of(def, i)
		sw.locked = not SaveManager.is_paint_unlocked(racer_id, i)
		sw.cost = KartPaints.cost(i)
		sw.selected = i == chosen
		sw.custom_minimum_size = Vector2(40, 40)
		sw.focus_mode = Control.FOCUS_NONE
		var idx := i
		sw.pressed.connect(func(): _on_paint(idx, sw))
		paint_row.add_child(sw)


func _build_parts() -> void:
	for c in parts_grid.get_children():
		parts_grid.remove_child(c)
		c.queue_free()
	var data := SaveManager.data
	for i in Progression.PARTS.size():
		var part: Dictionary = Progression.PARTS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, UITheme.H_BTN_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text = tr(part.name)
		if Progression.part_unlocked(data, i):
			var on: bool = not (part.id in data.parts_off)
			UITheme.style_button(b, "lime" if on else "blue", UITheme.FS_CAPTION)
			var id: String = part.id
			b.pressed.connect(func(): toggle_part(id))
		else:
			UITheme.style_button(b, "blue", UITheme.FS_CAPTION)
			b.modulate = Color(1, 1, 1, 0.45)
			b.disabled = true
		parts_grid.add_child(b)


func toggle_part(id: String) -> void:
	var off: Array = SaveManager.data.parts_off
	if id in off:
		off.erase(id)
	else:
		off.append(id)
	SaveManager.save_profile()
	AudioManager.play_ui("ui_confirm")
	stage.show_racer(racer_id, false, SaveManager.get_paint(racer_id))
	_build_parts()


## Next kart in shop order the player does not own yet ("" = all owned).
static func next_locked_kart() -> String:
	for id in KartShop.shop_order():
		if RacerRoster.is_valid(id) and not SaveManager.is_kart_owned(id):
			return id
	return ""


func _build_new_kart() -> void:
	for c in new_kart_box.get_children():
		c.queue_free()
	new_kart_id = next_locked_kart()
	new_kart_btn = null
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.art_box("panel_card_selected" if new_kart_id != "" else "panel_card", 10, 6))
	new_kart_box.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	if new_kart_id == "":
		var all := GameUI.label("★ " + tr("GARAGE_ALL_KARTS"), UITheme.FS_H2, UITheme.YELLOW, 8)
		all.name = "AllKarts"
		h.add_child(all)
		return
	# 0.15.2: every kart card has its own buy button below; no extra card.
	card.queue_free()
	return
	var d := RacerRoster.get_def(new_kart_id)
	h.add_child(GameUI.portrait(new_kart_id, 84, UITheme.YELLOW))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(tv)
	tv.add_child(GameUI.label(tr("GARAGE_NEW_KART"), UITheme.FS_H2, UITheme.INK, 0))
	tv.add_child(GameUI.label(d.display_name, UITheme.FS_BODY, UITheme.INK, 0))
	new_kart_btn = make_button("%s  %s" % [tr("SHOP_BUY"), Money.format(KartShop.price(new_kart_id))], open_buy, true)
	new_kart_btn.name = "BuyKart"
	new_kart_btn.icon = UITheme.icon("manat")
	new_kart_btn.add_theme_constant_override("icon_max_width", 30)
	new_kart_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	new_kart_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(new_kart_btn, "lime", UITheme.FS_BTN)
	h.add_child(new_kart_btn)


## 0.14.4 (owner) "Maşınlarım": every kart in one row. Owned: tap to make it
## the kart for every race (selected one has a gold ring); locked: price, tap
## to buy it with manat. Races no longer ask for a kart.
var my_karts: GridContainer


func _build_my_karts(v: VBoxContainer) -> void:
	my_karts = GridContainer.new()
	my_karts.name = "MyKarts"
	my_karts.columns = 3
	my_karts.add_theme_constant_override("h_separation", 10)
	my_karts.add_theme_constant_override("v_separation", 10)
	v.add_child(my_karts)
	var selected := SaveManager.get_selected_kart()
	for d in RacerRoster.all():
		var owned := SaveManager.is_kart_owned(d.id)
		var sel := d.id == selected
		var b := Button.new()
		b.name = "Kart_" + d.id
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(184, 230)
		b.tooltip_text = d.display_name
		var box := UITheme.art_box("panel_card_selected" if sel else "panel_card", 8, 8)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, box)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		b.add_child(col)
		var ring := UITheme.YELLOW if sel else (Color.WHITE if owned else Color(0.4, 0.4, 0.5))
		var pic := GameUI.portrait(d.id, 104, ring)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not owned:
			pic.modulate = Color(0.5, 0.5, 0.6)
		col.add_child(pic)
		var nm := GameUI.label(d.display_name, UITheme.FS_H2, UITheme.INK if sel else UITheme.TEXT, 0 if sel else 6)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nm)
		var tag: Control
		if sel:
			tag = GameUI.badge("✓ " + tr("GARAGE_KART_ACTIVE"), UITheme.INK, UITheme.FS_BODY, UITheme.YELLOW)
		elif owned:
			tag = GameUI.badge(tr("GARAGE_KART_PICK"), Color("1f6fd1"), UITheme.FS_BODY)
		else:
			tag = GameUI.money_chip(KartShop.price(d.id), 22)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in tag.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tag)
		var id := d.id
		b.pressed.connect(func(): pick_kart(id))
		my_karts.add_child(b)


## Owned: race with it from now on (garage switches to it). Locked: buy it.
func pick_kart(id: String) -> void:
	AudioManager.play_ui("ui_confirm")
	if SaveManager.is_kart_owned(id):
		SaveManager.set_selected_kart(id)
		Game.race_config.kart_id = id
		Game.goto(Game.State.GARAGE)
	else:
		new_kart_id = id
		shop_dialog = KartBuyDialog.open(root, id, confirm_buy, close_shop)


func open_buy() -> void:
	close_shop()
	if new_kart_id == "":
		return
	shop_dialog = KartBuyDialog.open(root, new_kart_id, confirm_buy, close_shop)


func shop_kind() -> String:
	return String(shop_dialog.get_meta("kind", "")) if shop_dialog and is_instance_valid(shop_dialog) else ""


func confirm_buy() -> void:
	var id := new_kart_id
	var r := SaveManager.buy_kart(id)
	close_shop()
	if r == "ok":
		AudioManager.play_ui("ui_confirm")
		note_label.text = tr("SHOP_YOURS") % RacerRoster.get_def(id).display_name
		if new_kart_btn:
			UITheme.sparkle_burst(new_kart_box, new_kart_box.get_global_rect().get_center(), 14)
		# 0.14.4: a new kart is the one you race with; the garage shows it.
		SaveManager.set_selected_kart(id)
		Game.race_config.kart_id = id
		_build_new_kart()
		refresh()
		if is_inside_tree():
			Game.goto.call_deferred(Game.State.GARAGE)
	elif r == "funds":
		open_buy()


func close_shop() -> void:
	if shop_dialog and is_instance_valid(shop_dialog):
		shop_dialog.queue_free()
		shop_dialog.get_parent().remove_child(shop_dialog)
	shop_dialog = null


func first_focus() -> Control:
	return done_btn


var orbit_pad: OrbitPad
var view_zoom := 1.0


func _add_orbit_pad() -> void:
	orbit_pad = OrbitPad.make(PANEL_W + 40.0)
	root.add_child(orbit_pad)
	orbit_pad.orbit.connect(func(rel: Vector2):
		stage.drag(rel.x * RacerSelect.ORBIT_RAD_PER_PX))
	orbit_pad.zoom.connect(func(f: float):
		view_zoom = clampf(view_zoom * f, 0.7, 1.35)
		_frame())
	orbit_pad.held.connect(func(on: bool):
		_dragging = on
		stage.held = on)


func _frame() -> void:
	if stage == null or stage.camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var t := clampf((aspect - 1.33) / (2.22 - 1.33), 0.0, 1.0)
	var dist := lerpf(8.0, 4.8, t)
	var shift := (vp.x * 0.5 - (vp.x - PANEL_W) * 0.5) / vp.x
	var x := shift * dist * 0.8
	stage.camera.fov = 40.0 * view_zoom
	stage.camera.position = Vector3(x, lerpf(2.1, 1.4, t), dist)
	stage.camera.look_at_from_position(stage.camera.position, Vector3(x, 0.62, 0))


## Ten-segment preview: stock part, current upgrades, next level (pulsing).
class PreviewBar:
	extends Control
	var base := 5.0
	var value := 5.0:
		set(v):
			value = v
			queue_redraw()
	var next := 5.0
	var color := UITheme.TURQUOISE
	var _t := 0.0

	func _init() -> void:
		clip_contents = true

	func _process(delta: float) -> void:
		_t += delta
		if next > value:
			queue_redraw()

	func _draw() -> void:
		var n := 10
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		for i in n:
			var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y))
			var fill := clampf(value - i, 0.0, 1.0)
			var nfill := clampf(next - i, 0.0, 1.0)
			draw_style_box(UITheme.rounded(Color(UITheme.INK, 0.4), 5, 0, Color.TRANSPARENT, 0), r.grow(1.0))
			draw_style_box(UITheme.rounded(Color(1, 1, 1, 0.14), 4, 0, Color.TRANSPARENT, 0), r)
			if nfill > fill:
				var a := 0.35 + 0.25 * sin(_t * 5.0)
				draw_style_box(UITheme.rounded(Color(UITheme.YELLOW, a), 4, 0, Color.TRANSPARENT, 0), _part(r, nfill))
			if fill > 0.0:
				var c := color if i >= int(base) else color.darkened(0.25)
				draw_style_box(UITheme.rounded(c, 4, 0, Color.TRANSPARENT, 0), _part(r, fill))

	## Fill rect clamped to its rounded segment (never past the track end).
	func _part(r: Rect2, f: float) -> Rect2:
		var w := clampf(r.size.x * f, minf(8.0, r.size.x), r.size.x)
		return Rect2(r.position, Vector2(w, r.size.y)).intersection(Rect2(Vector2.ZERO, size))
