# Pin Puzzle Project (working name)

An original, offline, single-player pull-the-pin physics puzzle game. An apprentice tinkerer restores a whimsical workshop by routing brass tokens and power cores safely through machines. Godot 4, typed GDScript, Windows/Steam first, landscape with scalable, touch-friendly UI.

**Status:** Phase 0 scaffold. A menu, an empty level shell with Back/Restart, a test runner and Windows check scripts. There is no gameplay yet. See [docs/PROGRESS.md](docs/PROGRESS.md).

No public name, store availability or trademark clearance is implied by the working name.

## Toolchain

| Item | Choice |
|---|---|
| Engine | Godot **4.6.2-stable**, standard build (not .NET) |
| Export templates | 4.6.2.stable, **not installed yet** (needed only for Windows export) |
| Language | Typed GDScript |
| Renderer | `gl_compatibility` (OpenGL), see [ARCHITECTURE](docs/ARCHITECTURE.md#renderer-choice) |
| Physics | GodotPhysics2D, fixed 60 ticks/s |
| Tests | Small explicit runner in `tests/runner/` (no addons) |

## Prerequisites (Windows 10/11)

1. **Godot 4.6.2-stable, standard Windows build.** Download `Godot_v4.6.2-stable_win64.exe.zip` from the [4.6.2-stable release](https://github.com/godotengine/godot/releases/tag/4.6.2-stable) (official SHA-256 `14293422efb54b24a51f79d4cb55ab4001ef3d936e064a6c8af32e1f984024be`). Extract it and either add its folder to `PATH` (the scripts look for `godot.exe`) or set `GODOT_BIN`:

   ```powershell
   $env:GODOT_BIN = "C:\Tools\Godot\godot.exe"   # this session only
   ```

   The scripts verify the version and reject other versions and the .NET build. If `GODOT_BIN` is set it is the only binary tried, so a wrong value fails instead of silently using another install.
2. **Windows PowerShell 5.1 or PowerShell 7.** Run scripts with `-ExecutionPolicy Bypass` as shown below, or allow local scripts for your user.
3. **Export templates (later, from the Windows export stage).** Download `Godot_v4.6.2-stable_export_templates.tpz` (about 1.25 GB, SHA-256 `942366dc4e27e7686a99da4d3cfb1b8ae8d3eb9444f6d8217eef16245b599ef2`) from the same release page, then in the editor use *Editor > Manage Export Templates > Install From File*. They land in `%APPDATA%\Godot\export_templates\4.6.2.stable\`. `scripts\check-env.ps1 -RequireTemplates` verifies them.
4. **Git** is optional. This folder is not yet a Git repository.

Check everything with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-env.ps1
```

## Commands

Run from the repository root.

```powershell
# Full verification (import, parse, harness self-check, domain tests, scene tests)
powershell -ExecutionPolicy Bypass -File scripts\test-all.ps1
powershell -ExecutionPolicy Bypass -File scripts\test-all.ps1 -Clean   # also deletes .godot/ first

# Individual steps
powershell -ExecutionPolicy Bypass -File scripts\import.ps1 [-Clean]
powershell -ExecutionPolicy Bypass -File scripts\check-parse.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-harness.ps1
powershell -ExecutionPolicy Bypass -File scripts\test-domain.ps1
powershell -ExecutionPolicy Bypass -File scripts\test-scenes.ps1
powershell -ExecutionPolicy Bypass -File scripts\test-scenes.ps1 -Windowed   # real window and renderer, synthetic input
```

Every script exits nonzero on failure. Godot itself can exit 0 while printing script errors, so the scripts also scan engine output for error lines and fail on them. `verify-harness.ps1` proves this by feeding the checks deliberately broken inputs.

Run the game: open the folder in the Godot 4.6.2 editor and press F5, or `godot --path .`

## Layout

```
project.godot          engine config (renderer, physics tick, display)
scenes/                .tscn scenes (main, menu, level)
themes/                project-wide UI theme (keyboard focus ring)
src/
  data/                level definitions and validation (planned)
  rules/               puzzle rules and events (planned)
  sim/                 fixed-tick physics and shared simulation runner
  presentation/        screens, UI, effects
  progression/         saves, settings, campaign (planned)
tests/
  runner/              test runner, TestCase base, parse check
  domain/              pure logic tests
  scene/               real-scene tests
  harness_fixtures/    deliberately failing inputs for verify-harness.ps1
scripts/               Windows check scripts
docs/                  design, architecture, progress, assets
```

## Documents

- [docs/DESIGN.md](docs/DESIGN.md): mechanics, phased scope, exclusions
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): layers, shared simulation runner, versioning, testing
- [docs/PROGRESS.md](docs/PROGRESS.md): stage log with real command results
- [docs/ASSETS.md](docs/ASSETS.md): asset policy and provenance
- [CLAUDE.md](CLAUDE.md): conventions for AI-assisted work
