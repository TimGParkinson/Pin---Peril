# Progress

Single source of truth for what has actually been done and verified. Record real commands and real results. Manual checks stay PENDING until a human has done them.

## Current stage

**Prompt 03 (walls, tokens and reliable 2D physics): implemented 2026-11-17. All automated checks PASS (parse 58 files, harness 6 of 6 detected, domain 98, scene 37, physics 31; scene also windowed, physics also windowed). Manual check DONE 2026-11-18 (user reported it done, no issues; script at the end of the "Prompt 03" section). The Verification Prompt was run 2026-11-18: PASS (see "Verification pass"; scene tests now 39).** Prompt 04 may start when the user supplies it.

**Prompt 02 (versioned level data and validation): verification pass done 2026-11-17, PASS pending a 30-second manual re-look of the level screen.** The level screen changed again in Prompt 03, so the re-look is folded into the Prompt 03 manual script below (steps 1, 5 and 8). Details in "Prompt 02" and "Verification pass" below.

**Prompt 01 (project scaffold): signed off, PASS.**

- Automated verification: **PASS** (3 passes done, results below).
- Manual Windows checks: steps 1 to 6 recorded as **pass** by the developer on 2026-11-17; step 7 (touch) not applicable, no touch screen.
- Follow-up: the developer reported the Play focus ring in step 1 was "not very noticeable". Fixed in pass 3 (project theme, tests, screenshots). The developer re-checked on 2026-11-17 and confirmed the Play button is now "very noticeable". Closed.

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
- (Written at Prompt 01; the folder has since become a Git repository.) `.gd.uid` files are generated by Godot 4.6 and should be committed with their scripts.
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

## Prompt 02: versioned level data and validation (2026-11-17)

Status: **implemented; verification pass done (see below); automated checks PASS; manual re-look PENDING.**

### Acceptance criteria (from Prompt 02)

| Criterion | Evidence | Status |
|---|---|---|
| Versioned data-driven `LevelDefinition` with stable ids, design size, wall polylines or polygons, pins with pull direction, explicit spawns, goals, hazards, allowed mechanics, objective rules and thresholds, sim config version, authoring metadata, optional known solutions | `src/data/level_definition.gd`, `docs/LEVEL_FORMAT.md`; schema covered by `test_level_codec.gd` | Done |
| Definitions separate from runtime instances | `LevelInstance` (sim layer) owns an independent deep copy plus mutable state | PASS (tests below) |
| Validation of finite numbers, bounded sizes and counts, unique ids, references, wall geometry, supported mechanics, spawn clearances, before instantiating | `LevelValidator`; `LevelInstance.create` re-validates and refuses invalid data; about 80 malformed-data cases | PASS |
| Safe loading; no arbitrary scripts or resources from JSON; imported data outside the executable tree | `LevelLoader`: JSON class only, strict codec, path allowlist, size cap; user data in `user://levels/` | PASS |
| One original three-pin level built from data | `levels/workshop.three_pins.json` | Done (layout only; physics unverified) |
| Event types for action requested/accepted, material collected/lost/destroyed, terminal results | `LevelEvent`, `EventLog`, `TerminalResult` | PASS |
| Validation catches malformed definitions | `test_level_validation.gd` | PASS |
| Data round-trips | `test_level_codec.gd`, `test_level_loader.gd` (real file) | PASS |
| Restart instantiates a fresh level with identical initial geometry | `test_level_instance.gd`, `test_level_screen.gd` (real clicks) | PASS |
| Future generators output the same format | `meta.source = "generator"` is part of the schema; generators must produce `LevelDefinition` and pass `LevelValidator` | Format ready |

### Built

- `src/data/`: `LevelSchema` (limits and vocabularies), `LevelDefinition`, `LevelCodec` (strict parse and canonical save), `LevelValidator`, `LevelGeometry`, `LevelLoader` (safe file access and atomic save), `ValidationReport`.
- `src/rules/`: `LevelEvent` (9 event types), `EventLog` (one terminal result, one resolution per material, bounded), `TerminalResult`.
- `src/sim/`: `LevelInstance`, `LevelLibrary` (load by id).
- `src/presentation/`: `BoardView` (placeholder drawing, distinct shapes per material), `LevelScreen` and `AppRoot` now load the level from data and build a fresh instance on every start and restart.
- `levels/workshop.three_pins.json`, saved in canonical form.
- Tests: 5 new domain files and 1 new scene file (see counts below).
- Docs: `docs/LEVEL_FORMAT.md` (new), ARCHITECTURE, README, CLAUDE.md updated.

