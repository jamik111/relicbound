extends GutTest
## Task 2.3: checkpoint idols (sim side).

const H = preload("res://tests/sim/sim_helpers.gd")


func test_stepping_on_idol_lights_it() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@I.#", "#####"]), H.R)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_eq(r.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.CHECKPOINT_LIT)
	assert_eq(r.count_events(SimEvent.Type.CHECKPOINT_LIT), 1)


func test_lit_idol_does_not_relight() -> void:
	var s: SimState = H.run(H.state(["#####", "#@I.#", "#####"]), "RR")
	var r: StepResult = H.step(s, H.L)
	assert_eq(r.state.player, Vector2i(2, 1))
	assert_false(r.has_event(SimEvent.Type.CHECKPOINT_LIT))


func test_falling_boulder_cannot_crush_player_on_idol() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#...#", "#@I.#", "#####"])
	var after: SimState = H.run(s, "R..")
	assert_true(after.alive, "idols are safe spots")
	assert_eq(H.obj(after, 2, 2), Tiles.Obj.BOULDER, "the boulder stops above the idol")
	assert_false(after.is_moving(Vector2i(2, 2)))


func test_objects_cannot_enter_idol() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.I.#", "#@..#", "#####"])
	assert_eq(H.obj(H.run(s, "..."), 2, 1), Tiles.Obj.BOULDER)
	var push: StepResult = H.step(H.state(["#####", "#@XI#", "#####"]), H.R)
	assert_false(push.has_event(SimEvent.Type.OBJECT_PUSHED))
