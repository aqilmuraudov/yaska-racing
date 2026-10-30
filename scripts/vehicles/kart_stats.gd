class_name KartStats
extends Resource
## Handling class definition. All values are initial tuning parameters,
## documented in docs/TUNING.md. Speeds in m/s, angles in degrees.

@export var id := "balanced"
@export var name_key := "KART_BALANCED"
@export var desc_key := "KART_BALANCED_DESC"
@export var model_style := "balanced" ## Visual body family (silhouette)
@export var paints: Array[Color] = [Color("e0344b"), Color("25c2c2"), Color("ffc93c"), Color("4b5bd6")]

@export_group("Speed")
@export var top_speed := 27.0
@export var acceleration := 15.0 ## m/s² at standstill; tapers near top speed
@export var accel_taper := 0.6 ## 0 = constant, 1 = no acceleration at top speed
@export var brake_decel := 30.0
@export var coast_decel := 5.0
@export var reverse_speed := 8.0
@export var reverse_delay := 0.25 ## seconds stopped with brake held before reversing
@export var overspeed_decay := 10.0 ## m/s² back toward cap after boosts

@export_group("Steering")
@export var steer_rate_low := 115.0 ## deg/s at low speed
@export var steer_rate_high := 72.0 ## deg/s at top speed
@export var steer_response := 7.0 ## input smoothing rate (1/s)
@export var steer_min_speed := 3.0 ## full steering authority reached above this
@export var lateral_grip := 9.0 ## higher = less sideways slip (1/s)

@export_group("Drift")
@export var drift_min_speed := 11.0
@export var drift_turn_base := 62.0 ## deg/s neutral drift turn rate
@export var drift_turn_range := 34.0 ## ± deg/s from steering inside/outside
@export var drift_visual_angle := 26.0
@export var drift_correction := 6.0 ## visual angle return speed (1/s)
@export var drift_speed_factor := 0.985
@export var drift_charge_time := 0.85 ## seconds to fill the meter
@export var drift_window_start := 0.72 ## meter fraction where the boost window opens
@export var drift_perfect_start := 0.92
@export var drift_overheat_time := 0.22 ## time at full meter before a miss

@export_group("Air")
@export var gravity := 32.0
@export var hop_impulse := 3.0 ## subtle drift hop (was 5.2: a jump)
@export var air_steer_rate := 40.0
@export var air_drag := 0.6
@export var landing_boost_airtime := 0.55

@export_group("Boost")
@export var boost_strength := 6.0 ## base speed bonus for drift boost
@export var boost_duration := 0.85
@export var boost_tier_bonus := 1.0 ## extra speed per chain tier
@export var boost_perfect_bonus := 1.5
@export var boost_max_bonus := 10.0 ## absolute cap on speed above top speed
@export var boost_max_stored := 2.6 ## seconds of boost that may be banked
@export var boost_accel := 40.0 ## how fast speed rises toward the boosted cap
@export var pad_strength := 8.0
@export var pad_duration := 1.0
@export var start_boost_strength := 7.0
@export var start_boost_duration := 1.2
@export var item_boost_strength := 9.0
@export var item_boost_duration := 1.6

@export_group("Collision")
@export var wall_glance_loss := 0.12 ## speed lost per unit of impact ratio on glancing hits
@export var wall_hard_ratio := 0.6 ## impact ratio above which a hit is "hard"
@export var wall_hard_loss := 0.55
@export var wall_bounce := 2.5 ## m/s pushed back off hard hits
@export var kart_bump := 3.2 ## lateral m/s exchanged on kart contact
@export var mass := 1.0

@export_group("Surface")
@export var offroad_speed_factor := 0.55
@export var offroad_accel_factor := 0.6
@export var offroad_grip_factor := 0.75
@export var rough_speed_factor := 0.74

@export_group("Display stats (0-5)")
@export var stat_speed := 3
@export var stat_accel := 3
@export var stat_handling := 3
