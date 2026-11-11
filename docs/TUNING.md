# Tuning reference

All values are **initial tuning parameters** meant to be refined in
playtests. Speeds in m/s (×3.6 = km/h), angles in degrees, times in seconds.

## Racers and handling (`data/racers/*.tres` → `RacerTuning` → `KartStats`)

Each racer package (animal + kart) stores five ratings (1–10). The UI stat
bars and the simulation read the **same resource**. Ratings never multiply
physics directly; each goes through a named, bounded linear curve
(`scripts/vehicles/racer_tuning.gd`, value at rating 1 → value at 10):

| Curve | 1 → 10 | Driven by |
|---|---|---|
| top_speed (m/s) | 26.5 → 27.7 | Top speed |
| acceleration (m/s²) / accel_taper | 11.5 → 20.5 / 0.66 → 0.5 | Acceleration |
| steer_rate_low / high (°/s), steer_response, lateral_grip | 100→132 / 58→90, 5.5→9, 8→11 | Handling |
| drift_window_start / perfect_start | 0.74→0.67 / 0.93→0.88 (lower = more forgiving) | Drift |
| drift_overheat_time, drift_turn_range, drift_correction | 0.18→0.34 s, 28→40°/s, 5→8 | Drift |
| boost strength × / duration × (all sources) | 0.95→1.09 / 0.95→1.17 | Boost |
| boost bank / absolute boost cap | 2.5→2.85 s / +9.5→+11 m/s | Boost |

| Racer | Animal | Kart | Top | Accel | Handling | Drift | Boost |
|---|---|---|---|---|---|---|---|
| Posi | panda | Bamboo Sprint | 6 | 10 | 7 | 6 | 6 |
| Bicok | fox | Amber Dash | 9 | 6 | 8 | 6 | 6 |
| Ləlöyün | rabbit | Hop Rocket | 7 | 9 | 9 | 5 | 5 |
| Məstan | cat | Velvet Slide | 7 | 6 | 7 | 10 | 5 |
| HavHav | dog | Buddy Rally | 7 | 7 | 7 | 7 | 7 |
| Çəpiş | lamb | Cloud Booster | 8 | 5 | 5 | 7 | 10 |

Balance check (`--balance`: identical hard-AI skill for all six, no
catch-up, no items, every racer takes the player slot once, two seed sets,
3 laps): mean best laps Məstan 51.55 s, Bicok 51.88, Çəpiş 51.90, HavHav
52.09, Ləlöyün 52.36, Posi 52.48 → **spread 0.93 s (1.8 %)**, within
seed-to-seed noise (~1 s). The first curve set gave 2.7 s (5 %); top speed
and boost were compressed. On this fast circuit drift/boost ratings matter
most for AI; acceleration pays off mainly after slowdowns, hits and the
start (more relevant for human players). Re-check on new tracks.

All racers share the same collision capsule (r 0.6, length 2.0).

Shared defaults (see `scripts/vehicles/kart_stats.gd`): brake 30 m/s²,
coast 5, reverse 8 m/s after 0.25 s stopped with brake held, overspeed decay
10 m/s², gravity 32 m/s², hop impulse 3.0 m/s (0.7.0, was 5.2), air steer 40°/s, off-road
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

## Drift feel (0.7.0, `KartController` / `KartVisual` / `ChaseCamera`)

| Value | Now | Was | Effect |
|---|---|---|---|
| hop_impulse | 3.0 m/s | 5.2 | subtle hop (≈0.15 m) instead of a jump |
| drift slip angle | 0.75·drift_visual_angle neutral, 1.10 full inward, 0.40 full counter-steer | visual only, ±8° from steer at 10/s | real `drift_slip` state; counter-steer closes it |
| DRIFT_SLIP_RATE | 4.0 /s | — | how fast the slip follows steering (smooth on digital touch input) |
| slip recovery after release | drift_correction (5→8 /s by Drift rating) | same | grip returns smoothly, no snap |
| drift_speed_factor | 0.985 × (1 − 0.03·slip/angle) | 0.97 | speed is mostly kept |
| body roll in drift | 3.5° × slip/angle at 5 /s | 7° at 8 /s | subtle lean, no side-to-side wobble |
| body roll normal | 3° × steer × speed | 5° | calmer |
| front wheels in drift | counter-steer = 0.7 × slip + 6° × steer | fixed 10° into the turn | wheels point along the travel |
| camera drift follow | 0.35 × slip (≈9° full slide), 3 /s | fixed 9° | camera follows the slide angle |
| tyre smoke | while drifting, and while slip > 7° after release | drifting only | smoke fades with the slide |

Touch buttons: the 4 /s slip rate filters the on/off steer button so the angle
glides between 40 % and 110 %. Tilt: analog steer maps straight onto the slip
range. Mini-turbo tiers, Easy Drift and timing windows are unchanged.
Tests: `tests/test_drift_feel.gd`.

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

## Currency: Azerbaijani manat (0.8.0, `scripts/progression/money.gd`)

