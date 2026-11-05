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
@onready var _hint_label: Label = %HintLabel

## The level's one-line goal (meta.hint), so a new player always knows what they're doing.
var _hint: String = ""


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.06, 0.05)
	add_child(env)
	Events.level_loaded.connect(_on_level_loaded)
	Events.sim_events.connect(_on_sim_events)
	Events.state_replaced.connect(_on_state_replaced)
	Events.checkpoint_saved.connect(_on_checkpoint_saved)
	_view.player_move_ticks = Game.move_interval_ticks
	%RewindButton.pressed.connect(Game.rewind)
	%RestartButton.pressed.connect(Game.restart)
	%BackButton.pressed.connect(_on_back)
	%ControlsButton.pressed.connect(_on_toggle_controls)
	_update_controls_button()
	var path: String = Game.level_path if Game.level_path != "" else default_level
	if not Game.load_level(path):
		_status_label.text = "Could not load %s" % path


func _process(delta: float) -> void:
	if Game.state == null:
		return
	_view.interpolate(Game.alpha)
	_camera.follow(_view.player_world_position(), delta)


func _on_level_loaded() -> void:
	var meta: Dictionary = LevelLoader.load_data(Game.level_path).get("meta", {}) as Dictionary
	_hint = str(meta.get("hint", ""))
	_hint_label.text = _hint
	_view.build(Game.state)
	_camera.snap_to(_view.player_world_position())
	_update_hud()


## Rewind or respawn: rebuild from the restored state; the camera eases over instead of snapping.
func _on_state_replaced() -> void:
	_view.build(Game.state)
	_update_hud()


func _on_checkpoint_saved() -> void:
	_hint_label.text = "Checkpoint saved"
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		_hint_label.text = _hint


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
	%RewindButton.text = "⌛ %d" % Game.rewinds_left
	%RewindButton.disabled = Game.rewinds_left <= 0
	if s.won:
		_status_label.text = "Level complete!"
	elif not s.alive:
		_status_label.text = "Crushed!" + ("  Rewind?" if Game.rewinds_left > 0 else "")
	elif not s.echoes.is_empty():
		_status_label.text = _echo_status(s.echoes[-1])
	elif s.exit_open and s.gems_required > 0:
		_status_label.text = "The exit is open"
	else:
		_status_label.text = ""


func _echo_status(e: SimEcho) -> String:
	if e.cursor < e.inputs.size():
		return "Your echo is replaying"
	return "Echo fades in %d s" % ceili(float(e.linger) / Game.tick_rate())


## Swipe vs stick is an open PRD question (Q1), so playtesters can switch in-level.
func _on_toggle_controls() -> void:
	Settings.touch_scheme = (Settings.TouchScheme.STICK if Settings.touch_scheme == Settings.TouchScheme.SWIPE
		else Settings.TouchScheme.SWIPE)
	Settings.save_settings()
	_update_controls_button()


func _update_controls_button() -> void:
	%ControlsButton.text = "Stick" if Settings.touch_scheme == Settings.TouchScheme.STICK else "Swipe"


func _on_back() -> void:
	Game.stop()
	get_tree().change_scene_to_file(BOOT_SCENE)
