# Progress

Single source of truth for what has actually been done and verified. Record real commands and real results. Manual checks stay PENDING until a human has done them.

## Current stage

**Phase 0, Prompt 01: project scaffold.**

- Automated verification: **PASS** (3 passes done, results below).
- Manual Windows checks: steps 1 to 6 recorded as **pass** by the developer on 2026-11-17; step 7 (touch) not applicable, no touch screen.
- Follow-up: the developer reported the Play focus ring in step 1 was "not very noticeable". Fixed in pass 3 (project theme, tests, screenshots). The developer re-checked on 2026-11-17 and confirmed the Play button is now "very noticeable". Closed.
- Overall verdict: **PASS.** Prompt 01 is signed off. Next: Prompt 02.

Next stage after sign-off: Prompt 02 (versioned level data and validation). Not started.

## Acceptance criteria for this stage (from Prompt 01)

| Criterion | Evidence | Status |
|---|---|---|
| Exact stable engine version chosen and recorded, with matching export templates identified | Godot 4.6.2-stable in `scripts/engine-version.txt`, ARCHITECTURE, README; templates named and checksummed but **not installed** | Done (templates install deferred to Prompt 17) |
| Clean project imports | `import.ps1 -Clean` exit 0 | PASS |
| Menu opens | Windowed run on real renderer, frame inspected; scene tests boot into menu | PASS (visual, one machine) |
| Scene transitions work | 14 scene tests incl. real mouse/keyboard input, headless and windowed | PASS (automated); manual PENDING |
| Empty level with restart/back controls | `LevelScreen`, tests, screenshots | PASS |
| Renderer chosen and documented | `gl_compatibility`, ARCHITECTURE | Done |
| Required docs exist | CLAUDE.md, README.md, docs/{DESIGN,ARCHITECTURE,PROGRESS,ASSETS}.md | Done |
| Test runner with reliable nonzero exits; Windows commands and prerequisites documented | `scripts/`, README | PASS |
| Checks detect an intentional failure before it is removed | See "Failure detection evidence" | PASS |

## Decisions

| Decision | Choice | Notes |
|---|---|---|
| Engine | Godot 4.6.2-stable standard build, `4.6.2.stable.official.71f334935` | Checked 2026-11-17: latest stable is 4.7.2, latest 4.6 patch is 4.6.3. 4.6.2 kept because it is installed and its zip matches the official SHA-256. Upgrading means revalidation. |
| Export templates | `Godot_v4.6.2-stable_export_templates.tpz` | **Not installed.** Needed from Prompt 17. |
| Renderer | `gl_compatibility` | Rationale in ARCHITECTURE. |
| Tests | Small explicit runner | GUT 9.7.1 is the fallback option. |
| Physics tick | 60/s, guarded by test | |

## Built

- `project.godot` (renderer, 1920x1080 design size, `canvas_items`/`expand` stretch, landscape, 60 tick physics, `untyped_declaration` as error).
- `AppRoot` screen owner, `MainMenu` (Play, Quit), `LevelScreen` (Back, Restart, `BoardRoot` placeholder, Esc = back).
- `SimConfig` (tick constants and conversions), `UiMetrics` (design size, 96x96 minimum hit size).
- Test tooling: `tests/runner/{test_runner,test_case,parse_check}.gd`, `tests/scene/scene_test_case.gd`, PowerShell scripts in `scripts/`.
- Docs: CLAUDE.md, README.md, docs/{DESIGN,ARCHITECTURE,PROGRESS,ASSETS}.md.

## Verification pass 2 (2026-11-17)

