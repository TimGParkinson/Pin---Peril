class_name PhysicsTestCase
extends TestCase
## Base for physics tests. Builds a real SimWorld in the real scene tree and advances the
## engine's own fixed physics ticks. No mocks: every claim is about what the physics step did.
##
## Run through scripts/test-physics.ps1, which passes --fixed-fps 60 so each frame advances
## exactly one tick without waiting for the wall clock (otherwise 1000 ticks take 17 seconds).

## Worlds created by the current test; freed in after_each even if the test fails.
var _worlds: Array[SimWorld] = []


func after_each() -> void:
	for world: SimWorld in _worlds:
		if is_instance_valid(world):
			tree.root.remove_child(world)
			world.free()
	_worlds.clear()
	await tree.physics_frame


## Builds a world for `definition` and adds it to the tree. Returns null (and fails the test) if
## the definition does not validate or the world refuses to build.
func make_world(definition: LevelDefinition, tuning: SimTuning = null) -> SimWorld:
	assert_not_null(definition, "scenario definition is valid")
	if definition == null:
		return null
	var report: ValidationReport = ValidationReport.new()
	var instance: LevelInstance = LevelInstance.create(definition, report)
	assert_not_null(instance, report.summary())
	if instance == null:
		return null
	var world: SimWorld = SimWorld.new()
	var built: bool = world.build(instance, tuning)
	assert_true(built, "world builds: %s" % ", ".join(world.build_problems))
	if not built:
		world.free()
		return null
	tree.root.add_child(world)
	_worlds.append(world)
	return world


## Frees a world now and waits one tick so the physics server has dropped its bodies.
func discard_world(world: SimWorld) -> void:
	_worlds.erase(world)
	tree.root.remove_child(world)
	world.free()
	await tree.physics_frame


## Advances `ticks` fixed physics ticks.
func step(ticks: int) -> void:
	for _i: int in ticks:
		await tree.physics_frame


## Advances until `done` returns true or `max_ticks` have passed. Returns the ticks used, or -1
## if the limit was reached first.
func step_until(max_ticks: int, done: Callable) -> int:
	for used: int in max_ticks:
		if done.call() as bool:
			return used
		await tree.physics_frame
	return -1 if not (done.call() as bool) else max_ticks
