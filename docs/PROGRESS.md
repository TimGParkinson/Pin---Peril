# Progress

Single source of truth for what has actually been done and verified. Record real commands and real results. Manual checks stay PENDING until a human has done them.

## Current stage

**Prompt 02 (versioned level data and validation): verification pass done 2026-11-17. Automated checks PASS (domain 84, scene 28, all harness and parse checks). Original manual check PASS (developer). The verification pass fixed 6 defects, 3 of them in code the manual check had covered, so a 30-second manual re-look is PENDING.** Verdict: **PASS pending that re-look.** Details in "Prompt 02" and "Verification pass" below. Do not start Prompt 03 until the re-look is done.

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

## Next stage

Prompt 03: walls, tokens and reliable 2D physics, built on `LevelInstance` and the three-pin level. Prerequisites in place: validated data, explicit spawn positions, stable ids, event contract, `SceneTestCase`, fixtures pattern. Wait for the Prompt 02 verification and sign-off first.
