class_name LevelLibrary
extends RefCounted
## Finds and loads levels by id, using the simulation version this build supports.
##
## Built-in levels live in res://levels/<level_id>.json and ship read-only. Imported,
## authored or generated levels live in user://levels/<level_id>.json. The file name must
## equal the level id inside the file, so ids cannot be spoofed by renaming a file.

const DEFAULT_LEVEL_ID: String = "workshop.three_pins"


static func load_builtin(level_id: String) -> LevelLoader.LoadResult:
	return _load(LevelLoader.BUILTIN_ROOT, level_id)


static func load_user(level_id: String) -> LevelLoader.LoadResult:
	return _load(LevelLoader.USER_ROOT, level_id)


## Ids of all built-in levels, sorted. Reads file names only.
static func list_builtin_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(LevelLoader.BUILTIN_ROOT):
		if file_name.ends_with(LevelLoader.EXTENSION):
			ids.append(file_name.trim_suffix(LevelLoader.EXTENSION))
	ids.sort()
	return ids


static func _load(root: String, level_id: String) -> LevelLoader.LoadResult:
	if not LevelSchema.is_valid_id(level_id):
		var rejected: LevelLoader.LoadResult = LevelLoader.LoadResult.new()
		rejected.report.add("level_id", "id.invalid", "invalid level id")
		return rejected
	var result: LevelLoader.LoadResult = LevelLoader.load_file(root + level_id + LevelLoader.EXTENSION, SimConfig.CONFIG_VERSION)
	if result.is_ok() and result.definition.level_id != level_id:
		result.report.add("level_id", "id.file_mismatch", "file is named '%s' but contains level '%s'" % [level_id, result.definition.level_id])
		result.definition = null
	return result
