class_name RewindBuffer
extends RefCounted
## The hourglass: the last `capacity` states and the input given at each, oldest first. SimStep never modifies a state it was given,
## so storing references (no copies) is safe.

var capacity: int = 30
var _states: Array[SimState] = []
var _intents: PackedInt32Array = PackedInt32Array()


func _init(p_capacity: int = 30) -> void:
	capacity = p_capacity


## `intent` is the input that was given from `state`.
func push(state: SimState, intent: int = SimStep.Intent.NONE) -> void:
	_states.append(state)
	_intents.append(intent)
	if _states.size() > capacity:
		_states.pop_front()
		_intents.remove_at(0)


func size() -> int:
	return _states.size()


func is_empty() -> bool:
	return _states.is_empty()


func clear() -> void:
	_states.clear()
	_intents.clear()


## The inputs recorded since the oldest stored state: what an echo replays.
func intents() -> PackedInt32Array:
	return _intents.duplicate()


## Removes and returns the oldest stored state (the furthest back the hourglass reaches), or null.
func rewind_all() -> SimState:
	if _states.is_empty():
		return null
	var oldest: SimState = _states[0]
	clear()
	return oldest
