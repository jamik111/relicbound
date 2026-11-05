extends GutTest
## "The temple remembers": scars and remnants (RuleMemory), and level 7, whose puzzle depends on them.

const H = preload("res://tests/sim/sim_helpers.gd")
const LEVEL_7: String = "res://levels/greybox/level_07_where_you_fall.json"
const NEAR_PLATE := Vector2i(5, 1)
const FAR_PLATE := Vector2i(9, 1)
const LEVEL_8: String = "res://levels/greybox/level_08_before_you_fall.json"
const NEAR_PLATE_8 := Vector2i(1, 4)
const FAR_PLATE_8 := Vector2i(8, 2)
const IDOL_8 := Vector2i(6, 1)
const LEVEL_9: String = "res://levels/greybox/level_09_long_way_round.json"
const SHIELD_9 := Vector2i(3, 3)
const LOWER_PLATE_9 := Vector2i(19, 3)
const UPPER_PLATE_9 := Vector2i(18, 1)


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

## Returns {won: bool, gem: bool, deaths: {cell: true}} for everything reachable without dying. `move_ticks` limits how
## often the player can move: 1 ignores the walking speed, Game.MOVE_INTERVAL_TICKS is what a person can do.
func _explore(start: SimState, move_ticks: int = 1) -> Dictionary:
	var seen: Dictionary = {}
	var deaths: Dictionary = {}
	var gem: bool = false
	var queue: Array[Array] = [[start, 0]]
	while not queue.is_empty():
		var entry: Array = queue.pop_back()
		var s: SimState = entry[0]
		var cooldown: int = entry[1]
		for intent: int in SimStep.DIRECTIONS.size() if cooldown == 0 else 1:
			var next: SimState = SimStep.step(s, intent as SimStep.Intent).state
			gem = gem or next.gems_collected > start.gems_collected
			if next.won:
				return {"won": true, "gem": gem, "deaths": deaths}
			if not next.alive:
				deaths[next.player] = true
				continue
			var next_cooldown: int = maxi(0, cooldown - 1) if intent == 0 else move_ticks - 1
			var key: Array = [next.player, next.tick % RuleHazards.DART_PERIOD, next.gems_collected, next.gates_open,
				hash(next.terrain), next_cooldown]
			if not seen.has(key):
				seen[key] = true
				queue.append([next, next_cooldown])
	return {"won": false, "gem": gem, "deaths": deaths}


func test_level_7_cant_be_won_without_dying() -> void:
	assert_false(_explore(LevelLoader.load_state(LEVEL_7))["won"])


func test_level_7_cant_be_won_with_any_single_scar() -> void:
	var start: SimState = LevelLoader.load_state(LEVEL_7)
	var deaths: Dictionary = _explore(start)["deaths"]
	assert_true(deaths.has(NEAR_PLATE) and deaths.has(FAR_PLATE))
	for cell: Vector2i in deaths:
		assert_false(_explore(RuleMemory.scarred(start, cell))["won"], "scar at %s" % cell)


## Playtest 3 won by running through the gate while a remnant stood on the near plate: reflexes, not the puzzle.
func test_level_7_a_remnant_on_the_near_plate_doesnt_open_the_gate() -> void:
	var far: String = "R.U.U.R.R.R.R.R.R." + ".".repeat(12)
	var past_near: String = "R.U.U.R.R.R." + ".".repeat(18)
	var run: String = "R.R.R.R.R.R.R.R.R.R.R.R."
	var s: SimState = Replay.run(LevelLoader.load_state(LEVEL_7), far + "X" + past_near + "X" + run)
	assert_false(s.won)
	assert_eq(s.player, Vector2i(9, 3), "stopped at the shut gate")


func test_remnant_has_no_weight_but_an_echo_does() -> void:
	var s: SimState = _remembering(["#####", "#@P.#", "##H##", "#####"])
	var inputs := PackedInt32Array([SimStep.Intent.RIGHT])
	assert_false(H.run(RuleMemory.with_remnant(s, inputs), "..").gates_open)
	assert_true(H.run(RuleEcho.spawned(s, inputs), "..").gates_open)


# --- Level 8: the order is gem, idol, die on the far plate, echo on the near plate ---

func _level_8() -> SimState:
	return LevelLoader.load_state(LEVEL_8)


func test_level_8_cant_be_won_without_dying() -> void:
	assert_false(_explore(_level_8())["won"])


func test_level_8_has_one_hourglass_use_so_one_echo_cant_hold_both_plates() -> void:
	assert_eq(_level_8().hourglass_uses, 1)


func test_level_8_the_near_plate_cant_take_a_scar() -> void:
	assert_false(_explore(_level_8())["deaths"].has(NEAR_PLATE_8))


func test_level_8_dying_on_the_far_plate_too_soon_walls_off_the_gem() -> void:
	var scarred: SimState = RuleMemory.scarred(_level_8(), FAR_PLATE_8)
	assert_false(_explore(scarred)["gem"], "the scar stands between you and the gem")


