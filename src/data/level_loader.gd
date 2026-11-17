class_name LevelLoader
extends RefCounted
## Safe loading and saving of level data files.
##
## Safety rules:
## - Only .json files inside res://levels/ (built-in content, shipped read-only) or
##   user://levels/ (imported, authored or generated content, outside the executable tree).
## - Paths are checked before any file access: no "..", no backslashes, no other roots.
## - Files are read as plain text with a size cap and parsed with the JSON class. Nothing is
##   ever passed to load(), str_to_var(), bytes_to_var() or instantiated from file contents.
## - Parsed data goes through LevelCodec (strict structure) and LevelValidator (meaning).
## Saving writes a temporary file and renames it, so a failed write never truncates an
## existing file. Further hardening (backups, recovery) arrives with the editor stage.
## Data layer: file IO only, no Node access.

const BUILTIN_ROOT: String = "res://levels/"
const USER_ROOT: String = "user://levels/"
const EXTENSION: String = ".json"


class LoadResult:
	extends RefCounted
	var definition: LevelDefinition = null
	var report: ValidationReport = ValidationReport.new()

	func is_ok() -> bool:
		return definition != null and report.is_ok()


## Parses and validates level text. `supported_sim_config_version` comes from the caller.
static func parse_text(text: String, supported_sim_config_version: int) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		result.report.add("$", "json.parse", "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return result
	return parse_variant(json.data, supported_sim_config_version)


## Parses and validates already-decoded plain data.
static func parse_variant(data: Variant, supported_sim_config_version: int) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var parsed: LevelCodec.ParseResult = LevelCodec.from_variant(data)
	result.report.merge(parsed.report)
	if not parsed.report.is_ok():
		return result
	var validation: ValidationReport = LevelValidator.validate(parsed.definition, supported_sim_config_version)
	result.report.merge(validation)
	if validation.is_ok():
		result.definition = parsed.definition
	return result


## Loads, parses and validates one level file. `path` must pass is_allowed_path().
static func load_file(path: String, supported_sim_config_version: int) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var path_problem: String = check_path(path)
	if not path_problem.is_empty():
		result.report.add("path", "path.rejected", path_problem)
		return result
	if not FileAccess.file_exists(path):
		result.report.add("path", "file.missing", "no such level file")
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.report.add("path", "file.unreadable", "cannot open file (error %d)" % FileAccess.get_open_error())
		return result
	var length: int = file.get_length()
	if length > LevelSchema.MAX_FILE_BYTES:
		result.report.add("path", "file.too_large", "file is %d bytes, at most %d allowed" % [length, LevelSchema.MAX_FILE_BYTES])
		return result
	var text: String = file.get_as_text()
	file.close()
	return parse_text(text, supported_sim_config_version)


## Validates then writes a definition under user://levels/. Returns OK or an Error.
## An invalid definition is never written. Existing files survive any failure.
static func save_file(def: LevelDefinition, path: String, supported_sim_config_version: int) -> Error:
	if not path.begins_with(USER_ROOT) or not check_path(path).is_empty():
		return ERR_INVALID_PARAMETER
	if not LevelValidator.validate(def, supported_sim_config_version).is_ok():
		return ERR_INVALID_DATA
	var make_dir: Error = DirAccess.make_dir_recursive_absolute(USER_ROOT)
	if make_dir != OK:
		return make_dir
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(LevelCodec.to_json_text(def))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return write_error
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
	return rename_error


## Returns an empty string if `path` may be read as level data, otherwise the reason.
static func check_path(path: String) -> String:
	var root: String = ""
	if path.begins_with(BUILTIN_ROOT):
		root = BUILTIN_ROOT
	elif path.begins_with(USER_ROOT):
		root = USER_ROOT
	else:
		return "level files must be inside %s or %s" % [BUILTIN_ROOT, USER_ROOT]
	if path.contains("\\") or path.contains(".."):
		return "path may not contain backslashes or '..'"
	var relative: String = path.substr(root.length())
	if relative.is_empty() or relative.contains("/"):
		return "level files must sit directly in the levels folder"
	if not (relative.ends_with(EXTENSION) or relative.ends_with(EXTENSION + ".tmp")):
		return "only %s files are accepted" % EXTENSION
	for index: int in relative.length():
		var code: int = relative.unicode_at(index)
		var allowed: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95 or code == 46 or code == 45
		if not allowed:
			return "file names may only use a-z, 0-9, '_', '-' and '.'"
	return ""
