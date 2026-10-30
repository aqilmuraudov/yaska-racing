class_name KartBuyDialog
extends RefCounted
## 0.11.0: the "buy this kart?" pop-up as a helper, so the Garage can sell
## karts too (same look as Kart select's dialog). kind = "confirm" | "funds".

## Builds the dialog over `root`. on_confirm is called by the lime button;
## on_close by cancel / OK. Returns the overlay (free it to close).
static func open(root: Control, racer_id: String, on_confirm: Callable, on_close: Callable) -> Control:
	var d := RacerRoster.get_def(racer_id)
	var miss := KartShop.missing(racer_id, SaveManager.get_money())
	AudioManager.play_ui("ui_back" if miss > 0 else "ui_confirm")
	var over := Control.new()
	over.name = "ShopDialog"
	over.set_meta("kind", "funds" if miss > 0 else "confirm")
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
	panel.add_child(v)
	var por := GameUI.portrait(racer_id, 120, UITheme.YELLOW)
	por.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(por)
	var title := GameUI.label(TranslationServer.translate("SHOP_CONFIRM") % d.kart_name if miss == 0 else TranslationServer.translate("SHOP_NO_MONEY"), 36, UITheme.YELLOW if miss == 0 else UITheme.CORAL, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if miss > 0:
		var ml := GameUI.label(TranslationServer.translate("SHOP_MISSING") % Money.format(miss), 28, UITheme.TEXT, 8)
		ml.name = "Missing"
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ml)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 12)
	v.add_child(chips)
	if miss == 0:
		chips.add_child(GameUI.money_chip(KartShop.price(racer_id), 40))
	else:
		chips.add_child(GameUI.money_chip(SaveManager.get_money(), 28))
		chips.add_child(GameUI.label("/", 28, UITheme.TEXT_DIM, 0))
		chips.add_child(GameUI.money_chip(KartShop.price(racer_id), 28))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var first: Button
	if miss == 0:
		var ok := MenuScreen.make_button(TranslationServer.translate("SHOP_BUY"), on_confirm, true)
		ok.name = "Confirm"
		ok.custom_minimum_size = Vector2(0, UITheme.H_BTN)
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(ok, "lime", UITheme.FS_BTN)
		row.add_child(ok)
		var no := MenuScreen.make_button(TranslationServer.translate("SHOP_CANCEL"), on_close)
		no.custom_minimum_size = Vector2(0, UITheme.H_BTN)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(no, "blue", UITheme.FS_BTN)
		row.add_child(no)
		first = ok
	else:
		var close := MenuScreen.make_button(TranslationServer.translate("SHOP_OK"), on_close)
		close.name = "Ok"
		close.custom_minimum_size = Vector2(0, UITheme.H_BTN)
		close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(close, "yellow", UITheme.FS_BTN)
		row.add_child(close)
		first = close
	root.add_child(over)
	first.grab_focus.call_deferred()
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	UITheme.bounce(panel, 0.12)
	return over
