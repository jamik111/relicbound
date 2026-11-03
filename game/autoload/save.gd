extends Node
## Local progress save (user://save.json). The local file is the source of truth;
## cloud sync adapters in platform/ come later.

const PATH: String = "user://save.json"
const VERSION: int = 1

var data: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	data = _default_data()
	if not FileAccess.file_exists(PATH):
		return
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		data.merge(parsed as Dictionary, true)


func write_save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save: cannot open %s (%d)" % [PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))


func _default_data() -> Dictionary:
	return {
		"version": VERSION,
		"levels": {},
		"relics": [],
	}
