class_name ValidationReport
extends RefCounted
## Collects problems found while parsing or validating level data.
##
## Each issue has a machine-readable code (tests and tools match on it), a location path
## such as "pins[1].tip", and a human-readable message. The report is capped so a hostile
## file cannot create unbounded output.

class Issue:
	extends RefCounted
	var path: String = ""
	var code: String = ""
	var message: String = ""

	func _to_string() -> String:
		return "%s [%s] %s" % [path, code, message]


var issues: Array[Issue] = []

## True if more issues were found than are stored.
var truncated: bool = false


func add(path: String, code: String, message: String) -> void:
	if issues.size() >= LevelSchema.MAX_REPORT_ISSUES:
		truncated = true
		return
	var issue: Issue = Issue.new()
	issue.path = path
	issue.code = code
	issue.message = message
	issues.append(issue)


func is_ok() -> bool:
	return issues.is_empty()


func has_code(code: String) -> bool:
	for issue: Issue in issues:
		if issue.code == code:
			return true
	return false


func codes() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for issue: Issue in issues:
		if not result.has(issue.code):
			result.append(issue.code)
	return result


## Issue paths for one code, for assertions about where a problem was reported.
func paths_for(code: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for issue: Issue in issues:
		if issue.code == code:
			result.append(issue.path)
	return result


func merge(other: ValidationReport) -> void:
	for issue: Issue in other.issues:
		add(issue.path, issue.code, issue.message)
	if other.truncated:
		truncated = true


## Multi-line summary for logs and on-screen error text.
func summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for issue: Issue in issues:
		lines.append(str(issue))
	if truncated:
		lines.append("(more issues not shown)")
	return "\n".join(lines)
