extends TestCase
## Round 10 (0.9.2): golden hour, gulls, flame glow, UI pop, turbo pop text.

var _dd := 1


func before_each() -> void:
	_dd = int(Settings.values.graphics.decor_distance)


func after_each() -> void:
	Settings.values.graphics.decor_distance = _dd


func test_golden_hour_and_gulls() -> void:
	var env := RaceEnvironment.new()
	tree.root.add_child(env)
	env.build()
	check(env.sun.rotation_degrees.x > -40.0, "lower golden-hour sun")
	check(env.sun.light_color.b < 0.7, "warm sun colour")
	check_eq(env.gulls.size(), 4, "four gulls")
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	Settings.values.graphics.decor_distance = 1
	env._process(0.016)
	check(env.gulls[0].visible, "gulls on medium")
	Settings.values.graphics.decor_distance = 0
	env._process(0.016)
	check(not env.gulls[0].visible, "low quality hides gulls")
	check(env.gulls[0].get_child_count() == 0 and env.gulls[0] is MeshInstance3D, "plain meshes, no collision")
	cam.queue_free()
	env.queue_free()
	await tree.process_frame


func test_water_shader_tint() -> void:
	var sh: Shader = load("res://assets/materials/water.gdshader")
	check(sh.code.contains("sky_tint") and sh.code.contains("EMISSION"), "sky tint + glint")


func test_pop_in_and_bounce() -> void:
	var c := Control.new()
	c.size = Vector2(200, 100)
	tree.root.add_child(c)
	UITheme.pop_in(c)
	check(c.scale.x < 1.0, "starts small")
	for i in 30:
		await tree.process_frame
	await tree.create_timer(0.3).timeout
	check(is_equal_approx(c.scale.x, 1.0), "ends at full size")
	var b := Button.new()
	UITheme.style_button(b, "blue")
	UITheme.style_button(b, "lime")
	check_eq(b.pressed.get_connections().size(), 1, "press bounce connected once")
	c.queue_free()
	b.free()