### Commands run and actual results (Windows 11, PowerShell 5.1, Godot 4.6.2)

| Command | Result |
|---|---|
| `scripts\test-all.ps1 -Clean` (final) | exit 0: import PASS; parse 41 files, 0 failures; harness 6 of 6 detected; domain 69 passed; scene 23 passed |
| `scripts\test-scenes.ps1 -Windowed` (real renderer, synthetic input) | exit 0, 23 passed |
| Screenshot of the level screen (windowed, real renderer) | board drawn from data: 5 tokens on pin A, 2 scrap on pin C, ramp, gate pin B, collector and disposal zones; inspected by eye |
| Compiler warnings | none from project code. The only `WARNING` line in test output is the engine's `Exponent too high`, printed on purpose by the `1e999` test |

Test count change: domain 9 to 69 (+60), scene 15 to 23 (+8). One existing scene test was adjusted, not weakened: the restart test now expects the board view as the one child of the board root.

### Defects found while building (all fixed)

1. **Freed-object access in new scene tests.** Tests read properties of a screen after restart had freed it. The runner counted them as passing; only the wrapper's engine-output scan caught them (this is the failure mode the harness was built for). Fixed by capturing values before the transition.
2. **Path check relied on accident.** `LevelLoader.check_path` computed the relative file name from a root chosen by a second condition, so a path such as `res://a_long_file_name.json` was only rejected incidentally. Mutation testing exposed that no test would notice if the root check were removed. Fixed by making root detection explicit and adding six wrong-place paths to the test.
3. **Half-open bounds check.** `Rect2.has_point` excludes the right and bottom edges, which would have rejected a wall ending exactly on the design edge. Replaced with an inclusive check.
4. **Shadowed parameter names** in `LevelEvent` factories (compiler warnings). Renamed.

### Mutation evidence (temporary edits to product code, each reverted; files verified identical afterwards)

| Mutation | Result |
|---|---|
| Spawn overlap check disabled | domain exit 1, 4 tests fail |
| `LevelInstance` aliases the source definition instead of copying | exit 1, 1 test fails (source or later restart would be corrupted) |
| Loader root-folder check disabled (original code) | **survived**: led to defect 2 |
| Loader root-folder check disabled (fixed code, variant) | exit 1, path test fails |
| Event log allows a material to resolve twice | exit 1, 1 test fails |
| Codec ignores unknown keys | exit 1, 3 tests fail |

### Design decisions worth knowing

- Built-in levels ship as JSON in `res://levels/` and are read as text, never via `load()`. **The export preset must include `*.json` (non-resource files filter) or the level will be missing from builds.** Prompt 17 task.
- Imported, authored or generated levels live in `user://levels/`, outside the executable resource tree. Files are named `<level_id>.json`, and the id inside must match the name.
- Parsing is strict: unknown keys, wrong types and missing keys are errors. Structural errors stop validation (semantic checks only run on structurally sound data).
- Saved coordinates are quantised to 0.0001 so files are byte-stable.
- Material radii, `SPAWN_GAP`, `MAX_SPAWNS` and the other numbers in `LevelSchema` are **provisional** until the physics tuning stage; changing them then is a schema or sim-config version event.
- Known solution sequences are optional. The three-pin level records none, because nothing can honestly claim a solution before real physics replay exists.
- `LevelEvent` and `EventLog` define the contract only. No rules emit events yet.

### Limitations and known gaps

- No physics bodies, pin interaction or win/lose rules exist yet. The three-pin level's layout is plausible by eye but its behaviour and solvability are **unverified**.
- `LevelInstance` holds records only. Prompt 03 attaches the real 2D physics world.
- `ValidationReport` stops at 50 issues. The validator does not yet check pin sweep paths against walls or tiny passages (editor stage, Prompt 08).
- `LevelLoader.save_file` writes a temp file then renames; backup and recovery are Prompt 08.
- Domain tests that touch files write and delete `user://levels/_test_*.json` and `test.*.json` in your Godot user data folder; they clean up after themselves.
- Not applicable yet: collision layers and masks, fixed-tick behaviour, deferred physics changes, one-shot event emission by rules, terminal-state handling in play, timers, pause, hint and replay regressions, generator checks. Nothing here claims physics ran.

