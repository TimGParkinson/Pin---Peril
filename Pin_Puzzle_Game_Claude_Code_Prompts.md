# Standalone Pin Puzzle Game: Claude Code Prompt Pack

Prepared 16 November 2026. An original single-player 2D puzzle game for a solo developer assisted by Claude Code. Includes the game, original code-produced graphics, internal level editor, verification gates and a later procedural level generator.

## How to use this

Open Claude Code inside your project folder. Paste Prompt 01, let it complete, then paste the reusable Verification Prompt. Continue one numbered prompt at a time, verifying between stages. Do not paste the entire pack as one task. Commit project-owned changes after successful stages and keep backups. Never let an agent discard unrelated work.

Default: Godot 4 stable, typed GDScript, Windows/Steam first, mouse and touch-friendly controls. Despite the developer's C# experience, this pack uses GDScript to keep setup and Godot iteration simple. If you prefer C#, make that decision before Prompt 01 and consistently adapt the build/test tooling; do not mix languages accidentally.

Working name: Pin Puzzle Project. No public name or availability claim is implied. Original theme: an apprentice tinkerer restores a whimsical workshop by routing brass tokens and power cores through machines. No match-3, lives, energy timers, ads, accounts or server dependency. No copied Homescapes characters, graphics, UI, layouts or story. Screenshots are mechanic references only.

### Development route

| Stage | Prompts | Outcome |
|---|---|---|
| Prototype | 01–08 | Small playable game with basic art and an editor |
| Complete game | 09–17 | Additional mechanics, levels, polish and Windows build |
| Later generation | 18–25 | Seeded templates, solver, physics validation and endless mode |
| Release | 26–28 | Regression checks, honest Steam materials and release candidate |

You can release a handcrafted campaign after Prompt 17 plus release checks and add generation in an update. Design the level format and simulation hooks from the beginning so generation does not require rewriting the game.

## Progress tracker

Tick a box only after the prompt has been run AND the Verification Prompt has passed (including manual checks). Each prompt section below has its own checkbox too. Keep both in sync so a prompt is never pasted twice.

- [x] Prompt 01: Establish the project and rules
- [ ] Prompt 02: Versioned level data and validation
- [ ] Prompt 03: Walls, tokens and reliable 2D physics
- [ ] Prompt 04: Pin interaction and action sequencing
- [ ] Prompt 05: Goals, losses, win and fail states
- [ ] Prompt 06: Hazard materials and meaningful choices
- [ ] Prompt 07: Original art and feedback pass
- [ ] Prompt 08: Internal level editor and ten-level prototype
- [ ] Prompt 09: Fans and directional forces
- [ ] Prompt 10: Portals without loops or duplication
- [ ] Prompt 11: Rescue objectives and mechanical progress
- [ ] Prompt 12: Campaign, progression and safe saves
- [ ] Prompt 13: Hints and solution replay
- [ ] Prompt 14: Level-design pass and a small campaign
- [ ] Prompt 15: Sound, usability and accessibility
- [ ] Prompt 16: Physics robustness and repeatable test harness
- [ ] Prompt 17: Windows export and handcrafted release gate
- [ ] Prompt 18: Define the procedural subset and puzzle graph
- [ ] Prompt 19: Seeded template generation
- [ ] Prompt 20: Logical solver and meaningful-choice checks
- [ ] Prompt 21: Validate generated solutions in real physics
- [ ] Prompt 22: Difficulty bands, quality and diversity
- [ ] Prompt 23: Generation review tools and approved content packs
- [ ] Prompt 24: Endless mode with bounded generation and fallback
- [ ] Prompt 25: Persistence, seed sharing and generator update safety
- [ ] Prompt 26: Full regression and procedural stress gate
- [ ] Prompt 27: Steam materials and release preparation
- [ ] Prompt 28: Final release candidate and handover

## What automatic generation should mean

Do not place pins and hazards randomly and call the result a puzzle. Generate structured layouts from tested puzzle families, find a solution in a simplified logical model, replay that solution in the real physics game, reject fragile/uninteresting candidates and release only accepted puzzles.

A seed can reproduce layout data when versions are fixed. It does not make Godot rigid-body physics perfectly deterministic across machines or builds. Treat a verified solution as tested evidence under recorded conditions, not a mathematical guarantee on every device. Use ample physical clearances and no split-second timing. Persist generated layouts rather than relying solely on old seeds after updates.

