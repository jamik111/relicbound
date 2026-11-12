extends Node3D
## Plays one level: asks Game to load it, and connects Game's ticks to the LevelView, camera and HUD.
## The level comes from Game.level_path if the boot screen set one, otherwise `default_level`.

const BOOT_SCENE: String = "res://scenes/boot.tscn"
const KEY_SHAPES: Array[String] = ["♦", "●", "▲", "■"]
const ECHO_PROMPT_TOUCH: String = "Tap ⌛ now!"
const ECHO_PROMPT_KEYS: String = "Press R now! (Y on a gamepad)"
const NO_REWINDS_TEXT: String = "No rewinds left. Tap Restart if you're stuck."
const SCARS_TEXT: String = "The temple remembers %d of your deaths (max %d), even if you leave."
const NO_FORGETS_TEXT: String = "Stuck? Tap Back, win any level for a Forget, then return."
## Settings.TouchScheme order.
const CONTROL_NAMES: Array[String] = ["Swipe", "Float stick", "Joystick"]
const REWIND_PULSE_SCALE: Vector2 = Vector2(1.18, 1.18)
const REWIND_PULSE_SECONDS: float = 0.35
const REWIND_PROMPT_TINT: Color = Color(2.2, 1.7, 0.5)
## See-through, so the map stays readable underneath it.
const REWIND_IDLE_TINT: Color = Color(1.0, 1.0, 1.0, 0.6)

@export_file("*.json") var default_level: String = "res://levels/test/test_05_keys_doors.json"

@onready var _view: LevelView = $LevelView
@onready var _camera: FollowCamera = $FollowCamera
@onready var _gems_label: Label = %GemsLabel
@onready var _status_label: Label = %StatusLabel
@onready var _hint_label: Label = %HintLabel

## The level's one-line goal (meta.hint), so a new player always knows what they're doing.
var _hint: String = ""
## meta.teach_echo: this room teaches the hourglass, so prompt the player at the right moment.
var _teach_echo: bool = false
var _rewind_pulse: Tween
## Steam is the target, so the on-screen joystick and the controls switch only appear on a touchscreen.
var _touch: bool = DisplayServer.is_touchscreen_available()


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
	%ForgetButton.pressed.connect(Game.forget)
	%BackButton.pressed.connect(_on_back)
	%NextButton.pressed.connect(_on_next)
	%ControlsButton.pressed.connect(_on_toggle_controls)
	%RewindButton.modulate = REWIND_IDLE_TINT
	$HUD/TouchControls.visible = _touch
	%ControlsButton.visible = _touch
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
	_teach_echo = bool(meta.get("teach_echo", false))
	_view.build(Game.state)
	_camera.snap_to(_view.player_world_position())
	_update_hud()


## True when the player is holding a plate and the hourglass would leave an echo there: the moment to teach it.
static func should_prompt_echo(s: SimState, teach: bool, rewinds_left: int) -> bool:
	return (teach and s.alive and rewinds_left > 0 and s.echoes.is_empty()
		and s.terrain_at(s.player) == Tiles.Terrain.PLATE)


func _update_echo_prompt() -> void:
	var prompting: bool = should_prompt_echo(Game.state, _teach_echo, Game.rewinds_left)
	if prompting == (_rewind_pulse != null):
		return
	var button: Button = %RewindButton
	if prompting:
		_hint_label.text = ECHO_PROMPT_TOUCH if _touch else ECHO_PROMPT_KEYS
		button.modulate = REWIND_PROMPT_TINT
		_rewind_pulse = create_tween().set_loops()
		_rewind_pulse.tween_property(button, "scale", REWIND_PULSE_SCALE, REWIND_PULSE_SECONDS)
		_rewind_pulse.tween_property(button, "scale", Vector2.ONE, REWIND_PULSE_SECONDS)
	else:
		_hint_label.text = _hint
		_rewind_pulse.kill()
		_rewind_pulse = null
		button.scale = Vector2.ONE
		button.modulate = REWIND_IDLE_TINT


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
	%RewindButton.text = ("⌛ %d\nRewind" if _touch else "⌛ %d\nRewind [R]") % Game.rewinds_left
	%RewindButton.disabled = Game.rewinds_left <= 0
	%ForgetButton.visible = not s.scars.is_empty()
	%ForgetButton.text = "Forget (%d)" % Save.forgets()
	%ForgetButton.disabled = Save.forgets() <= 0
	if s.won:
		_status_label.text = "Level complete!"
	elif not s.alive:
		_status_label.text = "You died" + ("  Rewind?" if Game.rewinds_left > 0 else "")
	elif not s.echoes.is_empty():
		_status_label.text = _echo_status(s.echoes[-1])
	elif not s.scars.is_empty():
		_status_label.text = NO_FORGETS_TEXT if Save.forgets() <= 0 else SCARS_TEXT % [s.scars.size(), RuleMemory.MAX_SCARS]
	elif Game.rewinds_left <= 0 and s.hourglass_uses > 0:
		_status_label.text = NO_REWINDS_TEXT
	elif s.exit_open and s.gems_required > 0:
		_status_label.text = "The exit is open"
	else:
		_status_label.text = ""
	_update_echo_prompt()
	%NextButton.visible = s.won and LevelLoader.next_level(Game.level_path) != ""


func _echo_status(e: SimEcho) -> String:
	if e.remnant:
		return "Your last attempt is replaying"
	if e.cursor < e.inputs.size():
		return "Your echo is replaying"
	return "Echo fades in %d s" % ceili(float(e.linger) / Game.tick_rate())


## Which control scheme is best is an open PRD question (Q1), so playtesters can switch in-level.
func _on_toggle_controls() -> void:
	Settings.touch_scheme = ((Settings.touch_scheme + 1) % Settings.TouchScheme.size()) as Settings.TouchScheme
	Settings.save_settings()
	_update_controls_button()
	$HUD/TouchControls.queue_redraw()


func _update_controls_button() -> void:
	%ControlsButton.text = CONTROL_NAMES[Settings.touch_scheme]


func _on_next() -> void:
	Game.load_level(LevelLoader.next_level(Game.level_path))


func _on_back() -> void:
	Game.stop()
	get_tree().change_scene_to_file(BOOT_SCENE)
