class_name RuleMemory
extends RefCounted
## "The temple remembers", for levels with meta.remembers. Dying isn't a clean retry:
## - A scar, a solid statue, stands on the cell where you died. It blocks you, echoes and falling objects,
##   stops darts and holds down a plate, so the exact same attempt can't happen twice.
## - A remnant, a ghost of your failed attempt, replays it from the moment you respawn: it pushes what you
##   pushed and stands where you stood.
## Only MAX_SCARS scars last, oldest gone first. They're saved, so restarting or leaving the level keeps them.
## Winning clears them, and so does spending a Forget (Game.forget): that's the way out if your scars have closed
## off the room.
## Pure: everything comes from the checkpoint, the cell you died on and your inputs, so replays stay exact.

const MAX_SCARS: int = 3
## A remnant skips your thinking time: at most this many idle ticks in a row are kept.
const MAX_IDLE_RUN: int = 4
const REMNANT_LINGER_TICKS: int = 20


## The checkpoint to use from now on: `checkpoint` plus a scar on `died_at`. No scar goes where you respawn, or
## on anything that has to stay usable (an object, an idol, a gate, the exit).
static func scarred(checkpoint: SimState, died_at: Vector2i) -> SimState:
	var s: SimState = checkpoint.copy()
	if died_at == s.player or s.object_at(died_at) != Tiles.Obj.NONE or not Tiles.object_can_enter(s.terrain_at(died_at)):
		return s
	if s.scars.size() >= MAX_SCARS:
		var oldest: int = s.scars[0]
		s.remove_object(Vector2i(oldest % s.width, oldest / s.width))
		s.scars.remove_at(0)
	s.spawn_object(died_at, Tiles.Obj.SCAR)
	s.scars.append(s.idx(died_at))
	return s


## `start` with saved scars put back, oldest first. Cells that no longer fit (the level changed) are skipped.
static func with_scars(start: SimState, cells: PackedInt32Array) -> SimState:
	var s: SimState = start
	for i: int in cells:
		s = scarred(s, Vector2i(i % s.width, i / s.width))
	return s


## `checkpoint` plus a remnant replaying the failed attempt's inputs.
static func with_remnant(checkpoint: SimState, attempt: PackedInt32Array) -> SimState:
	var s: SimState = RuleEcho.spawned(checkpoint, _without_long_pauses(attempt))
	var remnant: SimEcho = s.echoes[-1]
	remnant.remnant = true
	remnant.linger = REMNANT_LINGER_TICKS
	return s


static func _without_long_pauses(attempt: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var idle: int = 0
	for intent: int in attempt:
		idle = idle + 1 if intent == SimStep.Intent.NONE else 0
		if idle <= MAX_IDLE_RUN:
			out.append(intent)
	return out
