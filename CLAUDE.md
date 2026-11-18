# CLAUDE.md

Working name: **Pin Puzzle Project**. Original standalone pull-the-pin physics puzzle game. Godot 4, typed GDScript, Windows/Steam first, offline single-player, landscape, scalable touch-friendly UI.

Read before working: `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/LEVEL_FORMAT.md`, `docs/PROGRESS.md`. The staged prompt pack is in `Pin_Puzzle_Game_Claude_Code_Prompts.md` (user-owned, do not edit).

## Pinned toolchain

- Engine: **Godot 4.6.2-stable, standard build (not .NET)**. Exact version lives in `scripts/engine-version.txt`.
- Export templates must match exactly (4.6.2.stable). Not installed yet; see README.
- Renderer: `gl_compatibility`. Physics: built-in GodotPhysics2D at a fixed 60 ticks/s.
- Do not use APIs or docs from other versions. Do not upgrade the engine casually: an engine change invalidates physics validation (see ARCHITECTURE, "Versioning").
- Test framework: small explicit runner in `tests/runner/` (no addons).

## Commands (Windows, from the repo root)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\test-all.ps1        # everything below, stops at first failure
powershell -ExecutionPolicy Bypass -File scripts\import.ps1 [-Clean] # headless import
powershell -ExecutionPolicy Bypass -File scripts\check-parse.ps1     # load every .gd/.tscn/.tres
powershell -ExecutionPolicy Bypass -File scripts\verify-harness.ps1  # proves the checks can fail
powershell -ExecutionPolicy Bypass -File scripts\test-domain.ps1
powershell -ExecutionPolicy Bypass -File scripts\test-scenes.ps1 [-Windowed]  # -Windowed uses the real renderer
powershell -ExecutionPolicy Bypass -File scripts\test-physics.ps1 [-Windowed]  # real physics, --fixed-fps 60 (one tick per frame)
powershell -ExecutionPolicy Bypass -File scripts\profile-physics.ps1 [-Windowed]  # physics cost per tick at several body counts
powershell -ExecutionPolicy Bypass -File scripts\check-env.ps1       # prerequisites
```

Godot is found via `GODOT_BIN` or `PATH` and its version is verified. Always run `import.ps1` after adding or renaming a `class_name` script, otherwise headless runs cannot resolve the class.

## Architecture rules (summary)

Five layers, dependencies point downward only: presentation -> progression, sim -> rules -> data. See `docs/ARCHITECTURE.md`.

- **data**: level definitions, strict codec, validator, safe loader (`docs/LEVEL_FORMAT.md`). No Node access. Every level, including generated ones, must pass `LevelLoader`/`LevelValidator`; never load level data with `load()`, `str_to_var` or similar.
- **rules**: puzzle rules, events, state machine. Pure logic, no Node access.
- **sim**: the physics world (`SimWorld`, built, see `docs/PHYSICS.md`) and later the shared `SimulationRunner` (live play and replay use the same code). No UI.
- **presentation**: scenes, UI, effects. Reads sim state and events, never decides outcomes.
- **progression**: saves, settings, campaign. Consumes terminal results only.

## Coding conventions

- Typed GDScript everywhere. `untyped_declaration` is a project **error**; every var, parameter, return, loop variable and lambda parameter needs a type.
- Files `snake_case.gd`; `class_name` PascalCase and only for types used across files; constants `UPPER_SNAKE`; private members `_leading_underscore`; signals are past-tense or request-style (`play_requested`, `screen_changed`).
- Tabs for indentation. Doc comments (`##`) on public classes and functions. Comments explain why.
- Screens emit request signals; only `AppRoot` swaps screens. No autoload singletons for gameplay state. Use `%UniqueName` nodes instead of long `get_node` paths.
- Gameplay changes happen in fixed physics ticks only. Never move `RigidBody2D` by setting transforms to fake physics. Change collision with deferred calls. Visual effects must not influence simulation state or share its RNG.
- Every gameplay object has a stable string ID. Never use list positions as persistent identity.
- Definitions are data, instances are runtime. Never mutate a `LevelDefinition` during play; build a fresh `LevelInstance` (restart does exactly that). Numbers in `LevelSchema` marked PROVISIONAL change only through the physics tuning stage, with a version bump.
- No `eval`, no loading user-authored data as executable resources/scripts. Level/save data is validated JSON.
- Do not suppress errors, lower thresholds or delete tests to get green. A launched process is not proof of a passing test.
- Generated text and docs: no em-dashes.

