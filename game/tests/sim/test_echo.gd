extends GutTest
## Echoes: the signature mechanic. An hourglass use rewinds and leaves a ghost replaying the recorded inputs.

const H = preload("res://tests/sim/sim_helpers.gd")


func _with_echo(s: SimState, inputs: String) -> SimState:
	return RuleEcho.spawned(s, Replay.parse_inputs(inputs))


func test_echo_replays_inputs_while_the_player_acts_freely() -> void:
	var s: SimState = _with_echo(H.state(["######", "#@...#", "#....#", "######"]), "RR")
	var after: SimState = H.run(s, "D.")
	assert_eq(after.echoes[0].cell, Vector2i(3, 1))
	assert_eq(after.player, Vector2i(1, 2))


func test_echo_lingers_then_fades() -> void:
	var s: SimState = _with_echo(H.state(["####", "#@.#", "####"]), "")
	for i: int in RuleEcho.LINGER_TICKS - 1:
		s = H.step(s).state
	assert_eq(s.echoes.size(), 1, "still holding")
	var r: StepResult = H.step(s)
	assert_eq(r.state.echoes.size(), 0)
	assert_true(r.has_event(SimEvent.Type.ECHO_FADED))


func test_echo_pushes_a_boulder() -> void:
	var s: SimState = _with_echo(H.state(["#####", "#@O.#", "#####"]), "R")
	var after: SimState = H.step(s).state
	assert_eq(H.obj(after, 3, 1), Tiles.Obj.BOULDER)
	assert_eq(after.echoes[0].cell, Vector2i(2, 1))


func test_echo_digs_dirt() -> void:
	var after: SimState = H.step(_with_echo(H.state(["#####", "#@:.#", "#####"]), "R")).state
	assert_eq(after.terrain_at(Vector2i(2, 1)), Tiles.Terrain.FLOOR)
	assert_eq(after.echoes[0].cell, Vector2i(2, 1))


func test_echo_passes_gems_and_keys_without_taking_them() -> void:
	var after: SimState = H.run(_with_echo(H.state(["######", "#@*r.#", "######"]), "RR"), "..")
	assert_eq(after.gems_collected, 0)
	assert_eq(H.obj(after, 2, 1), Tiles.Obj.GEM)
	assert_eq(H.obj(after, 3, 1), Tiles.Obj.KEY_RED)
	assert_eq(after.echoes[0].cell, Vector2i(3, 1))


func test_echo_cannot_open_doors_or_use_the_exit() -> void:
	var door: SimState = H.step(_with_echo(H.state(["#####", "#@R.#", "#####"]), "R")).state
	assert_eq(door.echoes[0].cell, Vector2i(1, 1))
	var gate: SimState = H.step(_with_echo(H.state(["#####", "#@E.#", "#####"], {"gems_required": 0}), "R")).state
	assert_eq(gate.echoes[0].cell, Vector2i(1, 1))
	assert_false(gate.won)


func test_echo_doesnt_light_idols() -> void:
	var after: SimState = H.step(_with_echo(H.state(["#####", "#@I.#", "#####"]), "R")).state
	assert_eq(after.terrain_at(Vector2i(2, 1)), Tiles.Terrain.CHECKPOINT)
	assert_eq(after.echoes[0].cell, Vector2i(2, 1))


func test_player_walks_through_echo() -> void:
	var after: SimState = H.step(_with_echo(H.state(["#####", "#@..#", "#####"]), ""), H.R).state
	assert_eq(after.player, Vector2i(2, 1))


func test_falling_boulder_destroys_echo() -> void:
	var s: SimState = _with_echo(H.state(["#####", "#.O.#", "#...#", "#@..#", "#####"]), "R")
	var r: StepResult = H.step(s, H.L)
	assert_eq(r.state.echoes.size(), 1, "boulder is only starting to fall")
	var r2: StepResult = H.step(r.state)
	assert_eq(r2.state.echoes.size(), 0)
	assert_true(r2.has_event(SimEvent.Type.ECHO_DESTROYED))
	assert_true(r2.state.alive)


func test_echo_takes_a_dart_for_the_player() -> void:
	var s: SimState = _with_echo(H.state(["########", "#>...@.#", "########"]), "LL")
	while s.tick < RuleHazards.DART_PERIOD - 1:
		var linger_guard: SimEcho = s.echoes[0]
		linger_guard.linger = 999
		s = H.step(s).state
	var r: StepResult = H.step(s)
	assert_true(r.state.alive, "the dart stopped at the echo")
	assert_eq(r.state.echoes.size(), 0)


func test_pit_destroys_echo() -> void:
	assert_eq(H.step(_with_echo(H.state(["#####", "#@_.#", "#####"]), "R")).state.echoes.size(), 0)


# --- Plates and gates ---------------------------------------------------------