Start procedural support with coins, pins, walls, traps and goals. Fans, portals and moving mechanisms can remain handcrafted until their logical and physical validation is implemented. Do not pretend the basic solver supports every mechanic.

### Default interaction contract

For the first release, puzzles test pin order, not reflex speed. Allow one pin action, then wait for the board to settle before the next. Use fixed physics ticks, a minimum observation period, low motion over a sustained window and event completion to determine settling. A timeout is an unresolved/jammed board, never automatic success. Design away inaccessible pins and ambiguous interactions.

## Reusable Verification Prompt: run after every stage

```text
Verify the stage just implemented before doing more feature work. Read CLAUDE.md, docs/DESIGN.md, docs/ARCHITECTURE.md and docs/PROGRESS.md. Inspect Git status and the current diff; preserve unrelated work. Identify the acceptance criteria for the current stage.

Run the documented import/parse check, automated domain tests, relevant scene/integration tests and export/build checks that exist at this stage. Capture real exit codes and errors. A launched process is not proof of a passing test. Never claim headless physics ran if the harness bypassed the actual physics step or mocked the simulation.

Exercise the changed feature in the real game when available. Check mouse/touch hit areas, scaling, input during animation, restart, pause/resume, transitions and repeated scene loading. Inspect visuals and errors. Label checks requiring manual Windows testing as pending rather than passed.

Review collision layers/masks, collision geometry versus visible geometry, fixed-tick state changes, deferred physics-safe object changes, object IDs, collection/death accounting, one-shot events, terminal-state handling, timer cancellation, stale callbacks and full restart cleanup. Do not move RigidBody2D objects by arbitrary transform changes each frame to fake physics.

Check meaningful regressions: the same good action sequence should reliably win; known bad actions should fail for the stated reason; cosmetic variation should not alter gameplay. For generator changes also check invalid-seed rejection, bounded runtime, duplicate detection, solution replay and safe fallback. A logical solver result alone is insufficient physics validation.

Fix stage-related defects and rerun affected checks. Add focused tests for bugs and changed behaviour; do not create assertion-free tests or test implementation details alone. Do not delete tests, suppress errors, lower success thresholds, widen collectors secretly or regenerate golden results without examining the difference.

Update docs/PROGRESS.md with actual commands/results, accepted features, limitations, manual checks and next stage. Report PASS, FAIL or BLOCKED. PASS requires all mandatory checks to be completed, including required manual checks; unavailable execution is BLOCKED, not PASS. Give a concise manual test script if necessary. Stop before the next stage. Suggest a Git checkpoint only when appropriate.
```

## Prompt 01: Establish the project and rules

- [x] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Create an original standalone pull-the-pin physics puzzle game in Godot 4 using typed GDScript. Working name: Pin Puzzle Project. Windows/Steam first, offline single-player, landscape presentation with scalable UI and touch-friendly hit areas. Theme: whimsical tinkerer workshop; route brass tokens/power cores safely through machines. Use original assets and levels. No match-3 or monetization infrastructure.

Inspect the folder first and preserve existing work. Check current official Godot stable documentation, choose and record an exact stable engine version plus matching export templates. Do not use unstable/latest APIs. Scaffold a minimal project with menu, empty level scene and restart/back controls. Use a renderer suitable for a lightweight 2D game and document the choice.

Create CLAUDE.md, README.md, docs/DESIGN.md, docs/ARCHITECTURE.md, docs/PROGRESS.md and docs/ASSETS.md. Define the initial mechanics, phased scope, exclusions and coding conventions. Separate level data, puzzle rules, physics simulation, presentation and progression. Plan a shared simulation runner for both gameplay and later automated replay.

Establish a practical test runner and scripts for headless import/parse, domain tests and scene tests; use a maintained pinned Godot-compatible framework or a small explicit runner with reliable nonzero exits. Document Windows commands and missing prerequisites. Acceptance: a clean project imports, menu opens, scene transitions work and checks actually detect an intentional test failure before that failure is removed. Stop after scaffolding.
```

## Prompt 02: Versioned level data and validation

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Implement a versioned data-driven LevelDefinition with stable level/object IDs, design-space dimensions, wall polylines or validated polygon geometry, pins and pull direction, initial material spawn positions, goals, hazards and allowed mechanics. Include objective rules and thresholds, simulation config version, authoring metadata and optional known solution actions. Record explicit non-overlapping spawn positions rather than randomizing piles at runtime.

Keep definitions separate from runtime instances. Validate finite numbers, bounded dimensions/counts, unique IDs, references, wall geometry, supported mechanics and spawn clearances before instantiating. Use safe data loading; do not load arbitrary executable scripts/resources from user-authored JSON. Keep imported data outside the executable resource tree.

Build one original three-pin test level from data. Define event types for action requested/accepted, material collected/lost/destroyed and terminal results. Acceptance: validation catches malformed definitions; data round-trips; restarting instantiates a fresh level with identical initial geometry. Future generators must output this same format.
```

