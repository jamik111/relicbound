extends Node3D
## Plays one level: asks Game to load it, and connects Game's ticks to the LevelView, camera and HUD.
## The level comes from Game.level_path if the boot screen set one, otherwise `default_level`.

const BOOT_SCENE: String = "res://scenes/boot.tscn"
const KEY_SHAPES: Array[String] = ["♦", "●", "▲", "■"]

@export_file("*.json") var default_level: String = "res://levels/test/test_05_keys_doors.json"

@onready var _view: LevelView = $LevelView
@onready var _camera: FollowCamera = $FollowCamera
@onready var _gems_label: Label = %GemsLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.06, 0.05)
	add_child(env)
	Events.level_loaded.connect(_on_level_loaded)
	Events.sim_events.connect(_on_sim_events)
	%RestartButton.pressed.connect(Game.restart)
	%BackButton.pressed.connect(_on_back)
	var path: String = Game.level_path if Game.level_path != "" else default_level
	if not Game.load_level(path):
		_status_label.text = "Could not load %s" % path


func _process(delta: float) -> void:
	if Game.state == null:
		return
	_view.interpolate(Game.alpha)
	_camera.follow(_view.player_world_position(), delta)


func _on_level_loaded() -> void:
	_view.build(Game.state)
	_camera.snap_to(_view.player_world_position())
	_update_hud()


func _on_sim_events(_tick: int, events: Array) -> void:
	_view.show_state(Game.prev_state, Game.state, events)
	_update_hud()


func _update_hud() -> void:
	var s: SimState = Game.state
	var keys: String = ""
	for c: int in Tiles.KEY_COLOR_COUNT:
		if s.keys[c] > 0:
			keys += "  %s×%d" % [KEY_SHAPES[c], s.keys[c]]
	_gems_label.text = "Gems %d/%d%s" % [s.gems_collected, s.gems_required, keys]
	if s.won:
		_status_label.text = "Level complete!"
	elif not s.alive:
		_status_label.text = "Crushed! Restart to try again"
	elif s.exit_open and s.gems_required > 0:
		_status_label.text = "The exit is open"
	else:
		_status_label.text = ""


func _on_back() -> void:
	Game.stop()
	get_tree().change_scene_to_file(BOOT_SCENE)
