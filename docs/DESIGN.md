# Design

Working name: **Pin Puzzle Project**. Original game; no Homescapes characters, graphics, UI, layouts or story. Screenshots of other games, if ever consulted, are mechanic references only.

## Fantasy and theme

An apprentice tinkerer restores a whimsical workshop. Each chamber is a toy-like machine. The player pulls pins to let brass tokens and power cores fall through the machine into the right collector, while keeping dangerous materials away from it.

Style direction (applied in a later stage): colourful toy-workshop diorama, brass hardware, cream enamel chambers, teal machinery, warm wood.

## Platform and presentation

- Windows/Steam first. Offline, single-player, no accounts or servers.
- Landscape. Design space **1920x1080**, stretch mode `canvas_items`, aspect `expand`. UI is built with anchors/containers so it scales with window size and Windows display scaling.
- Touch-friendly: every interactive control is at least **96x96 design units** (`UiMetrics.MIN_HIT_SIZE`, enforced by a scene test). Pin hit regions will be generous and non-overlapping.
- Mouse first, keyboard focus supported, touch must work without precision.
- Keyboard focus must be obvious at a glance on every background: a thick bright ring with a dark outer edge, defined once in `themes/base_theme.tres` (`UiMetrics.MIN_FOCUS_RING_WIDTH`, enforced by a scene test).

## Interaction contract

Puzzles test **pin order, not reflexes**.

1. One accepted action at a time: the player pulls one pin.
2. The pin withdraws along its pull direction. Collision stops blocking exactly when the visible pin has cleared the material path, never earlier.
3. The board then **settles** before another action is accepted. Settled means all of: a minimum observation period has elapsed, every dynamic body has stayed below motion thresholds for a sustained window, and pending interactions have finished. Cosmetic particles and idle animation never count.
4. If the board has not settled within a maximum simulated duration it becomes **JAMMED**: a recoverable retry state. A timeout is never an automatic win and never accepts further pulls.
5. Restart is always instant and always available. There is no undo of a running physics world in version 1.

Thresholds are fixed in the physics tuning stage and recorded in `SimConfig` (tick rate is already fixed at 60/s).

## Initial mechanics (target of phases 1 to 4)

| Element | Rule |
|---|---|
| Chamber walls | Static collision, visibly identical to the drawn boundary. Defined as validated polylines/polygons in level data. |
| Pin | One-use. Stable string ID. Has a pull direction. Blocks materials until withdrawn. Only one pin pulled per turn. |
| Brass token | Dynamic circular body. The thing to collect. Unique ID, collected or lost at most once. |
| Dark scrap | Inert dynamic body. May be routed to disposal. Fails the level if delivered to a protected collector. |
| Hazardous energy core | Visibly distinct dynamic body. Entering a protected goal fails the level and triggers a cosmetic burst only. |
| Collector | Goal region with a required token amount. Protected collectors reject scrap and cores. |
| Disposal zone | Accepts scrap (and optionally other listed materials) without penalty. |
| Out of bounds | Materials leaving the board are counted as lost, once. |

Level states: `READY`, `SETTLING`, `WON`, `LOST`, `JAMMED`. Objectives are evaluated in a stable per-tick order; a hazard arriving in the same tick as an apparent success wins the tie (failure). Totals are tracked explicitly and never inferred from animation. Default objective: collect all required tokens; lower thresholds are visible level rules, never hidden physics workarounds.

Shape and icon cues accompany colour for every material and hazard (colour-independent).

## Phased scope

Phases follow the prompt pack stages in `Pin_Puzzle_Game_Claude_Code_Prompts.md`.

| Phase | Prompts | Outcome |
|---|---|---|
| 0 Scaffold | 01 | Project, menu, empty level, test runner, docs. Done. |
| 1 Prototype core | 02 to 06 | Level data, walls and tokens, pins and sequencing, win/lose, scrap and hazards. **Current** (02 and 03 built) |
| 2 Prototype polish | 07, 08 | Original art kit, internal level editor, ten handcrafted levels |
| 3 Complete game | 09 to 17 | Fans, portals, rescue/heater objectives, campaign and saves, hints, 30 levels, audio and accessibility, robustness harness, Windows export |
| 4 Generation (optional, later) | 18 to 25 | Seeded templates, logical solver, real-physics validation, approved packs, endless mode |
| 5 Release | 26 to 28 | Regression gate, Steam materials, release candidate |

A handcrafted campaign can ship after phase 3. Phase 4 must not destabilise it. Level format and simulation hooks are designed from the start so generators can emit the same `LevelDefinition`.

## Explicit exclusions

- No match-3 gameplay.
- No lives, energy timers, wait timers, ads, in-app purchases, accounts, server dependency, telemetry or online services.
- No copied third-party characters, art, UI, layouts, levels or story.
- No true fluid simulation. Water, if shown, is cosmetic and must not imply interactive rules.
- No timing or reflex challenges in version 1 (no moving obstacles that require timed pulls).
- No procedural generation until phase 4, and then only for mechanics that the logical model and physics validator explicitly support.
- No undo or rewind of a running physics world in version 1.
- No claim that physics is bit-for-bit deterministic across machines or builds. A verified solution is tested evidence under recorded conditions.

## Open questions (decide in the stage that needs them)

- ~~Exact token radius, masses, friction, bounce, gravity, wall thickness and body-count limit~~: decided in Prompt 03, see [PHYSICS.md](PHYSICS.md).
- Settle thresholds and maximum jam duration: Prompt 04.
- Final public name: undecided; the working name implies nothing about availability.
