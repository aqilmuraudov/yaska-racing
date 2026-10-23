# Status, verification evidence and known issues

Date: 2026-10-23 · Build: 0.5.0 · Engine: Godot 4.4.1-stable

## Update 0.5.0 — Android interaction fixes, compact Settings, cheerful Baku

**No Android device was attached** (`adb devices` empty). Everything below is
verified on desktop (Mobile renderer, injected touch events, unit tests) or
by reading the Godot 4.4.1 Android sources. Physical tilt, finger feel and
phone performance are **pending a device check**.

### Root causes and fixes

| Problem | Root cause (evidence) | Fix |
|---|---|---|
| Scrolling heavy, delayed, stepped on the phone | (1) `TouchScroll` truncated each drag delta with `int()`; with the 1280×720 canvas stretched ×1.5 on a 2400×1080 phone, slow drags (< 1 viewport px per event) moved 0 px and faster ones lost the fraction; (2) fling speed came from millisecond timestamps (0 ms gaps → spikes); (3) the ScrollContainer's own touch drag only switches on when a touchscreen exists, so on phones two drag/inertia systems fought (desktop tests never saw it); (4) the cancel-release sent when a drag started still fired/toggled the control, because `BaseButton` decides from `pressing_inside`, which only motion events update (reproduced: a drag over a switch toggled Bloom) | One shared `TouchScroll` (`scripts/ui/touch_scroll.gd`) for every scroll view: float offsets, 100 ms µs-sampled release velocity, exponential frame-rate-independent glide, built-in drag disabled (`MOUSE_FILTER_IGNORE`), off-control motion + release on drag start, a touch on a gliding list stops it and activates nothing, one mouse-only input stream (emulated from the first finger), wheel/trackpad support, `PROCESS_MODE_ALWAYS` for pause. `SafeSlider` for the developer list (changes only on tap or sideways drag) |
| Tilt does nothing | (1) Godot 4.4 registers Android sensors only if `input_devices/sensors/enable_*` is true; the defaults are **false** (`core/input/input.cpp`, `Godot.kt` registerSensorsIfNeeded) and project.godot did not set them, so `get_accelerometer()` returned zero; (2) the code read `acc.y`, but Godot already rotates samples into the display orientation (`GodotInputHandler.onSensorChanged`) and negates them, so steering is screen **x**; `y` is pitch and would have pinned the kart to full lock | Sensors enabled; `TiltSteering` uses `get_gravity()` (fused) with accelerometer fallback and bump rejection, screen-x axis, stale-180°-rotation correction, wheel-angle/lean blend, 1.8° dead zone, three levels (30°/22°/15° full lock), 40/110 ms low-pass on the fixed tick, calibration, reset on pause/background/mode switch, buttons fallback with a notice, debug overlay (debug builds) |

Also fixed: the racer preview rotated twice per finger movement (handled both
`ScreenDrag` and the emulated mouse motion); scenery textures were imported
lossless without mipmaps (now VRAM-compressed ETC2/ASTC with mipmaps).

### Implemented
- **Settings** replaced by four tabs — Graphics (Texture Quality, Frame Rate
  30/60/90/120 gated by the display refresh rate, Shadows Off/Low/Normal/High),
  Audio (Master / Music / Sound Effects switches; Master keeps the other two
  choices), Controls (Control Type, Button Size, Automatic Acceleration,
  Steering Sensitivity, Calibrate with a live tilt bar), Language (flag icons
  plus names) — and Back and Restore Defaults with confirmation. Renderer and
  tuning options moved to a debug-build-only developer tab (long-press the
  title; English only). Settings v2 with migration from v1 (no resets).
- Texture Quality changes real assets: 256 / 512 / 1024 px texture tiers
  swapped in place (`TextureLibrary`), plus mip bias and anisotropy.
- One cheerful theme: generated glossy 9-patch buttons/panels, 20 SVG icons,
  outlined Baloo headings, bounce and sparkle micro-animations; main menu
  (Baku plaza stage, idle reactions), racer select, loading, pause, results,
  HUD and touch buttons restyled; all text localized and re-labelled live.