## Prompt 03: Walls, tokens and reliable 2D physics

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Implement static chamber walls and a bounded number of dynamic brass tokens using Godot's 2D physics. Prefer simple collision shapes with visual detail separate from collision geometry. Specify wall thickness, token radius, clearances, mass/friction/bounce, gravity and a fixed physics-tick rate. Collision geometry must visibly match the playable boundaries.

Create debug overlays for collision shapes, body IDs and velocities. Test sloped channels, corners, narrow openings and piles. Use continuous collision detection where justified by observed tunnelling, not indiscriminately. Avoid tiny bodies, thin walls and overlapping spawn points. Cosmetic particles are not gameplay bodies.

Acceptance: tokens flow through intended openings without unexplained leaks or persistent jams across repeated runs. Profile a typical board and establish an initial body-count limit. No custom fluid simulation yet; animated water backgrounds may be cosmetic but must not imply interactive water rules.
```

## Prompt 04: Pin interaction and action sequencing

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Implement pins with clear hover/selected states, generous non-overlapping hit regions, pull-direction animation and physics-safe collision updates. Each pin is one-use for now. Define exactly when it stops blocking materials relative to its visible withdrawal; do not remove collision far ahead of the animation.

Allow one accepted action at a time. Disable subsequent actions until minimum simulation time has passed and dynamic bodies remain below motion thresholds for a sustained window, with pending interactions finished. Document settle thresholds. Handle particles/idle animation separately so visual effects do not prevent settling. If the board cannot settle within a maximum simulated duration, show a recoverable jam/retry state; do not auto-win or accept unsafe actions.

Acceptance: repeated taps cannot pull twice; input during settling is visibly blocked; removal wakes affected bodies; wrong pin order changes outcomes; no callback from an old level affects a restarted one. Record actions with stable pin IDs for future replay.
```

## Prompt 05: Goals, losses, win and fail states

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add collection goals, forbidden-material goals, disposal zones and out-of-bounds handling. Every gameplay object has one unique ID and can be collected/lost/destroyed only once. Track totals explicitly; never infer success from a bag-filling animation. Define each level's required token amount and allowed losses. Default to collecting all required tokens; lower thresholds must be visible level rules, not hidden workarounds for unreliable physics.

Implement explicit READY, SETTLING, WON, LOST and JAMMED states. Evaluate objectives in a stable physics-step order; hazards override apparent success when they arrive in the same step. Win must wait until the relevant simulation/events resolve. Distinguish irrecoverable failure from a board that can still be solved.

Add restart, next-level and clear feedback. Acceptance: good and bad action sequences produce correct results; repeated area signals do not double count; failed boards never later win; restart resets every body, counter, timer, effect and signal connection.
```

## Prompt 06: Hazard materials and meaningful choices

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add inert dark scrap as a forbidden material and a visibly distinct hazardous energy core. Document exact rules: scrap may be routed to disposal but fails if delivered to a protected collector; an energy core entering a protected goal triggers failure and a cosmetic burst. Keep hazard rules simple and unambiguous before adding chain reactions.

Add original puzzles requiring isolate-hazard, drain-waste-first and divert-before-release decisions. Avoid pins that appear meaningful but change nothing unless deliberately used as a tutorial example. Use visual shape/icon cues as well as colour. Add a rules/help panel explaining interactions.

Acceptance: rules operate through shared events used by both live play and tests; hazard/goal contact in the same tick resolves consistently; no explosion effect can accidentally award tokens or fire twice. Verify the new puzzles across repeated runs.
```