- Stored internally as **integer qəpik** (1 ₼ = 100 qəpik). Displayed as `2,50 ₼`, deltas as `+80 qəpik` (below 1 ₼) or `+1,20 ₼`; comma decimal, space thousands separator (`1 234,56 ₼`).
- Save migration v2 → v3: **1 old coin = 2 qəpik** (`Money.COINS_TO_QEPIK`). Old race rewards were 15–60 coins (≈ 0,30–1,20 ₼), which sits in the same band as the new per-race pay, so old balances buy roughly what they bought before. `lifetime.coins` is converted the same way and the kart-part thresholds were doubled, so no unlock is lost or gained. Daily-task and trophy rewards were converted ×2.

## Economy (0.8.0, `scripts/progression/economy.gd`)

| Source | Pay |
|---|---|
| Place 1–8 (quick race / cup race) | 2,00 / 1,60 / 1,30 / 1,00 / 0,85 / 0,70 / 0,60 / 0,50 ₼ |
| Did not finish | 30 qəpik |
| Time trial finish | 90 qəpik, +40 qəpik for a new record |
| Tutorial | 30 qəpik |
| Drift boost | 4 qəpik (+2 for a perfect release) |
| Boost pad / boost item | 1 qəpik |
| Overtake (new best place, after 2 s) | 5 qəpik |
| Star pickup | 2 qəpik |
| Clean lap (no hard wall hit) | 15 qəpik |
| Driving income cap per race | 1,50 ₼ |
| Rewarded ad (hook only, no SDK) | doubles one race payout, once per race |

1st pays exactly 2× 4th. Driving income is shown live in the HUD pill and broken down in the results (Yer · Sürüş · Rekord). It is granted once per race (`event_instance_id`).

## Garage / tuning (0.8.0, `scripts/progression/kart_tuning.gd`)

| Upgrade | Per level | Max | Level costs |
|---|---|---|---|
| Sürət (top speed) | +2,4 % | 5 | 1,30 / 2,20 / 3,40 / 5,20 / 8,00 ₼ (20,10 ₼ total) |
| Mühərrik (acceleration) | +5 % | 5 | same |
| Əyləclər (brake) | +8 % | 5 | same |
| Sükan (steering) | +3,5 % | 5 | same |
| Təkərlər (grip, + off-road grip 0,02) | +5 % | 5 | same |
| Nitro | fit + 3 levels | 4 | 6,00 / 3,00 / 4,50 / 6,00 ₼ |
| Paint (locked by stars) | — | — | 1,50 ₼ each |

Nitro level L: strength 7+0,8L, duration 1,2+0,15L s, recharge 20−2,5L s; charge also fills +12 % per drift boost. Total gains are capped (top speed ≤ +12 %). AI rivals get a share of the player's levels: easy 50 %, medium 80 %, hard 100 % (no AI nitro). Upgrades are per kart. Balance tests, tutorial and time-trial ghosts use stock karts.

### Simulation (`Economy.simulate`, 300 careers, random finish 1st–6th, realistic driving income)

| Measure | Result |
|---|---|
| Average race pay | ≈ 2,12 ₼ |
| Average by place 1st…6th | 2,88 / 2,48 / 2,18 / 1,87 / 1,73 / 1,58 ₼ |
| First level-1 upgrade (1,30 ₼) | 1,0 races (even 6th place affords one) |
| A paint (1,50 ₼) | 1,1 races |
| Mid tier: levels 1–3 of a stat (6,90 ₼) | 3,8 races (level 3 alone ≈ 1,6 races) |
| Nitro fit (6,00 ₼) | 3,4 races |
| One stat maxed (20,10 ₼) | 10,0 races |
| Full kart (5 stats + nitro, 120,00 ₼) | 57 races |

`tests/test_round5.gd::test_economy_payouts_and_pacing` keeps these inside the targets.

## Kart shop (0.9.1: prices rise with shop order, same 64 ₼ total)
Prices live in `scripts/progression/kart_shop.gd` (`PRICES`, qəpik). A new profile picks ONE free starter kart (any racer); the rest are bought. 0.17.4: HavHav costs 8,50 ₼ (was 0, which made it a free second kart for anyone whose starter was another racer) and is offered first when not owned (`KartShop.shop_order()`). The table below assumes the HavHav starter.
| Kart | Price | Cumulative | Races (race pay only) | Races (+avg goals 0.40 ₼) |
|---|---|---|---|---|
| Posi | 9,00 ₼ | 9 ₼ | 4.8 | 4.1 |
| Leloyun | 9,50 ₼ | 18,50 ₼ | 9.2 | 7.9 |
| Biçok | 10,00 ₼ | 28,50 ₼ | 13.9 | 11.9 |
| Mestan | 11,00 ₼ | 39,50 ₼ | 19.1 | 16.2 |
| Çəpiş | 11,50 ₼ | 51 ₼ | 24.5 | 20.8 |
| Yaska | 13,00 ₼ | 64 ₼ | 30.7 | 25.9 |
Simulation: `Economy.simulate_karts` (`tools/sim_karts.gd`), avg race pay 2.12 ₼, buying in ORDER, no tuning spend.
Extra income: daily login 0.50/0.70/0.90/1.10/1.30/1.60/4.00 ₼; race goals 0.30–0.60 ₼ each; near miss 0.03 ₼ (inside the 1.50 ₼ driving cap).
Existing saves (v<4) keep all karts. Tuning only applies to owned karts.

