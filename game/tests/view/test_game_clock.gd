extends GutTest
## Game autoload: level loading, tick advance and the input buffer (taps between ticks aren't lost,
## the most recently held direction wins). The clock is stopped so ticks are advanced by hand.

const LEVEL: String = "res://levels/test/test_01_walk_dig.json"


func before_each() -> void:
	Game.move_interval_ticks = 1  # most tests here look at buffering, one move per tick
	assert_true(Game.load_level(LEVEL))
	Game.stop()


func after_each() -> void:
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	Game.release_all()
	Game.stop()


func test_load_sets_state() -> void:
	assert_not_null(Game.state)
	assert_eq(Game.state.player, Vector2i(1, 1))
	assert_eq(Game.prev_state, Game.state)


func test_tap_between_ticks_is_used_once() -> void:
	Game.press(SimStep.Intent.RIGHT)
	Game.release(SimStep.Intent.RIGHT)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1))
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1), "a released tap moves only once")


func test_held_direction_repeats_every_tick() -> void:
	Game.press(SimStep.Intent.RIGHT)
	Game._advance()
	Game._advance()
	assert_eq(Game.state.player, Vector2i(3, 1))


func test_most_recent_held_direction_wins() -> void:
	Game.press(SimStep.Intent.RIGHT)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1))
	Game.press(SimStep.Intent.LEFT)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(1, 1), "LEFT pressed last wins while RIGHT is still held")
	Game.release(SimStep.Intent.LEFT)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1), "releasing LEFT falls back to the still-held RIGHT")


## The cadence is one tile per tick now (playtest 7: "still lagging"), but the cooldown still works if it's raised.
func test_walking_cadence_limits_held_direction() -> void:
	Game.move_interval_ticks = 2
	Game.press(SimStep.Intent.RIGHT)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1), "the first step is immediate")
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1), "cooling down")
	Game._advance()
	assert_eq(Game.state.player, Vector2i(3, 1), "second step after the interval")


func test_tap_during_cooldown_waits_instead_of_vanishing() -> void:
	Game.move_interval_ticks = 2
	Game.press(SimStep.Intent.RIGHT)
	Game.release(SimStep.Intent.RIGHT)
	Game._advance()
	Game.press(SimStep.Intent.RIGHT)  # not a reversal: those skip the cooldown
	Game.release(SimStep.Intent.RIGHT)
	Game._advance()
	assert_eq(Game.state.player, Vector2i(2, 1), "cooling down")
	Game._advance()
	assert_eq(Game.state.player, Vector2i(3, 1), "the buffered tap happens")


# --- Responsiveness (playtest 6: "if I move left and get back, it has to follow, or the dart hits me") ---

func _start_clock() -> void:
	Game.move_interval_ticks = Game.MOVE_INTERVAL_TICKS
	Game.running = true


func test_a_press_moves_on_the_next_frame_not_the_next_tick() -> void:
	_start_clock()
	Game._process(0.001)  # a frame with almost no time passed
	var tick: int = Game.state.tick
	Game.press(SimStep.Intent.RIGHT)
	Game._process(0.016)
	assert_eq(Game.state.player, Vector2i(2, 1), "one frame after the press")
	assert_eq(Game.state.tick, tick + 1, "exactly one tick, no catch-up burst")


func test_reversing_skips_the_walking_cadence() -> void:
	_start_clock()
	Game.press(SimStep.Intent.RIGHT)
	Game._process(0.016)
	Game.release(SimStep.Intent.RIGHT)
	assert_eq(Game.state.player, Vector2i(2, 1))
	Game.press(SimStep.Intent.LEFT)
	Game._process(0.016)
	assert_eq(Game.state.player, Vector2i(1, 1), "straight back, no cooldown")


func test_other_turns_still_keep_the_walking_cadence() -> void:
	_start_clock()
	Game.move_interval_ticks = 2
	Game.press(SimStep.Intent.RIGHT)
	Game._process(0.016)
	Game.release(SimStep.Intent.RIGHT)
	Game.press(SimStep.Intent.DOWN)
	Game._process(0.016)
	assert_eq(Game.state.player, Vector2i(2, 1), "a sideways step waits for the cooldown")


func test_holding_a_direction_still_walks_at_walking_speed() -> void:
	_start_clock()
	Game.press(SimStep.Intent.RIGHT)
	for i: int in 5:
		Game._process(0.1)
	assert_between(Game.state.player.x - 1, 5, 6, "one tile per tick, no faster")


func test_no_early_tick_while_dead() -> void:
	_start_clock()
	Game.state.alive = false
	var tick: int = Game.state.tick
	Game.press(SimStep.Intent.RIGHT)
	Game._process(0.016)
	assert_eq(Game.state.tick, tick)


func test_prev_state_kept_for_interpolation() -> void:
	Game.press(SimStep.Intent.RIGHT)
	Game._advance()
	assert_eq(Game.prev_state.player, Vector2i(1, 1))
	assert_eq(Game.state.player, Vector2i(2, 1))


func test_restart_reloads() -> void:
	Game.press(SimStep.Intent.RIGHT)
	Game._advance()
	Game.restart()
	Game.stop()
	assert_eq(Game.state.player, Vector2i(1, 1))
	assert_eq(Game.state.tick, 0)
