extends SceneTree
## Measures how long the physics tick takes at different body counts. Not a test: it prints a
## table. Run with scripts\profile-physics.ps1 (headless, --fixed-fps 60 so frames do not wait
## for the clock) or with -Windowed for the real renderer.
##
## Each tick is timed from one physics_frame to the next, so the figure includes the engine's
## physics step, SimWorld's per-tick sync and the frame loop. Rendering is not included in the
## headless run; the windowed run adds it.
##
## Scenes: "pile" drops N tokens into a bowl (everything touching, worst case for contacts);
## "flow" pours N tokens through a funnel opening (tokens keep moving for a long time).

const PILE_COUNTS: Array[int] = [25, 50, 100, 150, 200, 300]
const FLOW_COUNTS: Array[int] = [24, 48, 72]
const MAX_TICKS: int = 1500
const SEEDS: Array[int] = [1, 2, 3]


func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)


## Builds an instance by hand, skipping the validator, so the profile can go past the spawn
## limit the validator enforces. Only this tool does this; the game never builds unvalidated
## instances. The scenario's own geometry is still validated (the over-limit tokens are added
## to a valid smaller level).
func _unchecked_instance(base: LevelDefinition, columns: int, target_count: int, rng: RandomNumberGenerator) -> LevelInstance:
	var instance: LevelInstance = LevelInstance.new()
	instance.definition = base
	# Continue the bowl's own grid (40 apart across, 36 apart up) for the extra tokens.
	for index: int in range(base.spawns.size(), target_count):
		var spawn: LevelDefinition.Spawn = LevelDefinition.Spawn.new()
		spawn.id = "token.%d" % (index + 1)
		spawn.position = Vector2(330.0 + float(index % columns) * 40.0, 710.0 - float(index / columns) * 36.0) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		base.spawns.append(spawn)
	for spawn: LevelDefinition.Spawn in base.spawns:
		var state: LevelInstance.MaterialState = LevelInstance.MaterialState.new()
		state.id = spawn.id
		state.kind = spawn.material
		state.position = spawn.position
		state.radius = LevelSchema.MATERIAL_RADIUS[spawn.material] as float
		instance.materials.append(state)
	return instance


func _build(definition: LevelDefinition, instance_override: LevelInstance = null) -> SimWorld:
	var instance: LevelInstance = instance_override if instance_override != null else LevelInstance.create(definition)
	if instance == null:
		printerr("RUNNER ERROR: profile scenario invalid: %s" % PhysicsScenarios.last_report.summary(3))
		return null
	var world: SimWorld = SimWorld.new()
	var tuning: SimTuning = SimTuning.new()
	# Profiling must be able to exceed the shipped limit to find the real cost curve.
	tuning.max_dynamic_bodies = 100000
	# --ccd-off compares the cost of ray CCD against none (run the tool a few times each).
	if OS.get_cmdline_user_args().has("--ccd-off"):
		tuning.token_ccd_mode = RigidBody2D.CCD_MODE_DISABLED
	if not world.build(instance, tuning):
		printerr("RUNNER ERROR: profile world failed: %s" % ", ".join(world.build_problems))
		return null
	root.add_child(world)
	return world


## Steps until every token sleeps (or MAX_TICKS) and returns per-tick microseconds while awake.
func _measure(world: SimWorld) -> Dictionary:
	var samples: PackedFloat64Array = PackedFloat64Array()
	var last: int = Time.get_ticks_usec()
	var asleep_after: int = -1
	for tick: int in MAX_TICKS:
		await physics_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - last))
		last = now
		if world.all_tokens_asleep():
			asleep_after = tick
			break
	var sorted: PackedFloat64Array = samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in samples:
		total += value
	return {
		"ticks": samples.size(),
		"asleep_after": asleep_after,
		"mean_us": total / float(maxi(1, samples.size())),
		"p95_us": sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))],
		"max_us": sorted[sorted.size() - 1],
		"outside": world.tokens_outside_board(0.0).size(),
	}


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var windowed: bool = DisplayServer.get_name() != "headless"
	print("Physics tick cost, %s, engine %s, %d seeds per row" % ["windowed" if windowed else "headless", Engine.get_version_info()["string"], SEEDS.size()])
	print("(microseconds per tick while any token is awake; 16667 us is the whole 60 Hz budget)")
	print("")
	print("%-6s %6s %9s %9s %9s %9s %12s %8s" % ["scene", "tokens", "mean_us", "p95_us", "max_us", "ticks", "asleep_after", "outside"])
	var failed: bool = false
	if not args.has("--flow-only"):
		for count: int in PILE_COUNTS:
			failed = not await _row("pile", count) or failed
	if not args.has("--pile-only"):
		for count: int in FLOW_COUNTS:
			failed = not await _row("flow", count) or failed
	quit(1 if failed else 0)


func _row(scene: String, count: int) -> bool:
	var means: float = 0.0
	var p95: float = 0.0
	var worst: float = 0.0
	var ticks: int = 0
	var asleep: int = 0
	var outside: int = 0
	for seed_value: int in SEEDS:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var definition: LevelDefinition = null
		var forced: LevelInstance = null
		if scene == "pile":
			# Wider block for large counts so the pile is a realistic height.
			var columns: int = clampi(count / 6, 14, 40)
			definition = PhysicsScenarios.bowl(mini(count, LevelSchema.MAX_SPAWNS), 2.0, rng, columns)
			if count > LevelSchema.MAX_SPAWNS and definition != null:
				forced = _unchecked_instance(definition, columns, count, rng)
		else:
			definition = PhysicsScenarios.funnel(4.0 * PhysicsScenarios.TOKEN_DIAMETER, count, 3.0, rng)
		var world: SimWorld = _build(definition, forced)
		if world == null:
			return false
		var result: Dictionary = await _measure(world)
		means += result["mean_us"] as float
		p95 = maxf(p95, result["p95_us"] as float)
		worst = maxf(worst, result["max_us"] as float)
		ticks += result["ticks"] as int
		asleep = maxi(asleep, result["asleep_after"] as int)
		outside += result["outside"] as int
		root.remove_child(world)
		world.free()
		await physics_frame
	print("%-6s %6d %9.0f %9.0f %9.0f %9d %12s %8d" % [scene, count, means / float(SEEDS.size()), p95, worst, ticks / SEEDS.size(), str(asleep) if asleep >= 0 else "never", outside])
	return true
