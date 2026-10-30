class_name GameUI
extends RefCounted
## Shared "game look" widgets (0.8.3): money/star chips, badges, chunky
## progress bars, medals and cards. Big friendly numbers and icons instead
## of text lines, so every info window reads like game UI.

const GOLD_MEDAL := Color("ffcf33")
const SILVER_MEDAL := Color("dfe8f3")
const BRONZE_MEDAL := Color("ff9f5a")
const PLAIN_MEDAL := Color("5fa8ff")


static func medal_color(place: int) -> Color:
	match place:
		1: return GOLD_MEDAL
		2: return SILVER_MEDAL
		3: return BRONZE_MEDAL
	return PLAIN_MEDAL


static func label(text: String, size: int, col := UITheme.TEXT, outline := 8, head := true) -> Label:
	var l := Label.new()
	l.text = text
	if head:
		l.add_theme_font_override("font", UITheme.heading_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", UITheme.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func icon_rect(icon_name: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UITheme.icon(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Rounded pill holding an icon and a big value. Returns the PanelContainer;
## the value Label is meta "value".
static func chip(icon_name: String, text: String, size := 28, bg := Color(UITheme.INK, 0.72), col := UITheme.YELLOW) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.rounded(bg, 40, 3, Color(1, 1, 1, 0.22), 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	if icon_name != "":
		h.add_child(icon_rect(icon_name, size + 8))
	var l := label(text, size, col, 8)
	h.add_child(l)
	p.set_meta("value", l)
	return p


static func money_chip(amount: int, size := 28) -> PanelContainer:
	return chip("manat", Money.format(amount), size)


## Small coloured badge with short text (titles, NEW RECORD, "Alındı").
static func badge(text: String, bg: Color, size := 20, fg := UITheme.TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.rounded(bg, 30, 3, Color(UITheme.INK, 0.6), 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, fg, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_meta("value", l)
	return p


## Chunky rounded progress bar (no numbers on it).
static func bar(value: float, max_value: float, col := UITheme.LIME, height := 18.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maxf(max_value, 1.0)
	b.value = clampf(value, 0.0, b.max_value)
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := UITheme.rounded(Color(UITheme.INK, 0.55), int(height * 0.5), 2, Color(1, 1, 1, 0.18), 0)
	var fg := UITheme.rounded(col, int(height * 0.5), 0, Color.TRANSPARENT, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


## Panel with the glossy card art.
static func card(min_size := Vector2.ZERO, selected := false) -> PanelContainer:
	var c := PanelContainer.new()
	c.custom_minimum_size = min_size
	c.add_theme_stylebox_override("panel", UITheme.art_box("panel_card_selected" if selected else "panel_card", 16, 10))
	return c


## Round medal with the place number.
class Medal:
	extends Control
	var place := 1:
		set(v):
			place = v
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var col := GameUI.medal_color(place)
		# ribbon tails
		for sx in [-1.0, 1.0]:
			var pts := PackedVector2Array([c + Vector2(sx * r * 0.25, r * 0.4), c + Vector2(sx * r * 0.85, r * 1.05),
				c + Vector2(sx * r * 0.45, r * 0.95), c + Vector2(0, r * 0.6)])
			draw_colored_polygon(pts, UITheme.CORAL if sx < 0 else UITheme.SKY)
		draw_circle(c, r, UITheme.INK)
		draw_circle(c, r - 4.0, col.darkened(0.18))
		draw_circle(c - Vector2(0, 2), r - 9.0, col)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.45))
		var f := UITheme.heading_font()
		var fs := int(r * 1.15)
		var s := str(place)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := c + Vector2(-w * 0.5, fs * 0.36)
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(UITheme.INK, 0.8))
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


static func medal(place: int, px: float) -> Medal:
	var m := Medal.new()
	m.place = place
	m.custom_minimum_size = Vector2(px, px)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## Racer portrait in a round frame.
static func portrait(racer_id: String, px: float, ring := Color.WHITE) -> Control:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.SKY, 0.9), int(px * 0.5), 3, ring, 0))
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := RacerIcon.new()
	ic.def = RacerRoster.get_def(racer_id if RacerRoster.is_valid(racer_id) else RacerRoster.DEFAULT_ID)
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ic)
	return holder