## Game modes (0.10.0)
Mode select ("Oyna") has four cards: Sərbəst yarış, Bakı Kuboku, Rekord, Gündəlik tapşırıq; Drift məktəbi is a small button below. Cup and daily races run as `mode="quick"` with `config.series` = `cup` / `daily` (quick-race goals are off in series races).

### Bakı Kuboku (`scripts/progression/baku_cup.gd`)
| | value |
|---|---|
| races | 3, same 5 rivals (random from the roster, fixed for the cup) |
| points by place | 10 / 8 / 6 / 4 / 2 / 1 |
| race 1 | 2 laps, normal grid (player 4th), items on |
| race 2 | 3 laps, reverse grid by standings (leader starts last), items on |
| race 3 | 2 laps, reverse grid, **no items** |
| final prize | 1st 4,00 ₼ · 2nd 2,50 ₼ · 3rd 1,50 ₼ · 4th–6th 0,60 ₼ (ledger `cup:<seed>:final`, paid once) |
| per race | normal place + driving pay, fixed event id `cup:<seed>:<race>` so each race pays once |
Tie-break: points, then last-race place, then rival order. No time-of-day or reverse-direction variation exists in the game, so the variation is laps, grid and items.
Saved in `cup_progress` after every finished race; closing the app mid-race re-runs that race (a race that was not finished scores nothing). A damaged save state is dropped (`BakuCup.sanitize`) → clean reset. `cup_history` counts played/won/best.

### Rekord (time trial)
- Ghost = best lap ever (translucent kart, replayed every lap). Ghost file format 2 adds lap distance per sample → live delta pill under the best lap (green −, red +, white 0.00); old format-1 ghosts still replay without the delta. Lap-end flash shows the lap delta.
- New record: existing `RECORD_BONUS` 40 qəpik, once per improving race.
- Kids controls on: no record, no ghost, no bonus; HUD and results say so (`TT_KIDS_NO_RECORD`).

### Gündəlik tapşırıq (`scripts/progression/daily_challenge.gd`)
- Seed = hash of the local date → same challenge all day on every device; 2 laps, 5 rivals.
- Types: win; win with a given owned kart (only if 2+ karts owned); collect 5–8 stars; finish under a time (2 × 49/52/55 s — autopilot best lap is ~50.3 s); clean race (top 3, no hard wall hit).
- Reward 1,50 ₼ once per day (ledger `dailych:<date>`); card shows "✓ Bu gün edildi" afterwards. Replays are allowed and pay normal race money.
- Kids controls: win → top 3, time × 1.15.

## Time of day (0.10.1, `scripts/racing/time_of_day.gd`)
- `TimeOfDay.params(id)` holds sky, sun/moon, ambient, fog, glow, saturation and which lights are on; "day" reproduces the old values.
- Sunset: sun pitch -9, colour (1, .56, .3), energy 1.55. Night: moon pitch -42, energy 0.6, colour ambient 0.42 (0.11.2; was 0.6), saturation x0.8.
- `apply_materials` switches shared emissions (LED, lamps, windows, HAC); `RaceEnvironment._exit_tree` restores day for the menus.
- `add_lights`: Government House OmniLight (range 70, energy 3) at sunset/night; player headlight SpotLight (range 38, energy 6.5 since 0.11.2; angle 32) at night.


## Quality tiers and LOD (0.10.2)
- `Settings.auto_preset(gpu, cores, mobile)`: desktop → high; mobile → medium, high for `STRONG_GPU_HINTS` (Adreno 73x+/8xx, Immortalis, Mali-G715+, Xclipse), low for `WEAK_GPU_HINTS` (Adreno 3xx–52x/60x–61x, Mali-4/T/G31–G57, PowerVR, software) or ≤ 4 cores; capped by `graphics.auto_cap`.
- `Settings.auto_step_down()`: PerfMonitor on mobile + "auto" when frames are slow; one tier down, cap saved. Otherwise the steady-30 fallback.
- Decor: `TrackDecor.CHUNK` 70 m; near MultiMesh ends at `lod_for(m) = clamp(0.42·m, 60, 200)`, far `_lo` MultiMesh (PropKit `"@lo"` meshes at ShapeKit.detail 0.5, no shadows) begins there.
- Karts: `KartVisual.KART_LOD` 28 m → `model_lo` (ShapeKit.detail 0.4, tiny parts hidden).
- Shadow distance per shadows level: `[0, 45, 100, 150]` m. Dynamic resolution on Low and Medium.

