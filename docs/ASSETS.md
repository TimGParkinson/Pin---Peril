# Assets and provenance

## Policy

- All game assets are original, or properly licensed with the licence recorded here before use.
- No assets copied or traced from other games (including Homescapes characters, graphics, UI or layouts).
- Prefer code-drawn and procedural graphics, local SVGs and original synthesised audio. No runtime dependency on external asset or audio services.
- Every bundled third-party file (font, sound, library) is listed below with source URL, licence, version and access date, and its licence text is shipped with the build.
- Record whether AI assistance was used in producing each asset (needed later to answer the Steam content survey accurately). Code and docs in this repository are written with Claude Code assistance.
- Gameplay collision geometry is defined by level data, never derived from art.

## Current inventory (Phase 0)

| Asset | Type | Origin | Licence | AI-assisted | Notes |
|---|---|---|---|---|---|
| (none) | | | | | No art, audio or fonts are bundled. Menu colours are flat `ColorRect` fills and text uses Godot's built-in default font. |

## Engine and tooling

| Component | Version | Licence | Source | Accessed |
|---|---|---|---|---|
| Godot Engine (standard build) | 4.6.2-stable | MIT (engine); bundled third-party components listed in Godot's own licence data | https://github.com/godotengine/godot/releases/tag/4.6.2-stable | 2026-11-17 |

Godot's built-in default theme font is embedded in the engine and covered by the engine's third-party licence list. Before a release build, export the engine's licence notices (Godot editor: *Help > About Godot > Third-party Licenses*, or `Engine.get_license_info()`) and ship them. This is a Prompt 17 task.

## To add per asset

```
Name:
Type (font/sprite/sound/other):
File(s):
Author or tool:
Source URL / how it was made:
Licence and URL:
Version / date accessed:
AI-assisted (yes/no, which tool):
Modifications:
Attribution required (yes/no, text):
```
