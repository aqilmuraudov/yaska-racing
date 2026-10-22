class_name UITheme
extends RefCounted
## Builds the shared kart-racing UI theme in code so every menu shares one
## look: rounded panels, strong hierarchy, large legible text and explicit
## focus / pressed / disabled states.

const NAVY := Color("1b2a4a")
const NAVY_DEEP := Color("101a30")
const NAVY_LIGHT := Color("2c4170")
const TURQUOISE := Color("25c2c2")
const ORANGE := Color("ff8a3d")
const POMEGRANATE := Color("e0344b")
const CREAM := Color("f6ead0")
const GOLD := Color("ffc93c")
const GRASS := Color("5cc46a")
const TEXT := Color("fffaf0")
const TEXT_DIM := Color(1, 0.98, 0.94, 0.62)

const BODY_FONT := "res://assets/fonts/Nunito-Variable.ttf"
const HEAD_FONT := "res://assets/fonts/Baloo2-Variable.ttf"

static var _body: FontVariation
static var _bold: FontVariation
static var _head: FontVariation


static func body_font() -> Font:
	if _body == null:
		_body = _variation(BODY_FONT, 600)
	return _body


static func bold_font() -> Font:
	if _bold == null:
		_bold = _variation(BODY_FONT, 800)
	return _bold


static func heading_font() -> Font:
	if _head == null:
		_head = _variation(HEAD_FONT, 800)
	return _head