## Testing rules

- Domain tests (`tests/domain`) cover pure logic. Scene tests (`tests/scene`) drive the real scenes. Physics claims need the real physics step, never a mock.
- Tests extend `TestCase` and must contain at least one assertion. Test files are `test_*.gd` and methods `test_*`.
- Scene tests extend `SceneTestCase` (`tests/scene/scene_test_case.gd`), which sets an explicit window size (the headless default is 64x64 and distorts layout) and offers `click`, `send_key` and `set_window_size` helpers that use the real input pipeline. Prefer these over `pressed.emit()` for anything about input or layout. Send keyboard input as `InputEventKey`, not `InputEventAction`.
- Never read a node or screen after something may have freed it (restart and Back free the old screen). Capture ids or values first. The runner counts such a test as passing; only the wrapper's SCRIPT ERROR scan catches it.
- After writing a safeguard, break it on purpose (mutation check) and confirm a test fails. A safeguard no test notices is not tested.
- A new folder under `src/` must be added to `LAYER_RANK` in `tests/domain/test_architecture_layers.gd` (and to ARCHITECTURE.md). That test enforces the layer rules on the source text.
- A property or randomised test must assert that the interesting case actually occurred (count it). A probe that never reaches the case proves nothing; one such probe wrongly suggested a real bug was only theoretical.
- Compare object counts with a small drift allowance, not exact equality (the real renderer shows +/-1 jitter), over many cycles so a real leak stands out.
- Layout text can be longer than the layout expects. Anything showing data-supplied text (titles, error messages) must clip, wrap or cap it so it can never move the controls.
- Physics tests use `PhysicsTestCase` and run only through `scripts/test-physics.ps1` (it passes `--fixed-fps 60`; without it 1000 ticks take 17 seconds). Build scenarios with `PhysicsScenarios` so every level still passes the real validator.
- A drop, flow or settle test must run until the thing it measures has happened (every token landed, passed or asleep) and must assert that it did. A fixed tick count can end before anything arrives and "0 failures" then proves nothing: the first tunnelling tests stopped 35 ticks before the tokens reached the floor. Record the speed or state at the event and assert it.
- Vary the phase of what you drop (start heights, offsets). Bodies released from one height meet a wall at one phase within a tick and test only one.
- The engine stores physics properties as 32-bit floats: compare them with `assert_almost_eq`, not `assert_eq`.
- Judge a physical quantity by what physics says it should be, not by the nominal constant (measured acceleration is gravity minus damping times speed, not gravity).
- Do not read `Performance.TIME_PHYSICS_PROCESS` per tick (it does not update per tick); time between `physics_frame` signals. Windowed physics runs need `--disable-vsync` or each tick waits for the display.
- Debug overlays and any other presentation read the world and never change it; tests compare a run with and without them.
- Any change to a tuning number, CCD or the speed limit repeats `tests/physics/test_tunnelling.gd`, updates `docs/PHYSICS.md`, bumps `SimConfig.CONFIG_VERSION` and updates `RECORDED_TUNING` in `tests/domain/test_sim_config.gd`.
- Domain tests that write files use `user://levels/_test_*.json` and clean up in `after_each`.
- `tests/harness_fixtures/` contains deliberately failing tests used only by `verify-harness.ps1`. Never add it to a suite.
- Update `docs/PROGRESS.md` with real commands and results after each stage. Mark manual checks as pending, never passed, until a human has done them.

## Scope discipline

Work one stage at a time and stop at the stage boundary. Exclusions are listed in `docs/DESIGN.md` (no match-3, lives/energy timers, ads, accounts, servers, IAP, copied Homescapes assets).

## Preserve user work

This folder is a Git repository. Do not delete or overwrite files you did not create, and never discard unrelated changes. The prompt pack is listed in `.gitignore` but is still tracked until the user runs `git rm --cached Pin_Puzzle_Game_Claude_Code_Prompts.md`; do not edit it.
