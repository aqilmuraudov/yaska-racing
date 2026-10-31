class_name ResultsScreen
extends Control
## Game-style results (0.8.3): a big place medal ("1-ci yer!"), a NEW
## RECORD badge, a short podium list with racer portraits (top three, plus
## the player's own row when lower; only the player's time is shown, no
## projected "~" times), one big money counter that counts up, the stars won
## and up to three small unlock cards. Buttons sit outside the scrolling
## part, so they are always fully on screen (16:9, 19.5:9, 20:9, 4:3).
## Rewards are applied once per event (SaveManager ledger).

const PANEL_W := 560.0
const MARGIN := 14
const MAX_CARDS := 3
const COUNT_TIME := 1.1

var race: RaceManager
var panel: PanelContainer
var scroll: ScrollContainer
var mid: VBoxContainer
var medal: GameUI.Medal
var place_label: Label
var record_badge: PanelContainer
var rows_box: VBoxContainer
var money_chip: PanelContainer
var money_label: Label
var star_chip: PanelContainer
var cards_row: HBoxContainer
var ad_btn: Button
var retry_btn: Button
var menu_btn: Button
var buttons_row: HBoxContainer
var money_target := 0
var goals_box: VBoxContainer
var goals_panel: PanelContainer
var goals_row: HBoxContainer
var shown_rows: Array = [] ## result rows on screen (tests)
var _money_shown := 0
var _count_tw: Tween
var _event_id := ""
var _earned := 0


func setup(p_race: RaceManager) -> void:
	race = p_race
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	# Docked right so the winner's celebration stays visible on the left.
	var dock := MarginContainer.new()
	dock.anchor_left = 1.0
	dock.anchor_right = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = -(PANEL_W + MARGIN * 2)
	for side in ["left", "right", "top", "bottom"]:
		dock.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(dock)
	panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dock.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	# Header: medal + "1-ci yer!" + NEW RECORD
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	medal = GameUI.medal(1, 92)
	head.add_child(medal)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	place_label = GameUI.label("", 46, UITheme.YELLOW, 12)
	hv.add_child(place_label)
	record_badge = GameUI.badge(tr("HUD_NEW_RECORD"), UITheme.CORAL, 22)
	record_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hv.add_child(record_badge)
	# Middle part scrolls if a screen is ever too short; buttons never do.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	mid = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	scroll.add_child(mid)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	mid.add_child(rows_box)
	var gains := HBoxContainer.new()
	gains.add_theme_constant_override("separation", 12)
	gains.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(gains)
	money_chip = GameUI.chip("manat", "+0", 40)
	gains.add_child(money_chip)
	money_label = money_chip.get_meta("value")
	star_chip = GameUI.chip("star", "+0", 34, Color(UITheme.INK, 0.72), Color.WHITE)
	gains.add_child(star_chip)
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 10)
	mid.add_child(cards_row)
	ad_btn = Button.new()
	ad_btn.text = tr("RESULTS_AD_DOUBLE")
	ad_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN_SMALL)
	UITheme.style_button(ad_btn, "lime", UITheme.FS_BTN_SMALL)
	ad_btn.pressed.connect(_on_ad)
	mid.add_child(ad_btn)
	# Next race goals (0.9.0): three small pills in their own card at the
	# bottom left, over the 3D scene, so the results panel never scrolls.
	goals_box = VBoxContainer.new()
	goals_box.add_theme_constant_override("separation", 4)
	var gpanel := PanelContainer.new()
	gpanel.name = "GoalsPanel"
	gpanel.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.BLUE_DEEP, 0.85), 22, 3, Color(UITheme.YELLOW, 0.8), 12))
	gpanel.anchor_top = 1.0
	gpanel.anchor_bottom = 1.0
	gpanel.offset_left = MARGIN
	gpanel.offset_bottom = -MARGIN
	gpanel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gpanel.add_child(goals_box)
	add_child(gpanel)
	goals_panel = gpanel
	var gh := GameUI.label(tr("GOALS_NEXT"), 17, UITheme.YELLOW, 5)
	gh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goals_box.add_child(gh)
	goals_row = HBoxContainer.new()
	goals_row.add_theme_constant_override("separation", 6)
	goals_box.add_child(goals_row)
	buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 12)
	v.add_child(buttons_row)
	retry_btn = Button.new()
	retry_btn.text = tr("RESULTS_RETRY")
	retry_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(retry_btn, "yellow", UITheme.FS_BTN)
	retry_btn.icon = UITheme.icon("restore")
	retry_btn.expand_icon = false
	retry_btn.add_theme_constant_override("icon_max_width", 30)
	retry_btn.pressed.connect(func():
		AudioManager.play_ui("ui_confirm")
		if String(race.config.get("series", "")) == "cup":
			# Cup: no re-runs of a scored race; on to the standings.
			Game.goto(Game.State.CUP)
		else:
			race.restart())
	buttons_row.add_child(retry_btn)
	menu_btn = Button.new()
	menu_btn.text = tr("RESULTS_MENU")
	menu_btn.custom_minimum_size = Vector2(0, UITheme.H_BTN)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(menu_btn, "blue", UITheme.FS_BTN)
	menu_btn.pressed.connect(func():
		AudioManager.play_ui("ui_back")
		race.quit_to_menu())
	buttons_row.add_child(menu_btn)


