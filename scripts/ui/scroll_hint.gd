class_name ScrollHint
extends Control
## Makes a scrollable list obviously scrollable for children: a thick, rounded
## scrollbar that is always shown when there is more content, a soft fade at
## the edge that hides content, and a bouncing "more" chevron. Visual only:
## it never takes input, so drags that start on it still scroll (TouchScroll).
## Everything disappears when the list fits.
## Drawn as a sibling overlay on top of the ScrollContainer, never inside it.

var scroll: ScrollContainer
var _t := 0.0


static func attach(sc: ScrollContainer) -> ScrollHint:
	var h := ScrollHint.new()
	h.scroll = sc
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	style_bar(sc.get_v_scroll_bar())
	sc.get_parent().add_child.call_deferred(h)
	return h


static func style_bar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x = 14
	bar.add_theme_stylebox_override("scroll", UITheme.rounded(Color(UITheme.INK, 0.35), 7, 0, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("scroll_focus", UITheme.rounded(Color(UITheme.INK, 0.35), 7, 0, Color.TRANSPARENT, 0))
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(s, UITheme.rounded(UITheme.YELLOW, 7, 2, UITheme.INK, 0))


func remaining_below() -> float:
	var bar := scroll.get_v_scroll_bar()
	return maxf(bar.max_value - bar.page - bar.value, 0.0)


func remaining_above() -> float:
	return scroll.get_v_scroll_bar().value


func _process(delta: float) -> void:
	if scroll == null or not is_instance_valid(scroll):
		queue_free()
		return
	_t += delta
	# Follow the scroll container's rect (it may move with layout changes).
	global_position = scroll.global_position
	size = scroll.size
	visible = scroll.is_visible_in_tree()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var below := remaining_below()
	var above := remaining_above()
	var w := size.x - 18.0
	if above > 2.0:
		_fade(Rect2(0, 0, w, 36), true)
	if below > 2.0:
		_fade(Rect2(0, size.y - 46, w, 46), false)
		# Bouncing "more below" chevron in a yellow bubble.
		var c := Vector2(w * 0.5, size.y - 28 + sin(_t * 5.0) * 5.0)
		draw_circle(c + Vector2(0, 3), 22, Color(UITheme.INK, 0.35))
		draw_circle(c, 22, UITheme.INK)
		draw_circle(c, 19, UITheme.YELLOW)
		draw_polyline(PackedVector2Array([c + Vector2(-9, -4), c + Vector2(0, 5), c + Vector2(9, -4)]), UITheme.INK, 5.0, true)


func _fade(r: Rect2, top: bool) -> void:
	var steps := 8
	for i in steps:
		var a := 0.42 * (1.0 - float(i) / steps) if top else 0.42 * float(i + 1) / steps
		var y := r.position.y + r.size.y * float(i) / steps
		draw_rect(Rect2(r.position.x, y, r.size.x, r.size.y / steps + 0.5), Color(UITheme.INK, a))

