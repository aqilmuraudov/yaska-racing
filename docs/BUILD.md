# Build, run and test

## Supported versions (pinned)

| Tool | Version | Notes |
|---|---|---|
| Godot Engine | **4.4.1-stable** (official, win64) | Editor + export templates `4.4.1.stable` |
| Rendering | Forward+ (desktop), **Mobile** (Android, via `rendering_method.mobile`) | Physics interpolation on, 60 Hz fixed tick |
| Physics | Jolt Physics (built into 4.4) | `physics/3d/physics_engine="Jolt Physics"` |
| Android SDK | Platform 34, build-tools 34.0.0 | Paths configured in Godot editor settings |
| Java | Temurin JDK 17 | |
| Python | 3.13 + numpy (tools only) | Audio generator, CSV/script checkers |

No third-party Godot add-ons are used. Fonts are bundled (OFL).

## Run

```bash
# Editor
"C:/Tools/Godot/Godot_v4.4.1-stable_win64.exe" --path . -e
# Play from the command line
"C:/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe" --path .
# Preview the Android renderer on desktop
... --path . --rendering-method mobile --resolution 1600x720
# Unusable display settings? Start in safe mode (Low preset, windowed):
... --path . -- --safe-mode
```

## Tests

```bash
G="C:/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe"
python tools/check_scripts.py            # parse every .gd file (refreshes class cache)
python tools/check_csv.py                # localisation table sanity
"$G" --headless -s tests/run_tests.gd    # unit + integration tests (exit code 0 = pass)
"$G" --headless -s tests/run_tests.gd -- --only=test_items   # subset
```

## Debug runner (development harness)

Arguments after `--` (see `scripts/core/debug_runner.gd`):

| Flag | Purpose |
|---|---|
| `--race` | skip menus, load a race directly |
| `--autopilot` | the player kart is AI-driven (never writes records/rewards) |
| `--seed=N --difficulty=easy\|medium\|hard --kart=ID --laps=N --ai=N --mode=quick\|time_trial\|tutorial` | race setup |
| `--graphics=low\|medium\|high` | apply a preset for this run |
| `--capture=DIR --capture-times=a,b` | screenshots at race times |
| `--overview`, `--views=s1,s2` | top-down layout shot, fixed cameras along the track |
| `--screens=main,mode,kart,track,settings0..4,credits` | menu screenshots |
| `--stats` | per-second FPS, worst frame, memory, objects, draw calls, primitives |
| `--probe=T` | print every kart's state on the physics tick where race time ≥ T |
| `--quit-after=S`, `--quit-on-results`, `--soak`, `--timescale=X`, `--touch`, `--log-hits` | soak / balancing helpers |

Frame-rate independence check (identical output expected):

```bash
"$G" --headless --fixed-fps 30  --path . -- --race --autopilot --seed=5 --probe=12
"$G" --headless --fixed-fps 144 --path . -- --race --autopilot --seed=5 --probe=12
```

## Export

`export_presets.cfg` defines **Android** (arm64-v8a, debug-keystore signed APK,
immersive, landscape sensor, vibrate permission) and **Windows** (x86_64,
embedded PCK).

```bash
"$G" --headless --path . --export-debug   "Android" builds/android/BakuTurbo-debug.apk
"$G" --headless --path . --export-release "Windows" builds/windows/BakuTurbo.exe
# Install on a device (USB debugging enabled):
C:/Tools/AndroidSdk/platform-tools/adb.exe install -r builds/android/BakuTurbo-debug.apk
```

A release-signed Android build needs a release keystore (not created; do
not commit keystores). `builds/` is git-ignored.

## Regenerating generated content

- Audio: `python tools/audio/generate_audio.py` (deterministic).
- Track meshes, scenery, karts, UI theme: generated at runtime from data and
  code; nothing to bake.
