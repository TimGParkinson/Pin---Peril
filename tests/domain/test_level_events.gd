extends TestCase
## The event vocabulary and the one-shot rules of EventLog.


func test_every_event_type_has_a_distinct_readable_name() -> void:
	var names: Dictionary = {}
	for type: int in LevelEvent.Type.values():
		var event_name: String = LevelEvent.type_name(type as LevelEvent.Type)
		assert_false(event_name.is_empty())
		assert_false(names.has(event_name), "name %s is unique" % event_name)
		names[event_name] = true
	assert_eq(names.size(), 9)
	assert_true(names.has("action_requested") and names.has("action_accepted") and names.has("action_rejected"))
	assert_true(names.has("material_collected") and names.has("material_lost") and names.has("material_destroyed"))
	assert_true(names.has("level_won") and names.has("level_lost") and names.has("level_jammed"))


func test_factories_fill_the_expected_fields() -> void:
	var requested: LevelEvent = LevelEvent.action_requested(12, "pin.a")
	assert_eq(requested.type, LevelEvent.Type.ACTION_REQUESTED)
	assert_eq(requested.tick, 12)
	assert_eq(requested.subject_id, "pin.a")
	var rejected: LevelEvent = LevelEvent.action_rejected(13, "pin.a", "board_settling")
	assert_eq(rejected.detail, "board_settling")
	var collected: LevelEvent = LevelEvent.material_collected(40, "token.1", "goal.collector")
	assert_eq(collected.subject_id, "token.1")
	assert_eq(collected.detail, "goal.collector")
	assert_eq(LevelEvent.material_lost(41, "token.2", "out_of_bounds").detail, "out_of_bounds")
	assert_eq(LevelEvent.material_destroyed(42, "core.1", "hazard.pit").detail, "hazard.pit")
	var won: LevelEvent = LevelEvent.level_won(90, "required_tokens_collected")
	assert_eq(won.subject_id, "")
	assert_eq(won.detail, "required_tokens_collected")


func test_classification_helpers() -> void:
	assert_true(LevelEvent.level_won(1, "").is_terminal())
	assert_true(LevelEvent.level_lost(1, "").is_terminal())
	assert_true(LevelEvent.level_jammed(1, "").is_terminal())
	assert_false(LevelEvent.action_accepted(1, "pin.a").is_terminal())
	assert_false(LevelEvent.material_collected(1, "t", "g").is_terminal())
	assert_true(LevelEvent.material_collected(1, "t", "g").is_material_resolution())
	assert_true(LevelEvent.material_lost(1, "t", "x").is_material_resolution())
	assert_true(LevelEvent.material_destroyed(1, "t", "h").is_material_resolution())
	assert_false(LevelEvent.action_requested(1, "pin.a").is_material_resolution())


func test_terminal_kind_maps_to_terminal_results() -> void:
	assert_eq(LevelEvent.level_won(1, "").terminal_kind(), TerminalResult.Kind.WON)
	assert_eq(LevelEvent.level_lost(1, "").terminal_kind(), TerminalResult.Kind.LOST)
	assert_eq(LevelEvent.level_jammed(1, "").terminal_kind(), TerminalResult.Kind.JAMMED)
	assert_eq(LevelEvent.action_requested(1, "pin.a").terminal_kind(), -1)


func test_terminal_result_names_match_the_level_schema() -> void:
	var from_enum: PackedStringArray = PackedStringArray()
	for kind: int in TerminalResult.Kind.values():
		from_enum.append(TerminalResult.to_name(kind as TerminalResult.Kind))
	assert_eq(from_enum, LevelSchema.TERMINAL_RESULTS, "rules enum and data vocabulary must agree")
	for result_name: String in LevelSchema.TERMINAL_RESULTS:
		assert_ne(TerminalResult.from_name(result_name), -1)
		assert_eq(TerminalResult.to_name(TerminalResult.from_name(result_name) as TerminalResult.Kind), result_name)
	assert_eq(TerminalResult.from_name("draw"), -1)


func test_log_assigns_a_stable_total_order() -> void:
	var log: EventLog = EventLog.new()
	assert_true(log.append(LevelEvent.action_requested(5, "pin.a")))
	assert_true(log.append(LevelEvent.action_accepted(5, "pin.a")))
	assert_true(log.append(LevelEvent.material_collected(30, "token.1", "goal.collector")))
	assert_eq(log.events.size(), 3)
	for index: int in 3:
		assert_eq(log.events[index].sequence, index)
	assert_eq(log.count_of(LevelEvent.Type.ACTION_REQUESTED), 1)
	assert_eq(log.to_dicts()[2]["type"], "material_collected")
	assert_eq(log.to_dicts()[2]["sequence"], 2)


func test_a_material_can_be_resolved_only_once() -> void:
	var log: EventLog = EventLog.new()
	assert_true(log.append(LevelEvent.material_collected(10, "token.1", "goal.collector")))
	assert_true(log.is_material_resolved("token.1"))
	assert_false(log.append(LevelEvent.material_collected(11, "token.1", "goal.collector")), "double collect")
	assert_false(log.append(LevelEvent.material_lost(12, "token.1", "out_of_bounds")), "collected then lost")
	assert_false(log.append(LevelEvent.material_destroyed(13, "token.1", "hazard.pit")), "collected then destroyed")
	assert_true(log.last_rejection.contains("token.1"))
	assert_eq(log.events.size(), 1, "rejected events are not stored")
	assert_true(log.append(LevelEvent.material_lost(14, "token.2", "out_of_bounds")), "other materials unaffected")


func test_only_one_terminal_event_and_nothing_after_it() -> void:
	var log: EventLog = EventLog.new()
	assert_false(log.has_terminal())
	assert_true(log.append(LevelEvent.level_lost(50, "scrap_in_protected")))
	assert_true(log.has_terminal())
	assert_eq(log.terminal_event().type, LevelEvent.Type.LEVEL_LOST)
	assert_false(log.append(LevelEvent.level_won(51, "late")), "a failed board can never later win")
	assert_false(log.append(LevelEvent.material_collected(52, "token.1", "goal.collector")))
	assert_false(log.append(LevelEvent.action_requested(53, "pin.a")))
	assert_eq(log.events.size(), 1)
	assert_eq(log.terminal_event().detail, "scrap_in_protected", "the first terminal result stands")


func test_log_is_bounded() -> void:
	var log: EventLog = EventLog.new()
	for index: int in EventLog.MAX_EVENTS:
		assert_true(log.append(LevelEvent.action_requested(index, "pin.a")), "event %d fits" % index)
	assert_eq(log.events.size(), EventLog.MAX_EVENTS)
	assert_false(log.append(LevelEvent.action_requested(0, "pin.a")))
	assert_eq(log.last_rejection, "event log is full")


func test_a_new_log_for_each_attempt_starts_clean() -> void:
	var first: EventLog = EventLog.new()
	first.append(LevelEvent.material_collected(1, "token.1", "goal.collector"))
	first.append(LevelEvent.level_won(2, "done"))
	var second: EventLog = EventLog.new()
	assert_false(second.has_terminal())
	assert_false(second.is_material_resolved("token.1"))
	assert_true(second.append(LevelEvent.material_collected(1, "token.1", "goal.collector")))
