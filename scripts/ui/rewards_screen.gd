class_name RewardsScreen
extends MenuScreen
## Rewards (0.8.3), kept simple and visual: the title is a header badge with
## one progress bar; two big tabs: "Günlük tapşırıqlar" (three task cards:
## icon, short text, progress bar, reward chip, "Alındı" when done — daily
## rewards are paid automatically at the race that completes them) and
## "Kuboklar" (one badge per trophy family: shiny when any tier is won,
## a silhouette otherwise, only the next goal with its progress; tap for the
## tiers). Kart paints and parts live in the Garage now. Progression logic
## is unchanged (Progression / SaveManager).

const STAT_ICONS := {"races": "mode_quick", "podiums": "trophy", "wins": "trophy", "drift_boosts": "hud_drift",
	"stars": "star", "daily_done": "star", "tutorial_done": "mode_school", "tt_runs": "mode_time"}

var tab_buttons: Array[Button] = []
var pages: Array[Control] = []
var daily_cards: Array = [] ## [{"id", "card", "done": bool, "bar"}]
var trophy_cards: Array = [] ## [{"stat", "card", "won", "total"}]
var title_badge: PanelContainer
var detail: PanelContainer
var current_tab := 0


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "REWARDS_TITLE"


static func stat_icon(stat: String) -> String:
	if stat.contains(":"):
		var kind := stat.get_slice(":", 1)
		return "mode_time" if kind.begins_with("tt_") else "flag_az"
	return String(STAT_ICONS.get(stat, "trophy"))


## Trophy families in display order: [{"stat", "tiers": Array}].
static func trophy_groups() -> Array:
	var out: Array = []
	var index := {}
	for t in Progression.trophies():
		var k := String(t.stat)
		if not index.has(k):
			index[k] = out.size()
			out.append({"stat": k, "tiers": []})
		out[index[k]].tiers.append(t)
	return out


func build() -> void:
	if stage and stage.turntable:
		stage.turntable.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.BLUE_DEEP, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	root.move_child(dim, 0)
	var data := SaveManager.data
	Progression.seed_from_old(data)
	Progression.ensure_daily(data)
	_build_title_badge()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", UITheme.GAP_M)
	body.add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", UITheme.GAP_M)
	col.add_child(tabs)
	for t in [["REWARDS_TAB_DAILY", "star"], ["REWARDS_TROPHIES", "trophy"], ["REWARDS_ALBUM", "star"]]: # 0.13.0 album
		var b := Button.new()
		b.text = tr(t[0])
		b.icon = UITheme.icon(t[1])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
		b.custom_minimum_size = Vector2(0, UITheme.H_BTN_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := tab_buttons.size()
		b.pressed.connect(func():
			AudioManager.play_ui("ui_move")
			show_tab(idx))
		tabs.add_child(b)
		tab_buttons.append(b)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	pages.append(_build_daily())
	pages.append(_build_trophies())
	pages.append(_build_album())
	for pg in pages:
		holder.add_child(pg)
	_build_detail()
	show_tab(0)


func show_tab(i: int) -> void:
	current_tab = i
	if i == 2: # 0.13.0: stickers count as seen once the album is really opened
		var stars := Progression.stat(SaveManager.data, "stars")
		if Stickers.new_count(SaveManager.data, stars) > 0:
			Stickers.mark_seen(SaveManager.data, stars)
			SaveManager.save_profile()
	for k in pages.size():
		pages[k].visible = k == i
		UITheme.style_button(tab_buttons[k], "yellow" if k == i else "blue", UITheme.FS_BTN)
	if detail:
		detail.visible = false


func _build_title_badge() -> void:
	var stars := Progression.stat(SaveManager.data, "stars")
	var cur := Progression.title_for(stars)
	var nxt := Progression.next_title(stars)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	title_badge = PanelContainer.new()
	title_badge.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.INK, 0.7), 34, 3, UITheme.YELLOW, 4))
	header.add_child(title_badge)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	title_badge.add_child(h)
	h.add_child(GameUI.icon_rect("star", 44))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(GameUI.label(tr(cur.name), 24, UITheme.YELLOW, 6))
	var b := GameUI.bar(stars - int(cur.stars), (int(nxt.stars) - int(cur.stars)) if not nxt.is_empty() else 1, UITheme.YELLOW, 14)
	if nxt.is_empty():
		b.value = b.max_value
	b.custom_minimum_size.x = 240
	v.add_child(b)
	title_badge.set_meta("bar", b)


# --- Daily ----------------------------------------------------------------------