## Cinematic camera (0.10.2, `ChaseCamera.Mode.CINEMATIC`)
- Shots in order: trackside 4.2 s (FOV 42, zooms to ~14 m framing, 26–60°), helicopter 5.0 s (r 11 m, 8→6.5 m high, eased 1.5 rad orbit), front chase 3.2 s (6.2→5.4 m ahead, 1.5 m high), fly-by 4.6 s (7.5 m behind on the far side from the nearest landmark within 650 m, sweeps 3 → −1 m sideways, rises 1.8 → 4 m). Hard cut between shots.
- Trackside anchor: 10–26 m ahead (1.6 s of travel), 5.5 m to the side, other side if a ray hits; ends early when the kart is > 30 m away or has passed it by 20 m.
- Other shots pull in when the kart→camera ray hits collision; camera never > 36 m from the kart.

## Downtown map (0.11.0)
- `TrackList.LAP_SCALE`: seafront 1.0, downtown 0.7 (autopilot lap ~36 s vs 51.5 s). Daily time goal × lap_scale; daily star goals × 0.85 on downtown.
- Bakı Kuboku stages: 1 seafront (day), 2 downtown_towers 3 laps (day), 3 seafront (sunset).
- CityKit: 16 floors × 3.6 m = 57.6 m towers; malls 64×36×16 m; parking 40×24 m. Mall bridge deck from 8 m (BRIDGE_CLEAR).
- DowntownDecor: tower chunks 160 m, mall chunks 140 m; far LOD kept to at least 560 m (towers) / 420 m (malls) so the skyline never pops; buildings keep road + offroad + 8 m clear, MALL_R 38.
- Skyscraper shader: lit window if hash > 0.6, energy `window_glow` × 1.2 (TimeOfDay `windows`).
- Debug: `--track=ID`, `--perf-every=S` (PERF_SAMPLE lines + PERF_SUMMARY at quit).

## City select (0.11.1)
- Cards: width clamp((avail - gap - 24) / 2, 300, 600), height clamp(avail.y - 12, 320, 1.02·w); picture height clamp(0.6·h, 150, 0.78·w).
- "Yeni!" shown for every city except `TrackList.IDS[0]` until `CityCards.is_played` (played_tracks, a record, or a quick/tt finish stat).
- Thumbnails: 640×400 JPEG crops of 1280×720 `--no-hud` race captures (seafront: cinematic t=9 s; downtown: chase t=17 s), colour ×1.12.

## Phone optimisation and night polish (0.11.2)
- **Render height cap** (`presets.json` `render_height`, `Settings.render_scale_for`): on phones the 3D scale is `min(resolution_scale, render_height / screen short side)`, clamped 0.5–1.0. Low 648, Medium 864, High 1080 px. A 1080p phone (Mi 12 Lite) renders exactly as before (0.6 / 0.8 / 1.0); a 1440p phone renders 0.5 / 0.6 / 0.75 instead of 0.6 / 0.8 / 1.0 (−31…−44 % pixels). Desktop keeps the plain fraction. Dynamic resolution works on top of it.
- **Upscaling**: phones stay on bilinear. FSR 1.0 is Forward+-only in Godot 4.4 (engine error "FSR1 is only available when using the Forward+ renderer", seen on the Mobile renderer in 0.11.2).
- **Anti-aliasing**: MSAA 2× was tried on Medium and rejected: in the Mobile-renderer screenshots (render scale 0.8) edges were clearly MORE jagged than with FXAA (`docs/screenshots/0.11.2/aa_compare.png`). Medium stays on FXAA.
- **Settings v5**: only the new `render_height` is filled in from the stored preset; all other stored values (frame rate, texture detail, …) are kept.
- **Shared noise texture** `assets/textures/noise_value.png` (`tools/gen_noise.py`: tileable value noise, period 64 cells, 4 texels per cell, smoothstep, 256×256 L8, lossless + mipmaps), global shader uniform `yaska_noise`. `vnoise(p)` = `texture(yaska_noise, p / 64).r` in road, ground and water. Estimated fragment ALU saved per pixel: road 4 calls × 4 hashes (~16 hashes), ground 2 calls (~8 hashes), water 2 calls (~8 hashes), each replaced by one texture fetch. Ground: sRGB→linear of the vertex colour moved to the vertex shader (was 2 `pow` per pixel).
- **Kart shadows**: the full-detail kart/driver no longer casts; a shadows-only copy of the far-LOD mesh (`ShadowProxy`, ShapeKit.detail 0.4, same pivots) casts up to `KART_LOD` (28 m); beyond it nothing casts (blob shadow grounds the kart). Kart shadow-pass primitives at the start grid (6 karts near): ~58k → ~9.5k.
- **Night (NightGlow, `scripts/racing/night_glow.gd`)**, no extra real lights:
  - lamp pools: one MultiMesh of 11 m additive unshaded quads, `POOL_LIFT` 0.32 m above each `lamp` instance (promenade/sidewalk tops sit above the lamp base), strength 0.62 × k; colour (1, .74, .42). Seafront 24 lamps, downtown 105.
  - kart lamps: one merged vertex-coloured mesh per kart (2 head lamps r 0.1 m at z −0.97, 2 tail lamps r 0.075 m at z +1.12), unshaded, colour × 2.6 (HDR for glow).
  - rival headlight cone: 6.5 × 11 m additive quad ahead of the kart, strength 0.24 × k, fades out within 5–13 m of the camera (a kart beside the camera would wash the screen), hidden beyond 70 m. The player keeps the real SpotLight.
  - k = 1 at night, 0.35 at sunset, 0 by day.
  - sea: global `yaska_night` (1 night, 0.3 sunset, 0 day) mixes the water to navy (0.02, 0.06, 0.12)…(0.006, 0.018, 0.055) with cool moon glints.

