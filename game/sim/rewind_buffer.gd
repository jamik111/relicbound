class_name RewindBuffer
extends RefCounted
## The hourglass: the last `capacity` states, oldest first. SimStep never modifies a state it was given,
## so storing references (no copies) is safe.

var capacity: int = 30
var _states: Array[SimState] = []


func _init(p_capacity: int = 30) -> void:
	capacity = p_capacity


func push(state: SimState) -> void:
	_states.append(state)
	if _states.size() > capacity:
		_states.pop_front()


func size() -> int:
	return _states.size()


func is_empty() -> bool:
	return _states.is_empty()


func clear() -> void:
	_states.clear()


## Removes and returns the oldest stored state (the furthest back the hourglass reaches), or null.
func rewind_all() -> SimState:
	if _states.is_empty():
		return null
	var oldest: SimState = _states[0]
	_states.clear()
	return oldest
