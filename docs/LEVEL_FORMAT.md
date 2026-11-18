# Level data format, schema version 1

One level is one JSON file. Hand-authored levels, the future editor and future generators all produce this exact format, and every consumer goes through `LevelLoader`, which parses strictly (`LevelCodec`) and then validates meaning (`LevelValidator`). A reference example is `levels/workshop.three_pins.json`.

All coordinates are **design space**: origin top-left, x to the right, y down, units are design units. The board is fitted into the window by presentation code; level data never contains pixel or window sizes.

## Where files live

| Location | Purpose | Notes |
|---|---|---|
| `res://levels/<level_id>.json` | Built-in levels shipped with the game | Read as plain text, never via `load()`. The export preset must include `*.json` (Prompt 17). |
| `user://levels/<level_id>.json` | Imported, edited or generated levels | Outside the executable resource tree. |

The file name must equal the `level_id` inside it. Only `.json` files directly inside those two folders are readable; paths with `..`, backslashes, other roots or other extensions are rejected before any file access. Files over 1 MiB are refused. A UTF-8 byte order mark (added by some Windows editors) and Windows line endings are accepted.

## Safety

Data is parsed with Godot's `JSON` class into plain values and read through a strict, typed codec. Nothing in a level file is ever passed to `load()`, `str_to_var()`, `bytes_to_var()` or instantiated, so a file cannot cause code, scripts or resources to load. Unknown keys are errors. Strings that look like resource paths are ordinary text (and invalid as ids).

## Top level

| Key | Type | Rule |
|---|---|---|
| `schema_version` | int | must be 1 |
| `level_id` | string | id, see below |
| `title` | string | 1 to 200 characters |
| `sim_config_version` | int | must equal the build's `SimConfig.CONFIG_VERSION` (currently 2: version 1 had no physics, version 2 is the first physics tuning) |
| `meta` | object | `author` (string), `created` (`YYYY-MM-DD`), `source` (`handcrafted`, `editor`, `generator`), `notes` (optional string, up to 1000) |
| `design_size` | [w, h] | each side 200 to 4096 |
| `allowed_mechanics` | string list | subset of `pins`, `scrap`, `hazard_cores`, `disposal_zones`, `hazard_zones` |
| `walls` | list | up to 64 walls and 1024 points in total |
| `pins` | list | up to 16 |
| `spawns` | list | up to 150, the measured dynamic body limit (see [PHYSICS.md](PHYSICS.md)) |
| `goals` | list | up to 8 |
| `hazards` | list | up to 16 |
| `objective` | object | see below |
| `known_sequences` | list | up to 32, may be empty |

**Ids** are dot-separated segments of `a-z`, `0-9`, `_`, starting with a letter, at most 64 characters (`pin.a`, `workshop.three_pins`). Every wall, pin, spawn, goal and hazard id must be unique within the level. Ids are the persistent identity for solutions, hints and saves; never use list positions.

**Mechanics.** Anything used must be declared: pins need `pins`, scrap spawns need `scrap`, core spawns need `hazard_cores`, disposal goals need `disposal_zones`, hazards need `hazard_zones`. The planned but unimplemented mechanics `fans`, `portals`, `rescue_lift` and `heater` are rejected (`mechanic.unsupported`), as is anything unknown.

## Objects

**Wall**, two kinds:
- `{"id", "kind": "polyline", "thickness", "points": [[x,y], ...]}`: at least 2 points, thickness 8 to 64, a thick line.
- `{"id", "kind": "polygon", "points": [[x,y], ...]}`: a filled solid, at least 3 points, no thickness key, area at least 400.

Up to 256 points per wall and 1024 across all walls, all inside the design space, no segment shorter than 4, no self-crossing or fold-back.

**Pin**: `{"id", "tip", "handle", "thickness", "pull_direction", "pull_distance"}`. The pin is the segment from `tip` (blocks material) to `handle` (the player grabs it). It slides out along its own axis, so `pull_direction` must be a unit vector pointing from the tip toward the handle, and `pull_distance` must be at least the pin length (so the withdrawn pin clears its footprint). Length 40 to 2000, thickness 6 to 32, tip and handle inside the design space, pins at least 4 units apart.

**Spawn**: `{"id", "material", "position"}` with material `token`, `scrap` or `core`. Positions are explicit and never randomised at runtime. Each body must be fully inside the design space and clear (by at least 2 units) of walls, pins, other spawns and every goal and hazard rectangle. Radii: token 14 (final, see [PHYSICS.md](PHYSICS.md)), scrap 14 and core 16 (provisional until they are simulated).

**Goal**: `{"id", "kind": "collector" | "disposal", "rect": [x, y, w, h], "accepts": [materials], "protected": bool}`. Rectangles are at least 20 per side and inside the design space. `protected` means delivering a material the goal does not accept is a failure (rules arrive in Prompt 05/06).

**Hazard**: `{"id", "kind": "destroy_zone", "rect", "affects": [materials]}`. Goals and hazards must not overlap each other.

