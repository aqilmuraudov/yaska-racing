# Architecture

Godot 4.4.1, GDScript. Everything visual on the track is generated from data
at load time, so collision, checkpoints, AI paths and visuals always agree.

## Layout

```
project.godot            engine config (autoloads, 60 Hz physics, interpolation, renderers)
export_presets.cfg       Android + Windows exports
data/                    data-driven definitions
  vehicles/*.tres          KartStats per handling class (balanced, agile, fast)
  tracks/*.json            centreline, widths, themes, checkpoints, shortcut, pads, ramp, items
  items/items.json         item params and position roll tables
  difficulty/profiles.json AI skill profiles
  graphics/presets.json    Low/Medium/High
scenes/                  thin scene files (root node + script)
scripts/
  core/        game flow (Game), settings, camera, boot, debug runner
  input/       InputActions (single action map), PlayerInput, TouchControls
  vehicles/    KartController (simulation), KartBoost, DriftMeter, KartVisual/Model/Effects, factory
  ai/          AIDriver
  racing/      RaceManager, RaceTracker, environment, ghosts, tutorial
  items/       ItemSystem
  track/       TrackPath, TrackData, TrackBuilder, TrackDecor, PropKit, MeshBuilder
  ui/          theme, HUD, menus, widgets
  audio/       AudioManager, KartAudio
  persistence/ SafeFile, SaveManager
localization/strings.csv  az + en (Godot CSV translations)
assets/        fonts, shaders (assets/materials), generated audio, icon
tests/         headless test runner + suites
tools/         checkers, audio generator, track checker
```

## Autoloads

| Name | Responsibility |
|---|---|
| `Settings` | persistent settings (JSON, versioned, safe-write), preset application, viewport graphics, dynamic resolution, language, input remaps |
| `SaveManager` | profile: selections, currency, records, ghost metadata, reward ledger, tutorial flags |
| `AudioManager` | buses (Music/Engine/SFX/UI), pooled 2D/3D voices, limiter, music crossfade, focus muting |
| `Game` | scene flow state machine and race configuration; installs UI theme |

## Flow

Boot → Main Menu → Mode → Kart → Track/Setup → Loading (threaded) → Race
(INTRO → COUNTDOWN → RACING → FINISHING → RESULTS). Pause is an overlay that
works with the tree paused; restart resets in place.

## Simulation

- `KartController` (CharacterBody3D, upright, yaw only): signed forward
  speed + decaying lateral slip + vertical speed, rebuilt each 60 Hz tick.
  States: NORMAL, HOP, DRIFT, AIR, HIT, RECOVER. Floor-plane following keeps
  crests from launching karts while real ramps do.
- Visuals never write back: `KartVisual` reads state on the physics tick
  (physics interpolation smooths it); the camera reads the interpolated
  transform in `_process`.
- `KartBoost` and `DriftMeter` are pure logic (unit-tested), shared by
  player and AI. AI only produces `KartInput`.
- Kart contacts: CharacterBody sliding + symmetric capped bump in
  `RaceManager._resolve_contacts`.

## Race rules

`RaceTracker` counts gates in order (`cp_count`), undoes on backward
crossings, and derives a race distance clamped between the last and next
gate. Ranking: finished by time, then race distance. Shortcut positions map
onto main-route distance; no checkpoints sit in the skipped section (tested).

## Rendering and performance

Shared shaders (road, curbs, ground, limestone, water, vertex-colour props),
merged multi-material props (one vertex-coloured surface per prop),
MultiMesh chunks with visibility ranges for scenery, low-poly helpers,
blob shadows on Low, per-preset shadow distance/atlas, fog matched to the
scenery distance. Race-critical collision is independent of presets.

## Persistence

`SafeFile`: write temp → verify → keep previous as `.bak` → rename. Reads fall
back to the backup; validators reject newer versions or wrong types.
Rewards are applied once per race instance id (ledger). Android pause /
close saves profile and settings.