- Track: painted textures (asphalt, setts, limestone, paving, grass), lighter
  blue haze, warm sun, glossy kart paint, flower planters; **six landmarks**:
  National Flag Square (waving flag, correct blue/red/green, crescent and
  eight-pointed star) dead ahead on the Boulevard straight, Heydar Aliyev
  Center beside the modern connector, Flame Towers above the Old City walls,
  Maiden Tower in the Old City, Baku Crescent in the bay on the return leg,
  improved Boulevard (planters, palms, benches, balustrade, wheel facing the
  road). Footprints are reserved so scatter never overlaps them; nothing was
  added on the driving corridor; far LODs beyond 380 m.
- Audio: major-key menu (112 BPM) and race (138 BPM) loops, victory jingle on
  the Music bus, marimba UI, bell countdown, overtake cue, sea ambience
  (pauses with the race). All original (numpy synthesis).

### Verified (desktop)
- Tests: **59 test methods, 761 checks, 0 failures** (new
  `test_controls_settings.gd`: tilt axis/direction incl. flat hold and stale
  rotation, dead zone/bounds/monotonic curve per level, 30 vs 120 Hz filter
  equality, bump rejection, calibration, tilt reaching `KartInput.steer` and
  turning the kart right/left while LEFT is held, buttons fallback after no
  data, button ramp levels with exact full lock, v1→v2 migration, audio
  switches, texture tiers, FPS options).
- `--ui-flow` with injected touches, 0 failures at 1600×720 (touch) and
  1280×720: a slow sub-pixel drag follows the finger (30.0 of 30 px),
  direction reversal, drags starting over rows change nothing, a flick
  glides, a touch stops the glide and taps nothing — in the main-menu
  Settings **and** in the paused race; Settings opens from menu and pause;
  a live language switch in the paused race keeps race time and pause.
- Frame-rate independence: `--probe=12` output identical at `--fixed-fps 30`
  and `144` (steering ramp and tilt filter run on the 60 Hz physics tick).
- Landmark gameplay views: `--landmark-views` (chase camera on the racing
  line) — `docs/screenshots/0.5.0/landmark_*.jpg`; Boulevard in
  `after_race_return.jpg`.
- Azerbaijani and English screenshots reviewed for clipping.
- APK exported and signed (`builds/android/BakuTurbo-debug.apk`, 35.6 MB,
  `apksigner verify` OK; sensor settings present in `project.binary`);
  Windows exe rebuilt.

### Performance (desktop proxy, back-to-back A/B, `docs/perf/ab_back_to_back.txt`)
RTX 3070, Mobile renderer, 1600×720, seed 5, 75 s autopilot, both builds run
in the same machine state. (A single earlier baseline read 1.25 ms GPU on
Medium because of GPU clocking, so only back-to-back pairs are compared.)

| Preset | Draws med/p95 before → after | Prims | GPU ms med (p95) before → after | VRAM | Frames >20 ms |
|---|---|---|---|---|---|
| Low | 124/168 → 126/172 | 172k → 173k | 1.22 (1.38) → 1.22 (1.67) | 75 → 79 MB | 0 |
| Medium | 170/216 → 175/223 | 303k → 316k | 2.58 (3.02) → 2.59 (3.23) | 92 → 97 MB | 0 |
| High | 207/272 → 213/284 | 478k → 482k | 4.03 (5.86) → 4.01 (5.52) | 144 → 151 MB | 0 |

Static memory 168–171 → 155–158 MB; objects 3935 → 4072. Before the
texture-import fix Medium measured 2.86 ms (p95 4.78): uncompressed,
mip-less textures were the cost, not the landmarks.

### Pending (needs the Xiaomi Mi 12 Lite)
- Tilt direction, comfort, calibration and the Low/Normal/High feel on the
  real sensor; behaviour after a 180° flip; the buttons-fallback notice.
- Finger feel of scrolling and flings; accidental-tap check by hand.
- Which FPS caps the phone reports as supported (Godot reports the current
  display mode; Android may keep the app at 60 Hz), frame pacing, thermals,
  memory over a 15-minute session.
- Music and effects by ear on the phone speaker; backgrounding with audio.

