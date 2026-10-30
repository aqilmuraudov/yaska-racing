class_name RacerIcon
extends Control
## Small procedural face portrait of a racer's animal for selection cards
## (no textures). Drawn with the racer's own colours.

var def: RacerDefinition:
	set(v):
		def = v
		queue_redraw()


func _draw() -> void:
	if def == null:
		return
	var c := size * 0.5 + Vector2(0, size.y * 0.06)
	var r := minf(size.x, size.y) * 0.34
	var main := def.fur_main
	var light := def.fur_light
	var dark := def.fur_dark
	if def.species == "lamb":
		main = def.fur_light
	# Ears behind the head
	match def.species:
		"panda":
			for sx in [-1.0, 1.0]:
				draw_circle(c + Vector2(sx * r * 0.78, -r * 0.78), r * 0.36, dark)
		"fox", "cat":
			for sx in [-1.0, 1.0]:
				var base := c + Vector2(sx * r * 0.55, -r * 0.55)
				var tip := c + Vector2(sx * r * 0.95, -r * 1.35)
				var pts := PackedVector2Array([base + Vector2(-r * 0.32, 0), tip, base + Vector2(r * 0.32, 0)])
				draw_colored_polygon(pts, main)
				var inner := PackedVector2Array([base + Vector2(-r * 0.16, 0), base.lerp(tip, 0.7), base + Vector2(r * 0.16, 0)])
				draw_colored_polygon(inner, dark if def.species == "fox" else def.detail)
		"rabbit":
			for sx in [-1.0, 1.0]:
				var e := c + Vector2(sx * r * 0.38, -r * 1.25)
				_draw_ellipse(e, Vector2(r * 0.26, r * 0.7), main)
				_draw_ellipse(e + Vector2(0, r * 0.05), Vector2(r * 0.13, r * 0.52), def.detail)
		"dog":
			for sx in [-1.0, 1.0]:
				_draw_ellipse(c + Vector2(sx * r * 0.95, r * 0.05), Vector2(r * 0.28, r * 0.55), dark)
		"lamb":
			for sx in [-1.0, 1.0]:
				_draw_ellipse(c + Vector2(sx * r * 1.0, -r * 0.1), Vector2(r * 0.36, r * 0.17), light)
	if def.species == "girl":
		# Pigtails with pink ties behind the head, hair cap and bangs
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(sx * r * 0.92, -r * 0.82), r * 0.34, dark)
			draw_circle(c + Vector2(sx * r * 0.72, -r * 0.62), r * 0.12, Color("ff7fb2"))
		draw_circle(c + Vector2(0, -r * 0.08), r * 1.04, dark)
	# Head
	draw_circle(c, r, main)
	if def.species == "girl":
		draw_colored_polygon(_arc_poly(c + Vector2(0, -r * 0.08), r * 1.04, PI * 1.08, PI * 1.92), dark)
		var fc := c + Vector2(r * 0.62, -r * 0.62)
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(fc + Vector2(cos(a), sin(a)) * r * 0.13, r * 0.11, Color("ff7fb2"))
		draw_circle(fc, r * 0.09, Color("ffd84d"))
	if def.species == "lamb":
		for p in [Vector2(0, -0.85), Vector2(-0.45, -0.75), Vector2(0.45, -0.75), Vector2(-0.75, -0.4), Vector2(0.75, -0.4)]:
			draw_circle(c + p * r, r * 0.33, def.fur_main)
	if def.species == "cat":
		for i in 3:
			draw_line(c + Vector2((i - 1) * r * 0.25, -r * 0.95), c + Vector2((i - 1) * r * 0.22, -r * 0.62), dark, r * 0.1, true)
	# Face patches / muzzle
	match def.species:
		"panda":
			for sx in [-1.0, 1.0]:
				_draw_ellipse(c + Vector2(sx * r * 0.38, -r * 0.08), Vector2(r * 0.25, r * 0.32), dark)
		"fox":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, r * 0.05), c + Vector2(0, r * 0.95), c + Vector2(r * 0.75, r * 0.05), c + Vector2(0, r * 0.25)]), light)
		"dog", "lamb":
			_draw_ellipse(c + Vector2(0, r * 0.38), Vector2(r * 0.42, r * 0.32), light if def.species == "dog" else light.lightened(0.2))
		"cat", "rabbit":
			for sx in [-1.0, 1.0]:
				draw_circle(c + Vector2(sx * r * 0.14, r * 0.38), r * 0.18, light)
	# Eyes
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(sx * r * 0.38, -r * 0.08)
		_draw_ellipse(e, Vector2(r * 0.17, r * 0.21), Color.WHITE)
		_draw_ellipse(e + Vector2(0, r * 0.03), Vector2(r * 0.11, r * 0.15), Color("4a2a18") if def.species == "girl" else Color("1d1a22"))
		draw_circle(e + Vector2(-r * 0.04, -r * 0.04), r * 0.045, Color.WHITE)
	# Nose, smile, blush
	var nose := Color("ff8fa3") if def.species in ["cat", "rabbit"] else Color("2b1d1a")
	if def.species == "girl":
		_draw_ellipse(c + Vector2(0, r * 0.26), Vector2(r * 0.06, r * 0.04), main.darkened(0.15))
	else:
		_draw_ellipse(c + Vector2(0, r * 0.28), Vector2(r * 0.11, r * 0.08), nose)
	draw_arc(c + Vector2(0, r * 0.36), r * 0.14, 0.3, PI - 0.3, 10, Color("3a2420"), r * 0.05, true)
	for sx in [-1.0, 1.0]:
		_draw_ellipse(c + Vector2(sx * r * 0.62, r * 0.25), Vector2(r * 0.13, r * 0.07), Color(1, 0.6, 0.7, 0.8))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _arc_poly(center: Vector2, radius: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
