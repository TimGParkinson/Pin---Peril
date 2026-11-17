# Architecture

Status: Phase 0. Only the presentation shell, `SimConfig`, and the test tooling exist. Everything else below is the plan that later stages implement; sections say which parts are built.

## Toolchain decisions

### Engine version

**Godot 4.6.2-stable, standard build**, official build `4.6.2.stable.official.71f334935`. Pinned in `scripts/engine-version.txt`; the scripts refuse any other version.

Why 4.6.2 and not newer: checked 2026-11-17 against the official releases. The latest stable is 4.7.2 and the latest 4.6 patch is 4.6.3. 4.6.2 was chosen because it is the build already installed and verified on the development machine (its zip matches the official SHA-256), and because physics-validated puzzles are tied to an exact engine. Moving to 4.6.3 or 4.7.x is a deliberate upgrade with full revalidation (see Versioning), not something to do mid-scaffold.

Matching export templates: `Godot_v4.6.2-stable_export_templates.tpz`, installed to `%APPDATA%\Godot\export_templates\4.6.2.stable\`. **Not installed yet**, needed only at the Windows export stage. Docs consulted match the 4.6 line (docs.godotengine.org, command line tutorial and project settings, via Context7). Do not use 4.7-only APIs.

### Renderer choice

`gl_compatibility` for both desktop and mobile. This is a 2D game with no need for Vulkan features; Compatibility has the widest hardware and driver support (older Intel/AMD iGPUs and Windows drivers), the lowest start-up and memory cost, and avoids Vulkan/D3D12 driver variance on Steam machines. Trade-off: no Forward+/Mobile-only 2D features (for example the more advanced 2D lighting and some shader effects). If a later art stage needs them, change the renderer deliberately, retest visuals and note it in PROGRESS. The renderer does not affect physics.

### Physics

Built-in GodotPhysics2D, fixed `physics/common/physics_ticks_per_second = 60`, mirrored by `SimConfig.TICK_RATE` and guarded by a domain test. Godot physics is not guaranteed deterministic across machines or builds; the project treats verified solutions as evidence under recorded conditions.

### Test framework

A small explicit runner (`tests/runner/test_runner.gd`) instead of an addon. Reasons: no vendored third-party code to pin or audit, full control of exit codes, and it works identically in `--headless --script` mode on the pinned engine. GUT 9.7.1 was available and is a viable later swap if the runner becomes limiting.

Failure rules: a failed assertion, a test with zero assertions, a test file that cannot load, an empty or missing test directory, and any engine `ERROR`/`SCRIPT ERROR` line in the output all produce a nonzero exit. The last rule is enforced by the PowerShell wrapper because Godot can exit 0 after a script runtime error. `scripts/verify-harness.ps1` proves each rule against deliberately bad inputs.

## Layers

```
presentation  --->  progression
     |                  |
     v                  v
    sim  ------------>  rules  ------>  data
```

Dependencies point down or right only. A lower layer never references a higher one.

| Layer | Folder | Responsibility | May use Nodes? |
|---|---|---|---|
| data | `src/data` | Versioned `LevelDefinition`, stable object IDs, validation, safe JSON load/save. Definitions are separate from runtime instances. | No |
| rules | `src/rules` | Event types, objective evaluation, level state machine (READY/SETTLING/WON/LOST/JAMMED), settle policy. Pure functions of definition + events. | No |
| sim | `src/sim` | Instantiates a definition into a physics world, advances fixed ticks, applies actions, emits events. Hosts `SimulationRunner`. No UI. | Yes (physics bodies) |
| presentation | `src/presentation`, `scenes/` | Screens, UI, pin hover/animation, effects, audio. Reads sim state and events. Never decides outcomes. | Yes |
| progression | `src/progression` | Campaign structure, unlocks, saves, settings under `user://`. Consumes terminal results only. | No |

Built so far: `SimConfig` (sim), `UiMetrics`, `AppRoot`, `MainMenu`, `LevelScreen` (presentation).

### Presentation shell (built)

`scenes/main.tscn` is an `AppRoot`. It owns exactly one screen at a time. `MainMenu` and `LevelScreen` emit request signals (`play_requested`, `quit_requested`, `back_requested`, `restart_requested`); only `AppRoot` swaps screens, always freeing the old one and instantiating a new one, so restart cannot carry stale state. No autoloads, no `change_scene_to_file`, which also makes the flow testable by instantiating `AppRoot` under the test tree.

## Shared simulation runner (planned, Prompt 03 to 05, 16)

One class, `SimulationRunner`, used by both live play and automated replay. Replay must never reimplement rules.

Planned API (names may change when implemented):

```
load_level(definition: LevelDefinition) -> void    # builds a fresh physics world from data
submit_action(pin_id: String) -> ActionResult      # accepted or rejected with a reason
physics step                                       # advanced by real fixed ticks, never faked
state: READY | SETTLING | WON | LOST | JAMMED
events: ordered stream (action requested/accepted, material collected/lost/destroyed, terminal result)
snapshot/trace: tick count, action trace (pin IDs + settle policy), versions
```

How the two consumers use it:

- **Live game**: a presentation `PlayController` forwards input to `submit_action`, renders events and state, and lets the engine drive fixed ticks via `_physics_process`.
- **Headless replay**: a SceneTree harness loads a `LevelDefinition`, calls `submit_action` for each recorded pin ID, advances real physics frames until the runner reports settled, and reports results with a nonzero exit on failure. Actions are pin IDs plus the settling policy, never wall-clock timestamps.

Hard rules: no mocked physics in any test that claims a physics result; visual and audio systems may be disabled in replay but collision shapes, spawn order, rules and physics settings must be identical to release; effects consume events and cannot change outcomes; cosmetic RNG is separate from gameplay.

## Data and IDs (planned, Prompt 02)

- `LevelDefinition` is a versioned, validated, data-only structure loaded from JSON stored outside the executable resource tree. Validation covers finite numbers, bounded counts and dimensions, unique IDs, references, wall geometry and spawn clearance.
- Every gameplay object (pin, material, goal, hazard) has a unique stable string ID. Recorded solutions, hints and saves refer to IDs, never indices.
- User-authored or generated data is never loaded as an executable script or arbitrary Resource.

## Versioning

Three independent versions, recorded with every replay result and validation record:

| Version | Changes when | Consequence |
|---|---|---|
| Layout/data schema | `LevelDefinition` format changes | Explicit migration code |
| Simulation config (`SimConfig.CONFIG_VERSION`) | Tick rate, tuning, settle thresholds, collision layers, rule semantics change | Revalidate every known solution |
| Engine | Godot version changes | Revalidate every known solution, reinstall matching export templates |

## Testing layout

| Suite | Folder | Runs | Needs |
|---|---|---|---|
| parse | `tests/runner/parse_check.gd` | Loads every `.gd/.tscn/.tres` | import |
| domain | `tests/domain` | Pure logic, project-setting guards | import |
| scene | `tests/scene` | Real scenes driven by real mouse/key events and measured layout at several window sizes; `-Windowed` reruns on the real renderer | import |
| harness | `tests/harness_fixtures` | Deliberate failures, used only by `verify-harness.ps1` | import |

Headless scene tests run with the dummy display and audio drivers, so they prove structure and flow, **not** rendering, touch input or Windows display scaling. Those are manual checks listed in PROGRESS. Physics replay tests arrive with the simulation stages.

## Folder conventions

`src/<layer>/` for code, `scenes/<area>/` for scenes, `tests/<suite>/` for tests, `scripts/` for Windows tooling, `docs/` for documents. Authored level data will live under a separate `levels/` directory (not `res://` scripts) when introduced.
