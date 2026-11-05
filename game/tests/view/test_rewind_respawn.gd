extends GutTest
## Tasks 2.3 + 2.4 in Game: rewind charges, rewinding mid-fall and after death, respawn at the checkpoint.
## Levels are written to user:// so the tests don't depend on the shipped test rooms.

const H = preload("res://tests/sim/sim_helpers.gd")
const PATH: String = "user://test_rewind_level.json"
const SAVE_PATH: String = "user://test_rewind_save.json"


func _load(rows: PackedStringArray, meta: Dictionary = {"gems_required": 0}) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(LevelCodec.from_combined(rows, meta)))
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


func before_each() -> void:
	Save.path = SAVE_PATH
	Save.load_save()


func after_each() -> void:
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	Game.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Save.path = Save.PATH
	Save.load_save()


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


const REMEMBERING: Dictionary = {"gems_required": 0, "remembers": true}
const PIT_ROOM: Array[String] = ["#######", "#@.._.#", "#######"]


func _die_in_the_pit() -> void:
	_load(PIT_ROOM, REMEMBERING)
	_ticks(3, SimStep.Intent.RIGHT)
	assert_false(Game.state.alive)


func test_remembering_level_leaves_a_scar_and_a_remnant() -> void:
	_die_in_the_pit()
	Game.respawn()
	assert_true(Game.state.alive)
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.SCAR)
	assert_true(Game.state.echoes[0].remnant)
	assert_eq(Game.state.echoes[0].inputs.size(), 3, "exactly the moves made while alive")


func test_scars_survive_a_second_death() -> void:
	_die_in_the_pit()
	Game.respawn()
	_ticks(2, SimStep.Intent.RIGHT)
	Game.state.alive = false  # a scar now fills the pit, so end this attempt by hand at (3, 1)
	Game.respawn()
	assert_eq(Game.state.scars.size(), 2)
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.SCAR)
	assert_eq(Game.state.object_at(Vector2i(3, 1)), Tiles.Obj.SCAR)


func test_rewinding_a_death_leaves_no_scar() -> void:
	_die_in_the_pit()
	assert_true(Game.rewind())
	assert_true(Game.state.alive)
	assert_true(Game.state.scars.is_empty())


func test_rewind_shortens_what_the_remnant_replays() -> void:
	_load(["#########", "#@......#", "#########"], REMEMBERING)
	_ticks(3, SimStep.Intent.RIGHT)
	assert_true(Game.rewind())
	assert_eq(Game._attempt.size(), 0, "the hourglass took those moves back")


func test_restart_keeps_the_scars() -> void:
	_die_in_the_pit()
	Game.respawn()
	Game.restart()
	Game.stop()
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.SCAR)
	assert_true(Game.state.echoes.is_empty(), "the remnant only follows a death")


func test_restarting_during_the_respawn_delay_doesnt_dodge_the_scar() -> void:
	_die_in_the_pit()
	Game.restart()
	Game.stop()
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.SCAR)


func test_leaving_during_the_respawn_delay_doesnt_dodge_the_scar() -> void:
	_die_in_the_pit()
	Game.stop()
	assert_eq(Save.scars_of(PATH).size(), 1)


func test_scars_survive_closing_the_game() -> void:
	_die_in_the_pit()
	Game.respawn()
	Save.load_save()  # what the next launch reads from disk
	assert_true(Game.load_level(PATH))
	Game.stop()
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.SCAR)


## Gem at x=2, idol at x=3, pit at x=5.
func _take_gem_light_idol_and_die() -> void:
	_load(["#######", "#@*I._#", "#######"], {"gems_required": 2, "remembers": true})
	_ticks(2, SimStep.Intent.RIGHT)
	assert_eq(Game.state.gems_collected, 1)
	assert_eq(Game.state.terrain_at(Vector2i(3, 1)), Tiles.Terrain.CHECKPOINT_LIT)
	_ticks(2, SimStep.Intent.RIGHT)
	assert_false(Game.state.alive)
	Game.respawn()


func _assert_back_at_the_idol() -> void:
	assert_eq(Game.state.player, Vector2i(3, 1))
	assert_eq(Game.state.gems_collected, 1, "what the idol kept is still kept")
	assert_eq(Game.state.terrain_at(Vector2i(3, 1)), Tiles.Terrain.CHECKPOINT_LIT)
	assert_eq(Game.state.object_at(Vector2i(5, 1)), Tiles.Obj.SCAR)
	assert_eq(Game.state.scars.size(), 1)
	assert_eq(Game.state.hourglass_uses, Game.REWIND_CHARGES)


