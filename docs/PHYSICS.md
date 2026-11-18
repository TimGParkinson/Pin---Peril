# Physics

Status: Prompt 03 (walls, brass tokens, reliable 2D physics). Everything here was measured on one machine with the pinned engine; the numbers are evidence under recorded conditions, not a promise about other machines or engine versions. See [ARCHITECTURE.md](ARCHITECTURE.md#versioning) for what a change requires.

Measurement conditions: Windows 11, Intel Core i7-7700 3.6 GHz, 15.9 GB RAM, NVIDIA GTX 1060 3 GB, Godot 4.6.2-stable (GodotPhysics2D), 2026-11-17.

## What is simulated

| Thing | Body | Notes |
|---|---|---|
| Walls | one `StaticBody2D` per wall (`StaticPartBody`) | Capsules per polyline segment, convex pieces per polygon |
| Pins | one `StaticBody2D` per pin | **Immovable until Prompt 04.** They are present so the three-pin layout rests as designed. Shaft rectangle plus handle knob disc |
| Brass tokens | one `RigidBody2D` per token (`TokenBody`) | The only dynamic bodies |
| Scrap and cores | none yet | Drawn at their start positions; simulated when their rules arrive (Prompt 06) |

`SimWorld` (sim layer) builds all of this from a `LevelInstance`. It sits at the origin and ignores its parent's transform, so physics coordinates are design coordinates and scaling the board to the window is purely presentation.

## World and units

Units are design units (1 unit = 1 pixel of the 1920x1080 design space; levels are typically 1600x900 units). Time is seconds; the simulation ticks 60 times a second. All numbers below live in `SimConfig`, are mirrored in `project.godot` where the engine owns them, and are checked on every `SimWorld.build` and by `tests/domain/test_sim_config.gd`.

| Setting | Value | Where | Why |
|---|---|---|---|
| Tick rate | 60 per second | `physics/common/physics_ticks_per_second` | Unchanged since Prompt 01 |
| Gravity | 1000 units/s squared, straight down | `physics/2d/default_gravity` | A token falls the 800 unit height of a normal board in about 1.3 s: weighty but readable. Round number |
| Token radius | 14 (28 across) | `LevelSchema.MATERIAL_RADIUS` | See "Sizes" |
| Token mass | 1.0 | `SimConfig.TOKEN_MASS` | Only ratios matter; all tokens equal |
| Token friction | 0.4 | `TOKEN_FRICTION` | Middle of a plateau: 0.3 to 0.8 behaved the same (sweep below) |
| Token bounce | 0.15 | `TOKEN_BOUNCE` | Same plateau for 0.05 to 0.3. Brass settles quickly |
| Token linear damping | 0.05 per second | `TOKEN_LINEAR_DAMP` | Almost none; Godot damping is velocity proportional |
| Token angular damping | 1.0 per second | `TOKEN_ANGULAR_DAMP` | The only sensitive knob (sweep below). Both damping modes are REPLACE so project or area defaults cannot change the feel |
| Wall friction, bounce | 0.5, 0.1 | `WALL_*` | |
| Wall thickness | 8 to 64 for polylines | `LevelSchema.WALL_THICKNESS_*` | Safe with ray CCD; without it the 8 minimum tunnels from about 1100 units/s |
| Polygon walls | edges at least 4 long, area at least 400 | `LevelSchema` | Thinnest legal plate is 4 thick, wedges taper to a point; safe only with ray CCD |
| CCD | **ray mode** on tokens | `SimConfig.TOKEN_CCD_MODE` | Justified by observed tunnelling at the speed limit; see below |
| Speed limit | 1000 units/s | `SimConfig.MAX_TOKEN_SPEED` | Defense in depth, applied inside the physics step. Not shown necessary; see below |
| Sleep | below 2 units/s and 8 degrees/s for 0.5 s | `physics/2d/sleep_*`, `time_before_sleep` | Engine defaults, now pinned and guarded |
| Solver iterations | 16 | `physics/2d/solver/solver_iterations` | Engine default, pinned |
| Collision layers | wall 1, pin 2, token 4 | `SimConfig.LAYER_*` | Tokens collide with all three |
| Body limit | 150 dynamic bodies per level | `SimConfig.MAX_DYNAMIC_BODIES` = `LevelSchema.MAX_SPAWNS` | See "Cost" |

`physics/common/physics_interpolation` is on: the renderer smooths token visuals between ticks on displays that are not exactly 60 Hz. It does not change the simulation.

Simulation config version is now **2** (version 1 had no physics). `SimTuning` holds the adjustable numbers with `signature()` text to record next to replay results.

## Collision geometry equals what is drawn

Visual detail is separate from collision, and collision uses the simplest exact shapes (`BoardColliders`):

- **Polyline wall**: one `CapsuleShape2D` per segment (radius half the thickness, ends exactly on the points). Flat segment rectangles plus a disc at every point is what `BoardView` draws, so drawing and collision are the same region, including round joints and ends. (`draw_polyline` would have drawn miter spikes the physics does not have, so it is not used.)
- **Polygon wall**: the convex decomposition from `Geometry2D.decompose_polygon_in_convex`. Tests check the pieces cover exactly the polygon (concave L and U shapes, both windings).
- **Pin**: a rectangle from tip to handle plus a disc of 1.2 pin thicknesses at the handle (`SimConfig.PIN_KNOB_RADIUS_FACTOR`). Outlines are drawn inside these shapes.

How it is checked: `tests/physics/test_collision_geometry.gd` asks the real physics engine (a point query) about every point of a 6 unit grid over three levels and compares with what the level data says is solid. Points within 0.75 units of an edge are skipped. Zero disagreements, thousands of solid and empty points on both sides, and a mutation check that a 3 unit error is noticed. The debug overlay (below) draws the shapes straight from the physics nodes, so you can see the same thing.

## Tunnelling, CCD and the speed limit

Tunnelling means a fast body ends up on the far side of a thin wall because it moved further in one tick than the wall is thick. Measured, not assumed.

**A correction first.** My first version of these measurements and tests dropped tokens for a fixed 230 to 260 ticks. At the speed limit a token needs about 265 ticks to fall the 3900 unit shaft (one second to reach the limit, 3400 units after), so **no token had reached the floor** and every "0 tunnelled" at the limit was vacuous; only the faster, earlier-arriving cases were real. I found this while writing this document, re-measured properly, and the conclusions changed (thin polygons do tunnel at the limit). Every drop below, and every drop in `tests/physics/test_tunnelling.gd`, now runs until each token has gone through or come to rest (a falling token is never asleep), and the speed just before contact is recorded so the impact is shown to be real. The tests include a mutation proof: cutting the drop back to 230 ticks makes six of them fail.

**Raw probe** (one 14 radius body started just above a flat capsule floor at a fixed speed, 40 trials per cell with random phase within the tick, tunnelled out of 40). This probe always had real impacts:

| Floor thickness | 600 | 1000 | 1300 | 1600 | 2000 | 2600 | 3200 units/s |
|---|---|---|---|---|---|---|---|
| 8 | 0 | 0 | 5 | 12 | 23 | 23 | 31 |
| 12 | 0 | 0 | 4 | 11 | 19 | 15 | 23 |
| 16 | 0 | 0 | 0 | 10 | 8 | 21 | 23 |
| 24 | 0 | 0 | 0 | 1 | 8 | 12 | 21 |

With ray CCD (`CCD_MODE_CAST_RAY`) every cell is 0 up to 3200. Shape-cast CCD (`CCD_MODE_CAST_SHAPE`) tunnelled about as often as no CCD, so it is not an option.

**On the real `SimWorld`**, tokens dropped down a 4096 unit shaft (12 variants per cell, 120 tokens, 72 for the wedge), CCD off, tunnelled tokens per speed limit; every row finished and every straight drop hit at the limit:

| Speed limit | polyline 8 thick | polygon plate 4 thick | wedge tapering to a point | V trough of two 8 thick polylines |
|---|---|---|---|---|
| 800, 900 | 0 | 0 | 0 | 0 |
| **1000 (shipped limit)** | 0 | **6 of 120** | **12 of 72** | 0 |
| 1050 | 0 | 13 | 0 | 0 |
| 1100 | 4 | 18 | 0 | 0 |
| 1150 | 0 | 14 | 36 | 0 |
| 1200 | 15 | 29 | 26 | 0 |
| 1300 | 22 | 22 | 0 | 0 |
| 1400 | 39 | 53 | 36 | 0 |
| 1600 | 45 | 59 | 72 of 72 | 7 |
| no limit (impacts up to 2657) | 23 | 38 | 60 | 70 of 120 |

The pattern is erratic (it depends on where within a tick the token first overlaps the wall), but the threshold is clear: **thin polygons tunnel at the speed limit itself, and an 8 unit polyline tunnels from about 1100 units/s, only 10 percent above the limit.** That is observed tunnelling of legal level data, which is the case that justifies CCD.

With ray CCD on, the same drops:

| Setting | polyline 8 | plate 4 | wedge | V trough |
|---|---|---|---|---|
| ray CCD, limit 1000 | 0 | 0 | 0 | 0 |
| ray CCD, limit 1200 / 1600 / 2400 | 0 | 0 | 0 | 0 |
| ray CCD, no limit (impacts 1855 to 2659) | 0 | 0 | 0 | 0 |
| shape-cast CCD, limit 1000 | 0 | 6 | 12 | 0 |

**Decision: ray CCD on every token, and a speed limit of 1000 units/s.**

- Ray CCD is what removes the tunnelling, at every speed tried. Cost is small: the 150 token pile averaged 1028 microseconds per tick with it against 923 without (see Cost). It does not change flow (all flow and pile tests pass unchanged with it on).
- The speed limit is **not shown to be necessary** by any measurement now that CCD is on (no tunnelling even with no limit, and tokens landing at 2650 units/s on a resting row never passed through each other or the floor; the closest pair of centres was 27.1 against a 28 diameter). It stays as defense in depth: it keeps per-tick travel under one diameter (16.7 against 28), which token-against-token contact depends on (that uses ordinary discrete detection), and without it tokens falling a tall board become invisible streaks at 3900 units/s. It only matters when a token falls more than about 500 units. Removing it would need a measurement showing nothing else breaks. I first believed the limit was the tunnelling fix; the corrected measurements show CCD is.
- One cheap thing remains untested: ray CCD follows only the token's centre path, so a very fast token could clip the corner of a wall without a recorded contact. No such leak was found; the limit also bounds this.

Revalidation rule: any change to the limit, to CCD or to the thinnest legal wall or plate repeats `tests/physics/test_tunnelling.gd` and bumps the sim config version. The tuning is recorded as text in `tests/domain/test_sim_config.gd` so it cannot change silently.

One measurement trap, so nobody repeats it: tokens released from one height all meet a wall at the same phase within a tick and test only one phase, so the scenarios step each token 1.7 units lower than the last (`PHASE_STEP`) and the variants shift further.

## Sizes

- Token radius 14 (28 across, 1.75 percent of a 1600 unit board). Not tiny: about 22 pixels across at 1280x720 and 34 at 1920x1080. Smaller radii were not tried.
- Spawns are always at least 2 units clear of everything (`SPAWN_GAP`), so no body starts overlapping.
- Thinnest wall 8, thinnest polygon plate 4. Both are safe with ray CCD and neither is safe without it at the speed limit (see above).

## Flow guidance for level design

Measured over seeded runs with spawn jitter. The validator does not enforce these; `SimConfig` records them and tests keep them true. A "crowd" is 36 tokens in a hopper.

**Openings** (gap between wall faces, in token diameters; runs where every token passed within 25 s):

| Opening | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 | 4.0 | 5.0 |
|---|---|---|---|---|---|---|---|---|
| Units | 28 | 42 | 56 | 70 | 84 | 98 | 112 | 140 |
| Runs that fully passed | 0 of 10 | 0 of 10 | 2 of 10 | 9 of 10 | 10 of 10 | 20 of 20 | 10 of 10 | 10 of 10 |
| Median ticks to pass | n/a | n/a | 286 | 197 | 143 | 119 | 96 | 85 |

An opening narrower than a token passes nothing; exactly one token wide passed a single token once. **A crowd should get an opening of at least 3.5 diameters (98 units)** (`SimConfig.RELIABLE_OPENING_DIAMETERS`). Narrower openings jam by forming a stable arch (the tokens fall asleep): a physical jam at a known width, not a bug. Gaps meant for one or two tokens can be tighter (a single token passed a gap exactly its own width); that was not measured systematically.

**Slopes** (5 tokens, 700 unit ramp, median ticks to roll off): 2 degrees 790, 3 degrees 576, 5 degrees 399, 10 degrees 253, 20 degrees 167, 30 degrees 133, 45 degrees 103, 60 degrees 82. Every angle from 2 up flowed in 10 of 10 runs; 1 degree was still rolling (about 31 units/s) after 20 s. **Ramps below 5 degrees crawl** (`SimConfig.COMFORTABLE_SLOPE_DEGREES`); the crawl is the angular damping, since a steady rolling speed equals slope acceleration divided by damping.

**Corners**: 16 tokens dropped into two walls meeting at 20, 30, 45, 90 and 120 degrees, three seeds each: every token ended inside the corner, none through a wall, all asleep in about 100 to 190 ticks. Acute corners wedge tokens; they never squeeze one out.

**Piles**: 25, 75 and 150 tokens dropped into a box, three seeds each: all settle (asleep) inside the box. Worst settle time in the profile runs 435 ticks (7 s); the 100 token pile test also checks the pile is at least 4 layers tall and no two tokens overlap by more than 3 units.

**Open floors creep.** On the lab level (48 tokens that spread over an open floor) the pile took 1213 ticks (20 s) to fall fully asleep, because round tokens on a flat floor keep spreading slowly under the weight above them. Raising angular damping did **not** fix it: at 2.0 it took 2448 ticks, at 3.0 and 4.0 it was still awake after 4000, and ramps got slow (10 degree ramp 253, 322, 410, 510 ticks at damping 1, 2, 3, 4). So 1.0 stays. This matters for Prompt 04: the settle thresholds and maximum duration must allow a worst case of about 20 s, or bound the creep by putting walls round collection bays.

### Tuning sweep

27 combinations of token friction (0.3, 0.5, 0.8), bounce (0.05, 0.15, 0.3) and angular damping (0.3, 1.0, 2.0). Results were almost insensitive to friction and bounce: a 100 token bowl settled in 111 to 307 ticks in every combination, and a 36 token crowd passed an 84 unit opening 5 of 5 times in all but one (friction 0.8, bounce 0.15, damping 2.0: 3 of 5). Angular damping decided the ramp speed: 3 degree ramp median 428, 577, 885 ticks at 0.3, 1.0, 2.0. The shipped values sit in the middle.

## Cost and the body limit

`scripts\profile-physics.ps1` times every tick (from one `physics_frame` to the next, so it includes the physics step, `SimWorld`'s sync and the frame loop) while any token is awake, three seeds per row. 16667 microseconds is the whole 60 Hz tick. Final shipped tuning (ray CCD on), headless, microseconds per tick:

| Scene | Tokens | Mean | p95 | Worst |
|---|---|---|---|---|
| pile | 25 | 231 | 366 | 848 |
| pile | 50 | 348 | 472 | 1046 |
| pile | 100 | 673 | 1134 | 1746 |
| pile | **150** | **1028** | **2019** | **2575** |
| pile | 200 | 1242 | 2183 | 2858 |
| pile | 300 | 1917 | 3259 | 5996 |
| flow | 24 / 48 / 72 | 237 / 349 / 481 | 368 / 554 / 715 | 1274 / 1509 / 1563 |

**These numbers are noisy.** Repeating the same profile back to back on this desktop moved the 150 token mean between 1000 and 1313 microseconds (and one unrelated tick took 33 ms, an operating system hiccup), so treat any figure here as accurate to about plus or minus 25 percent. `--ccd-off` on the profile tool compares ray CCD against none; three rounds each (pile of 150, mean): CCD on 1313, 1180, 1000; CCD off 1237, 969, 920. **Ray CCD costs between nothing and roughly 20 percent, inside the noise**, so it is not a cost problem.

Windowed (real renderer, vsync off; the loop also draws an almost empty scene, which is part of the extra): 150 tokens measured mean 1692 / p95 3095 / worst 4145 microseconds before CCD was enabled and 2347 / 3610 / 4687 after, in two separate runs; the 300 token row reached a worst tick of 6.7 to 9.3 ms.

Cost grows about linearly, roughly 6 microseconds per awake token per tick. **Decision: 150 dynamic bodies per level** (the Prompt 02 provisional value, now measured). At 150 on this machine the physics alone (headless) uses about 6 percent of the 60 Hz budget on average and at most 16 percent on the worst tick; the whole windowed frame loop uses 10 to 14 percent on average and at most 28 percent on the worst tick. That leaves comfortable room on this machine (an i7-7700 and GTX 1060, a mid-range 2017 desktop) but **less than a threefold margin on the worst tick**, so the limit is not generous: 200 or 300 would not leave enough, and a low-end laptop must be measured before the release stage. Typical levels will use 5 to 60 tokens. Sleeping bodies cost almost nothing, so a settled board is cheap, and the awake period of even the heaviest pile lasts about three seconds.

The Performance monitor `TIME_PHYSICS_PROCESS` was tried first and rejected: it did not update per tick (it reported the same figure for every row). Wall-clock timing between ticks is used instead. `test_flow.gd::test_the_body_limit_costs_a_small_part_of_the_tick_budget` is only a tripwire (mean under 8000 microseconds); it is not a benchmark.

## Reproducibility

Two runs of the same definition on this machine and build produced identical state (`test_repeated_runs_of_the_same_level_are_identical...`), and a different jitter seed produced a different state, so the comparison means something. This is not a claim of bit-exact determinism across machines or engine builds (DESIGN states the project makes no such claim).

## Debug overlay

Off by default. In debug builds on the level screen: **F2** collision shapes (drawn from the live physics shapes: walls cyan, pins magenta, tokens green), **F3** body ids, **F4** velocity arrows (green slow, red at the speed limit; an arrow shows 0.25 s of travel), **F5** statistics (tick, tokens, awake, fastest and peak speed, limit, tokens outside the board, fps). The overlay only reads the world; a test runs the same level with and without every layer and requires identical state.

To open the physics lab (48 tokens, ramps, a 104 unit opening, a 45 degree funnel with a 100 unit exit): `godot --path . -- --level=dev.physics_lab`, then Play. Debug builds only; `AppRoot.level_id_from_arguments` ignores the argument otherwise.

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File scripts\test-physics.ps1            # 30 physics tests, about 20 s
powershell -ExecutionPolicy Bypass -File scripts\test-physics.ps1 -Windowed  # same on the real renderer (vsync off)
powershell -ExecutionPolicy Bypass -File scripts\profile-physics.ps1 [-Windowed]
```

The physics suite runs with `--fixed-fps 60`: each frame is exactly one 1/60 s tick and the loop does not wait for the clock. Without that flag 1000 ticks take 17 seconds.

## Known limits

- Pins are immovable. Pulling, the settle rules, win and lose, and scrap and core bodies come in Prompts 04 to 06.
- `SimWorld.all_tokens_asleep()` is a helper, not the settle rule; thresholds and the jam timeout are Prompt 04.
- A token resting on a pin's handle knob is physically supported, but the validator only clears spawns from the pin shaft, not the knob. A spawn placed inside a knob starts overlapping and is pushed out. Decide in Prompt 04 whether to validate it.
- Measurements are from one machine. Re-measure on a low-end machine before the release stage.
- Cosmetic particles and the animated water background are not part of this stage; neither will ever be a gameplay body, and water must not imply interactive rules.
