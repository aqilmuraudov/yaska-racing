# Status, verification evidence and known issues

Date: 2026-10-22 · Build: 0.4.0 · Engine: Godot 4.4.1-stable

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
