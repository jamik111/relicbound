class_name Replay
extends RefCounted
## Replays: a starting state plus one input character per tick.
## ".": none, "U"/"D"/"L"/"R": move. Whitespace is ignored so long inputs can be grouped for reading.

const INPUT_CHARS: String = ".UDLR"  # index = SimStep.Intent


static func parse_inputs(inputs: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for ch: String in inputs:
		var intent: int = INPUT_CHARS.find(ch)
		if intent >= 0:
			out.append(intent)
	return out


static func encode_inputs(intents: PackedInt32Array) -> String:
	var out: String = ""
	for intent: int in intents:
		out += INPUT_CHARS[intent]
	return out


## Runs every input from `start` and returns the final state.
static func run(start: SimState, inputs: String) -> SimState:
	var s: SimState = start
	for intent: int in parse_inputs(inputs):
		s = SimStep.step(s, intent as SimStep.Intent).state
	return s
