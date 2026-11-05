extends GutTest
## Task 1.6: golden replays. Each file in res://tests/replays/ must reproduce its recorded final hash.
## If a rule change is intended, re-record with tests/replays/record_replay.gd and review the diff.

const REPLAYS: String = "res://tests/replays/"


func test_input_encoding_round_trip() -> void:
	var intents := PackedInt32Array([0, 1, 2, 3, 4, 4])
	assert_eq(Replay.encode_inputs(intents), ".UDLRR")
	assert_eq(Replay.parse_inputs(".U D\nL RR"), intents)


## A solution has to be playable by a person, so it can't walk faster than Game's walking cadence.
func _walks_too_fast(inputs: String) -> bool:
	var compact: String = inputs.replace(" ", "")
	for i: int in range(1, compact.length()):
		if "UDLR".contains(compact[i]) and "UDLR".contains(compact[i - 1]):
			return true
	return false


func test_every_greybox_level_has_a_solution_at_walking_speed() -> void:
	var levels: PackedStringArray = LevelLoader.levels_in("res://levels/greybox/")
	assert_eq(levels.size(), 9)
	var solved: Dictionary = {}
	for f: String in DirAccess.get_files_at(REPLAYS):
		if f.ends_with(".json"):
			var replay: Dictionary = LevelLoader.load_data(REPLAYS + f)
			solved[replay["level"]] = replay
	for level: String in levels:
		assert_true(solved.has(level), "%s has no solution replay" % level)
		if solved.has(level):
			var replay: Dictionary = solved[level]
			assert_false(_walks_too_fast(replay["inputs"] as String), "%s solution outruns the walking speed" % level)
			assert_true(bool((replay["expect"] as Dictionary)["won"]), level)


func test_level_order() -> void:
	var levels: PackedStringArray = LevelLoader.levels_in("res://levels/greybox/")
	assert_eq(LevelLoader.next_level(levels[0]), levels[1])
	assert_eq(LevelLoader.next_level(levels[levels.size() - 1]), "")


func test_golden_replays() -> void:
	var count: int = 0
	for f: String in DirAccess.get_files_at(REPLAYS):
		if not f.ends_with(".json"):
			continue
		count += 1
		var replay: Dictionary = LevelLoader.load_data(REPLAYS + f)
		var start: SimState = LevelLoader.load_state(replay["level"] as String)
		assert_not_null(start, f)
		if start == null:
			continue
		var final_state: SimState = Replay.run(start, replay["inputs"] as String)
		var expect: Dictionary = replay.get("expect", {}) as Dictionary
		for key: String in expect:
			var expected: Variant = expect[key]
			if expected is float:
				expected = int(expected)  # JSON numbers parse as float; sim fields are ints
			assert_eq(final_state.get(key), expected, "%s: %s" % [f, key])
		assert_ne(replay.get("hash", ""), "", "%s has no recorded hash" % f)
		assert_eq(final_state.hash(), replay.get("hash", ""), "%s: final hash" % f)
	assert_gt(count, 0, "no golden replays found")
