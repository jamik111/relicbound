extends GutTest
## The fixed joystick (Settings.TouchScheme.DPAD): press and you move, lift and you stop, and a touch anywhere else
## does nothing.

const LEVEL: String = "res://levels/test/test_01_walk_dig.json"
const SCREEN := Vector2(1280, 720)

var _controls: TouchControls
var _saved_scheme: int


func before_each() -> void:
	_saved_scheme = Settings.touch_scheme
	Settings.touch_scheme = Settings.TouchScheme.DPAD
	assert_true(Game.load_level(LEVEL))
	Game.stop()
	_controls = TouchControls.new()
	add_child_autofree(_controls)


func after_each() -> void:
	Game.release_all()
	Settings.touch_scheme = _saved_scheme as Settings.TouchScheme


func _center() -> Vector2:
	return TouchControls.dpad_center(_controls.get_viewport_rect().size)


func _radius() -> float:
	return TouchControls.DPAD_RADIUS * _controls.get_viewport_rect().size.y


func _touch(pos: Vector2, pressed: bool = true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_controls._gui_input(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	_controls._gui_input(ev)


func test_it_sits_in_the_bottom_left_corner_and_fits_on_screen() -> void:
	var c: Vector2 = TouchControls.dpad_center(SCREEN)
	var r: float = TouchControls.DPAD_RADIUS * SCREEN.y
	assert_gt(c.x - r, 0.0)
	assert_lt(c.y + r, SCREEN.y)
	assert_lt(c.x, SCREEN.x / 2.0)


func test_each_arrow_holds_its_direction() -> void:
	for intent: SimStep.Intent in [SimStep.Intent.UP, SimStep.Intent.DOWN, SimStep.Intent.LEFT, SimStep.Intent.RIGHT]:
		_touch(_center() + Vector2(SimStep.DIRECTIONS[intent]) * _radius() * 0.7)
		assert_eq(Game._held, [intent] as Array[SimStep.Intent])
		_touch(_center(), false)
		assert_true(Game._held.is_empty(), "lifting stops")


func test_pressing_moves_without_any_drag() -> void:
	_touch(_center() + Vector2.RIGHT * _radius() * 0.7)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1))


func test_a_touch_outside_it_does_nothing() -> void:
	var outside: Vector2 = _center() + Vector2(_radius() * 1.5, 0.0)
	_touch(outside)
	_drag(outside + Vector2(200, 0))
	assert_true(Game._held.is_empty())
	Game._advance()
	assert_eq(Game.state.player, Vector2i(1, 1))


func test_the_centre_is_a_dead_zone() -> void:
	_touch(_center() + Vector2(2, 2))
	assert_true(Game._held.is_empty())


func test_sliding_to_another_arrow_turns() -> void:
	_touch(_center() + Vector2.RIGHT * _radius() * 0.7)
	_drag(_center() + Vector2.UP * _radius() * 0.7)
	assert_eq(Game._held, [SimStep.Intent.UP] as Array[SimStep.Intent])


func test_a_finger_resting_in_place_keeps_its_direction() -> void:
	_touch(_center() + Vector2.RIGHT * _radius() * 0.7)
	_drag(_center() + Vector2.RIGHT * _radius() * 0.7 + Vector2(3, -4))
	assert_eq(Game._held, [SimStep.Intent.RIGHT] as Array[SimStep.Intent])


## Playtest 6: no hysteresis on the fixed pad. Crossing into the next arrow turns at once.
func test_crossing_the_diagonal_turns_at_once() -> void:
	_touch(_center() + Vector2(_radius() * 0.6, 0.0))
	_drag(_center() + Vector2(_radius() * 0.45, -_radius() * 0.5))
	assert_eq(Game._held, [SimStep.Intent.UP] as Array[SimStep.Intent])


func test_the_knob_follows_the_thumb_only_while_held() -> void:
	_touch(_center() + Vector2.RIGHT * _radius() * 0.7)
	assert_true(_controls._tracker.active)
	_touch(_center(), false)
	assert_false(_controls._tracker.active)


func test_the_dpad_is_the_default_scheme() -> void:
	var fresh: Node = load("res://autoload/settings.gd").new()
	assert_eq(fresh.get("touch_scheme"), Settings.TouchScheme.DPAD)
	fresh.free()
