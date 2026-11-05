class_name SwipeTracker
extends RefCounted
## Turns one finger's path into a held direction. No nodes, so it's unit-testable.
##
## SWIPE (swipe-and-hold, the default): once the finger has moved `threshold` px from the anchor, the
## dominant axis becomes the held direction and the anchor follows the finger. Keep holding to keep
## walking; drag the other way past the threshold to turn. Lifting the finger stops.
## STICK (floating virtual stick): the touch-down point is the stick centre. Outside the dead zone the
## dominant axis of the offset is held; back inside the dead zone nothing is held.

## A Settings.TouchScheme value (autoload enums can't be used as type hints).
var mode: int = Settings.TouchScheme.SWIPE
var threshold: float = 32.0
var dead_zone: float = 24.0

var active: bool = false
var origin: Vector2 = Vector2.ZERO
var position: Vector2 = Vector2.ZERO
var current: SimStep.Intent = SimStep.Intent.NONE


func begin(pos: Vector2) -> void:
	active = true
	origin = pos
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
			current = direction_of(d)
			origin = pos
	else:
		current = SimStep.Intent.NONE if d.length() < dead_zone else direction_of(d)
	return current


func end() -> void:
	active = false
	current = SimStep.Intent.NONE


## Screen-space vector to a grid direction (screen up = north). Ties go to the horizontal axis.
static func direction_of(d: Vector2) -> SimStep.Intent:
	if absf(d.x) >= absf(d.y):
		return SimStep.Intent.RIGHT if d.x > 0.0 else SimStep.Intent.LEFT
	return SimStep.Intent.DOWN if d.y > 0.0 else SimStep.Intent.UP
