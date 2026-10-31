class_name TimeOfDay
extends RefCounted
## 0.10.1 Time of day for a race: Gündüz (day), Gün batımı (sunset), Gecə
## (night). Sky, sun/moon, ambient and fog per time, plus the shared
## emissive materials (lamp globes, lit windows, HAC skin, Flame Towers LED
## show). Purely visual: never touches physics, items or AI.

const IDS := ["day", "sunset", "night"]
const DEFAULT := "day"
const ICONS := {"day": "tod_day", "sunset": "tod_sunset", "night": "tod_night"}
const NAME_KEYS := {"day": "TOD_DAY", "sunset": "TOD_SUNSET", "night": "TOD_NIGHT"}


static func valid(id) -> String:
	return String(id) if String(id) in IDS else DEFAULT


## The player's choice from Race setup (saved in settings).
static func selected() -> String:
	return valid(Settings.get_value("gameplay", "time_of_day", DEFAULT))


static func params(id: String) -> Dictionary:
	match valid(id):
		"sunset":
			return {
				"sky_top": Color(0.3, 0.24, 0.55), "sky_horizon": Color(1.0, 0.55, 0.42),
				"ground_horizon": Color(0.95, 0.62, 0.55), "ground_bottom": Color(0.3, 0.22, 0.3),
				"sky_energy": 1.0, "sun_angle_max": 30.0, "sun_curve": 0.1,
				"sun_color": Color(1.0, 0.56, 0.3), "sun_energy": 1.55, "sun_pitch": -9.0, "sun_yaw": -150.0,
				"ambient_source": Environment.AMBIENT_SOURCE_SKY, "ambient_energy": 0.42, "ambient_color": Color(1.0, 0.72, 0.68),
				"exposure": Palette.ENV_EXPOSURE * 0.92, "fog": Color(0.92, 0.6, 0.58),
				"glow": 0.6, "led": 1.0, "lamps": 0.55, "windows": 0.45, "hac": 0.55, "floodlight": 0.6,
				"headlights": false,
			}
		"night":
			return {
				"sky_top": Color(0.01, 0.025, 0.09), "sky_horizon": Color(0.1, 0.15, 0.32),
				"ground_horizon": Color(0.08, 0.12, 0.24), "ground_bottom": Color(0.02, 0.03, 0.06),
				"sky_energy": 1.0, "sun_angle_max": 6.0, "sun_curve": 0.3,
				"sun_color": Color(0.62, 0.74, 1.0), "sun_energy": 0.6, "sun_pitch": -42.0, "sun_yaw": -150.0,
				# Flat blue-grey fill so the road and barriers stay readable.
				"ambient_source": Environment.AMBIENT_SOURCE_COLOR, "ambient_energy": 0.42, "ambient_color": Color(0.46, 0.54, 0.85), "saturation": 0.8,
				"exposure": Palette.ENV_EXPOSURE * 1.05, "fog": Color(0.07, 0.1, 0.2),
				"glow": 0.85, "led": 1.0, "lamps": 1.0, "windows": 1.0, "hac": 1.0, "floodlight": 1.0,
				"headlights": true,
			}
	return {
		"sky_top": Palette.SKY_TOP, "sky_horizon": Palette.SKY_HORIZON.lerp(Color(1.0, 0.8, 0.58), 0.35),
		"ground_horizon": Color(0.74, 0.84, 0.9), "ground_bottom": Color(0.36, 0.42, 0.42),
		"sky_energy": 1.05, "sun_angle_max": 22.0, "sun_curve": 0.12,
		"sun_color": Color(1.0, 0.82, 0.6), "sun_energy": 1.75, "sun_pitch": -30.0, "sun_yaw": -140.0,
		"ambient_source": Environment.AMBIENT_SOURCE_SKY, "ambient_energy": 0.4, "ambient_color": Color(0.96, 0.88, 0.8),
		"exposure": Palette.ENV_EXPOSURE * 0.9, "fog": Palette.FOG,
		"glow": 0.45, "led": 0.0, "lamps": 0.0, "windows": 0.0, "hac": 0.0, "floodlight": 0.0,
		"headlights": false,
	}


## Shared materials are static (also used by the menu stage), so this is
## called for every race and again with "day" when the race scene leaves.
static func apply_materials(id: String) -> void:
	var p := params(id)
	LandmarkKit.set_flame_led(float(p.led))
	var globe := BakuExtras._mat("globe") as StandardMaterial3D
	if globe:
		globe.emission_energy_multiplier = lerpf(0.8, 5.0, float(p.lamps))
	var lantern := PropKit.m("lantern") as StandardMaterial3D
	if lantern:
		lantern.emission_energy_multiplier = lerpf(1.2, 4.0, float(p.lamps))
	# Lit windows: warm glow on the window glass of houses and blocks.
	for id_w in ["glass", "glass_tower", "glass_tower_warm"]:
		var g := PropKit.m(id_w) as StandardMaterial3D
		if g == null:
			continue
		var w := float(p.windows) * (1.0 if id_w == "glass" else 0.5)
		g.emission_enabled = w > 0.0
		g.emission = Color(1.0, 0.78, 0.42)
		g.emission_energy_multiplier = w * 1.4
	CityKit.set_window_glow(float(p.windows)) # 0.11.0 downtown towers
	PropKit.set_window_glow(float(p.windows)) # 0.14.1 baked Old City houses
	PropKit.set_lamp_glow(lerpf(0.8, 5.0, float(p.lamps))) # 0.14.2 baked boulevard lamps
	NightGlow.set_global_night(id) # 0.11.2 water darkens at night
	# Heydar Aliyev Center: soft warm-white uplight on the white skin.
	var hac := LandmarkKit.hac_white()
	var hk := float(p.hac)
	hac.emission = Color(0.8, 0.82, 0.86).lerp(Color(1.0, 0.86, 0.7), hk)
	hac.emission_energy_multiplier = lerpf(0.32, 0.75, hk)


## Floodlight on Government House and a headlight on the player kart.
static func add_lights(root: Node3D, id: String, landmarks: Dictionary, player_kart: Node3D) -> Array[Node3D]:
	var p := params(id)
	var out: Array[Node3D] = []
	var gov: Node3D = landmarks.get("government_house")
	if float(p.floodlight) > 0.0 and gov:
		var fl := OmniLight3D.new()
		fl.name = "GovFloodlight"
		fl.light_color = Color(1.0, 0.78, 0.48)
		fl.light_energy = 3.0 * float(p.floodlight)
		fl.omni_range = 70.0
		fl.omni_attenuation = 0.8
		fl.shadow_enabled = false
		root.add_child(fl)
		fl.global_position = gov.global_position + gov.global_transform.basis.z * 30.0 + Vector3(0, 14, 0)
		out.append(fl)
	if bool(p.headlights) and player_kart:
		var hl := SpotLight3D.new()
		hl.name = "Headlight"
		hl.light_color = Color(1.0, 0.95, 0.82)
		hl.light_energy = 6.5 # 0.11.2: brighter, the night ambient is darker
		hl.spot_range = 38.0
		hl.spot_angle = 32.0
		hl.spot_attenuation = 0.7
		hl.shadow_enabled = false
		hl.position = Vector3(0, 1.0, -1.0)
		hl.rotation = Vector3(deg_to_rad(-9.0), 0, 0) # forward is -Z, tipped to the road
		player_kart.add_child(hl)
		out.append(hl)
		# 0.11.2: the bulbs moved into NightGlow's merged per-kart lamp mesh.
	return out
