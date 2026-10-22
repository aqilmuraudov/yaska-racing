class_name ItemIcon
extends Control
## Draws item icons procedurally (no texture assets): turbo canister, shield,
## road trap and the "rolling" state. Shapes differ, not only colours.

var item: StringName = &"":
	set(v):
		item = v
		queue_redraw()
var rolling := false
var _roll_t := 0.0
const ROLL_ORDER := [&"turbo", &"shield", &"trap"]


func _process(delta: float) -> void:
	if rolling:
		_roll_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := r.get_center()
	var s := minf(size.x, size.y) * 0.5
	var it := item
	if rolling:
		it = ROLL_ORDER[int(_roll_t * 12.0) % ROLL_ORDER.size()]
	draw_icon(self, it, c, s)


static func draw_icon(ci: CanvasItem, it: StringName, c: Vector2, s: float) -> void:
	match it:
		&"turbo":
			# Canister body
			var body := Rect2(c + Vector2(-s * 0.32, -s * 0.55), Vector2(s * 0.64, s * 1.05))
			ci.draw_rect(body.grow(s * 0.06), Color("1b2a4a"))
			ci.draw_rect(body, Color("ff8a3d"))
			ci.draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.35), Vector2(body.size.x, body.size.y * 0.18)), Color("fffaf0"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.14, -s * 0.72), Vector2(s * 0.28, s * 0.18)), Color("d9dde3"))
			# Flame
			var pts := PackedVector2Array([c + Vector2(-s * 0.22, s * 0.52), c + Vector2(0, s * 0.95), c + Vector2(s * 0.22, s * 0.52)])
			ci.draw_colored_polygon(pts, Color("ffc93c"))
		&"shield":
			ci.draw_circle(c, s * 0.8, Color("1b2a4a"))
			ci.draw_circle(c, s * 0.7, Color("4fd8ff"))
			ci.draw_circle(c, s * 0.5, Color("bff3ff"))
			ci.draw_arc(c, s * 0.6, -2.4, -0.8, 12, Color.WHITE, s * 0.1)
		&"trap":
			var spikes := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				var rr := s * (0.85 if i % 2 == 0 else 0.5)
				spikes.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(spikes, Color("ffc93c"))
			ci.draw_circle(c, s * 0.45, Color("e0344b"))
			ci.draw_circle(c, s * 0.18, Color("1b2a4a"))
		_:
			pass
