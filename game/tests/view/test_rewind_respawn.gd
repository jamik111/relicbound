extends GutTest
## Tasks 2.3 + 2.4 in Game: rewind charges, rewinding mid-fall and after death, respawn at the checkpoint.
## Levels are written to user:// so the tests don't depend on the shipped test rooms.

const H = preload("res://tests/sim/sim_helpers.gd")
const PATH: String = "user://test_rewind_level.json"


func _load(rows: PackedStringArray) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(LevelCodec.from_combined(rows, {"gems_required": 0})))
	file.close()
	assert_true(Game.load_level(PATH))
	Game.stop()


func _ticks(n: int, intent: SimStep.Intent = SimStep.Intent.NONE) -> void:
	for i: int in n:
		if intent != SimStep.Intent.NONE:
			Game.press(intent)
		Game._advance()
		Game.release_all()


func after_each() -> void:
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


func test_crush_schedules_respawn() -> void:
	_load(["###", "#O#", "#.#", "#@#", "###"])
	_ticks(2)
	assert_false(Game.state.alive)
	assert_almost_eq(Game._respawn_timer, Game.RESPAWN_DELAY, 0.001)
