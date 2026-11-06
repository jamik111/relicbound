class_name TouchControls
extends Control
## Full-screen touch layer under the HUD buttons: feeds Game's input buffer from one finger via SwipeTracker.
## Uses the mouse events Godot emulates from the first touch, so it also works with a mouse on desktop.
## Sizes scale with the viewport height so they feel the same on every screen.

## Swipe distance before a direction counts, as a fraction of viewport height (~32 px at 1080p).
const SWIPE_THRESHOLD: float = 0.03
const STICK_RADIUS: float = 0.09
const STICK_DEAD_ZONE: float = 0.25  # fraction of the stick radius
## D-pad: fractions of viewport height, in the bottom left corner, under the left thumb.
const DPAD_RADIUS: float = 0.2
const DPAD_MARGIN: float = 0.03
const DPAD_DEAD_ZONE: float = 0.2  # fraction of the D-pad radius
const DPAD_ARROW_REACH: float = 0.72  # how far out each arrow's tip sits, as a fraction of the radius
const DPAD_ARROW_SIZE: float = 0.26
const DPAD_ALPHA: float = 0.14
const DPAD_ARROW_ALPHA: float = 0.5
const DPAD_PRESSED_ALPHA: float = 0.95

var _tracker := SwipeTracker.new()
var _held: SimStep.Intent = SimStep.Intent.NONE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_begin(mb.position)
		else:
			_tracker.end()
			_hold(SimStep.Intent.NONE)
		queue_redraw()
		accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm and _tracker.active:
		_hold(_tracker.move(mm.position))
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	# Don't leave a direction stuck if the app loses focus mid-swipe.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_tracker.end()
		_hold(SimStep.Intent.NONE)


## The D-pad's centre on a screen this size.
static func dpad_center(screen: Vector2) -> Vector2:
	var offset: float = (DPAD_RADIUS + DPAD_MARGIN) * screen.y
	return Vector2(offset, screen.y - offset)


## A touch anywhere else does nothing, so a stray finger can't move the player.
static func on_dpad(pos: Vector2, screen: Vector2) -> bool:
	return pos.distance_to(dpad_center(screen)) <= DPAD_RADIUS * screen.y


func _begin(pos: Vector2) -> void:
	var screen: Vector2 = get_viewport_rect().size
	_tracker.mode = Settings.touch_scheme
	_tracker.threshold = SWIPE_THRESHOLD * screen.y
	if Settings.touch_scheme == Settings.TouchScheme.DPAD:
		if not on_dpad(pos, screen):
			return
		_tracker.dead_zone = DPAD_DEAD_ZONE * DPAD_RADIUS * screen.y
		_tracker.begin_at(dpad_center(screen), pos)
		_hold(_tracker.move(pos))  # pressing moves at once: there's nothing to wait for
	else:
		_tracker.dead_zone = STICK_DEAD_ZONE * STICK_RADIUS * screen.y
		_tracker.begin(pos)


func _hold(intent: SimStep.Intent) -> void:
	if intent == _held:
		return
	if _held != SimStep.Intent.NONE:
		Game.release(_held)
	_held = intent
	if intent != SimStep.Intent.NONE:
		Game.press(intent)


func _draw() -> void:
	if Settings.touch_scheme == Settings.TouchScheme.DPAD:
		_draw_dpad()
	elif _tracker.active and _tracker.mode == Settings.TouchScheme.STICK:
		var r: float = STICK_RADIUS * get_viewport_rect().size.y
		var offset: Vector2 = (_tracker.position - _tracker.origin).limit_length(r)
		draw_circle(_tracker.origin, r, Color(1, 1, 1, 0.12))
		draw_arc(_tracker.origin, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(_tracker.origin + offset, r * 0.38, Color(1, 1, 1, 0.45))


func _draw_dpad() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var center: Vector2 = dpad_center(screen)
	var r: float = DPAD_RADIUS * screen.y
	draw_circle(center, r, Color(1, 1, 1, DPAD_ALPHA))
	draw_arc(center, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	for intent: SimStep.Intent in [SimStep.Intent.UP, SimStep.Intent.DOWN, SimStep.Intent.LEFT, SimStep.Intent.RIGHT]:
		var dir := Vector2(SimStep.DIRECTIONS[intent])
		var side := Vector2(dir.y, dir.x)
		var tip: Vector2 = center + dir * r * DPAD_ARROW_REACH
		var size: float = r * DPAD_ARROW_SIZE
		var alpha: float = DPAD_PRESSED_ALPHA if intent == _held else DPAD_ARROW_ALPHA
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * size + side * size, tip - dir * size - side * size]),
			Color(1, 1, 1, alpha))
