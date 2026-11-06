extends GutTest
## A held walk pauses where a new way opens, and the game never moves the player unasked.
## One move per tick for readable tests.

const PATH: String = "user://test_junction_level.json"
const U: SimStep.Intent = SimStep.Intent.UP
const R: SimStep.Intent = SimStep.Intent.RIGHT
## The only way up from the corridor is at x=4.
const JUNCTION: PackedStringArray = ["#########", "####.####", "#@......#", "#########"]


func _load(rows: PackedStringArray) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(LevelCodec.from_combined(rows, {"gems_required": 0})))
	file.close()
	Game.move_interval_ticks = 1
	assert_true(Game.load_level(PATH))
	Game.stop()


func _advance(ticks: int) -> void:
	for i: int in ticks:
		Game._advance()


func _walk(steps: int) -> void:
	Game.press(R)
	_advance(steps)
	Game.release_all()


func after_each() -> void:
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	Game.release_all()
	Game.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# --- Never moved unasked (playtest 5: "swipe does moves that I didn't do") -----------

func test_turning_early_stops_you_against_the_wall() -> void:
	_load(JUNCTION)
	_walk(2)
	Game.press(U)
	_advance(3)
	assert_eq(Game.state.player, Vector2i(3, 2), "no walking on to the opening by itself")


func test_a_flick_into_a_wall_isnt_kept_for_later() -> void:
	_load(JUNCTION)
	_walk(2)
	Game.press(U)
	Game.release(U)
	_advance(3)
	Game.press(R)
	Game.release(R)
	_advance(1)
	assert_eq(Game.state.player, Vector2i(4, 2))
	_advance(2)
	assert_eq(Game.state.player, Vector2i(4, 2), "the old turn doesn't fire when you reach the opening")


func test_turning_late_never_moves_you_backwards() -> void:
	_load(JUNCTION)
	_walk(4 + Game.JUNCTION_PAUSE_TICKS)
	assert_eq(Game.state.player, Vector2i(5, 2))
	Game.press(U)
	_advance(3)
	assert_eq(Game.state.player, Vector2i(5, 2))


func test_lifting_stops_you_on_the_next_tick() -> void:
	_load(["#######", "#@....#", "#######"])
	_walk(2)
	_advance(5)
	assert_eq(Game.state.player, Vector2i(3, 1))


# --- Pausing at junctions -----------------------------------------------------------

func test_turning_on_the_junction_is_immediate() -> void:
	_load(JUNCTION)
	_walk(3)
	assert_eq(Game.state.player, Vector2i(4, 2))
	Game.press(U)
	_advance(1)
	assert_eq(Game.state.player, Vector2i(4, 1))


func test_held_walk_pauses_at_a_new_opening_then_carries_on() -> void:
	_load(JUNCTION)
	Game.press(R)
	_advance(3)
	assert_eq(Game.state.player, Vector2i(4, 2))
	for i: int in Game.JUNCTION_PAUSE_TICKS:
		Game._advance()
		assert_eq(Game.state.player, Vector2i(4, 2), "waiting, tick %d" % i)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(5, 2), "still holding, so it carries on")


func test_turning_during_the_pause_goes_at_once() -> void:
	_load(JUNCTION)
	Game.press(R)
	_advance(4)
	Game.release(R)
	Game.press(U)
	_advance(1)
	assert_eq(Game.state.player, Vector2i(4, 1))


func test_pressing_the_same_way_again_skips_the_pause() -> void:
	_load(JUNCTION)
	Game.press(R)
	_advance(4)
	Game.release(R)
	Game.press(R)
	_advance(1)
	assert_eq(Game.state.player, Vector2i(5, 2))


func test_lifting_during_the_pause_stops_you() -> void:
	_load(JUNCTION)
	Game.press(R)
	_advance(4)
	Game.release(R)
	_advance(Game.JUNCTION_PAUSE_TICKS + 2)
	assert_eq(Game.state.player, Vector2i(4, 2))


func test_no_pause_in_a_plain_corridor_or_an_open_room() -> void:
	_load(["#######", "#@....#", "#######"])
	_walk(4)
	assert_eq(Game.state.player, Vector2i(5, 1))
	_load(["#######", "#.....#", "#@....#", "#.....#", "#######"])
	_walk(4)
	assert_eq(Game.state.player, Vector2i(5, 2))


func test_no_pause_for_a_side_way_that_is_shut_or_a_pit() -> void:
	_load(["#######", "###H###", "#@....#", "###_###", "#######"])
	_walk(3)
	assert_eq(Game.state.player, Vector2i(4, 2))


func test_a_statue_isnt_an_opening() -> void:
	var s: SimState = LevelCodec.parse(LevelCodec.from_combined(JUNCTION), PackedStringArray())
	s.player = Vector2i(4, 2)
	assert_true(Junctions.is_new_opening(s, R), "open without the statue")
	assert_false(Junctions.is_new_opening(RuleMemory.scarred(s, Vector2i(4, 1)), R))


func test_each_junction_pauses_once_per_visit() -> void:
	_load(JUNCTION)
	Game.press(R)
	_advance(3 + Game.JUNCTION_PAUSE_TICKS + 2)
	assert_eq(Game.state.player, Vector2i(6, 2), "one pause, then straight on")


func test_rewinding_stops_the_walk() -> void:
	_load(JUNCTION)
	_walk(2)
	assert_true(Game.rewind())
	assert_eq(Game._walking, SimStep.Intent.NONE)
