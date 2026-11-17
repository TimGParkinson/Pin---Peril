extends TestCase
## Enforces the documented layer rules (docs/ARCHITECTURE.md) on the source text:
## dependencies point down only (presentation -> sim -> rules -> data), and the data and rules
## layers never touch the scene tree or Nodes.

## Lower rank may not reference higher rank. A new folder under src/ must be added here so
## the rule keeps covering it; the test fails until it is.
const LAYER_RANK: Dictionary = {"data": 0, "rules": 1, "sim": 2, "presentation": 3}

## Words that mean "uses the scene tree or Nodes". Forbidden in data and rules code.
const NODE_WORDS: PackedStringArray = [
	"Node", "Node2D", "Control", "CanvasItem", "SceneTree", "get_tree", "add_child", "remove_child",
	"queue_free", "get_node", "PackedScene", "RigidBody2D", "StaticBody2D", "await",
]


func test_every_source_folder_is_classified_into_a_layer() -> void:
	var directories: PackedStringArray = DirAccess.get_directories_at("res://src")
	assert_true(directories.size() >= 4)
	for directory: String in directories:
		assert_true(LAYER_RANK.has(directory), "src/%s must be added to LAYER_RANK in this test and to ARCHITECTURE.md" % directory)


func test_no_layer_references_a_higher_layer() -> void:
	var layer_of_class: Dictionary = _classes_by_layer()
	assert_true(layer_of_class.size() >= 15, "found the project's global classes")
	var checked_files: int = 0
	for layer: String in LAYER_RANK.keys():
		for file_path: String in _scripts_in(layer):
			checked_files += 1
			var code: String = _code_only(FileAccess.get_file_as_string(file_path))
			for class_name_text: String in layer_of_class.keys():
				var other_layer: String = layer_of_class[class_name_text] as String
				if (LAYER_RANK[other_layer] as int) > (LAYER_RANK[layer] as int) and _mentions(code, class_name_text):
					fail("%s (%s layer) references %s from the %s layer" % [file_path, layer, class_name_text, other_layer])
	assert_true(checked_files >= 15, "scanned %d source files" % checked_files)


func test_data_and_rules_code_never_touch_nodes_or_the_scene_tree() -> void:
	var checked_files: int = 0
	for layer: String in ["data", "rules"]:
		for file_path: String in _scripts_in(layer):
			checked_files += 1
			var code: String = _code_only(FileAccess.get_file_as_string(file_path))
			for word: String in NODE_WORDS:
				if _mentions(code, word):
					fail("%s (%s layer) uses '%s'" % [file_path, layer, word])
	assert_true(checked_files >= 10, "scanned %d data and rules files" % checked_files)


func test_the_scanner_itself_catches_violations() -> void:
	# Guard against the checks above silently matching nothing.
	assert_true(_mentions(_code_only("var n: Node = null"), "Node"))
	assert_true(_mentions(_code_only("get_tree().quit()"), "get_tree"))
	assert_false(_mentions(_code_only("# uses a Node here"), "Node"), "comments are ignored")
	assert_false(_mentions(_code_only("var s := \"Node\""), "Node"), "string contents are ignored")
	assert_false(_mentions(_code_only("var x: Node2DThing = null"), "Node2D"), "whole words only")
	assert_eq(_classes_by_layer().get("LevelCodec"), "data")
	assert_eq(_classes_by_layer().get("LevelInstance"), "sim")
	assert_eq(_classes_by_layer().get("LevelEvent"), "rules")
	assert_eq(_classes_by_layer().get("BoardView"), "presentation")


func _classes_by_layer() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = entry["path"] as String
		for layer: String in LAYER_RANK.keys():
			if path.begins_with("res://src/%s/" % layer):
				result[entry["class"] as String] = layer
	return result


func _scripts_in(layer: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at("res://src/%s" % layer):
		if file_name.ends_with(".gd"):
			result.append("res://src/%s/%s" % [layer, file_name])
	return result


## Source with comments and string contents removed.
func _code_only(source: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		var kept: String = ""
		var quote: String = ""
		for index: int in line.length():
			var character: String = line[index]
			if quote.is_empty():
				if character == "#":
					break
				if character == "\"" or character == "'":
					quote = character
				else:
					kept += character
			elif character == quote and (index == 0 or line[index - 1] != "\\"):
				quote = ""
		lines.append(kept)
	return "\n".join(lines)


## Whole-word match, so Node does not match Node2D or LevelNode.
func _mentions(code: String, word: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % word)
	return regex.search(code) != null
