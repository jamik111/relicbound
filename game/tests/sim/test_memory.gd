extends GutTest
## "The temple remembers": scars and remnants (RuleMemory), and level 7, whose puzzle depends on them.

const H = preload("res://tests/sim/sim_helpers.gd")
const LEVEL_7: String = "res://levels/greybox/level_07_where_you_fall.json"
const NEAR_PLATE := Vector2i(5, 1)
const FAR_PLATE := Vector2i(9, 1)
const JUNCTION := Vector2i(3, 1)


func _remembering(rows: PackedStringArray) -> SimState:
	return H.state(rows, {"remembers": true})


# --- Scars ------------------------------------------------------------------------

func test_scar_blocks_the_player() -> void:
	var s: SimState = RuleMemory.scarred(_remembering(["#####", "#@..#", "#####"]), Vector2i(2, 1))
	assert_eq(H.run(s, "R").player, Vector2i(1, 1))


func test_scar_blocks_echoes() -> void:
	var start: SimState = RuleMemory.scarred(_remembering(["#####", "#@..#", "#####"]), Vector2i(2, 1))
	var s: SimState = RuleEcho.spawned(start, PackedInt32Array([SimStep.Intent.RIGHT]))
	assert_eq(H.run(s, ".").echoes[0].cell, Vector2i(1, 1))


func test_scar_stops_falling_objects_and_darts() -> void:
	var boulder: SimState = RuleMemory.scarred(_remembering(["#####", "#.O.#", "#...#", "#@..#", "#####"]), Vector2i(2, 3))
	assert_eq(H.obj(H.run(boulder, "...."), 2, 2), Tiles.Obj.BOULDER)
	var open: SimState = _remembering(["#####", "#>.@#", "#####"])
	var idle: String = ".".repeat(RuleHazards.DART_PERIOD)
	assert_false(H.run(open, idle).alive, "without the scar the dart hits")
	assert_true(H.run(RuleMemory.scarred(open, Vector2i(2, 1)), idle).alive)


func test_scar_holds_a_plate_down() -> void:
	var s: SimState = RuleMemory.scarred(_remembering(["#####", "#@P.#", "##H##", "#####"]), Vector2i(2, 1))
	assert_true(H.run(s, ".").gates_open)


func test_only_the_newest_scars_last() -> void:
	var s: SimState = _remembering(["#######", "#@....#", "#######"])
	for x: int in [2, 3, 4, 5]:
		s = RuleMemory.scarred(s, Vector2i(x, 1))
	assert_eq(s.scars.size(), RuleMemory.MAX_SCARS)
	assert_eq(H.obj(s, 2, 1), Tiles.Obj.NONE, "the oldest went first")
	assert_eq(H.obj(s, 5, 1), Tiles.Obj.SCAR)


func test_no_scar_on_the_respawn_cell_or_an_object() -> void:
	var s: SimState = _remembering(["#####", "#@X.#", "#####"])
	assert_true(RuleMemory.scarred(s, Vector2i(1, 1)).scars.is_empty())
	assert_true(RuleMemory.scarred(s, Vector2i(2, 1)).scars.is_empty())


func test_scars_change_the_hash() -> void:
	var s: SimState = _remembering(["#####", "#@..#", "#####"])
	assert_ne(RuleMemory.scarred(s, Vector2i(3, 1)).hash(), s.hash())


# --- The same attempt can't happen twice -------------------------------------------

func test_repeating_a_fatal_attempt_exactly_doesnt_end_the_same_way() -> void:
	var start: SimState = LevelLoader.load_state(LEVEL_7)
	var fatal: String = "R.U.U.R.R." + ".".repeat(21)
	var first: SimState = Replay.run(start, fatal)
	assert_false(first.alive)
	assert_eq(first.player, NEAR_PLATE)
	var second: SimState = Replay.run(start, fatal + "X" + fatal)
	assert_ne(second.player, NEAR_PLATE, "the scar is standing there")


# --- Remnants ---------------------------------------------------------------------

