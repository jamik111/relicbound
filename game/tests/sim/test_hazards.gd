extends GutTest
## Task 2.5: pits, cracked floor, spikes, dart walls.

const H = preload("res://tests/sim/sim_helpers.gd")


func _killed_by(r: StepResult) -> int:
	for e: SimEvent in r.events:
		if e.type == SimEvent.Type.PLAYER_KILLED:
			return e.value
	return -1


## Steps with no input until the state's tick equals `tick`.
func _run_to(s: SimState, tick: int) -> SimState:
	while s.tick < tick:
		s = H.step(s).state
	return s


# --- Pits ---------------------------------------------------------------------

func test_walking_into_pit_kills() -> void:
	var r: StepResult = H.step(H.state(["#####", "#@_.#", "#####"]), H.R)
	assert_false(r.state.alive)
	assert_eq(_killed_by(r), SimEvent.Cause.PIT)


func test_pushed_boulder_fills_pit() -> void:
	var r: StepResult = H.step(H.state(["######", "#@O_.#", "######"]), H.R)
	assert_eq(r.state.terrain_at(Vector2i(3, 1)), Tiles.Terrain.FLOOR)
	assert_eq(H.obj(r.state, 3, 1), Tiles.Obj.NONE)
	assert_true(r.has_event(SimEvent.Type.PIT_FILLED))
	var r2: StepResult = H.step(r.state, H.R)
	assert_eq(r2.state.player, Vector2i(3, 1))
	assert_true(r2.state.alive, "the filled pit is safe floor")


func test_falling_crate_fills_pit() -> void:
	var s: SimState = H.state(["#####", "#.X.#", "#._.#", "#@..#", "#####"])
	var r: StepResult = H.step(s)
	assert_eq(r.state.terrain_at(Vector2i(2, 2)), Tiles.Terrain.FLOOR)
	assert_eq(r.state.count_objects(Tiles.Obj.CRATE), 0)


# --- Cracked floor ------------------------------------------------------------

func test_cracked_floor_collapses_one_tick_after_leaving() -> void:
	var s: SimState = H.state(["######", "#@=..#", "######"])
	var on: StepResult = H.step(s, H.R)
	assert_eq(on.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.CRACKED, "standing on it is fine")
	var off: StepResult = H.step(on.state, H.R)
	assert_eq(off.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.CRACKED_COLLAPSING)
	assert_true(off.has_event(SimEvent.Type.FLOOR_CRACKING))
	var next: StepResult = H.step(off.state)
	assert_eq(next.state.terrain_at(Vector2i(2, 1)), Tiles.Terrain.PIT)
	assert_true(next.has_event(SimEvent.Type.FLOOR_COLLAPSED))


func test_stepping_back_onto_collapsed_floor_kills() -> void:
	var s: SimState = H.run(H.state(["######", "#@=..#", "######"]), "RR")
	var r: StepResult = H.step(s, H.L)
	assert_false(r.state.alive)
	assert_eq(_killed_by(r), SimEvent.Cause.PIT)


# --- Spikes -------------------------------------------------------------------

func test_spike_cycle_warns_before_rising() -> void:
	var s: SimState = H.state(["#####", "#@^.#", "#####"])
	var warn_tick: int = RuleHazards.SPIKE_CYCLE - RuleHazards.SPIKE_UP - RuleHazards.SPIKE_WARN
	var r: StepResult = H.step(_run_to(s, warn_tick))
	assert_true(r.has_event(SimEvent.Type.SPIKES_WARNING))
	var up: StepResult = H.step(_run_to(r.state, RuleHazards.SPIKE_CYCLE - RuleHazards.SPIKE_UP))
	assert_true(up.has_event(SimEvent.Type.SPIKES_UP))
	assert_gte(RuleHazards.SPIKE_WARN, 4, "GDD: telegraph >= 0.4 s at 10 ticks/s")


func test_spikes_kill_only_when_up() -> void:
	var s: SimState = H.state(["#####", "#@^.#", "#####"])
	var on: StepResult = H.step(s, H.R)
	assert_true(on.state.alive, "spikes are down at tick 0")
	var up_tick: int = RuleHazards.SPIKE_CYCLE - RuleHazards.SPIKE_UP
	var before: SimState = _run_to(on.state, up_tick)
	assert_true(before.alive, "still alive through the warning")
	var r: StepResult = H.step(before)
	assert_false(r.state.alive)
	assert_eq(_killed_by(r), SimEvent.Cause.SPIKES)


func test_spike_phase_b_is_half_a_cycle_later() -> void:
	var up_a: int = RuleHazards.SPIKE_CYCLE - 1
	assert_eq(RuleHazards.spike_phase(up_a, Tiles.Terrain.SPIKES_A), RuleHazards.SpikePhase.UP)
	assert_eq(RuleHazards.spike_phase(up_a, Tiles.Terrain.SPIKES_B), RuleHazards.SpikePhase.DOWN)
	assert_eq(RuleHazards.spike_phase(up_a - RuleHazards.SPIKE_CYCLE / 2, Tiles.Terrain.SPIKES_B),
		RuleHazards.SpikePhase.UP)


func test_objects_rest_on_spikes_and_cracked_floor() -> void:
	var s: SimState = H.state(["#####", "#.OX#", "#.^=#", "#@###", "#####"])
	var after: SimState = H.run(s, "...")
	assert_eq(H.obj(after, 2, 2), Tiles.Obj.BOULDER)
	assert_eq(H.obj(after, 3, 2), Tiles.Obj.CRATE)


# --- Darts --------------------------------------------------------------------

func test_dart_hits_player_in_row() -> void:
	var s: SimState = H.state(["#######", "#>..@.#", "#######"])
	var fire_tick: int = RuleHazards.DART_PERIOD - 1
	var warn: StepResult = H.step(_run_to(s, fire_tick - RuleHazards.DART_WARN))
	assert_true(warn.has_event(SimEvent.Type.DART_WARNING))
	var r: StepResult = H.step(_run_to(warn.state, fire_tick))
	assert_false(r.state.alive)
	assert_eq(_killed_by(r), SimEvent.Cause.DART)


func test_object_blocks_dart() -> void:
	var s: SimState = H.state(["#######", "#>.X@.#", "#######"])
	var r: StepResult = H.step(_run_to(s, RuleHazards.DART_PERIOD - 1))
	assert_true(r.state.alive)
	var fired: Array = r.events.filter(func(e: SimEvent) -> bool: return e.type == SimEvent.Type.DART_FIRED)
	assert_eq((fired[0] as SimEvent).to, Vector2i(3, 1), "stopped at the crate")


func test_idol_shelters_player_from_darts() -> void:
	var s: SimState = H.run(H.state(["#######", "#>@I..#", "#######"]), "R")
	var r: StepResult = H.step(_run_to(s, RuleHazards.DART_PERIOD - 1))
	assert_true(r.state.alive)


func test_west_dart_wall_fires_west() -> void:
	var s: SimState = H.state(["#######", "#.@..<#", "#######"])
	assert_false(H.step(_run_to(s, RuleHazards.DART_PERIOD - 1)).state.alive)