static func _variation(path: String, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	var base: FontFile = load(path)
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


static func rounded(bg: Color, radius: int = 18, border: int = 0, border_color: Color = Color.TRANSPARENT, pad: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.content_margin_left = pad + 6
	sb.content_margin_right = pad + 6
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 24

	# Panels
	var panel := rounded(Color(NAVY, 0.92), 26, 3, Color(1, 1, 1, 0.10), 18)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 5)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var card := rounded(Color(NAVY_LIGHT, 0.85), 20, 0, Color.TRANSPARENT, 12)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card)
	var pill := rounded(Color(NAVY_DEEP, 0.78), 22, 2, Color(1, 1, 1, 0.12), 8)
	t.set_type_variation("HudPill", "PanelContainer")
	t.set_stylebox("panel", "HudPill", pill)

	# Buttons
	var b_normal := rounded(NAVY_LIGHT, 20, 3, Color(1, 1, 1, 0.15), 12)
	var b_hover := rounded(NAVY_LIGHT.lightened(0.12), 20, 4, TURQUOISE, 12)
	var b_pressed := rounded(ORANGE.darkened(0.1), 20, 4, GOLD, 12)
	var b_disabled := rounded(Color(0.3, 0.33, 0.4, 0.5), 20, 2, Color(1, 1, 1, 0.05), 12)
	var b_focus := StyleBoxFlat.new()
	b_focus.draw_center = false
	b_focus.set_corner_radius_all(22)
	b_focus.set_border_width_all(5)
	b_focus.border_color = GOLD
	b_focus.expand_margin_left = 4
	b_focus.expand_margin_right = 4
	b_focus.expand_margin_top = 4
	b_focus.expand_margin_bottom = 4
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		t.set_stylebox("normal", type, b_normal)
		t.set_stylebox("hover", type, b_hover)
		t.set_stylebox("pressed", type, b_pressed)
		t.set_stylebox("hover_pressed", type, b_pressed)
		t.set_stylebox("disabled", type, b_disabled)
		t.set_stylebox("focus", type, b_focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, NAVY_DEEP)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.35))
		t.set_font("font", type, bold_font())
		t.set_font_size("font_size", type, 26)
	t.set_color("font_hover_pressed_color", "Button", NAVY_DEEP)
	# Toggles show state through the switch icon, not the panel colour.
	for type in ["CheckButton", "CheckBox"]:
		t.set_stylebox("pressed", type, b_normal)
		t.set_stylebox("hover_pressed", type, b_hover)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, TEXT)
	t.set_icon("checked", "CheckButton", _switch_texture(true, false))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false, false))
	t.set_icon("checked_disabled", "CheckButton", _switch_texture(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch_texture(false, true))

	# Big primary button (menus)
	t.set_type_variation("BigButton", "Button")
	t.set_stylebox("normal", "BigButton", rounded(POMEGRANATE, 26, 4, Color(1, 1, 1, 0.25), 16))
	t.set_stylebox("hover", "BigButton", rounded(POMEGRANATE.lightened(0.15), 26, 5, GOLD, 16))
	t.set_stylebox("pressed", "BigButton", rounded(GOLD, 26, 5, Color.WHITE, 16))
	t.set_font("font", "BigButton", heading_font())
	t.set_font_size("font_size", "BigButton", 36)

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", heading_font())
	t.set_font_size("font_size", "Title", 72)
	t.set_constant("outline_size", "Title", 10)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", heading_font())
	t.set_font_size("font_size", "Heading", 40)
	t.set_constant("outline_size", "Heading", 6)
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", TEXT_DIM)
	t.set_font_size("font_size", "Dim", 20)
	t.set_type_variation("HudBig", "Label")
	t.set_font("font", "HudBig", heading_font())
	t.set_font_size("font_size", "HudBig", 54)
	t.set_constant("outline_size", "HudBig", 10)
	t.set_type_variation("HudSmall", "Label")
	t.set_font("font", "HudSmall", bold_font())
	t.set_font_size("font_size", "HudSmall", 24)
	t.set_constant("outline_size", "HudSmall", 6)

	# Sliders
	var track := rounded(Color(NAVY_DEEP, 0.9), 8, 0, Color.TRANSPARENT, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := rounded(TURQUOISE, 8, 0, Color.TRANSPARENT, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", rounded(GOLD, 8, 0, Color.TRANSPARENT, 0))
	t.set_icon("grabber", "HSlider", _circle_texture(30, CREAM))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(34, GOLD))
	t.set_icon("grabber_disabled", "HSlider", _circle_texture(30, Color(0.5, 0.5, 0.5)))
	t.set_stylebox("focus", "HSlider", b_focus)

	# Option popups
	var popup := rounded(NAVY_DEEP, 16, 2, TURQUOISE, 8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", rounded(NAVY_LIGHT, 10, 0, Color.TRANSPARENT, 6))
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_constant("v_separation", "PopupMenu", 14)

	# Tabs
	t.set_stylebox("tab_selected", "TabBar", rounded(POMEGRANATE, 16, 0, Color.TRANSPARENT, 10))
	t.set_stylebox("tab_unselected", "TabBar", rounded(Color(NAVY_LIGHT, 0.8), 16, 0, Color.TRANSPARENT, 10))
	t.set_stylebox("tab_hovered", "TabBar", rounded(NAVY_LIGHT.lightened(0.15), 16, 0, Color.TRANSPARENT, 10))
	t.set_stylebox("tab_focus", "TabBar", b_focus)
	t.set_font("font", "TabBar", bold_font())
	t.set_font_size("font_size", "TabBar", 24)

	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(1, 1, 1, 0.08)
	scroll.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", scroll)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(TURQUOISE, 0.8)
	grab.set_corner_radius_all(6)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return t


## Pill switch with a knob; "on" also shows a tick mark (not colour-only).
static func _switch_texture(on: bool, disabled: bool) -> ImageTexture:
	var w := 76
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track_col := TURQUOISE if on else Color(0.35, 0.4, 0.5)
	if disabled:
		track_col = track_col.darkened(0.5)
	var r := h * 0.5
	var knob_c := Vector2(w - r, r) if on else Vector2(r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var col := Color(track_col, a)
			var kd := p.distance_to(knob_c)
			var ka := clampf(r - 4.0 - kd, 0.0, 1.0)
			col = col.lerp(Color(CREAM, 1.0), ka)
			if on and ka > 0.5:
				# Tick inside the knob
				var lp := p - knob_c
				var on_tick := absf(lp.y - (lp.x * -1.0 + 2.0)) < 2.0 and lp.x > -1.0 and lp.x < 7.0 or absf(lp.y - (lp.x * 0.8 + 2.0)) < 2.0 and lp.x > -6.0 and lp.x <= 0.0
				if on_tick:
					col = Color(NAVY_DEEP, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(size * 0.5 - d, 0.0, 1.0)
			var edge := clampf(size * 0.5 - 3.0 - d, 0.0, 1.0)
			var col := color.lerp(NAVY_DEEP, 1.0 - edge)
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)
