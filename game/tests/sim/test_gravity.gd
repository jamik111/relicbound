extends GutTest
## Task 1.3: gravity, rolling, and crushing only while moving.

const H = preload("res://tests/sim/sim_helpers.gd")


func test_boulder_falls_and_becomes_moving() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@O.#", "#...#", "#####"]))
	assert_eq(H.obj(r.state, 2, 2), Tiles.Obj.BOULDER)
	assert_true(r.state.is_moving(Vector2i(2, 2)))
	assert_true(r.has_event(SimEvent.Type.OBJECT_FELL))


func test_falls_one_tile_per_tick_then_lands() -> void:
	var s: SimState = H.state(["#####", "#@O.#", "#...#", "#...#", "#####"])
	var r1: StepResult = H.step(s)
	var r2: StepResult = H.step(r1.state)
	assert_eq(H.obj(r2.state, 2, 3), Tiles.Obj.BOULDER)
	var r3: StepResult = H.step(r2.state)
	assert_true(r3.has_event(SimEvent.Type.OBJECT_LANDED))
	assert_false(r3.state.is_moving(Vector2i(2, 3)))


func test_resting_boulder_above_player_is_safe() -> void:
	# The player walks under a resting boulder that sits on dirt they just dug.
	var s: SimState = H.state(["#####", "#.O.#", "#@:.#", "#####"])
	var r: StepResult = H.step(s, H.R)
	assert_eq(r.state.player, Vector2i(2, 2))
	assert_true(r.state.alive)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.BOULDER)


func test_leaving_from_under_boulder_starts_its_fall() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.@.#", "#...#", "#####"])
	var r: StepResult = H.step(s, H.R)
	assert_true(r.state.alive)
	assert_eq(H.obj(r.state, 2, 2), Tiles.Obj.BOULDER)
	assert_true(r.state.is_moving(Vector2i(2, 2)))


func test_falling_boulder_crushes_player() -> void:
	var s: SimState = H.state(["###", "#O#", "#.#", "#@#", "###"])
	var r1: StepResult = H.step(s)
	assert_true(r1.state.alive)
	var r2: StepResult = H.step(r1.state)
	assert_false(r2.state.alive)
	assert_true(r2.has_event(SimEvent.Type.PLAYER_CRUSHED))


func test_stepping_under_falling_boulder_crushes() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#...#", "#@..#", "#####"])
	# Tick 1: the boulder starts falling (now moving at (2,2)). Tick 2: the player steps right under it.
	var r1: StepResult = H.step(s, H.NONE)
	assert_true(r1.state.is_moving(Vector2i(2, 2)))
	var r2: StepResult = H.step(r1.state, H.R)
	assert_eq(r2.state.player, Vector2i(2, 3))
	assert_false(r2.state.alive)


func test_falling_crate_crushes_too() -> void:
	var s: SimState = H.state(["###", "#X#", "#.#", "#@#", "###"])
	assert_false(H.run(s, "..").alive)


func test_stacked_column_falls_together() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.O.#", "#...#", "#@..#", "#####"])
	var r: StepResult = H.step(s)
	assert_eq(H.obj(r.state, 2, 2), Tiles.Obj.BOULDER)
	assert_eq(H.obj(r.state, 2, 3), Tiles.Obj.BOULDER)
	assert_eq(r.count_events(SimEvent.Type.OBJECT_FELL), 2)


func test_boulder_rolls_west_first() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.O.#", "##@##", "#####"])
	var r: StepResult = H.step(s)
	assert_eq(H.obj(r.state, 1, 1), Tiles.Obj.BOULDER)
	assert_true(r.has_event(SimEvent.Type.OBJECT_ROLLED))


func test_boulder_rolls_east_when_west_blocked() -> void:
	var s: SimState = H.state(["#####", "##O.#", "#.O.#", "##@##", "#####"])
	var r: StepResult = H.step(s)
	assert_eq(H.obj(r.state, 3, 1), Tiles.Obj.BOULDER)


func test_no_roll_when_tile_below_side_is_blocked() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "##O##", "##@##", "#####"])
	var r: StepResult = H.step(s)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.BOULDER)
	assert_false(r.has_event(SimEvent.Type.OBJECT_ROLLED))


func test_nothing_rolls_off_a_crate() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.X.#", "##@##", "#####"])
	assert_eq(H.obj(H.step(s).state, 2, 1), Tiles.Obj.BOULDER)


func test_crate_does_not_roll_off_boulder() -> void:
	var s: SimState = H.state(["#####", "#.X.#", "#.O.#", "##@##", "#####"])
	assert_eq(H.obj(H.step(s).state, 2, 1), Tiles.Obj.CRATE)


func test_gem_rolls_off_boulder() -> void:
	var s: SimState = H.state(["#####", "#.*.#", "#.O.#", "##@##", "#####"])
	assert_eq(H.obj(H.step(s).state, 1, 1), Tiles.Obj.GEM)


func test_rolled_boulder_then_falls() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.O.#", "#.#@#", "#####"])
	var s2: SimState = H.run(s, "..")
	assert_eq(H.obj(s2, 1, 2), Tiles.Obj.BOULDER)


func test_dirt_supports_objects() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.:.#", "#@..#", "#####"])
	assert_eq(H.obj(H.run(s, "..."), 2, 1), Tiles.Obj.BOULDER)
