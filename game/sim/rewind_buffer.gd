class_name RewindBuffer
extends RefCounted
## The hourglass: recent states and the input given at each, oldest first. SimStep never modifies a state it
## was given, so storing references (no copies) is safe.
##
## It reaches back `window` ticks from the player's last input, not from now. Time spent standing still to
## think doesn't count, so the echo always has the walk to replay. Rewinding therefore also undoes that thinking
## time in the world, which is fine: the world then replays exactly the same way.

## History kept while the player stands still: 60 s at 10 ticks/s. After a longer pause the last walk is gone.
const MAX_KEPT_TICKS: int = 600

var window: int = 30
var _states: Array[SimState] = []
var _intents: PackedInt32Array = PackedInt32Array()


func _init(p_window: int = 30) -> void:
	window = p_window


## `intent` is the input that was given from `state`.
func push(state: SimState, intent: int = SimStep.Intent.NONE) -> void:
	_states.append(state)
	_intents.append(intent)
	if _states.size() > maxi(MAX_KEPT_TICKS, window):
		_states.pop_front()
		_intents.remove_at(0)


func size() -> int:
	return _states.size()


func is_empty() -> bool:
	return _states.is_empty()


func clear() -> void:
	_states.clear()
	_intents.clear()


## The inputs an echo replays: from the rewind point up to the last input. Trailing idle ticks are dropped.
func intents() -> PackedInt32Array:
	var last: int = _last_input_index()
	return _intents.slice(_start_index(last), last + 1)


## Removes everything and returns the state the hourglass reaches back to, or null if there's no history.
func rewind_all() -> SimState:
	if _states.is_empty():
		return null
	var target: SimState = _states[_start_index(_last_input_index())]
	clear()
	return target


func _start_index(last: int) -> int:
	return maxi(0, last - window + 1)


## Index of the most recent real input, or the newest tick if the player hasn't moved at all.
func _last_input_index() -> int:
	for i: int in range(_intents.size() - 1, -1, -1):
		if _intents[i] != SimStep.Intent.NONE:
			return i
	return _intents.size() - 1
