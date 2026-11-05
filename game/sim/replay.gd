class_name Replay
extends RefCounted
## Replays: a starting state plus one input character per tick.
## ".": none, "U"/"D"/"L"/"R": move, "H": use the hourglass (rewind and leave an echo),
## "X": respawn after dying, as Game does, from the last idol saved or the level start.
## Whitespace is ignored so long inputs can be grouped for reading.

const INPUT_CHARS: String = ".UDLR"  # index = SimStep.Intent
const HOURGLASS_CHAR: String = "H"
const RESPAWN_CHAR: String = "X"
const HOURGLASS_TICKS: int = 30


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
	var checkpoint: SimState = start
	var attempt := PackedInt32Array()
	var idol_pending: bool = false
	var history := RewindBuffer.new(HOURGLASS_TICKS)
	for ch: String in inputs:
		if ch == HOURGLASS_CHAR:
			if not history.is_empty():
				var recorded: PackedInt32Array = history.intents()
				s = RuleEcho.spawned(history.rewind_all(), recorded)
				attempt.resize(s.tick - checkpoint.tick)
			continue
		if ch == RESPAWN_CHAR:
			if s.remembers:
				checkpoint = RuleMemory.scarred(checkpoint, s.player)
				s = RuleMemory.with_remnant(checkpoint, attempt)
			else:
				s = checkpoint
			attempt.clear()
			history.clear()
			idol_pending = false
			continue
		var intent: int = INPUT_CHARS.find(ch)
		if intent >= 0:
			if s.alive:
				attempt.append(intent)
			history.push(s, intent)
			var result: StepResult = SimStep.step(s, intent as SimStep.Intent)
			s = result.state
			idol_pending = idol_pending or result.has_event(SimEvent.Type.CHECKPOINT_LIT)
			if idol_pending and SimStep.is_settled(s):
				checkpoint = s
				attempt.clear()
				idol_pending = false
	return s