### Remaining limitations
- The developer tab is English-only (debug builds, hidden).
- Landmarks are stylised low-poly interpretations scaled to the circuit.
- Low p95 GPU rose slightly (1.38 → 1.67 ms) when glass landmarks are in view.
- Keyboard/controller remapping is no longer exposed to players.

---

## Previous release (0.4.0)

## Update 0.4.0 — Settings fix, animal racers, UI/graphics/perf pass

### Fixes
| Problem | Root cause | Fix | Evidence |
|---|---|---|---|
| Settings inaccessible during a race | Pause→Settings assigned the settings root (a `Node`) to a `Control`-typed variable → script error, overlay never opened | Typed as `Node` | `--ui-flow` (injected touch taps): Race→Pause→Settings→Back→Resume passes; race clock frozen in Settings; still paused after Back |
| Settings unusable on a phone | Rows (buttons/sliders/selectors) swallowed touches, so the list could not be scrolled with a finger | `TouchScroll`: vertical drag past 14 px scrolls with inertia and cancels the tap underneath | `--ui-flow`: drag scrolls 0→~495 px and changes no setting |
| Settings showing options with no effect | Unsupported options were shown disabled | Hidden per platform: 30/60 FPS on phones; VSync/window/SSAO hidden where unsupported; touch options only with touch | code + screenshots |
| Full-screen panels sized 0×0 (results drawn off-screen when docked) | `set_anchors_preset` does not resize existing controls | `set_anchors_and_offsets_preset` everywhere | results/pause screenshots |
| Karts pinned nose-first on barriers | Steering authority scaled with speed, which a wall holds at 0 | Wall-contact pivot authority + low-speed alignment along the barrier toward the race direction | chaos driver: stuck >1 s 21–30/run → 0–1/run (max 1.6 s incl. deliberate braking) |
| Respawn could be read as a gate crossing | Teleport segment evaluated by the gate test | Respawn resets the previous position | code; lap/gate tests pass |

### New content
- Six racer packages (data resources): Posi/panda/Bamboo Sprint, Bicok/fox/Amber Dash,
  Ləlöyün/rabbit/Hop Rocket, Məstan/cat/Velvet Slide, HavHav/dog/Buddy Rally,
  Çəpiş/lamb/Cloud Booster — exact names, rating table as specified, ratings mapped
  through bounded curves (see TUNING.md); balance spread 1.8 %.
- Procedural animal drivers (shared rig, species ears/muzzles/markings/tails,
  accessories) with blink, breathing, steering with paws on the rim, lean, jump/land,
  boost, hit, victory, ear/tail motion; six distinct kart bodies; identical collision.
- Racer selection (6 cards with drawn portraits, one live preview, 5 stat bars,
  specialty, Start Race, race-setup button); the separate kart/paint picker is gone;
  AI uses the other five racers; last racer saved.
- HUD: position badge with up/down change cue, lap and timer pills + pause (upper
  right), minimap lower-left (above steering buttons on touch), item slot by the
  driving controls, trap-ahead warning; results docked right so the winner
  celebrates on screen.
- Graphics: contact shadows on all presets, deeper sky and warmer grade, red/white
  barrier caps, "BAKU TURBO" gantry and "İÇƏRİŞƏHƏR" gate signage, landing dust and
  boost bursts, closer chase camera.

### Performance (desktop proxy: RTX 3070, **Mobile renderer**, 1600×720, one full race lap, `--stats`)
| | Draw calls med / p95 | Primitives med | GPU ms med | CPU process+physics ms | Frames >20 ms | Static mem |
|---|---|---|---|---|---|---|
| Medium before | 223 / 298 | 319k | 2.41 | 2.21 + 2.79 | 1 | 131–134 MB |
| Medium after | 254 / 299 | 340k | 2.73 | 2.10 + 2.66 | 0 | 153–156 MB |
| Low before | 166 / 211 | 160k | 0.53 | 2.18 + 2.88 | 0 | 130–132 MB |
| Low after | 200 / 241 | 188k | 1.30 | 1.94 + 2.42 | 0 | 153–155 MB |
| High after | 286 / 371 | 522k | 1.78 | 2.42 + 3.02 | 0 | 154–156 MB |