### Verification pass (2026-11-17)

Git: the Prompt 02 work was already committed (`a1e77f7`); at the start only the prompts file (checkbox ticks) was modified. Everything below is uncommitted on top of that.

Commands run and actual results (Windows 11, PowerShell 5.1, Godot 4.6.2, GTX 1060 OpenGL Compatibility)

| Command | Result |
|---|---|
| `scripts\test-all.ps1 -Clean` before any change | exit 0 (domain 69, scene 23) |
| `scripts\test-all.ps1 -Clean` after fixes (final) | exit 0: import PASS; parse 42 files, 0 failures; harness 6 of 6 detected; domain 84 passed; scene 28 passed |
| `scripts\test-scenes.ps1 -Windowed` (real renderer, synthetic input) | exit 0, 28 passed |
| Mutation runs (10 safeguards, plus the leak test) | every mutation caught, files restored identical (table below) |
| Screenshots, real renderer | normal level screen unchanged; long-title and error-flood screens now correct |
| Compiler warnings | none from project code; the only `WARNING` is the deliberate `1e999` engine message |

Probes run that found defects (scratch scripts, not committed)

| Probe | Finding |
|---|---|
| Largest legal file by the old limits (64 walls x 256 points, 150 spawns, 199 KB) | **5.5 s** to validate, then again to instantiate |
| 30000 spawn entries into the codec | all parsed into objects (600 ms) before the count check refused them |
| UTF-8 BOM before valid JSON | confusing `json.parse` error |
| Source position 200.123459 into `LevelInstance` | instance position 200.123505: the deep copy rounded silently |
| 200 character title (valid data) on the level screen | Back at x=-3443, Restart at x=5123, both off screen |
| 40 validation errors on the level screen | error label 2170 px tall, partly off screen |
| Rounding on save, 20000 random near-limit placements | **716 (3.7%) valid in memory but invalid after save and reload** |
| Nested JSON up to 1,000,000 deep, Enter+Esc in one frame | no problem found (engine rejects the nesting; no error from the frame race) |
| 120 Play/Restart/Back cycles | object count flat at 1556 from cycle 1: no leak |

Defects fixed

1. **Unbounded validation work.** Added `MAX_TOTAL_WALL_POINTS` (1024). Largest legal level now validates in about 0.5 s (was 5.5 s) and instantiates in about 0.6 s. Tests: cap rejects quickly, boundary case (64 walls x 16 points) passes, one more point per wall fails, worst legal file stays under a generous time ceiling.
2. **Codec built objects before checking list sizes.** Oversized lists are now refused as a whole, before any entry is parsed. Test uses 1000 malformed entries per list and requires only `count.exceeded`.
3. **Instance drift from validated data.** `LevelCodec.clone` no longer rounds; saving still does. Tests use positions off the 0.0001 grid.
4. **Rounding on save could write a file the game then refuses to open.** `to_saved_text` validates the rounded text; a rounding-only failure is reported as `save.rounding`. A seeded 1500-trial test requires that both outcomes occur (the guard is really exercised) and that nothing written ever fails to load. **Correction:** my first probe of this reported zero hazard cases and I described the risk to you as theoretical. That probe was broken (it placed a spawn inside a wall, so every trial failed validation and was skipped). The redone probe found the real 3.7% rate above.
5. **Data-supplied text could break the HUD.** Title label now clips with an ellipsis; error text is capped at 6 issues of at most 110 characters and wrapped. Tests at 5 window sizes check the controls and message stay inside the window and board area.
6. **Smaller items.** UTF-8 BOM accepted (Windows editors); `.json.tmp` files are no longer readable as levels (code allowed it, docs said otherwise); `.gitattributes` now forces LF for JSON and the canonical-form test ignores line-ending conversion, because a Windows checkout would otherwise have broken it; `_fit_board` guarded against running after the screen was removed (no error was observed, defensive only).

