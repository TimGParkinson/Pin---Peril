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
	# Windows editors such as Notepad may prepend a UTF-8 byte order mark.
	var error: Error = json.parse(text.trim_prefix("\uFEFF"))
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
## An invalid definition is never written. Existing files survive any failure. When the
## definition is refused, `report_out` (if given) says why.
static func save_file(def: LevelDefinition, path: String, supported_sim_config_version: int, report_out: ValidationReport = null) -> Error:
	if not path.begins_with(USER_ROOT) or not check_path(path).is_empty():
		return ERR_INVALID_PARAMETER
	var text: String = to_saved_text(def, supported_sim_config_version, report_out)
	if text.is_empty():
		return ERR_INVALID_DATA
	var make_dir: Error = DirAccess.make_dir_recursive_absolute(USER_ROOT)
	if make_dir != OK:
		return make_dir
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return write_error
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
	return rename_error


## The exact text save_file would write, or "" if it would not load back as a valid level.
## Saving rounds coordinates to LevelSchema.COORD_DECIMALS, which can move a body a hair closer
## to a wall than the limit allows. About 4 percent of placements within 0.0004 of a clearance
## limit are valid in memory but invalid once rounded (measured), so the rounded text is
## validated too. Problems are added to `report_out`; a rounding-only failure gets the code
## save.rounding. A definition that was valid when loaded from a file is already rounded.
static func to_saved_text(def: LevelDefinition, supported_sim_config_version: int, report_out: ValidationReport = null) -> String:
	var before: ValidationReport = LevelValidator.validate(def, supported_sim_config_version)
	if not before.is_ok():
		if report_out != null:
			report_out.merge(before)
		return ""
	var text: String = LevelCodec.to_json_text(def)
	var after: LoadResult = parse_text(text, supported_sim_config_version)
	if not after.is_ok():
		if report_out != null:
			report_out.add("$", "save.rounding", "valid as built but not after rounding coordinates to %s; move the objects apart or away from walls by a little" % LevelSchema.COORD_DECIMALS)
			report_out.merge(after.report)
		return ""
	return text


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
	if not relative.ends_with(EXTENSION):
		return "only %s files are accepted" % EXTENSION
	for index: int in relative.length():
		var code: int = relative.unicode_at(index)
		var allowed: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95 or code == 46 or code == 45
		if not allowed:
			return "file names may only use a-z, 0-9, '_', '-' and '.'"
	return ""
