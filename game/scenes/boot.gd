extends Control
## Entry scene. For the grey-box phase it's a launcher: one button per level, plus the perf spike.
## Later: run the first-boot benchmark, pick a quality tier, go to the main menu.

const LEVEL_SCENE: String = "res://scenes/level.tscn"
const LEVEL_DIRS: Array[String] = ["res://levels/greybox/", "res://levels/test/"]
const PERF_SPIKE_SCENE: String = "res://scenes/spikes/perf_spike.tscn"

@onready var _label: Label = $Label
@onready var _menu: GridContainer = %Menu


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version") as String
	var renderer: String = RenderingServer.get_current_rendering_method()
	_label.text = "Twicefall %s  ·  %s renderer" % [version, renderer]
	print("Twicefall boot OK (v%s, %s, physics=%s)" % [
		version, renderer, ProjectSettings.get_setting("physics/3d/physics_engine")])

	for dir: String in LEVEL_DIRS:
		for path: String in LevelLoader.levels_in(dir):
			var data: Dictionary = LevelLoader.load_data(path)
			var meta: Dictionary = data.get("meta", {}) as Dictionary
			_add_button(str(meta.get("name", path.get_file().get_basename())), _play.bind(path))
	_add_button("Perf spike", func() -> void: get_tree().change_scene_to_file(PERF_SPIKE_SCENE))

	if OS.is_debug_build() and preload("res://scenes/spikes/perf_spike.gd").autostart_requested():
		get_tree().change_scene_to_file.call_deferred(PERF_SPIKE_SCENE)


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 80)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(on_pressed)
	_menu.add_child(button)


func _play(path: String) -> void:
	Game.level_path = path
	get_tree().change_scene_to_file(LEVEL_SCENE)
