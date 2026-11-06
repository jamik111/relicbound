extends GutTest
## Task 2.2: swipe-and-hold and floating-stick direction logic.

const NONE: SimStep.Intent = SimStep.Intent.NONE

var _t: SwipeTracker


func before_each() -> void:
	_t = SwipeTracker.new()
	_t.threshold = 30.0
	_t.dead_zone = 20.0


func test_direction_of() -> void:
	assert_eq(SwipeTracker.direction_of(Vector2(10, 2)), SimStep.Intent.RIGHT)
	assert_eq(SwipeTracker.direction_of(Vector2(-10, 2)), SimStep.Intent.LEFT)
	assert_eq(SwipeTracker.direction_of(Vector2(2, -10)), SimStep.Intent.UP)
	assert_eq(SwipeTracker.direction_of(Vector2(2, 10)), SimStep.Intent.DOWN)


func test_swipe_needs_threshold() -> void:
	_t.begin(Vector2(100, 100))
	assert_eq(_t.move(Vector2(120, 100)), NONE)
	assert_eq(_t.move(Vector2(135, 100)), SimStep.Intent.RIGHT)


func test_swipe_holds_while_finger_rests() -> void:
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	assert_eq(_t.move(Vector2(142, 101)), SimStep.Intent.RIGHT, "small jitter keeps the direction")


func test_swipe_turns_after_new_threshold() -> void:
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	assert_eq(_t.move(Vector2(140, 80)), SimStep.Intent.RIGHT, "20 px up is under the threshold")
	assert_eq(_t.move(Vector2(140, 60)), SimStep.Intent.UP)


## Playtest 5: "chaotic". None of these small thumb movements should change where you're going.
func test_swipe_a_rocking_thumb_doesnt_reverse() -> void:
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	assert_eq(_t.move(Vector2(165, 100)), SimStep.Intent.RIGHT)
	assert_eq(_t.move(Vector2(130, 100)), SimStep.Intent.RIGHT, "35 px back is a rock, not a reverse")
	assert_eq(_t.move(Vector2(160, 100)), SimStep.Intent.RIGHT)


func test_swipe_a_slanted_forward_drag_doesnt_turn() -> void:
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	for i: int in range(1, 11):
		assert_eq(_t.move(Vector2(140 + i * 20, 100 - i * 9)), SimStep.Intent.RIGHT, "step %d" % i)


func test_stick_near_the_diagonal_doesnt_flip() -> void:
	_t.mode = Settings.TouchScheme.STICK
	_t.begin(Vector2(100, 100))
	assert_eq(_t.move(Vector2(140, 100)), SimStep.Intent.RIGHT)
	assert_eq(_t.move(Vector2(140, 55)), SimStep.Intent.RIGHT, "45 up against 40 right isn't a clear turn")
	assert_eq(_t.move(Vector2(140, 40)), SimStep.Intent.UP, "60 up against 40 right is")


func test_stick_reverses_at_once() -> void:
	_t.mode = Settings.TouchScheme.STICK
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	assert_eq(_t.move(Vector2(70, 100)), SimStep.Intent.LEFT)


func test_swipe_reverse() -> void:
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	assert_eq(_t.move(Vector2(75, 100)), SimStep.Intent.LEFT, "a long swipe back reverses")


func test_end_releases() -> void:
	_t.begin(Vector2(100, 100))
	_t.move(Vector2(140, 100))
	_t.end()
	assert_eq(_t.current, NONE)
	assert_eq(_t.move(Vector2(200, 100)), NONE, "moves after lift-off are ignored")


func test_stick_dead_zone_and_return() -> void:
	_t.mode = Settings.TouchScheme.STICK
	_t.begin(Vector2(100, 100))
	assert_eq(_t.move(Vector2(110, 100)), NONE)
	assert_eq(_t.move(Vector2(100, 140)), SimStep.Intent.DOWN)
	assert_eq(_t.move(Vector2(105, 105)), NONE, "back in the dead zone stops")
	assert_eq(_t.origin, Vector2(100, 100), "the stick centre doesn't follow the finger")