New test coverage: architecture layers (`test_architecture_layers.gd`: no upward references, no Node use in data and rules, scanner self-check), leak check (60 cycles, node and orphan counts exact, object count drift at most 2), Play-then-Back in one frame, BOM and CRLF, wall caps and timing, exact clone, rounding property, long title, error flood, summary capping.

One test was changed after it failed for the wrong reason: the leak test first used exact object-count equality and failed in the windowed run with a count that went DOWN by one (engine jitter, not a leak). It now bounds drift. A deliberate leak (one `LevelInstance` kept per cycle) produced a drift of 3600 and failed it, so it still detects leaks.

Mutation evidence (temporary edits to product code, each reverted and verified identical)

| Mutation | Result |
|---|---|
| Total wall point cap removed | 2 tests fail |
| Codec parses oversized lists | 1 test fails |
| Clone rounds again | 2 tests fail |
| Save skips validating rounded text | 2 tests fail |
| BOM not stripped | 1 test fails |
| `.tmp` files readable | 1 test fails |
| Data layer references `Node` | architecture test fails |
| Sim layer references `UiMetrics` | architecture test fails |
| Title label unclipped | long-title test fails |
| Error text not capped | error-flood test fails |
| `LevelScreen` leaks one instance per cycle | leak test fails (drift 3600) |

Reviewed and found fine: layer dependencies (now enforced by test), spawn and clearance geometry at limits, polygon walls, JSON nesting bombs, hostile keys and resource-path strings, path allowlist, event log one-shot rules, definition/instance separation, restart cleanup and stale callbacks at screen level, hit areas and scaling at 6 window sizes.

Remaining limitations (not defects of this stage)

- Validation does not check that a level is playable or solvable (zero pins is legal data). Playability belongs to the editor (Prompt 08) and replay (Prompt 16).
- Symbolic links or junctions inside `user://levels/` are not specially handled.
- Everything physics-related is not applicable yet and nothing here claims physics ran.
- `Pin_Puzzle_Game_Claude_Code_Prompts.md` was added to `.gitignore` at the developer's request, but it is already tracked, so it stays tracked until `git rm --cached Pin_Puzzle_Game_Claude_Code_Prompts.md` is run.

### Manual check (PASS, recorded by the developer 2026-11-17: "manual checks all check out", all five steps)

Run `C:\Tools\Godot\godot.exe --path .`

1. Click **Play**. Expected: a cream board with brown walls, a sloped ramp, three gold-brown pins labelled A, B and C with round handles, five gold circles resting on pin A, two dark squares on pin C, a green COLLECTOR box bottom right and a grey DISPOSAL box bottom left. The title reads "Three Pins Test Chamber".
2. Click **Restart** several times. Expected: the board looks identical every time.
3. Click **Back**, then **Play** again. Expected: same board.
4. Resize the window (wide, tall, small). Expected: the whole board stays visible and centred, never covering Back or Restart.
5. Press Esc on the level. Expected: back to the menu.

Result: all five steps passed (before the verification pass).

**Re-look (PENDING, 30 seconds)** because the verification pass touched the level screen: run `C:\Tools\Godot\godot.exe --path .`, click Play and confirm the board looks the same as before; click Restart and Back a few times; shrink the window and confirm Back and Restart stay in the top corners with the title between them. Record pass or fail here.

## Prompt 03: walls, tokens and reliable 2D physics (2026-11-17)

Status: **implemented; automated checks PASS; manual check PENDING; Verification Prompt not yet run.** Full numbers, tables and reasoning are in [PHYSICS.md](PHYSICS.md); this section records what was built, what was run, what went wrong and what is left.

### Acceptance criteria (from Prompt 03)

