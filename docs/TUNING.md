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
Prices live in `scripts/progression/kart_shop.gd` (`PRICES`, qəpik). New profiles own only HavHav.
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