**Objective**: `{"required_tokens", "allowed_token_losses", "collector_ids", "fail_conditions"}`. `required_tokens` is 1 to the number of token spawns (default design: all of them). `allowed_token_losses` is 0 to (tokens minus required), so a lowered threshold is always a visible number in the data. `collector_ids` must name collectors that accept tokens. `fail_conditions` come from `scrap_in_protected`, `core_in_protected`.

**Known sequence** (optional): `{"id", "actions": [pin ids in pull order], "expected_result": "won" | "lost" | "jammed"}`. Pins are one-use so an id may appear once per sequence. Sequences are claims to be verified by real physics replay (Prompt 16); do not add one that has not been replayed.

## Saving

`LevelCodec.to_json_text` writes canonical text: sorted keys, tab indent, trailing newline, coordinates rounded to 0.0001. Loading and saving again yields identical bytes. `LevelLoader.save_file` validates first, writes `<file>.tmp`, then renames, so a failed save never damages an existing file.

**Rounding on save.** Rounding to 0.0001 can move a body a hair inside a clearance limit. Measured: about 4 percent of placements within 0.0004 of a limit are valid in memory but invalid after rounding. So save validates the rounded text as well, and a definition that fails only because of rounding is refused with the code `save.rounding` (and the underlying issue). The fix is to move the objects apart or away from walls by a small amount. A level loaded from a file is already rounded and never hits this. In memory, a `LevelInstance` uses the exact values that were validated, not rounded ones.

## Validation issue codes

Every problem has a code, a path such as `pins[1].tip`, and a message. Tools and tests match on the code.

| Group | Codes |
|---|---|
| Structure (codec) | `type.mismatch`, `key.missing`, `key.unknown`, `json.parse` |
| Files | `path.rejected`, `file.missing`, `file.unreadable`, `file.too_large`, `id.file_mismatch` |
| Header | `schema.version_unsupported`, `sim.version_mismatch`, `id.invalid`, `id.duplicate`, `text.invalid`, `meta.date_invalid`, `meta.source_invalid`, `design.size_invalid` |
| Limits | `count.exceeded`, `number.not_finite` |
| Instancing | `level.missing` (no definition was given to `LevelInstance.create`) |
| Saving | `save.rounding` |
| Mechanics | `mechanic.unknown`, `mechanic.unsupported`, `mechanic.duplicate`, `mechanic.undeclared_use` |
| Walls | `wall.kind_invalid`, `wall.too_few_points`, `wall.thickness`, `wall.out_of_bounds`, `wall.degenerate_segment`, `wall.self_intersect`, `wall.polygon_area` |
| Pins | `pin.thickness`, `pin.length`, `pin.out_of_bounds`, `pin.direction_not_unit`, `pin.direction_mismatch`, `pin.pull_distance`, `pin.overlap` |
| Zones | `goal.kind_invalid`, `goal.accepts_empty`, `goal.accepts_unknown`, `goal.rect`, `goal.overlap`, `hazard.kind_invalid`, `hazard.affects_empty`, `hazard.affects_unknown` |
| Spawns | `spawn.unknown_material`, `spawn.out_of_bounds`, `spawn.in_wall`, `spawn.in_pin`, `spawn.in_zone`, `spawn.overlap` |
| Objective | `objective.required_tokens`, `objective.allowed_losses`, `objective.collector_ref`, `objective.collector_kind`, `objective.fail_condition_unknown` |
| Sequences | `sequence.empty`, `sequence.pin_unknown`, `sequence.pin_repeated`, `sequence.result_unknown` |

Cheap checks run first. Oversized lists are refused before any entry is parsed, and if counts are exceeded or any number is not finite the quadratic geometry checks are skipped, so hostile files cannot cause large amounts of work. The wall point cap exists for this reason: before it, a legal 200 KB level (64 walls of 256 points) took 5.5 seconds to validate; the largest legal level now validates in about 0.5 seconds. Deeply nested JSON is rejected by the engine's own depth limit.

## Runtime and events

A `LevelDefinition` is never played directly. `LevelInstance.create(definition)` validates it, deep-copies it, and builds mutable records (material positions and status, pin pulled flags). Changing an instance never changes the definition or any later instance, so restart always begins from the authored positions. While a `SimWorld` runs, it copies each token's position into the instance's material records every tick, so `state_signature()` shows where the tokens are now; `initial_state_signature` is the fixed record of where they began. Two signatures support tests: `geometry_signature()` (immutable geometry and starting positions, also available on the definition, with `geometry_hash()`) and `state_signature()` (all mutable state).

`LevelEvent` types: `action_requested`, `action_accepted`, `action_rejected`, `material_collected`, `material_lost`, `material_destroyed`, `level_won`, `level_lost`, `level_jammed`. `EventLog` assigns a total order and refuses a second terminal event, any event after the terminal one, and a second resolution of the same material. Rules that emit these events arrive in later stages.

## Changing the format

Bump `LevelSchema.SCHEMA_VERSION` for any incompatible change and add an explicit migration. Changes to radii, gaps or limits that alter what is playable also change the simulation config version and require revalidating known solutions.