## Finish replay and wordless hints (0.12.0)
- `FinishReplay` (`scripts/racing/finish_replay.gd`): ring buffer of every kart's transform + speed, recorded every 2nd physics tick (30 Hz), `BUFFER_S` 15 s (452 frames × karts).
- Starts when FINISHING reaches `RESULTS_DELAY` (3.4 s). Target: the race winner if its crossing is still covered by the buffer, else the player. Window `WINDOW_BEFORE` 3.6 s before the line to `WINDOW_AFTER` 1.4 s after; playback ×`SLOWMO` 0.45 within ±`SLOWMO_RANGE` 0.7 s of the crossing → about 6.1 s real time. Kart physics paused during playback; transforms/velocity/speed/yaw restored afterwards; race clock frozen.
- Camera: CINEMATIC on the target kart, then back to the saved view on the player. HUD: race HUD hidden, cinema bars (10 % top/bottom), "⟲ TƏKRAR" chip, "Keç" button (196×84, bottom-right above the bar, pulses).
- Off in the tutorial, in headless tests (unless `force_replay`), or with config `finish_replay = false`. Restart during the replay restores the karts and gives no results.
- Item notice: `RaceHUD.item_caption` — item icon (44 px) + item name in a dark pill, 0.25 s pop, 1.8 s, 0.4 s fade (was the text line "[Əşya: …]").
- Item hint on touch screens: `TapHint` — yellow ring pulsing at 1.1 Hz around the ITEM button and a tapping hand (`hint_tap.svg`), 3.2 s or until the item is used. Keyboard/controller keeps the sentence.

## 0.13.0
- TapHint: CYCLE_ALT 0.9 s per button; HOLD_TIME 1.3 s fill + 0.7 s release burst; hand flips above when `c.y + r + 110 > height`.
- RivalStrip: portraits 48 px, refresh 0.25 s.
- AoMap: RES 1024 over track bounds + 140 m; blob = footprint × 1.05 + 5 m; plateau 0.62 of the radius; strength 0.24 + 0.018·h (max 0.5); MAX_DARK 0.6 in 6 levels; props below 1.6 m or 2.5 m² skipped. Vertical fade on walls 0.2 → 1.8 m (props), 0.2 → 2.5 m (towers); road uses 75 %.
- Wet road (night): roughness ×(1 − 0.58·0.85), albedo ×0.86. Lamp streaks: 12 m × 1.5 m, strength 0.46, hidden beyond 60-110 m.
- Outline: width 0.028 m at 8 m, scaled 0.7-2.2× with distance; parts with no range limit that cast shadows; off when effects density < 0.5.
- Lesson: start delay 0.8 s; timeouts steer 9 s, drift 11 s, item 9 s; end 2.6 s. Seafront, day, 1 lap, 2 easy rivals, no item boxes.
- Stickers (stars): 3, 8, 15, 25, 40, 55, 75, 100, 130, 165, 205, 250.
- Old City: 757 m, width 17 m (Boulevard) / 15 m (streets), offroad 2.5 m, `LAP_SCALE` 0.5 (autopilot lap ~26 s), house fill grid 12 m within 70 m of the track, 34 m clear round the Maiden Tower.


