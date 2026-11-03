class_name SimStep
extends RefCounted
## The one entry point that advances the game: step(state, intent) -> StepResult.
## Pure: the input state is never modified, and the same state + intent always gives the same result.

## Player input for one tick. The values are stored in replays: never renumber.
enum Intent { NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4 }

const DIRECTIONS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func step(state: SimState, intent: Intent) -> StepResult:
	var s: SimState = state.copy()
	var events: Array[SimEvent] = []
	var done := PackedByteArray()
	done.resize(s.width * s.height)
	done.fill(0)

	# 1) Player intent.
	if s.alive and not s.won:
		RulePlayer.apply(s, DIRECTIONS[intent], done, events)
	# 2) Tools: Sprint 4+ (grapple-whip, lantern, pick...).
	# 3) Falling / rolling objects.
	var crushed_by: int = RuleGravity.apply(s, done, events)
	# 4) Element flows: per world (water in World 1...).
	# 5) Enemies: Sprint 2.
	# 6) Triggers.
	RuleTriggers.apply(s, events)
	# 7) Damage resolve.
	if crushed_by != Tiles.Obj.NONE and s.alive:
		s.alive = false
		events.append(SimEvent.make(SimEvent.Type.PLAYER_CRUSHED, s.player, s.player, crushed_by))

	s.tick += 1
	var result := StepResult.new()
	result.state = s
	result.events = events
	return result