| Criterion | Evidence | Status |
|---|---|---|
| Static chamber walls and a bounded number of dynamic brass tokens in Godot 2D physics | `SimWorld`: a `StaticBody2D` per wall and pin, a `RigidBody2D` per token, limit 150 (`SimConfig.MAX_DYNAMIC_BODIES` = `LevelSchema.MAX_SPAWNS`); 31 physics tests | PASS |
| Simple collision shapes, visual detail separate from collision | Capsule per polyline segment, convex pieces per polygon, rectangle plus disc per pin (`BoardColliders`); decoration never adds collision | PASS |
| Specify wall thickness, token radius, clearances, mass, friction, bounce, gravity, tick rate | Table in PHYSICS.md; values in `SimConfig`, pinned in `project.godot`, re-checked by `SimWorld.build`, recorded text in `test_sim_config.gd` | Done |
| Collision geometry visibly matches playable boundaries | Physics point query vs level data over a 6 unit grid on 3 levels, zero disagreements; overlay draws the live physics shapes; screenshots | PASS (automated and visual); manual PENDING |
| Debug overlays for collision shapes, body ids, velocities | `PhysicsDebugOverlay`, F2 shapes, F3 ids, F4 velocities, F5 statistics; scene tests | PASS (automated); manual PENDING |
| Test sloped channels, corners, narrow openings, piles | Ramps 1 to 60 degrees, corners 20 to 120 degrees, openings 1.0 to 5.0 diameters, piles of 25 to 300 (PHYSICS.md tables); `test_flow.gd` | PASS |
| CCD where justified by observed tunnelling, not indiscriminately | Observed: thin polygons tunnel at the speed limit with CCD off (6 of 120 plates, 12 of 72 wedges); ray CCD removes it, shape-cast does nothing. Ray CCD on tokens only | PASS, see correction below |
| Avoid tiny bodies, thin walls, overlapping spawns | Token 28 across, wall minimum 8, plate minimum 4 (tested), spawn gap 2 (validator, unchanged) | PASS |
| Cosmetic particles are not gameplay bodies | None added; PHYSICS.md states the rule | Done |
| Tokens flow through intended openings without unexplained leaks or persistent jams across repeated runs | 20 seeded crowds of 36 pass a 98 unit opening 20 of 20; ramps 5 to 60 degrees 36 of 36; corners, piles and the lab level settle with nothing outside; jams below 3 diameters are shown and explained | PASS |
| Profile a typical board and establish an initial body-count limit | `scripts\profile-physics.ps1`; limit 150 kept, measured (mean 1.0 ms, worst 2.6 ms headless at 150) | PASS, limited to one machine |
| No custom fluid simulation; water cosmetic only | None built | Done |

### Built

- `src/sim/`: `SimWorld`, `BoardColliders`, `TokenBody`, `StaticPartBody`, `SimTuning`; `SimConfig` gained gravity, sleep and solver mirrors, layers, token tuning, CCD, speed limit, body limit and measured design guidance; **`CONFIG_VERSION` is now 2**; `LevelInstance.create(null)` no longer crashes.
- `src/presentation/`: `TokenVisual`, `PhysicsDebugOverlay`; `BoardView` follows the world (and draws pins and walls exactly as their colliders); `LevelScreen` builds one world per attempt and handles F2 to F5; `AppRoot` accepts `--level=<id>` in debug builds.
- `project.godot`: gravity 1000, sleep thresholds, solver iterations pinned, physics interpolation on.
- Data: `levels/workshop.three_pins.json` moved to `sim_config_version` 2 (geometry hash unchanged); new development level `levels/dev.physics_lab.json` (48 tokens, ramps, a 104 unit opening, a funnel).
- `LevelSchema`: `MAX_SPAWNS` documented as measured; token radius final, scrap and core still provisional.
- Tests: `tests/physics/` (new suite: `PhysicsTestCase`, `PhysicsScenarios`, 4 test files, `profile_physics.gd`), `tests/domain/test_board_colliders.gd`, additions to `test_sim_config.gd`, `test_level_instance.gd`, `test_builtin_levels.gd`, `tests/scene/test_physics_view.gd`; two old scene assertions changed (see below).
- Scripts: `test-physics.ps1`, `profile-physics.ps1`, `test-all.ps1` now includes physics.
- Docs: new PHYSICS.md; README, ARCHITECTURE, LEVEL_FORMAT, DESIGN, CLAUDE updated.

### Commands run and actual results (Windows 11, PowerShell 5.1, Godot 4.6.2, i7-7700, GTX 1060)

