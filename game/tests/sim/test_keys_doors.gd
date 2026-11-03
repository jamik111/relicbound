extends GutTest
## Task 1.4: keys and doors (4 colours, each with its own shape).

const H = preload("res://tests/sim/sim_helpers.gd")


func test_collect_key() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@b.#", "#####"]), H.R)
	assert_eq(r.state.keys[Tiles.KeyColor.BLUE], 1)
	assert_eq(H.obj(r.state, 2, 1), Tiles.Obj.NONE)
	assert_true(r.has_event(SimEvent.Type.KEY_COLLECTED))


func test_door_blocks_without_key() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@R.#", "#####"]), H.R)
	assert_eq(r.state.player, Vector2i(1, 1))
	assert_eq(r.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.DOOR_RED)


func test_matching_key_opens_door_and_is_used_up() -> void:
	var s: SimState = H.state(["######", "#r@R.#", "######"])
	var after: SimState = H.run(s, "LRR")
	assert_eq(after.player, Vector2i(3, 1))
	assert_eq(after.terrain_at(Vector2i(3, 1)), Tiles.Terrain.FLOOR)
	assert_eq(after.keys[Tiles.KeyColor.RED], 0)


func test_door_opened_event_carries_colour() -> void:
	var s: SimState = H.run(H.state(["######", "#j@J.#", "######"]), "LR")
	var r: StepResult = H.step(s, H.R)
	assert_true(r.has_event(SimEvent.Type.DOOR_OPENED))
	var e: SimEvent = r.events.filter(func(ev: SimEvent) -> bool: return ev.type == SimEvent.Type.DOOR_OPENED)[0]
	assert_eq(e.value, Tiles.KeyColor.JADE)


func test_wrong_colour_key_does_not_open() -> void:
	var s: SimState = H.state(["######", "#g@B.#", "######"])
	var after: SimState = H.run(s, "LRR")
	assert_eq(after.player, Vector2i(2, 1))
	assert_eq(after.keys[Tiles.KeyColor.GOLD], 1)


func test_one_key_opens_one_door() -> void:
	var s: SimState = H.state(["#######", "#r@RR.#", "#######"])
	var after: SimState = H.run(s, "LRRR")
	assert_eq(after.player, Vector2i(3, 1))
	assert_eq(after.terrain_at(Vector2i(4, 1)), Tiles.Terrain.DOOR_RED)


func test_keys_do_not_fall() -> void:
	var s: SimState = H.state(["#####", "#.r.#", "#...#", "#@..#", "#####"])
	assert_eq(H.obj(H.run(s, ".."), 2, 1), Tiles.Obj.KEY_RED)


func test_door_stops_falling_objects() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.R.#", "#@..#", "#####"])
	assert_eq(H.obj(H.run(s, ".."), 2, 1), Tiles.Obj.BOULDER)
