extends GutTest
## Task 2.4: hourglass ring buffer.


func _state(tick: int) -> SimState:
	var s: SimState = SimState.create(1, 1)
	s.tick = tick
	return s


func test_reaches_back_a_window_when_never_moved() -> void:
	var b := RewindBuffer.new(3)
	for t: int in 5:
		b.push(_state(t))
	assert_eq(b.rewind_all().tick, 2)


func test_window_counts_back_from_the_last_move() -> void:
	var b := RewindBuffer.new(3)
	for t: int in 6:
		b.push(_state(t), SimStep.Intent.RIGHT)
	for t: int in range(6, 50):
		b.push(_state(t))  # standing still to think
	assert_eq(b.intents(), PackedInt32Array([4, 4, 4]))
	assert_eq(b.rewind_all().tick, 3)


func test_idle_ticks_inside_the_walk_are_kept_but_trailing_ones_arent() -> void:
	var b := RewindBuffer.new(30)
	b.push(_state(0), SimStep.Intent.RIGHT)
	b.push(_state(1))
	b.push(_state(2), SimStep.Intent.DOWN)
	b.push(_state(3))
	b.push(_state(4))
	assert_eq(Replay.encode_inputs(b.intents()), "R.D")
	assert_eq(b.rewind_all().tick, 0)


func test_old_history_is_dropped_after_a_very_long_pause() -> void:
	var b := RewindBuffer.new(3)
	b.push(_state(0), SimStep.Intent.RIGHT)
	for t: int in range(1, RewindBuffer.MAX_KEPT_TICKS + 5):
		b.push(_state(t))
	assert_eq(b.size(), RewindBuffer.MAX_KEPT_TICKS)
	assert_eq(b.intents().count(SimStep.Intent.RIGHT), 0)


func test_rewind_all_empties() -> void:
	var b := RewindBuffer.new(30)
	b.push(_state(0))
	b.push(_state(1))
	assert_eq(b.rewind_all().tick, 0)
	assert_true(b.is_empty())
	assert_null(b.rewind_all())