func test_gate_blocks_until_plate_is_held() -> void:
	var s: SimState = H.state(["######", "#P@H.#", "######"])
	var closed: StepResult = H.step(s, H.R)
	assert_eq(closed.state.player, Vector2i(2, 1), "gate is shut")
	var on_plate: StepResult = H.step(closed.state, H.L)
	assert_true(on_plate.state.gates_open)
	assert_true(on_plate.has_event(SimEvent.Type.GATE_OPENED))
	var off_plate: StepResult = H.step(on_plate.state, H.R)
	assert_false(off_plate.state.gates_open, "stepping off shuts it")
	assert_true(off_plate.has_event(SimEvent.Type.GATE_CLOSED))


func test_crate_holds_a_plate() -> void:
	var s: SimState = H.state(["######", "#@XP.#", "######"])
	assert_true(H.step(s, H.R).state.gates_open)


func test_echo_holds_a_plate_and_the_player_passes_the_gate() -> void:
	var s: SimState = _with_echo(H.state(["#######", "#P@H..#", "#######"]), "L")
	var open: SimState = H.step(s).state
	assert_true(open.gates_open)
	var through: SimState = H.step(open, H.R).state
	assert_eq(through.player, Vector2i(3, 1))


func test_two_plates_both_needed() -> void:
	var one: SimState = H.step(H.state(["##########", "#P@.....P#", "#####H####", "##########"]), H.L).state
	assert_false(one.gates_open, "one of two plates isn't enough")
	var both: SimState = H.step(RuleEcho.spawned(H.state(["##########", "#P@.....P#", "#####H####", "##########"]),
		Replay.parse_inputs("RRRRRR")), H.L).state
	assert_false(both.gates_open, "the echo hasn't arrived yet")
	for i: int in 5:
		both = H.step(both).state
	assert_true(both.gates_open, "the player on one plate and the echo on the other")


func test_gate_wont_close_on_someone_standing_in_it() -> void:
	var s: SimState = H.state(["#######", "#P@H..#", "#######"])
	s.gates_open = true
	s.player = Vector2i(3, 1)
	var r: StepResult = H.step(s)
	assert_true(r.state.gates_open)
	var left: StepResult = H.step(r.state, H.R)
	assert_false(left.state.gates_open)


func test_gate_stops_objects_when_shut_and_lets_them_through_when_open() -> void:
	var s: SimState = H.state(["#####", "#.O.#", "#.H.#", "#...#", "#@..#", "#####"])
	assert_eq(H.obj(H.step(s).state, 2, 1), Tiles.Obj.BOULDER)
	s.gates_open = true
	assert_eq(H.obj(H.step(s).state, 2, 2), Tiles.Obj.BOULDER)


# --- State ---------------------------------------------------------------------

func test_copy_is_deep_and_hash_sees_echoes() -> void:
	var plain: SimState = H.state(["#####", "#@..#", "#####"])
	var a: SimState = _with_echo(plain, "R")
	assert_ne(a.hash(), plain.hash())
	var b: SimState = a.copy()
	assert_eq(a.hash(), b.hash())
	b.echoes[0].cursor = 1
	assert_eq(a.echoes[0].cursor, 0)
	assert_ne(a.hash(), b.hash())


func test_step_with_echo_is_deterministic_and_pure() -> void:
	var s: SimState = _with_echo(H.state(["######", "#@O..#", "#....#", "######"]), "RR")
	var before: String = s.hash()
	assert_eq(H.run(s, "DR").hash(), H.run(s, "DR").hash())
	assert_eq(s.hash(), before)


func test_replay_hourglass_char_leaves_an_echo() -> void:
	var after: SimState = H.run(H.state(["######", "#@...#", "#....#", "######"]), "RR H")
	assert_eq(after.player, Vector2i(1, 1))
	assert_eq(after.tick, 0)
	assert_eq(after.echoes.size(), 1)
	assert_eq(Replay.encode_inputs(after.echoes[0].inputs), "RR")


func test_thinking_before_the_hourglass_still_gives_the_echo_your_walk() -> void:
	var after: SimState = H.run(H.state(["######", "#@...#", "#....#", "######"]), "RR" + ".".repeat(100) + "H")
	assert_eq(after.player, Vector2i(1, 1), "back to before the walk, not just before the pause")
	assert_eq(Replay.encode_inputs(after.echoes[0].inputs), "RR")
	assert_eq(H.run(after, "..").echoes[0].cell, Vector2i(3, 1), "and the ghost walks")


func test_game_rewind_spawns_echo_of_recorded_moves() -> void:
	var path: String = "user://test_echo_level.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(LevelCodec.from_combined(["######", "#@...#", "######"], {"gems_required": 0})))
	file.close()
	Game.move_interval_ticks = 1
	assert_true(Game.load_level(path))
	Game.stop()
	Game.press(SimStep.Intent.RIGHT)
	Game._advance()
	Game._advance()
	Game.release_all()
	assert_true(Game.rewind())
	assert_eq(Game.state.player, Vector2i(1, 1))
	assert_eq(Game.state.echoes.size(), 1)
	assert_eq(Replay.encode_inputs(Game.state.echoes[0].inputs), "RR")
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