Six animated animal drivers first raised Medium to 310 draws; merging kart surfaces,
one node per rear axle, a shared eye node, no wheel shadows and a 45 m draw distance
for small driver parts brought it to 254. Repeated races (9 consecutive, headless):
memory 109.0–109.3 MB, objects ~4155 — no growth.

### Verification
- Tests: **48 test methods, 683 checks, 0 failures** (adds `test_racers.gd`: names,
  ratings, rating→handling direction and bounds, identical collision, selected racer
  loads with five distinct rivals, selection persists and old ids migrate).
- `--ui-flow` passes at 1280×720 and at 1600×720 with touch controls (uses a temporary
  profile, never the player's).
- AI races at easy/medium/hard complete with 0 recoveries; chaos driver 16 runs:
  1 automatic recovery (valid respawn; trigger not reproduced since).
- APK rebuilt and signed (`builds/android/BakuTurbo-debug.apk`, 30.1 MB); Windows exe rebuilt.

### Still unverified (no Android device attached — `adb devices` empty)
Frame rate / frame-time / thermals on the Xiaomi Mi 12 Lite, sustained play on the
phone, real notch insets, touch feel of the new layout, vibration, OS suspend/resume.

### Remaining issues
- Animals are procedural low-poly forms (no sculpted fur, no skeletal rigs); expressions
  are limited to blinking, head/ear/tail motion and poses.
- Memory rose ~23 MB (unique meshes per racer); acceptable on 8 GB, but meshes could be
  shared between duplicate AI racers when more than six race.
- Balance measured with AI on one track only; human playtests needed.
- One unexplained automatic recovery in chaos testing.

---

## Previous release (0.3.0)

Legend: **Implemented** = code exists and runs; **Verified** = checked by an
automated test, a measured run or a reviewed screenshot (evidence named);
**Unverified / blocked** = not checked, with the reason.

## Completed (implemented and verified on desktop)

| Area | Evidence |
|---|---|
| Fresh start reaches main menu (boot → menu) | menu screenshots via `--screens`, profile deleted beforehand |
| 3 selectable karts, paints, rotatable preview | kart-select screenshot; `KartFactory` used for all three in seeded races |
| Six racers complete a valid 3-lap race | `test_full_race_completes_with_results`; seeded headless races (all 6 finished, 0 recoveries) |
| Checkpoint skipping cannot award laps; line rocking cannot fake laps | `test_skipping_checkpoints_awards_nothing`, `test_backward_over_finish_cannot_fake_a_lap`, `test_backward_crossing_undoes_and_no_duplicate_events` |
| Shortcut merges into checkpoint route; no gate inside the skipped section or reachable from the alley | `test_seafront_checkpoint_layout_is_valid` (309 checks); AI uses the alley 0–2× per race without recoveries |
| Ranking (finish time, then clamped race distance) | `test_ranking_by_progress_and_finish`, `test_distance_clamped_to_next_gate`, `test_race_runs_and_ranks_six_racers` |
| Drift / boost chain, caps, cancellation (same rules for AI) | `test_boost_drift.gd` (8 tests) |
| Three items, ownership, arming, shield, hit immunity, single slot, disabled in Time Trial | `test_items.gd` (7 tests) |
| Save/load, backup recovery, version guard, type validation, records | `test_persistence.gd` |
| Rewards applied once; reloading results does not duplicate | `test_reward_granted_once_per_event`, `test_results_reapplied_do_not_duplicate` |
| Settings persist and sanitize; presets differ measurably | `test_settings_persist_and_sanitize`, `test_presets_change_settings_measurably`; draw calls/primitives per preset in `docs/TUNING.md` |
| Restart clears all race state (items, traps, boosts, timers, AI, inputs, trackers), no node leaks | `test_restart_clears_race_state` (60 checks) |
| Repeated races: object count stable | `test_repeated_restarts_do_not_grow_memory`; soak below |
| Simulation independent of render frame rate | `test_simulation_independent_of_render_frames`; **identical** probe output at `--fixed-fps 30` vs `144` |
| Simultaneous touch, slide steering, release on interruption; layout fits 16:9 and 20:9 | `test_simultaneous_touches`, `test_touch_layout_fits_wide_and_16_9_screens`; touch screenshots 1280×720 and 1600×720 |
| App suspension: race pauses, inputs released, profile/settings saved | `test_focus_loss_pauses_and_releases_input`; code paths in `Game._notification` |
| Azerbaijani UI renders (ə ı İ ö ü ş ç ğ) and fits | font coverage check; screenshots of every menu and HUD in `az` |
| AI difficulty differs by skill, not teleporting | seeded races: easy/medium/hard AI median best lap 60.9 / 54.9 / 53.0 s; speed factors ≤ 1.0 + ≤ 3 % capped catch-up |
| Android APK builds and is signed (arm64-v8a, debug keystore) | `builds/android/BakuTurbo-debug.apk` (≈ 30 MB), data/translations present in package |
| Windows release builds and runs a race | `builds/windows/BakuTurbo.exe`, smoke race via log |
| Pause → Settings overlay, results, Drift School, Time Trial ghost playback, shortcut fork/alley | screenshots reviewed; ghost shows stored best lap and drives ahead |
| Mobile renderer compatibility | game run with `--rendering-method mobile` at 1600×720, screenshots reviewed |

Test suite: **42 test methods, 626 checks, 0 failures** (`tests/run_tests.gd`).

## Implemented, verified only partially

| Item | What is missing |
|---|---|
| Drift boosts "consistent" with keyboard / controller / touch | All three feed the same actions (tested for touch and InputMap); not hand-played on a physical controller or phone |
| Audio | Generated and analysed numerically (levels, loop seams, loop metadata imported); **not listened to by a human** in this session |
| Controller button prompts | Xbox/PlayStation/Nintendo naming implemented; no physical pad was connected |
| Tilt steering | Implemented from the accelerometer; needs a phone |
| Visual quality | Reviewed in screenshots; not reviewed on a phone screen |

## Blocked (needs the physical device)

- **On-device performance** on the Xiaomi Mi 12 Lite (60 FPS target, 15-min
  sustained session, thermal behaviour, memory): no Android device was
  attached (`adb devices` empty). Desktop soak results are a proxy only.
- Touch feel, safe-area insets on the real notch, Android suspend/resume
  with the OS, audio focus, vibration.
- Install and first-launch test of the APK.

## Desktop soak (proxy)

20-minute real-time session, Mobile renderer, Medium preset, 1600×720
(20:9), autopilot, continuous 3-lap races (`--soak --stats`), RTX 3070 desktop.

| Window | Result |
|---|---|
| First 15.4 min, unattended (5 complete races, auto-restarts) | 60 FPS every second; **0 frames over 20 ms**; static memory 120.6–124.6 MB (124.1 → 124.4 MB at each race end); objects 3505–3643; draw calls median 161, p95 243, max 309; primitives median 0.30 M, max 0.54 M |
| Remaining minutes | someone interacted with the window (pause, settings, menu, new race); this exposed a bug — opening Settings from the pause menu failed (typed variable) — now fixed and covered by `test_pause_settings_overlay_opens_and_closes` |

This is a **desktop proxy**. It does not demonstrate the phone target.

## Known issues / limitations

- Track scenery is procedural and stylised; buildings are instanced from a
  small kit (4 Old City houses, 3 modern blocks), so repetition is visible
  up close.
- Drivers are not yet separate characters (one helmeted driver style; the
  driver/kart/handling split is planned for Milestone 4).
- Only items in the first set exist; the "incoming attack" warning is not
  needed until projectiles are added.
- The chase camera is kept inside the barrier corridor by a collision ray
  (barriers have 4.5 m invisible collision), so it never enters buildings;
  rival karts that come between camera and player fade out.
- Ghost lap 1 includes the standing start; later laps are flying laps.
- AI uses the shortcut with fixed probabilities per difficulty.
- Desktop measurements only; budgets must be re-set after phone profiling.

## Not implemented (future milestones)

Cup Championship, Adventure, Battle mode/arenas, additional tracks/drivers/
bodies, cosmetics shop, split-screen, online multiplayer (not started, and
not to be described as implemented until tested across devices/networks).
