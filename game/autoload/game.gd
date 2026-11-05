extends Node
## Owns the running level: the sim state, the fixed-rate tick clock and the input buffer.
## Each tick it takes the buffered intent, calls SimStep.step(), keeps the previous state for view
## interpolation and forwards the events through Events. Nothing else may change `state`.

const TICK_RATE_HZ: int = 10
const ASSIST_TICK_RATE_HZ: int = 6
## Hourglass: how far back from the last move one use reaches (ticks), and uses per level (GDD/roadmap 2.4).
const REWIND_TICKS: int = 30
const REWIND_CHARGES: int = 3
## Seconds from being crushed to respawning at the last lit checkpoint (roadmap 2.3: <= 1.2 s).
const RESPAWN_DELAY: float = 1.0
## The player moves at most once per this many ticks: 5 tiles/s at the 10 Hz tick. Objects still fall at 10 tiles/s.
## This is an input cadence, not a sim rule, so replays (which record per-tick intents) don't change.
const MOVE_INTERVAL_TICKS: int = 2

## Input actions registered at startup (remappable later through InputMap).
const MOVE_ACTIONS: Dictionary = {
	&"move_up": SimStep.Intent.UP,
	&"move_down": SimStep.Intent.DOWN,
	&"move_left": SimStep.Intent.LEFT,
	&"move_right": SimStep.Intent.RIGHT,
}

var state: SimState
## The state one tick earlier; the view interpolates from here to `state`.
var prev_state: SimState
var level_path: String = ""
var running: bool = false
## Fraction of the next tick already elapsed, for view interpolation (0..1).
var alpha: float = 0.0
var rewinds_left: int = REWIND_CHARGES
var move_interval_ticks: int = MOVE_INTERVAL_TICKS

var _accumulator: float = 0.0
## Directions currently held, most recent first. Holding a direction repeats at the walking cadence.
var _held: Array[SimStep.Intent] = []
## A press not yet used. It wins over held directions, so a quick tap between moves isn't lost.
var _pending: SimStep.Intent = SimStep.Intent.NONE
## Ticks until the player may move again.
var _move_cooldown: int = 0
var _history := RewindBuffer.new(REWIND_TICKS)
## State saved when the last checkpoint idol was lit (or the level start). Respawn restores it.
var _checkpoint: SimState
## Hourglass uses when that state was saved. Dying gives them back: the echoes they made are gone too,
## and a room that needs an echo would otherwise become unwinnable.
var _checkpoint_rewinds: int = REWIND_CHARGES
## An idol was lit but the room isn't settled yet: save as soon as nothing is moving.
var _checkpoint_pending: bool = false
## Counts down after a crush; < 0 when no respawn is pending.
var _respawn_timer: float = -1.0


func _ready() -> void:
	_register_actions()


func tick_rate() -> int:
	return ASSIST_TICK_RATE_HZ if Settings.assist_mode else TICK_RATE_HZ


## Loads a level and starts its clock. Returns false (and leaves the current level running) on error.
func load_level(path: String) -> bool:
	var s: SimState = LevelLoader.load_state(path)
	if s == null:
		return false
	level_path = path
	state = s
	prev_state = s
	_accumulator = 0.0
	alpha = 0.0
	_pending = SimStep.Intent.NONE
	_held.clear()
	_history.clear()
	_checkpoint = s
	_checkpoint_rewinds = REWIND_CHARGES
	_checkpoint_pending = false
	_move_cooldown = 0
	_respawn_timer = -1.0
	rewinds_left = REWIND_CHARGES
	running = true
	Events.level_loaded.emit()
	return true


func restart() -> void:
	if level_path != "":
		load_level(level_path)


func stop() -> void:
	running = false


## Hourglass: jumps back up to REWIND_TICKS ticks (works mid-fall and after being crushed) and leaves an
## echo of the player replaying those ticks.
## Returns false if no charges or no history are left.
func rewind() -> bool:
	if rewinds_left <= 0 or _history.is_empty():
		return false
	var recorded: PackedInt32Array = _history.intents()
	_replace_state(RuleEcho.spawned(_history.rewind_all(), recorded))
	rewinds_left -= 1
	Events.rewound.emit(rewinds_left)
	return true


## Restores the last checkpoint snapshot (or the level start), with the hourglass uses it had.
func respawn() -> void:
	_history.clear()
	rewinds_left = _checkpoint_rewinds
	_replace_state(_checkpoint)
	Events.respawned.emit()


