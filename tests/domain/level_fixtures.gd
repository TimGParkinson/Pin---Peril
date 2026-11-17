class_name LevelFixtures
extends RefCounted
## Shared test data: a small valid level (as plain JSON-style data) that uses every schema
## feature, plus helpers to reach into it. Tests mutate a fresh copy to build malformed
## data, which is exactly what a damaged or hostile file looks like to the loader.
## Every call returns brand new objects, so tests cannot affect each other.


static func minimal() -> Dictionary:
	return {
		"schema_version": 1,
		"level_id": "test.minimal",
		"title": "Minimal Test Level",
		"sim_config_version": SimConfig.CONFIG_VERSION,
		"meta": {"author": "Test Author", "created": "2026-01-01", "source": "handcrafted", "notes": ""},
		"design_size": [1000, 700],
		"allowed_mechanics": ["pins", "scrap", "hazard_cores", "disposal_zones", "hazard_zones"],
		"walls": [
			{"id": "wall.floor", "kind": "polyline", "thickness": 24, "points": [[100, 640], [900, 640]]},
			{"id": "wall.left", "kind": "polyline", "thickness": 24, "points": [[100, 100], [100, 640]]},
			{"id": "wall.right", "kind": "polyline", "thickness": 24, "points": [[900, 100], [900, 640]]},
			{"id": "wall.block", "kind": "polygon", "points": [[400, 300], [500, 300], [500, 380], [400, 380]]},
		],
		"pins": [
			{"id": "pin.one", "tip": [300, 200], "handle": [60, 200], "thickness": 16, "pull_direction": [-1, 0], "pull_distance": 240},
			{"id": "pin.two", "tip": [700, 200], "handle": [940, 200], "thickness": 16, "pull_direction": [1, 0], "pull_distance": 240},
		],
		"spawns": [
			{"id": "token.1", "material": "token", "position": [200, 160]},
			{"id": "token.2", "material": "token", "position": [240, 160]},
			{"id": "token.3", "material": "token", "position": [280, 160]},
			{"id": "scrap.1", "material": "scrap", "position": [720, 160]},
			{"id": "core.1", "material": "core", "position": [760, 160]},
		],
		"goals": [
			{"id": "goal.collector", "kind": "collector", "rect": [150, 560, 200, 70], "accepts": ["token"], "protected": true},
			{"id": "goal.disposal", "kind": "disposal", "rect": [650, 560, 200, 70], "accepts": ["scrap", "core"], "protected": false},
		],
		"hazards": [
			{"id": "hazard.pit", "kind": "destroy_zone", "rect": [450, 560, 100, 70], "affects": ["core"]},
		],
		"objective": {
			"required_tokens": 3,
			"allowed_token_losses": 0,
			"collector_ids": ["goal.collector"],
			"fail_conditions": ["scrap_in_protected", "core_in_protected"],
		},
		"known_sequences": [
			{"id": "seq.good", "actions": ["pin.one"], "expected_result": "won"},
			{"id": "seq.bad", "actions": ["pin.two", "pin.one"], "expected_result": "lost"},
		],
	}


## Parses and validates plain data exactly as the game would.
static func check(data: Variant) -> LevelLoader.LoadResult:
	return LevelLoader.parse_variant(data, SimConfig.CONFIG_VERSION)


## The minimal level as a definition. Fails the calling test if it does not load.
static func minimal_definition() -> LevelDefinition:
	return check(minimal()).definition


static func wall(data: Dictionary, index: int) -> Dictionary:
	return (data["walls"] as Array)[index] as Dictionary


static func pin(data: Dictionary, index: int) -> Dictionary:
	return (data["pins"] as Array)[index] as Dictionary


static func spawn(data: Dictionary, index: int) -> Dictionary:
	return (data["spawns"] as Array)[index] as Dictionary


static func goal(data: Dictionary, index: int) -> Dictionary:
	return (data["goals"] as Array)[index] as Dictionary


static func hazard(data: Dictionary, index: int) -> Dictionary:
	return (data["hazards"] as Array)[index] as Dictionary


static func sequence(data: Dictionary, index: int) -> Dictionary:
	return (data["known_sequences"] as Array)[index] as Dictionary


static func objective(data: Dictionary) -> Dictionary:
	return data["objective"] as Dictionary