func _build_daily() -> Control:
	var data := SaveManager.data
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", UITheme.GAP_L)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in data.daily.goals:
		var g := Progression.daily_goal(id)
		if g.is_empty():
			continue
		var done: bool = id in data.daily.done
		var value := int(g.target) if done else mini(int(data.daily.progress.get(id, 0)), int(g.target))
		var c := GameUI.card(Vector2(0, 0), done)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.custom_minimum_size = Vector2(260, 330)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 12)
		c.add_child(v)
		var ic := GameUI.icon_rect(stat_icon(String(g.stat)), 92)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var tl := GameUI.label(Progression.goal_text(g), 26, UITheme.TEXT, 8)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)
		var bh := HBoxContainer.new()
		bh.add_theme_constant_override("separation", 10)
		v.add_child(bh)
		var b := GameUI.bar(value, int(g.target), UITheme.LIME, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(b)
		bh.add_child(GameUI.label("%d/%d" % [value, int(g.target)], 22, UITheme.TEXT, 6))
		var state: Control
		if done:
			state = GameUI.badge("✓ " + tr("REWARDS_CLAIMED"), UITheme.LIME, 24, UITheme.INK)
		else:
			state = GameUI.money_chip(Progression.DAILY_COINS, 26)
		state.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(state)
		row.add_child(c)
		daily_cards.append({"id": id, "card": c, "done": done, "bar": b, "state": state})
	return row


# --- Trophies -------------------------------------------------------------------

# --- Album (0.13.0) ---------------------------------------------------------------

## Sticker album: 12 Baku stickers in a 4×3 grid. Open ones show the sticker
## and its name; locked ones a dark silhouette and the star goal. Opening
## the page clears the "new" count.
func _build_album() -> Control:
	var data := SaveManager.data
	var stars := Progression.stat(data, "stars")
	var scroll := ScrollContainer.new()
	scroll.name = "Album"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TouchScroll.attach(scroll)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UITheme.GAP_M)
	grid.add_theme_constant_override("v_separation", UITheme.GAP_M)
	scroll.add_child(grid)
	var new_from := int(data.get(Stickers.SEEN_KEY, 0))
	for i in Stickers.LIST.size():
		var s: Dictionary = Stickers.LIST[i]
		var open := Stickers.is_unlocked(i, stars)
		var card := PanelContainer.new()
		card.name = "Sticker_" + String(s.id)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UITheme.art_box("panel_card_selected" if open else "panel_card", 12, 6))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var pic := TextureRect.new()
		pic.texture = Stickers.texture(String(s.id), not open)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(118, 118)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pic)
		if open:
			var l := GameUI.label(tr(Stickers.name_key(String(s.id))), 18, UITheme.TEXT, 5)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
			l.custom_minimum_size = Vector2(110, 0)
			v.add_child(l)
			if i >= new_from:
				var nb := GameUI.badge(tr("CITY_NEW"), Color("e8384f"), 16)
				nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				v.add_child(nb)
		else:
			var chip := GameUI.chip("star", str(int(s.stars)), 20)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(chip)
		grid.add_child(card)
	return scroll


func _build_trophies() -> Control:
	var data := SaveManager.data
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TouchScroll.attach(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UITheme.GAP_M)
	grid.add_theme_constant_override("v_separation", UITheme.GAP_M)
	scroll.add_child(grid)
	for grp in trophy_groups():
		var tiers: Array = grp.tiers
		var won := 0
		var next: Dictionary = {}
		for t in tiers:
			if t.id in data.trophies:
				won += 1
			elif next.is_empty():
				next = t
		var c := Button.new() # tappable card
		c.custom_minimum_size = Vector2(0, 132)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_stylebox_override("normal", UITheme.art_box("panel_card_selected" if won > 0 else "panel_card", 12, 8))
		c.add_theme_stylebox_override("hover", c.get_theme_stylebox("normal"))
		c.add_theme_stylebox_override("pressed", UITheme.art_box("panel_card_selected", 12, 8))
		c.add_theme_stylebox_override("focus", UITheme.rounded(Color.TRANSPARENT, 22, 3, UITheme.YELLOW, 0))
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -12
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(h)
		var ic := GameUI.icon_rect(stat_icon(String(grp.stat)), 70)
		if won == 0:
			ic.modulate = Color(0.08, 0.14, 0.32, 0.85) # locked silhouette
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var dots := GameUI.label("★".repeat(won) + "☆".repeat(tiers.size() - won), 20, UITheme.YELLOW, 4)
		v.add_child(dots)
		if next.is_empty():
			v.add_child(GameUI.label(tr("REWARDS_ALL_DONE"), 22, UITheme.LIME, 6))
		else:
			var nl := GameUI.label(Progression.trophy_text(next), 18, UITheme.TEXT, 5)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.max_lines_visible = 2
			v.add_child(nl)
			var b := GameUI.bar(mini(Progression.stat(data, String(next.stat)), int(next.target)), int(next.target), UITheme.YELLOW, 14)
			v.add_child(b)
		for n in [h, v]:
			for ch in n.get_children():
				if ch is Control:
					ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g2: Dictionary = grp
		c.pressed.connect(func():
			AudioManager.play_ui("ui_confirm")
			show_detail(g2))
		grid.add_child(c)
		trophy_cards.append({"stat": grp.stat, "card": c, "won": won, "total": tiers.size()})
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(scroll)
	return page


func _build_detail() -> void:
	detail = PanelContainer.new()
	detail.add_theme_stylebox_override("panel", UITheme.art_box("panel_blue", 26, 18))
	detail.visible = false
	detail.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(detail)


## Tier list of one trophy family (opened by tapping its badge).
func show_detail(grp: Dictionary) -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var data := SaveManager.data
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	detail.add_child(v)
	for t in grp.tiers:
		var got: bool = t.id in data.trophies
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		var ic := GameUI.icon_rect("trophy", 40)
		if not got:
			ic.modulate = Color(0.08, 0.14, 0.32, 0.85)
		h.add_child(ic)
		var l := GameUI.label(Progression.trophy_text(t), 22, UITheme.LIME if got else UITheme.TEXT, 6)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 380
		h.add_child(l)
		h.add_child(GameUI.money_chip(int(t.coins), 20))
	var close := MenuScreen.make_button(tr("MENU_CONTINUE"), func(): detail.visible = false)
	close.custom_minimum_size = Vector2(0, UITheme.H_BTN_SMALL)
	UITheme.style_button(close, "yellow", UITheme.FS_BTN_SMALL)
	v.add_child(close)
	detail.visible = true
	detail.reset_size()
	await get_tree().process_frame
	detail.reset_size()
	detail.position = (root.size - detail.size) * 0.5


func first_focus() -> Control:
	return back_button