## Prompt 07: Original art and feedback pass

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Create an original coherent 2D art kit using local SVGs, Godot drawing/shaders and procedural animation. Style: colourful toy-workshop diorama, brass hardware, cream enamel chambers, teal machinery and warm wooden surfaces. Make pins, handles, tokens, scrap, hazard cores, collectors, buttons, panels and a simple original helper automaton. Do not reproduce Homescapes characters, UI or layouts.

Use visible material borders, sensible highlights, shadows and original gear/bolt motifs. Keep collision geometry readable and gameplay foreground clearer than backgrounds. Add token spin/glint, pin easing, gentle collector feedback, win celebration and restrained failure effects. Respect a reduced-motion setting; cosmetic RNG must be independent of gameplay RNG.

Create an asset contact sheet/gallery scene and a provenance/license list. Use licensed bundled fonts or safe system substitutes. Acceptance: assets read at normal size and reduced resolution, states remain distinguishable without colour alone, and toggling effects does not alter physics outcomes. External painted assets may be deferred; no broken asset-service dependency.
```

## Prompt 08: Internal level editor and ten-level prototype

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Build a simple developer-only level editor using the existing LevelDefinition format. Provide wall/channel drawing with snapping, pin placement/orientation, material spawn placement, goals/disposal/hazards, select/move/delete, undo/redo, validation, save/load and test-from-start. Prefer a focused in-game authoring scene or small Godot editor tool over a large custom plugin framework.

Keep edit state separate from test runtime. Returning from playtest must restore the unmodified authored definition. Include a known-solution recorder and thumbnail capture. Flag overlapping spawns, tiny passages and invalid pin sweeps. Use safe local data files and preserve existing files on failed writes.

Create ten original handcrafted levels teaching one concept at a time, with expected good/bad action sequences. Acceptance: I can build a level without editing source code, playtest it, save/reopen it and replay the recorded solution. Stop at the prototype gate and list any fairness/physics issues before expanding.
```

## Prompt 09: Fans and directional forces

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add fans as bounded directional force regions affecting eligible materials during fixed physics steps. They are fixed on/off per level initially, not timing challenges. Show the affected region clearly through subtle wind effects and a developer overlay. Cap acceleration/speed where needed and document material responses.

Implement three handcrafted levels teaching lateral transport and separation. Avoid very narrow landing windows or unstable balances. Add fan parameters to the schema/editor with validated ranges. Acceptance: force rules are shared by live and replay simulation, pause freezes the simulation, and known solutions remain reliable across repeated runs. Mark fans unsupported by the future logical generator until explicitly modelled and tested.
```

## Prompt 10: Portals without loops or duplication

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add paired portals with stable pair IDs and explicit eligible-material rules. Transform position and velocity using the portals' local orientations. Apply physics-safe teleportation, exit clearance checks and per-body cooldown/exit tracking so an object cannot instantly ping-pong or duplicate. Handle blocked exits gracefully; no silent object loss.

Show portal pair identity with shape/markings as well as colour. Add schema/editor support and three handcrafted teaching levels. Test multiple bodies arriving together, restart while teleporting and simultaneous goal contact. Acceptance: every body retains its ID/accounting, exit motion is predictable and portal loops are bounded. Keep procedural generation for portals disabled until its model and validator support them.
```

## Prompt 11: Rescue objectives and mechanical progress

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add an original rescue objective: collected power cores/tokens operate a lift that raises the helper automaton to safety. Use a clear progress gauge driven by collection totals and explicit thresholds. Initially animate the lift as presentation rather than simulating floating platforms or water. The interface must not imply a fluid system that does not exist.

Add an alternate fuel-the-heater objective using an allowed material type, with hazard exclusion. Reuse existing collectors and rules rather than duplicating the simulation. Include editor configuration and teaching levels. Acceptance: rescue success requires the correct totals and no disqualifying event; animation cannot finish a failed level; skip/reduced-motion options preserve results. Defer genuine fluid physics and timing-dependent moving obstacles.
```

## Prompt 12: Campaign, progression and safe saves

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Create a handcrafted campaign structure with chapter/level selection, completed markers, unlock rules and optional best move count. No lives or wait timers. Instant retry is always available. Keep campaign content IDs stable when inserting future levels. Do not use list positions as persistent identity.

Save progress/settings to user:// using versioned validated data, a safe temporary-write/replacement strategy and a recoverable backup. Handle missing/corrupt files without erasing valid backups. Persist accessibility/audio/display settings separately from authored level data. Define future migration rules.

Acceptance: progression survives restart, failed attempts do not unlock levels accidentally, duplicate win callbacks cannot award twice, and corrupt latest saves recover safely. Make Reset Progress explicit and confirm it in the actual UI.
```