| Command | Result |
|---|---|
| `scripts\test-all.ps1` (final code) | exit 0: import PASS; parse 58 files, 0 failures; harness 6 of 6 detected; domain 98 passed; scene 37 passed; physics 31 passed (about 80 s) |
| `scripts\test-all.ps1 -Clean` (final code, after the mutation sweep) | exit 0: clean import, parse 58 files, harness 6 of 6 detected, domain 98, scene 37, physics 31 (about 60 s) |
| `scripts\test-scenes.ps1 -Windowed` | exit 0, 37 passed |
| `scripts\test-physics.ps1 -Windowed` | exit 0, 31 passed (about 57 s, with `--disable-vsync`) |
| `scripts\profile-physics.ps1` and `-Windowed` | tables in PHYSICS.md; 150 tokens mean 1.0 ms, worst 2.6 ms headless |
| Compiler warnings | none from project code; the only `WARNING` in test output is the known `1e999` engine message |
| Screenshots, real renderer | lab level and three-pin level with every overlay layer; shapes sit exactly on the drawn walls and pins |

### Corrections and defects found while building

1. **The first tunnelling tests were vacuous (the biggest finding).** Every drop ran a fixed 230 ticks, but a token needs about 265 ticks to fall the shaft at the speed limit, so at the limit no token had reached the floor. "0 tunnelled" at the shipped limit and the whole "margin to 1200" table proved nothing. I found it while writing PHYSICS.md (the fall time did not add up), measured the arrival (lowest token y=3473 of a 3996 floor at tick 230), re-measured with drops that run until every token has landed or gone through and record impact speed, and the conclusion **reversed**: thin polygon plates and wedges tunnel at the speed limit itself, and an 8 unit polyline from about 1100. So CCD (ray) is justified and is now on, and the speed limit is only defense in depth. This is exactly what the rule "assert the interesting case occurred" in CLAUDE.md exists for, and I had not applied it to my own tests. New tests assert `finished`, arrival and impact speed, and a mutation (drops cut back to 230 ticks) now fails six tests.
2. **`LevelInstance.create(null)` crashed inside the validator** (Prompt 02 gap, found by a scenario that returned null). It now returns null with a `level.missing` issue. Test added.
3. Several of my own scenario levels were invalid or flawed: jittered spawns closer than the legal gap (the validator was right), and a lab layout whose ramps left only 1.4 token widths between them (an accidental narrow opening that jammed the pile), then a funnel exit 36 units above the floor (a pile backed up into it). Both lab layouts were redrawn after screenshots.
4. Wrong test expectations, all fixed with the physics unchanged: acceleration compared with gravity instead of gravity minus damping times speed (2 percent off); 32-bit float properties compared exactly; "nothing passes an opening one diameter wide" (one token did, so the test uses 0.9); a scene test that assumed the world had already ticked before it started counting (timing dependent, rewritten relative); a "signature tracks every change" test that used the new default as its change.
5. `Performance.TIME_PHYSICS_PROCESS` does not update per tick (the same figure for every row), so the profile times between `physics_frame` signals instead.
6. A windowed physics run without `--disable-vsync` waits for the display each tick (about 10 minutes); the scripts pass the flag.
7. A first reading of the ray CCD cost from one noisy run was unreliable; repeated back-to-back runs show run-to-run noise of about 25 percent, larger than the CCD effect, so PHYSICS.md says "between nothing and about 20 percent".
8. Two existing scene assertions compared a live instance's `state_signature()` with its initial one; once tokens move that is no longer equal, so they compare `initial_state_signature` and a new test checks the live world starts at the authored positions.

### Mutation evidence (temporary edits to product code or tests, each reverted and the file hash verified identical)

All 20 mutations were caught (final code, 2026-11-17). Failing counts are tests that failed under that mutation.

| Mutation | Suite | Result |
|---|---|---|
| Speed limit removed | physics | 2 fail |
| Capsule radius shrunk | physics | 5 fail |
| Capsule not rotated onto its segment | domain | 2 fail |
| World build skips the project settings check | physics | 1 fails |
| World not `top_level` | scene | 1 fails |
| Concave polygon replaced by its convex hull | domain | 1 fails |
| `LevelInstance.create(null)` guard removed | domain | 1 fails |
| Pin knob shape dropped | domain | 2 fail |
| Token records not synced from bodies | physics | 1 fails |
| Token visuals not moved with bodies | scene | 1 fails |
| Speed limit raised to 1500 | physics | 2 fail |
| `SimConfig` gravity differs from project | domain | 3 fail |
| Tokens collide with nothing | physics | 15 fail |
| Tokens ignore each other | physics | 4 fail |
| Overlay skips token shapes | scene | 1 fails |
| Debug keys ignored | scene | 1 fails |
| Ray CCD turned off | physics | 2 fail |
| Drops cut back to the old 230 ticks (test mutation) | physics | 6 fail |
| Token friction changed | domain | 1 fails |
| Speed limit raised only (CCD on) | domain | 1 fails (recorded tuning) |

