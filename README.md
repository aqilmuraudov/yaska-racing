# BAKU TURBO

Original arcade kart racer set in a colourful, stylised Baku. Godot 4.4.1,
GDScript, Android-first (landscape) with Windows builds for development.

**Status: vertical slice (Milestones 1–3) implemented and verified on
desktop. Not yet tested on the target phone** — see
[docs/STATUS.md](docs/STATUS.md).

## What's in the vertical slice

- **Baku Seafront Sprint** (1.5 km): Boulevard straight by the Caspian with
  palms, balustrades and an observation wheel; climb through a twin-tower
  gate into the limestone Old City (enclosed wooden balconies, carpets,
  bunting, a keep inspired by the old tower); a risky cobbled alley shortcut;
  a ramp and boost pad on the descent back to the shore.
- **3 karts** with distinct silhouettes and handling (Bulvar balanced,
  Nar agile, Külək fast), 4 paints each, rotatable 3D preview.
- **Driving**: responsive arcade handling, hop-drift with a 3-tier timed
  boost chain, start boost, pads, landing boost, wall sliding, kart bumps,
  recovery, wrong-way detection.
- **5 AI rivals** (easy/medium/hard) using the same physics, racing lines,
  drifting, boosting, item use, shortcut decisions, stuck recovery.
- **Items**: Turbo Canister, Shield, Road Trap (pooled, ownership rules,
  immunity).
- **Modes**: Quick Race, Time Trial (versioned ghosts), Drift School tutorial.
- **UI**: main menu, mode/kart/track setup, loading, HUD (position, lap,
  timer, minimap, item, drift meter, countdown, messages, speedometer),
  pause, results with records and once-only rewards, full settings with
  Low/Medium/High/Custom graphics, audio, controls & remapping, gameplay,
  accessibility. Azerbaijani (default) and English.
- **Input**: keyboard, controller and multi-touch through one action map.
- **Audio**: original synthesized SFX, engine/drift loops and music.

## Quick start

```bash
"C:/Tools/Godot/Godot_v4.4.1-stable_win64.exe" --path . -e     # open editor
"C:/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe" --headless -s tests/run_tests.gd   # tests
```

Builds: `builds/android/BakuTurbo-debug.apk`, `builds/windows/BakuTurbo.exe`
(see [docs/BUILD.md](docs/BUILD.md)).

Controls: WASD/arrows drive, **Space** hop/drift, **Shift** drift boost,
**E** item, **Q** look back, hold **R** recover, **Esc** pause.
Full table: [docs/INPUT.md](docs/INPUT.md).

## Documentation

- [docs/PLAN.md](docs/PLAN.md) — assessment, decisions, milestone roadmap
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — systems and data flow
- [docs/TUNING.md](docs/TUNING.md) — handling, boost rules, AI, items, presets
- [docs/INPUT.md](docs/INPUT.md) — input mappings
- [docs/ASSETS.md](docs/ASSETS.md) — asset inventory, sources, licences
- [docs/BUILD.md](docs/BUILD.md) — versions, build, run, test, debug flags
- [docs/STATUS.md](docs/STATUS.md) — completed / pending / blocked, test evidence, known issues
