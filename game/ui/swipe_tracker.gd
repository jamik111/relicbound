class_name SwipeTracker
extends RefCounted
## Turns one finger's path into a held direction. No nodes, so it's unit-testable.
##
## SWIPE (swipe-and-hold, the default): once the finger has moved `threshold` px from the anchor, the
## dominant axis becomes the held direction and the anchor follows the finger. Keep holding to keep
## walking; drag the other way past the threshold to turn. Lifting the finger stops.
## STICK (floating virtual stick): the touch-down point is the stick centre. Outside the dead zone the
## dominant axis of the offset is held; back inside the dead zone nothing is held.
## DPAD (fixed on screen, the default): the same as STICK, with a centre that never moves. See TouchControls.

## How much further than a turn a swipe has to go to reverse.
const REVERSE_FACTOR: float = 2.0
## How much bigger the sideways part of the stick must be than the forward part to turn.
const STICK_TURN_RATIO: float = 1.25

## A Settings.TouchScheme value (autoload enums can't be used as type hints).
var mode: int = Settings.TouchScheme.SWIPE
var threshold: float = 32.0
var dead_zone: float = 24.0

var active: bool = false
var origin: Vector2 = Vector2.ZERO
var position: Vector2 = Vector2.ZERO
var current: SimStep.Intent = SimStep.Intent.NONE


func begin(pos: Vector2) -> void:
	begin_at(pos, pos)


## A touch at `pos` measured from a fixed centre: the D-pad, which works like a stick that doesn't float.
func begin_at(center: Vector2, pos: Vector2) -> void:
	active = true
	origin = center
	position = pos
	current = SimStep.Intent.NONE


## Returns the direction to hold now (may be unchanged, or NONE).
func move(pos: Vector2) -> SimStep.Intent:
	if not active:
		return SimStep.Intent.NONE
	position = pos
	var d: Vector2 = pos - origin
	if mode == Settings.TouchScheme.SWIPE:
		if d.length() >= threshold:
			var next: SimStep.Intent = direction_of(d)
			# A resting thumb rocks back and forth: reversing takes a deliberate swipe.
			if current == SimStep.Intent.NONE or Vector2(SimStep.DIRECTIONS[next]) != -Vector2(SimStep.DIRECTIONS[current]) \
					or d.length() >= threshold * REVERSE_FACTOR:
				current = next
				origin = pos
	elif d.length() < dead_zone:
		current = SimStep.Intent.NONE
	elif mode == Settings.TouchScheme.DPAD:
		current = direction_of(d)  # a fixed pad turns the moment the thumb crosses into the next arrow
	else:
		current = _stick_direction(d)
	return current


## A thumb near the diagonal mustn't flip between two directions: a sideways turn has to clearly win.
func _stick_direction(d: Vector2) -> SimStep.Intent:
	var next: SimStep.Intent = direction_of(d)
	if current == SimStep.Intent.NONE or next == current:
		return next
	var heading := Vector2(SimStep.DIRECTIONS[current])
	var along: float = d.dot(heading)
	var across: float = absf(d.dot(Vector2(heading.y, heading.x)))
	return current if along > 0.0 and across < along * STICK_TURN_RATIO else next


func end() -> void:
	active = false
	current = SimStep.Intent.NONE


## Screen-space vector to a grid direction (screen up = north). Ties go to the horizontal axis.
static func direction_of(d: Vector2) -> SimStep.Intent:
	if absf(d.x) >= absf(d.y):
		return SimStep.Intent.RIGHT if d.x > 0.0 else SimStep.Intent.LEFT
	return SimStep.Intent.DOWN if d.y > 0.0 else SimStep.Intent.UP