Two earlier mutation rounds exposed gaps that were fixed: "tokens ignore each other" was caught only incidentally (a direct pile solidity test was added), and the speed limit's value was not pinned once CCD made it unnecessary for tunnelling (the recorded tuning test pins it).

### Design decisions worth knowing

- Pins are present as immovable static bodies. That is the minimum that makes the three-pin layout rest as authored (tokens sit on pin A); pulling is Prompt 04 and will replace this. Scrap and cores are not simulated (Prompt 06) and are drawn at their start positions.
- `SimWorld` is a `top_level` node at the origin and a sibling of the scaled board, so physics runs in design coordinates. Putting bodies under the scaled `BoardRoot` would have scaled the physics bodies.
- Both damping modes are REPLACE per body, so no project or area default can change the feel. Gravity and sleep live in `project.godot` (the engine owns them) and are verified on every build.
- Sim config version bumped from 1 to 2 (the first physics tuning); the level file moved with it. `SimTuning.signature()` is the text recorded with results and is pinned by a test.
- The speed limit stays at 1000 even though CCD made it unnecessary for tunnelling; the reasons and the fact that it is unproven are written down.
- The overlay draws the live `CollisionShape2D` nodes via the engine's own `Shape2D.draw`, not the level data, so it cannot disagree with the physics.

### Limitations and open items

- Everything is measured on one machine. A low-end machine measurement is still owed (before Prompt 17), and the worst tick at 150 bodies leaves less than a threefold margin on this machine.
- Open floors let piles creep: the lab pile took about 20 s to fall fully asleep. Prompt 04's settle thresholds and jam timeout must allow roughly that, or levels should wall in their collection bays.
- The validator checks spawns against a pin's shaft, not its knob. Decide in Prompt 04.
- Ray CCD follows only the token's centre path; no corner-clipping leak was found, but the speed limit is the only other guard.
- Physics interpolation (smooth motion on displays that are not 60 Hz) is switched on and visually unchanged at 60 Hz, but smoothness at other refresh rates has not been judged by a human.
- The Prompt 03 checkbox in `Pin_Puzzle_Game_Claude_Code_Prompts.md` was ticked on 2026-11-18 at the user's request, after their manual check.

### Manual check (DONE 2026-11-18, reported by the user; about 5 minutes)

Result: the user reported "Manual testing done" with no failures or issues. Per-step pass or fail was not itemised, and step 9 (above 60 Hz smoothness) was not separately reported. This also covers the Prompt 02 re-look (step 8).

Run `C:\Tools\Godot\godot.exe --path .`

1. Click **Play**. Expected: as before (cream board, brown walls, ramp, three pins A, B, C, collector bottom right, disposal bottom left), but the five gold tokens now **rest on pin A** (they drop a few units and stop; they do not fall through it) and the two dark squares sit on pin C. Pins are not clickable yet.
2. Press **F2**. Expected: a thin cyan outline traces every wall exactly, magenta traces every pin including its round handle, green traces each token. Nothing drawn should poke past the brown or gold shapes or leave a gap. Press F2 again: it disappears.
3. Press **F3**: ids like `token.1`, `wall.outer`, `pin.a` appear. **F4**: no arrows (everything is at rest). **F5**: a text block top left saying `awake 0` after a second or so, `outside board: 0`. Turn each off again.
4. Click **Restart** a few times. Expected: tokens start identically each time and settle on pin A the same way.
5. Resize the window (wide, tall, small) with F2 on. Expected: the outlines stay glued to the walls, the board stays centred and never covers Back or Restart, the title stays between the buttons.
6. Close it and run `C:\Tools\Godot\godot.exe --path . -- --level=dev.physics_lab`, then Play. Expected: 48 tokens roll down a gentle ramp, squeeze through the gap under the short wall, fall onto a second ramp that runs to the right, drop into the V funnel and land on the floor beside the green collector box, settling after roughly 20 seconds. Nothing leaves the board. Press F4 while they move: arrows point the way they roll.
7. Press Restart on the lab. Expected: the same story again.
8. Press Esc on the level, then Play again. Expected: back at the menu, then a fresh level (this repeats the Prompt 02 re-look).
9. If you have a monitor above 60 Hz: does the motion look smooth rather than stuttery? (Optional, not verified by me.)

