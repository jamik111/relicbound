extends GutTest
## Task 1.3: walking and digging.

const H = preload("res://tests/sim/sim_helpers.gd")


func test_walk_onto_floor() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@..#", "#####"]), H.R)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_true(r.has_event(SimEvent.Type.PLAYER_MOVED))


func test_walk_all_four_directions() -> void:
	var s: SimState = H.state(["#####", "#...#", "#.@.#", "#...#", "#####"])
	assert_eq(H.step(s, H.U).state.player, Vector2i(2, 1))
	assert_eq(H.step(s, H.D).state.player, Vector2i(2, 3))
	assert_eq(H.step(s, H.L).state.player, Vector2i(1, 2))
	assert_eq(H.step(s, H.R).state.player, Vector2i(3, 2))


func test_wall_blocks() -> void:
	var r: StepResult = H.step(H.state(["###", "#@#", "###"]), H.L)
	assert_eq(r.state.player, Vector2i(1, 1))
	assert_true(r.has_event(SimEvent.Type.PLAYER_BLOCKED))
	assert_false(r.has_event(SimEvent.Type.PLAYER_MOVED))


func test_ancient_wall_blocks() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@%.#", "#####"]), H.R)
	assert_eq(r.state.player, Vector2i(1, 1))


func test_map_edge_blocks() -> void:
	var r: StepResult = H.step(H.state(["@.."]), H.L)
	assert_eq(r.state.player, Vector2i(0, 0))


func test_dig_dirt() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@:.#", "#####"]), H.R)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_eq(r.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.FLOOR)
	assert_true(r.has_event(SimEvent.Type.DIRT_DUG))


func test_no_input_does_nothing() -> void:
	var s: SimState = H.state(["#####", "#@..#", "#####"])
	var r: StepResult = H.step(s, H.NONE)
	assert_eq(r.state.player, s.player)
	assert_eq(r.events.size(), 0)


func test_facing_updates_even_when_blocked() -> void:
	var r: StepResult = H.step(H.state(["###", "#@#", "###"]), H.U)
	assert_eq(r.state.facing, Vector2i.UP)


func test_dead_player_ignores_input() -> void:
	var s: SimState = H.state(["#####", "#@..#", "#####"])
	s.alive = false
	assert_eq(H.step(s, H.R).state.player, Vector2i(1, 1))
