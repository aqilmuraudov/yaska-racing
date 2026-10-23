class_name UITheme
extends RefCounted
## The shared cheerful UI theme, built in code so every screen shares one
## look: rich blue / turquoise foundations, warm yellow-orange primary
## actions, coral / lime / violet accents, glossy dimensional buttons
## (9-patch art from tools/gen_ui_art.py), illustrated icons
## (tools/gen_icons.py), bold outlined typography and clear selected,
## pressed and disabled states. Also hosts small shared UI animations.

# Palette ----------------------------------------------------------------------
const INK := Color("0c2559") ## outlines, text shadows
const BLUE_DEEP := Color("123f9a")
const BLUE := Color("1f63cf")
const SKY := Color("2f7de1")
const TURQUOISE := Color("17b9c9")
const YELLOW := Color("ffd23f")
const ORANGE := Color("ff8a1f")
const CORAL := Color("ff5f6d")
const LIME := Color("6fcf3c")
const VIOLET := Color("8b5cf6")
const CREAM := Color("fff6df")
const TEXT := Color("ffffff")
const TEXT_DIM := Color(0.86, 0.93, 1.0, 0.86)
# Legacy names still used by HUD widgets (mapped onto the new palette).
const NAVY := BLUE
const NAVY_DEEP := INK
const NAVY_LIGHT := SKY
const POMEGRANATE := CORAL
const GOLD := YELLOW
const GRASS := LIME

const BODY_FONT := "res://assets/fonts/Nunito-Variable.ttf"
const HEAD_FONT := "res://assets/fonts/Baloo2-Variable.ttf"
const UI_ART := "res://assets/ui/"
const ICONS := "res://assets/icons/ui/"

static var _body: FontVariation
static var _bold: FontVariation
static var _head: FontVariation
static var _icons: Dictionary = {}


static func body_font() -> Font:
	if _body == null:
		_body = _variation(BODY_FONT, 700)
	return _body


static func bold_font() -> Font:
	if _bold == null:
		_bold = _variation(BODY_FONT, 900)
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


static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var p := ICONS + icon_name + ".svg"
		_icons[icon_name] = load(p) if ResourceLoader.exists(p) else null
	return _icons[icon_name]


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


## 9-patch box from the generated art (96 px sources, 34 px corners).
static func art_box(art: String, pad_x := 22, pad_y := 12, margin := 34) -> StyleBox:
	var p := UI_ART + art + ".png"
	if not ResourceLoader.exists(p):
		return rounded(SKY, 22, 3, INK, pad_y)
	var sb := StyleBoxTexture.new()
	sb.texture = load(p)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y + 6
	return sb