Record pass or fail for each step here.

### Verification pass (Verification Prompt, 2026-11-18): PASS

Scope: Prompt 03 as implemented. Git: repository with 3 commits; 20 tracked files modified and about 20 new files, all Prompt 03 work (nothing unrelated touched).

| Check | Command | Result |
|---|---|---|
| Clean import, parse, harness proof, domain, scene, physics | `scripts\test-all.ps1 -Clean` | exit 0: parse 58 files, harness 6 of 6 detected, domain 98, scene 39, physics 31, 0 failed, 0 load errors |
| Real renderer, scene suite | `scripts\test-scenes.ps1 -Windowed` | exit 0, 37 passed (run before the two new tests were added) |
| Real renderer, physics suite | `scripts\test-physics.ps1 -Windowed` | exit 0, 31 passed, real physics at one tick per frame |
| Engine errors | wrapper scan of all runs | none; only the known `Exponent too high` warning from the deliberate 1e999 loader test |
| Export or build | none exists at this stage (export templates not installed) | not applicable, not claimed |

Physics claims here ran the real GodotPhysics2D step. Nothing was mocked, and the wrappers fail on SCRIPT ERROR.

Review against the Verification Prompt, with what was found:

- Layers and masks: walls layer 1, pins layer 2, tokens layer 4; static bodies have mask 0, tokens collide with all three. Matches SimConfig and is tested.
- Collision versus visible geometry: guarded by the 6 unit grid point-query test on 3 levels and the overlay drawing live shapes. No disagreement.
- No faked physics: a search of `src/` finds body transforms set only at spawn, collider local transforms, the speed clamp inside `_integrate_forces`, and visuals copying body positions. No `RigidBody2D` is moved to imitate motion.
- Deferred collision changes, collection and death accounting, one-shot events, terminal states, timers and stale callbacks: none exist yet (Prompts 04 to 06), so there is nothing to verify. Stable string ids exist for every wall, pin and token.
- Restart cleanup: **gap found.** The existing leak test cycled Play, Restart and Back but only when nothing was in motion and never with several restarts in one frame. Two scene tests were added (`test_physics_view.gd`): three restarts in one frame while tokens fall leaves exactly one world (4 walls, 3 pins, 5 tokens in the whole tree, older worlds freed), and Escape mid-fall leaves zero physics bodies and the next Play is a fresh world. Each asserts the tokens really were moving. Mutation check: removing `queue_free()` from `AppRoot._switch_to` fails 6 tests including both new ones; the file was restored and its hash verified. No product defect was found, so no product code changed.
- Regression meaning: the same level starts and settles identically on repeat (`test_repeated_runs_of_the_same_level_are_identical...`); overlays do not change state; flow tests count that tokens actually passed. Generator checks do not apply (no generator yet).
- Documentation defect fixed: CLAUDE.md and this file said the folder was not a Git repository. It is one now; CLAUDE.md corrected.

Manual checks: the Prompt 03 manual check was reported done by the user with no issues (not itemised). Optional step 9 (smoothness above 60 Hz) was not separately reported and stays unverified by me.

Verdict: **PASS.** Open items are the Limitations list above, plus: the prompts file is in `.gitignore` but still tracked (`git rm --cached` not yet run), and the Prompt 03 checkbox is for the user to tick.

## Next stage

Prompt 04 (pins and sequencing, settling), built on `SimWorld`. Prerequisites in place: real physics for walls and tokens with a recorded tuning, an immovable pin body per pin with a stable id, `LevelInstance` pin state, the event contract, settle observations (worst 20 s on an open floor), `PhysicsTestCase` and `PhysicsScenarios`. The Prompt 03 manual check and Verification Prompt are done; wait for the user to supply the prompt.
