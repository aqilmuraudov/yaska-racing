# Implementation plan and roadmap

## Assessment and decisions (recorded)

- New project (empty folder). Engine: **Godot 4.4.1-stable**, GDScript —
  the version installed locally together with matching Android export
  templates, Android SDK 34 and JDK 17. No migration questions arose.
- Renderers: Forward+ on desktop, Mobile on Android (feature override).
  Physics: Jolt, 60 Hz fixed tick, physics interpolation for visuals.
- Content strategy: procedural, code-generated geometry, shaders and audio
  (no external assets), so everything is original, reproducible and small.
- Kart model: custom arcade controller on `CharacterBody3D` (predictable,
  cheap, wall sliding built in) instead of a rigid-body vehicle.
- Language: Azerbaijani default UI, English fallback; code/docs in English.
- Reversible defaults chosen without asking: player starts 4th of 6,
  3 laps, medium difficulty, auto-accelerate on touch, Medium preset on
  mobile / High on desktop.

## Milestones

| # | Scope | State |
|---|---|---|
| 1 Driving foundation | project, input abstraction, kart, graybox loop, camera, accel/brake/steer, collision, reset | **Done** (on-device check blocked: no device attached) |
| 2 Core racing | drift & boost, checkpoints/laps/ranking, countdown/finish, 5 AI, restart/pause, HUD | **Done** |
| 3 Vertical slice | finished Baku Seafront Sprint, 3 karts, 3 items, menus/settings, presets, audio, save/load, results & records, Android + Windows builds | **Done except on-device verification** |
| 4 Single-player systems | Time Trial + ghosts *(done early)*, Drift School tutorial *(done early)*, Cup Championship, more items (forward/homing/bouncing projectiles, pulse, catch-up item), accessibility pass, progression & customisation shop, more tracks/drivers | Partly started |
| 5 Complete offline content | 8 tracks across 4 districts (Boulevard, Old City, Flame Hills, White City/Port), Adventure map, 2 battle arenas + 2 rule sets, 8 drivers, 12 bodies, cosmetics, balancing | Pending |
| 6 Multiplayer | Windows split-screen 2–4 (per-player cameras/HUD/input), separately scoped online (authority, prediction, reconciliation, rooms, anti-cheat, hosting costs) | Pending — online must not be claimed until tested across devices/networks |
| 7 Release prep | sustained device testing, save migration, localisation review, polish, packaging, credits/licences, release checklist | Pending |

## Next steps (recommended order)

1. Install the APK on the Xiaomi Mi 12 Lite; run a 15-minute session at
   Medium and Low with `--stats`-equivalent overlay; adjust presets/budgets.
2. Touch feel pass on the device (button sizes, auto-accelerate default,
   drift/boost thumb reach) and controller pass.
3. Driver identity separate from kart body and handling class (data split
   prepared: `KartStats` = handling, `KartModel` style = body).
4. Cup Championship (scoring 15/12/10/8/6/4/2/1, tie-break by best single
   finish then total time; resumable via `SaveManager.data.cup_progress`).
5. Second track in a new district, reusing TrackBuilder/TrackDecor.
