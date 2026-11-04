extends GutTest
## Task 2.4: hourglass ring buffer.


func _state(tick: int) -> SimState:
	var s: SimState = SimState.create(1, 1)
	s.tick = tick
	return s


func test_keeps_only_capacity_newest() -> void:
	var b := RewindBuffer.new(3)
	for t: int in 5:
		b.push(_state(t))
	assert_eq(b.size(), 3)
	assert_eq(b.rewind_all().tick, 2, "oldest kept state")


func test_rewind_all_empties() -> void:
	var b := RewindBuffer.new(30)
	b.push(_state(0))
	b.push(_state(1))
	assert_eq(b.rewind_all().tick, 0)
	assert_true(b.is_empty())
	assert_null(b.rewind_all())