## Prompt 13: Hints and solution replay

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Use recorded handcrafted solutions to provide optional next-pin hints after restart or when a verified continuation exists. Hints must depend on the current state; never show a stale pin from the original solution after a different action sequence. If no verified continuation exists, offer restart with a hint rather than guessing.

Create replay actions as pin IDs plus the turn/settling policy, not wall-clock input timestamps. Support developer solution playback through the same action interface as a player. Define version compatibility and record simulation version with results. No rewind/undo of a running physics world in version 1; restart is the supported recovery.

Acceptance: hints respect current available actions, solution playback respects settling and illegal actions fail clearly. Record visible replays for failed tests where practical. Hint availability must not be necessary to win any level.
```

## Prompt 14: Level-design pass and a small campaign

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Expand the original handcrafted campaign to 30 carefully tested levels as a first content target, using the editor and reusable puzzle families. Include tutorials, combined concepts and several genuine multi-step decisions. Do not inflate counts through recolouring or trivial mirroring. We can expand to 60–80 only after the initial campaign is enjoyable.

For each level record the intended insight, prerequisites, required action count, solution, at least one meaningful wrong action, supported mechanics and expected completion time estimate. Require repeatable outcomes, not a single lucky solution run. Build a review grid of thumbnails and metadata.

Acceptance: every level has a physically replayed solution and meaningful design notes; duplicate structures are flagged; later levels introduce reasoning rather than just more pins. Identify levels that need human playtesting; no automated difficulty score substitutes for it.
```

## Prompt 15: Sound, usability and accessibility

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add satisfying pin, token, collection and machine sounds using original synthesis or properly licensed local assets; document provenance. Limit simultaneous voices to avoid harsh pile noise. Provide master/music/effects controls and persistent mute. No external audio services at runtime.

Finish pause, help, hints, restart and chapter navigation. Support large click/touch areas, readable text, clear disabled states, keyboard focus, reduced motion and colour-independent material markers. Test landscape resize, fullscreen/windowed mode and Windows display scaling. Pause/focus-loss policies must freeze physics/action acceptance coherently and cancel dragging safely.

Acceptance: the main workflow is usable without precise clicking or audio, modal controls do not pull pins behind them, and pause/restart during any animation leaves no stale callback or extra progression award.
```

## Prompt 16: Physics robustness and repeatable test harness

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Implement or finish a headless replay harness that instantiates the actual gameplay simulation, executes actions through the same interface, advances real fixed physics ticks and reports results with nonzero exit on failure. Visual/audio work may be disabled but collision shapes, spawn ordering, rules and physics settings must match release gameplay.

Run all known solutions repeatedly, including controlled small variations of valid spawn positions, release delays and physics-relevant parameters within documented playable tolerances. Keep perturbed spawns non-overlapping and geometry valid. Test varied render rates in the visible game without changing the fixed-tick rules. Record engine/build/config versions, seeds, action traces, thresholds and failures. Do not claim deterministic physics across devices.

Acceptance: unstable levels are rejected or fixed in geometry; known bad sequences still fail for intended reasons. Profile bodies, memory and frame times on stated hardware. Do not hide failures by changing required collection counts. Maintain a reproducible regression corpus.
```

## Prompt 17: Windows export and handcrafted release gate

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Create reproducible Windows x64 exports with matching Godot export templates and original app icon/branding placeholders. Bundle required assets/fonts/sounds and include relevant engine/dependency/asset licenses. Keep saves in user://, not the installation directory. Do not fake code-signing or add secrets to the repository.

Test the actual exported executable on Windows without the editor, source tree or internet: campaign, restart, pause, saving, corrupted-save recovery, hints, all mechanics and display scaling. Include a clean account/machine test. A headless import or cross-export is not proof of Windows usability; mark unavailable checks BLOCKED with exact manual steps.