func test_level_8_lighting_the_idol_before_the_gem_loses_the_gem() -> void:
	var inputs: String = "R.R.R.U.U.U."  # straight to the idol
	var s: SimState = Replay.run(_level_8(), inputs + "D.R.R.R.L.." + ".".repeat(30) + "X")
	assert_eq(s.terrain_at(IDOL_8), Tiles.Terrain.CHECKPOINT_LIT)
	assert_eq(s.gems_collected, 0, "the save was made without it")
	assert_false(_explore(s)["gem"])


func test_level_8_gem_then_idol_keeps_the_gem() -> void:
	var s: SimState = Replay.run(_level_8(), "R.R.R.U.U.R.R.R.L.L.L.U.. D.R.R.. X")
	assert_eq(s.player, IDOL_8)
	assert_eq(s.gems_collected, 1)
	assert_eq(s.object_at(FAR_PLATE_8), Tiles.Obj.SCAR)


func test_level_8_the_echo_gives_time_to_walk() -> void:
	# The solution with a pause before the gate: no run needed.
	var setup: String = "R.R.R.U.U.R.R.R.L.L.L.U.. D.R.R.. X D.D.D.L.L.L.L.L. H"
	var s: SimState = Replay.run(_level_8(), setup + "D.D.D.R.R.R.R.R.R." + ".".repeat(20) + "R.R.R.")
	assert_true(s.won)


func test_saved_scars_go_back_in_order_and_skip_cells_that_dont_fit() -> void:
	var s: SimState = _remembering(["#####", "#@..#", "#####"])
	var cells := PackedInt32Array([s.idx(Vector2i(3, 1)), s.idx(Vector2i(0, 0)), s.idx(Vector2i(2, 1))])
	assert_eq(RuleMemory.with_scars(s, cells).scars, PackedInt32Array([s.idx(Vector2i(3, 1)), s.idx(Vector2i(2, 1))]))


# --- Level 9: shield the corridor, gem, idol, die on the upper plate, echo on the lower plate ---

func _level_9() -> SimState:
	return LevelLoader.load_state(LEVEL_9)


func test_level_9_the_corridor_cant_be_crossed_between_darts() -> void:
	assert_false(_explore(_level_9(), Game.MOVE_INTERVAL_TICKS)["gem"])


func test_level_9_a_scar_west_of_the_junction_opens_the_corridor() -> void:
	for x: int in [2, 3]:
		var shielded: SimState = RuleMemory.scarred(_level_9(), Vector2i(x, 3))
		assert_true(_explore(shielded, Game.MOVE_INTERVAL_TICKS)["gem"], "scar at x=%d" % x)


func test_level_9_a_scar_along_the_corridor_blocks_it() -> void:
	for x: int in [4, 5, 10, 18]:
		var blocked: SimState = RuleMemory.scarred(_level_9(), Vector2i(x, 3))
		assert_false(_explore(blocked, Game.MOVE_INTERVAL_TICKS)["gem"], "scar at x=%d" % x)


func test_level_9_the_upper_plate_too_soon_walls_off_the_gem() -> void:
	var s: SimState = RuleMemory.scarred(RuleMemory.scarred(_level_9(), SHIELD_9), UPPER_PLATE_9)
	assert_false(_explore(s, Game.MOVE_INTERVAL_TICKS)["gem"])


func test_level_9_the_shield_also_stops_you_dying_in_the_corridor() -> void:
	var shielded: SimState = RuleMemory.scarred(_level_9(), SHIELD_9)
	var deaths: Dictionary = _explore(shielded, Game.MOVE_INTERVAL_TICKS)["deaths"]
	assert_false(deaths.has(LOWER_PLATE_9), "so the lower plate can't take a scar")
	assert_true(deaths.has(UPPER_PLATE_9))


func test_level_9_lower_plate_alone_doesnt_open_the_gate() -> void:
	var s: SimState = RuleMemory.scarred(_level_9(), LOWER_PLATE_9)
	assert_false(H.run(s, ".").gates_open)


func test_level_9_there_is_time_to_walk_after_the_hourglass() -> void:
	var setup: String = ("R.R.U.U.L." + ".".repeat(20) + "X" + "R.R.U.U." + "R.".repeat(16) + "U.U.L.L.L.L.R.R.R.D.."
		+ "U.L." + ".".repeat(26) + "X" + "D" + "H")
	var s: SimState = Replay.run(_level_9(), setup + "D." + "L.".repeat(15) + "D.D." + ".".repeat(8) + "R.R.R.")
	assert_true(s.won, "a 0.8 s pause on the way is fine")


func test_level_7_near_plate_first_cuts_off_the_far_plate() -> void:
	var near: SimState = RuleMemory.scarred(LevelLoader.load_state(LEVEL_7), NEAR_PLATE)
	assert_false(_explore(near)["deaths"].has(FAR_PLATE))


func test_level_7_far_plate_then_near_plate_wins() -> void:
	var far: SimState = RuleMemory.scarred(LevelLoader.load_state(LEVEL_7), FAR_PLATE)
	assert_true(_explore(far)["deaths"].has(NEAR_PLATE))
	assert_true(_explore(RuleMemory.scarred(far, NEAR_PLATE))["won"])