static func place_text(place: int) -> String:
	return TranslationServer.translate("RESULTS_PLACE_%d" % clampi(place, 1, 8))


## Rows to show: the top three, plus the player's row when lower.
static func pick_rows(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		if int(r.place) <= 3 or bool(r.is_player):
			out.append(r)
	return out


## Unlock cards: [{"icon", "text"}], at most MAX_CARDS (the last one says
## "+N" when there are more).
static func make_cards(res: Dictionary) -> Array:
	var all: Array = []
	var before := int(res.get("stars_total", 0))
	var after := before + int(res.get("stars_added", 0))
	for i in range(1, KartPaints.count()):
		if not KartPaints.is_unlocked(i, before) and KartPaints.is_unlocked(i, after):
			all.append({"icon": "garage", "text": TranslationServer.translate("CARD_PAINT")})
	for c in res.get("unlock_cards", []):
		all.append(c)
	if all.is_empty():
		for u in res.get("unlocks", []): # older result dicts: text lines only
			all.append({"icon": "trophy", "text": short_text(String(u))})
	if all.size() > MAX_CARDS:
		var rest := all.size() - (MAX_CARDS - 1)
		all = all.slice(0, MAX_CARDS - 1)
		all.append({"icon": "star", "text": "+%d" % rest, "more": true})
	return all


## "Kubok: 5 yarışı bitir (+30 qəpik)" -> "5 yarışı bitir"
static func short_text(s: String) -> String:
	var i := s.find(" (")
	if i > 0:
		s = s.substr(0, i)
	var c := s.find(": ")
	if c > 0 and c < 14:
		s = s.substr(c + 2)
	return s.trim_suffix("!")


func show_results(res: Dictionary) -> void:
	var p: Dictionary = res.get("player", {})
	var place := int(p.get("place", 0)) if not p.is_empty() else 0
	medal.visible = place > 0
	medal.place = maxi(place, 1)
	place_label.text = tr("RESULTS_PLACE_BIG") % place_text(place) if place > 0 else tr("RESULTS_TITLE")
	place_label.add_theme_color_override("font_color", GameUI.medal_color(place) if place <= 3 else UITheme.TEXT)
	var imp: Dictionary = res.get("improved", {})
	record_badge.visible = bool(imp.get("lap", false)) or bool(imp.get("race", false))
	# Ranking rows
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	shown_rows = pick_rows(res.get("rows", []))
	var last_place := 0
	for row in shown_rows:
		if int(row.place) > last_place + 1 and last_place > 0:
			var dots := GameUI.label("•••", 20, UITheme.TEXT_DIM, 0)
			dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rows_box.add_child(dots)
		last_place = int(row.place)
		rows_box.add_child(_row(row))
	# Money (counts up) and stars
	_event_id = String(res.get("event_instance_id", ""))
	var granted := int(res.get("reward", 0))
	_earned = granted
	money_target = granted
	money_chip.visible = granted > 0 or not res.get("already_rewarded", false)
	_count_to(granted)
	var st := int(res.get("stars", 0))
	star_chip.get_meta("value").text = "+%d" % st
	star_chip.visible = st > 0
	# Unlock cards
	for c in cards_row.get_children():
		cards_row.remove_child(c)
		c.queue_free()
	for cd in make_cards(res):
		cards_row.add_child(_card(cd))
	cards_row.visible = cards_row.get_child_count() > 0
	for c in goals_row.get_children():
		goals_row.remove_child(c)
		c.queue_free()
	var nxt: Array = res.get("next_goals", [])
	for g in nxt:
		goals_row.add_child(_goal_pill(g))
	goals_box.get_parent().visible = not nxt.is_empty()
	goals_box.visible = not nxt.is_empty()
	ad_btn.visible = RewardedAds.is_available() and granted > 0 and not _event_id.is_empty()
	ad_btn.disabled = false
	visible = true
	_fit.call_deferred()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	medal.pivot_offset = medal.custom_minimum_size * 0.5
	medal.scale = Vector2.ONE * 0.3
	create_tween().tween_property(medal, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 0.11.2: race is null in UI tests (setup(null)); the old line crashed there
	# and the button text/icon/focus below were never set or tested.
	var cup_next := race != null and String(race.config.get("series", "")) == "cup"
	retry_btn.text = tr("CUP_STANDINGS_BTN") if cup_next else tr("RESULTS_RETRY")
	retry_btn.icon = UITheme.icon("trophy" if cup_next else "restore")
	retry_btn.grab_focus()


func _row(row: Dictionary) -> Control:
	var me := bool(row.is_player)
	var box := PanelContainer.new()
	var bg := Color(UITheme.YELLOW, 0.32) if me else Color(UITheme.INK, 0.35)
	box.add_theme_stylebox_override("panel", UITheme.rounded(bg, 22, 3 if me else 0, UITheme.YELLOW, 4))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	h.add_child(GameUI.medal(int(row.place), 46))
	h.add_child(GameUI.portrait(String(row.get("kart", "")), 50, UITheme.YELLOW if me else Color.WHITE))
	var nl := GameUI.label(String(row.name), 28, UITheme.YELLOW if me else UITheme.TEXT, 8)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nl)
	if me and bool(row.get("finished", false)):
		h.add_child(GameUI.label(RaceHUD.format_time(float(row.time)), 26, UITheme.TEXT, 8))
	return box


## One compact chip per goal (0.9.1): icon + short text + reward, one line.
func _goal_pill(g: Dictionary) -> Control:
	var c := PanelContainer.new()
	c.name = "GoalChip"
	c.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.INK, 0.4), 18, 2, Color(UITheme.YELLOW, 0.7), 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	c.add_child(h)
	var ic := GameUI.icon_rect(RaceGoals.icon(g), 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := GameUI.label(RaceGoals.short_text(g), 18, UITheme.TEXT, 5)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var m := GameUI.label("+" + Money.format(int(g.reward)), 16, UITheme.YELLOW, 5)
	m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(m)
	return c


func _card(cd: Dictionary) -> Control:
	# Compact unlock chip (0.9.0): icon + short text in one row so the next
	# race goals fit under it without scrolling.
	var c := GameUI.card(Vector2(0, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(h)
	if bool(cd.get("more", false)):
		h.add_child(GameUI.label(String(cd.text), 24, UITheme.YELLOW, 8))
		return c
	var ic: Control
	if cd.has("image"): # 0.13.0 sticker unlock: the sticker itself
		var tr_img := TextureRect.new()
		tr_img.texture = load(String(cd.image)) if ResourceLoader.exists(String(cd.image)) else null
		tr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_img.custom_minimum_size = Vector2(40, 40)
		tr_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic = tr_img
	else:
		ic = GameUI.icon_rect(String(cd.get("icon", "trophy")), 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := GameUI.label(String(cd.text), 17, UITheme.TEXT, 5)
	# One line; long unlock names end in "…" instead of growing the panel.
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.custom_minimum_size = Vector2(104, 0)
	l.tooltip_text = String(cd.text)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return c


func _count_to(target: int) -> void:
	if _count_tw and _count_tw.is_valid():
		_count_tw.kill()
	_set_money(0)
	if target <= 0:
		return
	_count_tw = create_tween()
	_count_tw.tween_interval(0.35)
	_count_tw.tween_method(_set_money, 0, target, COUNT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_count_tw.tween_callback(func(): UITheme.bounce(money_chip, 0.15))


func _set_money(v: int) -> void:
	_money_shown = v
	money_label.text = Money.format_delta(v)


## Jumps the counter to its final value (tests, skipping).
func finish_count() -> void:
	if _count_tw and _count_tw.is_valid():
		_count_tw.kill()
	_set_money(money_target)


func money_shown() -> int:
	return _money_shown


## The scroll area takes its content height, but never more than the screen
## leaves after the header and the (always visible) buttons.
func _fit() -> void:
	if not is_instance_valid(scroll):
		return
	var other := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var avail := size.y - MARGIN * 2.0 - other
	scroll.custom_minimum_size.y = clampf(mid.get_combined_minimum_size().y, 0.0, maxf(avail, 60.0))
	# Next goals: never under the results panel; shrink a little on narrow screens.
	if is_instance_valid(goals_panel):
		var free_w := size.x - (PANEL_W + MARGIN * 2) - MARGIN * 2.0
		var w := goals_panel.get_combined_minimum_size().x
		var k := clampf(free_w / maxf(w, 1.0), 0.6, 1.0)
		goals_panel.pivot_offset = Vector2(0, goals_panel.size.y)
		goals_panel.scale = Vector2.ONE * k


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(scroll):
		_fit.call_deferred()


## Rewarded-ad hook: "double reward" (hidden while no ad provider exists).
func _on_ad() -> void:
	ad_btn.disabled = true
	RewardedAds.show("double_reward", func(ok: bool):
		if ok:
			var extra := SaveManager.claim_ad_bonus(_event_id, _earned * (Economy.AD_MULTIPLIER - 1))
			if extra > 0:
				money_target = _earned + extra
				_count_to(money_target)
		ad_btn.visible = false)