Prepare a feature-complete checklist for the handcrafted game. Document release blockers and stop. Procedural generation is a later phase and must not destabilize this working baseline.
```

## Prompt 18: Define the procedural subset and puzzle graph

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Begin the optional generation phase without changing the working handcrafted campaign. Define generator-supported mechanics as static chambers/channels, one-use pins, tokens, scrap, hazard cores, protected collectors and disposal zones. Explicitly exclude fans, portals, dynamic mechanisms and rescue variants until implemented in both model and validation.

Create a discrete puzzle graph describing compartments, gates, permitted transfers, material types and goal/hazard rules. Restrict generated geometry so discrete transitions correspond to clear gravity-fed routes. Define actions as pull one pin and wait for settling. Store graph-to-physical-object mappings with stable IDs. Do not try to model unrestricted rigid-body motion symbolically.

Document the model's assumptions and failure modes. Acceptance: several handcrafted basic puzzles map to logical states with expected good/bad sequences; unsupported mechanics are rejected rather than silently ignored. Preserve separate layout, content and simulation versions.
```

## Prompt 19: Seeded template generation

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Implement a pure seeded generator producing LevelDefinitions from tested original puzzle families: isolate hazard, drain scrap first, divert flow, merge safe streams and choose safe outlet. Use a documented PRNG/version so output data is reproducible. No runtime LLM/API calls or server required.

Each template defines a logical graph, safe physical geometry ranges, minimum clearances, gate locations, spawn rules, allowed material counts and intended decision structure. Geometry may vary within validated bounds; changes must affect genuine layout/decisions rather than only colour. Validate pin withdrawal paths and non-overlapping object spawns.

Provide a developer command to generate candidates by seed/difficulty, showing rejection reasons. Cap attempts and work per request. Acceptance: a fixed seed/version produces the same canonical data; outputs pass schema/geometry validation; bad parameter ranges fail early. These are candidates, not approved playable puzzles yet.
```

## Prompt 20: Logical solver and meaningful-choice checks

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Build a bounded state-space solver for the supported puzzle graph with canonical state hashing, terminal predicates and legal actions. Breadth-first search is acceptable for minimum move counts; use memory/node/time budgets and explicit SOLVED, UNSOLVABLE and UNKNOWN/BUDGET_EXCEEDED results. A timeout must never count as proof of unsolvability or successful validation.

Find at least one solution and measure required actions, branching, useful wrong choices, shortest solution length and trivial bypasses. Multiple solutions are acceptable; do not require uniqueness unless explicitly requested. Reject boards already won, solved by an irrelevant single pin, or containing no meaningful decision beyond tutorials. Record solution trace and graph version.

Acceptance: small exhaustive fixtures match manually enumerated results, symmetric states deduplicate correctly and known unsolvable/timeout fixtures are distinct. A solver-approved candidate still requires real physics replay before players see it.
```

## Prompt 21: Validate generated solutions in real physics

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Connect the logical solver to the actual headless replay harness. For each candidate, instantiate its exact physical LevelDefinition and replay the proposed solution under the same turn/settling rules as live play. Compare outcomes/material accounting with the logical model and reject disagreements.

Run at least 20 validation replays per proposed accepted level, including baseline repetitions and valid small spawn/release-delay perturbations within documented tolerance bounds. Treat zero observed failures as a screening rule, not a mathematical reliability guarantee. Record all run configurations and timing. Recheck known bad choices where feasible to catch a physically trivial bypass.

Store accepted level data, solution, versions, validation summary and canonical hash. Reject stalls, leaks, jam timeouts, unbounded motion, unsupported mechanics and inconsistent outcomes. Acceptance: deliberately fragile/narrow-channel candidates are rejected; only validated entries enter the approved pool. Do not speed validation by skipping physical settling or changing physics rules.
```

## Prompt 22: Difficulty bands, quality and diversity

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add explainable provisional difficulty bands using minimum useful actions, dependency depth, branching, hazard-routing decisions and number of interacting compartments. Pin count and failure rate alone are not good measures of difficulty. Keep physical fragility as a rejection criterion, never a source of 'hard' difficulty.

Implement duplicate detection using canonical graph structure plus geometry fingerprints, recognizing trivial mirrors/recolours. Keep recent puzzle-family history so players do not receive the same idea repeatedly. Add quality rules for readable spacing, visible hazards, accessible handles and no offscreen objectives.

Generate a bounded review batch and a thumbnail/report gallery grouped by family/difficulty. Human-review representative levels and adjust scoring; flag uncalibrated bands honestly. Acceptance: diversity metrics are reported, duplicates are rejected, and tutorial/easy requests cannot accidentally include advanced unsupported mechanics.
```

