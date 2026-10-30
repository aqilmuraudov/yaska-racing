extends SceneTree
func _init():
	print(JSON.stringify(Economy.simulate_karts(300, 1, 0)))
	print(JSON.stringify(Economy.simulate_karts(300, 1, 40)))
	print(Economy.simulate(300,1).avg_race)
	quit()