func _replace_state(s: SimState) -> void:
	state = s
	prev_state = s
	_pending = SimStep.Intent.NONE
	_move_cooldown = 0
	_checkpoint_pending = false
	_respawn_timer = -1.0
	_accumulator = 0.0
	alpha = 0.0
	Events.state_replaced.emit()


# --- Input buffer (keyboard, gamepad and touch all feed these) -------------------

func press(intent: SimStep.Intent) -> void:
	_pending = intent
	_held.erase(intent)
	_held.push_front(intent)


func release(intent: SimStep.Intent) -> void:
	_held.erase(intent)


func release_all() -> void:
	_held.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for action: StringName in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			press(MOVE_ACTIONS[action])
		elif event.is_action_released(action):
			release(MOVE_ACTIONS[action])
	if event.is_action_pressed(&"restart"):
		restart()
	elif event.is_action_pressed(&"rewind"):
		rewind()


# --- Clock --------------------------------------------------------------------

func _process(delta: float) -> void:
	if not running:
		return
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			respawn()
			return
	var step_time: float = 1.0 / tick_rate()
	_accumulator += delta
	# Cap catch-up so a long hitch doesn't run dozens of ticks in one frame.
	_accumulator = minf(_accumulator, step_time * 5.0)
	while _accumulator >= step_time:
		_accumulator -= step_time
		_advance()
	alpha = _accumulator / step_time


func _advance() -> void:
	var intent: SimStep.Intent = _take_intent()
	var result: StepResult = SimStep.step(state, intent)
	_history.push(state, intent)
	prev_state = state
	state = result.state
	for e: SimEvent in result.events:
		if e.type == SimEvent.Type.CHECKPOINT_LIT:
			_checkpoint_pending = true
		elif e.type == SimEvent.Type.PLAYER_CRUSHED or e.type == SimEvent.Type.PLAYER_KILLED:
			_respawn_timer = RESPAWN_DELAY
			_checkpoint_pending = false
	if _checkpoint_pending and _room_is_settled(state):
		_checkpoint = state
		_checkpoint_rewinds = rewinds_left
		_checkpoint_pending = false
		Events.checkpoint_saved.emit()
	Events.sim_events.emit(state.tick, result.events)
	Events.sim_ticked.emit(state.tick)


## The direction to send this tick, limited to the walking cadence. A press waits for the cooldown.
func _take_intent() -> SimStep.Intent:
	if _move_cooldown > 0:
		_move_cooldown -= 1
		return SimStep.Intent.NONE
	var intent: SimStep.Intent = _pending
	if intent == SimStep.Intent.NONE and not _held.is_empty():
		intent = _held[0]
	_pending = SimStep.Intent.NONE
	if intent != SimStep.Intent.NONE:
		_move_cooldown = move_interval_ticks - 1
	return intent


## Settled = no echoes, and one idle tick later nothing has moved and the player is still alive, so respawning into this
## state can't drop anything on the player. Trial-steps the pure sim instead of duplicating its rules.
static func _room_is_settled(s: SimState) -> bool:
	var trial: StepResult = SimStep.step(s, SimStep.Intent.NONE)
	if not trial.state.alive or not s.echoes.is_empty():
		return false
	for e: SimEvent in trial.events:
		if e.type in [SimEvent.Type.OBJECT_FELL, SimEvent.Type.OBJECT_ROLLED, SimEvent.Type.OBJECT_LANDED]:
			return false
	return true


func _register_actions() -> void:
	var keys: Dictionary = {
		&"move_up": [KEY_W, KEY_UP],
		&"move_down": [KEY_S, KEY_DOWN],
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"restart": [KEY_BACKSPACE],
		&"rewind": [KEY_R],
	}
	var pads: Dictionary = {
		&"move_up": JOY_BUTTON_DPAD_UP,
		&"move_down": JOY_BUTTON_DPAD_DOWN,
		&"move_left": JOY_BUTTON_DPAD_LEFT,
		&"move_right": JOY_BUTTON_DPAD_RIGHT,
		&"restart": JOY_BUTTON_BACK,
		&"rewind": JOY_BUTTON_Y,
	}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)
		var pad := InputEventJoypadButton.new()
		pad.button_index = pads[action] as JoyButton
		InputMap.action_add_event(action, pad)
