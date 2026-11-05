extends GutTest
## Tasks 2.3 + 2.4 in Game: rewind charges, rewinding mid-fall and after death, respawn at the checkpoint.
## Levels are written to user:// so the tests don't depend on the shipped test rooms.

const H = preload("res://tests/sim/sim_helpers.gd")
const PATH: String = "user://test_rewind_level.json"


func _load(rows: PackedStringArray) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(LevelCodec.from_combined(rows, {"gems_required": 0})))
	file.close()
	Game.move_interval_ticks = 1
	assert_true(Game.load_level(PATH))
	Game.stop()


func _ticks(n: int, intent: SimStep.Intent = SimStep.Intent.NONE) -> void:
	for i: int in n:
		if intent != SimStep.Intent.NONE:
			Game.press(intent)
		Game._advance()
		Game.release_all()


func after_each() -> void:
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	Game.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_rewind_goes_back_up_to_30_ticks() -> void:
	_load(["##########################################", "#@.......................................#",
		"##########################################"])
	_ticks(35, SimStep.Intent.RIGHT)
	assert_eq(Game.state.player, Vector2i(36, 1))
	assert_true(Game.rewind())
	assert_eq(Game.state.tick, 5, "30 ticks back")
	assert_eq(Game.state.player, Vector2i(6, 1))
	assert_eq(Game.rewinds_left, Game.REWIND_CHARGES - 1)


func test_rewind_charges_run_out() -> void:
	_load(["#######", "#@....#", "#######"])
	for i: int in Game.REWIND_CHARGES:
		_ticks(2)
		assert_true(Game.rewind())
	_ticks(2)
	assert_false(Game.rewind())
	assert_eq(Game.rewinds_left, 0)


func test_rewind_mid_fall_restores_moving_flag() -> void:
	_load(["###", "#O#", "#.#", "#.#", "#.#", "#@#", "###"])
	_ticks(2)
	assert_true(Game.state.is_moving(Vector2i(1, 3)))
	_ticks(1)
	assert_true(Game.rewind())
	assert_eq(Game.state.tick, 0)
	_ticks(2)
	assert_true(Game.state.is_moving(Vector2i(1, 3)), "replays identically after rewind")


func test_rewind_undoes_a_crush() -> void:
	_load(["###", "#O#", "#.#", "#@#", "###"])
	_ticks(2)
	assert_false(Game.state.alive)
	assert_true(Game.rewind())
	assert_true(Game.state.alive)


func test_respawn_at_lit_checkpoint_after_delay() -> void:
	_load(["#######", "#@I...#", "#####.#", "#O....#", "#.....#", "#######"])
	_ticks(1, SimStep.Intent.RIGHT)
	assert_eq(Game.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.CHECKPOINT_LIT)
	_ticks(3)  # the room's boulder lands, so the checkpoint saves
	# Stand-in for a crush (the respawn path is what's under test). Use a copy: stored states are
	# never modified, and the checkpoint snapshot is this very object.
	var dead: SimState = Game.state.copy()
	dead.alive = false
	Game.state = dead
	Game._respawn_timer = Game.RESPAWN_DELAY
	Game.running = true
	Game._process(Game.RESPAWN_DELAY * 0.5)
	assert_false(Game.state.alive, "not yet")
	Game._process(Game.RESPAWN_DELAY)
	Game.stop()
	assert_true(Game.state.alive)
	assert_eq(Game.state.player, Vector2i(2, 1), "back on the idol")
	assert_lt(Game.RESPAWN_DELAY, 1.2, "roadmap 2.3: respawn within 1.2 s")


func test_checkpoint_waits_until_nothing_is_moving() -> void:
	_load(["#######", "#@I..O#", "#####.#", "#####.#", "#######"])
	var start: SimState = Game._checkpoint
	_ticks(1, SimStep.Intent.RIGHT)
	assert_eq(Game.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.CHECKPOINT_LIT)
	assert_eq(Game._checkpoint, start, "boulder is falling: not saved yet")
	_ticks(1)
	assert_eq(Game._checkpoint, start, "still falling")
	_ticks(1)
	assert_eq(Game._checkpoint, Game.state, "landed: saved now")


func test_checkpoint_saves_at_once_in_a_still_room() -> void:
	_load(["#####", "#@I.#", "#####"])
	_ticks(1, SimStep.Intent.RIGHT)
	assert_eq(Game._checkpoint, Game.state)


func test_death_cancels_a_waiting_checkpoint() -> void:
	# The boulder keeps the room unsettled; the player leaves the idol and walks into the pit.
	_load(["########", "#@I_..O#", "######.#", "######.#", "########"])
	var start: SimState = Game._checkpoint
	_ticks(1, SimStep.Intent.RIGHT)
	_ticks(1, SimStep.Intent.RIGHT)
	assert_false(Game.state.alive)
	_ticks(3)
	assert_eq(Game._checkpoint, start, "respawn goes back to the level start")


func test_dying_gives_back_the_uses_from_the_level_start() -> void:
	_load(["#######", "#@....#", "#######"])
	_ticks(2)
	assert_true(Game.rewind())
	_ticks(2)
	assert_true(Game.rewind())
	assert_eq(Game.rewinds_left, Game.REWIND_CHARGES - 2)
	Game.respawn()
	assert_eq(Game.rewinds_left, Game.REWIND_CHARGES)
	assert_eq(Game.state.echoes.size(), 0, "the echoes they made are gone too")


func test_dying_gives_back_only_the_uses_held_at_the_checkpoint() -> void:
	_load(["#######", "#.@I..#", "#######"])
	_ticks(2)
	assert_true(Game.rewind())
	var spent: int = Game.rewinds_left
	_ticks(RuleEcho.LINGER_TICKS + 3)  # the echo fades, so the room can settle and save
	_ticks(1, SimStep.Intent.RIGHT)
	assert_eq(Game._checkpoint, Game.state, "saved on the idol")
	_ticks(2)
	assert_true(Game.rewind())
	Game.respawn()
	assert_eq(Game.rewinds_left, spent)


func test_crush_schedules_respawn() -> void:
	_load(["###", "#O#", "#.#", "#@#", "###"])
	_ticks(2)
	assert_false(Game.state.alive)
	assert_almost_eq(Game._respawn_timer, Game.RESPAWN_DELAY, 0.001)
