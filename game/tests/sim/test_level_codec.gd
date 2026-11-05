extends GutTest
## Task 1.5: level format.

const TEST_LEVELS: String = "res://levels/test/"


func _parse(data: Dictionary) -> Array:
	var errors := PackedStringArray()
	var s: SimState = LevelCodec.parse(data, errors)
	return [s, errors]


func _level(terrain: Array, objects: Array, meta: Dictionary = {}) -> Dictionary:
	return {"size": [(terrain[0] as String).length(), terrain.size()], "meta": meta,
		"layers": {"terrain": terrain, "objects": objects}}


func test_parses_layers_player_and_objects() -> void:
	var out: Array = _parse(_level(["#####", "#.:E#", "#####"], [".....", ".@...", "....."]))
	var s: SimState = out[0]
	assert_eq((out[1] as PackedStringArray).size(), 0)
	assert_eq(s.width, 5)
	assert_eq(s.height, 3)
	assert_eq(s.player, Vector2i(1, 1))
	assert_eq(s.terrain_at(Vector2i(2, 1)), Tiles.Terrain.DIRT)
	assert_eq(s.terrain_at(Vector2i(3, 1)), Tiles.Terrain.EXIT)


func test_object_ids_assigned_row_major() -> void:
	var s: SimState = _parse(_level(["....", "...."], ["O*..", "X.@."]))[0]
	assert_eq(s.ids[s.idx(Vector2i(0, 0))], 1)
	assert_eq(s.ids[s.idx(Vector2i(1, 0))], 2)
	assert_eq(s.ids[s.idx(Vector2i(0, 1))], 3)
	assert_eq(s.next_id, 4)


func test_error_wrong_row_length() -> void:
	var out: Array = _parse(_level(["#####", "#.#", "#####"], [".....", ".@...", "....."]))
	assert_null(out[0])
	assert_gt((out[1] as PackedStringArray).size(), 0)


func test_error_player_count() -> void:
	assert_null(_parse(_level(["...."], ["...."]))[0])
	assert_null(_parse(_level(["...."], ["@.@."]))[0])


func test_error_unknown_char() -> void:
	assert_null(_parse(_level(["..?."], ["@..."]))[0])
	assert_null(_parse(_level(["...."], ["@.?."]))[0])


func test_error_object_not_on_floor() -> void:
	assert_null(_parse(_level(["..#."], ["@.O."]))[0])


func test_combined_map_round_trip() -> void:
	var data: Dictionary = LevelCodec.from_combined(["#####", "#@O*#", "#####"])
	var layers: Dictionary = data["layers"]
	assert_eq((layers["terrain"] as Array)[1], "#...#")
	assert_eq((layers["objects"] as Array)[1], ".@O*.")


func test_all_test_rooms_load() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(TEST_LEVELS)
	var count: int = 0
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		count += 1
		var errors := PackedStringArray()
		var s: SimState = LevelCodec.parse(LevelLoader.load_data(TEST_LEVELS + f), errors)
		assert_not_null(s, "%s: %s" % [f, errors])
	assert_eq(count, 6)