Git: this folder is not a repository, so there is no status or diff to inspect and no unrelated work at risk. Only files created by this project (plus the user's prompt pack and `.claude/settings.local.json`, both untouched) exist.

Commands run and actual results (Windows 11, PowerShell 5.1, Godot 4.6.2 at `C:\Tools\Godot\godot.exe`, GTX 1060, OpenGL 3.3 Compatibility)

| Command | Result |
|---|---|
| `scripts\test-all.ps1 -Clean` (baseline, before changes) | exit 0 |
| `scripts\test-all.ps1 -Clean` (final, after changes) | exit 0: import, parse (19 files, 0 failures), harness (6 of 6 detected), domain (9 passed), scene (14 passed) |
| `scripts\test-scenes.ps1 -Windowed` (real window, real OpenGL renderer, synthetic input) | exit 0, 14 passed |
| `scripts\check-env.ps1` | exit 0, warning only: export templates not installed |
| `GODOT_BIN` = .NET build, then = nonexistent path | `check-env` exit 1 both times; `test-domain` with the .NET build exit 10; unset (PATH) exit 0 |
| Screenshot script (windowed, 1280x720 and 1000x1000) | exit 0; menu and level frames inspected, controls on screen, centred, not overlapping |

Defects found in pass 2 and fixed

1. **Scene tests ran in a distorted viewport.** The headless root window is 64x64, so layout was computed in a 1920x1920 space, not 16:9. Fixed: `SceneTestCase` sets an explicit window size for every test and restores it.
2. **Weak hit-area check.** The old test only read `custom_minimum_size`. Now the laid-out rectangles are measured in design units at 6 window sizes (1280x720, 1366x768, 1920x1080, 2560x1080, 1600x1200, 3840x2160).
3. **Input path not exercised.** Old tests called `pressed.emit()` and the Esc handler directly. New tests send real mouse clicks and key events through the viewport input pipeline, including clicks that must do nothing and a double click in one frame.
4. **`GODOT_BIN` silently fell back to `PATH`.** An invalid explicit value now fails loudly (see table). The README claim that the scripts reject the .NET build is now true and verified.
5. **Untested wiring and focus.** Added tests for Play initial focus plus Enter activation, Quit/Play signal wiring, and `screen_changed` firing exactly once per transition.
6. A test-helper mistake (not a game bug): `InputEventAction` is not routed to the focused control by Godot, so keyboard activation is tested with real `InputEventKey`.

Tests replaced, not deleted: `test_ui_cancel_on_level_goes_back` (direct handler call) is superseded by `test_escape_goes_back_from_level_only` (real key through the pipeline); `test_all_buttons_meet_minimum_hit_size` (property read) is superseded by the laid-out-rectangle test. Node-leak check strengthened: 50 menu/level/restart cycles now also compare the engine node count before and after.

Mutation evidence (temporary edits to game code, each reverted; files verified byte-identical afterwards)

| Mutation | Scene tests |
|---|---|
| Play button height 96 to 60 | exit 1, hit-area test fails |
| Remove initial focus | exit 1, keyboard test fails |
| Restart no longer creates a fresh level | exit 1, 3 tests fail |

Failure detection evidence (acceptance requirement, from pass 1 and still valid)

1. Changed an expectation in `tests/domain/test_sim_config.gd` (60 to 61) and in a scene test. `test-domain.ps1` and `test-scenes.ps1` exited **1** with the right messages; both edits reverted, both suites exited 0.
2. `verify-harness.ps1` permanently re-proves detection of: failed assertion (exit 1), test with no assertions (exit 1), runtime script error inside a test (Godot exit **0**, caught only by the output scan), missing test directory (exit 1), unknown suite (exit 2), parse error (exit 1).

## Verification pass 3: focus ring feedback (2026-11-17)

Trigger: manual step 1 feedback that the Play button's keyboard focus outline was not very noticeable (Godot's default is a thin, low-contrast line).

Fix: a project-wide theme, `themes/base_theme.tres`, set through `gui/theme/custom` in `project.godot`. It overrides only the Button focus style: 6 unit bright brass border (`#FFCC33`) around the button plus a dark outer edge, drawn outside the button so it never covers the label. Two tones are required because no single colour contrasts with both the cream menu and the dark teal level background. `UiMetrics.MIN_FOCUS_RING_WIDTH` (4) is the guarded minimum.

