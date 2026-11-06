extends GutTest
## Forgiving turns while walking (CornerAssist through Game's input buffer). One move per tick for readable tests.

const PATH: String = "user://test_corner_level.json"
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


func _walk(steps: int) -> void:
	Game.press(R)
	for i: int in steps:
		Game._advance()
	Game.release_all()


func _turn_up() -> void:
	Game.press(U)


func after_each() -> void:
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	Game.release_all()
	Game.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_turn_on_the_junction_is_immediate() -> void:
	_load(JUNCTION)
	_walk(3)
	assert_eq(Game.state.player, Vector2i(4, 2))
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 1))


func test_turning_one_tile_early_walks_to_the_opening_then_turns() -> void:
	_load(JUNCTION)
	_walk(2)
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 2))
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 1))


func test_turning_two_tiles_early_also_works() -> void:
	_load(JUNCTION)
	_walk(1)
	_turn_up()
	for i: int in 3:
		Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 1))


func test_turning_three_tiles_early_just_stops_you() -> void:
	_load(["##########", "#####.####", "#@.......#", "##########"])
	_walk(1)
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 2), "the opening is out of reach")


func test_a_quick_flick_still_makes_the_turn() -> void:
	_load(JUNCTION)
	_walk(2)
	Game.press(U)
	Game.release(U)
	Game._advance()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 1), "the finger has lifted, but the turn stays queued")


func test_turning_one_tile_late_steps_back_then_turns() -> void:
	_load(JUNCTION)
	_walk(4)
	assert_eq(Game.state.player, Vector2i(5, 2))
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 2))
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 1))


func test_turning_two_tiles_late_just_stops_you() -> void:
	_load(JUNCTION)
	_walk(5)
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(6, 2))


func test_standing_still_gets_no_help() -> void:
	_load(JUNCTION)
	_walk(2)
	Game._advance()  # nothing held: the player has stopped
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(3, 2), "no walking off on its own")


func test_assist_stops_after_it_bumps() -> void:
	_load(JUNCTION)
	_walk(5)
	_turn_up()
	Game._advance()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(6, 2), "still against the wall, not drifting back")


func test_it_wont_walk_you_into_a_pit() -> void:
	_load(["#########", "####.####", "#@._....#", "#########"])
	_walk(1)
	_turn_up()
	Game._advance()
	assert_true(Game.state.alive)
	assert_eq(Game.state.player, Vector2i(2, 2))


func test_it_wont_step_back_onto_cracked_floor() -> void:
	_load(["#########", "###.#####", "#@.=....#", "#########"])
	_walk(3)
	assert_eq(Game.state.player, Vector2i(4, 2))
	_turn_up()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(4, 2))


func test_it_wont_push_an_object_for_you() -> void:
	_load(["#########", "####.####", "#@..X...#", "#########"])
	_walk(1)
	_turn_up()
	Game._advance()
	Game._advance()
	assert_eq(Game.state.object_at(Vector2i(4, 2)), Tiles.Obj.CRATE)


func test_a_pit_doesnt_count_as_an_opening() -> void:
	_load(["#########", "####_####", "#@......#", "#########"])
	_walk(2)
	_turn_up()
	Game._advance()
	Game._advance()
	assert_true(Game.state.alive)
	assert_eq(Game.state.player, Vector2i(3, 2))


func test_a_statue_counts_as_a_wall() -> void:
	var s: SimState = RuleMemory.scarred(LevelCodec.parse(LevelCodec.from_combined(JUNCTION), PackedStringArray()), Vector2i(4, 1))
	assert_true(CornerAssist.is_blocked(s, Vector2i(4, 1)))


func test_turning_into_open_floor_is_never_changed() -> void:
	var s: SimState = LevelCodec.parse(LevelCodec.from_combined(["#####", "#...#", "#@..#", "#####"]), PackedStringArray())
	assert_eq(CornerAssist.resolve(s, U, R), U)


func test_reversing_is_never_changed() -> void:
	var s: SimState = LevelCodec.parse(LevelCodec.from_combined(JUNCTION), PackedStringArray())
	assert_eq(CornerAssist.resolve(s, SimStep.Intent.LEFT, R), SimStep.Intent.LEFT)


func test_rewinding_stops_the_walk() -> void:
	_load(JUNCTION)
	_walk(2)
	assert_true(Game.rewind())
	assert_eq(Game._walking, SimStep.Intent.NONE)