## Prompt 23: Generation review tools and approved content packs

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Extend the internal editor with candidate/approved/rejected statuses, rejection reason, seed/version, logical solution, physical-validation evidence, estimated difficulty and one-click playtest/replay. Allow manual edits but invalidate prior approval/solution evidence whenever gameplay geometry or rules change. Cosmetic-only edits need not invalidate physics if that separation is enforced.

Add an offline batch pipeline: generate, validate schema/geometry, logical solve, physical replay, deduplicate, review, export a versioned approved content pack. Use hashes so validation cannot be attached to a different level accidentally. Store rejected seeds/regressions separately.

Acceptance: I can produce a content pack without hand-authoring each level, inspect representative samples and load it in the game. Invalid/tampered/version-incompatible entries never become approved by merely toggling a UI flag. Keep developer tools out of public menus unless deliberately exposed later.
```

## Prompt 24: Endless mode with bounded generation and fallback

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Add Endless mode backed initially by approved content packs. This is the safe first release of automatic content: levels are automatically produced and tested ahead of time, then selected offline during play. Label the mode accurately and do not claim a finite pool is literally unlimited unique content.

Add experimental on-device candidate generation behind a developer flag only after measuring validation cost. Do not run heavy physics mutation on an unsafe background thread; use appropriate isolated processes/simulation instances or time-sliced main-thread work, following current Godot threading rules. Bound CPU/memory, cancel jobs on exit, ignore stale results and never freeze gameplay. No candidate reaches a player without required validation.

Use a vetted fallback when attempts/time budget expire. Avoid immediate repeats and disclose when fresh unique content is unavailable rather than pretending a repeated map is new. Acceptance: exhaustion, cancellation, low-end performance and offline operation all have safe behaviour. Keep the public runtime feature disabled until packaged-device tests pass.
```

## Prompt 25: Persistence, seed sharing and generator update safety

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Persist each in-progress generated LevelDefinition, its content hash, stable object IDs and generator/template/rules versions. Restart must reload that exact starting board. Save progression and approved-pool history without regenerating old levels under a new algorithm.

If adding seed codes, include generator/template version and checksum with bounded input validation. State that replay across incompatible versions may require the saved level payload; a seed is not a permanent universal format. Keep validated authored data rather than allowing seed codes to execute code or load arbitrary resources. No online sharing service required.

Invalidate or revalidate physics approval when engine version, collision geometry, relevant rules/settings or generation logic changes. Keep old campaign files readable through explicit migrations. Acceptance: changing the generator does not change an ongoing puzzle, old codes fail clearly or use a supported version, and failed saves preserve the last valid progress.
```

## Prompt 26: Full regression and procedural stress gate

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Audit both campaign and procedural modes in the actual packaged build. Run all known handcrafted solutions and a representative accepted generated regression corpus through real physics after the final engine/configuration is fixed. Include deliberately rejected fragile/unsolvable cases to test the validator itself.

Run a bounded 500-candidate generation audit with a recorded seed range and report schema/geometry rejects, solver timeouts, unsolvable cases, physics failures, duplicates, accepted count, validation cost and difficulty distribution. Do not require 500 accepted puzzles or an arbitrary acceptance rate. Preserve failures as reproducible fixtures. If resources prevent the audit, mark it BLOCKED and provide a command to run locally.

Check visible versus headless behaviour on target Windows hardware, varied rendering frame rates, input pacing, progress recovery, restart spam and sustained sessions. Spot-check human enjoyment/clarity separately. Acceptance: no unresolved data-loss/security/core-progression failures; unsupported generated mechanics stay disabled; performance and reliability claims match recorded evidence.
```

## Prompt 27: Steam materials and release preparation

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Prepare local Steam release materials without uploading, publishing, paying fees or changing accounts. Recheck current official Steamworks documentation for store asset dimensions, build launch options, review requirements, content survey and relevant AI-assisted shipped-content disclosures. Record source URLs and access date; do not guess an App ID or assume approval.

Use original approved branding and real screenshots from the actual game. Create locally reproducible capsule/banner layouts, a short store description, feature list, trailer storyboard and system requirements grounded in tested hardware. Show the actual pin puzzles prominently. Describe campaign size and generation mode accurately; no 'infinite unique levels' or guaranteed solvability claims unsupported by evidence.