Evidence

| Check | Result |
|---|---|
| `scripts\test-all.ps1 -Clean` | exit 0: parse 20 files 0 failures, harness 6 of 6, domain 9 passed, scene 15 passed |
| New test `test_focus_ring_is_thick_two_tone_and_applied_to_every_button` | passes; asserts ring width, opaque colour, dark outer edge, no centre fill, and that every Button on the menu and level screens resolves to the theme's ring |
| Mutation: remove the `gui/theme/custom` line | scene tests exit 1, new test fails; project restored, 15 of 15 pass |
| Screenshots at 1280x720 (windowed, real renderer) | Focus ring clearly visible on the Play button (cream background) and the Back button (teal background); inspected by eye |

Limits: the test checks the style resource and its application, not rendered pixels (headless has no renderer). Visibility itself rests on the screenshots and the developer's re-look. Full focus handling (initial focus on every screen, tab order) is still Prompt 15.

## Checks not applicable at this stage

Collision layers and masks, collision versus visible geometry, fixed-tick state changes, deferred physics-safe changes, object IDs, collection and loss accounting, one-shot events, terminal states, timers, input during animation, pause/resume, hint and replay regressions, and generator checks do not apply: there are no physics bodies, rules, animations, timers, pause or generator yet. Nothing here claims physics ran. Restart cleanup and stale callbacks are covered only at screen level (fresh instance, old one freed, no node growth, no extra `screen_changed`).

## Limitations and known gaps

- Headless runs use dummy display and audio. Windowed runs use the real renderer but synthetic input. Neither proves real mouse or touch feel, OS display scaling, or window-manager behaviour.
- On-screen size scales with the window: at 1280x720 a 96-unit control is 64 physical pixels. Revisit the minimum hit size and a minimum supported window size during the usability stage (Prompt 15), ideally on a touch device.
- The Quit button's actual quit is not automated (it would end the test process); only its signal wiring is tested.
- Level screen has no initial keyboard focus (only the menu does). Deferred to Prompt 15.
- Godot exits 0 after some script runtime errors, so the PowerShell scripts, not bare `godot` commands, are the source of truth for pass/fail.
- The runner's "no assertions" rule is a safety net; the engine-output scan covers tests aborted by a script error.
- Export templates are not installed and no export has been attempted.
- This folder is not a Git repository, so no checkpoint exists. `.gd.uid` files are generated by Godot 4.6 and should be committed with their scripts.
- No assets, fonts or audio beyond Godot defaults; the default theme styling is intentional until the art stage. The only theme override is the Button focus ring (`themes/base_theme.tres`).

## Manual test script (PENDING, needs a human on Windows)

Run `godot --path .` from the repo root or press F5 in the Godot 4.6.2 editor. Watch the Output panel for red errors throughout.

1. Menu appears with title, Play and Quit; Play has a focus outline. - pass (focus outline reported "not very noticeable"; strengthened in pass 3, developer re-checked: pass)
2. Click Play, click Restart, click Back, click Play, press Esc. Expected: level, fresh level, menu, level, menu. - pass
3. On the menu press Enter. Expected: Play activates. - pass
4. Click Quit. Expected: the window closes and the process ends. - pass
5. Drag the window to very wide, very tall and small sizes. Expected: buttons stay on screen and clickable. - pass
6. Windows display scaling at 100%, 150% and 200% (Settings > Display). Expected: nothing clipped or tiny. - pass
7. Touch screen, if available: tap each button. (no touch screen)

Record pass or fail for each here, then mark the stage PASS.

## Next stage

Prompt 02: versioned `LevelDefinition` with validation and one original three-pin test level. Prerequisites in place: layering rules, ID conventions, validated-JSON rule, test runner, `SceneTestCase`, fixtures pattern.
