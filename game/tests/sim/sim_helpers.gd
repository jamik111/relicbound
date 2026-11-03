extends RefCounted
## Shared helpers for sim tests. Maps use LevelCodec's legend in one combined layer:
## # wall, % ancient wall, . floor, : dirt, E exit, RBGJ doors, @ player, O boulder, X crate, * gem, rbgj keys.

const U: SimStep.Intent = SimStep.Intent.UP
const D: SimStep.Intent = SimStep.Intent.DOWN
const L: SimStep.Intent = SimStep.Intent.LEFT
const R: SimStep.Intent = SimStep.Intent.RIGHT
const NONE: SimStep.Intent = SimStep.Intent.NONE


static func state(rows: PackedStringArray, meta: Dictionary = {}) -> SimState:
	var errors := PackedStringArray()
	var s: SimState = LevelCodec.parse(LevelCodec.from_combined(rows, meta), errors)
	assert(errors.is_empty(), "bad test map: %s" % [errors])
	return s


static func step(s: SimState, intent: SimStep.Intent = SimStep.Intent.NONE) -> StepResult:
	return SimStep.step(s, intent)


## Runs a replay-style input string ("RRD.L") and returns the final state.
static func run(s: SimState, inputs: String) -> SimState:
	return Replay.run(s, inputs)


static func obj(s: SimState, x: int, y: int) -> int:
	return s.object_at(Vector2i(x, y))
