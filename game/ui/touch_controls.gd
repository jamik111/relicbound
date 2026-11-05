class_name TouchControls
extends Control
## Full-screen touch layer under the HUD buttons: feeds Game's input buffer from one finger via SwipeTracker.
## Uses the mouse events Godot emulates from the first touch, so it also works with a mouse on desktop.
## Sizes scale with the viewport height so they feel the same on every screen.

## Swipe distance before a direction counts, as a fraction of viewport height (~32 px at 1080p).
const SWIPE_THRESHOLD: float = 0.03
const STICK_RADIUS: float = 0.09
const STICK_DEAD_ZONE: float = 0.25  # fraction of the stick radius

var _tracker := SwipeTracker.new()
var _held: SimStep.Intent = SimStep.Intent.NONE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_configure()
			_tracker.begin(mb.position)
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


func _configure() -> void:
	var h: float = get_viewport_rect().size.y
	_tracker.mode = Settings.touch_scheme
	_tracker.threshold = SWIPE_THRESHOLD * h
	_tracker.dead_zone = STICK_DEAD_ZONE * STICK_RADIUS * h


func _hold(intent: SimStep.Intent) -> void:
	if intent == _held:
		return
	if _held != SimStep.Intent.NONE:
		Game.release(_held)
	_held = intent
	if intent != SimStep.Intent.NONE:
		Game.press(intent)


func _draw() -> void:
	if not _tracker.active or _tracker.mode != Settings.TouchScheme.STICK:
		return
	var r: float = STICK_RADIUS * get_viewport_rect().size.y
	var offset: Vector2 = (_tracker.position - _tracker.origin).limit_length(r)
	draw_circle(_tracker.origin, r, Color(1, 1, 1, 0.12))
	draw_arc(_tracker.origin, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(_tracker.origin + offset, r * 0.38, Color(1, 1, 1, 0.45))
