extends GutTest
## Task 2.5 part 2: pit viper and cave bat, and how they interact with echoes.

const H = preload("res://tests/sim/sim_helpers.gd")


func _ticks(s: SimState, n: int, inputs: String = "") -> SimState:
	return H.run(s, inputs + ".".repeat(n))


func _killed_by_enemy(r: StepResult) -> bool:
	for e: SimEvent in r.events:
		if e.type == SimEvent.Type.PLAYER_KILLED and e.value == SimEvent.Cause.ENEMY:
			return true
	return false


# --- Viper ---------------------------------------------------------------------

func test_viper_moves_every_few_ticks() -> void:
	var s: SimState = H.state(["#######", "#v....#", "#@....#", "#######"])
	assert_eq(_ticks(s, RuleEnemies.VIPER_MOVE_TICKS - 1).enemies[0].cell, Vector2i(1, 1))
	assert_eq(_ticks(s, RuleEnemies.VIPER_MOVE_TICKS).enemies[0].cell, Vector2i(2, 1))


func test_viper_turns_at_a_wall() -> void:
	var s: SimState = H.state(["#####", "#.v.#", "#@..#", "#####"])
	var after: SimState = _ticks(s, RuleEnemies.VIPER_MOVE_TICKS)
	assert_eq(after.enemies[0].cell, Vector2i(3, 1))
	after = _ticks(after, RuleEnemies.VIPER_MOVE_TICKS)
	assert_eq(after.enemies[0].cell, Vector2i(2, 1), "turned back at the wall")


func test_vertical_viper_patrols_north_south() -> void:
	var s: SimState = H.state(["#####", "#.V.#", "#...#", "#@..#", "#####"])
	assert_eq(_ticks(s, RuleEnemies.VIPER_MOVE_TICKS).enemies[0].cell, Vector2i(2, 2))


func test_crate_blocks_viper() -> void:
	var s: SimState = H.state(["######", "#.vX.#", "#@####", "######"])
	assert_eq(_ticks(s, RuleEnemies.VIPER_MOVE_TICKS).enemies[0].cell, Vector2i(1, 1), "turned at the crate")


func test_viper_touching_player_kills() -> void:
	var s: SimState = H.state(["#####", "#v@.#", "#####"])
	var state: SimState = _ticks(s, RuleEnemies.VIPER_MOVE_TICKS - 1)
	var r: StepResult = H.step(state)
	assert_false(r.state.alive)
	assert_true(_killed_by_enemy(r))


func test_player_walking_into_viper_dies_and_cannot_swap_past() -> void:
	var s: SimState = H.state(["#####", "#@v.#", "#####"])
	var r: StepResult = H.step(s, H.R)
	assert_false(r.state.alive)


func test_falling_boulder_kills_viper() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#...#", "#.v.#", "#@..#", "#####"])
	var after: SimState = _ticks(s, 2)
	assert_eq(after.enemies.size(), 0)
	assert_true(after.alive)


func test_viper_wont_enter_dirt_pits_or_idols() -> void:
	for wall: String in [":", "_", "I"]:
		var s: SimState = H.state(["#####", "#v" + wall + ".#", "#@..#", "#####"])
		assert_eq(_ticks(s, RuleEnemies.VIPER_MOVE_TICKS).enemies[0].cell, Vector2i(1, 1), wall)


# --- Bat -----------------------------------------------------------------------

func test_bat_flies_diagonally_through_walls() -> void:
	var s: SimState = H.state(["w#####", "#####.", "#####@"])
	assert_eq(_ticks(s, RuleEnemies.BAT_MOVE_TICKS).enemies[0].cell, Vector2i(1, 1))


func test_bat_bounces_off_the_map_edge() -> void:
	var s: SimState = H.state(["....w", ".....", "@...."])
	var after: SimState = _ticks(s, RuleEnemies.BAT_MOVE_TICKS)
	assert_eq(after.enemies[0].cell, Vector2i(3, 1))


func test_bat_kills_and_boulders_dont_stop_it() -> void:
	var s: SimState = H.state(["w....", ".@..."])
	var r: StepResult = H.step(_ticks(s, RuleEnemies.BAT_MOVE_TICKS - 1))
	assert_false(r.state.alive)
	assert_true(_killed_by_enemy(r))


# --- Echoes and idols ------------------------------------------------------------

func test_viper_destroys_echo_and_turns_back() -> void:
	var s: SimState = RuleEcho.spawned(H.state(["#######", "#v.@..#", "#######"]), PackedInt32Array())
	s.player = Vector2i(5, 1)
	s.echoes[0].cell = Vector2i(2, 1)
	var r: StepResult = H.step(_ticks(s, RuleEnemies.VIPER_MOVE_TICKS - 1))
	assert_eq(r.state.echoes.size(), 0)
	assert_true(r.has_event(SimEvent.Type.ECHO_DESTROYED))
	assert_eq(r.state.enemies[0].cell, Vector2i(1, 1))
	assert_eq(r.state.enemies[0].dir, Vector2i.LEFT)
	assert_true(r.state.alive)


func test_idol_is_safe_from_enemies() -> void:
	var s: SimState = H.run(H.state(["w.....", ".I....", "@....."]), "U")
	s = H.run(s, "R")
	assert_eq(s.player, Vector2i(1, 1))
	assert_true(H.run(s, "...").alive)


# --- State ---------------------------------------------------------------------

func test_copy_is_deep_and_hash_sees_enemies() -> void:
	var a: SimState = H.state(["#####", "#.v@#", "#####"])
	var b: SimState = a.copy()
	assert_eq(a.hash(), b.hash())
	b.enemies[0].cell = Vector2i(1, 1)
	assert_eq(a.enemies[0].cell, Vector2i(2, 1))
	assert_ne(a.hash(), b.hash())


func test_enemy_steps_are_deterministic() -> void:
	var s: SimState = H.state(["w....v...", ".........", "@........"])
	assert_eq(_ticks(s, 40).hash(), _ticks(s, 40).hash())