## Blender-made karts (0.14.0 pilot: Yaska Star; 0.14.1: all seven, shared `tools/blender/kart_common.py`)
- Source: `tools/blender/yaska_star.py` (Blender 4.5, `blender --background --factory-startup --python tools/blender/yaska_star.py -- [--preview] [--no-bake]`, ~90 s on the RTX 3070). Writes `assets/models/yaska/{yaska_star.glb, yaska_star_far.glb, albedo.png, normal.png, orm.png}`; editable `tools/blender/out/yaska_star.blend` (git-ignored).
- Budget: near 11,038 triangles / 12 draws (procedural Yaska Star was 14,804 / 12); far LOD (beyond `KartVisual.KART_LOD` 28 m) 1,846 (was 4,772). Godot also generates mesh LODs on import (`generate_lods`) for the 0-28 m range.
- Textures: one 1024² set (baked at 2048², coverage-weighted downsample, islands dilated into the empty atlas so mipmaps never pick up the background). `orm.png` = R occlusion, G roughness, B metallic, A garage-paint mask (import: VRAM, mipmaps, `fix_alpha_border=false`).
- Palette (sRGB): body `E8409E` (metallic 0.55, rough 0.24), purple `8B3FD9`, gold tubes `F5B82E`, chrome `DDE1E6`, tyres `2B2830` + tread `4A4452`, hair `8C5530`, dress `5285CB`, skin `FCD7BF`. Albedo is pre-darkened by 50 % of the AO (Godot's AO only touches ambient light).
- `kart_baked.gdshader`: saturation `Palette.KART_SAT × 0.9`, rim 0.3, clear-coat 0.85 on rough < 0.6, AO light affect 0.6. Garage paint: `paint` instance uniform recolours the mask with luminance ratio `paint_ref_lum` 0.31.
- Tyre tread blur: `KartModel.spin_blur_for(step)` = smoothstep(0.04, 0.16 rad per physics tick); shader samples the colour with mip bias `spin_blur × 2.5` and flattens the normal map. Without it the chevron tread (34 per turn) strobes at race speed.
- Exhaust tips for smoke / flames: `KartModel.GLTF_EXHAUST` (±0.235, 1.0, 1.11).
- Rig contract (kart space, rest pose): wheels FL/FR pivots (∓0.62, 0.30, −0.72) radius 0.30 width 0.28, rear axle (0, 0.35, 0.68) tyres at ±0.66 radius 0.35 width 0.36; steering column (0, 0.88, −0.30) tilted −55°; shoulders (±0.20, 0.98, 0.17), arms authored along −Z (length 0.40); head pivot (0, 1.06, 0.18); eyes pivot y 1.22; braid pivots (±0.25, 1.42, 0.23). Debug A/B: `--no-gltf`.
- 0.14.1 per-racer glTF + exhaust tips: `KartModel.GLTF_MODELS / GLTF_FAR / GLTF_EXHAUST` keyed by `kart_style` (star, buddy, bamboo, amber, hop, velvet, cloud). Wheel radii follow the procedural styles (front/rear: buddy 0.31/0.36, bamboo 0.31/0.36, amber 0.27/0.35, hop 0.28/0.32, velvet 0.28/0.34, cloud 0.30/0.34; widths 0.26/0.34). Ear pivots (head-local): dog (±0.27, 0.26, 0.03), panda (±0.22, 0.34, 0.02), fox (±0.16, 0.33, 0.02), rabbit (±0.1, 0.34, 0.04), cat (±0.18, 0.31, 0.02), lamb (±0.24, 0.16, 0.02).
- 0.14.1 Old City props: `PropKit.GLTF_PROPS` (house_a..d, maiden_tower → `assets/models/oldcity/oldcity_props{,_far}.glb`), far ratio 0.5-0.55 houses / 0.35 tower. `prop_baked.gdshader`: `stone_detail` 1.0, `tex_mean` (0.768, 0.617, 0.371) linear, `detail_fade` 60 m, block 0.9 × 0.42 m, stone specular 0.25, window glow = `window_glow` × 1.4 × (1.0, 0.78, 0.42). Bake: `--bake-res 4096 --tex-res 2048`; Voronoi distance-to-edge bump (cells 0.9 × 0.42 m, strength 0.7, distance 0.03).
- 0.14.2: `KartVisual.MAX_WHEEL_RATE` 19 rad/s (visible wheel spin cap; physics untouched). Street / flora props: `PropKit.GLTF_PROPS` adds baluster, lamp (`assets/models/street`, glow = lamp energy / 1.4, colour FFE2A0) and palm, palm_b, tree, pine, cypress, flower_bed, bollard, bench (`assets/models/flora`, Palette.vivid colours baked in). Save v6: kart ownership as above.

## Character voices (`scripts/racing/voice_director.gd`, `data/voice_lines.json`)
| Param | Value | Meaning |
|---|---|---|
| `GAP` | 3.0 s | quiet after any line ends |
| `NEAR` / `NEAR_TIME` | 7 m / 1.5 s | player this close behind a rival (race distance) this long → "approach" |
| `NEAR_REST` | 8 s | same rival pair rest |
| `APPROACH_REST` | 10 s | any "approach" line rest |
| speaker | the player's racer only | rivals are silent |
| volume | +2 dB on the SFX bus | |
| generation | `eleven_v3`, `az`, stability 0.4, similarity 0.75; pitch per racer in the JSON (1.15–1.42) | |

## Guided tour "Öyrən" (`scripts/racing/tutorial_director.gd`, 0.15.2)
| Param | Value | Meaning |
|---|---|---|
| steps | gas, steer, brake, drift, boost, gift, camera, pause, done | 8 counted steps |
| `NEXT_AFTER` | 12 s | "Davam" shows on any step after this long |
| gas (auto-gas) | 4 s and speed > 6 m/s | moves on by itself |
| track / time | seafront, day, no rivals, 99 laps | `mode_select._choose("tutorial")` |

## Garage / city select (0.15.2)
| Param | Value |
|---|---|
| garage panel width | 640 px, tabs 84 px high |
| kart card | 184 × 230 px, portrait 104 px, 3 columns |
| city time-of-day bar | 3 buttons 250 × 96 px |
| Rekord camera switch | y 290 × scale (other modes 150) |

## Mini Baku (0.15.3)
| Item | Value |
|---|---|
| Flame Towers | 120 / 109 / 106 m (real 182/165/161 x 0.66), curl from 50 % height, triangle circumradius 42 m |
| HAC | portal 46 m at u 0.47, low arch 20 m at u 0.12, wing 13 m, horn 52 m |
| Seafront sites (x, z) | Flag Square (-395, -15), Crystal Hall (-320, 75), TV tower (-330, -600), Crescent (380, 120), Port Baku (338, -14) |
| 9-storey block | 30 x 16 m, shops 4.5 m + 9 x 3.1 m, unscaled |
| Road bump | asphalt 0.006, cobbles 0.03 (height = texture luminance), fades by 60 m |
| Kerb ridges | every 0.4 m, 0.012 high |


## Mini Baku: Old City and city centre (0.17.0)
| Item | Value |
|---|---|
| Old City sites (x, z, yaw, plot r) | Shirvanshahs' Palace (-85, -143, 0, 31), Juma Mosque (-118.5, -28, -90°, 17.5), Sınıqqala (-100, -91, 180°, 11), caravanserai (-45, -81, 180°, 20); Maiden Tower stays at (-30, -28) |
| Downtown sites (x, z, yaw, plot r) | Philharmonic (-200, 44, 180°, 28.5), City Hall (-130, 44, 180°, 26), Ismailiyya (-62, 42, 180°, 24), Fountain Square (-30, -53, plaza 56 x 40, plot 34), Flame Towers far model (-560, 10) |
| Nizami street | from the square's west edge (x -58) to x -205 at z -53, 14 m wide cobbles on the terrain; house rows 6.5 m off each kerb (nz_corner 18, nz_balcony 16, nz_bay 14, nz_arcade 20 m wide, 0.3 m joints); Nizami Museum at (-48, -81.5), plot 24; paving arcs 5 m wide, towers kept 20 m off its axis |
| Heights (game-fitted) | Juma minaret 24 m, Sınıqqala 26 m, Shah mosque minaret 24 m, caravanserai 9.4 m, Philharmonic towers 28.7 m, City Hall flag top 36.5 m, Ismailiyya gables 26 m |
| Triangles near / far | Old City set 7,092 / 2,755 (four buildings); centre set 9,824 / 4,143 (three buildings, two fountains, plaza) |
| Near → far switch | 260 m (20 m fade, `TrackDecor.LANDMARK_NEAR`) |
| Textures | one 2048² set each (`assets/models/icheri`, `assets/models/center`), VRAM compressed + mipmaps |
| Nizami set | 9,268 tris near (museum 2,984, corner 2,360, balcony 2,052, bay 956, arcade 916), one 2048² set |

## Roadside landmarks, touch layout, softer windows (0.17.3)
- Landmarks stand ~5 m behind the run-off (oriented footprint, measured): seafront `LANDMARK_SITES` flag (-353, -27), Flame Towers (-164, -404), Crescent (266, 38) (shore disc r 40, offset +8 z), Government House (41, -43), Carpet Museum (-226, -55.5, yaw 0, along the Boulevard), Port Baku (317, -53); `EXTRA_SITES` TV tower (-314, -230, r 12), Crystal Hall (-320, 69, r 44). Long buildings reserve a row of circles (`_reserve_footprint`). Seafront plots are reserved only on the seafront (`_reserve_seafront`).
- Downtown: Philharmonic z 29.5, City Hall 31, Ismailiyya 26 (placement check `footprint_clear_of_road`, margin 3 m); Fountain Square z -43, Nizami Museum z -71.5; Flame Towers (-352, -40), reserved r 76, near model to 380 m.
- Old City: Maiden Tower (-30, 27.5) beside the Boulevard street; Flame Towers (-257.5, -20), r 76; `OPEN_PLOTS` keep the 0.17.2 clearings (house count 296 vs 299).
- Malls (`FULL_LOD_PROPS`) use the full model at every distance (228–1700 tris).
- Touch: nitro takes the TURBO slot when Easy Drift hides TURBO (with manual gas: (-460, -250)), else (-300, -390) left of ITEM. Camera switch centre y = max(150 / 290 × s, top-right column bottom + 46 × s), synced on the column's resize.
- Windows: sunset `windows` 0.25 (was 0.45). Baked props: lit_share 0.38 (was 0.55), only a pane (x 0.24–0.76, y 0.30–0.82 of a 1.8 × 3.6 m cell), energy × 0.85 (was 1.4). Skyscrapers: hash > 0.7 (was 0.6), pane x 0.22–0.78 / y 0.12–0.88 of the glass part, energy × 0.8 (was 1.2). House glass material energy `windows` × 0.9 (was 1.4).

## Qarabağ map (0.19.0 big map, `data/tracks/karabakh.json`, `KarabakhDecor`, `tools/blender/karabakh_*.py`)
Owner's brief: famous places of Karabakh (Laçın, Şuşa, Xankəndi, the Xudafərin bridge), forest all round, asphalt roads, everything modelled in Blender; really big; landmarks one by one when the owner names them. Season: summer (owner's pick).
| | value |
|---|---|
| lap | 4916 m, **one lap** (`TrackList.MAX_LAPS`), 2 lanes, width 15–16 m, run-off 3 m, no sea |
| profile | Xankəndi y 12 (start) → climb, max grade 7.9 % → Şuşa plateau y 44 → Laçın y 20 → Həkəri valley → Araz bank y 2 → forest hills → Xankəndi |
| bends | tightest r 18 m; distant legs ≥ 95 m apart (tracker search window 45 m) |
| autopilot lap | 174.9 s (seafront 51 s) → `TrackList.LAP_SCALE` 3.4 |
| barriers | `THEME_FOREST` style "guardrail": galvanised grey, white reflector line, 0.85 m |
| zones | `zones` [id, x, z, radius]: khankendi 150, shusha 190, lachin 150, khudafarin 210 m - flattened 75 %, 90 % fewer trees, no canopy |
| rivers | `rivers`: araz width 64, level −2.6; hakari width 22, `drop` 43.5 → −2.4 (0.19.2: in Laçın it runs beside the road, centre 37 m from the road centre, 57 m at the café; water 2.6–6 m under the road there); bed 1.4 m under the water; road ≥ 26 m from a bank |
| bridges | `bridges`: khudafarin15 at x 80, khudafarin11 at x −170 (across the Araz, north-south) |
| landmarks | `landmarks` [id, x, y, z, yaw, w, d, zone, setback] from `tools/karabakh_layout.py` (footprint w along the road, d deep, front +z to the road; pad y); `lines` (shusha_wall: 8 m modules beside the plateau road on its gorge side, 3.6 m behind the run-off, a tower every 6, one gate; hakari_boulevard: 10 m modules on a terrace 1.8 m over the river); `peaks` (hocaz: x -1150, z -300, h 235, r 360, cliff face towards Laçın) |
| entry signs | `kb_sign_khankendi / shusha / lachin` (`karabakh_signs.py`): 22 m wall, letters 4–5 m, mast top (-12.6, 17, 0) = `KarabakhDecor.SIGN_MAST_TOP`, flag 7.2 × 3.6 m flying +x; placed 16–58 m before each town on the right, 1.5 m+ behind the run-off, turned 30° to the karts, 30 m forest-free lane in front |
| setbacks | every landmark front 3–9 m behind the run-off (`extra` 0 in `WANT`); far terrain LOD keeps 0.5 of a tile carrying a pad (0.06 elsewhere, 0.4 for Hoçaz) |
| landmark plots | circles covering every footprint + its view lane and the lines (forest / canopy cleared, `KarabakhDecor._reserved`), never over the run-off |
Pipeline (headless / background only):
1. `godot --headless --path . -s tools/export_road_samples.gd -- karabakh` → `tools/blender/out/karabakh_road.json` (the road is TrackPath's)
2. `blender --background --factory-startup --python tools/blender/karabakh_flora.py -- --bake-res 2048 --tex-res 1024` → `assets/models/karabakh_flora/`
3. `blender --background --factory-startup --python tools/blender/karabakh_terrain.py` (~1 min) → `assets/models/karabakh/`: 221 near tiles (3 m grid over x −1200..1248, z −912..960; decimated 0.28, road band + borders protected, 326k tris) + far tiles (0.06, borders protected, 61k, from 240 m), mountain ring (20 m grid ±2300 / −2100..2220, 27k), `River_araz`, `River_hakari`; `terrain_albedo.png` + `mountains_albedo.png` 4096² (inner: colour × AO with tree proxies; ring: colour × flat 0.71 tone, no AO); `heights.bin`; `trees.json` (8229; step 7.5 m, band 78 m, canopy from 70 m)
4. `blender --background --factory-startup --python tools/blender/karabakh_bridges.py -- --bake-res 4096 --tex-res 2048` (~5 min; `--layout-only` rewrites just `bridges.json`) → `assets/models/karabakh_bridges/` (kb_br_pier / arch_w 6.4 m / arch_n 4.8 m / ramp 9 m; kb_br11_arch 8 m / pier / ruin_a / ruin_b; deck 6.5 m and 6.9 m above the water)
5. Landmarks (0.19.1): `python tools/karabakh_layout.py` (before step 3), then `blender --background --factory-startup --python tools/blender/karabakh_{khankendi,shusha,lachin}.py -- --bake-res 4096 --tex-res 2048` (~4 min each; `kb_preview.py -- <set> [--baked]` for a quick look), `fix_imports.py` on each folder
6. `blender --background --factory-startup --python tools/blender/karabakh_render.py [-- --only bridge,overview]` → `docs/screenshots/0.19.0/` and the city card
After a rebuild: `godot --headless --import`, `python tools/blender/fix_imports.py assets/models/karabakh_flora` / `assets/models/karabakh_bridges` (terrain PNGs keep `compress/mode=2` + mipmaps in their .import).
Ground stays ≥ 0.25 m under road and verges, the chase camera clears every bank (round 34). Night: LED lamps every 46 m (alternate sides) with light pools under the heads; reflector posts every 25 m (both glow, `PropKit.PROP_GLOW` "lamps").
