extends Node
## Local progress save (user://save.json). The local file is the source of truth;
## cloud sync adapters in platform/ come later.

const PATH: String = "user://save.json"
const VERSION: int = 1
## Forgets wipe a level's scars. They're earned by winning, never by waiting or paying (BRD: no energy systems).
const STARTING_FORGETS: int = 1
const MAX_FORGETS: int = 3

## A variable so tests can point it away from the real save.
var path: String = PATH
var data: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	data = _default_data()
	if not FileAccess.file_exists(path):
		return
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		data.merge(parsed as Dictionary, true)


func write_save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Save: cannot open %s (%d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))


## Cell indices of a level's scars, oldest first.
func scars_of(level: String) -> PackedInt32Array:
	return PackedInt32Array((data["scars"] as Dictionary).get(level, []) as Array)


func set_scars(level: String, cells: PackedInt32Array) -> void:
	var scars: Dictionary = data["scars"]
	if cells.is_empty():
		scars.erase(level)
	else:
		scars[level] = Array(cells)
	write_save()


## The idol save of a level that remembers: {"state": SimState.to_dict(), "rewinds": int}. Empty if there's none.
func idol_save_of(level: String) -> Dictionary:
	return (data["idol_saves"] as Dictionary).get(level, {}) as Dictionary


func set_idol_save(level: String, state: Dictionary, rewinds: int) -> void:
	(data["idol_saves"] as Dictionary)[level] = {"state": state, "rewinds": rewinds}
	write_save()


## Everything a level remembers: its scars and its idol save.
func clear_memory(level: String) -> void:
	(data["scars"] as Dictionary).erase(level)
	(data["idol_saves"] as Dictionary).erase(level)
	write_save()


## Chambers solved at least once: they open the temple's next door.
func solved_levels() -> Dictionary:
	return data.get("levels", {}) as Dictionary


func is_solved(level: String) -> bool:
	return solved_levels().has(level)


func mark_solved(level: String) -> void:
	if not data.has("levels"):
		data["levels"] = {}
	(data["levels"] as Dictionary)[level] = {"solved": true}
	write_save()


func forgets() -> int:
	return int(data["forgets"])


func earn_forget() -> void:
	data["forgets"] = mini(forgets() + 1, MAX_FORGETS)
	write_save()


## Returns false if none are left.
func spend_forget() -> bool:
	if forgets() <= 0:
		return false
	data["forgets"] = forgets() - 1
	write_save()
	return true


func _default_data() -> Dictionary:
	return {
		"version": VERSION,
		"levels": {},
		"relics": [],
		"scars": {},
		"idol_saves": {},
		"forgets": STARTING_FORGETS,
	}
