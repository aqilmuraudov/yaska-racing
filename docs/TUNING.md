# Tuning reference

All values are **initial tuning parameters** meant to be refined in
playtests. Speeds in m/s (×3.6 = km/h), angles in degrees, times in seconds.

## Kart handling (`data/vehicles/*.tres`, class `KartStats`)

| Parameter | Balanced "Bulvar" | Agile "Nar" | Fast "Külək" | Meaning |
|---|---|---|---|---|
| top_speed | 27.3 | 26.5 | 28.2 | cap on road without boost (×surface factor) |
| acceleration | 15.0 | 19.0 | 12.5 | m/s² from standstill |
| accel_taper | 0.6 | 0.5 | 0.65 | how much acceleration fades near the cap |
| steer_rate_low / high | 115 / 72 | 128 / 86 | 104 / 62 | yaw rate at low / top speed |
| lateral_grip | 9.0 | 10.0 | 8.5 | sideways slip decay (1/s) |
| drift_turn_base / range | 62 / ±34 | 68 / ±36 | 56 / ±30 | drift yaw rate, steering modulates within range |

Shared defaults (see `scripts/vehicles/kart_stats.gd`): brake 30 m/s²,
coast 5, reverse 8 m/s after 0.25 s stopped with brake held, overspeed decay
10 m/s², gravity 32 m/s², hop impulse 5.2 m/s, air steer 40°/s, off-road
speed ×0.55 / accel ×0.6 / grip ×0.75, rough cobbles ×0.74, wall glance loss
0.12×impact ratio, hard wall (ratio ≥ 0.6 and > 8 m/s into wall) loses 55 %
speed, bounce 2.5 m/s, kart bump ≤ 3.2 m/s. **Collision footprint is identical
for all classes** (capsule r 0.6, length 2.0).

## Drift and boost rules

- Drift: press Drift while steering at ≥ 11 m/s → hop → land holding Drift
  and steering → powerslide. Steering into/out of the turn changes yaw rate.
- Meter fills in 0.85 s. Window opens at 72 %, perfect zone from 92 %.
  Boost press in window → tier 1–3 (max 3 per drift). Early press or holding
  full > 0.22 s = miss: meter restarts after 0.3 s, chain kept.
- Drift boost: +6 m/s (+1 per tier, +1.5 perfect) for 0.85 s (+0.12/tier,
  +0.2 perfect).
- Other sources: pad +8 / 1.0 s, start boost +7 / 1.2 s (perfect, ≤ 0.25 s
  before GO; 0.45 s window gives 65 %), item turbo +9 / 1.6 s, landing boost
  (airtime ≥ 0.55 s with Drift held/pressed) up to +8.
- **Stacking**: durations add into a bank capped at 2.6 s; the speed bonus is
  the strongest active source, capped at +10 m/s. Absolute speed cap =
  top_speed × AI scale + 10 m/s.
- **Cancelled by**: item hits, hard wall impacts, recovery. **Kept but halved**
  on off-road/rough surfaces. Same for players and AI.

## AI difficulty (`data/difficulty/profiles.json`)

| | easy | medium | hard |
|---|---|---|---|
| speed_factor (× real top speed) | 0.87 | 0.95 | 1.00 |
| corner_factor | 0.82 | 0.94 | 1.03 |
| boost_accuracy / perfect | 0.40 / 0.10 | 0.72 / 0.35 | 0.92 / 0.70 |
| mistakes per second | 0.05 | 0.012 | 0.003 |
| shortcut chance | 0.10 | 0.35 | 0.65 |
| catch-up max (±) | 3 % | 3 % | 2.5 % |

Measured (seeded 3-lap races, autopilot player as reference ≈ 53–54 s laps):
AI median best lap easy 60.9 s, medium 54.9 s, hard 53.0 s. Catch-up is
disabled in Time Trial and can be switched off in settings.

## Items (`data/items/items.json`)

Shield 8 s / one hit. Trap: arms after 0.35 s, owner immune for 1.0 s,
lifetime 20 s, radius 0.95 m. Hit = 1.0 s spin-out, then 1.6 s immunity.
Respawn protection 2.0 s. Roll time 1.0 s, box respawn 2.5 s.
Roll tables: front (P1) trap .5/shield .4/turbo .1; middle .35/.3/.35;
back (last third) .15/.25/.6.

## Graphics presets (`data/graphics/presets.json`)

| | Low | Medium | High |
|---|---|---|---|
| resolution scale | 0.6 | 0.8 | 1.0 |
| anti-aliasing | none | FXAA | MSAA 4× |
| shadows | blob only | 1 cascade, 55 m, 1024 | 2 cascades, 90 m, 2048 |
| effects density | 0.35 | 0.7 | 1.0 |
| scenery distance | 140 m | 260 m | 520 m |
| texture detail (mip bias) | +0.75 | 0 | −0.25 |
| bloom / SSAO | off / off | on / off | on / on (Forward+ only) |

Measured on desktop (RTX 3070, 1280×720, Forward+, start straight to Old
City): draw calls ≈ 230 / 400 / 550, primitives ≈ 0.24 M / 0.42 M / 0.6 M.
Mobile renderer at Medium: ≈ 290 draw calls, 0.35–0.45 M primitives.
These are **desktop measurements, not phone measurements**.