func test_restart_goes_back_to_the_idol_in_a_remembering_level() -> void:
	_take_gem_light_idol_and_die()
	Game.restart()
	Game.stop()
	_assert_back_at_the_idol()


func test_idol_progress_survives_closing_the_game() -> void:
	_take_gem_light_idol_and_die()
	Save.load_save()  # what the next launch reads from disk
	assert_true(Game.load_level(PATH))
	Game.stop()
	_assert_back_at_the_idol()
	assert_eq(Game.state.hash(), Game._checkpoint.hash())


func test_idol_save_keeps_the_hourglass_uses_left() -> void:
	_load(["#########", "#@..I...#", "#########"], {"gems_required": 0, "remembers": true})
	_ticks(2, SimStep.Intent.RIGHT)
	assert_true(Game.rewind())
	_ticks(3, SimStep.Intent.RIGHT)
	_ticks(RuleEcho.LINGER_TICKS + 5)  # an idol only saves once nothing is moving, and that includes echoes
	assert_false(Save.idol_save_of(PATH).is_empty())
	assert_eq(Game.rewinds_left, Game.REWIND_CHARGES - 1)
	Save.load_save()
	assert_true(Game.load_level(PATH))
	Game.stop()
	assert_eq(Game.rewinds_left, Game.REWIND_CHARGES - 1)


func test_forget_also_wipes_the_idol_save() -> void:
	_take_gem_light_idol_and_die()
	assert_true(Game.forget())
	Game.stop()
	assert_eq(Game.state.player, Vector2i(1, 1))
	assert_eq(Game.state.gems_collected, 0)
	assert_true(Save.idol_save_of(PATH).is_empty())


func test_a_save_that_doesnt_fit_the_level_is_ignored() -> void:
	var s: SimState = H.state(["###", "#@#", "###"])
	assert_null(s.restored({}))
	assert_null(s.restored({"terrain": [0, 0]}))


func test_clean_levels_dont_save_idols() -> void:
	_load(["#####", "#@I.#", "#####"])
	_ticks(1, SimStep.Intent.RIGHT)
	assert_true(Save.idol_save_of(PATH).is_empty())


func test_rewound_death_saves_no_scar() -> void:
	_die_in_the_pit()
	assert_true(Game.rewind())
	Game.stop()
	assert_true(Save.scars_of(PATH).is_empty())


func test_forget_costs_one_and_wipes_the_scars() -> void:
	_die_in_the_pit()
	Game.respawn()
	var before: int = Save.forgets()
	assert_true(Game.forget())
	Game.stop()
	assert_eq(Save.forgets(), before - 1)
	assert_true(Game.state.scars.is_empty())
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.NONE)
	assert_true(Save.scars_of(PATH).is_empty())


func test_forget_does_nothing_without_a_forget_to_spend() -> void:
	_die_in_the_pit()
	Game.respawn()
	Save.data["forgets"] = 0
	assert_false(Game.forget())
	assert_eq(Save.scars_of(PATH).size(), 1)


func test_forget_isnt_spent_when_there_are_no_scars() -> void:
	_load(PIT_ROOM, REMEMBERING)
	var before: int = Save.forgets()
	assert_false(Game.forget())
	assert_eq(Save.forgets(), before)


func test_winning_clears_the_scars_and_earns_a_forget() -> void:
	_load(["#######", "#@.E..#", "#######"], REMEMBERING)
	Save.set_scars(PATH, PackedInt32Array([11]))
	assert_true(Game.load_level(PATH))
	Game.stop()
	var before: int = Save.forgets()
	_ticks(2, SimStep.Intent.RIGHT)
	assert_true(Game.state.won)
	assert_eq(Save.forgets(), before + 1)
	assert_true(Save.scars_of(PATH).is_empty())


func test_forgets_are_capped() -> void:
	for i: int in Save.MAX_FORGETS + 2:
		Save.earn_forget()
	assert_eq(Save.forgets(), Save.MAX_FORGETS)


func test_only_remembering_levels_read_saved_scars() -> void:
	Save.set_scars(PATH, PackedInt32Array([11]))
	_load(["#######", "#@....#", "#######"])
	assert_eq(Game.state.object_at(Vector2i(4, 1)), Tiles.Obj.NONE)


func test_level_can_set_its_hourglass_uses() -> void:
	_load(PIT_ROOM, {"gems_required": 0, "rewinds": 0})
	assert_eq(Game.rewinds_left, 0)
	assert_false(Game.rewind())


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
