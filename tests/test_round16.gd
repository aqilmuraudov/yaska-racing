extends TestCase
## Round 16 (0.9.8): Heydar Aliyev Center, Flame Towers and Government House
## remodelled; Baku Eye cabins. Road clearance is covered by
## test_round4_bugs.test_landmarks_and_decor_clear_of_road.


func test_heydar_aliyev_wave() -> void:
	var m: ArrayMesh = LandmarkKit.get_mesh("heydar_aliyev")
	var bb := m.get_aabb()
	check(bb.size.x >= 180.0, "HAC is big (%.0f m long)" % bb.size.x)
	check(bb.size.y >= 45.0, "HAC peak is tall (%.0f m)" % bb.size.y)
	# 0.15.3 (photos): low arch left, dip, tall portal, long low wing right.
	var low_arch := LandmarkKit.hac_height(0.12)
	var dip := LandmarkKit.hac_height(0.27)
	var peak := LandmarkKit.hac_height(0.47)
	var wing := LandmarkKit.hac_height(0.75)
	check(peak > low_arch and low_arch > dip, "low arch, dip, tall portal")
	check(wing > 5.0 and wing < low_arch, "long low wing on the right")
	check(LandmarkKit.hac_height(0.55) < peak * 0.6, "steep right side of the portal")
	check(LandmarkKit.hac_height(0.0) < 0.5 and LandmarkKit.hac_height(1.0) < 0.5, "shell sweeps down to the plaza at both ends")
	var lip := LandmarkKit.hac_point(0.47, 1.0)
	check(lip.y > 15.0 and lip.y < peak, "front lip overhangs the glass at the peak")
	check(m.get_surface_count() >= 2, "white shell plus glass surfaces")


func test_flame_towers_shape() -> void:
	var defs := LandmarkKit.flame_defs()
	check(defs.size() == 3, "three towers")
	var real := [182.0, 165.0, 161.0]
	for i in 3:
		var ratio: float = defs[i][0] / defs[0][0]
		check(absf(ratio - real[i] / real[0]) < 0.03, "height ratio of tower %d follows the real towers" % i)
	for i in 3:
		for j in range(i + 1, 3):
			var gap: float = (defs[i][2] as Vector3).distance_to(defs[j][2]) - (defs[i][1] + defs[j][1]) * 1.1
			check(gap > 10.0, "towers %d/%d stand apart (gap %.0f m)" % [i, j, gap])
	var tip := LandmarkKit.flame_point(0.0, 1.0, 120.0, 17.0)
	var base := LandmarkKit.flame_point(0.0, 0.0, 120.0, 17.0)
	check(tip.x < 0.0 and base.x > 15.0, "pointed tip leans over the inner side")
	var w30 := LandmarkKit.flame_point(0.0, 0.3, 120.0, 17.0).x - LandmarkKit.flame_point(0.5, 0.3, 120.0, 17.0).x
	var w80 := LandmarkKit.flame_point(0.0, 0.8, 120.0, 17.0).x - LandmarkKit.flame_point(0.5, 0.8, 120.0, 17.0).x
	check(w80 < w30 * 0.75, "curls in towards the tip (real towers stay wide to ~half height)")
	check(LandmarkKit.get_mesh("flame_towers").get_aabb().size.y >= 119.0, "tallest tower ~120 m")


func test_government_house_massing() -> void:
	var bb := LandmarkKit.get_mesh("government_house").get_aabb()
	check(bb.size.x >= 170.0, "long facade (%.0f m)" % bb.size.x)
	check(bb.size.y >= 55.0, "loggia towers with needles above the roof (%.0f m)" % bb.size.y)
	check(absf(bb.position.x + bb.end.x) < 1.0, "symmetric")
	check(LandmarkKit.get_mesh("government_house_far").get_aabb().size.y >= 55.0, "far LOD keeps the silhouette")


func test_baku_eye_proportions() -> void:
	var bb := PropKit.get_mesh("wheel_ring").get_aabb()
	check(bb.size.x > 60.0 and bb.size.x < 70.0, "wheel ~60 m with cabins (%.0f m)" % bb.size.x)
