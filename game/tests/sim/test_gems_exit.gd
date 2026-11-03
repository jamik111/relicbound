extends GutTest
## Task 1.4: gems and the exit quota.

const H = preload("res://tests/sim/sim_helpers.gd")


func test_walk_collects_gem() -> void:
	var r: StepResult = H.step(H.state(["######", "#@*.E#", "######"]), H.R)
	assert_eq(r.state.gems_collected, 1)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.NONE)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_true(r.has_event(SimEvent.Type.GEM_COLLECTED))


func test_falling_gem_is_caught_not_deadly() -> void:
	var s: SimState = H.state(["###", "#*#", "#.#", "#@#", "#E#", "###"])
	var after: SimState = H.run(s, "..")
	assert_true(after.alive)
	assert_eq(after.gems_collected, 1)
	assert_eq(after.count_objects(Tiles.Obj.GEM), 0)


func test_gems_required_defaults_to_all_gems() -> void:
	assert_eq(H.state(["#######", "#@**.E#", "#######"]).gems_required, 2)


func test_exit_closed_until_quota() -> void:
	var s: SimState = H.state(["######", "#*@E.#", "######"])
	assert_false(s.exit_open)
	var r: StepResult = H.step(s, H.R)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_false(r.state.won)
	assert_true(r.has_event(SimEvent.Type.PLAYER_BLOCKED))


func test_exit_opens_once_when_quota_met() -> void:
	var s: SimState = H.state(["######", "#*@E.#", "######"])
	var r1: StepResult = H.step(s, H.L)
	assert_true(r1.state.exit_open)
	assert_eq(r1.count_events(SimEvent.Type.EXIT_OPENED), 1)
	assert_eq(r1.events.filter(func(e: SimEvent) -> bool: return e.type == SimEvent.Type.EXIT_OPENED)[0].cell,
		Vector2i(3, 1))
	var r2: StepResult = H.step(r1.state)
	assert_false(r2.has_event(SimEvent.Type.EXIT_OPENED))


func test_entering_open_exit_wins() -> void:
	var s: SimState = H.state(["######", "#*@E.#", "######"])
	var r: StepResult = H.step(H.run(s, "LR"), H.R)
	assert_true(r.state.won)
	assert_eq(r.state.player, Vector2i(3, 1))
	assert_true(r.has_event(SimEvent.Type.LEVEL_COMPLETED))


func test_input_ignored_after_win() -> void:
	var s: SimState = H.state(["#####", "#@E.#", "#####"], {"gems_required": 0})
	var won: SimState = H.run(s, "R")
	assert_true(won.won)
	assert_eq(H.step(won, H.R).state.player, Vector2i(2, 1))


func test_zero_quota_exit_open_from_start() -> void:
	assert_true(H.state(["#####", "#@E.#", "#####"], {"gems_required": 0}).exit_open)


func test_partial_quota() -> void:
	var s: SimState = H.state(["#######", "#**@E.#", "#######"], {"gems_required": 1})
	var r: StepResult = H.step(s, H.L)
	assert_true(r.state.exit_open)
	assert_eq(r.state.count_objects(Tiles.Obj.GEM), 1)