Keep AI-assisted artwork/source provenance available for accurate survey completion. Document licenses and included content. Steam Cloud, achievements and Workshop are optional later tasks, not reasons to rewrite a stable game. Acceptance: materials correspond to implemented packaged features and all account-specific actions remain clearly listed for me.
```

## Prompt 28: Final release candidate and handover

- [ ] **Completed** (prompt run, verification prompt run, result recorded in docs/PROGRESS.md)

```text
Review every product requirement and acceptance gate. Produce an implemented/verified/blocked matrix for campaign, mechanics, graphics, level editor, generation, replay validation, accessibility, persistence and Windows packaging. Check tests are actually executed by normal scripts; no mocked simulation test can stand in for real physics validation.

Build from a clean checkout/import with locked engine/addon versions. Test the exported Windows game on a clean account/machine without the editor or internet. Check included assets, licenses, data paths, default settings, all menus, save recovery, campaign completion and generated-pool exhaustion. Remove debug menus/flags and test cheats from public UI while preserving internal tooling.

Prepare README, player help, changelog, known issues, backup/recovery notes, build manifest/checksums and release/update checklist. Engine/physics updates must trigger puzzle revalidation. List exact remaining manual/account actions. Classify unresolved issues by severity; data loss, unreliable required solutions, broken save/progression and unverified Windows execution block release. Stop without publishing.
```

## Optional prompt: Resume in a new session

```text
Read CLAUDE.md and docs/DESIGN.md, docs/ARCHITECTURE.md and docs/PROGRESS.md. Inspect Git status without discarding changes. Identify the last verified stage, incomplete work, actual test evidence and blockers. Do not infer completion from filenames or a previous summary. Report the next stage and wait for my prompt before implementing.
```

## Optional prompt: Repair a failed stage

```text
Do not add features. Reproduce the last verification failure using its level ID/seed/action trace and recorded versions. Identify whether the defect is in rules, geometry, physics configuration, input sequencing, save handling or test infrastructure. Fix the root cause with minimal maintainable changes. Add a meaningful regression check and replay the affected valid and invalid solutions. Do not secretly lower objective thresholds or move collection areas to disguise the problem. Update PROGRESS and report actual results and remaining blockers.
```

## Optional prompt: Extend generation to fans or portals

```text
Extend the generator to ONE previously unsupported mechanic named in my message. First document the logical abstraction, physical preconditions and cases it cannot represent. Implement explicit solver semantics, safe geometry templates, editor support and real physics replay tests. Bound loops, velocities and solver/runtime cost. Revalidate prior generated families for regressions. Keep this mechanic disabled in public generation until a representative batch passes both logical and repeated physical validation. Do not enable all mechanics because one new example worked.
```

## Optional prompt: Improve graphics without changing puzzles

```text
Render a contact sheet and the same three reference levels before changing art. Improve shape consistency, hierarchy, materials, readable hazards, restrained animation and UI polish using original local vector/procedural assets. Preserve collision shapes, object IDs, gameplay timing and objective thresholds. Keep cosmetic RNG separate. Compare before/after using identical levels/actions and rerun solution replays to detect accidental gameplay changes. Update provenance and stop for visual review.
```

## Developer's manual smoke test

1. Play ten levels without hints and note confusion or boring/repeated decisions.
2. Repeat a known solution several times; any random failure deserves investigation.
3. Pull a deliberately wrong pin and confirm a clear, consistent failure reason.
4. Spam taps during withdrawal/settling, restart and pause; no double action or stuck state.
5. Restart while tokens collect, hazards trigger and portals transfer.
6. Resize and test 100%, 150% and 200% Windows display scaling where available.
7. Close/reopen mid-campaign and mid-generated puzzle; verify progress and exact board.
8. Simulate a corrupt latest save using disposable data; verify safe recovery.
9. Exhaust the approved generated pool and force generator timeout/cancellation.
10. Launch the exported build offline on a clean Windows account without Godot installed.

## Official documentation starting points

Use pages matching the exact installed stable engine. Recheck at implementation time.

- Godot 2D: https://docs.godotengine.org/en/stable/tutorials/2d/index.html
- Physics introduction and determinism limitations: https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
- Fixed processing: https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
- Headless commands/export: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Steam release: https://partner.steamgames.com/doc/store/releasing
- Steam content survey: https://partner.steamgames.com/doc/gettingstarted/contentsurvey

Automated generation reduces routine level authoring once its templates and validation work. It does not eliminate new puzzle-family design, human playtesting or maintenance after physics changes.