## Gives a Button the glossy look of one palette colour
## ("yellow", "orange", "blue", "turquoise", "coral", "lime", "violet").
static func style_button(b: Button, color := "blue", font_size := 26) -> void:
	var normal := art_box("btn_" + color)
	var pressed := art_box("btn_" + color + "_pressed")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", art_box("btn_grey"))
	var dark_text := color in ["yellow", "lime"]
	var fc := INK if dark_text else TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.5) if dark_text else Color(INK, 0.85))
	b.add_theme_constant_override("outline_size", 0 if dark_text else 6)
	b.add_theme_font_override("font", heading_font())
	b.add_theme_font_size_override("font_size", font_size)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 24

	# Panels
	t.set_stylebox("panel", "PanelContainer", art_box("panel_blue", 22, 18))
	t.set_stylebox("panel", "Panel", art_box("panel_blue", 22, 18))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", art_box("panel_card", 16, 12))
	t.set_type_variation("CardSelected", "PanelContainer")
	t.set_stylebox("panel", "CardSelected", art_box("panel_card_selected", 16, 12))
	t.set_type_variation("HudPill", "PanelContainer")
	t.set_stylebox("panel", "HudPill", art_box("panel_hud", 14, 6, 30))

	# Buttons: blue secondary by default; primary actions use style_button().
	var b_normal := art_box("btn_blue")
	var b_pressed := art_box("btn_blue_pressed")
	var b_hover := art_box("btn_turquoise")
	var b_disabled := art_box("btn_grey")
	var b_focus := StyleBoxFlat.new()
	b_focus.draw_center = false
	b_focus.set_corner_radius_all(30)
	b_focus.set_border_width_all(5)
	b_focus.border_color = YELLOW
	b_focus.expand_margin_left = 3
	b_focus.expand_margin_right = 3
	b_focus.expand_margin_top = 3
	b_focus.expand_margin_bottom = 1
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		t.set_stylebox("normal", type, b_normal)
		t.set_stylebox("hover", type, b_hover)
		t.set_stylebox("pressed", type, b_pressed)
		t.set_stylebox("hover_pressed", type, b_pressed)
		t.set_stylebox("disabled", type, b_disabled)
		t.set_stylebox("focus", type, b_focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, YELLOW)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.6))
		t.set_color("font_outline_color", type, Color(INK, 0.85))
		t.set_constant("outline_size", type, 6)
		t.set_font("font", type, heading_font())
		t.set_font_size("font_size", type, 26)
	t.set_color("font_hover_pressed_color", "Button", YELLOW)
	for type in ["CheckButton", "CheckBox"]:
		t.set_stylebox("pressed", type, b_normal)
		t.set_stylebox("hover_pressed", type, b_hover)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, TEXT)
	t.set_icon("checked", "CheckButton", _switch_texture(true, false))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false, false))
	t.set_icon("checked_disabled", "CheckButton", _switch_texture(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch_texture(false, true))

	# Big primary button (menus): warm yellow-orange.
	t.set_type_variation("BigButton", "Button")
	t.set_stylebox("normal", "BigButton", art_box("btn_yellow", 28, 14))
	t.set_stylebox("hover", "BigButton", art_box("btn_yellow", 28, 14))
	t.set_stylebox("pressed", "BigButton", art_box("btn_yellow_pressed", 28, 14))
	t.set_stylebox("hover_pressed", "BigButton", art_box("btn_yellow_pressed", 28, 14))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "BigButton", INK)
	t.set_constant("outline_size", "BigButton", 0)
	t.set_font("font", "BigButton", heading_font())
	t.set_font_size("font_size", "BigButton", 40)

	# Labels: white, bold, with a soft ink outline for legibility on 3D.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(INK, 0.75))
	t.set_constant("outline_size", "Label", 4)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", heading_font())
	t.set_font_size("font_size", "Title", 72)
	t.set_constant("outline_size", "Title", 16)
	t.set_color("font_outline_color", "Title", INK)
	t.set_color("font_shadow_color", "Title", Color(INK, 0.6))
	t.set_constant("shadow_offset_y", "Title", 6)
	t.set_constant("shadow_offset_x", "Title", 0)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", heading_font())
	t.set_font_size("font_size", "Heading", 42)
	t.set_constant("outline_size", "Heading", 12)
	t.set_color("font_outline_color", "Heading", INK)
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", TEXT_DIM)
	t.set_font_size("font_size", "Dim", 20)
	t.set_constant("outline_size", "Dim", 0)
	t.set_type_variation("HudBig", "Label")
	t.set_font("font", "HudBig", heading_font())
	t.set_font_size("font_size", "HudBig", 56)
	t.set_constant("outline_size", "HudBig", 14)
	t.set_color("font_outline_color", "HudBig", INK)
	t.set_type_variation("HudSmall", "Label")
	t.set_font("font", "HudSmall", heading_font())
	t.set_font_size("font_size", "HudSmall", 26)
	t.set_constant("outline_size", "HudSmall", 8)
	t.set_color("font_outline_color", "HudSmall", INK)

	# Sliders (developer panel only)
	var track := rounded(Color(INK, 0.9), 8, 0, Color.TRANSPARENT, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := rounded(TURQUOISE, 8, 0, Color.TRANSPARENT, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", rounded(YELLOW, 8, 0, Color.TRANSPARENT, 0))
	t.set_icon("grabber", "HSlider", _circle_texture(30, CREAM))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(34, YELLOW))
	t.set_icon("grabber_disabled", "HSlider", _circle_texture(30, Color(0.5, 0.5, 0.5)))
	t.set_stylebox("focus", "HSlider", b_focus)

	var popup := rounded(BLUE_DEEP, 16, 3, YELLOW, 8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", rounded(SKY, 10, 0, Color.TRANSPARENT, 6))
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_constant("v_separation", "PopupMenu", 14)

	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(1, 1, 1, 0.12)
	scroll.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", scroll)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(YELLOW, 0.9)
	grab.set_corner_radius_all(6)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return t


## Pill switch with a knob; "on" also shows a tick mark (not colour-only).
static func _switch_texture(on: bool, disabled: bool) -> ImageTexture:
	var w := 84
	var h := 44
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track_col := LIME if on else Color(0.55, 0.6, 0.7)
	if disabled:
		track_col = track_col.darkened(0.45)
	var r := h * 0.5
	var knob_c := Vector2(w - r, r) if on else Vector2(r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var outline := clampf(r - d, 0.0, 1.0)
			var inner := clampf(r - 3.0 - d, 0.0, 1.0)
			var col := Color(INK, outline).lerp(Color(track_col, 1.0), inner)
			col.a = outline
			var kd := p.distance_to(knob_c)
			var ka := clampf(r - 6.0 - kd, 0.0, 1.0)
			col = col.lerp(Color(1, 1, 1, 1.0), ka)
			if on and ka > 0.5:
				var lp := p - knob_c
				var on_tick := absf(lp.y - (lp.x * -1.0 + 2.0)) < 2.2 and lp.x > -1.0 and lp.x < 7.0 or absf(lp.y - (lp.x * 0.8 + 2.0)) < 2.2 and lp.x > -6.0 and lp.x <= 0.0
				if on_tick:
					col = Color(INK, 1.0)
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
			var col := color.lerp(INK, 1.0 - edge)
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


# Shared micro-animations -------------------------------------------------------

## Short squash-and-bounce on press / selection (respects pivot at centre).
static func bounce(c: Control, amount := 0.1) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A handful of sparkles that pop out of `pos` (global canvas coords) and fade.
static func sparkle_burst(parent: Control, pos: Vector2, count := 6, color := YELLOW) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var tex: Texture2D = load(UI_ART + "sparkle.png") if ResourceLoader.exists(UI_ART + "sparkle.png") else null
	if tex == null:
		return
	var local := parent.get_global_transform_with_canvas().affine_inverse() * pos
	for i in count:
		var s := TextureRect.new()
		s.texture = tex
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.modulate = color.lerp(Color.WHITE, randf() * 0.5)
		s.size = Vector2(22, 22)
		s.pivot_offset = s.size * 0.5
		var dir := Vector2.from_angle(TAU * float(i) / count + randf() * 0.5)
		# Start on a ring around the point so the burst frames, never hides, it.
		s.position = local - s.size * 0.5 + dir * 34.0
		s.scale = Vector2.ONE * 0.3
		parent.add_child(s)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", s.position + dir * randf_range(30.0, 55.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.6, 1.0), 0.2)
		tw.tween_property(s, "rotation", randf_range(-1.5, 1.5), 0.45)
		tw.tween_property(s, "modulate:a", 0.0, 0.25).set_delay(0.2)
		tw.chain().tween_callback(s.queue_free)


## Patterned blue backdrop for screens without a 3D stage.
static func pattern_backdrop() -> TextureRect:
	var r := TextureRect.new()
	var p := UI_ART + "pattern_blue.png"
	if ResourceLoader.exists(p):
		r.texture = load(p)
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