func test_remnant_replays_the_attempt_and_pushes_what_you_pushed() -> void:
	var s: SimState = _remembering(["#######", "#@.X..#", "#######"])
	var ghost: SimState = RuleMemory.with_remnant(s, PackedInt32Array([4, 0, 4]))
	assert_true(ghost.echoes[0].remnant)
	assert_eq(H.obj(H.run(ghost, "..."), 4, 1), Tiles.Obj.CRATE)


func test_remnant_skips_long_pauses() -> void:
	var idle := PackedInt32Array()
	idle.resize(100)
	idle.fill(SimStep.Intent.NONE)
	var ghost: SimState = RuleMemory.with_remnant(_remembering(["###", "#@#", "###"]), idle)
	assert_eq(ghost.echoes[0].inputs.size(), RuleMemory.MAX_IDLE_RUN)


func test_remnant_changes_the_hash() -> void:
	var s: SimState = _remembering(["###", "#@#", "###"])
	var echo: SimState = RuleEcho.spawned(s, PackedInt32Array())
	assert_ne(RuleMemory.with_remnant(s, PackedInt32Array()).hash(), echo.hash())


# --- Only levels that ask for it remember ------------------------------------------

func test_other_levels_respawn_clean() -> void:
	var s: SimState = H.state(["#####", "#@_.#", "#####"])
	var after: SimState = Replay.run(s, "R.X")
	assert_true(after.alive)
	assert_true(after.scars.is_empty())
	assert_true(after.echoes.is_empty())


func test_codec_reads_the_level_options() -> void:
	var s: SimState = LevelLoader.load_state(LEVEL_7)
	assert_true(s.remembers)
	assert_eq(s.hourglass_uses, 0)
	assert_eq(H.state(["#@#"]).hourglass_uses, 3)


# --- Level 7, checked exhaustively ---------------------------------------------------
# A search over every input from a given set of scars. It ignores the walking speed, so it allows more than a person
# can do. It leaves out remnants, so it says nothing about routes that use one to hold a plate for a moment.

## Returns {won: bool, deaths: {cell: true}} for everything reachable without dying.
func _explore(start: SimState) -> Dictionary:
	var seen: Dictionary = {}
	var deaths: Dictionary = {}
	var queue: Array[SimState] = [start]
	while not queue.is_empty():
		var s: SimState = queue.pop_back()
		for intent: int in SimStep.DIRECTIONS.size():
			var next: SimState = SimStep.step(s, intent as SimStep.Intent).state
			if next.won:
				return {"won": true, "deaths": deaths}
			if not next.alive:
				deaths[next.player] = true
				continue
			var key: Array = [next.player, next.tick % RuleHazards.DART_PERIOD, next.gems_collected, next.gates_open]
			if not seen.has(key):
				seen[key] = true
				queue.append(next)
	return {"won": false, "deaths": deaths}


func test_level_7_cant_be_won_without_dying() -> void:
	assert_false(_explore(LevelLoader.load_state(LEVEL_7))["won"])


func test_level_7_cant_be_won_with_any_single_scar() -> void:
	var start: SimState = LevelLoader.load_state(LEVEL_7)
	var deaths: Dictionary = _explore(start)["deaths"]
	assert_true(deaths.has(NEAR_PLATE) and deaths.has(FAR_PLATE))
	for cell: Vector2i in deaths:
		assert_false(_explore(RuleMemory.scarred(start, cell))["won"], "scar at %s" % cell)


func test_level_7_near_plate_first_cuts_off_the_far_plate() -> void:
	var near: SimState = RuleMemory.scarred(LevelLoader.load_state(LEVEL_7), NEAR_PLATE)
	assert_false(_explore(near)["deaths"].has(FAR_PLATE))


func test_level_7_far_plate_then_near_plate_wins() -> void:
	var far: SimState = RuleMemory.scarred(LevelLoader.load_state(LEVEL_7), FAR_PLATE)
	assert_true(_explore(far)["deaths"].has(NEAR_PLATE))
	assert_true(_explore(RuleMemory.scarred(far, NEAR_PLATE))["won"])
