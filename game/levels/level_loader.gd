class_name LevelLoader
extends RefCounted
## Reads level JSON files. The parsing itself is pure (LevelCodec); this only does the file I/O.


static func load_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("LevelLoader: no file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("LevelLoader: %s is not a JSON object" % path)
		return {}
	return parsed as Dictionary


## Returns the starting state, or null (with the problems pushed as errors).
static func load_state(path: String) -> SimState:
	var errors := PackedStringArray()
	var state: SimState = LevelCodec.parse(load_data(path), errors)
	for e: String in errors:
		push_error("LevelLoader: %s: %s" % [path, e])
	return state
