extends Control
## Entry scene. Later: run the first-boot benchmark, pick a quality tier, go to the main menu.

const PERF_SPIKE_SCENE: String = "res://scenes/spikes/perf_spike.tscn"

@onready var _label: Label = $Label
@onready var _perf_spike_button: Button = $PerfSpikeButton


func _ready() -> void:
	_perf_spike_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(PERF_SPIKE_SCENE))
	var version: String = ProjectSettings.get_setting("application/config/version") as String
	var renderer: String = RenderingServer.get_current_rendering_method()
	_label.text = "Relicbound %s\n%s renderer" % [version, renderer]
	print("Relicbound boot OK (v%s, %s, physics=%s)" % [
		version, renderer, ProjectSettings.get_setting("physics/3d/physics_engine")])
