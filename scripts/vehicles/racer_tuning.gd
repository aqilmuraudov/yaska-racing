class_name RacerTuning
extends RefCounted
## Maps the displayed 1–10 ratings onto real handling through named, bounded
## curves (never by multiplying physics values with the rating itself).
## Each curve is linear in the rating between a "1" and a "10" value chosen
## so the weakest attribute is still fun and the strongest never dominates.
## Values are initial tuning parameters (see docs/TUNING.md).

const CURVES := {
	# Top speed → normal maximum speed (m/s)
	"top_speed": [26.5, 27.7],
	# Acceleration → standstill acceleration (m/s²); taper slightly less for
	# strong accelerators so they also regain speed quickly after slowing.
	"acceleration": [11.5, 20.5],
	"accel_taper": [0.66, 0.5],
	# Handling → steering response and cornering control
	"steer_rate_low": [100.0, 132.0],
	"steer_rate_high": [58.0, 90.0],
	"steer_response": [5.5, 9.0],
	"lateral_grip": [8.0, 11.0],
	# Drift → slide stability, correction control, boost timing tolerance
	"drift_window_start": [0.74, 0.67],
	"drift_perfect_start": [0.93, 0.88],
	"drift_overheat_time": [0.18, 0.34],
	"drift_turn_range": [28.0, 40.0],
	"drift_correction": [5.0, 8.0],
	# Boost → strength and duration of every boost source (bounded), bank size
	"boost_strength_scale": [0.95, 1.09],
	"boost_duration_scale": [0.95, 1.17],
	"boost_max_stored": [2.5, 2.85],
	"boost_max_bonus": [9.5, 11.0],
}


static func curve(name: String, rating: int) -> float:
	var c: Array = CURVES[name]
	var t := clampf((float(rating) - 1.0) / 9.0, 0.0, 1.0)
	return lerpf(c[0], c[1], t)


static func build_stats(def: RacerDefinition) -> KartStats:
	var s := KartStats.new()
	s.id = def.id
	s.name_key = def.display_name
	s.model_style = def.kart_style
	s.paints = [def.kart_primary]
	s.top_speed = curve("top_speed", def.top_speed)
	s.acceleration = curve("acceleration", def.acceleration)
	s.accel_taper = curve("accel_taper", def.acceleration)
	s.steer_rate_low = curve("steer_rate_low", def.handling)
	s.steer_rate_high = curve("steer_rate_high", def.handling)
	s.steer_response = curve("steer_response", def.handling)
	s.lateral_grip = curve("lateral_grip", def.handling)
	s.drift_window_start = curve("drift_window_start", def.drift)
	s.drift_perfect_start = curve("drift_perfect_start", def.drift)
	s.drift_overheat_time = curve("drift_overheat_time", def.drift)
	s.drift_turn_range = curve("drift_turn_range", def.drift)
	s.drift_correction = curve("drift_correction", def.drift)
	var bs := curve("boost_strength_scale", def.boost)
	var bd := curve("boost_duration_scale", def.boost)
	s.boost_strength *= bs
	s.boost_duration *= bd
	s.pad_strength *= bs
	s.pad_duration *= bd
	s.item_boost_strength *= bs
	s.item_boost_duration *= bd
	s.start_boost_strength *= bs
	s.start_boost_duration *= bd
	s.boost_max_stored = curve("boost_max_stored", def.boost)
	s.boost_max_bonus = curve("boost_max_bonus", def.boost)
	s.stat_speed = def.top_speed
	s.stat_accel = def.acceleration
	s.stat_handling = def.handling
	return s
