extends GutTest
## Task 1.3: pushing boulders (sideways only) and crates (any direction).

const H = preload("res://tests/sim/sim_helpers.gd")


func test_push_boulder_right() -> void:
	var r: StepResult = H.step(H.state(["######", "#@O..#", "######"]), H.R)
	assert_eq(H.obj(r.state, 3, 1), Tiles.Obj.BOULDER)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.NONE)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_true(r.has_event(SimEvent.Type.OBJECT_PUSHED))


func test_push_boulder_left() -> void:
	var r: StepResult = H.step(H.state(["######", "#..O@#", "######"]), H.L)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.BOULDER)
	assert_eq(r.state.player, Vector2i(3, 1))


func test_boulder_cannot_be_pushed_vertically() -> void:
	var s: SimState = H.state(["###", "#.#", "#O#", "#@#", "###"])
	var r: StepResult = H.step(s, H.U)
	assert_eq(H.obj(r.state, 1, 2), Tiles.Obj.BOULDER)
	assert_eq(r.state.player, Vector2i(1, 3))
	assert_true(r.has_event(SimEvent.Type.PLAYER_BLOCKED))


func test_push_blocked_by_wall() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@O##", "#####"]), H.R)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.BOULDER)
	assert_eq(r.state.player, Vector2i(1, 1))


func test_no_chain_pushing() -> void:
	var r: StepResult = H.step(H.state(["#######", "#@OO..#", "#######"]), H.R)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.BOULDER)
	assert_eq(H.obj(r.state, 3, 1), Tiles.Obj.BOULDER)
	assert_eq(r.state.player, Vector2i(1, 1))


func test_cannot_push_into_dirt() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@O:#", "#####"]), H.R)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.BOULDER)


func test_crate_pushed_up_rests_on_player() -> void:
	var s: SimState = H.state(["###", "#.#", "#X#", "#@#", "###"])
	var r: StepResult = H.step(s, H.U)
	assert_eq(H.obj(r.state, 1, 1), Tiles.Obj.CRATE)
	assert_eq(r.state.player, Vector2i(1, 2))
	# Resting on the player's head is safe.
	var r2: StepResult = H.step(r.state)
	assert_true(r2.state.alive)
	assert_false(r2.state.is_moving(Vector2i(1, 1)))


func test_crate_pushed_down() -> void:
	var r: StepResult = H.step(H.state(["###", "#@#", "#X#", "#.#", "###"]), H.D)
	assert_eq(H.obj(r.state, 1, 3), Tiles.Obj.CRATE)
	assert_eq(r.state.player, Vector2i(1, 2))


func test_cannot_push_moving_object() -> void:
	var s: SimState = H.state(["######", "#@O..#", "#.....", "######"])
	s.set_moving(Vector2i(2, 1), true)
	var r: StepResult = H.step(s, H.R)
	assert_eq(r.state.player, Vector2i(1, 1))
	assert_false(r.has_event(SimEvent.Type.OBJECT_PUSHED))


func test_pushed_off_ledge_falls_next_tick_not_same_tick() -> void:
	var s: SimState = H.state(["#####", "#@O.#", "###.#", "#####"])
	var r: StepResult = H.step(s, H.R)
	assert_eq(H.obj(r.state, 3, 1), Tiles.Obj.BOULDER, "moved sideways only this tick")
	var r2: StepResult = H.step(r.state)
	assert_eq(H.obj(r2.state, 3, 2), Tiles.Obj.BOULDER, "falls on the next tick")
	assert_true(r2.has_event(SimEvent.Type.OBJECT_FELL))
