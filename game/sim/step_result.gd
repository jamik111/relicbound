class_name StepResult
extends RefCounted
## What SimStep.step() returns: the next state and what happened on the way there.

var state: SimState
var events: Array[SimEvent] = []


func has_event(type: SimEvent.Type) -> bool:
	for e: SimEvent in events:
		if e.type == type:
			return true
	return false


func count_events(type: SimEvent.Type) -> int:
	var n: int = 0
	for e: SimEvent in events:
		if e.type == type:
			n += 1
	return n
